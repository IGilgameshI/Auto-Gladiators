--!nocheck
-- Config: единственное место, где лежат числа баланса.
-- Контент (карты, предметы, артефакты, черты, территории, крипы) лежит в
-- подмодулях этой же папки и доступен как Config.Cards, Config.Items и т.д.
--
-- Важно: модуль и все его подмодули написаны на подмножестве Luau,
-- совместимом с Lua 5.x (без типов, без "+=", без "continue"), чтобы
-- тесты гонялись обычным Lua-интерпретатором вне Roblox.

local function sub(name)
	-- В Roblox подмодули лежат дочерними ModuleScript'ами, в тестах их
	-- подставляет загрузчик tests/run.lua (через фейковый `script`).
	return require(script[name])
end

local Config = {}

---------------------------------------------------------------------------
-- Общие правила партии
---------------------------------------------------------------------------
Config.Match = {
	MaxPlayers = 8, -- игроков в лобби (пустые места займут боты)
	CourierHp = 100, -- HP курьера
	WinningPlaces = 4, -- места 1..4 считаются победой
	MaxTurns = 60, -- страховка от бесконечной партии
	MinRealPlayersToStart = 1, -- сколько людей нужно, чтобы начать партию
	LobbyWaitSeconds = 20, -- ожидание игроков в лобби
	TerritoryVoteSeconds = 15,
	TerritoryChoices = 6, -- сколько территорий выносится на голосование
	HeroPickSeconds = 15,
	HeroChoices = 3, -- выбор гладиатора из N случайных
	TraitPickSeconds = 15,
	TraitChoices = 3, -- выбор черты из N случайных
	PrepSeconds = 30, -- фаза подготовки (магазин)
	OpponentRevealSeconds = 3, -- пауза «выбор соперника»
	PickSeconds = 15, -- выбор артефакта/предмета/таланта
	ResultSeconds = 4, -- пауза после боя
	MaxBattlePlaybackSeconds = 75, -- дольше бой на клиентах не показывается
	BattleSpeed = 1.0, -- во сколько раз ускорено воспроизведение боя
	CreepTurns = { [5] = 1, [10] = 2, [15] = 3 }, -- ход -> уровень снаряжения
	ArtifactTurns = { [3] = true, [8] = true, [13] = true },
	ArtifactChoices = 3,
	ItemChoices = 3,
	TalentLevels = { 5, 10, 15 }, -- уровни героя, на которых открывается талант
	CreepLossDamagesCourier = false, -- поражение от крипов не бьёт курьера
	GhostFromEliminated = true, -- нечётное число игроков: бой с «призраком»
}

---------------------------------------------------------------------------
-- Экономика
---------------------------------------------------------------------------
Config.Economy = {
	StartGold = 300,
	BaseGold = 250, -- базовое золото за ход
	BaseGoldPerTurn = 5, -- + за каждый номер хода (растущий доход)
	BaseGoldMaxBonus = 150, -- предел роста базового дохода
	WinBonus = 100, -- бонус за победу
	WinStreakBonus = 25, -- + за каждую победу в серии
	WinStreakBonusMax = 100, -- максимум бонуса за серию побед
	LoseComp = 80, -- компенсация за поражение
	LoseStreakBonus = 20, -- + за каждое поражение в серии
	LoseStreakBonusMax = 80,
	InterestPer = 100, -- каждые 100 непотраченного золота...
	InterestValue = 10, -- ...дают +10
	InterestMax = 100, -- максимум процентов за ход
	RerollCost = 30,
	CardPrice = { n = 100, r = 200, sr = 300 },
	SellRefundPct = 0, -- карты не продаются (как в оригинале)
}

---------------------------------------------------------------------------
-- Магазин и пул карт
---------------------------------------------------------------------------
Config.Shop = {
	Slots = 5,
	MaxStars = 5,
	-- Сколько копий (звёзд) каждой карты лежит в общем пуле.
	PoolCopies = { n = 18, r = 12, sr = 8 },
	-- Базовые веса редкостей, когда редкость разблокирована стилем.
	RarityWeight = { n = 100, r = 18, sr = 5 },
	-- Минимальный уровень стиля, начиная с которого выпадает редкость.
	RarityUnlockStyleLevel = { n = 0, r = 2, sr = 3 },
	-- Вес карт «своих» стилей (у которых уже есть XP) относительно прочих.
	OwnStyleWeightMul = 1.6,
}

