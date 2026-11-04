--!nocheck
-- Мета-эффекты: артефакты, черты и территории, которые влияют на
-- экономику и прогресс (не на сам бой). Вызывается из GameState.
local Config = require(script.Parent.Parent.Config)
local Progression = require(script.Parent.Progression)

local Meta = {}

local function hasArt(p, hook)
	local out = {}
	for _, a in ipairs(p.artifacts or {}) do
		if a.hook == hook then
			table.insert(out, a)
		end
	end
	return out
end
Meta.artifactsWith = hasArt

local function addGold(game, p, value, reason)
	if value and value ~= 0 then
		p.gold = math.max(0, p.gold + value)
		game:note(p, (value > 0 and "+" or "") .. math.floor(value) .. " золота: " .. reason)
	end
end
Meta.addGold = addGold

-- Случайный стиль героя (для наград «XP случайного стиля»)
local function randomHeroStyle(game, p)
	local hero = Config.Heroes[p.heroId]
	if hero then
		return game.rng:pick(hero.styles)
	end
	return game.rng:pick(Config.Styles.Order)
end
Meta.randomHeroStyle = randomHeroStyle

---------------------------------------------------------------------------
-- Выбор артефакта: мгновенные эффекты
---------------------------------------------------------------------------
function Meta.onPickArtifact(game, p, art)
	p.mods = p.mods or {}
	local h = art.hook
	if h == "gold_once" then
		addGold(game, p, art.gold, art.name)
	elseif h == "loan" then
		addGold(game, p, art.gold, art.name)
		p.loans = p.loans or {}
		table.insert(p.loans, { minus = art.minus, turnsLeft = art.turnsN })
	elseif h == "fate" then
		addGold(game, p, art.gold, art.name)
		p.mods.rerollPlus = (p.mods.rerollPlus or 0) + art.plus
	elseif h == "style_xp_once" then
		game:addXp(p, randomHeroStyle(game, p), art.xp)
	elseif h == "free_rerolls_once" then
		p.freeRerolls = (p.freeRerolls or 0) + art.count
	elseif h == "tome" then
		p.mods.tomeXp = (p.mods.tomeXp or 0) + art.xp
	elseif h == "random_cards" then
		local n = game.rng:range(art.min, art.max)
		for _ = 1, n do
			game:grantRandomCard(p, nil, art.name)
		end
	elseif h == "level_income" then
		p.mods.levelIncome = (p.mods.levelIncome or 0) + art.per
	elseif h == "income" then
		p.mods.income = (p.mods.income or 0) + art.gold
	elseif h == "win_gold" then
		p.mods.winGold = (p.mods.winGold or 0) + art.gold
	elseif h == "reroll_discount" then
		p.mods.rerollDiscount = (p.mods.rerollDiscount or 0) + art.gold
	elseif h == "courier_heal_once" then
		game:healCourier(p, art.heal)
	elseif h == "lose_next_gold" then
		p.mods.loseNextGold = (p.mods.loseNextGold or 0) + art.gold
	elseif h == "gossamer" then
		p.gossamerLeft = (p.gossamerLeft or 0) + art.count
	elseif h == "duel_grail" then
		p.grail = art.start
	end
	-- Территория «Каменный зал»
	local terr = game.territory
	if terr and terr.artifactGoldPerTurn then
		addGold(game, p, terr.artifactGoldPerTurn * game.turn, terr.name)
	end
end

