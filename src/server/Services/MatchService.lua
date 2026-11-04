--!nonstrict
-- Цикл партии: лобби -> голосование -> выбор героя/черты -> ходы.
-- Все правила живут в shared/Game/GameState; здесь только таймеры, сеть,
-- проверка запросов клиентов и постановка боёв на арены.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local GameState = require(Shared:WaitForChild("Game"):WaitForChild("GameState"))
local Bot = require(Shared.Game:WaitForChild("Bot"))

local ArenaService = require(script.Parent.ArenaService)
local FighterService = require(script.Parent.FighterService)

local M = Config.Match
local MatchService = {}

local remotes = {}
local current = nil -- активная партия (GameState)
local phaseName = "lobby"
local phaseEndsAt = 0
local dirty = true
local readyFlags = {} -- pid -> true (игрок нажал «Готов»)
local actionBudget = {} -- защита от спама запросами
local playerById = {} -- pid -> Player
local territoryGuis = {}

local function now()
	return Workspace:GetServerTimeNow()
end

local function pidOf(player)
	return tostring(player.UserId)
end

local function markDirty()
	dirty = true
end

local function toast(target, text)
	if target == nil then
		remotes.Toast:FireAllClients(text)
	else
		remotes.Toast:FireClient(target, text)
	end
end

local function setPhase(name, seconds)
	phaseName = name
	phaseEndsAt = now() + seconds
	markDirty()
end

---------------------------------------------------------------------------
-- Сеть
---------------------------------------------------------------------------

