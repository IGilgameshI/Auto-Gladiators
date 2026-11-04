--!nocheck
-- Движок автобоя 1 на 1.
-- Чистый модуль: не использует API Roblox. Симуляция идёт тиками по
-- Config.Combat.Dt секунд, весь случай берётся из ГСЧ с seed, поэтому
-- одинаковые спецификации + seed всегда дают одинаковый бой.
--
-- Использование:
--   local result = Engine.simulate(specA, specB, seed)
--   result.winner  -- 1 или 2
--   result.time    -- длительность боя, сек
--   result.log     -- журнал событий для воспроизведения на клиенте
--   result.final   -- { {hp, maxHp}, {hp, maxHp} }
--
-- Спецификацию бойца собирает Combat/Builder.lua (см. там формат).

local Config = require(script.Parent.Parent.Config)
local Rng = require(script.Parent.Rng)
local HeroKits = require(script.Parent.HeroKits)

local C = Config.Combat
local Engine = {}

local STACKS = { "poison", "ice", "fury", "shield", "injury" }
local ENEMY_STACK = { poison = true, ice = true, injury = true } -- накладываются на врага

---------------------------------------------------------------------------
-- Вспомогательные функции
---------------------------------------------------------------------------

local function clamp(x, lo, hi)
	if x < lo then
		return lo
	end
	if x > hi then
		return hi
	end
	return x
end

-- Значение по звезде: 5 чисел — напрямую, 3 — интерполяция, 1 — константа
local function starValue(arr, star)
	if arr == nil then
		return 0
	end
	if type(arr) == "number" then
		return arr
	end
	local n = #arr
	star = clamp(star or 1, 1, 5)
	if n >= 5 then
		return arr[star]
	elseif n == 3 then
		if star == 1 then
			return arr[1]
		elseif star == 2 then
			return (arr[1] + arr[2]) / 2
		elseif star == 3 then
			return arr[2]
		elseif star == 4 then
			return (arr[2] + arr[3]) / 2
		end
		return arr[3]
	elseif n == 1 then
		return arr[1]
	elseif n == 0 then
		return 0
	end
	return arr[math.min(star, n)]
end
Engine.starValue = starValue

-- Таблица статов: отсутствующий ключ = 0
local statMeta = {
	__index = function()
		return 0
	end,
}
local function newStats()
	return setmetatable({}, statMeta)
end

---------------------------------------------------------------------------
-- Построение юнита из спецификации
---------------------------------------------------------------------------

local function compileSource(u, src)
	local def = src.def
	local star = src.star or 1
	local vals = { v = starValue(def.v, star), v2 = starValue(def.v2, star) }
	for _, fx in ipairs(def.fx or {}) do
		local entry = { fx = fx, vals = vals, def = def, star = star, src = src }
		local k = fx.k
		if k == "stat" then
			local value = fx.val
			if value == nil then
				value = vals[fx.key or "v"] or 0
			end
			u.st[fx.stat] = u.st[fx.stat] + value
		elseif k == "statXp" then
			local xp = (u.spec.styleXp and u.spec.styleXp[fx.style]) or 0
			u.st[fx.stat] = u.st[fx.stat] + (vals[fx.key or "v2"] or 0) * xp
		elseif k == "on" then
			local list = u.on[fx.ev]
			if not list then
				list = {}
				u.on[fx.ev] = list
			end
			table.insert(list, entry)
		elseif k == "every" then
			entry.period = fx.t or vals[fx.tKey or "v"] or 1
			entry.timer = 0
			table.insert(u.every, entry)
		elseif k == "hpLoss" then
			entry.count = 0
			table.insert(u.hpLoss, entry)
		elseif k == "healAccum" then
			entry.count = 0
			table.insert(u.healAccum, entry)
		elseif k == "applyAccum" then
			entry.count = 0
			table.insert(u.applyAccum, entry)
		elseif k == "start" then
			table.insert(u.start, entry)
		elseif k == "below" then
			entry.fired = false
			table.insert(u.below, entry)
		elseif k == "ward" then
			table.insert(u.wardFx, entry)
		elseif k == "wardDeath" then
			table.insert(u.wardDeathFx, entry)
		elseif k == "special" then
			u.special[fx.id] = entry
		end
	end
end

local function newUnit(spec, side)
	local b = spec.base
	local u = {
		side = side,
		spec = spec,
		name = spec.name or "?",
		heroId = spec.heroId,
		st = newStats(),
		on = {},
		every = {},
		hpLoss = {},
		healAccum = {},
		applyAccum = {},
		start = {},
		below = {},
		wardFx = {},
		wardDeathFx = {},
		special = {},
		stk = { poison = 0, ice = 0, fury = 0, shield = 0, injury = 0 },
		perm = { poison = 0, ice = 0, fury = 0, shield = 0, injury = 0 },
		applied = { poison = 0, ice = 0, injury = 0 }, -- всего наложено (для накопителей)
		buffs = {},
		grow = newStats(), -- растущие в бою статы (с пределами)
		growTimes = {},
		wards = {},
		cooldowns = {},
		once = {},
		mana = 0,
		manaGained = 0,
		atkTimer = 0,
		poisonTimer = 0,
		decayTimer = 0,
		stunUntil = -1,
		silenceUntil = -1,
		immuneUntil = -1,
		physImmuneUntil = -1,
		lost = 0, -- всего потеряно HP
		healed = 0, -- всего вылечено
		healedWindow = 0,
		dealt = 0,
		ultCount = 0,
		attacks = 0,
		crits = 0,
		dead = false,
		kit = {}, -- состояние набора героя
	}
	-- Пассивные статы от спецификации (стили, черта, руны, таланты)
	for key, value in pairs(spec.stats or {}) do
		u.st[key] = u.st[key] + value
	end
	for _, src in ipairs(spec.sources or {}) do
		compileSource(u, src)
	end
	u.baseHp = b.hp
	u.baseAtk = b.atk
	u.interval = b.interval
	u.baseCrit = b.crit
	u.baseEvade = b.evade
	u.baseManaRegen = b.manaRegen
	u.critMult = b.critMult or C.CritMultBase
	u.ultFn = spec.ult
	return u
