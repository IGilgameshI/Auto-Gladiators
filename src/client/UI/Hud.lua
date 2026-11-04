--!nonstrict
-- Верхняя панель: фаза, таймер, ход, территория, золото, HP курьера, уровень.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Text = require(Shared:WaitForChild("Text"))
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Hud = {}

function Hud.new(parent, actions)
	local self = {}
	local bar = Util.panel({
		Name = "TopBar",
		Size = UDim2.new(1, -16, 0, 52),
		Position = UDim2.fromOffset(8, 8),
		Parent = parent,
	})
	Util.padding(6).Parent = bar

	local phase = Util.label({ Size = UDim2.new(0.28, 0, 1, 0), Font = Theme.FontBold, TextSize = 18, Parent = bar })
	local center = Util.label({
		Size = UDim2.new(0.36, 0, 1, 0),
		Position = UDim2.fromScale(0.28, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		Parent = bar,
	})
	local right = Util.label({
		Size = UDim2.new(0.26, 0, 1, 0),
		Position = UDim2.fromScale(0.64, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.FontBold,
		TextSize = 17,
		Parent = bar,
	})
	local ready = Util.button({
		Size = UDim2.new(0.09, 0, 1, 0),
		Position = UDim2.fromScale(0.91, 0),
		Text = "Готов",
		TextSize = 15,
		BackgroundColor3 = Theme.Good,
		Parent = bar,
	}, function()
		actions.ready()
	end)

	local state = nil
	function self.update(msg)
		state = msg
		local me = msg.me
		local pub = msg.pub
		local name = Text.phaseName(msg.phase)
		if msg.phase == "battle" and pub and pub.creepTurn then
			name = "Бой с крипами"
		end
		phase.Text = name
		local parts = {}
		if pub then
			table.insert(parts, "Ход <b>" .. pub.turn .. "</b>")
			if pub.creepTurn then
				table.insert(parts, "<font color='#9CE07A'>ход крипов</font>")
			end
			if pub.territory then
				table.insert(parts, "<font color='#FFB070'>" .. Util.escape(pub.territory.name) .. "</font>")
			end
		elseif msg.phase == "lobby" then
			table.insert(parts, "Игроков на сервере: " .. tostring(msg.lobbyCount or 0) .. " / " .. Config.Match.MaxPlayers)
		end
		center.Text = table.concat(parts, "  •  ")
		if me then
			right.Text = string.format(
				"<font color='%s'>%d з.</font>   <font color='%s'>♥ %d</font>   ур. %d",
				Util.hex(Theme.Gold), me.gold, Util.hex(me.hp > 30 and Theme.Hp or Theme.HpLow), me.hp, me.level
			)
		else
			right.Text = (msg.inMatch and "Зритель" or "")
		end
		ready.Visible = (msg.phase == "prep") and me ~= nil and me.alive
		if me and me.ready then
			ready.Text = "✓ Готов"
			ready.BackgroundColor3 = Theme.PanelLight
		else
			ready.Text = "Готов"
			ready.BackgroundColor3 = Theme.Good
		end
	end

	-- Таймер обновляется каждый кадр
	function self.tick()
		if not state then
			return
		end
		local left = math.max(0, math.floor((state.endsAt or 0) - Workspace:GetServerTimeNow() + 0.5))
		local name = Text.phaseName(state.phase)
		if state.phase == "battle" and state.pub and state.pub.creepTurn then
			name = "Бой с крипами"
		end
		phase.Text = string.format("%s  <font color='%s'>%d с</font>", name, Util.hex(left <= 5 and Theme.Bad or Theme.Gold), left)
	end

	return self
end

return Hud
