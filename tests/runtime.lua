-- Run with a Lua 5.1+ interpreter, from the repository root.
local combat, auras, drivers, callbacks = false, {}, {}, {}
local ns, events = {}, nil
local ranges, tickers = {}, {}
local cvars = {autoSelfCast = "1", ActionButtonUseKeyDown = "1"}
function GetCVar(key) return cvars[key] end
function SetCVar(key, value) assert(not combat, "CVar write during combat"); cvars[key] = value end
local known = {[8936] = "Regrowth", [5185] = "Healing Touch", [774] = "Rejuvenation", [1126] = "Mark", [467] = "Thorns", [2782] = "Remove Curse", [2893] = "Abolish Poison"}
local spellNames = {[21849] = "Gift"}
for id, name in pairs(known) do spellNames[id] = name end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function InCombatLockdown() return combat end
function UnitClass() return "Druid", "DRUID" end
function UnitExists(u) return u ~= nil end
function UnitCanAssist() return true end
function UnitIsDeadOrGhost() return false end
function UnitIsConnected() return true end
function UnitIsUnit(a, b) return a == b end
function IsPlayerSpell(id) return known[id] ~= nil end
function issecretvalue() return false end
function RegisterAttributeDriver(f, attr, expression)
    assert(not combat, "driver registered in combat")
    assert(not expression:find("/cast", 1, true) and not expression:find("\n", 1, true), "state drivers must not parse slash-command payloads")
    drivers[f] = drivers[f] or {}
    drivers[f][attr] = expression
    local first, second = expression:match("^%[combat%] (.-); (.*)$")
    local value = combat and first or second
    f:SetAttribute(attr, value ~= "nil" and value or nil)