end

---------------------------------------------------------------------------
-- Симуляция
---------------------------------------------------------------------------

local Sim = {}
Sim.__index = Sim

function Sim:log(kind, side, a, b, c)
	if #self.events >= C.MaxLogEvents then
		return
	end
	table.insert(self.events, { math.floor(self.t * 100 + 0.5) / 100, kind, side, a, b, c })
end

function Sim:enemy(u)
	if u.side == 1 then
		return self.u2
	end
	return self.u1
end

-- Итоговые статы (с баффами и растущими значениями)
function Sim:stat(u, key)
	local total = u.st[key] + u.grow[key]
	for _, bf in ipairs(u.buffs) do
		if bf.stat == key then
			total = total + bf.val
		end
	end
	return total
end

function Sim:maxHp(u)
	return u.maxHpValue
end

function Sim:critChance(u)
	return clamp(u.baseCrit + self:stat(u, "crit"), 0, C.CritChanceMax)
end

function Sim:evadeChance(u)
	return clamp(u.baseEvade + self:stat(u, "evade"), 0, C.EvadeChanceMax)
end

function Sim:attackDamage(u)
	local atk = u.baseAtk + self:stat(u, "baseAtk")
	local pct = self:stat(u, "atkPct")
	local dmg = atk * (1 + pct / 100)
	if u.st.shieldToAtk > 0 then
		dmg = dmg + (u.stk.shield + u.perm.shield) * u.st.shieldToAtk / 100
	end
	return math.max(1, dmg)
end

function Sim:attackSpeed(u)
	local as = self:stat(u, "atkSpeed")
	if as > 0 and u.st.atkSpeedMul ~= 0 then
		as = as * (1 + u.st.atkSpeedMul / 100)
	end
	as = as + (u.stk.fury + u.perm.fury) * C.FuryAttackSpeedPerStack
	if u.st.iceImmune == 0 then
		as = as - (u.stk.ice + u.perm.ice) * C.IceAttackSpeedPerStack
	end
	return clamp(as, C.AttackSpeedMin, C.AttackSpeedMax)
end

function Sim:attackPeriod(u)
	return u.interval / (1 + self:attackSpeed(u) / 100)
end

function Sim:manaRegen(u)
	local e = self:enemy(u)
	local base = u.baseManaRegen + self:stat(u, "manaRegen")
	local mul = 1 + (u.stk.fury + u.perm.fury) * C.FuryManaRegenPerStack
	if u.st.iceImmune == 0 then
		mul = mul - (u.stk.ice + u.perm.ice) * C.IceManaRegenPerStack
	end
	mul = clamp(mul, C.ManaRegenMulMin, C.ManaRegenMulMax)
	local reduce = clamp(e.st.enemyManaRegenReduce, 0, 90)
	local pct = 1 + u.st.manaRegenPct / 100
	return math.max(0, base * mul * (1 - reduce / 100) * pct)
end

function Sim:ultPower(u)
	local e = self:enemy(u)
	local p = self:stat(u, "ultPower") + (u.arcaneStorm or 0) * 20 - e.st.enemyUltReduce
	return math.max(0.1, 1 + p / 100)
end

function Sim:overtime()
	if self.t <= C.OvertimeStart then
		return 1
	end
	return 1 + (self.t - C.OvertimeStart) * C.OvertimePerSec
end

---------------------------------------------------------------------------
-- Триггеры
---------------------------------------------------------------------------

function Sim:fire(u, ev, ctx)
	local list = u.on[ev]
	if not list then
		return
	end
	if self.depth > 6 then
		return
	end
	self.depth = self.depth + 1
	for _, entry in ipairs(list) do
		local fx = entry.fx
		if not (fx.noExtra and ctx and ctx.extra) then
			local chance = fx.chance
			if type(chance) == "string" then
				chance = entry.vals[chance] or 0
			end
			local cd = fx.cd or (fx.cdKey and entry.vals[fx.cdKey])
			local ready = true
			if cd then
				local last = u.cooldowns[entry]
				if last and self.t - last < cd then
					ready = false
				end
			end
			if ready and self.rng:chance(chance or 100) then
				if cd then
					u.cooldowns[entry] = self.t
				end
				self:act(u, entry, entry.fx.a, ctx)
			end
		end
	end
	self.depth = self.depth - 1
end

-- Значение действия
local function actValue(entry, a)
	if a.val ~= nil then
		return a.val
	end
	return entry.vals[a.key or "v"] or 0
end

