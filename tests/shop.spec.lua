local Config = R("shared/Config")
local Shop = R("shared/Game/Shop")
local Progression = R("shared/Game/Progression")
local Rng = R("shared/Combat/Rng")

T.suite("Магазин и пул")

local function newP()
	return { heroId = "koku", cards = {}, cardOrder = {}, styleXp = {}, items = {}, talents = {} }
end

T.test("пул содержит копии по редкости", function()
	local pool = Shop.newPool()
	T.eq(pool[4], Config.Shop.PoolCopies.n)
	T.eq(pool[13], Config.Shop.PoolCopies.r)
	T.eq(pool[14], Config.Shop.PoolCopies.sr)
end)

T.test("магазин без прокачки показывает только обычные карты", function()
	local pool = Shop.newPool()
	local rng = Rng.new(5)
	local byId = Progression.cardsById()
	for _ = 1, 50 do
		local slots = Shop.roll(pool, newP(), rng)
		T.eq(#slots, Config.Shop.Slots)
		for _, id in ipairs(slots) do
			T.eq(byId[id].r, "n")
		end
	end
end)

T.test("редкие открываются со 2-го уровня стиля, легендарные с 3-го", function()
	local p = newP()
	p.styleXp.attack = Config.Styles.LevelXp[2]
	local pool = Shop.newPool()
	local byId = Progression.cardsById()
	local seenR, seenSR = false, false
	local rng = Rng.new(11)
	for _ = 1, 300 do
		for _, id in ipairs(Shop.roll(pool, p, rng)) do
			local c = byId[id]
			if c.r == "r" then
				seenR = true
				T.ok(Progression.cardStyleLevel(p, c) >= 2)
			end
			if c.r == "sr" then
				seenSR = true
			end
		end
	end
	T.ok(seenR, "редкие должны выпадать")
	T.ok(not seenSR, "легендарные не должны выпадать на 2-м уровне")
	p.styleXp.attack = Config.Styles.LevelXp[3]
	for _ = 1, 400 do
		for _, id in ipairs(Shop.roll(pool, p, rng)) do
			if byId[id].r == "sr" then
				seenSR = true
			end
		end
	end
	T.ok(seenSR, "легендарные должны выпадать на 3-м уровне")
end)

T.test("закончившиеся в пуле карты не выпадают", function()
	local pool = Shop.newPool()
	for _, c in ipairs(Config.Cards) do
		if c.id ~= 47 then
			pool[c.id] = 0
		end
	end
	local slots = Shop.roll(pool, newP(), Rng.new(3))
	T.eq(slots[1], 47)
	T.eq(slots[2], false)
	pool[47] = 0
	T.eq(Shop.roll(pool, newP(), Rng.new(3))[1], false)
end)

T.test("в одном магазине нет повторов", function()
	local pool = Shop.newPool()
	local rng = Rng.new(8)
	for _ = 1, 100 do
		local seen = {}
		for _, id in ipairs(Shop.roll(pool, newP(), rng)) do
			T.ok(not seen[id])
			seen[id] = true
		end
	end
end)

T.test("карты с 5 звёздами больше не предлагаются", function()
	local pool = Shop.newPool()
	local p = newP()
	p.cards[47] = 5
	T.ok(not Shop.canOffer(pool, p, Progression.cardsById()[47]))
end)

T.test("возврат карт выбывшего в пул", function()
	local pool = Shop.newPool()
	local p = newP()
	Shop.take(pool, 4)
	Shop.take(pool, 4)
	p.cards[4] = 2
	Shop.returnAll(pool, p)
	T.eq(pool[4], Config.Shop.PoolCopies.n)
end)

T.test("цены и стоимость реролла", function()
	local p = newP()
	local byId = Progression.cardsById()
	T.eq(Shop.price(p, byId[4]), 100)
	T.eq(Shop.price(p, byId[13]), 200)
	T.eq(Shop.price(p, byId[14]), 300)
	T.eq(Shop.rerollCost(p), Config.Economy.RerollCost)
	p.mods = { cardDiscount = 10, rerollDiscount = 10 }
	T.eq(Shop.price(p, byId[4]), 90)
	T.eq(Shop.rerollCost(p), Config.Economy.RerollCost - 10)
end)
