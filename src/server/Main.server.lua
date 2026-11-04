--!nonstrict
-- Точка входа сервера. Сервер решает всё: магазин, бои, урон, места.
local MatchService = require(script.Parent:WaitForChild("Services"):WaitForChild("MatchService"))

MatchService.start()
