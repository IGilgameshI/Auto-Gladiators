--!nonstrict
-- Стили героя: уровень 0..4, опыт до следующего уровня, бонусы в подсказке.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local StylesPanel = {}

function StylesPanel.new(parent)
	local self = {}
	local root = Util.panel({
		Name = "Styles",
		Position = UDim2.fromOffset(8, 68),
		Size = UDim2.new(0, 236, 0, 470),
		Parent = parent,
	})
	Util.padding(8).Parent = root
	Util.list(Enum.FillDirection.Vertical, 4).Parent = root
	local header = Util.label({ Size = UDim2.new(1, 0, 0, 40), Font = Theme.FontBold, TextSize = 15, LayoutOrder = 0, Parent = root })

	local rows = {}
	for i, styleId in ipairs(Config.Styles.Order) do
		local data = Config.Styles.Data[styleId]
		local row = Util.create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, Parent = root })
		local name = Util.label({ Size = UDim2.new(0.5, 0, 1, 0), TextSize = 13, Font = Theme.FontBold, TextColor3 = Theme.rgb(data.color), Parent = row })
		local barFrame, setBar = Util.bar({ Size = UDim2.new(0.5, 0, 0, 18), Position = UDim2.new(0.5, 0, 0.5, -9), Parent = row }, Theme.rgb(data.color))
		Util.tooltip(row, function()
			return string.format("<b>%s</b>\n%s\n\nУровень 4: %s", data.name, Util.escape(data.desc), Util.escape(data.mastery or ""))
		end)
		rows[styleId] = { name = name, set = setBar, frame = barFrame }
	end

	function self.update(msg)
		local me = msg.me
		root.Visible = me ~= nil and me.heroId ~= nil
		if not me or not me.heroId then
			return
		end
		local hero = Config.Heroes[me.heroId]
		header.Text = string.format("%s — ур. %d\n<font size='12' color='%s'>%s</font>", hero.name, me.level, Util.hex(Theme.TextDim), Util.escape(hero.passive.name .. " / " .. hero.ult.name))
		for _, styleId in ipairs(Config.Styles.Order) do
			local s = me.styles[styleId]
			local row = rows[styleId]
			local data = Config.Styles.Data[styleId]
			local lvl = s.level
			row.name.Text = string.format("%s  %s", data.name, string.rep("◆", lvl) .. string.rep("◇", Config.Styles.MaxLevel - lvl))
			if lvl >= Config.Styles.MaxLevel then
				row.set(1, s.xp .. " (макс.)")
			else
				local need = s.next
				local frac = need > 0 and (s.xp / need) or 0
				row.set(frac, s.xp .. " / " .. need)
			end
		end
	end

	return self
end

return StylesPanel
