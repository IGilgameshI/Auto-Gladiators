--!nocheck
-- Имена удалённых событий и действий клиента. Общие для сервера и клиента.
local Net = {}

Net.FolderName = "Remotes"

Net.Remotes = {
	State = "State", -- сервер -> клиент: снимок состояния (публичное + личное)
	Action = "Action", -- клиент -> сервер: просьба совершить действие
	Battle = "Battle", -- сервер -> клиент: журнал боя для воспроизведения
	Toast = "Toast", -- сервер -> клиент: короткое сообщение
}

-- Действия клиента. Сервер проверяет всё сам.
Net.Actions = {
	Vote = "Vote", -- (index)
	PickHero = "PickHero", -- (index)
	PickTrait = "PickTrait", -- (index)
	Buy = "Buy", -- (slot)
	Reroll = "Reroll", -- ()
	PickArtifact = "PickArtifact", -- (index)
	PickItem = "PickItem", -- (index)
	PickTalent = "PickTalent", -- (index)
	Ready = "Ready", -- () закончить подготовку досрочно
}

return Net