function Sim:act(u, entry, a, ctx)
	if u.dead then
		return
	end
	local e = self:enemy(u)
	local kind = a[1]
	local v = actValue(entry, a)
	if kind == "heal" then
		self:heal(u, v)
	elseif kind == "mana" then
		self:addMana(u, v)
	elseif kind == "poison" or kind == "ice" or kind == "injury" then
		if a.timeMul then
			v = v * math.floor(self.t)
		end
		self:applyStack(u, e, kind, v)
	elseif kind == "shield" or kind == "fury" then
		self:applyStack(u, u, kind, v)
	elseif kind == "perm" then
		local target = u
		if ENEMY_STACK[a.s] then
			target = e
		end
		target.perm[a.s] = target.perm[a.s] + v
	elseif kind == "dmg" then
		local amount = v
		if a.plusSelfStack then
			amount = amount + (u.stk[a.plusSelfStack] + u.perm[a.plusSelfStack]) * (a.mul or 1)
		end
		if a.plusEnemyStack then
			amount = amount + (e.stk[a.plusEnemyStack] + e.perm[a.plusEnemyStack]) * (a.mul or 1)
		end
		if a.perSelfStack then
			amount = v * math.floor((u.stk[a.perSelfStack] + u.perm[a.perSelfStack]) / a.per)
		end
		if a.perEnemyStack then
			amount = v * math.floor((e.stk[a.perEnemyStack] + e.perm[a.perEnemyStack]) / a.per)
		end
		if a.plusLevel then
			amount = amount + (u.spec.heroLevel or 0) * a.plusLevel
		end
		if amount > 0 then
			self:damage(u, e, amount, a.t or "magic", { src = entry.def and entry.def.name })
		end
	elseif kind == "dmgCtx" then
		if ctx and ctx[a.field] and not (ctx.noReflect) then
			local amount = ctx[a.field] * v / 100
			if amount > 0 then
				self:damage(u, e, amount, a.t or "pure", { noReflect = a.noReflect, src = entry.def and entry.def.name })
			end
		end
	elseif kind == "dmgMaxHpPct" then
		self:damage(u, e, u.maxHpValue * v / 100, a.t or "phys", { src = entry.def and entry.def.name })
	elseif kind == "ult" then
		self:castUlt(u, 1)
	elseif kind == "attack" then
		self:doAttack(u, { extra = true })
	elseif kind == "buff" then
		local maxv = a.maxKey and entry.vals[a.maxKey] or math.huge
		local cur = 0
		for _, bf in ipairs(u.buffs) do
			if bf.entry == entry then
				cur = cur + bf.val
			end
		end
		local add = math.min(v, maxv - cur)
		if add > 0 then
			table.insert(u.buffs, { stat = a.stat, val = add, expire = self.t + (a.dur or 3), entry = entry })
		end
	elseif kind == "grow" then
		local maxv = math.huge
		if a.maxKey then
			maxv = entry.vals[a.maxKey]
		elseif a.maxVal then
			maxv = a.maxVal
		end
		local key = entry
		local cur = u.growTimes[key] or 0
		local add = math.min(v, maxv - cur)
		if add > 0 then
			u.growTimes[key] = cur + add
			u.grow[a.stat] = u.grow[a.stat] + add
			if a.stat == "maxHpPct" then
				self:recalcMaxHp(u)
			end
		end
	elseif kind == "growMaxHp" then
		local times = u.growTimes[entry] or 0
		if times < (a.maxTimes or 1) then
			u.growTimes[entry] = times + 1
			u.maxHpValue = u.maxHpValue + v
			u.hp = u.hp + v
		end
	elseif kind == "healLostPct" then
		self:heal(u, math.max(1, (u.maxHpValue - u.hp) * v / 100))
	elseif kind == "wardHeal" then
		for _, w in ipairs(u.wards) do
			if w.hp > 0 then
				w.hp = math.min(w.maxHp, w.hp + v)
				if not (ctx and ctx.allWards) then
					break
				end
			end
		end
	elseif kind == "summonWard" then
		self:summonWard(u, v, nil)
	elseif kind == "summonWardPct" then
		local first = u.firstWardMaxHp or (C.WispHealth * (1 + u.st.wardHpPct / 100))
		self:summonWard(u, first * v / 100, nil)
	elseif kind == "dmgWardExplode" then
		if ctx and ctx.ward then
			self:damage(u, e, v + ctx.ward.maxHp * (entry.vals.v2 or 0) / 100, "magic", { src = entry.def and entry.def.name })
		end
	elseif kind == "multi" then
		for _, sub in ipairs(a.list) do
			self:act(u, entry, sub, ctx)
		end
	elseif kind == "drainMana" then
		e.mana = math.max(0, e.mana - v)
	elseif kind == "physImmune" then
		u.physImmuneUntil = self.t + v
	elseif kind == "cleansePct" then
		local pct = v
		if pct <= 0 then
			pct = 30
		end
		for _, s in ipairs({ "poison", "ice", "injury" }) do
			u.stk[s] = math.floor(u.stk[s] * (1 - pct / 100))
		end
	elseif kind == "cleanseStack" then
		u.stk[a.s] = math.floor(u.stk[a.s] * (1 - v / 100))
	elseif kind == "enemyPhysWeaken" then
		e.physWeakUntil = self.t + (a.dur or 2)
		e.physWeak = v
	elseif kind == "tempMagicReduce" then
		table.insert(u.buffs, { stat = "magicReduce", val = v, expire = self.t + (a.dur or 2), entry = entry })
	elseif kind == "silence" then
		e.silenceUntil = math.max(e.silenceUntil, self.t + v)
	elseif kind == "stun" then
		self:stun(e, v)
	elseif kind == "stealStack" then
		local take = math.min(e.stk[a.s], v)
		e.stk[a.s] = e.stk[a.s] - take
		self:applyStack(u, u, a.s, take)
	elseif kind == "enemyAtkDown" then
		table.insert(e.buffs, { stat = "baseAtk", val = -v, expire = self.t + 3, entry = entry })
	end
end

---------------------------------------------------------------------------
-- Ресурсы: HP, мана, стаки
---------------------------------------------------------------------------

function Sim:recalcMaxHp(u)
	local old = u.maxHpValue or 0
	local value = (u.baseHp + u.st.maxHp) * (1 + (u.st.maxHpPct + u.grow.maxHpPct) / 100)
	value = math.max(1, math.floor(value + 0.5))
	u.maxHpValue = value
	if u.hp then
		u.hp = math.min(value, u.hp + math.max(0, value - old))
	end
end

