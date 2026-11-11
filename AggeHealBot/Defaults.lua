local _, A = ...
A.buttons = {"Left", "Right", "Middle", "Button 4", "Button 5"}
A.modifiers = {
    {label = "", prefix = ""}, {label = "Shift + ", prefix = "shift-"},
    {label = "Ctrl + ", prefix = "ctrl-"}, {label = "Alt + ", prefix = "alt-"},
    {label = "Ctrl + Shift + ", prefix = "ctrl-shift-"},
    {label = "Alt + Shift + ", prefix = "alt-shift-"},
    {label = "Alt + Ctrl + ", prefix = "alt-ctrl-"},
    {label = "Alt + Ctrl + Shift + ", prefix = "alt-ctrl-shift-"},
}
A.actionLabels = {spell = "Spell", target = "Target unit", assist = "Assist unit", togglemenu = "Unit menu", settings = "AggeHealBot settings", none = "Disabled"}
A.spellCategories = {
    heals = {8936, 5185, 774, 18562, 50464, 33763, 408124, 48438, 408120, 740,
        2050, 2054, 2060, 2061, 139, 17, 596, 32546, 401937, 33076, 401859, 34861, 401946, 64843,
        19750, 635, 20473, 633, 85673, 82327, 85222,
        331, 8004, 1064, 61295, 408521, 974, 408514, 5394, 73920,
        -- Forever 1.60.1.70888: distinct/new healing spells and their ranks.
        1238214, 1238215, 402174, 1240720, 1240721, 1316995,
        1240826, 1240827, 1239242, 1239243, 1311590, 1311595},
    buffs = {1126, 21849, 467, 29166, 22812, 16864, 16689,
        1243, 21562, 14752, 27681, 976, 27683, 588, 10060, 6346,
        19740, 19742, 20217, 1038, 19977, 20911, 1022, 1044, 6940,
        324, 24398, 408510, 52127, 546, 131, 25782, 25916, 25894, 25918, 25898},
    utility = {437138, 1237948, 1237949, 1237950, 1237951, 50769, 20484, 2006, 7328, 2008, 212036, 212040, 212048,
        2010, 10880, 10881, 20770, 10322, 10324, 20772, 20773,
        20609, 20610, 20776, 20777, 20739, 20742, 20747, 20748,
        2782, 2893, 8946, 88423, 527, 988, 528, 552, 4987, 1152, 526, 2870, 51886, 77130},
}

-- Binding data inspired by HealBot Continued's defaults, adapted to Forever.
-- Spell IDs are name lookups only: casts use names, selecting the learned rank.
-- Candidate lists prefer the first spell actually present in the spellbook.
A.presets = {
    DRUID = {
        {"Left", "", 1, {8936}},
        {"Right", "", 2, {5185}},
        {"Middle", "", 3, {774}},
        {"Ctrl + Left", "ctrl-", 1, {2782}},
        {"Ctrl + Right", "ctrl-", 2, {88423, 2893, 8946}},
        {"Ctrl + Middle", "ctrl-", 3, {50464, 18562}},
    },
    PRIEST = {
        {"Left", "", 1, {2061, 2050}},
        {"Right", "", 2, {2060, 2054, 2050}},
        {"Middle", "", 3, {139}},
        {"Shift + Left", "shift-", 1, {32546, 401937, 17}},
        {"Shift + Right", "shift-", 2, {2054, 2050}},
        {"Shift + Middle", "shift-", 3, {401859, 1240826, 1240827, 33076}},
        {"Ctrl + Left", "ctrl-", 1, {527, 988}},
        {"Ctrl + Right", "ctrl-", 2, {552, 528}},
        {"Ctrl + Middle", "ctrl-", 3, {64843}},
        {"Alt + Middle", "alt-", 3, {596}},
    },
    PALADIN = {
        {"Left", "", 1, {19750}},
        {"Right", "", 2, {635}},
        {"Middle", "", 3, {20473, 20929, 20930, 85673}},
        {"Shift + Right", "shift-", 2, {85222}},
        {"Shift + Middle", "shift-", 3, {82327}},
        {"Ctrl + Left", "ctrl-", 1, {4987, 1152}},
    },
    SHAMAN = {
        {"Left", "", 1, {331}},
        {"Right", "", 2, {8004}},
        {"Middle", "", 3, {408521, 1239242, 1239243, 61295, 73920}},
        {"Shift + Left", "shift-", 1, {1064}},
        {"Shift + Middle", "shift-", 3, {5394}},
        {"Ctrl + Left", "ctrl-", 1, {51886, 526}},
        {"Ctrl + Right", "ctrl-", 2, {77130, 2870}},
    },
}

A.buffs = {
    DRUID = {{1126, 21849}, {467}},
    PRIEST = {{1243, 21562}, {14752, 27681}, {976, 27683}},
}

-- Ascending strength, not numeric spell-ID order. Group buffs share the
-- strength of the matching single-target rank (Forever 1.60.1.70888).
A.buffRanks = {
    [1126] = {ranks = {1126, 5232, 6756, 5234, 8907, 9884, 9885}, equivalents = {[21849] = 6, [21850] = 7}},
    [467] = {ranks = {467, 782, 1075, 8914, 9756, 9910}},
    [1243] = {ranks = {1243, 1244, 1245, 2791, 10937, 10938}, equivalents = {[21562] = 5, [21564] = 6}},
    [14752] = {ranks = {14752, 14818, 14819, 27841}, equivalents = {[27681] = 4}},
    [976] = {ranks = {976, 10957, 10958}, equivalents = {[27683] = 3}},
}

-- Ordinary single-target resurrection spells have no reagent cost.
A.resurrections = {
    DRUID = {437138, 1237948, 1237949, 1237950, 1237951, 50769},
    PRIEST = {2006, 2010, 10880, 10881, 20770},
    PALADIN = {7328, 10322, 10324, 20772, 20773},
    SHAMAN = {2008, 20609, 20610, 20776, 20777},
}
A.combatResurrections = {DRUID = {20484, 20739, 20742, 20747, 20748}}
A.dispels = {
    DRUID = {{88423, "Magic", "Curse", "Poison"}, {2782, "Curse"}, {2893, "Poison"}, {8946, "Poison"}},
    PRIEST = {{527, "Magic"}, {988, "Magic"}, {552, "Disease"}, {528, "Disease"}},
    PALADIN = {{4987, "Magic", "Disease", "Poison"}, {1152, "Disease", "Poison"}},
    SHAMAN = {{77130, "Magic", "Curse"}, {51886, "Curse"}, {526, "Poison"}, {2870, "Disease"}},
}

-- HealBot's own menu has no equivalent here: Button 5 opens our small settings.
A.common = {
    {"Button 4", "", 4, "togglemenu"},
    {"Button 5", "", 5, "settings"},
    {"Shift + Button 4", "shift-", 4, "target"},
    {"Shift + Button 5", "shift-", 5, "assist"},
}
