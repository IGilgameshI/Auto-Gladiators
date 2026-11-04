local Rng = R("shared/Combat/Rng")

T.suite("Rng")

T.test("одинаковый seed даёт одинаковую последовательность", function()
	local a, b = Rng.new(42), Rng.new(42)
	for _ = 1, 100 do
		T.eq(a:nextInt(), b:nextInt())
	end
end)

T.test("разные seed дают разные последовательности", function()
	local a, b = Rng.new(1), Rng.new(2)
	local same = 0
	for _ = 1, 50 do
		if a:nextInt() == b:nextInt() then
			same = same + 1
		end
	end
	T.ok(same < 5)
end)

T.test("float в [0,1), range в границах", function()
	local r = Rng.new(7)
	for _ = 1, 2000 do
		local f = r:float()
		T.ok(f >= 0 and f < 1)
		local x = r:range(3, 9)
		T.ok(x >= 3 and x <= 9 and x == math.floor(x))
	end
end)

T.test("chance примерно соответствует проценту", function()
	local r = Rng.new(99)
	local hits = 0
	for _ = 1, 10000 do
		if r:chance(30) then
			hits = hits + 1
		end
	end
	T.ok(hits > 2700 and hits < 3300, "hits=" .. hits)
	T.ok(not r:chance(0))
	T.ok(r:chance(100))
end)

T.test("seed 0 и отрицательные не ломают генератор", function()
	for _, s in ipairs({ 0, -5, 2147483647, 1e12 }) do
		local r = Rng.new(s)
		local v = r:nextInt()
		T.ok(v > 0 and v < 2147483647)
	end
end)