---------------------------------------------------------------------------
-- Начало хода (после основного дохода)
---------------------------------------------------------------------------
function Meta.onTurnStart(game, p)
	p.mods = p.mods or {}
	local terr = game.territory or {}
	-- Кредиты: уменьшаем счётчик
	for _, loan in ipairs(p.loans or {}) do
		if loan.turnsLeft > 0 then
			loan.turnsLeft = loan.turnsLeft - 1
		end
	end
	for _, a in ipairs(hasArt(p, "free_rerolls_turn")) do
		p.freeRerolls = (p.freeRerolls or 0) + a.count
	end
	for _, a in ipairs(hasArt(p, "phoenix")) do
		if p.courierHp < a.below then
			game:healCourier(p, a.heal)
		end
	end
	for _, a in ipairs(hasArt(p, "reserve")) do
		local n = math.min(a.max or 99, math.floor(p.gold / a.per))
		if n > 0 then
			game:healCourier(p, n)
		end
	end
	for _, a in ipairs(hasArt(p, "low_hp_gold")) do
		if p.courierHp < a.below then
			addGold(game, p, a.gold, a.name)
		end
	end
	for _, a in ipairs(hasArt(p, "style_xp_turn")) do
		game:addXp(p, randomHeroStyle(game, p), a.xp)
	end
	for _, a in ipairs(hasArt(p, "dice")) do
		addGold(game, p, game.rng:range(a.min, a.max), a.name)
	end
	for _, a in ipairs(hasArt(p, "no_streak_gold")) do
		if (p.winStreak or 0) < 4 and (p.loseStreak or 0) < 4 then
			addGold(game, p, a.gold, a.name)
		end
	end
	if p.lootBoxGold and p.lootBoxGold > 0 then
		addGold(game, p, p.lootBoxGold, "Лутбокс")
		p.lootBoxGold = 0
	end
	-- Черта «Знатный род»: карта стиля героя несколько ходов
	if (p.mods.freeHeroCards or 0) > 0 then
		p.mods.freeHeroCards = p.mods.freeHeroCards - 1
		game:grantHeroStyleCard(p, "Знатный род", "n")
	end
	-- Территории
	if terr.heroCardEvery and game.turn % terr.heroCardEvery == 0 then
		game:grantHeroStyleCard(p, terr.name)
	end
	if terr.rareCardEvery and game.turn % terr.rareCardEvery == 0 then
		game:grantRandomCard(p, function(c)
			return c.r == "r"
		end, terr.name, true)
	end
	if terr.chaos and game.chaosRoll then
		addGold(game, p, game.chaosRoll, terr.name)
	end
end

---------------------------------------------------------------------------
-- Покупка карты
---------------------------------------------------------------------------
function Meta.onPurchase(game, p, card, isNew)
	for _, a in ipairs(hasArt(p, "rebate")) do
		addGold(game, p, a.gold, a.name)
	end
	if isNew then
		for _, a in ipairs(hasArt(p, "new_card_gold")) do
			addGold(game, p, a.gold, a.name)
		end
	end
	local terr = game.territory
	if terr and terr.bonusCardChance and game.rng:chance(terr.bonusCardChance) then
		game:grantRandomCard(p, nil, terr.name)
	end
end

---------------------------------------------------------------------------
-- Повышение уровня героя
---------------------------------------------------------------------------
function Meta.onLevelUp(game, p, level)
	p.mods = p.mods or {}
	for _, a in ipairs(hasArt(p, "level_up_gold")) do
		addGold(game, p, level * a.per, a.name)
	end
	for _, a in ipairs(hasArt(p, "latter_rich")) do
		if level == a.level then
			addGold(game, p, a.gold, a.name)
		end
	end
	if (p.mods.levelUpCards or 0) > 0 then
		p.mods.levelUpCards = p.mods.levelUpCards - 1
		game:grantHeroStyleCard(p, "Везунчик")
	end
	local terr = game.territory
	if terr and terr.levelUpCard then
		game:grantHeroStyleCard(p, terr.name)
	end
end

---------------------------------------------------------------------------
-- После боя
---------------------------------------------------------------------------
function Meta.afterBattle(game, p, won, courierDamageDealt)
	for _, a in ipairs(hasArt(p, "battle_rerolls")) do
		p.freeRerolls = (p.freeRerolls or 0) + a.count + (won and a.win or 0)
	end
	for _, a in ipairs(hasArt(p, "battle_xp")) do
		game:addXp(p, randomHeroStyle(game, p), a.xp + (won and a.win or 0))
	end
	if not won then
		for _, a in ipairs(hasArt(p, "lose_xp")) do
			game:addXp(p, randomHeroStyle(game, p), a.xp)
		end
	end
	if won and courierDamageDealt and courierDamageDealt > 0 then
		for _, a in ipairs(hasArt(p, "loot_box")) do
			p.lootBoxGold = (p.lootBoxGold or 0) + courierDamageDealt * a.per
		end
		local terr = game.territory
		if terr and terr.goldPerCourierDamage then
			addGold(game, p, courierDamageDealt * terr.goldPerCourierDamage, terr.name)
		end
	end
	-- Статуя мстителей
	if won and p.lastResult == "lose" then
		for _, a in ipairs(hasArt(p, "statue")) do
			if not p.statueUsed then
				p.statueUsed = true
				game:healCourier(p, a.heal)
			end
		end
	end
	-- Грааль дуэли
	if p.grail then
		if won then
			p.grail = p.grail * 2
			if p.grail >= 320 then
				addGold(game, p, p.grail, "Грааль дуэли")
				p.grail = 40
			end
		else
			addGold(game, p, math.floor(p.grail * 0.5), "Грааль дуэли")
			p.grail = 40
		end
	end
