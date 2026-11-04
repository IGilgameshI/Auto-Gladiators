--!nonstrict
-- Короткие сообщения сверху экрана
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Toasts = {}

function Toasts.new(parent)
	local self = {}
	local holder = Util.create("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 210),
		Size = UDim2.new(0, 520, 0, 300),
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = parent,
	})
	Util.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center).Parent = holder
	local n = 0

	function self.show(text)
		n = n + 1
		local label = Util.label({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0.15,
			BackgroundColor3 = Theme.Bg,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.FontBold,
			TextSize = 17,
			Text = Util.escape(text),
			LayoutOrder = n,
			ZIndex = 31,
			Parent = holder,
		})
		Util.corner(8).Parent = label
		Util.padding(8).Parent = label
		task.delay(4, function()
			local tween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
			label:Destroy()
		end)
	end

	return self
end

return Toasts
