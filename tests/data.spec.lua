local Config = R("shared/Config")

T.suite("Данные")

local KNOWN_STYLES = {}
for _, s in ipairs(Config.Styles.Order) do
	KNOWN_STYLES[s] = true
end

T.test("12 стилей с бонусами на 4 уровня", function()
	T.eq(#Config.Styles.Order, 12)
	for _, s in ipairs(Config.Styles.Order) do
		local d = Config.Styles.Data[s]
		T.ok(d, "нет данных стиля " .. s)
		T.ok(d.name and d.desc)
		for key, arr in pairs(d.bonus) do
			T.eq(#arr, 4, s .. "." .. key)
		end
	end
end)

T.test("150 карт, уникальные id, корректные стили и редкость", function()
	T.eq(#Config.Cards, 150)
	local seen = {}
	local counts = { n = 0, r = 0, sr = 0 }
	for _, c in ipairs(Config.Cards) do
		T.ok(not seen[c.id], "дубль id " .. c.id)
		seen[c.id] = true
		T.ok(counts[c.r] ~= nil, "редкость " .. tostring(c.r))
		counts[c.r] = counts[c.r] + 1
		T.ok(#c.s >= 1 and #c.s <= 2, "стили карты " .. c.id)
		for _, s in ipairs(c.s) do
			T.ok(KNOWN_STYLES[s], "неизвестный стиль " .. s .. " у карты " .. c.id)
		end
		T.ok(type(c.name) == "string" and #c.name > 0)
		T.ok(type(c.desc) == "string" and #c.desc > 0)
		T.ok(c.fx and #c.fx >= 1, "нет эффектов у карты " .. c.id)
		if c.desc:find("{v}") then
			T.ok(c.v ~= nil, "нет v у карты " .. c.id)
		end
		if c.desc:find("{v2}") then
			T.ok(c.v2 ~= nil, "нет v2 у карты " .. c.id)
		end
	end
	T.eq(counts.n, 90)
	T.eq(counts.r, 36)
	T.eq(counts.sr, 24)
end)

T.test("6 героев с конфигом анимаций и талантами на 5/10/15", function()
	T.eq(#Config.HeroOrder, 6)
	for _, id in ipairs(Config.HeroOrder) do
		local h = Config.Heroes[id]
		T.ok(h and h.model and h.anims and h.ult and h.passive, id)
		for _, lvl in ipairs(Config.Match.TalentLevels) do
			T.ok(h.talents[lvl] and #h.talents[lvl] >= 2, id .. " таланты " .. lvl)
		end
		for _, s in ipairs(h.styles) do
			T.ok(KNOWN_STYLES[s])
		end
	end
end)

T.test("предметы, артефакты, черты, территории, крипы на месте", function()
	T.ok(#Config.Items >= 40)
	T.ok(#Config.Artifacts >= 30)
	T.ok(#Config.Traits >= 20)
	T.ok(#Config.Territories >= Config.Match.TerritoryChoices)
	for tier = 1, 3 do
		local n = 0
		for _, c in ipairs(Config.Creeps) do
			if c.tier == tier then
				n = n + 1
				T.ok(KNOWN_STYLES[c.style], c.id)
			end
		end
		T.ok(n >= 3, "мало крипов уровня " .. tier)
		local items = 0
		for _, it in ipairs(Config.Items) do
			if it.tier == tier then
				items = items + 1
			end
		end
		T.ok(items >= Config.Match.ItemChoices, "мало предметов уровня " .. tier)
	end
	for _, turn in ipairs({ 3, 8, 13 }) do
		local n = 0
		for _, a in ipairs(Config.Artifacts) do
			for _, t in ipairs(a.turns) do
				if t == turn then
					n = n + 1
				end
			end
		end
		T.ok(n >= Config.Match.ArtifactChoices, "мало артефактов хода " .. turn)
	end
end)

T.test("описания карт форматируются без незаполненных {v}", function()
	local Text = R("shared/Text")
	for _, c in ipairs(Config.Cards) do
		for star = 1, 5 do
			local s = Text.cardDesc(c, star)
			T.ok(not s:find("{v"), "карта " .. c.id .. ": " .. s)
		end
	end
	T.eq(Text.cardDesc(Config.Cards[1], 5), "С шансом 60% восстанавливает 60 HP при каждой атаке.")
	for _, id in ipairs(Config.HeroOrder) do
		local h = Config.Heroes[id]
		T.ok(not Text.heroText(h.passive):find("{"), id .. " пассив")
		T.ok(not Text.heroText(h.ult):find("{"), id .. " ульт")
	end
end)
