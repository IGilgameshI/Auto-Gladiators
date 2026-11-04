--!nonstrict
-- Магазин: 5 карт + реролл. Клиент только просит, решает сервер.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))
local Progression = require(Shared:WaitForChild("Game"):WaitForChild("Progression"))
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local ShopPanel = {}

function ShopPanel.new(parent, actions)
	local self = {}
	local slots = Config.Shop.Slots
	local root = Util.panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0, slots * 168 + 150, 0, 182),
		Parent = parent,
	})
	Util.padding(8).Parent = root

	local cardsRow = Util.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -140, 1, 0),
		Parent = root,
	})
	Util.list(Enum.FillDirection.Horizontal, 8).Parent = cardsRow

	local side = Util.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 132, 1, 0),
		Position = UDim2.new(1, -132, 0, 0),
		Parent = root,
	})
	local rerollBtn = Util.button({
		Size = UDim2.new(1, 0, 0, 64),
		Text = "Обновить",
		BackgroundColor3 = Theme.Accent2,
		Parent = side,
	}, function()
		actions.reroll()
	end)
	local info = Util.label({
		Size = UDim2.new(1, 0, 1, -72),
		Position = UDim2.fromOffset(0, 72),
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = side,
	})

	local slotFrames = {}
	local current = {}
	for i = 1, slots do
		local f = Util.create("TextButton", {
			Name = "Slot" .. i,
			Size = UDim2.new(0, 160, 1, 0),
			BackgroundColor3 = Theme.PanelLight,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = i,
			Parent = cardsRow,
		})
		Util.corner(8).Parent = f
		local stroke = Util.stroke(Theme.Rarity.n, 2)
		stroke.Parent = f
		Util.padding(6).Parent = f
		local title = Util.label({ Name = "Title", Size = UDim2.new(1, 0, 0, 36), Font = Theme.FontBold, TextSize = 15, Parent = f })
		local styles = Util.label({ Name = "Styles", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 36), TextSize = 12, TextColor3 = Theme.TextDim, Parent = f })
		local desc = Util.label({ Name = "Desc", Size = UDim2.new(1, 0, 1, -80), Position = UDim2.fromOffset(0, 54), TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, Parent = f })
		local footer = Util.label({ Name = "Footer", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), Font = Theme.FontBold, TextSize = 14, Parent = f })
		f.Activated:Connect(function()
			if current[i] then
				actions.buy(i)
			end
		end)
		Util.tooltip(f, function()
			local s = current[i]
			if not s then
				return nil
			end
			local card = Progression.cardsById()[s.id]
			local next = math.min(s.owned + 1, Config.Shop.MaxStars)
			return string.format(
				"<b>%s</b> (%s)\n%s\n\nЗвезда %d: %s\nПо звёздам: %s\nОпыт стиля за звезду: %d\nОсталось в пуле: %d",
				Util.escape(card.name), Text.RarityName[card.r], Text.styleNames(card), next, Util.escape(Text.cardDesc(card, next)), Text.cardValues(card),
				Config.Styles.XpPerStar[card.r], s.left
			)
		end)
		slotFrames[i] = { frame = f, stroke = stroke, title = title, styles = styles, desc = desc, footer = footer }
	end

	function self.update(msg)
		local me = msg.me
		root.Visible = (msg.phase == "prep") and me ~= nil and me.alive
		if not me then
			return
		end
		for i = 1, slots do
			local s = me.shop[i]
			local ui = slotFrames[i]
			current[i] = s or nil
			if s then
				local card = Progression.cardsById()[s.id]
				local next = math.min(s.owned + 1, Config.Shop.MaxStars)
				ui.frame.BackgroundTransparency = 0
				ui.stroke.Color = Theme.Rarity[card.r]
				ui.title.Text = Util.escape(card.name)
				ui.title.TextColor3 = Theme.Rarity[card.r]
				ui.styles.Text = Text.styleNames(card)
				ui.desc.Text = Util.escape(Text.cardDesc(card, next))
				local canBuy = me.gold >= s.price
				ui.footer.Text = string.format("<font color='%s'>%d з.</font>  %s", Util.hex(canBuy and Theme.Gold or Theme.Bad), s.price, Text.stars(s.owned))
			else
				ui.frame.BackgroundTransparency = 0.6
				ui.stroke.Color = Theme.PanelLight
				ui.title.Text = ""
				ui.styles.Text = ""
				ui.desc.Text = "<i>пусто</i>"
				ui.footer.Text = ""
			end
		end
		if me.freeRerolls > 0 then
			rerollBtn.Text = "Обновить\n<font size='13'>бесплатно: " .. me.freeRerolls .. "</font>"
		else
			rerollBtn.Text = "Обновить\n<font size='13'>" .. me.rerollCost .. " з.</font>"
		end
		local lines = {}
		if me.lastIncome then
			table.insert(lines, "<b>Доход за ход:</b>")
			for k, v in pairs(me.lastIncome) do
				table.insert(lines, Util.escape(k) .. ": +" .. v)
			end
		end
		if me.nextOpponent then
			table.insert(lines, "\n<font color='#FFB070'>Соперник: " .. Util.escape(me.nextOpponent) .. "</font>")
		end
		info.Text = table.concat(lines, "\n")
	end

	return self
end

return ShopPanel
