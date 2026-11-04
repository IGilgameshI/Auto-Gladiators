--!nonstrict
-- Окно выбора «1 из N»: территория, гладиатор, черта, талант, артефакт,
-- снаряжение. show(key, title, options, onPick) — options = { {title, desc, badge?} }
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local ChoiceModal = {}

function ChoiceModal.new(parent)
	local self = {}
	local root = Util.create("Frame", {
		Name = "Choice",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	})
	local box = Util.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 900, 0, 380),
		ZIndex = 21,
		Parent = root,
	})
	Util.padding(14).Parent = box
	local title = Util.label({ Size = UDim2.new(1, -120, 0, 36), Font = Theme.FontBold, TextSize = 22, ZIndex = 22, Parent = box })
	local hide = Util.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(110, 32),
		Text = "Свернуть",
		TextSize = 14,
		BackgroundColor3 = Theme.PanelLight,
		ZIndex = 22,
		Parent = box,
	})
	local row = Util.create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), ZIndex = 22, Parent = box })
	Util.list(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center).Parent = row

	-- Кнопка, чтобы вернуть свёрнутое окно
	local reopen = Util.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 68),
		Size = UDim2.fromOffset(260, 40),
		Text = "Сделать выбор",
		BackgroundColor3 = Theme.Accent,
		Visible = false,
		ZIndex = 19,
		Parent = parent,
	})

	local currentKey = nil
	local minimized = {}
	local selectedIndex = nil

	hide.Activated:Connect(function()
		if currentKey then
			minimized[currentKey] = true
			root.Visible = false
			reopen.Visible = true
		end
	end)
	reopen.Activated:Connect(function()
		if currentKey then
			minimized[currentKey] = nil
			root.Visible = true
			reopen.Visible = false
		end
	end)

	-- key — уникальный ключ выбора; повторный show с тем же key не пересоздаёт кнопки
	function self.show(key, titleText, options, onPick, opts)
		opts = opts or {}
		if currentKey == key and (root.Visible or reopen.Visible) then
			-- Обновить только подписи (например, счётчики голосов)
			for i, opt in ipairs(options) do
				local b = row:FindFirstChild("Opt" .. i)
				if b then
					b.Text = string.format("<b>%s</b>\n\n%s", opt.title, opt.desc or "")
					if opts.selected == i then
						b.BackgroundColor3 = Theme.Accent
					else
						b.BackgroundColor3 = Theme.PanelLight
					end
				end
			end
			return
		end
		currentKey = key
		selectedIndex = nil
		title.Text = titleText
		Util.clear(row)
		local n = #options
		local width = math.clamp(math.floor((860 - (n - 1) * 12) / math.max(1, n)), 130, 280)
		box.Size = UDim2.new(0, math.max(420, n * (width + 12) + 16), 0, 380)
		for i, opt in ipairs(options) do
			local b = Util.button({
				Name = "Opt" .. i,
				Size = UDim2.new(0, width, 1, 0),
				BackgroundColor3 = (opts.selected == i) and Theme.Accent or Theme.PanelLight,
				TextWrapped = true,
				TextSize = 14,
				Font = Theme.Font,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = string.format("<b>%s</b>\n\n%s", opt.title, opt.desc or ""),
				LayoutOrder = i,
				ZIndex = 23,
				Parent = row,
			}, function()
				selectedIndex = i
				onPick(i)
				if not opts.keepOpen then
					self.hide()
				end
			end)
			Util.padding(10).Parent = b
		end
		if minimized[key] then
			root.Visible = false
			reopen.Visible = true
		else
			root.Visible = true
			reopen.Visible = false
		end
	end

	function self.hide()
		currentKey = nil
		root.Visible = false
		reopen.Visible = false
	end

	function self.key()
		return currentKey
	end

	return self
end

return ChoiceModal