function Sim:heal(u, amount, noRepeat)
	if u.dead or amount <= 0 then
		return 0
	end
	if u.st.noHeal > 0 then
		return 0
	end
	local e = self:enemy(u)
	if e.st.healBlock > 0 and self.rng:chance(e.st.healBlock) then
		return 0
	end
	local amp = 1 + self:stat(u, "healAmp") / 100
	local reduce = clamp(e.st.enemyHealReduce, 0, 90) / 100
	local value = (amount + u.st.healFlat) * amp * (1 - reduce)
	if u.falsePromiseUntil and self.t < u.falsePromiseUntil then
		u.fpHeal = (u.fpHeal or 0) + value * (u.fpMul or 2)
		return 0
	end
	local before = u.hp
	u.hp = math.min(u.maxHpValue, u.hp + value)
	local done = u.hp - before
	u.healed = u.healed + done
	u.healedWindow = u.healedWindow + done
	-- Медик: лечение дополнительно наносит урон
	if u.st.healToDamage > 0 and done > 0 then
		self:damage(u, e, done * u.st.healToDamage / 100 * 0.2, "magic", { src = "Медик" })
	end
	-- Накопители «за каждые N вылеченного HP»
	for _, entry in ipairs(u.healAccum) do
		local n = math.floor(u.healed / entry.fx.per)
		while entry.count < n do
			entry.count = entry.count + 1
			self:act(u, entry, entry.fx.a, nil)
		end
	end
	self:fire(u, "heal", { amount = done })
	if not noRepeat then
		if u.st.healRepeat > 0 and self.rng:chance(u.st.healRepeat) then
			self:heal(u, amount, true)
		end
		local lv = u.spec.styleLevels and u.spec.styleLevels.regen or 0
		if lv >= 4 and self.rng:chance(Config.Mastery.regen.chance) then
			self:heal(u, Config.Mastery.regen.value, true)
		end
	end
	return done
end

function Sim:addMana(u, amount)
	if u.dead or amount <= 0 then
		return
	end
	u.mana = math.min(C.ManaMax, u.mana + amount)
	-- Мастерство Ульт: каждые N полученной маны даёт ещё
	local lv = u.spec.styleLevels and u.spec.styleLevels.ulti or 0
	if lv >= 4 then
		u.manaGained = u.manaGained + amount
		local m = Config.Mastery.ulti
		while u.manaGained >= m.per do
			u.manaGained = u.manaGained - m.per
			u.mana = math.min(C.ManaMax, u.mana + m.value)
		end
	end
end

-- Наложить стаки: src — кто накладывает, tgt — на кого
function Sim:applyStack(src, tgt, kind, n, noMastery)
	if n <= 0 or tgt.dead then
		return 0
	end
	local enemyOfTarget = self:enemy(tgt)
	if ENEMY_STACK[kind] then
		-- бонусы накладывающего
		if kind == "poison" then
			n = n + src.st.poisonApply
		elseif kind == "ice" then
			n = n * (1 + src.st.iceApplyPct / 100)
			if tgt.st.iceImmune > 0 then
				return 0
			end
			if tgt.st.iceResist > 0 and self.rng:chance(tgt.st.iceResist) then
				return 0
			end
		elseif kind == "injury" then
			n = n + src.st.injuryApply
			if tgt.st.injuryResist > 0 and self.rng:chance(tgt.st.injuryResist) then
				return 0
			end
		end
		n = n * (1 - clamp(tgt.st.debuffReduce, 0, 90) / 100) - tgt.st.debuffFlatReduce
	else
		if kind == "shield" then
			n = (n + tgt.st.shieldGain) * (1 + tgt.st.shieldGainPct / 100) - enemyOfTarget.st.enemyShieldMinus
			if enemyOfTarget.st.shieldBreak > 0 and self.rng:chance(enemyOfTarget.st.shieldBreak) then
				return 0
			end
		elseif kind == "fury" then
			n = n * (1 + tgt.st.furyGainPct / 100)
			if enemyOfTarget.st.furyDisrupt > 0 and self.rng:chance(enemyOfTarget.st.furyDisrupt) then
				return 0
			end
		end
	end
	n = math.floor(n + 0.5)
	if n <= 0 then
		return 0
	end
	-- Взаимное гашение: Щит <-> Уязвимость, Ярость <-> Заморозка
	local opposite = nil
	if kind == "shield" then
		opposite = "injury"
	elseif kind == "injury" then
		opposite = "shield"
	elseif kind == "fury" then
		opposite = "ice"
	elseif kind == "ice" then
		opposite = "fury"
	end
	local added = n
	if opposite and tgt.stk[opposite] > 0 then
		local cancel = math.min(tgt.stk[opposite], n)
		tgt.stk[opposite] = tgt.stk[opposite] - cancel
		added = n - cancel
	end
	tgt.stk[kind] = tgt.stk[kind] + added
	-- События и накопители
	if ENEMY_STACK[kind] then
		src.applied[kind] = src.applied[kind] + n
		for _, entry in ipairs(src.applyAccum) do
			if entry.fx.stack == kind then
				local c = math.floor(src.applied[kind] / entry.fx.per)
				while entry.count < c do
					entry.count = entry.count + 1
					self:act(src, entry, entry.fx.a, nil)
				end
			end
		end
		self:fire(src, kind, { amount = n })
		HeroKits.call(self, src, "onApply", kind, n)
	elseif kind == "shield" then
		self:fire(tgt, "shieldGain", { amount = n })
	elseif kind == "fury" then
		self:fire(tgt, "furyGain", { amount = n })
	end
	-- Мастер-эффекты стилей: шанс наложить ещё
	if not noMastery then
		local owner = src
		local style = kind
		local lv = owner.spec.styleLevels and owner.spec.styleLevels[style] or 0
		if lv >= 4 then
			local m = Config.Mastery[style]
			if m and m.chance and self.rng:chance(m.chance) then
				self:applyStack(src, tgt, kind, m.value, true)
			end
		end
	end
	return n
end

function Sim:stun(u, dur)
	if u.dead then
		return
	end
	u.stunUntil = math.max(u.stunUntil, self.t + math.min(dur, C.StunMax))
	self:log("stun", u.side, dur)
end

---------------------------------------------------------------------------
-- Стражи
---------------------------------------------------------------------------

