# AggeHealBot

**[Download on CurseForge](https://www.curseforge.com/wow/addons/aggehealbot)** · [GitHub release](https://github.com/arwebSE/AggeHealBot/releases/latest)

Click-to-heal on Blizzard and supported X-Perl frames in **WoW Forever**.

<img src="https://media.forgecdn.net/attachments/2170/4/chatgpt-image-nov-8-2026-11_53_36-pm-png.png" width="340" alt="AggeHealBot missing-buff reminder">

- Custom mouse bindings with Shift, Ctrl and Alt.
- Optional keyboard hovercasting, off by default.
- Healing presets for druid, priest, paladin and shaman.
- Missing-buff reminders outside combat.

Type **`/ahb`** or open **Options → AddOns → AggeHealBot** for settings.

For **Forever 1.60.1**. Every cast requires a click.

**Auto Self Cast:** Your game-wide preference stays unchanged. Frame clicks use explicit unit targeting. If an older addon version turned Auto Self Cast off, you can re-enable it in WoW's settings.

[Report an issue](https://github.com/arwebSE/AggeHealBot/issues) · [AggeMinimap](https://www.curseforge.com/wow/addons/aggeminimap)

<details>
<summary>Manual installation</summary>

Extract the addon ZIP into your Forever client's `Interface/AddOns` folder. The path should be `Interface/AddOns/AggeHealBot/AggeHealBot.toc`. Restart the game after first installation.

</details>

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
| Shift + Left | Target |
| Shift + Right | Unit context menu |
| Shift + Middle | AggeHealBot settings |
| Shift + Button 4 | Assist |
| Shift + Button 5 | Unassigned |

Spells use the highest learned rank by default. Enable **Show all ranks** beside Show unlearned to choose a specific learned rank instead, or choose **Auto** to keep using the highest. Fixed-rank bindings stay saved when the list is hidden and do not upgrade when you train a newer rank. Automatic buff, cure and resurrection watchers keep using their own spell choices. Unlearned default bindings are marked and inactive. Any binding can be changed or restored in `/ahb`. Select a modifier tab, then click a mouse button or its icon beside the diagram to choose its binding. The five standard assigned icons remain visible around the mouse. Client-reported buttons 6–31 appear in an Extra buttons strip when detected or saved, with pages for larger button sets. The selected control pulses red, and its full spell icon/name appears centered below. Hover text follows the selected modifier.

The spell picker opens on **Suggested**, combining heals, buffs and utility. **All**, at the far right, includes all listed spells and actions. Actions also have their own tab. Unlearned spells are included when Show unlearned is enabled.

**Show unlearned**, at the top right of the spell picker, adds your class's unlearned healing and support spells. It is off by default. These entries are dimmed and explain their status on hover. You can bind them in advance; they remain inactive until learned and stay saved if you hide unlearned spells again. Offensive spells are not added to this optional catalogue.

**Identify buttons** on Home lets you press a physical mouse button over the diagram to see its number and select its binding. Standard buttons highlight on the mouse; extra buttons highlight in the numbered strip below it. Hold Shift, Ctrl or Alt while detecting to select that modifier combination, or choose a modifier tab afterward. Click Stop identifying before continuing normal editing. Detected buttons save per character; Reset all bindings clears their assignments while keeping the detected hardware list. If a side button arrives as a keyboard key, the capture area reports it instead of treating it as a mouse click. Check the mapping in your mouse software; this feature does not create keyboard bindings. Identifying buttons never casts a spell, and protected binding changes made during combat wait until combat ends.

## Buff priority and settings

Missing-buff priority is **on by default**. It applies only outside combat and only when plain left click is assigned a spell. Every cast still requires a click.

Use the top **Home**, **Watchers** and **Advanced** tabs in `/ahb`. Home contains bindings and general settings. Advanced contains frame support, right-click behavior and separate party/raid control toggles. Its bottom-left Reset advanced settings button resets only those controls, preserving bindings, Home preferences and watcher settings. Watchers shows buffs and cures side by side: enable or disable individual spells, change their order with up/down arrows, and choose **Cures first** or **Buffs first**. Choices save for the current character. **Reset watcher settings** restores the original lists and priorities; **Reset settings** also resets these choices. The default remains cures before buffs, using debuff order until cure priorities are customized. Resurrection stays first. Unlearned spells remain configurable and activate when trained. Paladin blessings opens from Watchers for paladins. Advanced has a default-off Preview Paladin blessings option for testing. Shaman has no automatic buff list; its buffs remain manually bindable.

- Druid: Mark of the Wild, then Thorns. Gift of the Wild satisfies Mark.
- Priest: Fortitude, Divine Spirit and Shadow Protection, when learned. Their group versions satisfy the corresponding buff.

Paladins use the **Paladin** tab in `/ahb`. Suggested defaults use Might for warriors and rogues, and Wisdom for everyone else, including druids regardless of form. Choose a different blessing for druids with their class override. Auto falls back to Kings if the suggested spell is unlearned and Kings is available. Each class has a dropdown for Auto, Might, Wisdom, Kings or Off, alongside its class icon and colored name. Use Home to return to bindings. Only one selected blessing is watched per class, and equivalent greater blessings satisfy the watch. The watcher casts single-target blessings rather than reagent-consuming group versions. Shaman buffs remain manually bindable without automatic watch rules. Cure and resurrection watching support all four healer classes.

Once the unit has its buffs, left click returns to its assigned spell. The buff icon and outline disappear when buffs are complete, combat begins, a modifier is held or buff priority is turned off. Unreachable buff targets are blocked instead of falling through to another spell.

Below **90% health**, your assigned heal takes priority over missing buffs. Buff watching resumes at 90% or higher. This uses readable health data outside combat; cure and resurrection priority are unchanged. Availability hints explain known range, mana/power, cooldown and unusable-spell conditions in the binding tooltip. Unavailable watcher spells keep a dim icon and stop glowing; the game still validates the cast. The global cooldown does not dim all spells.

The watcher compares your highest learned single-target buff rank with the active buff's spell ID. A weaker known rank gets an upgrade icon, glow and left-click action. An equal or stronger rank satisfies the watcher, including equivalent group buffs such as Gift of the Wild and the priest Prayers. Unknown ranks with a matching buff name are left alone rather than assumed weaker.

If the game rejects an offered buff because a stronger conflicting effect is active, AggeHealBot skips that buff for that player and removes its icon/glow. This also works for conflicts between differently named spells. The next missing buff, or the normal heal, takes over. Suppression is reconsidered when an observed aura disappears or is replaced, or when your spellbook changes. Additions and ordinary refreshes do not immediately reoffer a rejected buff. For conflicts not already recognized, the first click may still be rejected by the game; the addon does not have a general API for predicting every server-side stacking rule.

Target and target-of-target click healing, hover tooltips and player-only watching are **on by default**, with separate Target frame and Target of target toggles in `/ahb` → Advanced. Friendly units use your normal bindings, while enemy frames keep their stock interactions. Player names in the binding tooltip use their class color.

**Focus frame** is also on by default, with its own toggle on Advanced. Friendly focus units use the same editable bindings, unit menus and hover details, with casts explicitly directed to focus. Automatic buff, cure and resurrection watching remains players-only. Enemy focus interactions keep their stock behavior.

The tooltip puts class and known spec on one row. Hovering an eligible player can request inspection outside combat; the spec appears when the response arrives and is cached for one hour per player, including across reloads. Cached specs remain visible during combat without talent queries or inspection requests. Forever/classic talent data uses the tree with the most spent points when there is a clear leader. Generic class labels and unknown or tied results are not shown as specs.

**Override rightclick** is on by default. Your player and target frames use their assigned plain right-click bindings. Turn it off in `/ahb` to open the native unit menu instead. Party and raid frames always use their assigned bindings; modifier bindings are unchanged. Existing saved preferences are preserved.

By default, outside combat, plain left-click prioritizes a learned reagent-free resurrection on a dead friendly player, then a learned cure for a removable debuff, then missing buffs, then your assigned heal. The Watchers tab can put buffs before cures; resurrection stays first. Its default-on Resurrection watcher toggle can disable automatic resurrection watching without changing manual spell bindings. The adjacent Combat resurrection option requires Resurrection watcher. Each resurrection spell has its own rank dropdown: Auto uses the highest learned rank, while a selected learned rank stays fixed. Choices save per character and reset to Auto with Reset watcher settings. Rank changes made during combat apply afterward. Reset watcher settings is anchored at the bottom and restores these resurrection options too. Resurrection has a pale-blue glow, and cure watching has a red glow. Cure watching can be disabled in `/ahb`.

Automatic buff and resurrection watches apply only to players. **Cure pets** in Watchers is on by default and watches removable debuffs on friendly pets. Stock pet, normal party-pet, compact pet and supported X-Perl pet frames accept your healing bindings and show hover tooltips regardless of this setting. Resurrection remains player-only; ordinary NPCs support manual click bindings without automatic watches.

**Combat resurrection** in Watchers is off by default. Enable it to allow learned combat resurrection spells, including those that consume reagents. Combat resurrection uses secure conditions for dead party/raid members. Automatic cure priority runs outside combat, when aura data is readable.

The **Cure in combat** toggle beside the Cures settings in Watchers enables combat cure alerts when debuff data is readable. It is on by default. Combat alerts show the cure's assigned binding. Automatic left-click cure priority runs outside combat.

**Player frame**, **Hide party controls** and **Hide raid controls** are on by default under Advanced. The two control toggles independently hide Blizzard's shared side panel and tab depending on whether you are in a party or raid. Unit frames remain visible.

**X-Perl:** Automatically detects the Forever build's shared unit-frame registry. Player, party, raid, friendly target, focus and target-of-target frames use the same bindings, hover details and player-only buff/cure/resurrection watchers. Existing Advanced frame toggles apply. X-Perl keeps its own enemy-frame interactions. X-Perl pet frames also use your bindings and the optional Cure pets rules. Party-target and arena frames are excluded. The adapter stays inactive when X-Perl is absent.

**Show tooltip** on Home is on by default. Turn it off to hide AggeHealBot's hover binding panel while keeping the normal unit tooltip and all click bindings/watchers. **Replace Blizzard tooltip** in Advanced is off by default; enable it to hide the matching native unit/resource tooltip while ours is displayed. If Show tooltip is off, the normal tooltip is used even with replacement selected. Unrelated item, spell and settings tooltips are unaffected.

## Casting behavior

**Minimap icon** on Home adds our spellbook icon for quick access to settings. It uses bundled LibDBIcon and LibDataBroker so standard minimap collectors can recognize it; no separate library installation is needed. It is on by default. Click to open or close settings, and drag around the minimap to save its position.

**Target on cast**, also on Home and off by default, selects the friendly unit you click when using a spell binding, including watcher casts. It changes your current target. Known out-of-range casts blocked by the addon do not target; a cast rejected by the game in combat can still select the unit. Changes to casting behavior made during combat apply after combat.

Clicks execute once on mouse-button press. Spells use an explicit mouseover target without a target/self fallback, followed by secure targeting-cursor cleanup. Known out-of-range heals are blocked before casting outside combat. In combat, the client validates the cast; addon aura and range decisions are not made in combat.

**Auto Self Cast:** AggeHealBot leaves this game-wide preference unchanged. Frame clicks explicitly target the hovered unit or friendly target and do not include a self-cast fallback. This does not change action-bar behavior. If a previous version disabled the setting, re-enable it in WoW's settings if desired.

**Shift + left-click** targets the unit and **Shift + right-click** opens the unit context menu, and **Shift + middle-click** opens AggeHealBot settings by default. These are ordinary bindings you can change in `/ahb`; existing saved overrides are preserved. Holding a modifier while hovering shows its current bindings.

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

**Keyboard hovercasting:** In Home, enable **Hovercast**, then open **Keyboard bindings**. Click the key field, press a key (with optional Shift/Ctrl/Alt), and choose a spell or action from the normal picker. Show all ranks also works for keyboard bindings. Keys temporarily override their normal action only while hovering a supported frame, including its health/mana bars. Moving away or hiding the frame restores normal bindings. Keyboard spells cast their assigned spell; automatic watcher priority remains on left click. Configuration changes made in combat apply after combat. Reset all bindings also clears keyboard shortcuts.

**Buff recipients:** In Watchers, each buff has a targeting dropdown: **Everyone**, **Only me**, **Choose players…**, a class under **Class**, or a role or resource group. The **Role** submenu offers **Healers**, **Tanks**, and **DPS** based on WoW’s assigned group roles. Players with no assigned role do not match those filters. Casters covers mages, priests, shamans and warlocks. Melee covers warriors, rogues and paladins. Both groups offer an Include Druids option per buff. Mana, Rage and Energy follow the unit’s current resource. Click **Choose players…**, check yourself or any group members you want watched, then click **Use checked players** to save the list. Selections persist for that character across frames and groups. Self-only spells such as Inner Fire remain restricted to you. Manual spell bindings are unaffected.

**Use buff bindings:** Enable this in Watchers to keep watcher icons and glows visible while holding Shift, Ctrl or Alt. It is off by default. When enabled, a missing buff with an existing binding shows that shortcut in the tooltip and leaves plain left click available for its assigned spell. Unbound buffs still use the automatic left-click priority.