---------------------------------------------------------------------------
-- Стили и уровни героя
---------------------------------------------------------------------------
Config.Styles = {
	-- Опыт стиля за одну звезду карты по редкости.
	XpPerStar = { n = 1, r = 2, sr = 4 },
	-- Суммарный опыт, нужный для уровней 1..4.
	LevelXp = { 3, 8, 16, 28 },
	MaxLevel = 4,
	HpPerStyleXp = 80, -- HP за каждую единицу опыта стиля
	-- Порядок стилей (используется UI и генераторами).
	Order = {
		"attack", "evade", "crit", "health", "regen", "ulti",
		"poison", "ice", "shield", "injury", "wisp", "fury",
	},
}
Config.Styles.Data = sub("Styles")

---------------------------------------------------------------------------
-- Боевые правила
---------------------------------------------------------------------------
Config.Combat = {
	Dt = 0.05, -- шаг симуляции, сек
	MaxTime = 120, -- жёсткий предел боя, потом решает % HP
	OvertimeStart = 20, -- после 20 сек урон растёт...
	OvertimePerSec = 0.06, -- ...на 6% в секунду
	ManaMax = 100,
	StackDecay = 0.30, -- стаки тают на 30%
	DecayInterval = 1.0, -- Заморозка/Ярость тают раз в секунду
	PoisonInterval = 1.0, -- базовый интервал тика яда
	PoisonIntervalMin = 0.4,
	CritMultBase = 150, -- базовый множитель крита, %
	EvadeReduceBase = 60, -- уклонение снижает физический урон на 60%
	EvadeReduceMax = 100,
	EvadeChanceMax = 75,
	CritChanceMax = 100,
	AttackSpeedMin = -80, -- нижний предел бонуса скорости атаки
	AttackSpeedMax = 500,
	FuryAttackSpeedPerStack = 1, -- +1 скорость атаки за стак Ярости
	FuryManaRegenPerStack = 0.01, -- +1% реген маны за стак Ярости
	IceAttackSpeedPerStack = 1, -- -1 скорость атаки за стак Заморозки
	IceManaRegenPerStack = 0.01, -- -1% реген маны за стак Заморозки
	ManaRegenMulMin = 0.2,
	ManaRegenMulMax = 4,
	DamageReduceMax = 90, -- предел снижения урона, %
	-- Стражи
	WispHealth = 250,
	WispDamage = 15,
	WispShare = 30, -- % урона героя, который забирает страж
	WispInterval = 1.5,
	WispIntervalMin = 0.4,
	-- Ограничения журнала боя (сколько событий уходит клиентам)
	MaxLogEvents = 2500,
	SnapshotInterval = 0.25,
	-- Длительность контроля
	StunMax = 3,
}

-- Мастер-эффекты стилей (активны на 4-м уровне стиля).
Config.Mastery = {
	attack = { chance = 30, value = 20, max = 100, duration = 3 },
	evade = { chance = 50, value = 5, max = 30, duration = 3 },
	crit = { chance = 50, value = 20, max = 100, duration = 3 },
	health = { healthLoss = 300, value = 150, duration = 5 },
	regen = { chance = 25, value = 40 },
	ulti = { per = 50, value = 10 },
	poison = { chance = 30, value = 10 },
	ice = { chance = 30, value = 10 },
	shield = { chance = 30, value = 10 },
	injury = { chance = 30, value = 8 },
	wisp = { interval = 1, value = 3 },
	fury = { chance = 30, value = 10 },
}

-- Базовые параметры крипов (HP/атака — в Config.Creeps)
Config.CreepBase = {
	Interval = 1.0,
	Crit = 10,
	CritMult = 150,
	Evade = 8,
	ManaRegen = 8,
	UltDamage = 60, -- урон «удара крипа» = 60 + 40 x уровень крипа
	UltDamagePerTier = 40,
	StyleLevelByTier = { 2, 3, 4 }, -- уровень стиля крипа
	HeroLevelByTier = { 6, 9, 12 },
	HpMulByTier = { 1.4, 2.4, 4 }, -- крипы растут вместе с героями
	AtkMulByTier = { 1.3, 2, 3 },
}

