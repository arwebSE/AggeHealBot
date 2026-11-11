# Forever spell-data audit

Checked 2026-11-11 against Wowhead's client-derived spellbook data, live build **1.60.1.70888**:

- https://www.wowhead.com/forever/changes/spellbook/druid
- https://www.wowhead.com/forever/changes/spellbook/priest
- https://www.wowhead.com/forever/changes/spellbook/paladin
- https://www.wowhead.com/forever/changes/spellbook/shaman

Current distinct healing IDs explicitly recognized in Defaults.lua:

| Spell | IDs |
| --- | --- |
| Wild Growth | 408120, 1238214, 1238215 |
| Penance | 402174, 1240720, 1240721, 1316995 |
| Prayer of Mending | 401859, 1240826, 1240827 |
| Riptide | 408521, 1239242, 1239243 |
| Light's Vigil | 1311590, 1311595 |
| Revive | 437138, 1237948, 1237949, 1237950, 1237951 |

Current baseline cures:

| Class | Spell IDs | Supported debuff types |
| --- | --- | --- |
| Druid | 2782 | Curse (Forever tooltip includes Bane; spell effect is Dispel Curse) |
| Druid | 8946, 2893 | Poison |
| Priest | 527, 988 | Magic only |
| Priest | 528, 552 | Disease |
| Paladin | 1152 | Disease, Poison |
| Paladin | 4987 | Magic, Disease, Poison |
| Shaman | 526 | Poison |
| Shaman | 2870 | Disease |

Older spell candidates remain compatibility fallbacks and are offered only if learned. Names resolve through the live client for localization and rank selection. Explicit resurrection rank lists also handle missing base-ID lookups.

Automatic buff watching covers druid Mark/Gift of the Wild and Thorns, priest Fortitude, Divine Spirit and Shadow Protection, and a single selected paladin blessing per recipient class (Might, Wisdom or Kings). Paladin Auto suggests Might for warriors/rogues and Wisdom for all other classes, including druids regardless of form, with learned Kings as a fallback. Druid blessing choices use the same per-class overrides as everyone else; resource/form tracking is not used. No automatic shaman buff selection is implemented.

Paladin rank equivalences checked against the same client data: Greater Might 25782/25916 equals Might ranks 6/7; Greater Wisdom 25894/25918 equals Wisdom ranks 5/6; Greater Kings 25898 equals Kings 20217. These greater spells satisfy the watch but are never selected for automatic casting.

Buff upgrades compare explicit ascending single-target ranks. Equivalent group ranks use the same strength tiers: Gift of the Wild 21849/21850 match Mark ranks 6/7; Prayer of Fortitude 21562/21564 match Fortitude ranks 5/6; Prayer of Spirit 27681 matches Divine Spirit rank 4; Prayer of Shadow Protection 27683 matches Shadow Protection rank 3. These equivalences were checked against the spellbook's current effect values. Group spells known by the caster do not raise the strength attributed to their single-target cast. Unknown aura ranks remain conservative, and actual server rejections still suppress conflicting buffs.

Unknown future spells still appear in the learned-spell picker and can be bound manually. New spell identities, changed cure effects and new buff stacking rules need an explicit data review; name resolution alone cannot infer their behavior. These checks use a mocked runtime, not live play on all four classes.

The optional unlearned catalogue in Defaults.lua lists current class healing and support spell identities from the same spellbook data. It does not add offensive spells or racial abilities. Known abilities still come from the live spellbook. Future spellbook entries are not treated as learned; saved advance bindings remain inactive until the client reports a learned rank. Passive abilities are excluded from both lists.