function Sim:summonWard(u, hp, opts)
	opts = opts or {}
	local interval = clamp(C.WispInterval + u.st.wardInterval + self:wispMasteryInterval(u), C.WispIntervalMin, 10)
	local w = {
		hp = hp,
		maxHp = hp,
		atk = (opts.atk or C.WispDamage) * (1 + u.st.wardAtkPct / 100),
		interval = interval,
		timer = 0,
		share = opts.share or C.WispShare,
		clone = opts.clone,
	}
	if u.st.wardHpToHero > 0 then
		u.maxHpValue = u.maxHpValue + hp * u.st.wardHpToHero
		u.hp = u.hp + hp * u.st.wardHpToHero
	end
	table.insert(u.wards, w)
	if not u.firstWardMaxHp then
		u.firstWardMaxHp = hp
	end
	self:log("ward", u.side, math.floor(hp), #u.wards)
	return w
end

function Sim:wispMasteryInterval(u)
	local lv = u.spec.styleLevels and u.spec.styleLevels.wisp or 0
	if lv >= 4 then
		return -0.2
	end
	return 0
end

function Sim:aliveWards(u)
	local n = 0
	for _, w in ipairs(u.wards) do
		if w.hp > 0 then
			n = n + 1
		end
	end
	return n
end

function Sim:killWard(u, w)
	w.hp = 0
	self:log("wardDeath", u.side)
	for _, entry in ipairs(u.wardDeathFx) do
		self:act(u, entry, entry.fx.a, { ward = w })
	end
	HeroKits.call(self, u, "onWardDeath", w)
end

---------------------------------------------------------------------------
-- Урон
---------------------------------------------------------------------------

-- o: isAttack, forceCrit, noReflect, src (название источника), noShare
function Sim:damage(src, tgt, amount, dtype, o)
	o = o or {}
	if tgt.dead or amount <= 0 then
		return 0
	end
	local raw = amount
	local isCrit = false
	local evaded = false
	-- Неуязвимость
	if tgt.immuneUntil > self.t then
		return 0
	end
	if dtype == "phys" and tgt.physImmuneUntil > self.t then
		return 0
	end
	-- Блок атаки (Изнашивающий клинок)
	if o.isAttack and tgt.st.blockChance > 0 and self.rng:chance(tgt.st.blockChance) then
		self:log("block", tgt.side)
		return 0
	end
	-- Крит: физический урон (и магический при Манавзрыве)
	local canCrit = (dtype == "phys" and o.noCrit ~= true)
	if dtype == "magic" and src.st.magicCrit > 0 then
		canCrit = true
	end
	if canCrit then
		local chance = self:critChance(src)
		if dtype == "magic" then
			chance = chance * src.st.magicCrit / 100
		end
		if o.forceCrit or self.rng:chance(chance) then
			if tgt.st.critResist > 0 and self.rng:chance(tgt.st.critResist) then
				isCrit = false
			else
				isCrit = true
			end
		end
	end
	if isCrit then
		local mult = (src.critMult + self:stat(src, "critDmg")) / 100
		mult = mult * (1 - clamp(tgt.st.critTakenReduce, 0, 90) / 100)
		amount = amount * math.max(1, mult)
	end
	-- Уклонение: снижает физический урон (и магический при Отклонении)
	local canEvade = (dtype == "phys") or (dtype == "magic" and tgt.st.magicEvade > 0)
	if tgt.st.cannotEvade > 0 then
		canEvade = false
	end
	if canEvade then
		local chance = self:evadeChance(tgt)
		if dtype == "magic" then
			chance = chance * tgt.st.magicEvade / 100
		end
		local forced = (tgt.special.item_elvenskin and o.isAttack and self.t < 4)
		if forced or self.rng:chance(chance) then
			if src.st.ignoreEvade > 0 and self.rng:chance(src.st.ignoreEvade) and not forced then
				evaded = false
			else
				evaded = true
			end
		end
	end
	local prevented = 0
	if evaded then
		local reduce = clamp(C.EvadeReduceBase + self:stat(tgt, "evadeReduce"), 0, C.EvadeReduceMax)
		prevented = amount * reduce / 100
		amount = amount - prevented
	end
	-- Усиления и снижения
	local amp = 1 + self:stat(src, "dmgAmp") / 100
	if dtype == "phys" or dtype == "magic" then
		amp = amp + src.st.physMagicAmp / 100
	end
	if src.st.giantSlayer > 0 and tgt.hp > src.hp then
		amp = amp + src.st.giantSlayer / 100
	end
	if src.special.item_giant_slayer then
		amp = amp + math.floor(tgt.maxHpValue / 600) * 0.02
	end
	if src.special.item_shako then
		amp = amp + math.floor(src.maxHpValue / 500) * 0.01
	end
	-- Черта «Замедление времени» у цели: наш урон снижен в начале боя
	if tgt.st.timeDilation > 0 then
		amp = amp * (1 - math.max(0, tgt.st.timeDilation - math.floor(self.t)) / 100)
	end
	if tgt.special.item_wraith_pact and self.t < 3 and (dtype == "phys" or dtype == "magic") then
		amp = amp * 0.65
	end
	if dtype == "phys" and src.physWeakUntil and self.t < src.physWeakUntil then
		amp = amp * (1 - (src.physWeak or 0) / 100)
	end
	amp = math.max(0.05, amp)
	local reduce = tgt.st.dmgTakenAmp - self:stat(tgt, "dmgReduce")
	if dtype == "phys" then
		reduce = reduce - self:stat(tgt, "physReduce")
	elseif dtype == "magic" then
		reduce = reduce - self:stat(tgt, "magicReduce")
	elseif dtype == "poison" then
		reduce = reduce - tgt.st.poisonResist
	end
	if tgt.special.item_kindle then
		local lostPct = (tgt.maxHpValue - tgt.hp) / tgt.maxHpValue * 100
		reduce = reduce - math.floor(lostPct / 16) * 7
	end
	reduce = math.max(-C.DamageReduceMax, reduce)
	amount = amount * amp * (1 + reduce / 100) * self:overtime()
	-- Уязвимость (+1 урона за стак) и Щит (-1 урона за стак)
	if dtype ~= "poison" then
		local inj = tgt.stk.injury + tgt.perm.injury
		if inj > 0 then
			amount = amount + inj
			local keep = src.st.injuryNoDecay > 0 and self.rng:chance(src.st.injuryNoDecay)
			if not keep and not src.keepInjury then
				tgt.stk.injury = math.floor(tgt.stk.injury * (1 - C.StackDecay))
			end
		end
	end
	if dtype == "phys" or dtype == "magic" then
		local sh = tgt.stk.shield + tgt.perm.shield
		if sh > 0 then
			local absorbed = math.min(amount, sh)
			amount = amount - absorbed
			if not (tgt.strongShieldUntil and self.t < tgt.strongShieldUntil) then
				local before = tgt.stk.shield
				tgt.stk.shield = math.floor(tgt.stk.shield * (1 - C.StackDecay))
				tgt.shieldLost = (tgt.shieldLost or 0) + (before - tgt.stk.shield)
				HeroKits.special(self, tgt, "aphotic_check")
			end
			if absorbed > 0 then
				self:fire(tgt, "shieldBlock", { amount = absorbed })
			end
		end
	end
	if amount <= 0 then
		if o.isAttack then
			self:log("atk", src.side, 0, isCrit and 1 or 0, evaded and 1 or 0)
		end
		return 0
	end
	-- Стражи забирают часть урона
	if dtype ~= "pure" and tgt.st.wardNoShare == 0 and not o.noShare then
		for _, w in ipairs(tgt.wards) do
			if w.hp > 0 then
				local share = amount * w.share / 100
				local wardDmg = share * (1 + src.st.wardDmgPct / 100)
				amount = amount - share
				w.hp = w.hp - wardDmg
				if w.hp <= 0 then
					self:killWard(tgt, w)
				end
				break
			end
		end
	end
	-- Ложное обещание: урон откладывается
	if tgt.falsePromiseUntil and self.t < tgt.falsePromiseUntil then
		tgt.fpDamage = (tgt.fpDamage or 0) + amount
		return amount
	end
	-- Применение
	local before = tgt.hp
	tgt.hp = tgt.hp - amount
	local lostNow = math.min(before, amount)
	tgt.lost = tgt.lost + lostNow
	src.dealt = src.dealt + amount
	if tgt.special.item_martyr then
		tgt.martyrWindow = (tgt.martyrWindow or 0) + amount
	end
	-- Журнал
	if o.isAttack then
		self:log("atk", src.side, math.floor(amount + 0.5), isCrit and 1 or 0, evaded and 1 or 0)
	elseif dtype ~= "poison" then
		self:log("dmg", src.side, math.floor(amount + 0.5), dtype, o.src)
	end
	-- Вампиризм
	local ls = self:stat(src, "lifesteal")
	if ls > 0 and dtype ~= "poison" then
		self:heal(src, amount * ls / 100, true)
	end
	-- Смерть?
	if tgt.hp <= 0 then
		self:onLethal(tgt, src)
	end
	if tgt.dead then
		return amount
	end
	-- Накопители потери HP
	for _, entry in ipairs(tgt.hpLoss) do
		local n = math.floor(tgt.lost / entry.fx.per)
		while entry.count < n do
			entry.count = entry.count + 1
			self:act(tgt, entry, entry.fx.a, nil)
		end
	end
	self:checkBelow(tgt)
	-- События
	if isCrit then
		src.crits = src.crits + 1
		self:fire(src, "crit", { amount = amount })
		HeroKits.call(self, src, "onCrit", amount)
		self:fire(tgt, "critTaken", { amount = amount })
		self:masteryCrit(src)
	end
	if evaded then
		self:fire(tgt, "evade", { raw = raw, prevented = prevented })
		self:masteryEvade(tgt)
	end
	if not o.noReflect then
		self:fire(tgt, "damaged", { amount = amount, dtype = dtype })
		if dtype == "phys" then
			self:fire(tgt, "damagedPhys", { amount = amount })
		end
		self:fire(src, "dealDamage", { amount = amount })
		if amount > 100 then
			self:fire(src, "bigHit", { amount = amount })
		end
		HeroKits.special(self, tgt, "mischief", amount)
	end
	-- Мастерство Здоровья: потеря HP временно повышает макс. HP
	local hlv = tgt.spec.styleLevels and tgt.spec.styleLevels.health or 0
	if hlv >= 4 then
		local m = Config.Mastery.health
		local n = math.floor(tgt.lost / m.healthLoss)
		tgt.giantCount = tgt.giantCount or 0
		while tgt.giantCount < n do
			tgt.giantCount = tgt.giantCount + 1
			tgt.maxHpValue = tgt.maxHpValue + m.value
			tgt.hp = tgt.hp + m.value
		end
	end
	return amount
end

function Sim:masteryCrit(u)
	local lv = u.spec.styleLevels and u.spec.styleLevels.crit or 0
	if lv >= 4 then
		local m = Config.Mastery.crit
		if self.rng:chance(m.chance) then
			local cur = 0
			for _, bf in ipairs(u.buffs) do
				if bf.entry == "masteryCrit" then
					cur = cur + bf.val
				end
			end
			if cur < m.max then
				table.insert(u.buffs, { stat = "critDmg", val = m.value, expire = self.t + m.duration, entry = "masteryCrit" })
			end
		end
	end
end

function Sim:masteryEvade(u)
	local lv = u.spec.styleLevels and u.spec.styleLevels.evade or 0
	if lv >= 4 then
		local m = Config.Mastery.evade
		if self.rng:chance(m.chance) then
			local cur = 0
			for _, bf in ipairs(u.buffs) do
				if bf.entry == "masteryEvade" then
					cur = cur + bf.val
				end
			end
			if cur < m.max then
				table.insert(u.buffs, { stat = "dmgReduce", val = m.value, expire = self.t + m.duration, entry = "masteryEvade" })
			end
		end
	end
end

function Sim:checkBelow(u)
	local pct = u.hp / u.maxHpValue * 100
	for _, entry in ipairs(u.below) do
		if not entry.fired and pct < entry.fx.pct then
			entry.fired = true
			self:act(u, entry, entry.fx.a, nil)
		end
	end
	HeroKits.special(self, u, "below_check", pct)
	HeroKits.call(self, u, "onBelow", pct)
end

-- Смертельный урон: попытка спастись (легендарки, таланты)
function Sim:onLethal(u, killer)
	if HeroKits.preventDeath(self, u) then
		return
	end
	u.hp = 0
	u.dead = true
	self:log("death", u.side)
end

---------------------------------------------------------------------------
-- Атака и ульт
---------------------------------------------------------------------------

function Sim:doAttack(u, ctx)
	local e = self:enemy(u)
	if u.dead or e.dead then
		return
	end
	u.attacks = u.attacks + 1
	local force = false
	if u.forceCrits and u.forceCrits > 0 then
		u.forceCrits = u.forceCrits - 1
		force = true
	end
	if u.special.item_gauntlets and (self.t - (u.lastGauntlet or -10)) >= 4 then
		u.lastGauntlet = self.t
		force = true
	end
	local dmg = self:attackDamage(u)
	dmg = HeroKits.call(self, u, "modifyAttack", dmg) or dmg
	self:damage(u, e, dmg, "phys", { isAttack = true, forceCrit = force })
	if e.dead then
		return
	end
	HeroKits.call(self, u, "onAttack", ctx)
	self:fire(u, "attack", ctx or {})
	-- Мастерство Атаки: шанс получить скорость атаки
	local lv = u.spec.styleLevels and u.spec.styleLevels.attack or 0
	if lv >= 4 then
		local m = Config.Mastery.attack
		if self.rng:chance(m.chance) then
			local cur = 0
			for _, bf in ipairs(u.buffs) do
				if bf.entry == "masteryAttack" then
					cur = cur + bf.val
				end
			end
			if cur < m.max then
				table.insert(u.buffs, { stat = "atkSpeed", val = m.value, expire = self.t + m.duration, entry = "masteryAttack" })
			end
		end
	end
end

function Sim:castUlt(u, bonusMul)
	local e = self:enemy(u)
	if u.dead or e.dead then
		return
	end
	u.ultCount = u.ultCount + 1
	local power = self:ultPower(u) * (bonusMul or 1)
	self:log("ult", u.side, u.ultCount)
	if u.ultFn then
		u.ultFn(self, u, e, power)
	else
		HeroKits.ult(self, u, e, power)
	end
	if u.st.ultStack > 0 then
		u.grow.ultPower = u.grow.ultPower + u.st.ultStack
	end
	self:fire(u, "ult", {})
	self:fire(e, "enemyUlt", {})
	HeroKits.special(self, u, "after_ult")
	if u.st.ultDouble > 0 and not self.inDouble and self.rng:chance(u.st.ultDouble) then
		self.inDouble = true
		self:castUlt(u, bonusMul)
		self.inDouble = false
	end
end

---------------------------------------------------------------------------
-- Тик
---------------------------------------------------------------------------

function Sim:tickUnit(u, dt)
	if u.dead then
		return
	end
	local e = self:enemy(u)
	-- Баффы истекают
	local i = 1
	while i <= #u.buffs do
		if u.buffs[i].expire <= self.t then
			table.remove(u.buffs, i)
		else
			i = i + 1
		end
	end
	local stunned = u.stunUntil > self.t
	-- Мана и ульт
	if not stunned then
		self:addMana(u, self:manaRegen(u) * dt)
		if u.mana >= C.ManaMax and u.silenceUntil <= self.t then
			u.mana = 0
			self:castUlt(u, 1)
			if u.dead or e.dead then
				return
			end
		end
	end
	-- Атака
	if not stunned then
		u.atkTimer = u.atkTimer + dt
		local period = self:attackPeriod(u)
		if u.atkTimer >= period then
			u.atkTimer = u.atkTimer - period
			self:doAttack(u, {})
			if u.dead or e.dead then
				return
			end
		end
	end
	-- Яд на этом юните тикает с интервалом, заданным противником
	local poison = u.stk.poison + u.perm.poison
	if poison > 0 then
		u.poisonTimer = u.poisonTimer + dt
		local interval = clamp(C.PoisonInterval + e.st.poisonInterval, C.PoisonIntervalMin, 5)
		if u.poisonTimer >= interval then
			u.poisonTimer = u.poisonTimer - interval
			local dmg = poison * (1 + e.st.poisonAmp / 100)
			local dealt = self:damage(e, u, dmg, "poison", { src = "Яд" })
			HeroKits.call(self, e, "onPoisonTick", dealt)
			local keep = e.st.poisonNoDecay > 0 and self.rng:chance(e.st.poisonNoDecay)
			if not keep then
				u.stk.poison = math.floor(u.stk.poison * (1 - C.StackDecay))
			end
			if u.dead or e.dead then
				return
			end
		end
	else
		u.poisonTimer = 0
	end
	-- Заморозка и Ярость тают раз в секунду
	u.decayTimer = u.decayTimer + dt
	if u.decayTimer >= C.DecayInterval then
		u.decayTimer = u.decayTimer - C.DecayInterval
		u.stk.ice = math.floor(u.stk.ice * (1 - C.StackDecay))
		u.stk.fury = math.floor(u.stk.fury * (1 - C.StackDecay))
		HeroKits.special(self, u, "per_second")
		HeroKits.call(self, u, "perSecond")
		if u.dead or e.dead then
			return
		end
	end
	-- Периодические эффекты
	for _, entry in ipairs(u.every) do
		entry.timer = entry.timer + dt
		if entry.timer >= entry.period then
			entry.timer = entry.timer - entry.period
			self:act(u, entry, entry.fx.a, nil)
			if u.dead or e.dead then
				return
			end
		end
	end
	-- Стражи
	for _, w in ipairs(u.wards) do
		if w.hp > 0 then
			w.timer = w.timer + dt
			if w.timer >= w.interval then
				w.timer = w.timer - w.interval
				self:damage(u, e, w.atk, "phys", { src = w.clone and "Клон" or "Страж", noCrit = true })
				HeroKits.call(self, u, "onWardAttack", w)
				for _, entry in ipairs(u.wardFx) do
					self:act(u, entry, entry.fx.a, { ward = w })
				end
				if u.dead or e.dead then
					return
				end
			end
		end
	end
	HeroKits.call(self, u, "onTick", dt)
end

function Sim:snapshot()
	local function pack(u)
		return {
			math.floor(math.max(0, u.hp)),
			u.maxHpValue,
			math.floor(u.mana),
			u.stk.poison + u.perm.poison,
			u.stk.ice + u.perm.ice,
			u.stk.fury + u.perm.fury,
			u.stk.shield + u.perm.shield,
			u.stk.injury + u.perm.injury,
			self:aliveWards(u),
		}
	end
	table.insert(self.snaps, { math.floor(self.t * 100 + 0.5) / 100, pack(self.u1), pack(self.u2) })
end

local function startUnit(sim, u)
	sim:recalcMaxHp(u)
	u.hp = u.maxHpValue
	-- Первый страж от стиля Страж
	local wl = u.spec.styleLevels and u.spec.styleLevels.wisp or 0
	if wl >= 1 then
		local hp = C.WispHealth * (1 + u.st.wardHpPct / 100) + u.st.wardHp
		sim:summonWard(u, hp, nil)
	end
	HeroKits.call(sim, u, "init")
	HeroKits.initSpecials(sim, u)
	if u.st.startMana > 0 then
		sim:addMana(u, u.st.startMana)
	end
end

function Engine.simulate(specA, specB, seed, opts)
	opts = opts or {}
	local sim = setmetatable({}, Sim)
	sim.rng = Rng.new(seed or 1)
	sim.t = 0
	sim.depth = 0
	sim.events = {}
	sim.snaps = {}
	sim.u1 = newUnit(specA, 1)
	sim.u2 = newUnit(specB, 2)
	startUnit(sim, sim.u1)
	startUnit(sim, sim.u2)
	-- Враждебные стартовые эффекты (постоянная Заморозка от черты и т.п.)
	for _, u in ipairs({ sim.u1, sim.u2 }) do
		local e = sim:enemy(u)
		if u.st.enemyPermIce > 0 then
			e.perm.ice = e.perm.ice + u.st.enemyPermIce
		end
	end
	-- Стартовые эффекты карт
	for _, u in ipairs({ sim.u1, sim.u2 }) do
		for _, entry in ipairs(u.start) do
			sim:act(u, entry, entry.fx.a, nil)
		end
		HeroKits.special(sim, u, "start")
	end
	sim:snapshot()
	local dt = opts.dt or C.Dt
	local maxTime = opts.maxTime or C.MaxTime
	local snapTimer = 0
	while sim.t < maxTime and not sim.u1.dead and not sim.u2.dead do
		sim.t = sim.t + dt
		-- Порядок ходов в тике случайный (из seed): чередование по чётности
		-- давало бы преимущество одной стороне при кратных интервалах атаки
		local first, second = sim.u1, sim.u2
		if sim.rng:float() < 0.5 then
			first, second = sim.u2, sim.u1
		end
		sim:tickUnit(first, dt)
		sim:tickUnit(second, dt)
		snapTimer = snapTimer + dt
		if snapTimer >= C.SnapshotInterval then
			snapTimer = snapTimer - C.SnapshotInterval
			sim:snapshot()
		end
	end
	sim:snapshot()
	local winner
	if sim.u1.dead and not sim.u2.dead then
		winner = 2
	elseif sim.u2.dead and not sim.u1.dead then
		winner = 1
	else
		-- Ничья или таймаут: решает доля оставшегося HP, затем нанесённый урон
		local p1 = math.max(0, sim.u1.hp) / sim.u1.maxHpValue
		local p2 = math.max(0, sim.u2.hp) / sim.u2.maxHpValue
		if p1 > p2 then
			winner = 1
		elseif p2 > p1 then
			winner = 2
		elseif sim.u1.dealt >= sim.u2.dealt then
			winner = 1
		else
			winner = 2
		end
	end
	return {
		winner = winner,
		time = math.floor(sim.t * 100 + 0.5) / 100,
		log = sim.events,
		snaps = sim.snaps,
		final = {
			{ hp = math.max(0, math.floor(sim.u1.hp)), maxHp = sim.u1.maxHpValue, dealt = math.floor(sim.u1.dealt), ults = sim.u1.ultCount },
			{ hp = math.max(0, math.floor(sim.u2.hp)), maxHp = sim.u2.maxHpValue, dealt = math.floor(sim.u2.dealt), ults = sim.u2.ultCount },
		},
		names = { sim.u1.name, sim.u2.name },
	}
end

-- Для тестов: прямой доступ к внутренностям
Engine._Sim = Sim
Engine._newUnit = newUnit
Engine._startUnit = startUnit
function Engine._newSim(specA, specB, seed)
	local sim = setmetatable({}, Sim)
	sim.rng = Rng.new(seed or 1)
	sim.t = 0
	sim.depth = 0
	sim.events = {}
	sim.snaps = {}
	sim.u1 = newUnit(specA, 1)
	sim.u2 = newUnit(specB, 2)
	startUnit(sim, sim.u1)
	startUnit(sim, sim.u2)
	return sim
end

return Engine