end
function UnregisterAttributeDriver(f, attr) assert(not combat); drivers[f][attr] = nil end
local function Region()
    local r = {}
    for _, method in ipairs({"SetPoint", "SetAllPoints", "SetAtlas", "SetAlpha", "SetVertexColor", "SetHeight", "SetWidth", "SetSize", "SetTexCoord", "SetDrawLayer", "SetJustifyH", "SetWordWrap", "SetTextColor"}) do
        r[method] = function() end
    end
    function r:SetColorTexture(...) self.color = {...} end
    function r:SetTexture(value) self.texture = value end
    function r:SetText(value) self.text = value end
    function r:CreateAnimationGroup()
        local group = {playing = false, plays = 0}
        function group:SetLooping(value) self.looping = value end
        function group:CreateAnimation()
            return {SetFromAlpha = function() end, SetToAlpha = function() end, SetDuration = function() end, SetSmoothing = function() end}
        end
        function group:IsPlaying() return self.playing end
        function group:Play() self.playing = true; self.plays = self.plays + 1 end
        function group:Stop() self.playing = false end
        self.animationGroup = group
        return group
    end
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    return r
end
function CreateFrame(_, name, parent, template)
    local f = {attrs = {}, scripts = {}, name = name, regions = {}, template = template}
    function f:CreateTexture() local r = Region(); self.regions[#self.regions + 1] = r; return r end
    function f:CreateFontString() local r = Region(); self.regions[#self.regions + 1] = r; return r end
    function f:GetName() return self.name end
    function f:GetAttribute(k) return self.attrs[k] end
    function f:SetAttribute(k, v) assert(not combat, "protected write in combat"); self.attrs[k] = v end
    function f:RegisterForClicks(...) assert(not combat); self.clicks = {...} end
    function f:HookScript(k, fn) self.scripts[k] = fn end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent() events = self end
    function f:Hide() end
    return f
end
function hooksecurefunc(name, fn) callbacks[name] = fn end
function CompactUnitFrame_SetUnit() end
function CompactUnitFrame_SetUpFrame() end
function SecureUnitButton_OnLoad() end
C_Timer = {After = function(_, fn) fn() end, NewTicker = function(_, fn) tickers[#tickers + 1] = fn end}
C_Spell = {
    GetSpellInfo = function(id) return spellNames[id] and {name = spellNames[id], iconID = id + 100000} end,
    IsSpellInRange = function(_, unit)
        if ranges[unit] == "unknown" then return nil end
        return ranges[unit] ~= false
    end,
}
C_UnitAuras = {GetAuraDataByIndex = function(unit, i) return auras[unit] and auras[unit][i] end}
SlashCmdList, UISpecialFrames = {}, {}
PlayerFrame = CreateFrame("Button", "PlayerFrame")
PlayerFrame:SetAttribute("unit", "player")
local function event(e, arg) events.scripts.OnEvent(events, e, arg) end
local function mouseEdge(frame, button, down)
    local wanted = down and "AnyDown" or "AnyUp"
    local registered = false
    for _, edge in ipairs(frame.clicks or {}) do if edge == wanted then registered = true end end
    if not registered then return end
    local suffix = button:match("^Button(%d+)$")
    if suffix and frame.attrs["type" .. suffix] == "click" then
        local delegate = frame.attrs["clickbutton" .. suffix]
        delegate.scripts.OnClick(delegate, button)
    end
end
assert(loadfile("AggeHealBot/Defaults.lua"))("AggeHealBot", ns)
assert(loadfile("AggeHealBot/Indicators.lua"))("AggeHealBot", ns)
assert(loadfile("AggeHealBot/Core.lua"))("AggeHealBot", ns)
event("ADDON_LOADED", "AggeHealBot")
event("PLAYER_LOGIN")
assert(cvars.autoSelfCast == "0", "disable client self-cast fallback for heals and buffs")
assert(AggeHealBotDB.smartBuffs == true)
assert(AggeHealBotDB.playerFrame == false, "portrait support defaults off")
assert(not drivers[PlayerFrame], "portrait untouched by default")
ns.SetOption("playerFrame", true)
assert(#PlayerFrame.clicks == 1 and PlayerFrame.clicks[1] == "AnyDown", "clicks run once on press")
assert(PlayerFrame.attrs.spell1 == "Mark", "first missing buff")
assert(PlayerFrame.regions[2].shown and PlayerFrame.regions[2].texture == 101126, "Mark icon shown")
assert(PlayerFrame.regions[3].shown and PlayerFrame.regions[3].color[1] == 0.8, "Mark glow active")
assert(PlayerFrame.regions[3].animationGroup.playing, "missing buff glow animates")
assert(PlayerFrame.attrs.spell2 == "Healing Touch")
assert(PlayerFrame.attrs.spell3 == "Rejuvenation")
assert(PlayerFrame.attrs["ctrl-spell2"] == "Abolish Poison", "Forever dispel fallback")
assert(PlayerFrame.attrs.type4 == "click" and PlayerFrame.attrs.clickbutton4, "side menu bypasses native interaction filter")
assert(PlayerFrame.attrs.clickbutton5 == ns.settingsButton, "Button 5 opens addon settings")
local menuUnit, menuMouse
local currentMenu
local manager = {
    GetOpenMenu = function() return currentMenu end,
    CloseMenus = function() currentMenu = nil end,
}
Menu = {GetManager = function() return manager end}
function CompactUnitFrame_OpenMenu(_, unit, mouseButton)
    menuUnit, menuMouse = unit, mouseButton
    currentMenu = {}
end
local menu = PlayerFrame.attrs.clickbutton4
mouseEdge(PlayerFrame, "Button4", true)
assert(menuUnit == "player" and menuMouse == "Button4", "Button 4 opens stock menu for clicked unit")
mouseEdge(PlayerFrame, "Button4", false)
assert(currentMenu, "releasing mouse keeps unit menu open")
mouseEdge(PlayerFrame, "Button4", true)
assert(not currentMenu, "same side button closes unit menu")
mouseEdge(PlayerFrame, "Button4", false)
assert(not currentMenu, "release does not reopen unit menu")
menu.scripts.OnClick(menu, "Button4")
assert(currentMenu, "unit menu reopens")
currentMenu = nil
menu.scripts.OnClick(menu, "Button4")
assert(currentMenu, "unit menu reopens after external dismissal")
PlayerFrame:SetAttribute("unit", "party1")
menu.scripts.OnClick(menu, "Button4")
assert(menuUnit == "party1", "menu follows reassigned stock-frame unit")
assert(currentMenu, "different unit replaces menu instead of closing it")
PlayerFrame:SetAttribute("unit", "player")
event("UNIT_AURA", "player")
assert(PlayerFrame.attrs.spell1 == "Mark", "repeated refresh must retain buff")
assert(PlayerFrame.regions[3].animationGroup.plays == 1, "refresh must not restart pulse")
auras.player = {{name = "Gift"}}
event("UNIT_AURA", "player")
assert(PlayerFrame.attrs.spell1 == "Thorns", "group buff satisfies Mark")
assert(PlayerFrame.regions[2].texture == 100467, "indicator advances")
assert(PlayerFrame.regions[3].color[1] == 1 and PlayerFrame.regions[3].color[2] == 0.6, "glow switches to Thorns color")
auras.player[2] = {name = "Thorns"}
event("UNIT_AURA", "player")
assert(PlayerFrame.attrs.spell1 == "Regrowth", "all buffs present")
assert(not PlayerFrame.regions[2].shown, "no indicator when buffed")
assert(not PlayerFrame.regions[3].shown, "glow clears when buffed")
assert(not PlayerFrame.regions[3].animationGroup.playing, "resolved buff stops animation")
auras.player = {}
event("UNIT_AURA", "player")
combat = true
event("PLAYER_REGEN_DISABLED")
assert(not PlayerFrame.regions[2].shown, "indicator hides immediately in combat")
assert(not PlayerFrame.regions[3].shown, "glow hides in combat")
-- Model the client's secure driver transition, bypassing insecure SetAttribute.
for f, attrs in pairs(drivers) do
    for key, expression in pairs(attrs) do
        local value = expression:match("^%[combat%] (.-);")
        f.attrs[key] = value ~= "nil" and value or nil
    end
end
assert(PlayerFrame.attrs.spell1 == "Regrowth", "combat restores healing")
event("UNIT_AURA", "player")
event("SPELLS_CHANGED")
CompactRaidFrame1 = CreateFrame("Button", "CompactRaidFrame1")
CompactRaidFrame1.attrs.unit = "raid1"
callbacks.CompactUnitFrame_SetUnit(CompactRaidFrame1)
assert(not drivers[CompactRaidFrame1], "no registration in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(drivers[CompactRaidFrame1], "frames created in combat picked up afterward")
-- Movement/range gating must clear both action and spell, with no heal/self fallback.
local playerSpellBefore = PlayerFrame.attrs.spell1
ranges.raid1 = false
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1)
assert(CompactRaidFrame1.attrs.type1 == "none" and CompactRaidFrame1.attrs.spell1 == nil, "out-of-range buff cannot cast")
assert(not CompactRaidFrame1.regions[2].shown, "blocked buff indicator hidden")
assert(PlayerFrame.attrs.spell1 == playerSpellBefore, "range block on teammate does not redirect to self")
ranges.raid1 = true
tickers[1]()
assert(CompactRaidFrame1.attrs.type1 == "macro" and CompactRaidFrame1.attrs.spell1 == "Mark", "movement back into range restores buff")
ranges.raid1 = "unknown"
tickers[1]()
assert(CompactRaidFrame1.attrs.type1 == "none", "unknown range fails closed")
ranges.raid1 = true
tickers[1]()
assert(CompactRaidFrame1.attrs.spell1 == "Mark")
-- All healing bindings use an explicit target plus secure cursor cleanup.
for _, suffix in ipairs({"1", "2", "3"}) do
    local macro = CompactRaidFrame1.attrs["macrotext" .. suffix]
    assert(macro:find("/cast [", 1, true) == 1, "macro retains cast command")
    assert(macro:sub(-16) == "/stopspelltarget", "every spell clears targeting cursor")
end
assert(not drivers[CompactRaidFrame1].macrotext1, "macro commands never pass through state-driver parser")
assert(CompactRaidFrame1.attrs.macrotext1 == "/cast [combat,@mouseover,help,nodead] Regrowth; [nocombat,@mouseover,help,nodead] Mark\n/stopspelltarget", "left macro keeps full command and combat/buff conditions")
ranges.raid1 = false
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1)
assert(CompactRaidFrame1.attrs.type2 == "none", "out-of-range Healing Touch blocked before cast")
assert(CompactRaidFrame1.attrs.type3 == "none", "out-of-range Rejuvenation blocked before cast")
assert(drivers[CompactRaidFrame1].type3 == "[combat] macro; none", "combat range handled by secure macro, no frozen out-of-range binding")
ranges.raid1 = true
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1)
assert(CompactRaidFrame1.attrs.type2 == "macro" and CompactRaidFrame1.attrs.type3 == "macro")
SlashCmdList.AGGEHEALBOT("buffs off")
assert(PlayerFrame.attrs.spell1 == "Regrowth", "buff toggle")
assert(not PlayerFrame.regions[2].shown, "buff setting hides icon")
SlashCmdList.AGGEHEALBOT("buffs on")
assert(PlayerFrame.attrs.spell1 == "Mark")
local modified = true
IsModifierKeyDown = function() return modified end
event("MODIFIER_STATE_CHANGED")
assert(not PlayerFrame.regions[2].shown, "modifier suppresses plain click hint")
modified = false
event("MODIFIER_STATE_CHANGED")
assert(PlayerFrame.regions[2].shown, "plain click hint returns")
local enemy = CreateFrame("Button", "CompactNamePlate1")
callbacks.CompactUnitFrame_SetUnit(enemy)
assert(not drivers[enemy], "nameplates untouched")
-- Editing spells and actions must replace old secure attributes, not accumulate them.
SlashCmdList.AGGEHEALBOT("buffs off")
assert(ns.SaveBinding("", 2, "spell", "Rejuvenation"))
assert(PlayerFrame.attrs.spell2 == "Rejuvenation")
assert(not ns.SaveBinding("", 2, "spell", "Made up spell"))
assert(ns.SaveBinding("", 2, "target"))
assert(PlayerFrame.attrs.type2 == "target" and PlayerFrame.attrs.spell2 == nil)
assert(ns.SaveBinding("", 2, "togglemenu"))
assert(PlayerFrame.attrs.type2 == "click" and PlayerFrame.attrs.clickbutton2 == menu, "unit menu can be rebound")
assert(ns.SaveBinding("", 2, "target"))
assert(PlayerFrame.attrs.clickbutton2 == nil, "rebinding removes menu delegate")
assert(ns.SaveBinding("alt-ctrl-", 5, "spell", "Healing Touch"))
assert(PlayerFrame.attrs["alt-ctrl-spell5"] == "Healing Touch")
assert(ns.SaveBinding("", 1, "none"))
SlashCmdList.AGGEHEALBOT("buffs on")
assert(PlayerFrame.attrs.type1 == "none", "buffing respects disabled left click")
assert(ns.SaveBinding("", 1, "target"))
assert(PlayerFrame.attrs.type1 == "target", "buffing respects target action")
assert(ns.SaveBinding("", 1, "default"))
assert(PlayerFrame.attrs.spell1 == "Mark")
combat = true
assert(ns.SaveBinding("", 2, "spell", "Regrowth"))
assert(PlayerFrame.attrs.type2 == "target", "editing during combat defers secure changes")
event("UNIT_AURA", "player")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(PlayerFrame.attrs.spell2 == "Regrowth" and PlayerFrame.attrs.type2 == "macro")
ns.SetOption("playerFrame", false)
assert(not drivers[PlayerFrame].spell1 and not drivers[PlayerFrame].type1)
assert(PlayerFrame.attrs.spell2 == nil and PlayerFrame.attrs.type2 == nil, "portrait original attributes restored")
assert(not PlayerFrame.regions[2].shown, "portrait indicator removed when disabled")
event("GROUP_ROSTER_UPDATE")
assert(PlayerFrame.attrs.spell2 == nil, "disabled portrait stays disabled")
ns.SetOption("playerFrame", true)
assert(PlayerFrame.attrs.spell2 == "Regrowth", "custom binding survives portrait toggling")
ns.ResetBindings()
assert(PlayerFrame.attrs.spell2 == "Healing Touch")
assert(PlayerFrame.attrs["alt-ctrl-type5"] == "none", "reset clears custom modifier")
-- Rank 1 need not be learned: name matching discovers higher learned ranks.
known[8936] = nil
Enum = {SpellBookSpellBank = {Player = 0}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = 5} end,
    GetSpellBookItemInfo = function(slot)
        return ({ {spellID = 8938}, {spellID = 1126}, {spellID = 9990, isPassive = true}, {spellID = 9991}, {spellID = 50769} })[slot]
    end,
}
spellNames[8938] = "Regrowth"
spellNames[9990], spellNames[9991] = "Dodge", "Claw"
spellNames[50769] = "Revive"
event("SPELLS_CHANGED")
SlashCmdList.AGGEHEALBOT("buffs off")
assert(PlayerFrame.attrs.spell1 == "Regrowth", "higher rank learned by name")
local choices = ns.GetSpellChoices()
local order, previous = {heals = 1, buffs = 2, utility = 3, other = 4}, 0
local sawHeal, sawBuff, sawOther, sawRevive = false, false, false, false
for _, item in ipairs(choices) do
    assert(item.label ~= "Dodge", "passives excluded from spell picker")
    assert(order[item.category] >= previous, "heals before buffs before other spells")
    previous = order[item.category]
    sawHeal = sawHeal or item.category == "heals"
    sawBuff = sawBuff or item.category == "buffs"
    sawOther = sawOther or item.category == "other"
    sawRevive = sawRevive or (item.label == "Revive" and item.category == "utility")
end
assert(sawHeal and sawBuff and sawOther and sawRevive, "resurrection spells appear before other spells")
print("PASS: defaults, buffs, ranks, combat guards, rebinding, portrait restore, icons, all-spell range guards and cursor cleanup, menu toggle")

-- Exercise the real options callbacks with lightweight widget mocks.
local originalCreateFrame = CreateFrame
CreateFrame = function(kind, name, parent, template)
    local f = originalCreateFrame(kind, name, parent, template)
    if name then _G[name] = f end
    for _, method in ipairs({"SetSize", "SetPoint", "ClearAllPoints", "SetTextColor", "SetFrameStrata", "SetClampedToScreen", "EnableMouse", "EnableMouseWheel", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetJustifyH", "SetFocus", "ClearFocus"}) do
        f[method] = function() end
    end
    function f:SetText(value)
        self.text = value
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function f:GetText() return self.text or "" end
    function f:SetChecked(v) self.checked = v end
    function f:GetChecked() return self.checked end
    function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:IsShown() return self.shown end
    function f:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:CreateFontString() return CreateFrame("FontString") end
    f.TitleText = {SetText = function() end}
    if template == "PortraitFrameTemplate" then
        f.NineSlice = {}
        f.TitleContainer = CreateFrame("Frame")
        f.PortraitContainer = CreateFrame("Frame")
        f.Bg = Region()
    end
    return f
end
NineSliceUtil = {ApplyLayoutByName = function(frame, layout) frame.layout = layout end}
tinsert = table.insert
assert(loadfile("AggeHealBot/Options.lua"))("AggeHealBot", ns)
SlashCmdList.AGGEHEALBOT("")
assert(AggeHealBotSettings.shown, "settings opens")
assert(AggeHealBotSettings.NineSlice.layout == "ButtonFrameTemplateNoPortrait", "native Blizzard frame layout")
assert(AggeHealBotSettings.tabs[1].glow[1].pulse.playing, "selected modifier pulses")
AggeHealBotSettings.tabs[2].scripts.OnClick()
assert(not AggeHealBotSettings.tabs[1].glow[1].pulse.playing, "previous modifier stops pulsing")
assert(AggeHealBotSettings.tabs[2].glow[1].pulse.playing, "new modifier pulses")
AggeHealBotSettings.tabs[1].scripts.OnClick()
mouseEdge(PlayerFrame, "Button5", true)
assert(not AggeHealBotSettings.shown, "settings mouse binding closes open panel")
mouseEdge(PlayerFrame, "Button5", false)
assert(not AggeHealBotSettings.shown, "release keeps settings closed")
mouseEdge(PlayerFrame, "Button5", true)
assert(AggeHealBotSettings.shown, "settings mouse binding reopens panel")
mouseEdge(PlayerFrame, "Button5", false)
assert(AggeHealBotSettings.shown, "settings stays open after release")
local row = AggeHealBotSettings.rows[2].button
row.scripts.OnClick(row)
assert(AggeHealBotSpellPicker.shown)
AggeHealBotSpellPicker.search:SetText("regrowth")
local choice = AggeHealBotSpellPicker.rows[1]
assert(choice.choice.spell == "Regrowth", "spell search filters choices")
choice.scripts.OnClick(choice)
assert(PlayerFrame.attrs.spell2 == "Regrowth", "picker rebinds right click")
assert(AggeHealBotSpellPicker.shown, "inline browser remains visible after selection")
row.scripts.OnClick(row)
ns.settingsButton.scripts.OnClick(ns.settingsButton)
assert(not AggeHealBotSettings.shown and not AggeHealBotSpellPicker.shown, "toggle closes spell picker with panel")
SlashCmdList.AGGEHEALBOT("")
AggeHealBotSettings.player:SetChecked(false)
AggeHealBotSettings.player.scripts.OnClick(AggeHealBotSettings.player)
assert(not AggeHealBotDB.playerFrame and PlayerFrame.attrs.spell2 == nil)
assert(AggeHealBotDB.hideRaidControls == false, "stock raid controls visible by default")
CompactRaidFrameManager = CreateFrame("Frame")
CompactRaidFrameManager:Show()
function CompactRaidFrameManager_UpdateShown() CompactRaidFrameManager:Show() end
ns.SetOption("hideRaidControls", true)
assert(not CompactRaidFrameManager:IsShown(), "optional raid controls toggle hides manager")
CompactRaidFrameManager:Show()
assert(not CompactRaidFrameManager:IsShown(), "raid controls remain hidden when Blizzard refreshes them")
ns.SetOption("hideRaidControls", false)
assert(CompactRaidFrameManager:IsShown(), "turning option off restores stock controls")
local browser = AggeHealBotSpellPicker
browser.search:SetText("")
browser.tabs[6].scripts.OnClick(browser.tabs[6])
assert(browser.filter == "actions" and browser.rows[1].choice.action == "target", "actions have a separate tab")
browser.tabs[2].scripts.OnClick(browser.tabs[2])
assert(browser.filter == "heals" and browser.rows[1].choice.category == "heals", "heals filter")
browser.tabs[4].scripts.OnClick(browser.tabs[4])
assert(browser.filter == "utility" and browser.rows[1].choice.category == "utility", "utility spells have a category")
browser.search:SetText("no such spell")
assert(browser.empty.shown and not browser.rows[1].shown, "empty search state")
browser.search:SetText("")
browser.tabs[1].scripts.OnClick(browser.tabs[1])
assert(browser.rows[1].choice.category == "heals", "all spells begins with heals, not actions")
print("PASS: inline UI, search/selection, category filters, passive removal, spell priority, raid controls optional/default visible")
