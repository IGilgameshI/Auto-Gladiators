--!nocheck
-- Наборы способностей героев (пассив + ульт + таланты) и особые эффекты
-- легендарных карт/предметов/черт, которые не выражаются через DSL.
-- Все числа берутся из Config.Heroes / данных карт.

local Config = require(script.Parent.Parent.Config)

local HeroKits = {}
local Kits = {}

-- Параметры таланта, если он выбран
local function talent(u, id)
	if not (u.spec.talents and u.spec.talents[id]) then
		return nil
	end
	local hero = Config.Heroes[u.heroId]
	if not hero then
		return nil
	end
	for _, list in pairs(hero.talents) do
		for _, t in ipairs(list) do
			if t.id == id then
				return t
			end
		end
	end
	return nil
end
HeroKits.talent = talent

local function hero(u)
	return Config.Heroes[u.heroId]
end

---------------------------------------------------------------------------
-- Нарато: теневой клон-страж, ульт Расенган
---------------------------------------------------------------------------
Kits.narato = {
	init = function(sim, u)
		local p = hero(u).passive
		local hp = p.cloneHp
		local t1 = talent(u, "narato_clone_hp")
		if t1 then
			hp = hp + t1.cloneHp
		end
		hp = hp * (1 + u.st.wardHpPct / 100)
		sim:summonWard(u, hp, { share = p.cloneShare, atk = p.cloneAtk, clone = true })
		local t2 = talent(u, "narato_second_clone")
		if t2 then
			sim:summonWard(u, hp * t2.ratio, { share = p.cloneShare, atk = p.cloneAtk, clone = true })
		end
	end,
	onWardAttack = function(sim, u, w)
		local t = talent(u, "narato_clone_mana")
		if t and w.clone then
			sim:addMana(u, t.mana)
		end
	end,
	onWardDeath = function(sim, u, w)
		local t = talent(u, "narato_sage")
		if t then
			sim:heal(u, u.maxHpValue * t.healPct / 100)
		end
	end,
	ult = function(sim, u, e, power)
		local cfg = hero(u).ult
		local dmg = cfg.dmg
		local t = talent(u, "narato_rasen_dmg")
		if t then
			dmg = dmg + t.dmg
		end
		local clones = 0
		for _, w in ipairs(u.wards) do
			if w.hp > 0 and w.clone then
				clones = clones + 1
			end
		end
		dmg = (dmg + cfg.perClone * clones) * power
		sim:damage(u, e, dmg, "magic", { src = cfg.name })
		local ts = talent(u, "narato_rasenshuriken")
		if ts then
			sim:damage(u, e, dmg * ts.pct / 100, "pure", { src = "Расен-сюрикен" })
		end
		sim:stun(e, cfg.stun)
		if talent(u, "narato_sage") and sim:aliveWards(u) < 3 then
			local p = hero(u).passive
			sim:summonWard(u, p.cloneHp * 0.5, { share = p.cloneShare, atk = p.cloneAtk, clone = true })
		end
	end,
}

---------------------------------------------------------------------------
-- Дзадзке: криты дают Ярость, ульт Чидори
---------------------------------------------------------------------------
Kits.zazke = {
	init = function(sim, u)
		local p = hero(u).passive
		u.baseEvade = u.baseEvade + p.evade
		local t = talent(u, "zazke_crit")
		if t then
			u.st.crit = u.st.crit + t.crit
		end
	end,
	onCrit = function(sim, u)
		local p = hero(u).passive
		sim:applyStack(u, u, "fury", p.fury)
		local t = talent(u, "zazke_amaterasu")
		if t then
			sim:applyStack(u, sim:enemy(u), "poison", t.poison)
		end
	end,
	perSecond = function(sim, u)
		local t = talent(u, "zazke_fury_crit")
		if t then
			local want = math.floor((u.stk.fury + u.perm.fury) / t.per) * t.crit
			local cur = u.kit.furyCrit or 0
			u.grow.crit = u.grow.crit + (want - cur)
			u.kit.furyCrit = want
		end
	end,
	onBelow = function(sim, u, pct)
		local t = talent(u, "zazke_susanoo")
		if t and pct < 30 and not u.once.susanoo then
			u.once.susanoo = true
			sim:applyStack(u, u, "shield", t.shield)
		end
	end,
	ult = function(sim, u, e, power)
		local cfg = hero(u).ult
		local dmg = cfg.dmg
		local t = talent(u, "zazke_chidori_dmg")
		if t then
			dmg = dmg + t.dmg
		end
		dmg = dmg * power
		sim:damage(u, e, dmg, "phys", { forceCrit = true, src = cfg.name })
		local t2 = talent(u, "zazke_double")
		if t2 and not e.dead then
			sim:damage(u, e, dmg * t2.pct / 100, "phys", { forceCrit = true, src = cfg.name })
		end
		sim:applyStack(u, u, "fury", cfg.fury)
	end,
}

