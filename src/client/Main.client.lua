--!nonstrict
-- Клиент: весь интерфейс. Получает состояние от сервера и отправляет
-- запросы действий. Ничего не решает сам.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Text = require(Shared:WaitForChild("Text"))
local GameState = require(Shared:WaitForChild("Game"):WaitForChild("GameState"))

local UI = script.Parent:WaitForChild("UI")
local Util = require(UI:WaitForChild("Util"))
local Hud = require(UI:WaitForChild("Hud"))
local ShopPanel = require(UI:WaitForChild("ShopPanel"))
local StylesPanel = require(UI:WaitForChild("StylesPanel"))
local PlayersPanel = require(UI:WaitForChild("PlayersPanel"))
local CardsPanel = require(UI:WaitForChild("CardsPanel"))
local ChoiceModal = require(UI:WaitForChild("ChoiceModal"))
local BattleView = require(UI:WaitForChild("BattleView"))
local Toasts = require(UI:WaitForChild("Toasts"))
local BattlePlayer = require(script.Parent:WaitForChild("BattlePlayer"))

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild(Net.FolderName)
local Remotes = {}
for key, name in pairs(Net.Remotes) do
	Remotes[key] = remotesFolder:WaitForChild(name)
end

local function send(action, arg)
	Remotes.Action:FireServer(action, arg)
end

---------------------------------------------------------------------------
-- Построение интерфейса
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "AutoGladiatorsUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
Util.setTooltipLayer(gui)

local actions = {
	ready = function()
		send(Net.Actions.Ready)
	end,
	reroll = function()
		send(Net.Actions.Reroll)
	end,
	buy = function(slot)
		send(Net.Actions.Buy, slot)
	end,
}

local hud = Hud.new(gui, actions)
local styles = StylesPanel.new(gui)
local playersPanel = PlayersPanel.new(gui)
local shop = ShopPanel.new(gui, actions)
local cards = CardsPanel.new(gui)
local battleView = BattleView.new(gui)
local modal = ChoiceModal.new(gui)
local toasts = Toasts.new(gui)
BattlePlayer.init(battleView)

---------------------------------------------------------------------------
-- Выборы (модальные окна)
---------------------------------------------------------------------------
local function heroOption(id)
	local h = Config.Heroes[id]
	local styleNames = {}
	for i, s in ipairs(h.styles) do
		styleNames[i] = Config.Styles.Data[s].name
	end
	return {
		title = Util.escape(h.name),
		desc = string.format(
			"<font color='#A0A0B8'>Стиль: %s\nHP %d, атака %d, интервал %.2f</font>\n\n<b>%s</b>: %s\n\n<b>Ульт «%s»</b>: %s",
			table.concat(styleNames, "/"), h.hp, h.atk, h.interval,
			Util.escape(h.passive.name), Util.escape(Text.heroText(h.passive)),
			Util.escape(h.ult.name), Util.escape(Text.heroText(h.ult))
		),
	}
end

local function updateChoices(msg)
	local me = msg.me
	local pub = msg.pub
	if not me or not pub then
		modal.hide()
		return
	end
	if msg.phase == "vote" then
		local opts = {}
		for i, id in ipairs(pub.territoryChoices) do
			local t = GameState.TerritoriesById[id]
			opts[i] = {
				title = Util.escape(t.name) .. "  [" .. tostring(pub.votes[i] or 0) .. "]",
				desc = Util.escape(t.desc) .. "\n\n<font color='#A0A0B8'>Можно встать у маркера территории на площади.</font>",
			}
		end
		modal.show("vote", "Голосование за территорию партии", opts, function(i)
			send(Net.Actions.Vote, i)
		end, { keepOpen = true, selected = me.vote })
		return
	end
	if msg.phase == "hero" and not me.heroId and me.heroOffers then
		local opts = {}
		for i, id in ipairs(me.heroOffers) do
			opts[i] = heroOption(id)
		end
		modal.show("hero", "Выберите гладиатора", opts, function(i)
			send(Net.Actions.PickHero, i)
		end)
		return
	end
	if msg.phase == "trait" and not me.traitId and me.traitOffers then
		local opts = {}
		for i, id in ipairs(me.traitOffers) do
			local t = GameState.TraitsById[id]
			opts[i] = { title = Util.escape(t.name), desc = Util.escape(t.desc) }
		end
		modal.show("trait", "Выберите черту", opts, function(i)
			send(Net.Actions.PickTrait, i)
		end)
		return
	end
	if msg.phase == "prep" and me.alive then
		if me.artifactOffer then
			local opts = {}
			for i, id in ipairs(me.artifactOffer) do
				local a = GameState.ArtifactsById[id]
				opts[i] = { title = Util.escape(a.name), desc = Util.escape(a.desc) }
			end
			modal.show("art" .. pub.turn, "Артефакт: выберите 1 из 3", opts, function(i)
				send(Net.Actions.PickArtifact, i)
			end)
			return
		end
		if me.itemOffer then
			local opts = {}
			for i, id in ipairs(me.itemOffer) do
				local it = GameState.ItemsById[id]
				opts[i] = { title = Util.escape(it.name) .. "  <font color='#A0A0B8'>ур." .. it.tier .. "</font>", desc = Util.escape(it.desc) }
			end
			modal.show("item" .. pub.turn, "Снаряжение: выберите 1 из 3", opts, function(i)
				send(Net.Actions.PickItem, i)
			end)
			return
		end
		if me.talentOffer then
			local hero = Config.Heroes[me.heroId]
			local list = hero.talents[me.talentOffer.level]
			local opts = {}
			for i, t in ipairs(list) do
				opts[i] = { title = Util.escape(t.name), desc = Util.escape(t.desc) }
			end
			modal.show("talent" .. me.talentOffer.level, "Талант уровня " .. me.talentOffer.level, opts, function(i)
				send(Net.Actions.PickTalent, i)
			end)
			return
		end
	end
	modal.hide()
end

---------------------------------------------------------------------------
-- Сеть
---------------------------------------------------------------------------
local lastPhase = nil
Remotes.State.OnClientEvent:Connect(function(msg)
	hud.update(msg)
	styles.update(msg)
	playersPanel.update(msg, tostring(player.UserId))
	shop.update(msg)
	cards.update(msg)
	updateChoices(msg)
	if lastPhase == "battle" and msg.phase ~= "battle" then
		BattlePlayer.stop()
	end
	lastPhase = msg.phase
end)

Remotes.Battle.OnClientEvent:Connect(function(payload)
	BattlePlayer.play(payload)
end)

Remotes.Toast.OnClientEvent:Connect(function(text)
	toasts.show(text)
end)

RunService.RenderStepped:Connect(function()
	hud.tick()
end)
