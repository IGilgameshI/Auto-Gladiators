--!nocheck
-- Сборка спецификации бойца для Engine.simulate из состояния игрока.
--
-- Формат спецификации:
--   name, heroId, base = {hp, atk, interval, crit, critMult, evade, manaRegen}
--   stats      — пассивные статы (ключ -> число), складываются
--   sources    — { {def = карта/предмет/крип, star = 1..5}, ... }
--   styleLevels, styleXp, talents (id -> true), heroLevel, turn, wins
--   healthStylePct — бонус стиля Здоровье, % (для «Гасителя энергии»)
--   creepTier  — у крипов (для их ульта)

local Config = require(script.Parent.Parent.Config)
local Progression = require(script.Parent.Parent.Game.Progression)

local Builder = {}

local ItemsById, TraitsById = nil, nil
local function index()
	if ItemsById then
		return
	end
	ItemsById, TraitsById = {}, {}
	for _, it in ipairs(Config.Items) do
		ItemsById[it.id] = it
	end
	for _, t in ipairs(Config.Traits) do
		TraitsById[t.id] = t
	end
end

local function add(stats, key, value)
	if value and value ~= 0 then
		stats[key] = (stats[key] or 0) + value
	end
end

-- Бонусы стилей по уровням
function Builder.styleStats(stats, levels)
	for _, style in ipairs(Config.Styles.Order) do
		local lvl = levels[style] or 0
		if lvl > 0 then
			local data = Config.Styles.Data[style]
			for key, arr in pairs(data.bonus) do
				add(stats, key, arr[math.min(lvl, #arr)])
			end
		end
	end
end

-- Модификаторы черты для боя
function Builder.traitStats(stats, trait, heroLevel, gold)
	if not (trait and trait.battle) then
		return
	end
	local b = trait.battle
	add(stats, "maxHpPct", b.maxHpPct)
	add(stats, "lifesteal", b.lifesteal)
	add(stats, "dmgAmp", b.dmgAmp)
	add(stats, "dmgTakenAmp", b.dmgTakenAmp)
	add(stats, "physReduce", b.physReduce)
	add(stats, "magicReduce", b.magicReduce)
	add(stats, "noHeal", b.noHeal)
	add(stats, "atkSpeedMul", b.atkSpeedMul)
	add(stats, "atkPct", b.atkPct)
	add(stats, "shieldGainPct", b.shieldGainPct)
	add(stats, "shieldToAtk", b.shieldToAtk)
	add(stats, "atkSpeed", b.atkSpeed)
	add(stats, "crit", b.crit)
	add(stats, "critDmg", b.critDmg)
	add(stats, "ignoreEvade", b.ignoreEvade)
	add(stats, "healAmp", b.healAmp)
	add(stats, "healToDamage", b.healToDamage)
	add(stats, "giantSlayer", b.giantSlayer)
	add(stats, "startMana", b.startMana)
	add(stats, "cannotEvade", b.cannotEvade)
	add(stats, "wardNoShare", b.wardNoShare)
	add(stats, "wardInterval", b.wardInterval)
	add(stats, "wardHpToHero", b.wardHpToHero)
	add(stats, "poisonAmp", b.poisonAmp)
	add(stats, "physMagicAmp", b.physMagicAmp)
	add(stats, "iceImmune", b.iceImmune)
	add(stats, "furyGainPct", b.furyGainPct)
	add(stats, "enemyPermIce", b.enemyPermIce)
	add(stats, "timeDilation", b.timeDilation)
	add(stats, "manaRegenPct", b.manaRegenPct)
	add(stats, "ultStack", b.ultStack)
	add(stats, "vulcan", b.vulcan)
	if b.atkSpeedPerLevel then
		add(stats, "atkSpeed", b.atkSpeedPerLevel * heroLevel)
	end
	if b.atkPerLevel then
		add(stats, "baseAtk", b.atkPerLevel * heroLevel)
	end
	if b.ultPerLevel then
		add(stats, "ultPower", math.min(150, b.ultPerLevel * heroLevel))
	end
	if b.dmgPerLevel then
		add(stats, "dmgAmp", b.dmgPerLevel * heroLevel)
	end
	if b.dmgPerGold100 then
		add(stats, "dmgAmp", b.dmgPerGold100 * math.floor((gold or 0) / 100))
	end
end

-- Спецификация героя игрока
-- p: heroId, cards, cardOrder, styleXp, items, talents, traitId, turn, wins,
--    gold, battleMods (разовые модификаторы следующего боя)
function Builder.fromPlayer(p)
	index()
	local hero = Config.Heroes[p.heroId]
	assert(hero, "неизвестный герой: " .. tostring(p.heroId))
	local levels = Progression.styleLevels(p)
	local heroLevel = Progression.heroLevel(p)
	local stats = {}
	Builder.styleStats(stats, levels)
	add(stats, "maxHp", Progression.styleHp(p))
	local trait = p.traitId and TraitsById[p.traitId]
	Builder.traitStats(stats, trait, heroLevel, p.gold)
	for key, value in pairs(p.battleMods or {}) do
		add(stats, key, value)
	end
	local sources = {}
	-- Карты в порядке изучения (детерминированно)
	for _, cardId in ipairs(p.cardOrder or {}) do
		local stars = p.cards[cardId]
		local def = Progression.cardsById()[cardId]
		if def and stars and stars > 0 then
			table.insert(sources, { def = def, star = stars, kind = "card" })
		end
	end
	for _, itemId in ipairs(p.items or {}) do
		local def = ItemsById[itemId]
		if def then
			table.insert(sources, { def = def, star = 1, kind = "item" })
		end
	end
	local healthPct = 0
	if levels.health > 0 then
		local arr = Config.Styles.Data.health.bonus.maxHpPct
		healthPct = arr[math.min(levels.health, #arr)]
	end
	return {
		name = p.name or hero.name,
		heroId = p.heroId,
		base = {
			hp = hero.hp,
			atk = hero.atk,
			interval = hero.interval,
			crit = hero.crit,
			critMult = hero.critMult,
			evade = hero.evade,
			manaRegen = hero.manaRegen,
		},
		stats = stats,
		sources = sources,
		styleLevels = levels,
		styleXp = p.styleXp or {},
		talents = p.talents or {},
		heroLevel = heroLevel,
		turn = p.turn or 0,
		wins = p.wins or 0,
		healthStylePct = healthPct,
		revives = p.revives or 0,
	}
end

-- Спецификация крипа
function Builder.fromCreep(creep, tier)
	tier = tier or creep.tier or 1
	local cb = Config.CreepBase
	local lvl = cb.StyleLevelByTier[tier] or 2
	local levels = {}
	for _, s in ipairs(Config.Styles.Order) do
		levels[s] = 0
	end
	levels[creep.style] = lvl
	local stats = {}
	Builder.styleStats(stats, levels)
	return {
		name = creep.name,
		creepId = creep.id,
		creepTier = tier,
		base = {
			hp = math.floor(creep.hp * (cb.HpMulByTier[tier] or 1)),
			atk = creep.atk * (cb.AtkMulByTier[tier] or 1),
			interval = cb.Interval,
			crit = cb.Crit,
			critMult = cb.CritMult,
			evade = cb.Evade,
			manaRegen = cb.ManaRegen,
		},
		stats = stats,
		sources = { { def = creep, star = 1, kind = "creep" } },
		styleLevels = levels,
		styleXp = {},
		talents = {},
		heroLevel = cb.HeroLevelByTier[tier] or 6,
		turn = 0,
		wins = 0,
		healthStylePct = 0,
	}
end

return Builder
