--!nocheck
-- Прогресс героя: опыт стилей, уровни стилей, уровень героя, таланты.
-- Чистый модуль. Состояние игрока p — обычная таблица (см. GameState).
local Config = require(script.Parent.Parent.Config)

local Progression = {}

local CardsById = nil
function Progression.cardsById()
	if not CardsById then
		CardsById = {}
		for _, c in ipairs(Config.Cards) do
			CardsById[c.id] = c
		end
	end
	return CardsById
end

-- Множитель требования опыта для стиля (черты/территория/артефакты)
function Progression.reqMul(p, style)
	local pct = 0
	if p.mods then
		pct = pct + (p.mods.styleXpReq or 0)
		if p.mods.styleReq and p.mods.styleReq[style] then
			pct = pct + p.mods.styleReq[style]
		end
	end
	return math.max(0.3, 1 + pct / 100)
end

-- Порог опыта для уровня lvl (1..4) с учётом множителя
function Progression.levelReq(p, style, lvl)
	local base = Config.Styles.LevelXp[lvl]
	if not base then
		return math.huge
	end
	return math.max(1, math.floor(base * Progression.reqMul(p, style) + 0.5))
end

function Progression.styleLevel(p, style)
	local xp = (p.styleXp and p.styleXp[style]) or 0
	local lvl = 0
	for i = 1, Config.Styles.MaxLevel do
		if xp >= Progression.levelReq(p, style, i) then
			lvl = i
		else
			break
		end
	end
	return lvl
end

function Progression.styleLevels(p)
	local out = {}
	for _, s in ipairs(Config.Styles.Order) do
		out[s] = Progression.styleLevel(p, s)
	end
	return out
end

function Progression.heroLevel(p)
	local total = 0
	for _, s in ipairs(Config.Styles.Order) do
		total = total + Progression.styleLevel(p, s)
	end
	return total
end

function Progression.totalXp(p)
	local total = 0
	for _, s in ipairs(Config.Styles.Order) do
		total = total + ((p.styleXp and p.styleXp[s]) or 0)
	end
	return total
end

-- Опыт стиля за одну звезду карты
function Progression.xpPerStar(p, card)
	local xp = Config.Styles.XpPerStar[card.r] or 1
	if card.r == "r" and p.mods and p.mods.tomeXp then
		xp = xp + p.mods.tomeXp
	end
	return xp
end

-- Добавить опыт стилю. Возвращает список новых уровней героя.
function Progression.addStyleXp(p, style, xp)
	p.styleXp = p.styleXp or {}
	local before = Progression.heroLevel(p)
	p.styleXp[style] = (p.styleXp[style] or 0) + xp
	local after = Progression.heroLevel(p)
	local ups = {}
	for lvl = before + 1, after do
		table.insert(ups, lvl)
	end
	return ups
end

-- Добавить звезду карте (без проверки пула/золота). Возвращает
-- (успех, список новых уровней героя, была ли карта новой).
function Progression.addCardStar(p, cardId)
	local card = Progression.cardsById()[cardId]
	if not card then
		return false, {}, false
	end
	p.cards = p.cards or {}
	local stars = p.cards[cardId] or 0
	if stars >= Config.Shop.MaxStars then
		return false, {}, false
	end
	local isNew = stars == 0
	p.cards[cardId] = stars + 1
	if isNew then
		p.cardOrder = p.cardOrder or {}
		table.insert(p.cardOrder, cardId)
	end
	local ups = {}
	local xp = Progression.xpPerStar(p, card)
	for _, style in ipairs(card.s) do
		local u = Progression.addStyleXp(p, style, xp)
		for _, lvl in ipairs(u) do
			table.insert(ups, lvl)
		end
	end
	table.sort(ups)
	return true, ups, isNew
end

-- Уровни-пороги талантов, которые достигнуты, но талант не выбран
function Progression.pendingTalentLevels(p)
	local lvl = Progression.heroLevel(p)
	local out = {}
	for _, tl in ipairs(Config.Match.TalentLevels) do
		if lvl >= tl and not (p.talentTaken and p.talentTaken[tl]) then
			table.insert(out, tl)
		end
	end
	return out
end

-- Максимальный уровень среди стилей карты (для открытия редкостей)
function Progression.cardStyleLevel(p, card)
	local best = 0
	for _, s in ipairs(card.s) do
		local l = Progression.styleLevel(p, s)
		if l > best then
			best = l
		end
	end
	return best
end

-- HP героя от опыта стилей
function Progression.styleHp(p)
	return Progression.totalXp(p) * Config.Styles.HpPerStyleXp
end

return Progression