local function createRemotes()
	local folder = ReplicatedStorage:FindFirstChild(Net.FolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Net.FolderName
		folder.Parent = ReplicatedStorage
	end
	for _, name in pairs(Net.Remotes) do
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		remotes[name] = r
	end
end

-- Описание пар хода для клиентов
local function pairsInfo()
	if not current then
		return {}
	end
	local out = {}
	for _, pr in ipairs(current.pairs or {}) do
		local a = current:player(pr.a)
		local entry = { a = a and a.name or "?", host = current:player(pr.host).seat }
		if pr.b then
			entry.b = current:player(pr.b).name
		elseif pr.ghost then
			entry.b = current:player(pr.ghost).name .. " (призрак)"
		elseif pr.creep then
			for _, c in ipairs(Config.Creeps) do
				if c.id == pr.creep then
					entry.b = c.name
				end
			end
			entry.creep = true
		end
		table.insert(out, entry)
	end
	return out
end

local function sendState()
	local base = {
		phase = phaseName,
		endsAt = phaseEndsAt,
		inMatch = current ~= nil,
		lobbyCount = #Players:GetPlayers(),
	}
	local pub = current and current:publicState() or nil
	-- Клиенты видят пары только когда они объявлены
	local showPairs = current
		and (phaseName == "pairing" or phaseName == "battle" or phaseName == "results"
			or (phaseName == "prep" and current.territory and current.territory.revealOpponent))
	local pairsData = showPairs and pairsInfo() or {}
	for _, player in ipairs(Players:GetPlayers()) do
		local msg = table.clone(base)
		msg.pub = pub
		msg.pairs = pairsData
		if current then
			local me = current:privateState(pidOf(player))
			if me then
				me.ready = readyFlags[pidOf(player)] == true
			end
			msg.me = me
		end
		remotes.State:FireClient(player, msg)
	end
end

---------------------------------------------------------------------------
-- Обработка действий клиента (сервер проверяет всё сам)
---------------------------------------------------------------------------

local function validIndex(x)
	return type(x) == "number" and x == math.floor(x) and x >= 1 and x <= 16
end

local function onAction(player, action, arg)
	-- Ограничение частоты: 20 запросов в секунду
	local pid = pidOf(player)
	local t = os.clock()
	local budget = actionBudget[pid]
	if not budget or t - budget.since > 1 then
		budget = { since = t, count = 0 }
		actionBudget[pid] = budget
	end
	budget.count = budget.count + 1
	if budget.count > 20 then
		return
	end
	if not current or type(action) ~= "string" then
		return
	end
	local p = current:player(pid)
	if not p then
		return -- зритель
	end
	local A = Net.Actions
	local ok, err = false, nil
	if action == A.Ready then
		if phaseName == "prep" then
			readyFlags[pid] = true
			ok = true
		end
	elseif not validIndex(arg) and action ~= A.Reroll then
		return
	elseif action == A.Vote then
		ok, err = current:vote(pid, arg)
	elseif action == A.PickHero then
		ok, err = current:pickHero(pid, arg)
	elseif action == A.PickTrait then
		ok, err = current:pickTrait(pid, arg)
	elseif phaseName ~= "prep" then
		err = "Доступно только в фазе подготовки"
	elseif action == A.Buy then
		ok, err = current:buy(pid, arg)
	elseif action == A.Reroll then
		ok, err = current:reroll(pid)
	elseif action == A.PickArtifact then
		ok, err = current:pickArtifact(pid, arg)
	elseif action == A.PickItem then
		ok, err = current:pickItem(pid, arg)
	elseif action == A.PickTalent then
		ok, err = current:pickTalent(pid, arg)
	end
	if not ok and err then
		toast(player, err)
	end
	markDirty()
end

---------------------------------------------------------------------------
-- Персонажи и маркеры площади
---------------------------------------------------------------------------

local function teleportToSpawn(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local cf = nil
	if current then
		local p = current:player(pidOf(player))
		if p then
			cf = ArenaService.hubMarker("Spawn_" .. p.seat)
		end
	end
	cf = cf or ArenaService.hubMarker("HubCenter")
	if cf then
		char:PivotTo(cf + Vector3.new(0, 4, 0))
	end
end

local function clearTerritoryGuis()
	for _, g in ipairs(territoryGuis) do
		g:Destroy()
	end
	territoryGuis = {}
end

local function showTerritoryGuis()
	clearTerritoryGuis()
	local markers = ArenaService.markers()
	if not markers or not current then
		return
	end
	for i, id in ipairs(current.territoryChoices) do
		local marker = markers:FindFirstChild("Territory_" .. i)
		local terr = GameState.TerritoriesById[id]
		if marker and terr then
			local adornee = marker:IsA("BasePart") and marker or marker:FindFirstChildWhichIsA("BasePart", true)
			if adornee then
				local bb = Instance.new("BillboardGui")
				bb.Name = "TerritoryInfo"
				bb.Size = UDim2.fromOffset(260, 110)
				bb.StudsOffset = Vector3.new(0, 7, 0)
				bb.AlwaysOnTop = true
				bb.MaxDistance = 200
				bb.Adornee = adornee
				local label = Instance.new("TextLabel")
				label.Name = "Text"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
				label.BackgroundTransparency = 0.25
				label.TextColor3 = Color3.new(1, 1, 1)
				label.Font = Enum.Font.GothamBold
				label.TextScaled = true
				label.TextWrapped = true
				label.Text = terr.name .. "\n" .. terr.desc
				label.Parent = bb
				bb.Parent = adornee
				table.insert(territoryGuis, bb)
			end
		end
	end
end

local function updateTerritoryGuis()
	if not current then
		return
	end
	local counts = current:voteCounts()
	for i, bb in ipairs(territoryGuis) do
		local label = bb:FindFirstChild("Text")
		local terr = GameState.TerritoriesById[current.territoryChoices[i]]
		if label and terr then
			label.Text = string.format("%s  [%d]\n%s", terr.name, counts[i] or 0, terr.desc)
		end
	end
end

-- Голос ногами: игрок стоит рядом с маркером Territory_i
local function proximityVotes()
	local markers = ArenaService.markers()
	if not markers or not current then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root then
			for i = 1, #current.territoryChoices do
				local cf = ArenaService.hubMarker("Territory_" .. i)
				if cf and (cf.Position - root.Position).Magnitude <= M.TerritoryVoteRadius then
					if current.votes[pidOf(player)] ~= i then
						current:vote(pidOf(player), i)
						markDirty()
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Ожидание фазы
---------------------------------------------------------------------------

-- Ждёт seconds секунд или пока done() не вернёт true; tick() каждые 0.25 сек.
local function waitPhase(seconds, done, tick)
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if done and done() then
			return
		end
		if tick then
			tick()
		end
		task.wait(0.25)
	end
end

local function humans()
	local out = {}
	if not current then
		return out
	end
	for _, p in ipairs(current.players) do
		if not p.isBot then
			table.insert(out, p)
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Бои
---------------------------------------------------------------------------

local function stageBattles()
	local maxDuration = 0
	for _, b in ipairs(current.battles) do
		local pr = b.pair
		local host = current:player(pr.host)
		local arena = host.seat
		ArenaService.clearStage(arena)
		local pa = current:player(pr.a)
		local modelA = FighterService.spawn(arena, "A", { heroId = pa.heroId, name = pa.name })
		local whoB
		if pr.creep then
			whoB = { creepId = pr.creep, name = b.specB.name }
		elseif pr.ghost then
			local g = current:player(pr.ghost)
			whoB = { heroId = g.heroId, name = g.name .. " (призрак)" }
		else
			local pb = current:player(pr.b)
			whoB = { heroId = pb.heroId, name = pb.name }
		end
		local modelB = FighterService.spawn(arena, "B", whoB)
		FighterService.spawnCourier(arena, host.name)
		local duration = math.min(M.MaxBattlePlaybackSeconds, b.result.time / M.BattleSpeed)
		maxDuration = math.max(maxDuration, duration)
		local payload = {
			arena = arena,
			kind = b.kind,
			startAt = now() + 0.75,
			speed = M.BattleSpeed,
			duration = duration,
			time = b.result.time,
			winner = b.result.winner,
			names = b.result.names,
			heroes = { pa.heroId, whoB.heroId or false },
			creepId = pr.creep or false,
			log = b.result.log,
			snaps = b.result.snaps,
			final = b.result.final,
			models = { modelA, modelB },
			participants = { tostring(pr.a), pr.b and tostring(pr.b) or false },
		}
		-- Участникам — их бой; остальным (выбывшим/зрителям) — бой первой пары
		for _, player in ipairs(Players:GetPlayers()) do
			local pid = pidOf(player)
			local mine = (pid == tostring(pr.a)) or (pr.b and pid == tostring(pr.b))
			local p = current:player(pid)
			local spectator = (not p) or (not p.alive)
			if mine or (spectator and b == current.battles[1]) then
				payload.mine = mine and true or false
				remotes.Battle:FireClient(player, payload)
			end
		end
	end
	return maxDuration
end

local function announceResults(summary, eliminated)
	for _, s in ipairs(summary) do
		if s.winner then
			local w, l = current:player(s.winner), current:player(s.loser)
			if playerById[s.winner] then
				toast(playerById[s.winner], "Победа над " .. l.name .. "! Курьер соперника -" .. s.damage)
			end
			if playerById[s.loser] then
				toast(playerById[s.loser], "Поражение от " .. w.name .. ". Курьер -" .. s.damage)
			end
		elseif playerById[s.a] then
			local text = s.won and "Победа!" or "Поражение."
			if s.creep then
				text = text .. (s.won and " Выберите снаряжение." or " Получено случайное снаряжение.")
			elseif s.damage and s.damage > 0 then
				text = text .. " Курьер -" .. s.damage
			end
			toast(playerById[s.a], text)
		end
	end
	for _, p in ipairs(eliminated) do
		toast(nil, p.name .. " выбывает! Место: " .. tostring(p.place))
	end
end

---------------------------------------------------------------------------
-- Партия
---------------------------------------------------------------------------

local function runMatch()
	-- Лобби: ждём игроков
	current = nil
	readyFlags = {}
	setPhase("lobby", M.LobbyWaitSeconds)
	while #Players:GetPlayers() < M.MinRealPlayersToStart do
		phaseEndsAt = now() + M.LobbyWaitSeconds
		markDirty()
		task.wait(1)
	end
	waitPhase(M.LobbyWaitSeconds, function()
		return #Players:GetPlayers() >= M.MaxPlayers
	end)
	if #Players:GetPlayers() < M.MinRealPlayersToStart then
		return
	end

	local infos = {}
	playerById = {}
	for i, player in ipairs(Players:GetPlayers()) do
		if i > M.MaxPlayers then
			break
		end
		table.insert(infos, { id = pidOf(player), name = player.DisplayName, isBot = false })
		playerById[pidOf(player)] = player
	end
	local seed = math.floor(os.time() + (os.clock() * 1000)) % 2147483646 + 1
	current = GameState.new({ seed = seed, players = infos })
	for _, player in ipairs(Players:GetPlayers()) do
		teleportToSpawn(player)
	end

	-- Голосование за территорию
	current:beginTerritoryVote()
	showTerritoryGuis()
	setPhase("vote", M.TerritoryVoteSeconds)
	for _, p in ipairs(current.players) do
		if p.isBot then
			task.delay(math.random() * M.TerritoryVoteSeconds * 0.6, function()
				if current and current.phase == "vote" then
					Bot.vote(current, p)
					markDirty()
				end
			end)
		end
	end
	waitPhase(M.TerritoryVoteSeconds, nil, function()
		proximityVotes()
		updateTerritoryGuis()
	end)
	local terr = current:finishTerritoryVote()
	clearTerritoryGuis()
	toast(nil, "Территория партии: " .. terr.name .. " — " .. terr.desc)

	-- Выбор гладиатора
	current:offerHeroes()
	setPhase("hero", M.HeroPickSeconds)
	for _, p in ipairs(current.players) do
		if p.isBot then
			Bot.pickHero(current, p)
		end
	end
	waitPhase(M.HeroPickSeconds, function()
		for _, p in ipairs(humans()) do
			if not p.heroId then
				return false
			end
		end
		return true
	end)
	current:finishHeroPick()

	-- Выбор черты
	current:offerTraits()
	setPhase("trait", M.TraitPickSeconds)
	for _, p in ipairs(current.players) do
		if p.isBot then
			Bot.pickTrait(current, p)
		end
	end
	waitPhase(M.TraitPickSeconds, function()
		for _, p in ipairs(humans()) do
			if not p.traitId then
				return false
			end
		end
		return true
	end)
	current:finishTraitPick()

	-- Ходы
	while not current:isOver() do
		readyFlags = {}
		current:startTurn()
		setPhase("prep", M.PrepSeconds)
		for _, p in ipairs(current:alivePlayers()) do
			if p.isBot then
				task.delay(1 + math.random() * (M.PrepSeconds * 0.4), function()
					if current and current.phase == "prep" and p.alive then
						Bot.prep(current, p)
						markDirty()
					end
				end)
			end
		end
		waitPhase(M.PrepSeconds, function()
			for _, p in ipairs(humans()) do
				if p.alive and not readyFlags[tostring(p.id)] then
					return false
				end
			end
			return true
		end)
		current:endPrep()
		current:ensurePairings()
		setPhase("pairing", M.OpponentRevealSeconds)
		task.wait(M.OpponentRevealSeconds)

		current:runBattles()
		local duration = stageBattles()
		setPhase("battle", duration + 1)
		task.wait(duration + 1)

		local summary, eliminated = current:applyResults()
		setPhase("results", M.ResultSeconds)
		announceResults(summary, eliminated)
		task.wait(M.ResultSeconds)
	end

	-- Финал
	local results = current:finish()
	setPhase("over", 15)
	for _, r in ipairs(results) do
		local player = playerById[r.id]
		if player then
			toast(player, string.format("Игра окончена! Ваше место: %d%s", r.place or 8, r.victory and " — ПОБЕДА!" or ""))
		end
	end
	task.wait(15)
	for i = 1, Config.Arena.Count do
		ArenaService.clearStage(i)
	end
end

---------------------------------------------------------------------------
-- Запуск
---------------------------------------------------------------------------

function MatchService.start()
	createRemotes()
	ArenaService.build()
	remotes.Action.OnServerEvent:Connect(onAction)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			teleportToSpawn(player)
		end)
		markDirty()
	end)
	Players.PlayerRemoving:Connect(function(player)
		-- Вышедшего игрока подхватывает бот
		local pid = pidOf(player)
		playerById[pid] = nil
		if current then
			local p = current:player(pid)
			if p then
				p.isBot = true
				p.name = p.name .. " (бот)"
			end
		end
		markDirty()
	end)

	-- Рассылка состояния не чаще ~7 раз в секунду
	task.spawn(function()
		while true do
			if dirty then
				dirty = false
				local ok, err = pcall(sendState)
				if not ok then
					warn("[MatchService] sendState: " .. tostring(err))
				end
			end
			task.wait(0.15)
		end
	end)
	-- Таймер обновляется и без изменений (раз в секунду)
	task.spawn(function()
		while true do
			task.wait(1)
			markDirty()
		end
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(runMatch)
			if not ok then
				warn("[MatchService] ошибка партии: " .. tostring(err))
				task.wait(3)
			end
		end
	end)
end

MatchService._debug = function()
	return current
end

if RunService:IsStudio() then
	-- В Studio удобно стартовать даже в одиночку
	M.MinRealPlayersToStart = 1
end

return MatchService