---------------------------------------------------------------------------
-- Коку: ульт усиливает атаку, ульт Камехамеха
---------------------------------------------------------------------------
Kits.koku = {
	init = function(sim, u)
		local t = talent(u, "koku_mana")
		if t then
			u.st.manaRegen = u.st.manaRegen + t.manaRegen
		end
		local t2 = talent(u, "koku_ultra")
		if t2 then
			u.st.evade = u.st.evade + t2.evade
			u.st.evadeReduce = u.st.evadeReduce + t2.evadeReduce
		end
	end,
	ult = function(sim, u, e, power)
		local cfg = hero(u).ult
		local p = hero(u).passive
		local dmg = cfg.dmg
		local t = talent(u, "koku_kame_dmg")
		if t then
			dmg = dmg + t.dmg
		end
		dmg = (dmg + sim:attackDamage(u) * cfg.perAtk / 100) * power
		local ts = talent(u, "koku_spirit")
		if ts and u.ultCount % ts.every == 0 then
			dmg = dmg * ts.mul
		end
		sim:damage(u, e, dmg, "magic", { src = cfg.name })
		-- Кровь сайяна
		local mul = 1
		local t2 = talent(u, "koku_saiyan")
		if t2 then
			mul = t2.mul
		end
		u.grow.baseAtk = u.grow.baseAtk + p.atk * mul
		u.grow.atkSpeed = u.grow.atkSpeed + p.as
		local t3 = talent(u, "koku_refund")
		if t3 then
			sim:addMana(u, t3.mana)
		end
	end,
}

---------------------------------------------------------------------------
-- Таффи: резиновое тело, ульт Второй гир
---------------------------------------------------------------------------
Kits.tuffy = {
	init = function(sim, u)
		local p = hero(u).passive
		local reduce = p.reduce
		local t = talent(u, "tuffy_rubber")
		if t then
			reduce = reduce + t.reduce
		end
		u.st.physReduce = u.st.physReduce + reduce
		local t2 = talent(u, "tuffy_meat")
		if t2 then
			u.st.healAmp = u.st.healAmp + t2.healPct
		end
		u.kit.regenTimer = 0
		u.kit.gearTimer = 0
		u.kit.gearUntil = -1
	end,
	onTick = function(sim, u, dt)
		local p = hero(u).passive
		u.kit.regenTimer = u.kit.regenTimer + dt
		if u.kit.regenTimer >= p.interval then
			u.kit.regenTimer = u.kit.regenTimer - p.interval
			sim:heal(u, p.heal)
		end
		if sim.t < u.kit.gearUntil then
			u.kit.gearTimer = u.kit.gearTimer + dt
			if u.kit.gearTimer >= 0.5 then
				u.kit.gearTimer = u.kit.gearTimer - 0.5
				sim:heal(u, hero(u).ult.heal * (u.kit.gearPower or 1))
			end
		end
	end,
	ult = function(sim, u, e, power)
		local cfg = hero(u).ult
		local dur = cfg.dur
		local t = talent(u, "tuffy_gear_dur")
		if t then
			dur = dur + t.dur
		end
		u.kit.gearUntil = sim.t + dur
		u.kit.gearTimer = 0
		u.kit.gearPower = power
		table.insert(u.buffs, { stat = "atkSpeed", val = cfg.as * power, expire = sim.t + dur, entry = "gear" })
		local t3 = talent(u, "tuffy_gear3")
		if t3 then
			sim:damage(u, e, t3.dmg * power, "phys", { src = "Третий гир" })
		end
		local t4 = talent(u, "tuffy_gear4")
		if t4 then
			table.insert(u.buffs, { stat = "dmgAmp", val = t4.pct, expire = sim.t + dur, entry = "gear4" })
		end
	end,
	preventDeath = function(sim, u)
		local t = talent(u, "tuffy_will")
		if t and not u.once.will then
			u.once.will = true
			u.hp = 1
			sim:stun(sim:enemy(u), t.stun)
			sim:log("revive", u.side, 1)
			return true
		end
		return false
	end,
}

