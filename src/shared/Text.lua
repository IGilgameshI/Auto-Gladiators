--!nocheck
-- Форматирование текстов для UI (описания карт со значениями звезды и т.п.)
local Config = require(script.Parent.Config)
local Engine = require(script.Parent.Combat.Engine)

local Text = {}

local RARITY_NAME = { n = "Обычная", r = "Редкая", sr = "Легендарная" }
local RARITY_COLOR = { n = { 200, 200, 200 }, r = { 80, 160, 255 }, sr = { 255, 170, 40 } }
Text.RarityName = RARITY_NAME
Text.RarityColor = RARITY_COLOR

local function fmt(x)
	if type(x) ~= "number" then
		return tostring(x)
	end
	if x == math.floor(x) then
		return tostring(math.floor(x))
	end
	return string.format("%.1f", x)
end
Text.num = fmt

-- Описание карты на конкретной звезде (1..5)
function Text.cardDesc(card, star)
	star = math.max(1, star or 1)
	local v = Engine.starValue(card.v, star)
	local v2 = Engine.starValue(card.v2, star)
	local s = card.desc:gsub("{v2}", fmt(v2))
	s = s:gsub("{v}", fmt(v))
	return s
end

-- Строка значений по всем звёздам: «10/20/30/40/60»
function Text.cardValues(card)
	if card.v == nil then
		return ""
	end
	local parts = {}
	for star = 1, Config.Shop.MaxStars do
		parts[star] = fmt(Engine.starValue(card.v, star))
	end
	return table.concat(parts, "/")
end

function Text.styleNames(card)
	local names = {}
	for i, s in ipairs(card.s) do
		names[i] = Config.Styles.Data[s].name
	end
	return table.concat(names, " / ")
end

function Text.stars(n, max)
	max = max or Config.Shop.MaxStars
	return string.rep("★", n) .. string.rep("☆", math.max(0, max - n))
end

-- Описание пассивки/ульта героя с подстановкой чисел из конфига
function Text.heroText(tbl)
	local s = tbl.desc or ""
	return (s:gsub("{(%w+)}", function(key)
		local v = tbl[key]
		if v == nil then
			return "{" .. key .. "}"
		end
		return fmt(v)
	end))
end

-- Название события журнала боя
local DTYPE = { phys = "физ.", magic = "маг.", pure = "чист.", poison = "яд" }
Text.DamageType = DTYPE

function Text.phaseName(phase)
	local names = {
		lobby = "Лобби",
		vote = "Голосование за территорию",
		hero = "Выбор гладиатора",
		trait = "Выбор черты",
		prep = "Подготовка",
		pairing = "Выбор соперника",
		battle = "Бой",
		results = "Итоги хода",
		over = "Конец игры",
	}
	return names[phase] or phase
end

return Text
