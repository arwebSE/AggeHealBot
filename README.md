# AggeHealBot

**Click your party frames. Cast your heals. Keep the Blizzard UI you know.**

AggeHealBot adds **click-to-heal bindings to Blizzard party and raid frames in WoW Forever**. Start with class presets, choose your own spells and mouse modifiers, and see which missing buff your next click will cast.

**[Get AggeHealBot on CurseForge](https://www.curseforge.com/wow/addons/aggehealbot)** · [Latest GitHub release](https://github.com/arwebSE/AggeHealBot/releases/latest)

<img src="https://media.forgecdn.net/attachments/2170/4/chatgpt-image-nov-8-2026-11_53_36-pm-png.png" width="340" alt="AggeHealBot missing-buff reminder beside Blizzard party frames in WoW Forever">

[See the gameplay screenshots and binding editor](https://www.curseforge.com/wow/addons/aggehealbot/gallery).

## Familiar frames. Your healing bindings.

- **Heal directly from the frame.** Click a friendly party or raid member to cast on them. Use regular Blizzard party frames or raid-style party frames.
- **Start with class presets.** Defaults are included for druid, priest, paladin, shaman and mage. Review and customize them in `/ahb`.
- **Make each click yours.** Bind mouse buttons 1–5 with Shift, Ctrl, Alt or combinations. Find learned spells with search and Heals, Buffs and Utility filters.
- **See missing buffs at a glance.** Outside combat, an icon and animated outline show the buff your next plain left click will cast. Once buffed, that click returns to its healing spell.

No replacement unit frames or external libraries. Bindings are saved per character. Every cast requires your click.

## Start healing

1. Install **AggeHealBot** for **WoW Forever** from CurseForge.
2. Type **`/ahb`**, or open **Options → AddOns → AggeHealBot**, and review your bindings.
3. Click a friendly party or raid frame to cast on that player.

For druids, the starting healing bindings are **Left: Regrowth**, **Right: Healing Touch**, and **Middle: Rejuvenation**. Change them in the editor to suit your playstyle.

Want compact party frames? Enable **Use Raid-Style Party Frames** in WoW's settings. Missing-buff priority can be switched off in settings or with **`/ahb buffs off`**. During combat, your normal healing bindings apply.

## Compatibility and casting settings

For **WoW Forever 1.60.1, interface 16001**. Binding edits made during combat apply after combat ends. Avoid assigning overlapping click-cast bindings through Blizzard or another addon on the same frames.

**Auto Self Cast:** AggeHealBot turns off this game-wide WoW setting to prevent failed targeted spells from redirecting to you. This also affects action-bar spells and remains off after the addon is unloaded. You can restore it in WoW's settings after disabling AggeHealBot.

Prefer a manual install? Download the addon ZIP from [GitHub Releases](https://github.com/arwebSE/AggeHealBot/releases/latest) and extract `AggeHealBot` into your Forever client's `Interface/AddOns` folder. The resulting path should be `Interface/AddOns/AggeHealBot/AggeHealBot.toc`. Restart after first installation and enable the addon.

## Useful in your next group?

[Get AggeHealBot on CurseForge](https://www.curseforge.com/wow/addons/aggehealbot), favorite it to find it again, or share the link with another healer. [Report a bug or suggest a feature](https://github.com/arwebSE/AggeHealBot/issues) with your class, client build, addon version and binding.

**Want a cleaner minimap too?** [AggeMinimap](https://www.curseforge.com/wow/addons/aggeminimap) adds a square map, a compact header and just two settings for WoW Forever.

<details>
<summary>Full binding reference, buff behavior and development</summary>

## Druid defaults


| Click | Spell or action |
| --- | --- |
| Left | Regrowth |
| Right | Healing Touch |
| Middle | Rejuvenation |
| Ctrl + Left | Remove Curse |
| Ctrl + Right | Nature's Cure, or Abolish Poison / Cure Poison if learned |
| Ctrl + Middle | Nourish, or Swiftmend if learned |
| Button 4 | Unit menu |
| Button 5 | AggeHealBot settings |
| Shift + Button 4 | Target |
| Shift + Button 5 | Assist |

Spells use names without a fixed rank, allowing the client to select the highest learned rank. Unlearned default bindings are marked and inactive. Any binding can be changed or restored in `/ahb`.

## Buff priority and settings

Missing-buff priority is **on by default**. It applies only outside combat and only when plain left click is assigned a spell. Every cast still requires a click.

- Druid: Mark of the Wild, then Thorns. Gift of the Wild satisfies Mark.
- Priest: Fortitude, Divine Spirit and Shadow Protection, when learned. Their group versions satisfy the corresponding buff.
- Mage: Arcane Intellect; Arcane Brilliance also satisfies it.

Once the unit has its buffs, left click returns to its assigned spell. The buff icon and outline disappear when buffs are complete, combat begins, a modifier is held or buff priority is turned off. Unreachable buff targets are blocked instead of falling through to another spell.

Higher-rank auras are recognized through their canonical spell names, even when the displayed aura name differs. If the game rejects an offered buff because a stronger conflicting effect is active, AggeHealBot skips that buff for that player and removes its icon/glow. This also works for conflicts between differently named spells. The next missing buff, or the normal heal, takes over. Suppression is reconsidered when an observed aura disappears or is replaced, or when your spellbook changes. Additions and ordinary refreshes do not immediately reoffer a rejected buff. For conflicts not already recognized, the first click may still be rejected by the game; the addon does not have a general API for predicting every server-side stacking rule.

Two optional settings are **off by default**:

- Click healing on your player portrait, useful for solo testing.
- Hiding Blizzard's raid-control side panel and tab, while retaining the unit frames.

## Casting behavior

Clicks execute once on mouse-button press. Spells use an explicit mouseover target without a target/self fallback, followed by secure targeting-cursor cleanup. Known out-of-range heals are blocked before casting outside combat. In combat, the client validates the cast; addon aura and range decisions are not made in combat.

**Auto Self Cast:** AggeHealBot turns off this game-wide setting at login, or after combat if necessary, to prevent failed spells from redirecting to you. This also changes action-bar behavior and remains disabled after the addon is unloaded. You can restore it through WoW's settings after disabling AggeHealBot.

Binding edits made during combat apply after combat ends. Existing Blizzard click-cast spell bindings can take precedence; remove overlapping bindings if a click casts a different spell. Avoid having another addon also manage clicks on these stock frames.

## Commands

| Command | Action |
| --- | --- |
| `/ahb` | Open the binding editor |
| `/ahb buffs on` | Enable missing-buff priority |
| `/ahb buffs off` | Disable missing-buff priority |
| `/ahb status` | Show version and registered frame count |

## Development

Run `lua tests/runtime.lua` from the repository root using Lua 5.1 or newer. The tests also run with Fengari. They cover default and custom bindings, spell ranking by name, buff priority, range guards, combat write restrictions, cursor-cleanup macros, frame filtering, portrait restoration, menus, spell categories, settings and animation lifecycle.

These tests use a mocked WoW runtime. Secure execution and appearance must also be checked in the actual client. The druid setup has received in-game testing; other class presets still need class-specific validation.


</details>


[MIT](LICENSE). Binding choices were inspired by HealBot Continued; the implementation is independent. Blizzard UI artwork is referenced from the game client and is not redistributed in this repository. This project is not affiliated with Blizzard Entertainment or HealBot Continued.
