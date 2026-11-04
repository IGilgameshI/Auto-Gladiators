--!nocheck
-- Состояние партии и все игровые правила (без таймеров и сети).
-- Сервер (src/server) вызывает методы в нужные моменты и рассылает
-- состояние клиентам; боты и тесты используют тот же API.
--
-- Порядок партии:
--   g = GameState.new({ seed = N, players = { {id, name, isBot}, ... } })
--   g:beginTerritoryVote(); g:vote(id, i); g:finishTerritoryVote()
--   g:offerHeroes(); g:pickHero(id, i); g:finishHeroPick()
--   g:offerTraits(); g:pickTrait(id, i); g:finishTraitPick()
--   цикл: g:startTurn() -> (buy/reroll/pick*) -> g:endPrep()
--         -> g:makePairings() -> g:runBattles() -> g:applyResults()
--         пока not g:isOver()

local Config = require(script.Parent.Parent.Config)
local Rng = require(script.Parent.Parent.Combat.Rng)
local Engine = require(script.Parent.Parent.Combat.Engine)
local Builder = require(script.Parent.Parent.Combat.Builder)
local Progression = require(script.Parent.Progression)
local Shop = require(script.Parent.Shop)
local Economy = require(script.Parent.Economy)
local Meta = require(script.Parent.Meta)

local GameState = {}
GameState.__index = GameState

local M = Config.Match

local function indexBy(list, key)
	local out = {}
	for _, x in ipairs(list) do
		out[x[key]] = x
	end
	return out
end
local TraitsById = indexBy(Config.Traits, "id")
local ArtifactsById = indexBy(Config.Artifacts, "id")
local ItemsById = indexBy(Config.Items, "id")
local TerritoriesById = indexBy(Config.Territories, "id")

---------------------------------------------------------------------------
-- Создание
---------------------------------------------------------------------------

local function newPlayer(info, seat)
	return {
		id = info.id,
		name = info.name or ("Игрок " .. seat),
		isBot = info.isBot and true or false,
		seat = seat,
		alive = true,
		place = nil,
		courierHp = M.CourierHp,
		gold = Config.Economy.StartGold,
		heroId = nil,
		heroOffers = nil,
		traitId = nil,
		traitOffers = nil,
		cards = {},
		cardOrder = {},
		styleXp = {},
		items = {},
		talents = {},
		talentTaken = {},
		artifacts = {},
		shop = {},
		freeRerolls = 0,
		winStreak = 0,
		loseStreak = 0,
		wins = 0,
		losses = 0,
		lastResult = nil,
		lastOpponent = nil,
		mods = {},
		notes = {},
		history = {},
	}
end

function GameState.new(opts)
	opts = opts or {}
	local self = setmetatable({}, GameState)
	self.seed = opts.seed or 1
	self.rng = Rng.new(self.seed)
	self.turn = 0
	self.phase = "lobby"
	self.players = {}
	self.byId = {}
	self.pool = Shop.newPool()
	self.territory = nil
	self.territoryChoices = {}
	self.votes = {}
	self.pairs = {}
	self.battles = {}
	self.eliminatedOrder = {}
	local infos = opts.players or {}
	for i = 1, M.MaxPlayers do
		local info = infos[i]
		if not info then
			local botName = Config.Bots.Names[i] or ("Бот " .. i)
			info = { id = "bot_" .. i, name = botName, isBot = true }
		end
		local p = newPlayer(info, i)
		table.insert(self.players, p)
		self.byId[p.id] = p
	end
	return self
end

function GameState:player(id)
	return self.byId[id]
end

function GameState:alivePlayers()
	local out = {}
	for _, p in ipairs(self.players) do
		if p.alive then
			table.insert(out, p)
		end
	end
	return out
end

function GameState:trait(id)
	return id and TraitsById[id]
end

-- Сообщение игроку (показывается в журнале клиента)
function GameState:note(p, text)
	table.insert(p.notes, { turn = self.turn, text = text })
	if #p.notes > 40 then
		table.remove(p.notes, 1)
	end
end

---------------------------------------------------------------------------
-- Голосование за территорию
---------------------------------------------------------------------------