---------------------------------------------------------------------------
-- Урон курьеру
---------------------------------------------------------------------------
Config.CourierDamage = {
	Base = 2,
	PerTurns = 10, -- +1 за каждые 10 ходов
	StreakMax = 4, -- + серия побед победителя, до 4
	PerHeroLevels = 5, -- +1 за каждые 5 уровней героя победителя
	CapBase = 5, -- лимит урона за ход: 5 + ход / 2
	CapPerTurn = 0.5,
	CreepDamage = 2, -- если CreepLossDamagesCourier = true
}

---------------------------------------------------------------------------
-- Боты
---------------------------------------------------------------------------
Config.Bots = {
	Names = { "Бот Сакура", "Бот Ичиго", "Бот Ханако", "Бот Рин", "Бот Кайто", "Бот Мику", "Бот Джин", "Бот Юки" },
	RerollWhenGoldAbove = 250, -- бот рероллит, если золота больше
	KeepGoldForInterest = 0.35, -- доля золота, которую бот старается копить
	OwnStyleBias = 3, -- насколько бот предпочитает стили героя
}

---------------------------------------------------------------------------
-- Арены и визуал
---------------------------------------------------------------------------
Config.Arena = {
	Count = 8,
	-- Сдвиг каждой следующей копии арены (studs). Оригинал = арена 1.
	Offset = { x = 600, y = 0, z = 0 },
	-- Что клонировать: пути от workspace. Отсутствующие пропускаются.
	CloneSources = { "Dressing/Arena", "Map/Arena" },
	-- Дополнительно клонировать детали workspace.Map в этом радиусе от
	-- ArenaCenter (если геометрия арены лежит прямо в модели Map).
	CloneMapRadius = 220,
	ArenaZ = -450,
	FighterWalkSpeed = 0, -- бойцы стоят на месте, бой «стоячий»
}

