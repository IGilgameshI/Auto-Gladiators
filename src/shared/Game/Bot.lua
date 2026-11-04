--!nocheck
-- Простой ИИ бота. Использует тот же API GameState, что и игроки,
-- поэтому сервер ничего не «подыгрывает» ботам.
local Config = require(script.Parent.Parent.Config)
local Progression = require(script.Parent.Progression)
local Shop = require(script.Parent.Shop)

local Bot = {}

-- Оценка карты для бота: стили героя и уже прокачанные стили ценнее
local function score(p, card)
	local hero = Config.Heroes[p.heroId]
	local s = 1
	for _, st in ipairs(card.s) do
		for _, hs in ipairs(hero.styles) do
			if hs == st then
				s = s + Config.Bots.OwnStyleBias
			end
		end
		s = s + math.min(3, (p.styleXp[st] or 0) / 4)
	end
	s = s + (p.cards[card.id] or 0) * 0.5
	if card.r == "r" then
		s = s + 1.5
	elseif card.r == "sr" then
		s = s + 3
	end
	return s
end
Bot.score = score

-- Решения в фазе подготовки
function Bot.prep(game, p)
	if not p.alive then
		return
	end
	-- Выборы
	if p.artifactOffer then
		game:pickArtifact(p.id, game.rng:range(1, #p.artifactOffer))
	end
	if p.itemOffer then
		game:pickItem(p.id, game.rng:range(1, #p.itemOffer))
	end
	local guard = 0
	while p.talentOffer and guard < 5 do
		guard = guard + 1
		game:pickTalent(p.id, game.rng:range(1, #p.talentOffer.ids))
	end
	-- Покупки: сначала лучшие карты, держим часть золота под проценты
	local reserve = math.floor(p.gold * Config.Bots.KeepGoldForInterest / 100) * 100
	if game.turn <= 2 then
		reserve = 0
	end
	for _ = 1, 12 do
		local bestSlot, bestScore = nil, 0
		for slot = 1, Config.Shop.Slots do
			local id = p.shop[slot]
			if id then
				local card = Progression.cardsById()[id]
				local price = Shop.price(p, card)
				if p.gold - price >= reserve or (score(p, card) >= 5 and p.gold >= price) then
					local sc = score(p, card)
					if sc > bestScore then
						bestSlot, bestScore = slot, sc
					end
				end
			end
		end
		if bestSlot and bestScore >= 2 then
			game:buy(p.id, bestSlot)
		elseif (p.freeRerolls or 0) > 0 or p.gold >= Config.Bots.RerollWhenGoldAbove then
			if not game:reroll(p.id) then
				break
			end
		else
			break
		end
	end
end

function Bot.vote(game, p)
	game:vote(p.id, game.rng:range(1, #game.territoryChoices))
end

-- Предпочитаем героя по порядку предложений (случайный)
function Bot.pickHero(game, p)
	game:pickHero(p.id, game.rng:range(1, #p.heroOffers))
end

function Bot.pickTrait(game, p)
	game:pickTrait(p.id, game.rng:range(1, #p.traitOffers))
end

return Bot
