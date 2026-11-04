--!nonstrict
-- Модели бойцов на аренах.
-- Герой: ServerStorage.Gladiators.<Config.Heroes[id].model>
-- Крип:  ServerStorage.Creeps.<id> (необязательно)
-- Курьер: ServerStorage.Couriers.Default (необязательно)
-- Если модели нет — используется заглушка: стандартный R15-риг.
-- Анимации проигрывает клиент по ID из Config (атрибуты HeroId/CreepId).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ArenaService = require(script.Parent.ArenaService)

local FighterService = {}

local fallbackRig = nil

-- Заглушка: R15-риг из пустого HumanoidDescription
local function buildFallbackRig()
	if fallbackRig then
		return fallbackRig
	end
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and rig then
		fallbackRig = rig
	else
		-- Совсем простая заглушка, если риг не создался (например, в тестовом режиме)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.Parent = model
		local torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Size = Vector3.new(2, 2.5, 1)
		torso.Parent = model
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.5, 1.5, 1.5)
		head.Parent = model
		torso.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
		head.CFrame = root.CFrame * CFrame.new(0, 2.5, 0)
		local w1 = Instance.new("WeldConstraint")
		w1.Part0, w1.Part1 = root, torso
		w1.Parent = root
		local w2 = Instance.new("WeldConstraint")
		w2.Part0, w2.Part1 = torso, head
		w2.Parent = torso
		local hum = Instance.new("Humanoid")
		hum.Parent = model
		model.PrimaryPart = root
		fallbackRig = model
	end
	return fallbackRig
end

local function findTemplate(folderName, modelName)
	if not modelName then
		return nil
	end
	local folder = ServerStorage:FindFirstChild(folderName)
	local m = folder and folder:FindFirstChild(modelName)
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function prepare(model, displayName, color)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.WalkSpeed = Config.Arena.FighterWalkSpeed
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = (d.Name == "HumanoidRootPart") or (model.PrimaryPart == d)
			d.CanCollide = false
			if color and d.Name ~= "HumanoidRootPart" then
				d.Color = color
			end
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	if not model.PrimaryPart then
		model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	end
	if model.PrimaryPart then
		model.PrimaryPart.Anchored = true
	end
	-- Табличка с именем над головой
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "NameTag"
		bb.Size = UDim2.fromOffset(200, 40)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 150
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Text = displayName
		label.Parent = bb
		bb.Parent = head
	end
end

-- Цвет заглушки по герою, чтобы бойцов можно было различить
local HERO_COLORS = {
	narato = Color3.fromRGB(255, 150, 40),
	zazke = Color3.fromRGB(70, 70, 140),
	koku = Color3.fromRGB(255, 120, 60),
	tuffy = Color3.fromRGB(220, 50, 50),
	sound_hashira = Color3.fromRGB(200, 170, 60),
	blood_demon = Color3.fromRGB(140, 20, 40),
}

-- Создать бойца на арене. side = "A" | "B"
-- who = { heroId = ..., creepId = ..., name = ... }
function FighterService.spawn(arenaIndex, side, who)
	local template = nil
	local color = nil
	if who.heroId then
		local hero = Config.Heroes[who.heroId]
		template = findTemplate("Gladiators", hero and hero.model)
		if not template then
			color = HERO_COLORS[who.heroId]
		end
	elseif who.creepId then
		template = findTemplate("Creeps", who.creepId)
		if not template then
			color = Color3.fromRGB(90, 140, 90)
		end
	end
	local model = (template or buildFallbackRig()):Clone()
	model.Name = (side == "A" and "FighterA" or "FighterB")
	prepare(model, who.name or "?", color)
	model:SetAttribute("Side", side == "A" and 1 or 2)
	if who.heroId then
		model:SetAttribute("HeroId", who.heroId)
	end
	if who.creepId then
		model:SetAttribute("CreepId", who.creepId)
	end
	local cf = ArenaService.arenaMarker(arenaIndex, side == "A" and "Fighter_A" or "Fighter_B")
	-- Ставим модель так, чтобы ноги были на маркере
	local _, size = model:GetBoundingBox()
	model:PivotTo(cf + Vector3.new(0, size.Y / 2, 0))
	model.Parent = ArenaService.stage(arenaIndex)
	return model
end

-- Курьер хозяина арены
function FighterService.spawnCourier(arenaIndex, ownerName)
	local template = findTemplate("Couriers", "Default")
	local model
	if template then
		model = template:Clone()
	else
		model = Instance.new("Model")
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Shape = Enum.PartType.Ball
		body.Size = Vector3.new(3, 3, 3)
		body.Color = Color3.fromRGB(255, 220, 120)
		body.Material = Enum.Material.Neon
		body.Anchored = true
		body.CanCollide = false
		body.Parent = model
		model.PrimaryPart = body
	end
	model.Name = "Courier"
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model:PivotTo(ArenaService.arenaMarker(arenaIndex, "CourierPerch") + Vector3.new(0, 2, 0))
	model:SetAttribute("Owner", ownerName)
	model.Parent = ArenaService.stage(arenaIndex)
	return model
end

return FighterService
