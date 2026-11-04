-- Запуск тестов вне Roblox.
--
--   lua5.4 tests/run.lua              (из корня репозитория)
--   python3 tests/run_lupa.py         (если системного lua нет: pip install lupa)
--
-- Загрузчик эмулирует дерево Rojo: у каждого модуля есть свой `script`,
-- `script.Parent`, `script.Имя`, а `require(узел)` грузит соответствующий
-- файл (.lua или папку с init.lua). Поэтому код из src/shared работает без
-- изменений и в Roblox, и здесь.

local ROOT = (arg and arg[1]) or "."
local SRC = ROOT .. "/src"

---------------------------------------------------------------------------
-- Полифиллы функций, которые есть в Luau, но нет в Lua 5.x
---------------------------------------------------------------------------
if not table.find then
	function table.find(t, v)
		for i, x in ipairs(t) do
			if x == v then
				return i
			end
		end
		return nil
	end
end
if not table.clone then
	function table.clone(t)
		local c = {}
		for k, v in pairs(t) do
			c[k] = v
		end
		return c
	end
end
if not math.clamp then
	function math.clamp(x, a, b)
		return math.max(a, math.min(b, x))
	end
end
if not math.round then
	function math.round(x)
		return math.floor(x + 0.5)
	end
end

---------------------------------------------------------------------------
-- Фейковое дерево экземпляров
---------------------------------------------------------------------------
local function fileExists(path)
	local f = io.open(path, "r")
	if f then
		f:close()
		return true
	end
	return false
end

local function readFile(path)
	local f = assert(io.open(path, "r"))
	local s = f:read("a")
	f:close()
	return s
end

local Node = {}
local nodeCache = {}

local function node(path)
	local n = nodeCache[path]
	if n then
		return n
	end
	n = setmetatable({ __path = path }, Node)
	nodeCache[path] = n
	return n
end

Node.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		local parent = path:match("^(.*)/[^/]+$")
		return parent and node(parent) or nil
	elseif key == "Name" then
		return path:match("([^/]+)$")
	end
	return node(path .. "/" .. key)
end
Node.__tostring = function(self)
	return "Node(" .. rawget(self, "__path") .. ")"
end

local moduleCache = {}
local loading = {}
local requireNode

local function loadModule(path)
	local file, scriptNode
	if fileExists(SRC .. "/" .. path .. ".lua") then
		file = SRC .. "/" .. path .. ".lua"
	elseif fileExists(SRC .. "/" .. path .. "/init.lua") then
		file = SRC .. "/" .. path .. "/init.lua"
	else
		error("модуль не найден: " .. path, 3)
	end
	scriptNode = node(path)
	local env = setmetatable({ script = scriptNode, require = requireNode }, { __index = _G })
	local chunk, err = load(readFile(file), "@" .. file, "t", env)
	if not chunk then
		error(err, 0)
	end
	return chunk()
end

requireNode = function(target)
	if type(target) == "string" then
		return require(target)
	end
	local path = rawget(target, "__path")
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	if loading[path] then
		error("циклический require: " .. path)
	end
	loading[path] = true
	local result = loadModule(path)
	loading[path] = nil
	moduleCache[path] = result
	return result
end

-- Глобальный доступ для тестов: R("shared/Combat/Engine")
function R(path)
	return requireNode(node(path))
end

---------------------------------------------------------------------------
-- Мини-фреймворк тестов
---------------------------------------------------------------------------
local passed, failed = 0, 0
local failures = {}
local currentSuite = ""

T = {}
function T.suite(name)
	currentSuite = name
	print("== " .. name)
end
function T.test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		print("  ok   " .. name)
	else
		failed = failed + 1
		print("  FAIL " .. name)
		print("       " .. tostring(err):gsub("\n", "\n       "))
		table.insert(failures, currentSuite .. " / " .. name)
	end
end
function T.eq(a, b, msg)
	if a ~= b then
		error((msg or "ожидалось равенство") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2)
	end
end
function T.ok(v, msg)
	if not v then
		error(msg or "ожидалось true", 2)
	end
end
function T.near(a, b, eps, msg)
	if math.abs(a - b) > (eps or 1e-6) then
		error((msg or "ожидалось приблизительное равенство") .. ": " .. tostring(a) .. " vs " .. tostring(b), 2)
	end
end

local specs = {
	"tests/rng.spec.lua",
	"tests/data.spec.lua",
	"tests/engine.spec.lua",
	"tests/progression.spec.lua",
	"tests/shop.spec.lua",
	"tests/economy.spec.lua",
	"tests/game.spec.lua",
}

for _, spec in ipairs(specs) do
	local chunk = loadfile(ROOT .. "/" .. spec)
	if chunk then
		chunk()
	else
		print("(пропущен " .. spec .. ")")
	end
end

print(string.format("\nИтого: %d прошло, %d упало", passed, failed))
if failed > 0 then
	for _, f in ipairs(failures) do
		print("  - " .. f)
	end
	os.exit(1)
end
