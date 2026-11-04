--!nocheck
-- Снаряжение (выпадает с крипов на 5/10/15 ходу). tier = уровень предмета.
-- fx использует тот же DSL, что и карты (см. Cards.lua); значение v одно.
local function on(ev, chance, a, extra)
	local e = { k = "on", ev = ev, chance = chance, a = a }
	if extra then
		for key, value in pairs(extra) do
			e[key] = value
		end
	end
	return e
end

return {
	{ id = "brigand_blade", tier = 1, name = "Клинок разбойника", desc = "При нанесении урона с шансом 8% накладывает 6 стаков Уязвимости.", v = 6, fx = { on("dealDamage", 8, { "injury" }) } },
	{ id = "faerie_fire", tier = 1, name = "Волшебный огонь", desc = "Восстанавливает 30 HP при крите. Перезарядка 0.5 сек.", v = 30, fx = { on("crit", 100, { "heal" }, { cd = 0.5 }) } },
	{ id = "mango", tier = 1, name = "Манго", desc = "В начале боя получает 20 маны.", v = 20, fx = { { k = "start", a = { "mana" } } } },
	{ id = "orb_corrosion", tier = 1, name = "Сфера разъедания", desc = "Противник получает на 2 стака Щита меньше.", v = 2, fx = { { k = "stat", stat = "enemyShieldMinus", key = "v" } } },
	{ id = "poor_shield", tier = 1, name = "Щит бедняка", desc = "При получении физ. урона с шансом 12% даёт 8 стаков Щита.", v = 8, fx = { on("damagedPhys", 12, { "shield" }) } },
	{ id = "javelin", tier = 1, name = "Дротик", desc = "Атаки с шансом 20% наносят ещё 30 магического урона.", v = 30, fx = { on("attack", 20, { "dmg", t = "magic" }) } },
	{ id = "mekansm", tier = 1, name = "Мекансм", desc = "Каждые 3 сек. восстанавливает 45 HP.", v = 45, fx = { { k = "every", t = 3, a = { "heal" } } } },
	{ id = "spirit_vessel", tier = 1, name = "Сосуд духа", desc = "Лечение противника -20%.", v = 20, fx = { { k = "stat", stat = "enemyHealReduce", key = "v" } } },
	{ id = "arcane_ring", tier = 1, name = "Чародейское кольцо", desc = "Каждую секунду получает 2 маны.", v = 2, fx = { { k = "every", t = 1, a = { "mana" } } } },
	{ id = "dagger_ristul", tier = 1, name = "Кинжал Ристула", desc = "За каждые 300 потерянного HP +2 атаки.", v = 2, fx = { { k = "hpLoss", per = 300, a = { "grow", stat = "baseAtk" } } } },
	{ id = "sign_arachnid", tier = 1, name = "Знак арахнида", desc = "За каждые 300 потерянного HP +4 скорости атаки.", v = 4, fx = { { k = "hpLoss", per = 300, a = { "grow", stat = "atkSpeed" } } } },
	{ id = "flintstone", tier = 1, name = "Кремень", desc = "Атака с шансом 12% даёт 8 стаков Ярости.", v = 8, fx = { on("attack", 12, { "fury" }) } },
	{ id = "band_elvenskin", tier = 1, name = "Эльфийская повязка", desc = "Первые 4 сек. боя уклоняется от всех физических атак.", v = 4, fx = { { k = "special", id = "item_elvenskin" } } },
	{ id = "gauntlets", tier = 1, name = "Перчатки силы", desc = "Каждые 4 сек. следующая атака гарантированно критует.", v = 4, fx = { { k = "special", id = "item_gauntlets" } } },
	{ id = "winter_lotus", tier = 1, name = "Зимний лотос", desc = "Один раз при HP ниже 30%: лечит 200 HP и накладывает 100 Заморозки.", v = 200, fx = { { k = "below", pct = 30, a = { "multi", list = { { "heal", val = 200 }, { "ice", val = 100 } } } } } },
	{ id = "pavise", tier = 1, name = "Павеза", desc = "Один раз при HP ниже 30% даёт 100 стаков Щита.", v = 100, fx = { { k = "below", pct = 30, a = { "shield" } } } },
	{ id = "claymore", tier = 1, name = "Клеймор", desc = "+1 атаки за каждый сыгранный ход.", v = 1, fx = { { k = "special", id = "item_claymore" } } },
	{ id = "whisper_dread", tier = 1, name = "Шёпот ужаса", desc = "Когда противник применяет ульт, он теряет 15 маны.", v = 15, fx = { on("enemyUlt", 100, { "drainMana" }) } },

	{ id = "vampire_fangs", tier = 2, name = "Клыки вампира", desc = "При нанесении урона с шансом 12% восстанавливает 16 HP.", v = 16, fx = { on("dealDamage", 12, { "heal" }) } },
	{ id = "cloak_flames", tier = 2, name = "Плащ пламени", desc = "Каждую секунду: +8 Ярости и магический урон = 20% стаков Ярости.", v = 8, fx = { { k = "every", t = 1, a = { "multi", list = { { "fury", val = 8 }, { "dmg", t = "magic", val = 0, plusSelfStack = "fury", mul = 0.2 } } } } } },
	{ id = "lance_pursuit", tier = 2, name = "Копьё преследования", desc = "Каждый крит наносит ещё 40 чистого урона.", v = 40, fx = { on("crit", 100, { "dmg", t = "pure" }) } },
	{ id = "ghost_scepter", tier = 2, name = "Призрачный скипетр", desc = "Один раз при HP ниже 30%: 1 сек. иммунитета к физическому урону.", v = 1, fx = { { k = "below", pct = 30, a = { "physImmune" } } } },
	{ id = "vanguard", tier = 2, name = "Авангард", desc = "При получении физ. урона с шансом 20% даёт 10 стаков Щита.", v = 10, fx = { on("damagedPhys", 20, { "shield" }) } },
	{ id = "wraith_pact", tier = 2, name = "Пакт призраков", desc = "Первые 3 сек. боя урон противника -35%.", v = 35, fx = { { k = "special", id = "item_wraith_pact" } } },
	{ id = "eternal_shroud", tier = 2, name = "Вечный саван", desc = "При HP ниже 50%: +20% к лечению и -20% магического урона.", v = 20, fx = { { k = "below", pct = 50, a = { "multi", list = { { "grow", stat = "healAmp", val = 20 }, { "grow", stat = "magicReduce", val = 20 } } } } } },
	{ id = "lotus_orb", tier = 2, name = "Сфера лотоса", desc = "Каждые 2 сек. снимает 30% своих негативных стаков.", v = 30, fx = { { k = "every", t = 2, a = { "cleansePct" } } } },
	{ id = "ogre_femur", tier = 2, name = "Счастливая кость огра", desc = "Ульт с шансом 20% срабатывает дважды.", v = 20, fx = { { k = "stat", stat = "ultDouble", key = "v" } } },
	{ id = "elven_tunic", tier = 2, name = "Эльфийская туника", desc = "Урон стражей +20%.", v = 20, fx = { { k = "stat", stat = "wardAtkPct", key = "v" } } },
	{ id = "ascetic_cap", tier = 2, name = "Шапка аскета", desc = "Получаемый крит. урон -20%.", v = 20, fx = { { k = "stat", stat = "critTakenReduce", key = "v" } } },
	{ id = "blade_mail", tier = 2, name = "Клинковая броня", desc = "За каждые 600 потерянного HP наносит 40 чистого урона.", v = 40, fx = { { k = "hpLoss", per = 600, a = { "dmg", t = "pure" } } } },
	{ id = "enchanted_quiver", tier = 2, name = "Зачарованный колчан", desc = "Раз в 2 сек. атака наносит ещё 80 магического урона.", v = 80, fx = { on("attack", 100, { "dmg", t = "magic" }, { cd = 2 }) } },
	{ id = "howl_eldwurm", tier = 2, name = "Вой древних змиев", desc = "При наложении Заморозки с шансом 15% наносит 60 магического урона.", v = 60, fx = { on("ice", 15, { "dmg", t = "magic" }) } },
	{ id = "talisman_evasion", tier = 2, name = "Талисман уклонения", desc = "При HP ниже 50% +4 уклонения.", v = 4, fx = { { k = "below", pct = 50, a = { "grow", stat = "evade" } } } },
	{ id = "soul_booster", tier = 2, name = "Усилитель души", desc = "+30 макс. HP за каждый уровень героя.", v = 30, fx = { { k = "special", id = "item_soul_booster" } } },
	{ id = "claws_luscius", tier = 2, name = "Когти Люсиуса", desc = "Атаки с шансом 20% накладывают 6 стаков Яда.", v = 6, fx = { on("attack", 20, { "poison" }) } },
	{ id = "defiant_shell", tier = 2, name = "Дерзкий панцирь", desc = "При получении урона контратакует. Перезарядка 2.5 сек.", v = 0, fx = { on("damaged", 100, { "attack" }, { cd = 2.5 }) } },
	{ id = "nemesis_curse", tier = 2, name = "Проклятие немезиды", desc = "Накладываемая Уязвимость +6 стаков.", v = 6, fx = { { k = "stat", stat = "injuryApply", key = "v" } } },
	{ id = "soul_diffuser", tier = 2, name = "Рассеиватель души", desc = "Атака с шансом 30% сжигает 5 маны противника.", v = 5, fx = { on("attack", 30, { "drainMana" }, { cd = 0.5 }) } },
	{ id = "phylactery", tier = 2, name = "Филактерий", desc = "Каждый ульт наносит ещё 40 + 5 x уровень героя чистого урона.", v = 40, fx = { on("ult", 100, { "dmg", t = "pure", plusLevel = 5 }) } },

	{ id = "mind_breaker", tier = 3, name = "Ломатель разума", desc = "Атака накладывает безмолвие на 1.5 сек. и 150 магического урона. Перезарядка 3 сек.", v = 150, fx = { on("attack", 100, { "multi", list = { { "dmg", t = "magic" }, { "silence", val = 1.5 } } }, { cd = 3 }) } },
	{ id = "spell_prism", tier = 3, name = "Призма заклинаний", desc = "После ульта получает 20 маны.", v = 20, fx = { on("ult", 100, { "mana" }) } },
	{ id = "trickster_cloak", tier = 3, name = "Плащ обманщика", desc = "Получаемые негативные стаки -8 за раз.", v = 8, fx = { { k = "stat", stat = "debuffFlatReduce", key = "v" } } },
	{ id = "witless_shako", tier = 3, name = "Шако глупца", desc = "Каждые 500 макс. HP дают +1% ко всему урону.", v = 1, fx = { { k = "special", id = "item_shako" } } },
	{ id = "heavens_halberd", tier = 3, name = "Небесная алебарда", desc = "Один раз при HP ниже 50%: физ. урон противника -70% на 2 сек.", v = 70, fx = { { k = "below", pct = 50, a = { "enemyPhysWeaken", dur = 2 } } } },
	{ id = "heart_tarrasque", tier = 3, name = "Сердце Тарраска", desc = "Каждую секунду восстанавливает 20 HP, лечение +20%.", v = 20, fx = { { k = "every", t = 1, a = { "heal" } }, { k = "stat", stat = "healAmp", key = "v" } } },
	{ id = "minotaur_horn", tier = 3, name = "Рог минотавра", desc = "Один раз при HP ниже 30%: снимает все дебаффы и -70% магического урона на 2 сек.", v = 70, fx = { { k = "below", pct = 30, a = { "multi", list = { { "cleansePct", val = 100 }, { "tempMagicReduce", val = 70, dur = 2 } } } } } },
	{ id = "witch_blade", tier = 3, name = "Клинок ведьмы", desc = "Урон Ядом +20%.", v = 20, fx = { { k = "stat", stat = "poisonAmp", key = "v" } } },
	{ id = "orb_frost", tier = 3, name = "Сфера мороза", desc = "За каждые 160 наложенных стаков Заморозки наносит 140 чистого урона.", v = 140, fx = { { k = "applyAccum", stack = "ice", per = 160, a = { "dmg", t = "pure" } } } },
	{ id = "lotus_capsule", tier = 3, name = "Антитоксичная капсула", desc = "Каждую секунду снимает 25% своего Яда.", v = 25, fx = { { k = "every", t = 1, a = { "cleanseStack", s = "poison" } } } },
	{ id = "kindle_staff", tier = 3, name = "Посох растопки", desc = "Каждые 16% потерянного HP дают 7% снижения урона.", v = 7, fx = { { k = "special", id = "item_kindle" } } },
	{ id = "timeless_relic", tier = 3, name = "Вечная реликвия", desc = "Один раз при HP ниже 40% применяет ульт.", v = 0, fx = { { k = "below", pct = 40, a = { "ult" } } } },
	{ id = "revenant_brooch", tier = 3, name = "Брошь призрака", desc = "Урон атаки +15%.", v = 15, fx = { { k = "stat", stat = "atkPct", key = "v" } } },
	{ id = "butterfly", tier = 3, name = "Бабочка", desc = "+12 уклонения, +10% снижения урона при уклонении.", v = 12, fx = { { k = "stat", stat = "evade", key = "v" }, { k = "stat", stat = "evadeReduce", val = 10 } } },
	{ id = "arcanist_armor", tier = 3, name = "Доспех арканиста", desc = "При получении крита с шансом 30% отражает 60% урона чистым уроном.", v = 60, fx = { on("critTaken", 30, { "dmgCtx", t = "pure", field = "amount", noReflect = true }) } },
	{ id = "martyr_plate", tier = 3, name = "Латы мученика", desc = "Каждую секунду 10% полученного урона превращается в Щит.", v = 10, fx = { { k = "special", id = "item_martyr" } } },
	{ id = "stygian_desolator", tier = 3, name = "Стигийский десолятор", desc = "Удар сильнее 100 накладывает 20 Уязвимости. Перезарядка 3 сек.", v = 20, fx = { on("bigHit", 100, { "injury" }, { cd = 3 }) } },
	{ id = "monkey_king_bar", tier = 3, name = "Посох короля обезьян", desc = "Атаки с шансом 35% игнорируют уклонение и наносят 120 магического урона.", v = 120, fx = { on("attack", 35, { "dmg", t = "magic" }), { k = "stat", stat = "ignoreEvade", val = 35 } } },
	{ id = "giant_slayer", tier = 3, name = "Кольцо убийцы великанов", desc = "За каждые 600 HP противника урон по нему +2%.", v = 2, fx = { { k = "special", id = "item_giant_slayer" } } },
	{ id = "eye_skadi", tier = 3, name = "Око Скади", desc = "Лечение противника -25%.", v = 25, fx = { { k = "stat", stat = "enemyHealReduce", key = "v" } } },
	{ id = "unwavering", tier = 3, name = "Непоколебимость", desc = "Эффект ульта противника -30%.", v = 30, fx = { { k = "stat", stat = "enemyUltReduce", key = "v" } } },
	{ id = "shiva_guard", tier = 3, name = "Стража Шивы", desc = "Каждую секунду: 12 Заморозки и магический урон 20% от Заморозки на враге.", v = 12, fx = { { k = "every", t = 1, a = { "multi", list = { { "ice", val = 12 }, { "dmg", t = "magic", val = 0, plusEnemyStack = "ice", mul = 0.2 } } } } } },
	{ id = "stormcrafter", tier = 3, name = "Повелитель бурь", desc = "Каждые 2 сек. наносит 200 магического урона.", v = 200, fx = { { k = "every", t = 2, a = { "dmg", t = "magic" } } } },
	{ id = "helm_overlord", tier = 3, name = "Шлем владыки", desc = "HP стражей +20%, урон стражей +20%.", v = 20, fx = { { k = "stat", stat = "wardHpPct", key = "v" }, { k = "stat", stat = "wardAtkPct", key = "v" } } },
	{ id = "blade_ember", tier = 3, name = "Клинок углей", desc = "Атака с шансом 30% крадёт до 30 Ярости противника.", v = 30, fx = { on("attack", 30, { "stealStack", s = "fury" }) } },
}
