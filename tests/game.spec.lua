local Config = R("shared/Config")
local GameState = R("shared/Game/GameState")
local Bot = R("shared/Game/Bot")
local Progression = R("shared/Game/Progression")

T.suite("Партия целиком")

-- Полная партия из 8 ботов. Возвращает игру.
local function playGame(seed, territoryIndex)
	local g = GameState.new({ seed = seed })
	g:beginTerritoryVote()
	if territoryIndex then
		for _, p in ipairs(g.players) do
			g:vote(p.id, territoryIndex)
		end
	end
	g:finishTerritoryVote()
	g:offerHeroes()
	for _, p in ipairs(g.players) do
		Bot.pickHero(g, p)
	end
	g:finishHeroPick()
	g:offerTraits()
	for _, p in ipairs(g.players) do
		Bot.pickTrait(g, p)
	end
	g:finishTraitPick()
	while not g:isOver() do
		g:startTurn()
		for _, p in ipairs(g:alivePlayers()) do
			Bot.prep(g, p)
		end
		g:endPrep()
		g:ensurePairings()
		g:runBattles()
		g:applyResults()
	end
	return g, g:finish()
end

T.test("8 ботов доигрывают партию до конца", function()
	local g, results = playGame(2024)
	T.ok(g.turn < Config.Match.MaxTurns, "партия должна кончиться выбыванием, ход " .. g.turn)
	T.eq(#results, 8)
	local places = {}
	for _, r in ipairs(results) do
		T.ok(r.place and r.place >= 1 and r.place <= 8, "место " .. tostring(r.place))
		T.ok(not places[r.place], "повтор места " .. r.place)
		places[r.place] = true
		T.eq(r.victory, r.place <= 4)
	end
	print("       партия: " .. g.turn .. " ходов, территория «" .. g.territory.name .. "»")
end)

T.test("партии детерминированы по seed", function()
	local g1, r1 = playGame(77)
	local g2, r2 = playGame(77)
	T.eq(g1.turn, g2.turn)
	for i = 1, 8 do
		T.eq(r1[i].id, r2[i].id)
		T.eq(r1[i].place, r2[i].place)
	end
end)

T.test("каждая территория отыгрывается без ошибок", function()
	for i = 1, #Config.Territories do
		local g = GameState.new({ seed = 500 + i })
		g:beginTerritoryVote()
		-- Принудительно ставим i-ю территорию
		g.territoryChoices[1] = Config.Territories[i].id
		for _, p in ipairs(g.players) do
			g:vote(p.id, 1)
		end
		g:finishTerritoryVote()
		T.eq(g.territory.id, Config.Territories[i].id)
		g:offerHeroes()
		g:finishHeroPick()
		g:offerTraits()
		g:finishTraitPick()
		for _ = 1, 16 do
			if g:isOver() then
				break
			end
			g:startTurn()
			for _, p in ipairs(g:alivePlayers()) do
				Bot.prep(g, p)
			end
			g:endPrep()
			g:runBattles()
			g:applyResults()
		end
	end
end)

T.test("каждый артефакт применяется без ошибок", function()
	local g = GameState.new({ seed = 9 })
	g:beginTerritoryVote()
	g:finishTerritoryVote()
	g:offerHeroes()
	g:finishHeroPick()
	g:offerTraits()
	g:finishTraitPick()
	g:startTurn()
	local p = g.players[1]
	for _, a in ipairs(Config.Artifacts) do
		p.artifactOffer = { a.id }
		T.ok(g:pickArtifact(p.id, 1), a.id)
	end
	for _ = 1, 4 do
		g:endPrep()
		g:runBattles()
		g:applyResults()
		if g:isOver() then
			break
		end
		g:startTurn()
	end
end)

T.test("пул общий: купленная карта уходит из пула, выбывший возвращает", function()
	local g = GameState.new({ seed = 3 })
	g:beginTerritoryVote()
	g:finishTerritoryVote()
	g:offerHeroes()
	g:finishHeroPick()
	g:offerTraits()
	g:finishTraitPick()
	g:startTurn()
	local p = g.players[1]
	p.gold = 10000
	local id = p.shop[1]
	local before = g.pool[id]
	T.ok(g:buy(p.id, 1))
	T.eq(g.pool[id], before - 1)
	T.eq(p.shop[1], false)
	-- выбывание возвращает карты
	p.courierHp = 0
	g:checkEliminations()
	T.ok(not p.alive)
	T.eq(g.pool[id], before)
end)

T.test("сервер не даёт купить без золота и вне подготовки", function()
	local g = GameState.new({ seed = 4 })
	g:beginTerritoryVote()
	g:finishTerritoryVote()
	g:offerHeroes()
	g:finishHeroPick()
	g:offerTraits()
	g:finishTraitPick()
	g:startTurn()
	local p = g.players[2]
	p.gold = 0
	p.freeRerolls = 0
	T.ok(not g:buy(p.id, 1))
	T.ok(not g:reroll(p.id))
	T.ok(not g:buy(p.id, 99))
	g:endPrep()
	p.gold = 1000
	T.ok(not g:buy(p.id, 1))
end)

T.test("ходы 5/10/15 — крипы и снаряжение, 3/8/13 — артефакты", function()
	local g = GameState.new({ seed = 12 })
	g:beginTerritoryVote()
	g:finishTerritoryVote()
	g:offerHeroes()
	g:finishHeroPick()
	g:offerTraits()
	g:finishTraitPick()
	for turn = 1, 5 do
		g:startTurn()
		local p = g.players[1]
		if turn == 3 then
			T.ok(p.artifactOffer and #p.artifactOffer == 3)
		end
		for _, q in ipairs(g:alivePlayers()) do
			Bot.prep(g, q)
		end
		g:endPrep()
		g:ensurePairings()
		if turn == 5 then
			T.ok(g.pairs[1].creep ~= nil)
		else
			T.ok(g.pairs[1].creep == nil)
		end
		g:runBattles()
		g:applyResults()
	end
	-- после крипов у каждого есть предмет или выбор предмета
	for _, p in ipairs(g:alivePlayers()) do
		T.ok(#p.items >= 1 or p.itemOffer ~= nil)
	end
end)

T.test("курьер получает урон, HP не уходит выше максимума", function()
	local g = GameState.new({ seed = 5 })
	local p = g.players[1]
	g:healCourier(p, 50)
	T.eq(p.courierHp, Config.Match.CourierHp)
	g.turn = 1
	g:damageCourier(p, 7)
	T.eq(p.courierHp, Config.Match.CourierHp - 7)
end)

T.test("снимки состояния для клиента собираются", function()
	local g = GameState.new({ seed = 6 })
	g:beginTerritoryVote()
	g:finishTerritoryVote()
	g:offerHeroes()
	g:finishHeroPick()
	g:offerTraits()
	g:finishTraitPick()
	g:startTurn()
	local pub = g:publicState()
	T.eq(#pub.players, 8)
	local priv = g:privateState(g.players[1].id)
	T.eq(#priv.shop, Config.Shop.Slots)
	T.ok(priv.styles.attack ~= nil)
	T.ok(priv.gold > 0)
end)
