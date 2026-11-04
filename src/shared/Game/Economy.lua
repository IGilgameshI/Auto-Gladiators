--!nocheck
-- Экономика: доход за ход, проценты, урон курьеру. Чистый модуль.
local Config = require(script.Parent.Parent.Config)
local Progression = require(script.Parent.Progression)

local Economy = {}
local E = Config.Economy

-- Проценты: +10 за каждые 100 непотраченного золота, до предела
function Economy.interest(gold, cap)
	cap = cap or E.InterestMax
	local value = math.floor(math.max(0, gold) / E.InterestPer) * E.InterestValue
	return math.min(value, cap)
end

-- Предел процентов для игрока
function Economy.interestCap(game, p)
	local cap = E.InterestMax
	local terr = game and game.territory
	if terr and terr.interestMax then
		cap = terr.interestMax
	end
	if p.mods and p.mods.interestCapPer5Levels then
		cap = cap + p.mods.interestCapPer5Levels * math.floor(Progression.heroLevel(p) / 5)
	end
	return cap
end

-- Доход в начале хода. Возвращает (сумма, разбивка {название = число}).
-- Учитывает результат прошлого боя (p.lastResult = "win"/"lose"/nil).
function Economy.income(game, p)
	local parts = {}
	local terr = game and game.territory or {}
	local turn = game and game.turn or 1
	if terr.flatIncome then
		parts["База (Тёмный риф)"] = terr.flatIncome
		return terr.flatIncome, parts
	end
	local mods = p.mods or {}
	-- База
	local base = E.BaseGold + math.min(turn * E.BaseGoldPerTurn, E.BaseGoldMaxBonus)
	base = base + (mods.income or 0)
	local lvl = Progression.heroLevel(p)
	base = base + (mods.incomePerLevel or 0) * lvl + (mods.levelIncome or 0) * lvl
	if terr.chaos then
		base = base - terr.chaos.minus
	end
	-- Кредиты
	for _, loan in ipairs(p.loans or {}) do
		if loan.turnsLeft > 0 then
			base = base - loan.minus
		end
	end
	parts["База"] = math.max(0, base)
	-- Победа / поражение
	local streakMul = terr.streakMul or 1
	local capBonus = mods.streakCapBonus or 0
	if p.lastResult == "win" then
		local bonus = E.WinBonus + (mods.winGold or 0)
		local streak = math.min((p.winStreak or 0) * E.WinStreakBonus, E.WinStreakBonusMax + capBonus)
		parts["Победа"] = math.floor((bonus + streak) * streakMul)
	elseif p.lastResult == "lose" then
		local comp = E.LoseComp * (terr.loseCompMul or 1)
		local streak = math.min((p.loseStreak or 0) * E.LoseStreakBonus, E.LoseStreakBonusMax + capBonus)
		parts["Поражение"] = math.floor((comp + streak) * streakMul)
		if mods.loseNextGold then
			parts["Знамя"] = mods.loseNextGold
		end
	end
	-- Проценты
	if not mods.noInterest then
		parts["Проценты"] = Economy.interest(p.gold or 0, Economy.interestCap(game, p))
	end
	local total = 0
	for _, v in pairs(parts) do
		total = total + v
	end
	return total, parts
end

-- Урон курьеру проигравшего
function Economy.courierDamage(turn, winnerStreak, winnerLevel, extra)
	local D = Config.CourierDamage
	local dmg = D.Base + math.floor(turn / D.PerTurns) + math.min(winnerStreak or 0, D.StreakMax) + math.floor((winnerLevel or 0) / D.PerHeroLevels) + (extra or 0)
	return math.min(dmg, Economy.damageCap(turn))
end

-- Лимит урона курьеру за ход (растёт с ходами)
function Economy.damageCap(turn)
	local D = Config.CourierDamage
	return math.floor(D.CapBase + turn * D.CapPerTurn)
end

return Economy
