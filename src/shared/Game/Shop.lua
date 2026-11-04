--!nocheck
-- Общий ограниченный пул карт и магазин игрока. Чистый модуль.
local Config = require(script.Parent.Parent.Config)
local Progression = require(script.Parent.Progression)

local Shop = {}

---------------------------------------------------------------------------
-- Пул: cardId -> сколько звёзд-копий осталось
---------------------------------------------------------------------------
function Shop.newPool()
	local pool = {}
	for _, c in ipairs(Config.Cards) do
		pool[c.id] = Config.Shop.PoolCopies[c.r] or 0
	end
	return pool
end

function Shop.take(pool, cardId)
	if (pool[cardId] or 0) <= 0 then
		return false
	end
	pool[cardId] = pool[cardId] - 1
	return true
end

function Shop.give(pool, cardId, n)
	pool[cardId] = (pool[cardId] or 0) + (n or 1)
end

-- Вернуть в пул все карты игрока (выбывание)
function Shop.returnAll(pool, p)
	for cardId, stars in pairs(p.cards or {}) do
		Shop.give(pool, cardId, stars)
	end
end

---------------------------------------------------------------------------
-- Доступность и веса
---------------------------------------------------------------------------

-- Разблокирована ли редкость карты для игрока
function Shop.rarityUnlocked(p, card)
	local need = Config.Shop.RarityUnlockStyleLevel[card.r] or 0
	if need <= 0 then
		return true
	end
	return Progression.cardStyleLevel(p, card) >= need
end

function Shop.canOffer(pool, p, card)
	if (pool[card.id] or 0) <= 0 then
		return false
	end
	if (p.cards and p.cards[card.id] or 0) >= Config.Shop.MaxStars then
		return false
	end
	return Shop.rarityUnlocked(p, card)
end

-- Кандидаты для слота магазина с весами
-- opts: exclude (id->true), filter(card)->bool, srWeightMul
function Shop.candidates(pool, p, opts)
	opts = opts or {}
	local byRarity = { n = {}, r = {}, sr = {} }
	for _, c in ipairs(Config.Cards) do
		if not (opts.exclude and opts.exclude[c.id]) and Shop.canOffer(pool, p, c) then
			if not opts.filter or opts.filter(c) then
				table.insert(byRarity[c.r], c)
			end
		end
	end
	local list, weights = {}, {}
	for _, r in ipairs({ "n", "r", "sr" }) do
		local cards = byRarity[r]
		if #cards > 0 then
			local rw = Config.Shop.RarityWeight[r]
			if r == "sr" and opts.srWeightMul then
				rw = rw * opts.srWeightMul
			end
			if opts.rarityWeight and opts.rarityWeight[r] then
				rw = opts.rarityWeight[r]
			end
			local per = rw / #cards
			for _, c in ipairs(cards) do
				local w = per
				-- Карты стилей, в которых уже есть опыт, выпадают чаще
				for _, s in ipairs(c.s) do
					if (p.styleXp and p.styleXp[s] or 0) > 0 then
						w = per * Config.Shop.OwnStyleWeightMul
						break
					end
				end
				table.insert(list, c)
				table.insert(weights, w)
			end
		end
	end
	return list, weights
end

local function weightedPick(rng, list, weights)
	local total = 0
	for _, w in ipairs(weights) do
		total = total + w
	end
	if total <= 0 then
		return nil, nil
	end
	local roll = rng:float() * total
	for i, w in ipairs(weights) do
		roll = roll - w
		if roll < 0 then
			return list[i], i
		end
	end
	return list[#list], #list
end
Shop.weightedPick = weightedPick

-- Новое содержимое магазина (массив из Slots id карт или false)
function Shop.roll(pool, p, rng, opts)
	opts = opts or {}
	local slots = {}
	local exclude = {}
	for i = 1, Config.Shop.Slots do
		local list, weights = Shop.candidates(pool, p, {
			exclude = exclude,
			srWeightMul = opts.srWeightMul,
			rarityWeight = opts.rarityWeight,
			filter = opts.filter,
		})
		local card = weightedPick(rng, list, weights)
		if card then
			slots[i] = card.id
			exclude[card.id] = true
		else
			slots[i] = false
		end
	end
	return slots
end

-- Случайная карта из пула (для наград). Возвращает карту или nil.
function Shop.randomCard(pool, p, rng, filter)
	local list, weights = Shop.candidates(pool, p, { filter = filter })
	return (weightedPick(rng, list, weights))
end

function Shop.price(p, card)
	local price = Config.Economy.CardPrice[card.r] or 100
	if p.mods and p.mods.cardDiscount then
		price = math.floor(price * (1 - p.mods.cardDiscount / 100) + 0.5)
	end
	return price
end

function Shop.rerollCost(p)
	local cost = Config.Economy.RerollCost
	if p.mods then
		cost = cost - (p.mods.rerollDiscount or 0) + (p.mods.rerollPlus or 0)
	end
	return math.max(0, cost)
end

return Shop