---------------------------------------------------------------------------
-- Звуковой Хашира: метки + Уязвимость, ульт взрыв меток
---------------------------------------------------------------------------
Kits.sound_hashira = {
	init = function(sim, u)
		u.kit.marks = 0
	end,
	onAttack = function(sim, u, ctx)
		local p = hero(u).passive
		local max = p.max
		local t = talent(u, "sound_marks")
		if t then
			max = max + t.max
		end
		local add = 1
		local t2 = talent(u, "sound_double")
		if t2 then
			add = t2.marks
		end
		u.kit.marks = math.min(max, u.kit.marks + add)
		local inj = p.injury
		local t3 = talent(u, "sound_injury")
		if t3 then
			inj = inj + t3.injury
		end
		sim:applyStack(u, sim:enemy(u), "injury", inj)
	end,
	ult = function(sim, u, e, power)
		local cfg = hero(u).ult
		local marks = u.kit.marks or 0
		local dmg = (cfg.base + cfg.perMark * marks) * power
		local dtype = "magic"
		if talent(u, "sound_pure") then
			dtype = "pure"
		end
		sim:damage(u, e, dmg, dtype, { src = cfg.name })
		local tp = talent(u, "sound_perm")
		if tp then
			e.perm.injury = e.perm.injury + math.floor(marks / tp.per)
		end
		local keep = 0
		local tk = talent(u, "sound_keep")
		if tk then
			keep = tk.keep
		end
		u.kit.marks = math.floor(marks * keep / 100)
		sim:log("marks", u.side, marks)
	end,
}

---------------------------------------------------------------------------
-- Кровавый Демон: кровотечение (Яд) с вампиризмом, ульт кровавые серпы
---------------------------------------------------------------------------
Kits.blood_demon = {
	onAttack = function(sim, u)
		local p = hero(u).passive
		local n = p.poison
		local t = talent(u, "demon_bleed")
		if t then
			n = n + t.poison
		end
		sim:applyStack(u, sim:enemy(u), "poison", n)
	end,
	onPoisonTick = function(sim, u, dealt)
		if dealt and dealt > 0 then
			local p = hero(u).passive
			local pct = p.lifesteal
			local t = talent(u, "demon_lifesteal")
			if t then
				pct = pct + t.lifesteal
			end
			sim:heal(u, dealt * pct / 100, true)
		end
	end,
	perSecond = function(sim, u)
		local t = talent(u, "demon_regen")
		if t then
			sim:heal(u, u.maxHpValue * t.pct / 100, true)
		end
	end,
	ult = function(sim, u, e, power)
		local cfg = hero(u).ult
		local count = cfg.count
		local t = talent(u, "demon_sickles")
		if t then
			count = count + t.count
		end
		local tx = talent(u, "demon_explode")
		for _ = 1, count do
			if e.dead then
				break
			end
			local dmg = cfg.dmg
			if tx then
				dmg = dmg + (e.stk.poison + e.perm.poison) * tx.pct / 100
			end
			sim:damage(u, e, dmg * power, "magic", { src = cfg.name })
			sim:applyStack(u, e, "poison", cfg.poison * power)
		end
	end,
	preventDeath = function(sim, u)
		local t = talent(u, "demon_immortal")
		if t and not u.once.immortal then
			u.once.immortal = true
			u.hp = u.maxHpValue * t.pct / 100
			sim:log("revive", u.side, math.floor(u.hp))
			return true
		end
		return false
	end,
}

---------------------------------------------------------------------------
-- Общий интерфейс
---------------------------------------------------------------------------

-- Вызов хука набора героя (если он есть) + служебная логика тиков
function HeroKits.call(sim, u, hook, a, b)
	local kit = Kits[u.heroId]
	local result = nil
	if kit and kit[hook] then
		result = kit[hook](sim, u, a, b)
	end
	if hook == "onTick" then
		HeroKits.tickSpecials(sim, u, a)
	end
	return result
end

-- Ульт без набора героя (крипы, призраки)
function HeroKits.ult(sim, u, e, power)
	local kit = Kits[u.heroId]
	if kit and kit.ult then
		return kit.ult(sim, u, e, power)
	end
	local tier = u.spec.creepTier or 1
	local cb = Config.CreepBase
	sim:damage(u, e, (cb.UltDamage + cb.UltDamagePerTier * tier) * power, "magic", { src = "Удар крипа" })
