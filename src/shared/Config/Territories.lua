--!nocheck
-- Территории (модификатор всей партии). На голосование выносится
-- Config.Match.TerritoryChoices случайных. Параметры читает Game/Meta.lua.
return {
	{ id = "dark_reef", name = "Тёмный риф", desc = "Экономики нет: ровно 80 золота за ход (без бонусов и процентов).", flatIncome = 80 },
	{ id = "hill_mines", name = "Холмовые шахты", desc = "Предел процентов увеличен до 150.", interestMax = 150 },
	{ id = "sanctuary", name = "Запретное святилище", desc = "Без эффекта территории." },
	{ id = "clairvoyance", name = "Ясновидение", desc = "В фазе подготовки виден следующий соперник.", revealOpponent = true },
	{ id = "unexpected", name = "Неожиданность", desc = "Покупка карты с шансом 20% даёт ещё одну случайную карту.", bonusCardChance = 20 },
	{ id = "eliminated_treasure", name = "Сокровище выбывших", desc = "+300 золота за каждого выбывшего игрока.", elimGold = 300 },
	{ id = "mystic_shelter", name = "Мистическое убежище", desc = "Каждые 3 хода — карта стиля героя.", heroCardEvery = 3 },
	{ id = "wisdom_tree", name = "Древо мудрости", desc = "Опыт для уровней одного случайного стиля героя -10%.", heroStyleXpReq = -10 },
	{ id = "red_mist", name = "Красный туман", desc = "Каждые 5 ходов — случайная редкая карта.", rareCardEvery = 5 },
	{ id = "runic_paradise", name = "Рунический рай", desc = "Шанс легендарных карт +1% (вес x1.3).", srWeightMul = 1.3 },
	{ id = "stonehall", name = "Каменный зал", desc = "При выборе артефакта +50 x номер хода золота.", artifactGoldPerTurn = 50 },
	{ id = "blueheart", name = "Синесердый ледник", desc = "+900 золота в начале игры.", startGold = 900 },
	{ id = "food_pantry", name = "Кладовая", desc = "Компенсация за поражение x2.", loseCompMul = 2 },
	{ id = "blood_hunter", name = "Кровавый охотник", desc = "Победитель получает 10 золота за каждую единицу урона курьеру.", goldPerCourierDamage = 10 },
	{ id = "chaotic_space", name = "Хаотичное пространство", desc = "Базовый доход -50, но каждый ход всем 0 или 200 золота.", chaos = { minus = 50, gold = 200 } },
	{ id = "usury", name = "Ростовщичество", desc = "Бонусы за серии и победу x2.", streakMul = 2 },
	{ id = "underscape", name = "Подземье", desc = "Каждое повышение уровня героя даёт карту стиля героя.", levelUpCard = true },
	{ id = "bank_stash", name = "Банковский тайник", desc = "Все стили героя стартуют с 3 XP.", heroStyleStartXp = 3 },
	{ id = "mutual_prosperity", name = "Общее процветание", desc = "Выжившие к 20 ходу делят 3000 золота.", shareGold = { turn = 20, gold = 3000 } },
}
