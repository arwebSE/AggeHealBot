# Changelog

## 1.0.3 — 2026-11-10

- Add a target click-healing and buff-watch toggle, enabled by default for new and existing characters.
- Turning target support off hides the click surface and buff indicator and restores normal target interaction. Changes made in combat apply after combat ends.
- Use Blizzard's default position for the original target tooltip so it does not overlap the frame-relative AggeHealBot tooltip.

## 1.0.2 — 2026-11-10

- Support click healing and buff watching on the stock friendly target frame, including a mirrored portrait/level outline, external buff icon and Shift + left-click settings shortcut.
- Keep enemy target interactions untouched through a secure friendly-only click surface, including target changes during combat.
- Check aura secrecy before scanning and safely handle aura API calls that are denied while addon code is tainted.
- Discard incomplete or restricted aura scans, clear buff prompts and retain the normal healing binding until auras are readable again.
- Detect aura-secrecy changes outside combat so buff reminders recover without requiring a reload or another aura event.
- Preserve Blizzard's original teammate tooltip while keeping the persistent AggeHealBot binding tooltip beside the hovered unit frame.
- Make the hovered player's name the large tooltip heading and place a smaller AggeHealBot label at the top right.

## 1.0.1 — 2026-11-09

- Remove the mage utility preset and Arcane Intellect buff reminders; advertised presets now focus on druid, priest, paladin and shaman healers.
- Fix repeated secret-number errors in the player-frame buff glow by using native anchors instead of calculating with restricted screen coordinates.
- Preserve the last valid glow layout if portrait dimensions become restricted.
- Position the player-frame buff icon just outside the visible panel's top-right corner instead of the stock frame's padded bounds.
- Add a Shift + left-click menu shortcut on the player portrait when portrait support is enabled, with a tooltip hint while holding Shift.
- Keep portrait, party and raid binding information and the portrait Shift shortcut hint in an addon-owned tooltip so Blizzard's unit-tooltip refreshes cannot overwrite or fade them.

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
