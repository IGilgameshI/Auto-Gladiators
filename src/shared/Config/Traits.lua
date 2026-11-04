--!nocheck
-- Черты (выбираются в начале игры, 1 из 3).
-- meta  — эффекты на экономику/прогресс (Game/Meta.lua)
-- battle — модификаторы боя (Combat/Builder.lua -> спецификация бойца)
return {
	{ id = "trustfund", name = "Мажор", desc = "+300 золота в начале игры, базовый доход +20 за ход.", meta = { startGold = 300, income = 20 } },
	{ id = "noble", name = "Знатный род", desc = "4 хода подряд даёт случайную обычную карту стиля героя.", meta = { freeHeroCards = 4 } },
	{ id = "fragile", name = "Хрупкое тело", desc = "Макс. HP -15%, но 30% нанесённого урона восстанавливается как HP.", battle = { maxHpPct = -15, lifesteal = 30 } },
	{ id = "study", name = "Талант к учёбе", desc = "Опыт для уровней стиля -20%.", meta = { styleXpReq = -20 } },
	{ id = "berserker", name = "Берсерк", desc = "Наносимый урон +30%, получаемый +15%.", battle = { dmgAmp = 30, dmgTakenAmp = 15 } },
	{ id = "zombie", name = "Зомби", desc = "Макс. HP +30%, физ./маг. урон по вам -15%, лечение невозможно.", battle = { maxHpPct = 30, physReduce = 15, magicReduce = 15, noHeal = 1 } },
	{ id = "sharpshooter", name = "Стрелок", desc = "Бонус скорости атаки x2, урон атаки -20%.", battle = { atkSpeedMul = 100, atkPct = -20 } },
	{ id = "apex", name = "Мастер меча", desc = "+5 скорости атаки и +5 атаки за уровень героя.", battle = { atkSpeedPerLevel = 5, atkPerLevel = 5 } },
	{ id = "wager", name = "Пари", desc = "Бонусы за серии и победы +300 к пределу, но нет процентов.", meta = { streakCapBonus = 300, noInterest = true } },
	{ id = "ironman", name = "Железный человек", desc = "Получаемый Щит +30%, 10% Щита добавляется к урону атаки.", battle = { shieldGainPct = 30, shieldToAtk = 10 } },
	{ id = "sniper", name = "Меткий снайпер", desc = "Скорость атаки -20%, шанс крита +20, крит. урон +150%, атаки игнорируют 50% уклонения.", battle = { atkSpeed = -20, crit = 20, critDmg = 150, ignoreEvade = 50 } },
	{ id = "medic", name = "Медик", desc = "Лечение +15%, урон -40%; HP от лечения дополнительно бьёт врага (110%).", battle = { healAmp = 15, dmgAmp = -40, healToDamage = 110 } },
	{ id = "giant_slayer", name = "Убийца великанов", desc = "Пока у врага больше HP, чем у вас, урон +60%.", battle = { giantSlayer = 60 } },
	{ id = "lucky_dog", name = "Везунчик", desc = "При каждом повышении уровня героя — случайная карта стиля героя (до 10 раз).", meta = { levelUpCards = 10 } },
	{ id = "arcane", name = "Тайное превосходство", desc = "+10% эффекта ульта за уровень героя (до 150%), 60 маны в начале боя, но от вас нельзя уклониться.", battle = { ultPerLevel = 10, startMana = 60, cannotEvade = 1 } },
	{ id = "ward_protector", name = "Защитник стражей", desc = "Стражи не делят урон, интервал стражей -0.1, каждая единица HP стража +1 HP героя.", battle = { wardNoShare = 1, wardInterval = -0.1, wardHpToHero = 1 } },
	{ id = "venom", name = "Отравитель", desc = "Урон Ядом +20%, физ./маг. урон -30%. Начинает с картой «Длительный токсин».", battle = { poisonAmp = 20, physMagicAmp = -30 }, meta = { startCard = 82 } },
	{ id = "cold_blooded", name = "Хладнокровный", desc = "Иммунитет к Заморозке, -50% получаемой Ярости, враг получает 10 постоянной Заморозки. Начинает с «Длительным холодом».", battle = { iceImmune = 1, furyGainPct = -50, enemyPermIce = 10 }, meta = { startCard = 92 } },
	{ id = "time_dilation", name = "Замедление времени", desc = "Урон противника в начале боя -40%, затем каждую секунду +1% (30 сек.).", battle = { timeDilation = 40 } },
	{ id = "entrepreneur", name = "Предприниматель", desc = "Нет процентов, но +5 базового дохода и +1% урона за уровень героя; карты дешевле на 10%; урон -30%.", meta = { noInterest = true, incomePerLevel = 5, cardDiscount = 10 }, battle = { dmgAmp = -30, dmgPerLevel = 1 } },
	{ id = "hoarder", name = "Скупердяй", desc = "Предел процентов +20 за каждые 5 уровней героя; каждые 100 золота дают +1% урона.", meta = { interestCapPer5Levels = 20 }, battle = { dmgPerGold100 = 1 } },
	{ id = "battery", name = "Батарейка", desc = "Восстановление маны -15%, каждый ульт даёт +20% эффекта ульта до конца боя.", battle = { manaRegenPct = -15, ultStack = 20 } },
	{ id = "vulcan", name = "Вулкан", desc = "Каждую секунду тратит 40 HP и получает 40 Ярости; наносит магический урон 35% от Ярости.", battle = { vulcan = 40 } },
}
