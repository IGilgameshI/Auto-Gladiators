--!nocheck
-- Детерминированный ГСЧ (Park–Miller, минимальный стандарт).
-- Все произведения < 2^53, поэтому одинаково считается и в Luau (double),
-- и в Lua 5.4 (integer/float). Не зависит от Roblox и math.random.
local Rng = {}
Rng.__index = Rng

local M = 2147483647
local A = 48271

function Rng.new(seed)
	local s = math.floor(tonumber(seed) or 1) % M
	if s <= 0 then
		s = s + M - 1
	end
	local self = setmetatable({ state = s }, Rng)
	-- Прогрев: у Park–Miller первые значения при маленьком seed почти
	-- нулевые, поэтому отбрасываем несколько первых чисел.
	for _ = 1, 6 do
		self:nextInt()
	end
	return self
end

-- Следующее целое в [1, M-1]
function Rng:nextInt()
	self.state = (self.state * A) % M
	return self.state
end

-- Число в [0, 1)
function Rng:float()
	return (self:nextInt() - 1) / (M - 1)
end

-- Целое в [lo, hi]
function Rng:range(lo, hi)
	if hi <= lo then
		return lo
	end
	return lo + math.floor(self:float() * (hi - lo + 1))
end

-- Бросок шанса в процентах (0..100)
function Rng:chance(pct)
	if pct <= 0 then
		return false
	end
	if pct >= 100 then
		return true
	end
	return self:float() * 100 < pct
end

-- Случайный элемент массива
function Rng:pick(list)
	if #list == 0 then
		return nil
	end
	return list[self:range(1, #list)]
end

-- Перемешивание массива на месте (Фишер–Йетс)
function Rng:shuffle(list)
	for i = #list, 2, -1 do
		local j = self:range(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Порождает независимый ГСЧ (для подсистем), не ломая основной поток.
function Rng:fork()
	return Rng.new(self:nextInt())
end

return Rng
