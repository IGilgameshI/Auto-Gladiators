local Config = R("shared/Config")
local Economy = R("shared/Game/Economy")

T.suite("Экономика")

local function newP(gold)
	return { heroId = "koku", cards = {}, cardOrder = {}, styleXp = {}, gold = gold or 0, mods = {} }
end

T.test("проценты: +10 за каждые 100, максимум +100", function()
	T.eq(Economy.interest(0), 0)
	T.eq(Economy.interest(99), 0)
	T.eq(Economy.interest(100), 10)
	T.eq(Economy.interest(550), 50)
	T.eq(Economy.interest(1000), 100)
	T.eq(Economy.interest(5000), 100)
end)

T.test("доход: база + бонус за победу + проценты", function()
	local g = { turn = 3 }
	local p = newP(300)
	p.lastResult = "win"
	p.winStreak = 2
	local total, parts = Economy.income(g, p)
	local E = Config.Economy
	local base = E.BaseGold + 3 * E.BaseGoldPerTurn
	T.eq(parts["База"], base)
	T.eq(parts["Победа"], E.WinBonus + 2 * E.WinStreakBonus)
	T.eq(parts["Проценты"], 30)
	T.eq(total, base + E.WinBonus + 2 * E.WinStreakBonus + 30)
end)

T.test("доход: компенсация за поражение", function()
	local p = newP(0)
	p.lastResult = "lose"
	p.loseStreak = 1
	local _, parts = Economy.income({ turn = 2 }, p)
	T.eq(parts["Поражение"], Config.Economy.LoseComp + Config.Economy.LoseStreakBonus)
	T.eq(parts["Победа"], nil)
end)

T.test("территория «Тёмный риф»: ровно 80 золота", function()
	local p = newP(900)
	p.lastResult = "win"
	local total = Economy.income({ turn = 5, territory = { flatIncome = 80 } }, p)
	T.eq(total, 80)
end)

T.test("черта без процентов", function()
	local p = newP(900)
	p.mods.noInterest = true
	local _, parts = Economy.income({ turn = 2 }, p)
	T.eq(parts["Проценты"], nil)
end)

T.test("кредит уменьшает базовый доход", function()
	local p = newP(0)
	p.loans = { { minus = 50, turnsLeft = 3 } }
	local _, parts = Economy.income({ turn = 1 }, p)
	T.eq(parts["База"], Config.Economy.BaseGold + Config.Economy.BaseGoldPerTurn - 50)
end)

T.test("урон курьеру: 2 + ход/10 + серия (до 4) + уровень/5, с лимитом", function()
	-- ход 1: 2 + 0 + 1 + 0 = 3, лимит 5
	T.eq(Economy.courierDamage(1, 1, 0), 3)
	-- ход 12: 2 + 1 + 4 + 2 = 9, лимит 5 + 6 = 11
	T.eq(Economy.courierDamage(12, 7, 10), 9)
	-- ход 4, огромный уровень: упираемся в лимит 5 + 2 = 7
	T.eq(Economy.courierDamage(4, 4, 30), 7)
	T.eq(Economy.damageCap(20), 15)
end)
