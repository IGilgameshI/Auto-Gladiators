--!nonstrict
-- Список 8 игроков: HP курьера, герой, уровень, серия, место, пары хода.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local PlayersPanel = {}

function PlayersPanel.new(parent)
	local self = {}
	local root = Util.panel({
		Name = "Players",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 68),
		Size = UDim2.new(0, 260, 0, 8 * 46 + 150),
		Parent = parent,
	})
	Util.padding(8).Parent = root
	Util.list(Enum.FillDirection.Vertical, 4).Parent = root

	local rows = {}
	for i = 1, Config.Match.MaxPlayers do
		local row = Util.create("Frame", { BackgroundColor3 = Theme.PanelLight, BackgroundTransparency = 0.3, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = i, Parent = root })
		Util.corner(6).Parent = row
		Util.padding(4).Parent = row
		local name = Util.label({ Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Font = Theme.FontBold, Parent = row })
		local _, setHp = Util.bar({ Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 20), Parent = row }, Theme.Hp)
		rows[i] = { frame = row, name = name, setHp = setHp }
	end
	local pairsLabel = Util.label({ Size = UDim2.new(1, 0, 0, 130), TextSize = 12, TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 99, Parent = root })

	function self.update(msg, myId)
		local pub = msg.pub
		root.Visible = pub ~= nil
		if not pub then
			return
		end
		for i = 1, Config.Match.MaxPlayers do
			local p = pub.players[i]
			local row = rows[i]
			if p then
				row.frame.Visible = true
				local hero = p.heroId and Config.Heroes[p.heroId]
				local tags = {}
				if p.winStreak >= 2 then
					table.insert(tags, "<font color='#FF9050'>🔥" .. p.winStreak .. "</font>")
				end
				if p.place then
					table.insert(tags, "<font color='#FFD040'>#" .. p.place .. "</font>")
				end
				local nameText = Util.escape(p.name)
				if p.id == myId then
					nameText = "<font color='#7FD0FF'>" .. nameText .. "</font>"
				end
				row.name.Text = string.format("%s  <font color='#A0A0B8'>%s ур.%d</font> %s", nameText, hero and hero.name or "", p.level, table.concat(tags, " "))
				local frac = p.hp / Config.Match.CourierHp
				row.setHp(frac, p.alive and tostring(p.hp) or "выбыл", p.hp > 30 and Theme.Hp or Theme.HpLow)
				row.frame.BackgroundTransparency = p.alive and 0.3 or 0.8
			else
				row.frame.Visible = false
			end
		end
		local lines = {}
		for _, pr in ipairs(msg.pairs or {}) do
			table.insert(lines, string.format("%s  ⚔  %s", Util.escape(pr.a), Util.escape(pr.b or "?")))
		end
		pairsLabel.Text = #lines > 0 and ("<b>Пары хода</b>\n" .. table.concat(lines, "\n")) or ""
	end

	return self
end

return PlayersPanel
