--!nocheck
-- Крипы (PvE-ходы 5/10/15). tier: 1 = ход 5, 2 = ход 10, 3 = ход 15.
-- stars — уровень стиля крипа (даёт бонусы стиля), fx — тот же DSL.
local function on(ev, chance, a) return { k = "on", ev = ev, chance = chance, a = a } end

return {
	{ id = "skeleton", tier = 1, name = "Скелет", style = "health", hp = 850, atk = 20, v = 8, desc = "Атаки с шансом 40% лечат 8 HP.", fx = { on("attack", 40, { "heal" }) } },
	{ id = "plague_ward", tier = 1, name = "Чумной тотем", style = "poison", hp = 1200, atk = 10, v = 25, desc = "Урон от Яда по нему -25%.", fx = { { k = "stat", stat = "poisonResist", key = "v" } } },
	{ id = "alpha_wolf", tier = 1, name = "Вожак волков", style = "crit", hp = 800, atk = 15, v = 3, desc = "Крит снижает атаку противника на 3.", fx = { on("crit", 100, { "enemyAtkDown" }) } },
	{ id = "hellbear", tier = 1, name = "Адский медведь", style = "crit", hp = 900, atk = 23, v = 3, desc = "Каждый крит +3% урона атаки (до 30%).", fx = { on("crit", 100, { "grow", stat = "atkPct", maxVal = 30 }) } },
	{ id = "ghost", tier = 1, name = "Призрак", style = "ice", hp = 700, atk = 25, v = 10, desc = "Атаки дают +1 уклонения (до 10).", fx = { on("attack", 100, { "grow", stat = "evade", val = 1, maxVal = 10 }) } },
	{ id = "burning_army", tier = 1, name = "Пылающая армия", style = "fury", hp = 680, atk = 18, v = 5, desc = "Каждая атака даёт 5 Ярости.", fx = { on("attack", 100, { "fury" }) } },
	{ id = "kobold", tier = 1, name = "Кобольд", style = "attack", hp = 560, atk = 22, v = 10, desc = "Атаки с шансом 20% наносят ещё 10 урона.", fx = { on("attack", 20, { "dmg", t = "phys" }) } },
	{ id = "prowler", tier = 1, name = "Сатир-охотник", style = "injury", hp = 1080, atk = 9, v = 5, desc = "Каждые 1.5 сек. накладывает 5 Уязвимости.", fx = { { k = "every", t = 1.5, a = { "injury" } } } },
	{ id = "netherwolf", tier = 1, name = "Ядовитый волк", style = "poison", hp = 880, atk = 15, v = 4, desc = "При уроне с шансом 15% накладывает 4 Яда.", fx = { on("dealDamage", 15, { "poison" }) } },

	{ id = "woodsfolk", tier = 2, name = "Лесной дух льда и огня", style = "ice", hp = 1400, atk = 30, v = 8, desc = "Каждую секунду накладывает 8 Заморозки.", fx = { { k = "every", t = 1, a = { "ice" } } } },
	{ id = "wildwing", tier = 2, name = "Дикокрыл", style = "evade", hp = 1200, atk = 22, v = 20, desc = "При уклонении наносит 20 физического урона.", fx = { on("evade", 100, { "dmg", t = "phys" }) } },
	{ id = "wisp_ward", tier = 2, name = "Тотем огоньков", style = "wisp", hp = 1700, atk = 20, v = 15, desc = "Каждую секунду лечит 15 HP.", fx = { { k = "every", t = 1, a = { "heal" } } } },
	{ id = "enslaver", tier = 2, name = "Кобольд-поработитель", style = "wisp", hp = 1200, atk = 19, v = 150, desc = "HP стража +150.", fx = { { k = "stat", stat = "wardHp", key = "v" } } },
	{ id = "forest_priest", tier = 2, name = "Лесной жрец", style = "regen", hp = 1200, atk = 12, v = 25, desc = "Каждую секунду лечит 25 HP.", fx = { { k = "every", t = 1, a = { "heal" } } } },
	{ id = "centaur", tier = 2, name = "Вождь кентавров", style = "health", hp = 1900, atk = 25, v = 0, desc = "Макс. HP +500 (уже учтено).", fx = {} },
	{ id = "golem", tier = 2, name = "Глиняный голем", style = "shield", hp = 1600, atk = 16, v = 5, desc = "При физ. уроне с шансом 20% получает 5 Щита.", fx = { on("damagedPhys", 20, { "shield" }) } },
	{ id = "ogre", tier = 2, name = "Огр-дубинщик", style = "attack", hp = 1400, atk = 20, v = 0.2, desc = "Атаки с шансом 25% оглушают на 0.2 сек.", fx = { on("attack", 25, { "stun" }) } },
	{ id = "mole", tier = 2, name = "Свирепый крот", style = "crit", hp = 1600, atk = 25, v = 50, desc = "Шанс крита +50.", fx = { { k = "stat", stat = "crit", key = "v" } } },
	{ id = "familiar", tier = 2, name = "Древний фамильяр", style = "evade", hp = 1500, atk = 20, v = 40, desc = "При уклонении лечит 40 HP.", fx = { on("evade", 100, { "heal" }) } },

	{ id = "black_dragon", tier = 3, name = "Чёрный дракон", style = "injury", hp = 1800, atk = 35, v = 7, desc = "При получении урона с шансом 40% накладывает 7 Уязвимости.", fx = { on("damaged", 40, { "injury" }) } },
	{ id = "mega_creep", tier = 3, name = "Мега-крип", style = "shield", hp = 2200, atk = 30, v = 8, desc = "Каждую секунду получает 8 Щита.", fx = { { k = "every", t = 1, a = { "shield" } } } },
	{ id = "ancient_satyr", tier = 3, name = "Древний сатир", style = "injury", hp = 2100, atk = 25, v = 30, desc = "Уязвимость по нему с шансом 30% не проходит.", fx = { { k = "stat", stat = "injuryResist", key = "v" } } },
	{ id = "nemestice", tier = 3, name = "Дальний крип Неместиса", style = "ulti", hp = 2500, atk = 24, v = 60, desc = "Каждый ульт +60 базового урона.", fx = { on("ult", 100, { "grow", stat = "baseAtk" }) } },
	{ id = "venomancer", tier = 3, name = "Веномансер", style = "poison", hp = 2200, atk = 22, v = 80, desc = "Когда противник применяет ульт, накладывает 80 Яда.", fx = { on("enemyUlt", 100, { "poison" }) } },
	{ id = "genie", tier = 3, name = "Джинн", style = "fury", hp = 1900, atk = 30, v = 50, desc = "Атаки с шансом 30% наносят 50 + 40% Ярости магического урона.", fx = { on("attack", 30, { "dmg", t = "magic", plusSelfStack = "fury", mul = 0.4 }) } },
	{ id = "thunderhide", tier = 3, name = "Громошкур", style = "health", hp = 2200, atk = 30, v = 5, desc = "За каждые 300 потерянного HP +5 скорости атаки.", fx = { { k = "hpLoss", per = 300, a = { "grow", stat = "atkSpeed" } } } },
	{ id = "year_beast", tier = 3, name = "Зверь года", style = "ulti", hp = 1900, atk = 35, v = 25, desc = "После ульта получает 25 маны.", fx = { on("ult", 100, { "mana" }) } },
	{ id = "sobek", tier = 3, name = "Собек", style = "regen", hp = 2200, atk = 23, v = 30, desc = "Каждую секунду лечит 30 HP.", fx = { { k = "every", t = 1, a = { "heal" } } } },
}
