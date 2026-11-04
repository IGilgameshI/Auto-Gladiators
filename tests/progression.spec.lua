local Config = R("shared/Config")
local Progression = R("shared/Game/Progression")

T.suite("Прогресс стилей и героя")

local function newP()
	return { heroId = "koku", cards = {}, cardOrder = {}, styleXp = {}, items = {}, talents = {} }
end

T.test("опыт за звезду: обычная 1, редкая 2, легендарная 4", function()
	local p = newP()
	Progression.addCardStar(p, 4) -- Острый клинок, n, Атака
	T.eq(p.styleXp.attack, 1)
	Progression.addCardStar(p, 13) -- Кровожадный удар, r, Атака
	T.eq(p.styleXp.attack, 3)
	Progression.addCardStar(p, 14) -- Неустанные удары, sr, Атака
	T.eq(p.styleXp.attack, 7)
end)

T.test("карта с двумя стилями даёт опыт обоим", function()
	local p = newP()
	Progression.addCardStar(p, 1) -- Атака/Восст.
	T.eq(p.styleXp.attack, 1)
	T.eq(p.styleXp.regen, 1)
end)

T.test("у карты максимум 5 звёзд", function()
	local p = newP()
	for _ = 1, 5 do
		T.ok(Progression.addCardStar(p, 47))
	end
	T.ok(not Progression.addCardStar(p, 47))
	T.eq(p.cards[47], 5)
end)

T.test("уровень стиля 1..4 по порогам, уровень героя = сумма", function()
	local p = newP()
	local req = Config.Styles.LevelXp
	p.styleXp.attack = req[1]
	T.eq(Progression.styleLevel(p, "attack"), 1)
	p.styleXp.attack = req[4] + 100
	T.eq(Progression.styleLevel(p, "attack"), 4)
	p.styleXp.crit = req[2]
	T.eq(Progression.heroLevel(p), 6)
end)

T.test("черта «Талант к учёбе» снижает требования на 20%", function()
	local p = newP()
	p.mods = { styleXpReq = -20 }
	T.eq(Progression.levelReq(p, "attack", 4), math.floor(Config.Styles.LevelXp[4] * 0.8 + 0.5))
end)

T.test("таланты открываются на 5/10/15 уровнях", function()
	local p = newP()
	p.styleXp.attack = Config.Styles.LevelXp[4]
	p.styleXp.crit = Config.Styles.LevelXp[1]
	T.eq(Progression.heroLevel(p), 5)
	local pend = Progression.pendingTalentLevels(p)
	T.eq(#pend, 1)
	T.eq(pend[1], 5)
	p.talentTaken = { [5] = "x" }
	T.eq(#Progression.pendingTalentLevels(p), 0)
end)

T.test("addStyleXp возвращает новые уровни героя", function()
	local p = newP()
	local ups = Progression.addStyleXp(p, "ice", Config.Styles.LevelXp[2])
	T.eq(#ups, 2)
	T.eq(ups[1], 1)
	T.eq(ups[2], 2)
end)

T.test("HP за опыт стилей", function()
	local p = newP()
	p.styleXp.health = 10
	p.styleXp.ice = 5
	T.eq(Progression.styleHp(p), 15 * Config.Styles.HpPerStyleXp)
end)
