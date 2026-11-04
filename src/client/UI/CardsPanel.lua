--!nonstrict
-- «Мои карты»: изученные карты со звёздами, снаряжение, артефакты, черта,
-- таланты, журнал сообщений. Открывается кнопкой.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Text = require(Shared:WaitForChild("Text"))
local Progression = require(Shared:WaitForChild("Game"):WaitForChild("Progression"))
local GameState = require(Shared.Game:WaitForChild("GameState"))
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local CardsPanel = {}

local function talentName(heroId, id)
	local hero = Config.Heroes[heroId]
	if not hero then
		return id
	end
	for _, list in pairs(hero.talents) do
		for _, t in ipairs(list) do
			if t.id == id then
				return t.name, t.desc
			end
		end
	end
	return id
end

function CardsPanel.new(parent)
	local self = {}
	local open = false
	local toggle = Util.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -8),
		Size = UDim2.fromOffset(150, 40),
		Text = "Мои карты",
		BackgroundColor3 = Theme.PanelLight,
		Parent = parent,
	})
	local root = Util.panel({
		Name = "MyCards",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.new(0, 760, 0, 520),
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	})
	Util.padding(10).Parent = root
	local close = Util.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(32, 32), Text = "✕", ZIndex = 11, Parent = root })
	local scroll = Util.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0.62, 0, 1, -8),
		Position = UDim2.fromOffset(0, 0),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ZIndex = 11,
		Parent = root,
	})
	Util.list(Enum.FillDirection.Vertical, 4).Parent = scroll
	local sideText = Util.label({
		Size = UDim2.new(0.36, 0, 1, -40),
		Position = UDim2.new(0.64, 0, 0, 40),
		TextSize = 13,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 11,
		Parent = root,
	})

	local function setOpen(v)
		open = v
		root.Visible = v
		Util.hideTooltip()
	end
	toggle.Activated:Connect(function()
		setOpen(not open)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local lastKey = ""
	function self.update(msg)
		local me = msg.me
		toggle.Visible = me ~= nil and me.heroId ~= nil
		if not me or not me.heroId then
			setOpen(false)
			return
		end
		-- Перестраиваем список карт только при изменении
		local keyParts = {}
		for _, c in ipairs(me.cards) do
			table.insert(keyParts, c.id .. ":" .. c.stars)
		end
		local key = table.concat(keyParts, ",")
		if key ~= lastKey then
			lastKey = key
			Util.clear(scroll)
			for i, c in ipairs(me.cards) do
				local card = Progression.cardsById()[c.id]
				Util.label({
					Size = UDim2.new(1, -8, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = 13,
					LayoutOrder = i,
					ZIndex = 11,
					Text = string.format(
						"<font color='%s'><b>%s</b></font> %s  <font color='#A0A0B8'>%s</font>\n%s",
						Util.hex(Theme.Rarity[card.r]), Util.escape(card.name), Text.stars(c.stars), Text.styleNames(card), Util.escape(Text.cardDesc(card, c.stars))
					),
					Parent = scroll,
				})
			end
			toggle.Text = "Мои карты (" .. #me.cards .. ")"
		end
		-- Правая колонка
		local lines = {}
		local trait = me.traitId and GameState.TraitsById[me.traitId]
		if trait then
			table.insert(lines, "<b>Черта:</b> " .. Util.escape(trait.name) .. "\n<font color='#A0A0B8'>" .. Util.escape(trait.desc) .. "</font>")
		end
		local talentLines = {}
		for _, lvl in ipairs(Config.Match.TalentLevels) do
			local id = me.talents and me.talents[tostring(lvl)]
			if id then
				local n, d = talentName(me.heroId, id)
				table.insert(talentLines, lvl .. ": " .. Util.escape(n) .. " — <font color='#A0A0B8'>" .. Util.escape(d or "") .. "</font>")
			end
		end
		if #talentLines > 0 then
			table.insert(lines, "\n<b>Таланты:</b>\n" .. table.concat(talentLines, "\n"))
		end
		if #me.items > 0 then
			local names = {}
			for _, id in ipairs(me.items) do
				local it = GameState.ItemsById[id]
				table.insert(names, it and it.name or id)
			end
			table.insert(lines, "\n<b>Снаряжение:</b> " .. Util.escape(table.concat(names, ", ")))
		end
		if #me.artifacts > 0 then
			local names = {}
			for _, id in ipairs(me.artifacts) do
				local a = GameState.ArtifactsById[id]
				table.insert(names, a and a.name or id)
			end
			table.insert(lines, "\n<b>Артефакты:</b> " .. Util.escape(table.concat(names, ", ")))
		end
		local notes = {}
		for i = #me.notes, math.max(1, #me.notes - 8), -1 do
			table.insert(notes, "• " .. Util.escape(me.notes[i].text))
		end
		if #notes > 0 then
			table.insert(lines, "\n<b>События:</b>\n<font color='#A0A0B8'>" .. table.concat(notes, "\n") .. "</font>")
		end
		sideText.Text = table.concat(lines, "\n")
	end

	return self
end

return CardsPanel