function GameState:beginTerritoryVote()
	self.phase = "vote"
	local ids = {}
	for _, t in ipairs(Config.Territories) do
		table.insert(ids, t.id)
	end
	self.rng:shuffle(ids)
	self.territoryChoices = {}
	for i = 1, math.min(M.TerritoryChoices, #ids) do
		self.territoryChoices[i] = ids[i]
	end
	self.votes = {}
	return self.territoryChoices
end

function GameState:vote(pid, index)
	if self.phase ~= "vote" then
		return false, "Голосование закрыто"
	end
	local p = self.byId[pid]
	if not p or type(index) ~= "number" or not self.territoryChoices[index] then
		return false, "Неверный выбор"
	end
	self.votes[pid] = index
	return true
end

function GameState:voteCounts()
	local counts = {}
	for i = 1, #self.territoryChoices do
		counts[i] = 0
	end
	for _, p in ipairs(self.players) do
		local v = self.votes[p.id]
		if v then
			counts[v] = counts[v] + 1
		end
	end
	return counts
end

function GameState:finishTerritoryVote()
	-- Боты и не проголосовавшие голосуют случайно
	for _, p in ipairs(self.players) do
		if not self.votes[p.id] then
			self.votes[p.id] = self.rng:range(1, #self.territoryChoices)
		end
	end
	local counts = self:voteCounts()
	local best, bestList = -1, {}
	for i, c in ipairs(counts) do
		if c > best then
			best = c
			bestList = { i }
		elseif c == best then
			table.insert(bestList, i)
		end
	end
	local winner = self.rng:pick(bestList)
	self.territory = TerritoriesById[self.territoryChoices[winner]]
	self.territoryIndex = winner
	return self.territory, winner
end

---------------------------------------------------------------------------
-- Выбор героя и черты
---------------------------------------------------------------------------

function GameState:offerHeroes()
	self.phase = "hero"
	for _, p in ipairs(self.players) do
		local ids = {}
		for _, h in ipairs(Config.HeroOrder) do
			table.insert(ids, h)
		end
		self.rng:shuffle(ids)
		p.heroOffers = {}
		for i = 1, math.min(M.HeroChoices, #ids) do
			p.heroOffers[i] = ids[i]
		end
	end
end

function GameState:pickHero(pid, index)
	local p = self.byId[pid]
	if self.phase ~= "hero" or not p or p.heroId then
		return false, "Сейчас нельзя выбрать героя"
	end
	local id = p.heroOffers and p.heroOffers[index]
	if not id then
		return false, "Неверный выбор"
	end
	p.heroId = id
	return true
end

function GameState:finishHeroPick()
	for _, p in ipairs(self.players) do
		if not p.heroId then
			p.heroId = p.heroOffers[self.rng:range(1, #p.heroOffers)]
		end
	end
end

function GameState:offerTraits()
	self.phase = "trait"
	for _, p in ipairs(self.players) do
		local ids = {}
		for _, t in ipairs(Config.Traits) do
			table.insert(ids, t.id)
		end
		self.rng:shuffle(ids)
		p.traitOffers = {}
		for i = 1, math.min(M.TraitChoices, #ids) do
			p.traitOffers[i] = ids[i]
		end
	end
end

function GameState:pickTrait(pid, index)
	local p = self.byId[pid]
	if self.phase ~= "trait" or not p or p.traitId then
		return false, "Сейчас нельзя выбрать черту"
	end
	local id = p.traitOffers and p.traitOffers[index]
	if not id then
		return false, "Неверный выбор"
	end
	p.traitId = id
	return true
end

function GameState:finishTraitPick()
	for _, p in ipairs(self.players) do
		if not p.traitId then
			p.traitId = p.traitOffers[self.rng:range(1, #p.traitOffers)]
		end
		Meta.applyStart(self, p)
	end
end

---------------------------------------------------------------------------
-- Прогресс: опыт, карты, уровни
---------------------------------------------------------------------------

function GameState:onLevelUps(p, ups)
	for _, lvl in ipairs(ups) do
		self:note(p, "Уровень героя: " .. lvl)
		Meta.onLevelUp(self, p, lvl)
	end
	self:refreshTalentOffer(p)
end

function GameState:addXp(p, style, xp)
	local ups = Progression.addStyleXp(p, style, xp)
	self:note(p, "+" .. xp .. " XP стилю «" .. Config.Styles.Data[style].name .. "»")
	self:onLevelUps(p, ups)
end

-- Выдать конкретную карту (если есть в пуле)
function GameState:grantCard(p, cardId, reason)
	local card = Progression.cardsById()[cardId]
	if not card or not Shop.take(self.pool, cardId) then
		return false
	end
	local ok, ups, isNew = Progression.addCardStar(p, cardId)
	if not ok then
		Shop.give(self.pool, cardId, 1)
		return false
	end
	self:note(p, "Карта «" .. card.name .. "»" .. (reason and (": " .. reason) or ""))
	self:onLevelUps(p, ups)
	return true, isNew
end

-- Случайная карта из пула. ignoreUnlock — выдать даже закрытую редкость.
function GameState:grantRandomCard(p, filter, reason, ignoreUnlock)
	local card
	if ignoreUnlock then
		local list = {}
		for _, c in ipairs(Config.Cards) do
			if (self.pool[c.id] or 0) > 0 and (p.cards[c.id] or 0) < Config.Shop.MaxStars and (not filter or filter(c)) then
				table.insert(list, c)
			end
		end
		card = self.rng:pick(list)
	else
		card = Shop.randomCard(self.pool, p, self.rng, filter)
	end
	if not card then
		return false
	end
	return self:grantCard(p, card.id, reason)
end

-- Карта стиля героя
function GameState:grantHeroStyleCard(p, reason, rarity)
	local hero = Config.Heroes[p.heroId]
	local styles = {}
	for _, s in ipairs(hero.styles) do
		styles[s] = true
	end
	return self:grantRandomCard(p, function(c)
		if rarity and c.r ~= rarity then
			return false
		end
		for _, s in ipairs(c.s) do
			if styles[s] then
				return true
			end
		end
		return false
	end, reason)
end

function GameState:healCourier(p, n)
	if n <= 0 or not p.alive then
		return
	end
	p.courierHp = math.min(M.CourierHp, p.courierHp + n)
	self:note(p, "Курьер +" .. n .. " HP")
end

---------------------------------------------------------------------------
-- Таланты
---------------------------------------------------------------------------

function GameState:refreshTalentOffer(p)
	if p.talentOffer then
		return
	end
	local pending = Progression.pendingTalentLevels(p)
	local lvl = pending[1]
	if not lvl then
		return
	end
	local hero = Config.Heroes[p.heroId]
	local list = hero.talents[lvl]
	local ids = {}
	for i, t in ipairs(list) do
		ids[i] = t.id
	end
	p.talentOffer = { level = lvl, ids = ids }
end

function GameState:pickTalent(pid, index)
	local p = self.byId[pid]
	if not p or not p.talentOffer then
		return false, "Нет доступного таланта"
	end
	local id = p.talentOffer.ids[index]
	if not id then
		return false, "Неверный выбор"
	end
	p.talents[id] = true
	p.talentTaken[p.talentOffer.level] = id
	p.talentOffer = nil
	self:refreshTalentOffer(p)
	return true
end

---------------------------------------------------------------------------
-- Ход: подготовка
---------------------------------------------------------------------------

function GameState:isCreepTurn(turn)
	return M.CreepTurns[turn or self.turn] ~= nil
end

function GameState:shopOpts(p)
	local terr = self.territory or {}
	return { srWeightMul = terr.srWeightMul }
end

function GameState:startTurn()
	self.turn = self.turn + 1
	self.phase = "prep"
	self.pairs = {}
	self.battles = {}
	local terr = self.territory or {}
	-- Хаотичное пространство: один бросок на всех
	self.chaosRoll = nil
	if terr.chaos then
		self.chaosRoll = self.rng:chance(50) and terr.chaos.gold or 0
	end
	-- Общее процветание
	if terr.shareGold and self.turn == terr.shareGold.turn then
		local alive = self:alivePlayers()
		local share = math.floor(terr.shareGold.gold / math.max(1, #alive))
		for _, p in ipairs(alive) do
			Meta.addGold(self, p, share, terr.name)
		end
	end
	for _, p in ipairs(self:alivePlayers()) do
		p.turn = self.turn
		if self.turn > 1 then
			local income, parts = Economy.income(self, p)
			p.gold = p.gold + income
			p.lastIncome = parts
		end
		Meta.onTurnStart(self, p)
		p.shop = Shop.roll(self.pool, p, self.rng, self:shopOpts(p))
		p.battleMods = {}
		-- Артефакт
		if M.ArtifactTurns[self.turn] and not p.artifactOffer then
			p.artifactOffer = self:rollArtifacts(p)
		end
		self:refreshTalentOffer(p)
	end
	-- Ясновидение: соперники следующего боя известны заранее
	if terr.revealOpponent and not self:isCreepTurn() then
		self:makePairings()
	end
end

function GameState:rollArtifacts(p)
	local owned = {}
	for _, a in ipairs(p.artifacts) do
		owned[a.id] = true
	end
	local list = {}
	for _, a in ipairs(Config.Artifacts) do
		if not owned[a.id] then
			for _, t in ipairs(a.turns) do
				if t == self.turn then
					table.insert(list, a.id)
					break
				end
			end
		end
	end
	self.rng:shuffle(list)
	local out = {}
	for i = 1, math.min(M.ArtifactChoices, #list) do
		out[i] = list[i]
	end
	return out
end

function GameState:pickArtifact(pid, index)
	local p = self.byId[pid]
	if not p or not p.artifactOffer then
		return false, "Нет выбора артефакта"
	end
	local id = p.artifactOffer[index]
	local art = id and ArtifactsById[id]
	if not art then
		return false, "Неверный выбор"
	end
	p.artifactOffer = nil
	table.insert(p.artifacts, art)
	self:note(p, "Артефакт «" .. art.name .. "»")
	Meta.onPickArtifact(self, p, art)
	return true
end

function GameState:pickItem(pid, index)
	local p = self.byId[pid]
	if not p or not p.itemOffer then
		return false, "Нет выбора предмета"
	end
	local id = p.itemOffer[index]
	if not id or not ItemsById[id] then
		return false, "Неверный выбор"
	end
	p.itemOffer = nil
	table.insert(p.items, id)
	self:note(p, "Снаряжение «" .. ItemsById[id].name .. "»")
	return true
end

function GameState:buy(pid, slot)
	local p = self.byId[pid]
	if self.phase ~= "prep" or not p or not p.alive then
		return false, "Сейчас нельзя покупать"
	end
	local cardId = p.shop[slot]
	if not cardId then
		return false, "Пустой слот"
	end
	local card = Progression.cardsById()[cardId]
	if (p.cards[cardId] or 0) >= Config.Shop.MaxStars then
		return false, "Уже 5 звёзд"
	end
	local price = Shop.price(p, card)
	if p.gold < price then
		return false, "Не хватает золота"
	end
	if not Shop.take(self.pool, cardId) then
		return false, "Карта закончилась в пуле"
	end
	p.gold = p.gold - price
	local ok, ups, isNew = Progression.addCardStar(p, cardId)
	if not ok then
		Shop.give(self.pool, cardId, 1)
		p.gold = p.gold + price
		return false, "Ошибка покупки"
	end
	p.shop[slot] = false
	Meta.onPurchase(self, p, card, isNew)
	self:onLevelUps(p, ups)
	return true
end

function GameState:reroll(pid)
	local p = self.byId[pid]
	if self.phase ~= "prep" or not p or not p.alive then
		return false, "Сейчас нельзя обновлять"
	end
	if (p.freeRerolls or 0) > 0 then
		p.freeRerolls = p.freeRerolls - 1
	else
		local cost = Shop.rerollCost(p)
		if p.gold < cost then
			return false, "Не хватает золота"
		end
		p.gold = p.gold - cost
	end
	p.shop = Shop.roll(self.pool, p, self.rng, self:shopOpts(p))
	return true
end

-- Конец подготовки: незакрытые выборы делаются автоматически
function GameState:endPrep()
	for _, p in ipairs(self:alivePlayers()) do
		if p.artifactOffer then
			self:pickArtifact(p.id, self.rng:range(1, #p.artifactOffer))
		end
		if p.itemOffer then
			self:pickItem(p.id, self.rng:range(1, #p.itemOffer))
		end
		local guard = 0
		while p.talentOffer and guard < 5 do
			guard = guard + 1
			self:pickTalent(p.id, self.rng:range(1, #p.talentOffer.ids))
		end
	end
	self.phase = "pairing"
end

---------------------------------------------------------------------------
-- Пары и бои
---------------------------------------------------------------------------

-- Пары на ход. PvE: каждый против крипа. PvP: случайные пары без повтора
-- прошлого соперника; при нечётном числе один дерётся с «призраком».
function GameState:makePairings()
	self.pairs = {}
	local alive = self:alivePlayers()
	if self:isCreepTurn() then
		local tier = M.CreepTurns[self.turn]
		local creeps = {}
		for _, c in ipairs(Config.Creeps) do
			if c.tier == tier then
				table.insert(creeps, c)
			end
		end
		for _, p in ipairs(alive) do
			table.insert(self.pairs, { a = p.id, creep = self.rng:pick(creeps).id, tier = tier, host = p.id })
		end
		return self.pairs
	end
	local best, bestScore = nil, math.huge
	for _ = 1, 12 do
		local order = {}
		for i, p in ipairs(alive) do
			order[i] = p
		end
		self.rng:shuffle(order)
		local score = 0
		for i = 1, #order - 1, 2 do
			if order[i].lastOpponent == order[i + 1].id then
				score = score + 1
			end
		end
		if score < bestScore then
			best, bestScore = order, score
			if score == 0 then
				break
			end
		end
	end
	local i = 1
	while i <= #best do
		local a, b = best[i], best[i + 1]
		if b then
			-- Хозяин арены — тот, у кого меньше номер места (детерминированно)
			local host = a.seat < b.seat and a or b
			table.insert(self.pairs, { a = a.id, b = b.id, host = host.id })
		else
			-- Призрак: копия случайного другого живого игрока
			local others = {}
			for _, p in ipairs(alive) do
				if p ~= a then
					table.insert(others, p)
				end
			end
			local ghost = self.rng:pick(others)
			if ghost then
				table.insert(self.pairs, { a = a.id, ghost = ghost.id, host = a.id })
			end
		end
		i = i + 2
	end
	return self.pairs
end

-- Пары, если их ещё нет (при «Ясновидении» они составлены в начале хода)
function GameState:ensurePairings()
	if #self.pairs == 0 then
		self:makePairings()
	end
	return self.pairs
end

-- Пара игрока на текущий ход
function GameState:pairOf(pid)
	for i, pr in ipairs(self.pairs) do
		if pr.a == pid or pr.b == pid then
			return pr, i
		end
	end
	return nil
end

function GameState:specFor(p)
	p.turn = self.turn
	return Builder.fromPlayer(p)
end

-- Просчитать все бои хода (сервер потом воспроизводит журналы)
function GameState:runBattles()
	self.phase = "battle"
	self.battles = {}
	self:ensurePairings()
	for i, pr in ipairs(self.pairs) do
		local pa = self.byId[pr.a]
		local specA = self:specFor(pa)
		local specB, kind
		if pr.creep then
			local creep
			for _, c in ipairs(Config.Creeps) do
				if c.id == pr.creep then
					creep = c
				end
			end
			specB = Builder.fromCreep(creep, pr.tier)
			kind = "creep"
		elseif pr.ghost then
			specB = self:specFor(self.byId[pr.ghost])
			specB.name = specB.name .. " (призрак)"
			kind = "ghost"
		else
			specB = self:specFor(self.byId[pr.b])
			kind = "pvp"
		end
		local seed = self.rng:nextInt()
		local result = Engine.simulate(specA, specB, seed)
		self.battles[i] = { pair = pr, kind = kind, seed = seed, result = result, specA = specA, specB = specB }
	end
	return self.battles
end

-- Применить результат одного проигравшего
function GameState:damageCourier(loser, dmg)
	dmg = Meta.modifyCourierDamage(self, loser, dmg)
	if dmg <= 0 then
		return 0
	end
	local before = loser.courierHp
	loser.courierHp = loser.courierHp - dmg
	if loser.courierHp <= 0 and Meta.tryRescue(self, loser) then
		self:note(loser, "Последнее спасение!")
	end
	local lost = before - math.max(0, loser.courierHp)
	Meta.onCourierHurt(self, loser, lost)
	return dmg
end

local function setResult(p, won)
	if won then
		p.wins = p.wins + 1
		p.winStreak = p.winStreak + 1
		p.loseStreak = 0
		p.lastResult = "win"
	else
		p.losses = p.losses + 1
		p.loseStreak = p.loseStreak + 1
		p.winStreak = 0
		p.lastResult = "lose"
	end
end

function GameState:applyResults()
	self.phase = "results"
	local summary = {}
	for _, b in ipairs(self.battles) do
		local pr = b.pair
		local pa = self.byId[pr.a]
		local winnerSide = b.result.winner
		if b.kind == "creep" then
			local won = winnerSide == 1
			Meta.afterBattle(self, pa, won, 0)
			setResult(pa, won)
			-- Снаряжение: победа — выбор 1 из 3, поражение — случайный предмет
			local list = {}
			for _, it in ipairs(Config.Items) do
				if it.tier == pr.tier then
					table.insert(list, it.id)
				end
			end
			self.rng:shuffle(list)
			if won then
				pa.itemOffer = { list[1], list[2], list[3] }
			else
				table.insert(pa.items, list[1])
				self:note(pa, "Снаряжение (утешительное): «" .. ItemsById[list[1]].name .. "»")
				if M.CreepLossDamagesCourier then
					self:damageCourier(pa, Config.CourierDamage.CreepDamage)
				end
			end
			table.insert(summary, { a = pa.id, creep = pr.creep, won = won })
		else
			local pb = pr.b and self.byId[pr.b] or nil
			local winner, loser
			if winnerSide == 1 then
				winner, loser = pa, pb
			else
				winner, loser = pb, pa
			end
			if b.kind == "ghost" then
				-- Против призрака результат влияет только на живого игрока
				local won = winnerSide == 1
				local dmg = 0
				if not won then
					local g = self.byId[pr.ghost]
					local extra = Meta.extraDamage(g)
					dmg = self:damageCourier(pa, Economy.courierDamage(self.turn, g.winStreak, Progression.heroLevel(g), extra))
				end
				Meta.afterBattle(self, pa, won, 0)
				setResult(pa, won)
				table.insert(summary, { a = pa.id, ghost = pr.ghost, won = won, damage = dmg })
			else
				-- Серия победителя считается с учётом этой победы
				local streak = winner.winStreak + 1
				local extra = Meta.extraDamage(winner)
				local raw = Economy.courierDamage(self.turn, streak, Progression.heroLevel(winner), extra)
				local dmg = self:damageCourier(loser, raw)
				Meta.afterBattle(self, winner, true, dmg)
				Meta.afterBattle(self, loser, false, 0)
				setResult(winner, true)
				setResult(loser, false)
				winner.lastOpponent = loser.id
				loser.lastOpponent = winner.id
				table.insert(summary, { winner = winner.id, loser = loser.id, damage = dmg })
			end
		end
	end
	local eliminated = self:checkEliminations()
	self.lastSummary = summary
	return summary, eliminated
end

-- Выбывание и места. Одновременно выбывшие сортируются по HP курьера.
function GameState:checkEliminations()
	local dead = {}
	for _, p in ipairs(self.players) do
		if p.alive and p.courierHp <= 0 then
			table.insert(dead, p)
		end
	end
	table.sort(dead, function(x, y)
		if x.courierHp ~= y.courierHp then
			return x.courierHp < y.courierHp
		end
		return x.seat > y.seat
	end)
	local aliveCount = #self:alivePlayers()
	for _, p in ipairs(dead) do
		p.place = aliveCount
		aliveCount = aliveCount - 1
		p.alive = false
		p.courierHp = 0
		Shop.returnAll(self.pool, p)
		table.insert(self.eliminatedOrder, p.id)
		Meta.onElimination(self, p)
	end
	local alive = self:alivePlayers()
	if #alive == 1 then
		alive[1].place = 1
	end
	return dead
end

function GameState:isOver()
	if #self:alivePlayers() <= 1 then
		return true
	end
	return self.turn >= M.MaxTurns
end

-- Финал: места оставшимся (по HP курьера) и флаг победы (места 1..4)
function GameState:finish()
	self.phase = "over"
	local alive = self:alivePlayers()
	table.sort(alive, function(x, y)
		if x.courierHp ~= y.courierHp then
			return x.courierHp > y.courierHp
		end
		return x.seat < y.seat
	end)
	for i, p in ipairs(alive) do
		p.place = i
	end
	local out = {}
	for _, p in ipairs(self.players) do
		p.victory = (p.place or M.MaxPlayers) <= M.WinningPlaces
		table.insert(out, { id = p.id, name = p.name, place = p.place, victory = p.victory })
	end
	table.sort(out, function(x, y)
		return (x.place or 99) < (y.place or 99)
	end)
	return out
end

---------------------------------------------------------------------------
-- Снимки состояния для клиентов
---------------------------------------------------------------------------

function GameState:publicState()
	local players = {}
	for _, p in ipairs(self.players) do
		table.insert(players, {
			id = tostring(p.id),
			name = p.name,
			seat = p.seat,
			isBot = p.isBot,
			alive = p.alive,
			place = p.place,
			hp = p.courierHp,
			heroId = p.heroId,
			level = p.heroId and Progression.heroLevel(p) or 0,
			winStreak = p.winStreak,
			loseStreak = p.loseStreak,
			wins = p.wins,
		})
	end
	local terr = self.territory
	return {
		turn = self.turn,
		phase = self.phase,
		creepTurn = self:isCreepTurn(self.turn),
		territory = terr and { id = terr.id, name = terr.name, desc = terr.desc } or nil,
		territoryChoices = self.territoryChoices,
		votes = self:voteCounts(),
		players = players,
	}
end

function GameState:privateState(pid)
	local p = self.byId[pid]
	if not p then
		return nil
	end
	local styles = {}
	for _, s in ipairs(Config.Styles.Order) do
		local lvl = Progression.styleLevel(p, s)
		styles[s] = {
			xp = p.styleXp[s] or 0,
			level = lvl,
			next = Progression.levelReq(p, s, lvl + 1),
		}
	end
	local cards = {}
	for _, id in ipairs(p.cardOrder) do
		table.insert(cards, { id = id, stars = p.cards[id] })
	end
	local shop = {}
	for i = 1, Config.Shop.Slots do
		local id = p.shop[i]
		if id then
			local c = Progression.cardsById()[id]
			shop[i] = { id = id, price = Shop.price(p, c), owned = p.cards[id] or 0, left = self.pool[id] or 0 }
		else
			shop[i] = false
		end
	end
	local nextOpp = nil
	local pr = self:pairOf(p.id)
	if pr and self.territory and self.territory.revealOpponent and self.phase == "prep" then
		local oid = (pr.a == p.id) and (pr.b or pr.ghost) or pr.a
		local o = self.byId[oid]
		nextOpp = o and o.name
	end
	local arts = {}
	for _, a in ipairs(p.artifacts) do
		table.insert(arts, a.id)
	end
	return {
		id = tostring(p.id),
		gold = p.gold,
		hp = p.courierHp,
		heroId = p.heroId,
		heroOffers = p.heroOffers,
		traitId = p.traitId,
		traitOffers = p.traitOffers,
		level = p.heroId and Progression.heroLevel(p) or 0,
		styles = styles,
		cards = cards,
		shop = shop,
		rerollCost = Shop.rerollCost(p),
		freeRerolls = p.freeRerolls or 0,
		items = p.items,
		artifacts = arts,
		artifactOffer = p.artifactOffer,
		itemOffer = p.itemOffer,
		talentOffer = p.talentOffer,
		talents = p.talentTaken,
		winStreak = p.winStreak,
		loseStreak = p.loseStreak,
		lastIncome = p.lastIncome,
		nextOpponent = nextOpp,
		notes = p.notes,
		vote = self.votes[p.id],
		alive = p.alive,
		place = p.place,
	}
end

GameState.ItemsById = ItemsById
GameState.ArtifactsById = ArtifactsById
GameState.TraitsById = TraitsById
GameState.TerritoriesById = TerritoriesById

return GameState
