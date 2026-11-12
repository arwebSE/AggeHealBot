# Changelog

## 1.0.7 — 2026-11-12

- Rename Right-click menu to Override rightclick and invert its checkbox: checked uses the assigned binding, unchecked opens the native player/target unit menu. Preserve existing saved behavior and defaults.

## 1.0.6 — 2026-11-11

- Add smooth mouse texture scaling, a wheel-sized red highlight and a compact editor layout with clean spell icons around the mouse.
- Tighten mouse-editor spacing and add clickable spell/action icon callouts on both sides. Keep the selected icon and full spell name centered below the mouse.
- Default Shift + right-click to the unit context menu and Shift + middle-click to AggeHealBot settings; custom bindings still override both.
- Replace the binding list with Blizzard's classic tutorial mouse sprites and 0.8-second fading click animation, including a red wheel state. Draw numbered side buttons on the shell and show the selected spell icon/name below the graphic, preserving all modifier bindings and spell-picker behavior.
- Remove the priest right-click Lesser Heal fallback so low-level default left and right bindings do not duplicate the same heal. Right-click activates when Heal or Greater Heal is learned.
- List every learned spell before unlearned spells, preserving category priority within each group. All also places available actions before unlearned spells.
- Include Target, Assist, menus and Disabled in All alongside every spell, while respecting Show unlearned.
- Remove the Other category tab; its spells remain available under All. Widen the remaining tab labels.
- Default Shift + Button 4 to Assist and leave Shift + Button 5 unassigned, removing the redundant side-button Target shortcut.
- Resolve alternative preset spell IDs before labeling an unlearned binding; show Disabled when no spell identity exists instead of the generic Spell placeholder.
- Default the spell picker to Suggested (heals, buffs and utility), and move All to the rightmost category tab.
- Add an optional Show unlearned checkbox to the spell picker, off by default. Unlearned support spells are dimmed with hover explanations and can be bound in advance; saved bindings activate when the spell is learned.
- Replace cycling blessing buttons with native dropdowns, padded class-colored names and class icons. Separate footer controls and let Paladin blessings toggle back to the binding picker.
- Execute Target unit bindings through explicit secure targeting macros so Blizzard's click-binding interaction filter cannot discard Shift + left-click, including on the player frame.
- Add paladin blessing watching with class-specific suggestions and editable Auto, Might, Wisdom, Kings or Off rules. Druids default to Wisdom regardless of form; users can choose another blessing for their class. Greater blessings satisfy equal or weaker single-target ranks without automatically casting reagent-consuming group buffs.
- Prefer the assigned heal over missing buffs below 90% health when health data is readable, preserving cure and resurrection priority.
- Show out-of-combat range, mana/power, cooldown and availability hints. Dim unavailable watcher icons and pause their glow without changing protected combat casts.
- Keep Blizzard's global Auto Self Cast preference unchanged; frame clicks retain explicit targeting and cursor cleanup.
- Default Shift + left-click to target on supported frames. Modifier shortcuts are ordinary editable bindings, and modifier hover shows the saved assignments.
- Use AggeHealBot's spellbook-and-cursor artwork in the addon list instead of the default healing spell icon.

## 1.0.5 — 2026-11-11

- Offer watched buff upgrades when the target has a weaker known rank; suppress equal or stronger ranks, including equivalent group buffs. Leave unknown matching ranks alone and retain stronger-conflict rejection handling.
- Recognize Forever's Penance, Light's Vigil, and additional Wild Growth, Prayer of Mending and Riptide ranks as healing spells.
- Prefer current Forever Prayer of Mending, Holy Shock and Riptide IDs in class binding presets, retaining older fallback IDs.
- Recognize every current single-target resurrection and Rebirth rank explicitly, including when an older base-ID lookup is unavailable.
- Fix priest cure watching incorrectly offering Dispel Magic for diseases; use Cure Disease or Abolish Disease instead.
- Categorize greater paladin blessings as buffs and document the current automatic buff-watch coverage.

## 1.0.4 — 2026-11-11

- Add an optional Right-click menu override for player and target frames, off by default. Party and raid frames use their assigned right-click bindings. Modifier-click bindings are independent.
- Recognize Forever's ranked Revive spell IDs in Utility and resurrection watching.
- Disable and dim Cure in combat when Cure watcher is off, preserving its saved preference.
- Hide the custom tooltip while unit menus are open and show it when hovering health or mana bars as well as the rest of a supported unit frame.
- Add a Reset settings button that restores toggle defaults while preserving spell bindings.
- Shorten setting labels and explain each toggle in a hover tooltip, available over both the checkbox and its label.
- Arrange setting toggles in two columns and restore the compact editor height.
- Limit automatic buff, cure and resurrection watches to players while retaining normal click bindings on friendly NPCs.
- Add a default-on combat cure-alert toggle beside Cure watcher. Alerts use readable debuff data and show the assigned cure binding without changing protected combat bindings.
- Enable Player frame and Hide raid controls by default, including when resetting settings.
- Prioritize learned reagent-free resurrection spells on dead friendly players outside combat, with a pale blue resurrection glow and spell icon.
- Add optional combat resurrection priority and a secure dead-unit watcher, disabled by default. Enabling it permits reagent-consuming combat resurrection spells.
- Prioritize learned cures for removable debuffs outside combat, with a red cure glow, spell icon and debuff tooltip. Cure watching is enabled by default and can be disabled.
- Show Blizzard's original unit tooltip while hovering your own portrait, alongside the persistent AggeHealBot binding or Shift shortcut tooltip.

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
