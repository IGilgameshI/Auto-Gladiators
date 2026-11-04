local Config = R("shared/Config")
local Engine = R("shared/Combat/Engine")
local Builder = R("shared/Combat/Builder")
local Progression = R("shared/Game/Progression")

T.suite("Движок боя")

-- Простой «манекен» без набора героя
local function dummy(over)
	local spec = {
		name = "Манекен",
		base = { hp = 1000, atk = 20, interval = 1, crit = 0, critMult = 150, evade = 0, manaRegen = 0 },
		stats = {},
		sources = {},
		styleLevels = {},
		styleXp = {},
		talents = {},
		heroLevel = 0,
	}
	for k, v in pairs(over or {}) do
		if k == "base" then
			for bk, bv in pairs(v) do
				spec.base[bk] = bv
			end
		else
			spec[k] = v
		end
	end
	return spec
end

local function card(id)
	return Progression.cardsById()[id]
end

local function player(heroId, cards)
	local p = { heroId = heroId, cards = {}, cardOrder = {}, styleXp = {}, items = {}, talents = {} }
	for id, stars in pairs(cards or {}) do
		for _ = 1, stars do
			Progression.addCardStar(p, id)
		end
	end
	return p
end

T.test("детерминизм: одинаковый seed — одинаковый бой", function()
	local a = Builder.fromPlayer(player("zazke", { [33] = 3, [124] = 2 }))
	local b = Builder.fromPlayer(player("blood_demon", { [82] = 3, [2] = 2 }))
	local r1 = Engine.simulate(a, b, 12345)
	local r2 = Engine.simulate(a, b, 12345)
	T.eq(r1.winner, r2.winner)
	T.eq(r1.time, r2.time)
	T.eq(#r1.log, #r2.log)
	for i = 1, #r1.log do
		for j = 1, 6 do
			T.eq(r1.log[i][j], r2.log[i][j], "событие " .. i)
		end
	end
	T.eq(r1.final[1].hp, r2.final[1].hp)
	T.eq(r1.final[2].hp, r2.final[2].hp)
end)

T.test("бой всегда заканчивается и есть победитель", function()
	for seed = 1, 20 do
		local ids = Config.HeroOrder
		local a = Builder.fromPlayer(player(ids[(seed % 6) + 1]))
		local b = Builder.fromPlayer(player(ids[((seed + 2) % 6) + 1]))
		local r = Engine.simulate(a, b, seed)
		T.ok(r.winner == 1 or r.winner == 2)
		T.ok(r.time <= Config.Combat.MaxTime + 0.1)
	end
end)

T.test("сверхурочное время: урон растёт после 20 сек на 6%/сек", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	sim.t = 10
	T.near(sim:overtime(), 1)
	sim.t = 30
	T.near(sim:overtime(), 1 + 10 * 0.06)
end)

T.test("Щит снижает урон на число стаков и тает на 30%", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	local u1, u2 = sim.u1, sim.u2
	u2.stk.shield = 10
	local dealt = sim:damage(u1, u2, 50, "magic", {})
	T.near(dealt, 40)
	T.eq(u2.stk.shield, 7)
end)

T.test("Уязвимость добавляет урон и тает на 30%", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	local u1, u2 = sim.u1, sim.u2
	u2.stk.injury = 20
	local dealt = sim:damage(u1, u2, 50, "magic", {})
	T.near(dealt, 70)
	T.eq(u2.stk.injury, 14)
end)

T.test("чистый урон игнорирует Щит", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	sim.u2.stk.shield = 100
	T.near(sim:damage(sim.u1, sim.u2, 50, "pure", {}), 50)
end)

T.test("Щит и Уязвимость гасят друг друга", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	local u1, u2 = sim.u1, sim.u2
	u2.stk.injury = 30
	sim:applyStack(u2, u2, "shield", 20)
	T.eq(u2.stk.injury, 10)
	T.eq(u2.stk.shield, 0)
	sim:applyStack(u2, u2, "shield", 25)
	T.eq(u2.stk.injury, 0)
	T.eq(u2.stk.shield, 15)
end)

T.test("Ярость и Заморозка гасят друг друга", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	local u1, u2 = sim.u1, sim.u2
	u2.stk.fury = 50
	sim:applyStack(u1, u2, "ice", 30)
	T.eq(u2.stk.fury, 20)
	T.eq(u2.stk.ice, 0)
end)

T.test("Ярость ускоряет атаку, Заморозка замедляет", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	local u = sim.u1
	local base = sim:attackPeriod(u)
	u.stk.fury = 100
	T.near(sim:attackPeriod(u), base / 2, 1e-6)
	u.stk.fury = 0
	u.stk.ice = 50
	T.near(sim:attackPeriod(u), base / 0.5, 1e-6)
end)

T.test("Яд тикает по 1 урону за стак и тает на 30%", function()
	local sim = Engine._newSim(dummy(), dummy({ base = { atk = 0 } }), 1)
	local u1 = sim.u1
	u1.stk.poison = 100
	local hp0 = u1.hp
	-- Тикаем только юнит 1 ровно до первого тика яда
	for _ = 1, 20 do
		sim.t = sim.t + 0.05
		u1.atkTimer = -100 -- не атакуем
		sim:tickUnit(u1, 0.05)
	end
	T.near(hp0 - u1.hp, 100, 1e-6)
	T.eq(u1.stk.poison, 70)
end)

T.test("Заморозка и Ярость тают на 30% в секунду", function()
	local sim = Engine._newSim(dummy(), dummy(), 1)
	local u = sim.u1
	u.stk.ice = 100
	for _ = 1, 20 do
		sim.t = sim.t + 0.05
		u.atkTimer = -100
		sim:tickUnit(u, 0.05)
	end
	T.eq(u.stk.ice, 70)
end)

T.test("ульт срабатывает при полной мане и обнуляет её", function()
	local a = Builder.fromPlayer(player("koku"))
	local b = dummy({ base = { hp = 100000, atk = 0 } })
	local sim = Engine._newSim(a, b, 3)
	local u = sim.u1
	u.mana = 99.9
	sim.t = 0.05
	sim:tickUnit(u, 0.05)
	T.eq(u.ultCount, 1)
	T.ok(u.mana < 5)
end)

T.test("крит возможен только для физического урона", function()
	local a = dummy({ base = { crit = 100 } })
	local sim = Engine._newSim(a, dummy(), 1)
	T.near(sim:damage(sim.u1, sim.u2, 100, "magic", {}), 100)
	T.near(sim:damage(sim.u1, sim.u2, 100, "phys", {}), 150)
	T.near(sim:damage(sim.u1, sim.u2, 100, "pure", {}), 100)
end)

T.test("уклонение снижает физический урон, чистый не уклоняется", function()
	local b = dummy({ base = { evade = 75 } })
	local sim = Engine._newSim(dummy(), b, 5)
	local evadedPhys = 0
	for _ = 1, 200 do
		local d = sim:damage(sim.u1, sim.u2, 100, "phys", {})
		if d < 100 then
			evadedPhys = evadedPhys + 1
			T.near(d, 100 * (1 - Config.Combat.EvadeReduceBase / 100))
		end
		sim.u2.hp = sim.u2.maxHpValue
	end
	T.ok(evadedPhys > 100, "уклонений " .. evadedPhys)
	for _ = 1, 50 do
		T.near(sim:damage(sim.u1, sim.u2, 100, "pure", {}), 100)
		sim.u2.hp = sim.u2.maxHpValue
	end
end)

T.test("страж забирает долю урона героя", function()
	local spec = dummy({ styleLevels = { wisp = 1 } })
	local sim = Engine._newSim(dummy(), spec, 1)
	T.eq(#sim.u2.wards, 1)
	local w = sim.u2.wards[1]
	local hp0 = w.hp
	local dealt = sim:damage(sim.u1, sim.u2, 100, "magic", {})
	T.near(dealt, 100 * (1 - Config.Combat.WispShare / 100))
	T.near(hp0 - w.hp, 100 * Config.Combat.WispShare / 100)
end)

T.test("теневой клон Нарато появляется и делит урон", function()
	local a = Builder.fromPlayer(player("narato"))
	local sim = Engine._newSim(a, dummy(), 1)
	T.eq(#sim.u1.wards, 1)
	T.ok(sim.u1.wards[1].clone)
	T.eq(sim.u1.wards[1].share, Config.Heroes.narato.passive.cloneShare)
end)

T.test("звуковые метки Хаширы копятся и взрываются ультом", function()
	local a = Builder.fromPlayer(player("sound_hashira"))
	local sim = Engine._newSim(a, dummy({ base = { hp = 100000 } }), 1)
	for _ = 1, 5 do
		sim:doAttack(sim.u1, {})
	end
	T.eq(sim.u1.kit.marks, 5)
	T.ok(sim.u2.stk.injury > 0)
	sim:castUlt(sim.u1, 1)
	T.eq(sim.u1.kit.marks, 0)
end)

T.test("карта-триггер: Ядовитый удар накладывает яд при атаке", function()
	local p = player("koku", { [2] = 5 })
	local a = Builder.fromPlayer(p)
	local sim = Engine._newSim(a, dummy({ base = { hp = 100000 } }), 2)
	for _ = 1, 30 do
		sim:doAttack(sim.u1, {})
	end
	T.ok(sim.u2.stk.poison > 0)
end)

T.test("карта-стат: Крепкое тело увеличивает HP", function()
	local base = Builder.fromPlayer(player("tuffy"))
	local withCard = Builder.fromPlayer(player("tuffy", { [47] = 2 }))
	local s1 = Engine._newSim(base, dummy(), 1)
	local s2 = Engine._newSim(withCard, dummy(), 1)
	T.ok(s2.u1.maxHpValue > s1.u1.maxHpValue + 200)
end)

T.test("легендарка Свет веры воскрешает один раз", function()
	local p = player("tuffy", { [58] = 1 })
	local sim = Engine._newSim(Builder.fromPlayer(p), dummy(), 1)
	local u = sim.u1
	sim:damage(sim.u2, u, 1e6, "pure", {})
	T.ok(not u.dead)
	T.ok(u.hp > 0)
	sim:damage(sim.u2, u, 1e6, "pure", {})
	T.ok(u.dead)
end)

T.test("значения по звёздам: 3 значения раскладываются на 5", function()
	T.eq(Engine.starValue({ 10, 20, 40 }, 1), 10)
	T.eq(Engine.starValue({ 10, 20, 40 }, 2), 15)
	T.eq(Engine.starValue({ 10, 20, 40 }, 3), 20)
	T.eq(Engine.starValue({ 10, 20, 40 }, 5), 40)
	T.eq(Engine.starValue({ 1, 2, 3, 4, 6 }, 5), 6)
	T.eq(Engine.starValue(7, 3), 7)
end)

T.test("все 150 карт проходят бой на 5 звёздах без ошибок", function()
	local opponents = { "narato", "zazke", "koku", "tuffy", "sound_hashira", "blood_demon" }
	for i, c in ipairs(Config.Cards) do
		local p = player(opponents[(i % 6) + 1], { [c.id] = 5 })
		local q = player(opponents[((i + 3) % 6) + 1], { [Config.Cards[((i * 7) % 150) + 1].id] = 5 })
		local r = Engine.simulate(Builder.fromPlayer(p), Builder.fromPlayer(q), i)
		T.ok(r.winner == 1 or r.winner == 2, "карта " .. c.id)
	end
end)

T.test("все предметы и крипы проходят бой без ошибок", function()
	for i, it in ipairs(Config.Items) do
		local p = player("zazke")
		p.items = { it.id }
		local creep = Config.Creeps[(i % #Config.Creeps) + 1]
		local r = Engine.simulate(Builder.fromPlayer(p), Builder.fromCreep(creep), i)
		T.ok(r.winner == 1 or r.winner == 2, "предмет " .. it.id)
	end
end)

T.test("все черты и таланты проходят бой без ошибок", function()
	local i = 0
	for _, heroId in ipairs(Config.HeroOrder) do
		for _, lvl in ipairs(Config.Match.TalentLevels) do
			for _, t in ipairs(Config.Heroes[heroId].talents[lvl]) do
				i = i + 1
				local trait = Config.Traits[(i % #Config.Traits) + 1]
				local p = player(heroId, { [33] = 2, [116] = 1, [129] = 2 })
				p.talents = { [t.id] = true }
				p.traitId = trait.id
				local q = player(Config.HeroOrder[(i % 6) + 1], { [59] = 3 })
				local r = Engine.simulate(Builder.fromPlayer(p), Builder.fromPlayer(q), i)
				T.ok(r.winner == 1 or r.winner == 2, t.id)
			end
		end
	end
end)

T.test("баланс стартовых героев: никто не выигрывает 100% зеркальных стартов", function()
	local wins = {}
	for _, a in ipairs(Config.HeroOrder) do
		wins[a] = 0
	end
	local games = 0
	for _, a in ipairs(Config.HeroOrder) do
		for _, b in ipairs(Config.HeroOrder) do
			if a ~= b then
				for seed = 1, 6 do
					local r = Engine.simulate(Builder.fromPlayer(player(a)), Builder.fromPlayer(player(b)), seed * 31)
					local w = (r.winner == 1) and a or b
					wins[w] = wins[w] + 1
					games = games + 1
				end
			end
		end
	end
	local line = {}
	for _, a in ipairs(Config.HeroOrder) do
		table.insert(line, a .. "=" .. wins[a])
		-- каждый герой играет 60 боёв; не должно быть 0 или 60
		T.ok(wins[a] > 3 and wins[a] < 57, "дисбаланс: " .. a .. " " .. wins[a])
	end
	print("       победы стартовых героев: " .. table.concat(line, " "))
end)