end

---------------------------------------------------------------------------
-- Урон курьеру: модификаторы защиты. Возвращает итоговый урон.
---------------------------------------------------------------------------
function Meta.modifyCourierDamage(game, p, dmg)
	if (p.gossamerLeft or 0) > 0 then
		p.gossamerLeft = p.gossamerLeft - 1
		game:note(p, "Паутинный плащ поглотил урон")
		return 0
	end
	for _, a in ipairs(hasArt(p, "harbor")) do
		if (p.harborReadyTurn or 0) <= game.turn then
			p.harborReadyTurn = game.turn + a.cooldown
			game:note(p, "Гавань сокрытых поглотила урон")
			return 0
		end
	end
	for _, a in ipairs(hasArt(p, "courier_armor")) do
		if dmg >= a.threshold then
			dmg = dmg - a.reduce
		end
	end
	return math.max(0, dmg)
end

-- После потери HP курьером
function Meta.onCourierHurt(game, p, lost)
	if lost <= 0 then
		return
	end
	for _, a in ipairs(hasArt(p, "life_insurance")) do
		addGold(game, p, lost * a.gold, a.name)
	end
	for _, a in ipairs(hasArt(p, "hp_rerolls")) do
		p.freeRerolls = (p.freeRerolls or 0) + lost * a.count
	end
end

-- Попытка спастись от гибели. true — выжил.
function Meta.tryRescue(game, p)
	for _, a in ipairs(hasArt(p, "rescue")) do
		if not p.rescueUsed then
			p.rescueUsed = true
			p.courierHp = 1
			addGold(game, p, a.gold, a.name)
			return true
		end
	end
	return false
end

-- Кто-то выбыл
function Meta.onElimination(game, eliminated)
	local terr = game.territory or {}
	for _, p in ipairs(game.players) do
		if p.alive and p ~= eliminated then
			for _, a in ipairs(hasArt(p, "elim_gold")) do
				addGold(game, p, a.gold, a.name)
			end
			for _, a in ipairs(hasArt(p, "elim_heal")) do
				game:healCourier(p, a.heal)
			end
			if terr.elimGold then
				addGold(game, p, terr.elimGold, terr.name)
			end
		end
	end
end

-- Доп. урон курьеру от победителя
function Meta.extraDamage(p)
	local extra = 0
	for _, a in ipairs(hasArt(p, "extra_damage")) do
		extra = extra + a.value
	end
	return extra
end

---------------------------------------------------------------------------
-- Старт игры: черта и территория
---------------------------------------------------------------------------
function Meta.applyStart(game, p)
	p.mods = p.mods or {}
	local terr = game.territory or {}
	local trait = game:trait(p.traitId)
	if trait and trait.meta then
		local m = trait.meta
		if m.startGold then
			p.gold = p.gold + m.startGold
		end
		if m.income then
			p.mods.income = (p.mods.income or 0) + m.income
		end
		if m.freeHeroCards then
			p.mods.freeHeroCards = m.freeHeroCards
		end
		if m.styleXpReq then
			p.mods.styleXpReq = (p.mods.styleXpReq or 0) + m.styleXpReq
		end
		if m.streakCapBonus then
			p.mods.streakCapBonus = m.streakCapBonus
		end
		if m.noInterest then
			p.mods.noInterest = true
		end
		if m.levelUpCards then
			p.mods.levelUpCards = m.levelUpCards
		end
		if m.incomePerLevel then
			p.mods.incomePerLevel = m.incomePerLevel
		end
		if m.cardDiscount then
			p.mods.cardDiscount = m.cardDiscount
		end
		if m.interestCapPer5Levels then
			p.mods.interestCapPer5Levels = m.interestCapPer5Levels
		end
		if m.startCard then
			game:grantCard(p, m.startCard, trait.name)
		end
	end
	if terr.startGold then
		p.gold = p.gold + terr.startGold
	end
	if terr.heroStyleXpReq then
		p.mods.styleReq = p.mods.styleReq or {}
		local s = randomHeroStyle(game, p)
		p.mods.styleReq[s] = (p.mods.styleReq[s] or 0) + terr.heroStyleXpReq
	end
	if terr.heroStyleStartXp then
		local hero = Config.Heroes[p.heroId]
		for _, s in ipairs(hero.styles) do
			game:addXp(p, s, terr.heroStyleStartXp)
		end
	end
end

return Meta
