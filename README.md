# AggeHealBot

Click-cast healing for **World of Warcraft: Forever**, using Blizzard's own party and raid frames.

**[Install from CurseForge](https://www.curseforge.com/wow/addons/aggehealbot)** · [Download ZIP](https://github.com/arwebSE/AggeHealBot/releases) · [Report a bug](https://github.com/arwebSE/AggeHealBot/issues)

Start with ready-made class bindings, change them in `/ahb`, and see which missing buff your next left click will cast. No replacement unit frames or library dependencies.

**Supported client:** Forever 1.60.1, interface 16001. The druid setup has received in-game testing. Other class presets are included but need further playtesting.

## See it in game

<img src="https://media.forgecdn.net/attachments/2170/4/chatgpt-image-nov-8-2026-11_53_36-pm-png.png" width="340" alt="Missing-buff reminder on Blizzard party frames in WoW Forever">

[View the in-game screenshots and binding editor](https://www.curseforge.com/wow/addons/aggehealbot/gallery).

## Install

Install through the [CurseForge app or project page](https://www.curseforge.com/wow/addons/aggehealbot), selecting **WoW Forever**. For a manual installation:

1. Download the addon ZIP from CurseForge or [GitHub Releases](https://github.com/arwebSE/AggeHealBot/releases).
2. Extract the `AggeHealBot` folder into `_forever_/Interface/AddOns/`.
3. Enable the addon and reload the UI. Restart the client if it does not discover the newly installed folder.
4. Type `/ahb` or open **Options → AddOns → AggeHealBot** to review or change your bindings. Both use the same editor.

The resulting path should be `_forever_/Interface/AddOns/AggeHealBot/AggeHealBot.toc`.

The login message shows your installed version, and the addon list displays a built-in healing icon.

Enable **Use Raid-Style Party Frames** in WoW's settings if you want compact raid-style frames in a party. Regular Blizzard party frames also work.

## Features

- **Stock frames:** click directly on a party member or raid member to cast on that unit.
- **Class presets:** druid, priest, paladin, shaman and mage defaults, with learned-spell fallbacks where appropriate.
- **Custom bindings:** buttons 1–5 and every combination of Shift, Ctrl and Alt, saved per character.
- **Focused spell browser:** icons, search and category filters; heals first, then buffs, utility and other active spells. Passive abilities are omitted.
- **Missing buffs:** outside combat, plain left click can prioritize a missing class buff before its normal spell.
- **Visual cues:** an icon just outside each unit frame's top-right corner and a pulsing frame outline identify the next buff. Colors change with the buff; Blizzard's own aura icons remain unobstructed.
- **Small settings menu:** Blizzard-style frame art, colored category labels and animated selection borders.
- **Menu shortcuts:** assign Target, Assist, Unit Menu, Settings or Disabled; mouse menu bindings toggle open and closed.

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

These tests use a mocked WoW runtime. Secure execution and appearance must also be checked in the actual client.

## Releasing

GitHub Actions packages and uploads each pushed `v*` tag to CurseForge. Before tagging, update the version in `AggeHealBot/AggeHealBot.toc` and add the release notes to `CHANGELOG.md`. Push the changes, then push an annotated tag such as `v0.4.6`:

```sh
git tag -a v0.4.6 -m "AggeHealBot v0.4.6"
git push origin v0.4.6
```

The `CF_API_TOKEN` GitHub Actions secret is used only by the tagged release workflow.

## More from ARWeb

[AggeMinimap](https://www.curseforge.com/wow/addons/aggeminimap) adds a clean square minimap with a compact header and adjustable size and spacing for WoW Forever.

## License and attribution

[MIT](LICENSE). Binding choices were inspired by HealBot Continued; the implementation is independent. Blizzard UI artwork is referenced from the game client and is not redistributed in this repository. This project is not affiliated with Blizzard Entertainment or HealBot Continued.
