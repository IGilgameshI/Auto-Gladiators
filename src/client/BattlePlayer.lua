--!nonstrict
-- Воспроизведение журнала боя: полоски HP/маны по снимкам, строки журнала,
-- анимации моделей (ID из Config.Heroes[id].anims, 0 = нет анимации),
-- всплывающие цифры урона и камера на арене.
-- Клиент ничего не решает: он только показывает то, что посчитал сервер.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))

local BattlePlayer = {}

local view = nil
local playing = nil -- текущий бой
local animCache = {} -- model -> name -> AnimationTrack

local DTYPE_COLOR = {
	phys = "#FFFFFF",
	magic = "#7FB0FF",
	pure = "#FFE070",
	poison = "#9CE07A",
}

function BattlePlayer.init(battleView)
	view = battleView
end

---------------------------------------------------------------------------
-- Анимации
---------------------------------------------------------------------------

local function animId(model, name)
	local heroId = model and model:GetAttribute("HeroId")
	local hero = heroId and Config.Heroes[heroId]
	local id = hero and hero.anims and hero.anims[name]
	if not id or id == 0 then
		id = Config.FallbackAnims[name]
	end
	if not id or id == 0 then
		return nil
	end
	if type(id) == "number" then
		return "rbxassetid://" .. id
	end
	return id
end

local function playAnim(model, name, looped)
	if not model or not model.Parent then
		return
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local id = animId(model, name)
	if not id then
		return
	end
	animCache[model] = animCache[model] or {}
	local track = animCache[model][name]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, t = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if not ok then
			return
		end
		track = t
		track.Looped = looped and true or false
		animCache[model][name] = track
	end
	track:Play(0.1)
end

-- Простая «отдача» без анимаций: модель дёргается к противнику
local function lunge(model, toward)
	if not model or not model.PrimaryPart or not toward or not toward.PrimaryPart then
		return
	end
	local root = model.PrimaryPart
	local start = model:GetPivot()
	local dir = (toward.PrimaryPart.Position - root.Position)
	if dir.Magnitude < 0.1 then
		return
	end
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local value = Instance.new("CFrameValue")
	value.Value = start
	local conn = value.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local out = TweenService:Create(value, TweenInfo.new(0.08), { Value = start + dir * 1.5 })
	out:Play()
	out.Completed:Wait()
	local back = TweenService:Create(value, TweenInfo.new(0.12), { Value = start })
	back:Play()
	back.Completed:Wait()
	conn:Disconnect()
	value:Destroy()
end

