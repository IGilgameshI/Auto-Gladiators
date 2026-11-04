--!nonstrict
-- Вид боя: HP/мана/стаки обоих бойцов и журнал боя.
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local BattleView = {}

local STACK_ORDER = { { "poison", "Яд", 4 }, { "ice", "Мороз", 5 }, { "fury", "Ярость", 6 }, { "shield", "Щит", 7 }, { "injury", "Уязв.", 8 } }

function BattleView.new(parent)
	local self = {}
	local root = Util.panel({
		Name = "Battle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.new(0, 720, 0, 132),
		Visible = false,
		Parent = parent,
	})
	Util.padding(8).Parent = root
	local title = Util.label({ Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.FontBold, TextSize = 15, Parent = root })

	local sides = {}
	for side = 1, 2 do
		local col = Util.create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0.48, 0, 1, -22),
			Position = UDim2.new(side == 1 and 0 or 0.52, 0, 0, 22),
			Parent = root,
		})
		local name = Util.label({ Size = UDim2.new(1, 0, 0, 18), Font = Theme.FontBold, TextSize = 14, TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, Parent = col })
		local _, setHp = Util.bar({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 20), Parent = col }, Theme.Hp)
		local _, setMana = Util.bar({ Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 44), Parent = col }, Theme.Mana)
		local stacks = Util.label({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 60), TextSize = 13, TextXAlignment = side == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right, Parent = col })
		sides[side] = { name = name, setHp = setHp, setMana = setMana, stacks = stacks }
	end

	-- Журнал боя (справа снизу)
	local logPanel = Util.panel({
		Name = "BattleLog",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.new(0, 360, 0, 260),
		Visible = false,
		Parent = parent,
	})
	Util.padding(6).Parent = logPanel
	local logScroll = Util.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		Parent = logPanel,
	})
	Util.list(Enum.FillDirection.Vertical, 1).Parent = logScroll
	local logCount = 0

	function self.start(payload)
		root.Visible = true
		logPanel.Visible = true
		Util.clear(logScroll)
		logCount = 0
		local kind = payload.kind == "creep" and "Бой с крипом" or (payload.kind == "ghost" and "Бой с призраком" or "Бой")
		title.Text = kind .. (payload.mine and "" or "  <font color='#A0A0B8'>(наблюдение)</font>")
		for side = 1, 2 do
			sides[side].name.Text = Util.escape(payload.names[side] or "?")
		end
	end

	function self.snapshot(snap)
		for side = 1, 2 do
			local d = snap[side + 1]
			local ui = sides[side]
			local hp, maxHp, mana = d[1], d[2], d[3]
			ui.setHp(maxHp > 0 and hp / maxHp or 0, string.format("%d / %d", hp, maxHp), (hp / math.max(1, maxHp)) > 0.3 and Theme.Hp or Theme.HpLow)
			ui.setMana(mana / 100, tostring(mana))
			local parts = {}
			for _, st in ipairs(STACK_ORDER) do
				local v = d[st[3]]
				if v and v > 0 then
					table.insert(parts, string.format("<font color='%s'>%s %d</font>", Util.hex(Theme.Stacks[st[1]]), st[2], v))
				end
			end
			if d[9] and d[9] > 0 then
				table.insert(parts, "<font color='#F0F096'>Стражи " .. d[9] .. "</font>")
			end
			ui.stacks.Text = table.concat(parts, "  ")
		end
	end

	function self.log(text, color)
		logCount = logCount + 1
		Util.label({
			Size = UDim2.new(1, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 13,
			Text = text,
			TextColor3 = color or Theme.Text,
			LayoutOrder = logCount,
			Parent = logScroll,
		})
		-- Держим не больше 120 строк
		if logCount > 120 then
			for _, child in ipairs(logScroll:GetChildren()) do
				if child:IsA("TextLabel") and child.LayoutOrder <= logCount - 120 then
					child:Destroy()
				end
			end
		end
		logScroll.CanvasPosition = Vector2.new(0, 1e6)
	end

	function self.finish(text)
		title.Text = text
	end

	function self.hide()
		root.Visible = false
		logPanel.Visible = false
	end

	return self
end

return BattleView