end

-- Подготовка особых эффектов в начале боя
function HeroKits.initSpecials(sim, u)
	local sp = u.special
	if sp.gift_liberation then
		u.forceCrits = 3
	end
	if sp.unseen_blade then
		u.st.atkPct = u.st.atkPct + sp.unseen_blade.vals.v * math.floor(sim:evadeChance(u) / 3)
	end
	if sp.unseen_rage then
		u.st.critDmg = u.st.critDmg + sp.unseen_rage.vals.v * math.floor(sim:evadeChance(u) / 3)
	end
	if sp.overload then
		u.st.manaRegen = u.st.manaRegen + (u.st.ultPower / 10) * sp.overload.vals.v
	end
	if sp.item_claymore then
		u.st.baseAtk = u.st.baseAtk + (u.spec.turn or 0) * sp.item_claymore.vals.v
	end
	if sp.item_soul_booster then
		local add = (u.spec.heroLevel or 0) * sp.item_soul_booster.vals.v
		u.maxHpValue = u.maxHpValue + add
		u.hp = u.hp + add
	end
	if sp.heartstopper then
		u.st.healFlat = u.st.healFlat + 2 * (u.spec.wins or 0)
	end
	if sp.arcane_storm then
		u.arcaneStorm = 0
	end
end

-- Особые эффекты в отдельные моменты боя
function HeroKits.special(sim, u, moment, a)
	local sp = u.special
	local e = sim:enemy(u)
	if moment == "start" then
		if sp.energy_defuser then
			local pct = (e.spec.healthStylePct or 0) * sp.energy_defuser.vals.v / 100
			if pct > 0 then
				local cut = math.floor(e.maxHpValue * pct / 100 / (1 + (e.spec.healthStylePct or 0) / 100))
				e.maxHpValue = math.max(1, e.maxHpValue - cut)
				e.hp = math.min(e.hp, e.maxHpValue)
			end
		end
		if sp.arcane_storm then
			u.arcaneStorm = 1
		end
		if sp.initiative then
			sim:castUlt(u, 1 + sp.initiative.vals.v / 100)
		end
	elseif moment == "after_ult" then
		if sp.arcane_storm then
			u.arcaneStorm = (u.arcaneStorm or 0) + 1
		end
	elseif moment == "per_second" then
		if sp.arcane_storm and (u.arcaneStorm or 0) > 0 then
			sim:damage(u, e, sp.arcane_storm.vals.v * u.arcaneStorm, "magic", { src = "Чародейская буря" })
		end
		if sp.heartstopper then
			local w = u.healedWindow
			u.healedWindow = 0
			if w > 0 then
				sim:damage(u, e, w * sp.heartstopper.vals.v / 100, "magic", { src = "Аура разрыва сердца" })
			end
		else
			u.healedWindow = 0
		end
		if sp.item_martyr and (u.martyrWindow or 0) > 0 then
			local sh = u.martyrWindow * 0.1
			u.martyrWindow = 0
			sim:applyStack(u, u, "shield", sh)
		end
		if u.coldEmbraceUntil and sim.t < u.coldEmbraceUntil then
			sim:heal(u, u.maxHpValue * sp.cold_embrace.vals.v / 100)
		end
		-- Черта «Вулкан»
		if u.st.vulcan > 0 then
			u.hp = math.max(1, u.hp - u.st.vulcan)
			u.lost = u.lost + u.st.vulcan
			sim:applyStack(u, u, "fury", u.st.vulcan)
			sim:damage(u, e, (u.stk.fury + u.perm.fury) * 0.35, "magic", { src = "Вулкан" })
		end
	elseif moment == "below_check" then
		local pct = a
		if sp.false_promise and not u.once.falsePromise and pct < 18 then
			u.once.falsePromise = true
			u.falsePromiseUntil = sim.t + 1.5
			u.fpMul = sp.false_promise.vals.v
			u.fpDamage = 0
			u.fpHeal = 0
			sim:log("special", u.side, "Ложное обещание")
		end
		if sp.cold_embrace and not u.once.coldEmbrace and pct < 25 then
			u.once.coldEmbrace = true
			u.coldEmbraceUntil = sim.t + 3
			u.physImmuneUntil = math.max(u.physImmuneUntil, sim.t + 3)
			u.stunUntil = math.max(u.stunUntil, sim.t + 3)
			sim:log("special", u.side, "Холодные объятия")
		end
	elseif moment == "aphotic_check" then
		if sp.aphotic_shield then
			u.aphoticCount = u.aphoticCount or 0
			local n = math.floor((u.shieldLost or 0) / 200)
			while u.aphoticCount < n do
				u.aphoticCount = u.aphoticCount + 1
				sim:damage(u, e, sp.aphotic_shield.vals.v, "pure", { src = "Мрачный щит" })
				for _, s in ipairs({ "poison", "ice", "injury" }) do
					u.stk[s] = math.floor(u.stk[s] * 0.9)
				end
			end
		end
	elseif moment == "mischief" then
		if sp.mischief and sim.t - (u.lastMischief or -10) >= 0.5 then
			local chance = 8 + 0.2 * sim:evadeChance(u)
			if sim.rng:chance(chance) then
				u.lastMischief = sim.t
				u.immuneUntil = sim.t + sp.mischief.vals.v
			end
		end
	end
