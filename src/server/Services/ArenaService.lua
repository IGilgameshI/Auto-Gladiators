--!nonstrict
-- Арены: карта уже есть в плейсе (workspace.Map), арена одна на z = -450.
-- Сервис клонирует её Config.Arena.Count раз со сдвигом и умеет отдавать
-- CFrame маркеров (Fighter_A, Fighter_B, CourierPerch, Camera, ArenaCenter)
-- для арены с нужным номером. Арена 1 — оригинал.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local ArenaService = {}

local ARENA_MARKERS = { "ArenaCenter", "Fighter_A", "Fighter_B", "CourierPerch", "Camera" }

local markersFolder = nil
local arenaFolder = nil
local built = false

local function offsetFor(index)
	local o = Config.Arena.Offset
	return Vector3.new(o.x, o.y, o.z) * (index - 1)
end

-- Найти экземпляр по пути "A/B" от workspace
local function findPath(path)
	local node = Workspace
	for part in string.gmatch(path, "[^/]+") do
		if not node then
			return nil
		end
		node = node:FindFirstChild(part)
	end
	return node
end

-- CFrame маркера (часть, модель или Attachment)
local function markerCFrame(inst)
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	elseif inst:IsA("Attachment") then
		return inst.WorldCFrame
	end
	return CFrame.new()
end

function ArenaService.markers()
	if markersFolder and markersFolder.Parent then
		return markersFolder
	end
	local map = Workspace:FindFirstChild("Map")
	markersFolder = map and map:FindFirstChild("Markers") or nil
	if not markersFolder then
		warn("[ArenaService] Не найдена папка workspace.Map.Markers — использую заглушки")
	end
	return markersFolder
end

-- CFrame маркера общей площади (HubCenter, Spawn_i, Territory_i)
function ArenaService.hubMarker(name)
	local m = ArenaService.markers()
	local inst = m and m:FindFirstChild(name)
	if inst then
		return markerCFrame(inst)
	end
	return nil
end

-- CFrame маркера арены с номером index
function ArenaService.arenaMarker(index, name)
	local m = ArenaService.markers()
	local inst = m and m:FindFirstChild(name)
	local base
	if inst then
		base = markerCFrame(inst)
	else
		-- Заглушка: арена в точке (0, 5, ArenaZ)
		local center = CFrame.new(0, 5, Config.Arena.ArenaZ)
		local fallback = {
			ArenaCenter = center,
			Fighter_A = center * CFrame.new(-12, 0, 0) * CFrame.Angles(0, math.rad(-90), 0),
			Fighter_B = center * CFrame.new(12, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
			CourierPerch = center * CFrame.new(0, 0, -20),
			Camera = CFrame.lookAt(center.Position + Vector3.new(0, 25, 45), center.Position),
		}
		base = fallback[name] or center
	end
	return base + offsetFor(index)
end

local function shift(inst, offset)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() + offset)
	elseif inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame + offset
	else
		for _, child in ipairs(inst:GetChildren()) do
			shift(child, offset)
		end
	end
end

-- Клонирование арены. Вызывается один раз при старте сервера.
function ArenaService.build()
	if built then
		return
	end
	built = true
	arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "ArenaClones"
	arenaFolder.Parent = Workspace

	-- Собираем исходники для клонирования
	local sources = {}
	for _, path in ipairs(Config.Arena.CloneSources) do
		local inst = findPath(path)
		if inst then
			table.insert(sources, inst)
		end
	end
	-- Детали самой модели Map рядом с центром арены (если арена лежит прямо в Map)
	local map = Workspace:FindFirstChild("Map")
	local loose = {}
	local radius = Config.Arena.CloneMapRadius
	if map and radius and radius > 0 then
		local center = ArenaService.arenaMarker(1, "ArenaCenter").Position
		for _, child in ipairs(map:GetChildren()) do
			if child.Name ~= "Markers" and child.Name ~= "Arena" then
				local pos = nil
				if child:IsA("BasePart") then
					pos = child.Position
				elseif child:IsA("Model") then
					pos = child:GetPivot().Position
				end
				if pos and (pos - center).Magnitude <= radius then
					table.insert(loose, child)
				end
			end
		end
	end
	if #sources == 0 and #loose == 0 then
		warn("[ArenaService] Нечего клонировать: нет workspace.Dressing.Arena и деталей арены в workspace.Map")
	end

	for index = 2, Config.Arena.Count do
		local holder = Instance.new("Folder")
		holder.Name = "Arena_" .. index
		holder.Parent = arenaFolder
		local offset = offsetFor(index)
		for _, src in ipairs(sources) do
			local ok, clone = pcall(function()
				return src:Clone()
			end)
			if ok and clone then
				shift(clone, offset)
				clone.Parent = holder
			end
		end
		for _, src in ipairs(loose) do
			local ok, clone = pcall(function()
				return src:Clone()
			end)
			if ok and clone then
				shift(clone, offset)
				clone.Parent = holder
			end
		end
	end
end

-- Папка для бойцов/курьеров арены (очищается между боями)
function ArenaService.stage(index)
	local root = Workspace:FindFirstChild("ArenaStage")
	if not root then
		local f = Instance.new("Folder")
		f.Name = "ArenaStage"
		f.Parent = Workspace
		root = f
	end
	local name = "Stage_" .. index
	local stage = (root):FindFirstChild(name)
	if not stage then
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = root
		stage = f
	end
	return stage
end

function ArenaService.clearStage(index)
	local stage = ArenaService.stage(index)
	stage:ClearAllChildren()
end

ArenaService.ArenaMarkers = ARENA_MARKERS
return ArenaService
