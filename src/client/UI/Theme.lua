--!nonstrict
-- Цвета и шрифты интерфейса
local Theme = {
	Bg = Color3.fromRGB(18, 18, 28),
	Panel = Color3.fromRGB(28, 28, 42),
	PanelLight = Color3.fromRGB(42, 42, 62),
	Accent = Color3.fromRGB(255, 120, 60),
	Accent2 = Color3.fromRGB(110, 170, 255),
	Text = Color3.fromRGB(240, 240, 245),
	TextDim = Color3.fromRGB(165, 165, 185),
	Gold = Color3.fromRGB(255, 205, 60),
	Hp = Color3.fromRGB(90, 220, 110),
	HpLow = Color3.fromRGB(230, 70, 60),
	Mana = Color3.fromRGB(80, 150, 255),
	Good = Color3.fromRGB(90, 220, 110),
	Bad = Color3.fromRGB(240, 80, 70),
	Font = Enum.Font.Gotham,
	FontBold = Enum.Font.GothamBold,
	Rarity = {
		n = Color3.fromRGB(190, 190, 200),
		r = Color3.fromRGB(80, 160, 255),
		sr = Color3.fromRGB(255, 170, 40),
	},
	Stacks = {
		poison = Color3.fromRGB(140, 200, 40),
		ice = Color3.fromRGB(120, 210, 255),
		fury = Color3.fromRGB(255, 120, 30),
		shield = Color3.fromRGB(210, 210, 220),
		injury = Color3.fromRGB(190, 80, 200),
	},
}

function Theme.rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

return Theme