end

-- Служебные таймеры особых эффектов (каждый тик)
function HeroKits.tickSpecials(sim, u, dt)
	if u.falsePromiseUntil and sim.t >= u.falsePromiseUntil then
		u.falsePromiseUntil = nil
		local net = (u.fpHeal or 0) - (u.fpDamage or 0)
		u.hp = math.min(u.maxHpValue, u.hp + net)
		sim:log("special", u.side, "Обещание исполнено")
		if u.hp <= 0 then
			sim:onLethal(u, sim:enemy(u))
		end
	end
	if u.tranceUntil and sim.t >= u.tranceUntil then
		u.tranceUntil = nil
		u.silenceUntil = sim.t
	end
end

-- Попытка предотвратить смерть. true — юнит выжил.
function HeroKits.preventDeath(sim, u)
	local sp = u.special
	-- Пока идёт Ложное обещание или Боевой транс — умереть нельзя
	if u.falsePromiseUntil and sim.t < u.falsePromiseUntil then
		u.hp = 1
		return true
	end
	if u.tranceUntil and sim.t < u.tranceUntil then
		u.hp = 1
		return true
	end
	if sp.final_defense and not u.once.finalDefense then
		u.once.finalDefense = true
		u.hp = 1
		u.stk.shield = u.stk.shield + sp.final_defense.vals.v
		u.strongShieldUntil = sim.t + 2.4
		sim:log("revive", u.side, 1, "Последний рубеж")
		return true
	end
	if sp.battle_trance and not u.once.trance then
		u.once.trance = true
		u.hp = 1
		local dur = sp.battle_trance.vals.v
		u.tranceUntil = sim.t + dur
		u.silenceUntil = sim.t + dur
		table.insert(u.buffs, { stat = "atkSpeed", val = 80, expire = sim.t + dur, entry = "trance" })
		table.insert(u.buffs, { stat = "lifesteal", val = 45, expire = sim.t + dur + 2, entry = "trance" })
		sim:log("revive", u.side, 1, "Боевой транс")
		return true
	end
	local kit = Kits[u.heroId]
	if kit and kit.preventDeath and kit.preventDeath(sim, u) then
		return true
	end
	if sp.light_of_faith and not u.once.faith then
		u.once.faith = true
		u.hp = u.maxHpValue * sp.light_of_faith.vals.v / 100
		for _, s in ipairs({ "poison", "ice", "injury" }) do
			u.stk[s] = 0
			u.perm[s] = 0
		end
		sim:log("revive", u.side, math.floor(u.hp), "Свет веры")
		return true
	end
	if sp.supernova and not u.once.supernova then
		u.once.supernova = true
		u.hp = u.maxHpValue * sp.supernova.vals.v / 100
		sim:log("revive", u.side, math.floor(u.hp), "Сверхновая")
		sim:damage(u, sim:enemy(u), 200, "magic", { src = "Сверхновая" })
		return true
	end
	if (u.spec.revives or 0) > (u.revivesUsed or 0) then
		u.revivesUsed = (u.revivesUsed or 0) + 1
		u.hp = u.maxHpValue
		for _, s in ipairs({ "poison", "ice", "injury" }) do
			u.stk[s] = 0
		end
		sim:log("revive", u.side, math.floor(u.hp), "Возрождение")
		return true
	end
	return false
end

HeroKits.Kits = Kits
return HeroKits