local function popup(model, text, color)
	local head = model and (model:FindFirstChild("Head") or model.PrimaryPart)
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.StudsOffset = Vector3.new(math.random(-15, 15) / 10, 2, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.RichText = true
	label.TextStrokeTransparency = 0.2
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = "<font color='" .. (color or "#FFFFFF") .. "'>" .. text .. "</font>"
	label.Parent = bb
	bb.Parent = Workspace.CurrentCamera
	TweenService:Create(bb, TweenInfo.new(0.9), { StudsOffset = bb.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1, function()
		bb:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Камера
---------------------------------------------------------------------------

local savedCameraType = nil
local function focusCamera(arena)
	local cam = Workspace.CurrentCamera
	local markers = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Markers")
	local marker = markers and markers:FindFirstChild("Camera")
	local cf
	local o = Config.Arena.Offset
	local offset = Vector3.new(o.x, o.y, o.z) * (arena - 1)
	if marker then
		if marker:IsA("BasePart") then
			cf = marker.CFrame
		elseif marker:IsA("Model") then
			cf = marker:GetPivot()
		elseif marker:IsA("Attachment") then
			cf = marker.WorldCFrame
		end
	end
	if not cf then
		local center = Vector3.new(0, 5, Config.Arena.ArenaZ)
		cf = CFrame.lookAt(center + Vector3.new(0, 25, 45), center)
	end
	savedCameraType = savedCameraType or cam.CameraType
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = cf + offset
end

local function releaseCamera()
	local cam = Workspace.CurrentCamera
	cam.CameraType = savedCameraType or Enum.CameraType.Custom
	savedCameraType = nil
end

---------------------------------------------------------------------------
-- Воспроизведение
---------------------------------------------------------------------------

local function describe(ev, names)
	local kind, side = ev[2], ev[3]
	local who = names[side] or "?"
	local other = names[3 - side] or "?"
	if kind == "atk" then
		local dmg, crit, evade = ev[4], ev[5], ev[6]
		local s = string.format("%s бьёт %s: %d", who, other, dmg)
		if crit == 1 then
			s = s .. " <font color='#FFD040'>КРИТ</font>"
		end
		if evade == 1 then
			s = s .. " <font color='#9CE07A'>(уклонение)</font>"
		end
		return s
	elseif kind == "dmg" then
		local src = ev[6] and (" [" .. tostring(ev[6]) .. "]") or ""
		return string.format("%s%s: <font color='%s'>%d %s</font>", who, src, DTYPE_COLOR[ev[5]] or "#FFFFFF", ev[4], Text.DamageType[ev[5]] or "")
	elseif kind == "ult" then
		return string.format("<font color='#7FB0FF'><b>%s применяет ульт!</b></font>", who)
	elseif kind == "death" then
		return string.format("<font color='#FF6060'><b>%s повержен</b></font>", who)
	elseif kind == "revive" then
		return string.format("<font color='#FFE070'><b>%s возрождается%s</b></font>", who, ev[5] and (" (" .. tostring(ev[5]) .. ")") or "")
	elseif kind == "ward" then
		return string.format("%s призывает стража (%d HP)", who, ev[4] or 0)
	elseif kind == "wardDeath" then
		return string.format("Страж %s разрушен", who)
	elseif kind == "stun" then
		return string.format("%s оглушён на %.1f с", who, ev[4] or 0)
	elseif kind == "block" then
		return string.format("%s блокирует атаку", who)
	elseif kind == "special" then
		return string.format("<font color='#FFB070'>%s: %s</font>", who, tostring(ev[4]))
	elseif kind == "marks" then
		return string.format("%s взрывает %d звуковых меток", who, ev[4] or 0)
	end
	return nil
end

function BattlePlayer.play(payload)
	local token = {}
	playing = token
	view.start(payload)
	local models = payload.models or {}
	for _, m in ipairs(models) do
		if m then
			playAnim(m, "Idle", true)
		end
	end
	if payload.mine then
		focusCamera(payload.arena)
	end
	local speed = payload.speed or 1
	local startAt = payload.startAt or Workspace:GetServerTimeNow()
	local evIndex, snapIndex = 1, 1
	local log, snaps = payload.log or {}, payload.snaps or {}
	local names = payload.names or { "?", "?" }
	local duration = payload.duration or 30

	local conn
	conn = RunService.RenderStepped:Connect(function()
		if playing ~= token then
			conn:Disconnect()
			return
		end
		local t = (Workspace:GetServerTimeNow() - startAt) * speed
		if t < 0 then
			return
		end
		-- Если бой длиннее предела показа — проматываем быстрее
		if payload.time and payload.time / speed > duration then
			t = t * (payload.time / speed) / duration
		end
		while snapIndex <= #snaps and snaps[snapIndex][1] <= t do
			view.snapshot(snaps[snapIndex])
			snapIndex = snapIndex + 1
		end
		local shown = 0
		while evIndex <= #log and log[evIndex][1] <= t do
			local ev = log[evIndex]
			evIndex = evIndex + 1
			local kind, side = ev[2], ev[3]
			local attacker = models[side]
			local target = models[3 - side]
			if kind == "atk" then
				playAnim(attacker, "Attack")
				if animId(attacker, "Attack") == nil then
					task.spawn(lunge, attacker, target)
				end
				if ev[4] > 0 then
					playAnim(target, "Hit")
					popup(target, tostring(ev[4]), ev[5] == 1 and "#FFD040" or "#FFFFFF")
				end
			elseif kind == "dmg" then
				popup(target, tostring(ev[4]), DTYPE_COLOR[ev[5]])
			elseif kind == "ult" then
				playAnim(attacker, "Ult")
				popup(attacker, "УЛЬТ!", "#7FB0FF")
			elseif kind == "death" then
				playAnim(models[side], "Death")
			end
			-- В журнал пишем не всё подряд, чтобы не было лавины строк
			if kind ~= "atk" or shown < 3 then
				local line = describe(ev, names)
				if line then
					view.log(line)
					shown = shown + 1
				end
			end
		end
		if evIndex > #log and snapIndex > #snaps then
			conn:Disconnect()
			local winner = names[payload.winner] or "?"
			view.finish("Победитель: <b>" .. winner .. "</b>  (" .. string.format("%.1f", payload.time or 0) .. " с)")
			local w = models[payload.winner]
			playAnim(w, "Victory")
		end
	end)
end

-- Конец фазы боя: вернуть камеру и скрыть панели
function BattlePlayer.stop()
	playing = nil
	releaseCamera()
	view.hide()
	for model in pairs(animCache) do
		if not model.Parent then
			animCache[model] = nil
		end
	end
end

return BattlePlayer
