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
        331, 8004, 1064, 61295, 408521, 974, 408514, 5394, 73920},
    buffs = {1126, 21849, 467, 29166, 22812, 16864, 16689,
        1243, 21562, 14752, 27681, 976, 27683, 588, 10060, 6346,
        1459, 23028, 168, 7302, 6117, 30482, 1008, 604, 130,
        19740, 19742, 20217, 1038, 19977, 20911, 1022, 1044, 6940,
        324, 24398, 408510, 52127, 546, 131},
    utility = {50769, 20484, 2006, 7328, 2008, 212036, 212040, 212048,
        2782, 2893, 8946, 88423, 527, 528, 552, 4987, 1152, 475, 526, 2870, 51886, 77130},
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
        {"Shift + Middle", "shift-", 3, {33076, 401859}},
        {"Ctrl + Left", "ctrl-", 1, {527}},
        {"Ctrl + Right", "ctrl-", 2, {552, 528}},
        {"Ctrl + Middle", "ctrl-", 3, {64843}},
        {"Alt + Middle", "alt-", 3, {596}},
    },
    PALADIN = {
        {"Left", "", 1, {19750}},
        {"Right", "", 2, {635}},
        {"Middle", "", 3, {85673, 20473}},
        {"Shift + Right", "shift-", 2, {85222}},
        {"Shift + Middle", "shift-", 3, {82327}},
        {"Ctrl + Left", "ctrl-", 1, {4987, 1152}},
    },
    SHAMAN = {
        {"Left", "", 1, {331}},
        {"Right", "", 2, {8004}},
        {"Middle", "", 3, {73920, 408521, 61295}},
        {"Shift + Left", "shift-", 1, {1064}},
        {"Shift + Middle", "shift-", 3, {5394}},
        {"Ctrl + Left", "ctrl-", 1, {51886, 526}},
        {"Ctrl + Right", "ctrl-", 2, {77130, 2870}},
    },
    MAGE = {{"Left", "", 1, {475}}},
}

A.buffs = {
    DRUID = {{1126, 21849}, {467}},
    PRIEST = {{1243, 21562}, {14752, 27681}, {976, 27683}},
    MAGE = {{1459, 23028}},
}

-- HealBot's own menu has no equivalent here: Button 5 opens our small settings.
A.common = {
    {"Button 4", "", 4, "togglemenu"},
    {"Button 5", "", 5, "settings"},
    {"Shift + Button 4", "shift-", 4, "target"},
    {"Shift + Button 5", "shift-", 5, "assist"},
}