---------------------------------------------------------------------------
-- Герои (стартовые 6). Модели: ServerStorage.Gladiators.<Model>.
-- Анимации: rbxassetid; 0 = нет анимации, используется заглушка.
---------------------------------------------------------------------------
Config.Heroes = {
	narato = {
		order = 1,
		name = "Нарато",
		model = "Narato",
		styles = { "wisp" },
		hp = 1100, atk = 24, interval = 1.0, crit = 15, critMult = 150, evade = 14, manaRegen = 10,
		passive = {
			name = "Теневой клон",
			desc = "В начале боя создаёт теневого клона-стража ({hp} HP). Клон забирает {share}% урона по герою и атакует врага.",
			cloneHp = 260, cloneShare = 35, cloneAtk = 18,
		},
		ult = {
			name = "Расенган",
			desc = "Врезается во врага сферой чакры: {dmg} магического урона и оглушение {stun} сек. +{perClone} урона за каждого живого клона.",
			dmg = 160, stun = 0.4, perClone = 60,
		},
		talents = {
			[5] = {
				{ id = "narato_clone_hp", name = "Плотная чакра", desc = "+200 HP теневому клону.", cloneHp = 200 },
				{ id = "narato_rasen_dmg", name = "Большой Расенган", desc = "+60 урона Расенгана.", dmg = 60 },
			},
			[10] = {
				{ id = "narato_second_clone", name = "Множественные клоны", desc = "В начале боя появляется второй клон с 60% HP.", ratio = 0.6 },
				{ id = "narato_clone_mana", name = "Связь чакры", desc = "Каждая атака клона даёт герою 3 маны.", mana = 3 },
			},
			[15] = {
				{ id = "narato_rasenshuriken", name = "Расен-сюрикен", desc = "Расенган наносит ещё 40% урона чистым уроном.", pct = 40 },
				{ id = "narato_sage", name = "Режим мудреца", desc = "Клоны восстанавливают герою 2% макс. HP при смерти и Расенган призывает нового клона.", healPct = 2 },
			},
		},
		anims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 },
	},
	zazke = {
		order = 2,
		name = "Дзадзке",
		model = "Zazke",
		styles = { "crit", "fury" },
		hp = 1100, atk = 28, interval = 0.95, crit = 20, critMult = 150, evade = 14, manaRegen = 11,
		passive = {
			name = "Шаринган",
			desc = "Каждый крит даёт {fury} стаков Ярости. Шанс {evade}% предугадать удар и уклониться дополнительно.",
			fury = 12, evade = 6,
		},
		ult = {
			name = "Чидори",
			desc = "Пронзает врага молнией: {dmg} физического урона, гарантированный крит, +{fury} стаков Ярости.",
			dmg = 170, fury = 30,
		},
		talents = {
			[5] = {
				{ id = "zazke_crit", name = "Глаз молнии", desc = "+6 шанса крита.", crit = 6 },
				{ id = "zazke_chidori_dmg", name = "Острое Чидори", desc = "+50 урона Чидори.", dmg = 50 },
			},
			[10] = {
				{ id = "zazke_fury_crit", name = "Проклятая печать", desc = "Каждые 40 стаков Ярости дают +5 шанса крита.", per = 40, crit = 5 },
				{ id = "zazke_double", name = "Двойное Чидори", desc = "Чидори бьёт дважды (второй удар 50%).", pct = 50 },
			},
			[15] = {
				{ id = "zazke_amaterasu", name = "Аматэрасу", desc = "Криты накладывают 12 стаков Яда (чёрное пламя).", poison = 12 },
				{ id = "zazke_susanoo", name = "Сусаноо", desc = "При HP ниже 30% один раз получает 300 стаков Щита.", shield = 300 },
			},
		},
		anims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 },
	},
	koku = {
		order = 3,
		name = "Коку",
		model = "Koku",
		styles = { "ulti", "attack" },
		hp = 1100, atk = 25, interval = 1.0, crit = 14, critMult = 150, evade = 13, manaRegen = 12,
		passive = {
			name = "Кровь сайяна",
			desc = "Каждое применение ульта навсегда (до конца боя) даёт +{atk} атаки и +{as} скорости атаки.",
			atk = 6, as = 10,
		},
		ult = {
			name = "Камехамеха",
			desc = "Волна энергии: {dmg} магического урона + {perAtk}% от текущей атаки.",
			dmg = 200, perAtk = 200,
		},
		talents = {
			[5] = {
				{ id = "koku_kame_dmg", name = "Заряженная волна", desc = "+60 урона Камехамехи.", dmg = 60 },
				{ id = "koku_mana", name = "Тренировка у Кайо", desc = "+3 к восстановлению маны.", manaRegen = 3 },
			},
			[10] = {
				{ id = "koku_saiyan", name = "Супер-сайян", desc = "Кровь сайяна даёт вдвое больше атаки.", mul = 2 },
				{ id = "koku_refund", name = "Мгновенная передача", desc = "После ульта возвращает 25 маны.", mana = 25 },
			},
			[15] = {
				{ id = "koku_ultra", name = "Ультра-инстинкт", desc = "+15 уклонения и +20% снижения урона при уклонении.", evade = 15, evadeReduce = 20 },
				{ id = "koku_spirit", name = "Генки-дама", desc = "Каждый третий ульт наносит тройной урон.", every = 3, mul = 3 },
			},
		},
		anims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 },
	},
	tuffy = {
		order = 4,
		name = "Таффи",
		model = "Tuffy",
		styles = { "health", "regen" },
		hp = 1350, atk = 23, interval = 1.0, crit = 12, critMult = 150, evade = 12, manaRegen = 10,
		passive = {
			name = "Резиновое тело",
			desc = "Снижает получаемый физический урон на {reduce}%. Каждые {interval} сек. восстанавливает {heal} HP.",
			reduce = 12, interval = 2, heal = 30,
		},
		ult = {
			name = "Второй гир",
			desc = "Разгоняет кровь: +{as} скорости атаки и восстановление {heal} HP каждые 0.5 сек. в течение {dur} сек.",
			as = 100, heal = 15, dur = 4,
		},
		talents = {
			[5] = {
				{ id = "tuffy_gear_dur", name = "Выносливость", desc = "+1.5 сек. длительности Второго гира.", dur = 1.5 },
				{ id = "tuffy_rubber", name = "Толстая резина", desc = "+8% снижения физического урона.", reduce = 8 },
			},
			[10] = {
				{ id = "tuffy_gear3", name = "Третий гир", desc = "Ульт также наносит 120 физического урона (гигантский кулак).", dmg = 120 },
				{ id = "tuffy_meat", name = "Мясо!", desc = "Лечение усилено на 20%.", healPct = 20 },
			},
			[15] = {
				{ id = "tuffy_gear4", name = "Четвёртый гир", desc = "Пока действует гир, урон героя +40%.", pct = 40 },
				{ id = "tuffy_will", name = "Воля короля", desc = "Один раз при смерти выживает с 1 HP и оглушает врага на 1.5 сек.", stun = 1.5 },
			},
		},
		anims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 },
	},
	sound_hashira = {
		order = 5,
		name = "Звуковой Хашира",
		model = "SoundHashira",
		styles = { "injury" },
		hp = 1150, atk = 24, interval = 0.9, crit = 15, critMult = 150, evade = 12, manaRegen = 10,
		passive = {
			name = "Партитура",
			desc = "Каждая атака ставит звуковую метку (до {max}) и накладывает {injury} стака Уязвимости.",
			max = 20, injury = 2,
		},
		ult = {
			name = "Звуковой взрыв",
			desc = "Подрывает все метки: {perMark} магического урона за метку + {base}. Метки сбрасываются.",
			perMark = 20, base = 60,
		},
		talents = {
			[5] = {
				{ id = "sound_marks", name = "Громкая партитура", desc = "+10 к максимуму меток.", max = 10 },
				{ id = "sound_injury", name = "Резонанс", desc = "+2 стака Уязвимости за атаку.", injury = 2 },
			},
			[10] = {
				{ id = "sound_keep", name = "Эхо", desc = "После взрыва остаётся 30% меток.", keep = 30 },
				{ id = "sound_perm", name = "Глухота", desc = "Взрыв накладывает 1 постоянную Уязвимость за каждые 4 метки.", per = 4 },
			},
			[15] = {
				{ id = "sound_double", name = "Двойные клинки", desc = "Каждая атака ставит 2 метки.", marks = 2 },
				{ id = "sound_pure", name = "Звуковой удар", desc = "Урон взрыва становится чистым.", pure = true },
			},
		},
		anims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 },
	},
	blood_demon = {
		order = 6,
		name = "Кровавый Демон",
		model = "BloodDemon",
		styles = { "poison" },
		hp = 1150, atk = 24, interval = 1.0, crit = 14, critMult = 150, evade = 14, manaRegen = 10,
		passive = {
			name = "Кровотечение",
			desc = "Каждая атака накладывает {poison} стаков Яда. Каждый тик яда по врагу лечит демона на {lifesteal}% урона.",
			poison = 4, lifesteal = 20,
		},
		ult = {
			name = "Кровавые серпы",
			desc = "Выпускает {count} серпов: каждый наносит {dmg} магического урона и накладывает {poison} стаков Яда.",
			count = 4, dmg = 25, poison = 8,
		},
		talents = {
			[5] = {
				{ id = "demon_sickles", name = "Больше серпов", desc = "+2 серпа.", count = 2 },
				{ id = "demon_bleed", name = "Глубокие раны", desc = "+3 стака Яда за атаку.", poison = 3 },
			},
			[10] = {
				{ id = "demon_regen", name = "Демоническая регенерация", desc = "Каждую секунду восстанавливает 1% макс. HP.", pct = 1 },
				{ id = "demon_lifesteal", name = "Жажда крови", desc = "+25% лечения от яда.", lifesteal = 25 },
			},
			[15] = {
				{ id = "demon_explode", name = "Кровавый взрыв", desc = "Серпы наносят доп. урон 5% от текущих стаков Яда на враге.", pct = 5 },
				{ id = "demon_immortal", name = "Бессмертие демона", desc = "Один раз при смерти восстанавливает 35% HP.", pct = 35 },
			},
		},
		anims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 },
	},
}

-- Порядок героев для UI/генераторов
Config.HeroOrder = { "narato", "zazke", "koku", "tuffy", "sound_hashira", "blood_demon" }

-- Заглушка анимаций (если у героя ID = 0). Тоже 0 = не проигрывать.
Config.FallbackAnims = { Idle = 0, Attack = 0, Ult = 0, Hit = 0, Death = 0, Victory = 0 }

---------------------------------------------------------------------------
-- Контент
---------------------------------------------------------------------------
Config.Cards = sub("Cards")
Config.Items = sub("Items")
Config.Artifacts = sub("Artifacts")
Config.Traits = sub("Traits")
Config.Territories = sub("Territories")
Config.Creeps = sub("Creeps")

return Config
