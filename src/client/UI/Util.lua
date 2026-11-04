--!nonstrict
-- Мини-конструктор интерфейса
local Theme = require(script.Parent.Theme)

local Util = {}

-- create("Frame", {props}, {children})
function Util.create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local create = Util.create

function Util.corner(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Util.stroke(color, thickness)
	return create("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function Util.padding(px)
	local u = UDim.new(0, px or 6)
	return create("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function Util.list(dir, gap, align)
	return create("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function Util.panel(props, children)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.1
	props.BorderSizePixel = 0
	local f = create("Frame", props, children)
	Util.corner(10).Parent = f
	return f
end

function Util.label(props)
	props = props or {}
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.Font = props.Font or Theme.Font
	props.TextSize = props.TextSize or 14
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextWrapped = props.TextWrapped ~= false
	props.RichText = true
	return create("TextLabel", props)
end

function Util.button(props, onClick)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Accent
	props.TextColor3 = props.TextColor3 or Theme.Text
	props.Font = props.Font or Theme.FontBold
	props.TextSize = props.TextSize or 16
	props.AutoButtonColor = true
	props.BorderSizePixel = 0
	props.RichText = true
	local b = create("TextButton", props)
	Util.corner(8).Parent = b
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

-- Полоска прогресса: возвращает (frame, set(fraction, text))
function Util.bar(props, color)
	props = props or {}
	props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(10, 10, 15)
	props.BorderSizePixel = 0
	local frame = create("Frame", props)
	Util.corner(6).Parent = frame
	local fill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = color or Theme.Hp,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	})
	Util.corner(6).Parent = fill
	local text = Util.label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.FontBold,
		TextSize = 13,
		ZIndex = 3,
		Parent = frame,
	})
	local function set(fraction, str, col)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		text.Text = str or ""
		if col then
			fill.BackgroundColor3 = col
		end
	end
	return frame, set
end

function Util.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
end

-- Всплывающая подсказка: tooltip(guiObject, getText)
local tooltipLabel = nil
function Util.setTooltipLayer(screenGui)
	tooltipLabel = Util.label({
		Name = "Tooltip",
		Visible = false,
		BackgroundTransparency = 0.05,
		BackgroundColor3 = Color3.fromRGB(10, 10, 16),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 14,
		ZIndex = 50,
		Parent = screenGui,
	})
	Util.corner(6).Parent = tooltipLabel
	Util.padding(8).Parent = tooltipLabel
	Util.stroke(Theme.Accent2, 1).Parent = tooltipLabel
end

function Util.tooltip(gui, getText)
	gui.MouseEnter:Connect(function()
		if not tooltipLabel then
			return
		end
		local text = type(getText) == "function" and getText() or getText
		if not text or text == "" then
			return
		end
		tooltipLabel.Text = text
		local pos = gui.AbsolutePosition
		local size = gui.AbsoluteSize
		local screen = tooltipLabel.Parent.AbsoluteSize
		local x = math.clamp(pos.X, 4, screen.X - 304)
		local y = pos.Y - 8
		tooltipLabel.AnchorPoint = Vector2.new(0, 1)
		if y < 160 then
			y = pos.Y + size.Y + 8
			tooltipLabel.AnchorPoint = Vector2.new(0, 0)
		end
		tooltipLabel.Position = UDim2.fromOffset(x, y)
		tooltipLabel.Visible = true
	end)
	gui.MouseLeave:Connect(function()
		if tooltipLabel then
			tooltipLabel.Visible = false
		end
	end)
end

function Util.hideTooltip()
	if tooltipLabel then
		tooltipLabel.Visible = false
	end
end

function Util.hex(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

-- Безопасный текст для RichText
function Util.escape(s)
	s = tostring(s or "")
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

return Util
