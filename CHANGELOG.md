# Changelog

## 1.0.0 — 2026-11-09

- Show the next-buff icon and colored animated outline on the player portrait when portrait click-healing is enabled.
- Shape the player-frame glow around the circular portrait, level badge and rounded name/health/mana panel.
- Use a soft, blurred buff glow with a synchronized pulse across the player-frame outline.
- Register Forever's pooled standard party frames so buff reminders work with the regular party layout as well as raid-style frames.

## 0.4.5 — 2026-11-08

- Move the next-buff icon outside each unit frame's top-right corner, leaving Blizzard's own buff icons unobstructed.

## 0.4.4 — 2026-11-08

- Add the full binding editor to Options → AddOns → AggeHealBot, reusing the same controls as `/ahb` and fitting them to the native Options area.
- Include the installed version in the login message and `/ahb status`, read from addon metadata.
- Add a built-in healing icon to the game's addon list.

## 0.4.3 — 2026-11-08

- Recognize higher-rank buffs by their canonical spell name when the aura's displayed name differs.
- Stop offering an out-of-combat buff after WoW reports that a more powerful conflicting effect is active, including differently named spells.
- Remove the rejected buff's icon, glow and left-click priority for the affected player; proceed to the next buff or the assigned heal.
- Reconsider rejected buffs when an observed aura disappears/is replaced or the spellbook changes, without treating added buffs as a reason to retry.
- Associate rejection feedback with a recent plain-left-click buff attempt and the target's GUID, ignoring stale and unrelated errors.

## 0.4.2 — 2026-11-08

Initial public release for WoW: Forever 1.60.1.

- Click healing on Blizzard party and raid frames, with class presets and per-character rebinding.
- Mouse buttons 1–5 and Shift, Ctrl and Alt modifier combinations.
- Out-of-combat missing-buff priority enabled by default, with buff icons and animated colored frame outlines.
- A single-window binding editor with spell icons, search and Heals, Buffs, Utility, Other and Actions filters.
- Passive spells excluded from the spell picker; resurrection spells and dispels listed ahead of other abilities.
- Blizzard-style controls with animated gold selection outlines and colored category labels.
- Optional player portrait support and hiding of Blizzard's raid-control panel, both off by default.
- Menu bindings that toggle once on mouse press.
- Explicit mouseover casting, out-of-combat range guards and targeting-cursor cleanup.

AggeHealBot disables the game's Auto Self Cast setting to prevent failed targeted spells from falling back to the player. This affects action-bar spells too.
