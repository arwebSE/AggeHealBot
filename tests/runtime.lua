-- Run with a Lua 5.1+ interpreter, from the repository root.
local combat, auras, drivers, callbacks = false, {}, {}, {}
local ns, events, coreEvents = {}, nil, nil
local messages, originalPrint = {}, print
function print(message) messages[#messages + 1] = tostring(message); originalPrint(message) end
function GetAddOnMetadata(_, field)
    if field == "Version" then return "test-version" end
end
local ranges, tickers = {}, {}
local cvars = {autoSelfCast = "1", ActionButtonUseKeyDown = "1"}
local now, guids = 100, {}
local menuBoundary
function GetTime() return now end
function UnitGUID(unit) return guids[unit] or ("GUID-" .. unit) end
SPELL_FAILED_AURA_BOUNCED = "A more powerful spell is already active"
function GetGameMessageInfo(errorID) return errorID == 42 and "SPELL_FAILED_AURA_BOUNCED" or "ERR_OUT_OF_RANGE" end
function GetCVar(key) return cvars[key] end
function SetCVar(key, value) assert(not combat, "CVar write during combat"); cvars[key] = value end
local known = {[8936] = "Regrowth", [5185] = "Healing Touch", [774] = "Rejuvenation", [1126] = "Mark", [467] = "Thorns", [2782] = "Remove Curse", [2893] = "Abolish Poison"}
local spellNames = {[21849] = "Gift"}
for id, name in pairs(known) do spellNames[id] = name end
function wipe(t) for k in pairs(t) do t[k] = nil end end
function InCombatLockdown() return combat end
function UnitClass() return "Druid", "DRUID" end
function UnitIsPlayer() return true end
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
    function r:SetBlendMode(value) self.blendMode = value end
    function r:SetAlpha(value) self.alpha = value end
    function r:SetAtlas(value) self.atlas = value end
    function r:SetDesaturated(value) self.desaturated = value end
    function r:SetVertexColor(...) self.vertexColor = {...} end
    function r:SetTexCoord(...) self.texCoords = {...} end
    function r:ClearAllPoints() end
    function r:SetText(value) self.text = value end
    function r:CreateAnimationGroup()
        local group = {playing = false, plays = 0}
        function group:SetLooping(value) self.looping = value end
        function group:CreateAnimation(kind)
            local animation = {kind = kind}
            function animation:SetFromAlpha(value) self.fromAlpha = value end
            function animation:SetToAlpha(value) self.toAlpha = value end
            function animation:SetDuration(value) self.duration = value end
            function animation:SetSmoothing(value) self.smoothing = value end
            self.animation = animation
            return animation
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
    local f = {attrs = {}, scripts = {}, name = name, regions = {}, template = template, parent = parent}
    function f:CreateTexture() local r = Region(); self.regions[#self.regions + 1] = r; return r end
    function f:CreateFontString() local r = Region(); self.regions[#self.regions + 1] = r; return r end
    function f:GetName() return self.name end
    function f:GetFrameLevel() return self.frameLevel or 1 end
    function f:SetFrameLevel(level) self.frameLevel = level end
    function f:SetAllPoints(relative) self.allPoints = relative end
    function f:EnableMouse() end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:SetPoint(...) self.point = {...} end
    function f:SetHitRectInsets() end
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
local function event(e, ...)
    local target = coreEvents or events
    target.scripts.OnEvent(target, e, ...)
end
-- Model the secure template's action between addon PreClick/PostClick hooks.
-- This verifies routing; the client is still needed to validate actual taint.
local function clickDelegate(delegate, button, prefix)
    if delegate.scripts.PreClick then delegate.scripts.PreClick(delegate, button) end
    if delegate.template == "SecureActionButtonTemplate" then
        assert(delegate.scripts.OnClick == nil, "addon code must not replace the native secure OnClick")
        prefix = prefix or ""
        local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2"
            or button == "MiddleButton" and "3" or button:match("^Button(%d+)$")
        local action = delegate.attrs[prefix .. "type" .. suffix] or delegate.attrs["*type" .. suffix]
            or delegate.attrs[prefix .. "type*"] or delegate.attrs["*type*"] or delegate.attrs.type
        assert(action == "togglemenu", "delegate must resolve a menu action for the forwarded button and modifier")
        assert(delegate.attrs.useOnKeyDown == false and delegate.clicks[1] == "AnyUp",
            "delegated Click(button) must execute regardless of the global key-down preference")
        local previous = menuBoundary
        menuBoundary = "secure-action"
        UnitPopup_OpenMenu(nil, {ownerFrame = delegate, unit = delegate.attrs.unit}, button)
        menuBoundary = previous
    else
        delegate.scripts.OnClick(delegate, button)
    end
    if delegate.scripts.PostClick then delegate.scripts.PostClick(delegate, button) end
end
local function mouseEdge(frame, button, down, prefix)
    local wanted = down and "AnyDown" or "AnyUp"
    local registered = false
    for _, edge in ipairs(frame.clicks or {}) do if edge == wanted then registered = true end end
    if not registered then return end
    local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or button == "MiddleButton" and "3" or button:match("^Button(%d+)$")
    prefix = prefix or ""
    if suffix and frame.attrs[prefix .. "type" .. suffix] == "click" then
        local delegate = frame.attrs[prefix .. "clickbutton" .. suffix]
        clickDelegate(delegate, button, prefix)
    end
end
assert(loadfile("AggeHealBot/Defaults.lua"))("AggeHealBot", ns)
assert(loadfile("AggeHealBot/CastHints.lua"))("AggeHealBot", ns)
assert(ns.presets.MAGE == nil and ns.buffs.MAGE == nil, "mage utility preset and buff reminders are not supported")
assert(loadfile("AggeHealBot/Indicators.lua"))("AggeHealBot", ns)
assert(loadfile("AggeHealBot/Core.lua"))("AggeHealBot", ns)
coreEvents = events
event("ADDON_LOADED", "AggeHealBot")
event("PLAYER_LOGIN")
assert(ns.version == GetAddOnMetadata("AggeHealBot", "Version"))
assert(messages[#messages]:find("v" .. ns.version .. " loaded", 1, true), "login announces installed TOC version")
assert(cvars.autoSelfCast == "1", "frame targeting must leave the global Auto Self Cast preference unchanged")
assert(AggeHealBotDB.smartBuffs == true)
assert(AggeHealBotDB.targetFrame == true, "target support must default on for existing saved settings without the new option")
assert(AggeHealBotDB.playerFrame == true, "portrait support defaults on")
assert(drivers[PlayerFrame].spell1, "portrait is registered by default")
ns.SetOption("playerFrame", true)
assert(AggeHealBotDB.rightClickMenu == false and PlayerFrame.attrs.spell2 == "Healing Touch", "plain right-click must use the assigned heal by default")
ns.SetOption("rightClickMenu", false)
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
function CompactUnitFrame_OpenMenu()
    error("addon must not build native menus through a Lua fallback")
end
function UnitPopup_OpenMenu(_, context, mouseButton)
    assert(menuBoundary == "secure-action", "only the native secure action may build the unit menu")
    menuUnit, menuMouse = context.unit, mouseButton
    local builtSecurely = menuBoundary == "secure-action"
    currentMenu = {PickPVP = function() assert(builtSecurely, "protected PvP action must retain a securely-built menu") end}
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
clickDelegate(menu, "Button4")
assert(currentMenu, "unit menu reopens")
currentMenu = nil
clickDelegate(menu, "Button4")
assert(currentMenu, "unit menu reopens after external dismissal")
PlayerFrame:SetAttribute("unit", "party1")
PlayerFrame.scripts.PreClick(PlayerFrame, "Button4")
clickDelegate(menu, "Button4")
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
-- Display names may differ from the live aura's canonical spell/rank name.
spellNames[5232] = "Mark"
auras.raid1 = {{name = "Empowered Wild display name", spellId = 5232, auraInstanceID = 501}}
event("UNIT_AURA", "raid1")
assert(CompactRaidFrame1.attrs.spell1 == "Thorns", "higher-rank aura recognized by canonical spell name")
-- Different spells can block ours under the game's stacking rules.
auras.raid1 = {{name = "Superior Ward", spellId = 9992, auraInstanceID = 502}}
event("UNIT_AURA", "raid1")
assert(CompactRaidFrame1.attrs.spell1 == "Mark")
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Thorns", "rejected Mark skipped despite blocker having another name")
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Regrowth", "normal heal restored when remaining buffs cannot be applied")
assert(not CompactRaidFrame1.regions[2].shown and not CompactRaidFrame1.regions[3].shown, "rejected buffs have no icon or glow")
event("UNIT_AURA", "raid1")
assert(CompactRaidFrame1.attrs.spell1 == "Regrowth", "unchanged blocker must not reoffer rejected buffs")
auras.raid1[2] = {name = "Temporary HoT", auraInstanceID = 503}
event("UNIT_AURA", "raid1")
assert(CompactRaidFrame1.attrs.spell1 == "Regrowth", "new unrelated aura does not trigger a retry")
auras.raid1 = {}
event("UNIT_AURA", "raid1")
assert(CompactRaidFrame1.attrs.spell1 == "Mark", "removing conflicting buff restores offer")
-- An error after another click, or an unrelated error, is not a buff rejection.
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "RightButton")
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Mark")
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
event("UI_ERROR_MESSAGE", 99, "Out of range")
assert(CompactRaidFrame1.attrs.spell1 == "Mark")
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
now = now + 2
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Mark", "stale error not attributed to buff")
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
guids.raid1 = "GUID-new-occupant"
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Mark", "failure must not carry over to another player")
guids.raid1 = nil
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
event("UNIT_SPELLCAST_SENT", "player", "", "cast-other", 774)
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Mark", "unrelated spell error not attributed to prior buff click")
CompactRaidFrame1.scripts.PreClick(CompactRaidFrame1, "LeftButton")
event("UNIT_SPELLCAST_SUCCEEDED", "player")
event("UI_ERROR_MESSAGE", 42, SPELL_FAILED_AURA_BOUNCED)
assert(CompactRaidFrame1.attrs.spell1 == "Mark", "successful cast clears pending error attribution")
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
assert(PlayerFrame.attrs.type2 == "macro" and PlayerFrame.attrs.spell2 == nil
    and PlayerFrame.attrs.macrotext2 == "/target [@player,exists]")
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
assert(PlayerFrame.attrs.type1 == "macro" and PlayerFrame.attrs.macrotext1 == "/target [@player,exists]", "buffing respects target action")
assert(ns.SaveBinding("", 1, "default"))
assert(PlayerFrame.attrs.spell1 == "Mark")
combat = true
assert(ns.SaveBinding("", 2, "spell", "Regrowth"))
assert(PlayerFrame.attrs.type2 == "macro" and PlayerFrame.attrs.macrotext2 == "/target [@player,exists]", "editing during combat defers secure changes")
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
    for _, method in ipairs({"SetSize", "SetWidth", "SetWordWrap", "SetPoint", "ClearAllPoints", "SetTextColor", "SetFrameStrata", "SetClampedToScreen", "EnableMouse", "EnableMouseWheel", "SetMovable", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetAutoFocus", "SetJustifyH", "SetFocus", "ClearFocus"}) do
        f[method] = function() end
    end
    function f:SetParent(value) self.parent = value end
    function f:SetPoint(...) self.point = {...} end
    function f:SetScale(value) self.scale = value end
    function f:SetSize(width, height) self.width, self.height = width, height end
    function f:GetWidth() return self.width or 780 end
    function f:GetHeight() return self.height or 548 end
    function f:SetFrameStrata(value) self.strata = value end
    function f:GetFrameStrata() return self.strata or "DIALOG" end
    function f:SetText(value)
        self.text = value
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end
    end
    function f:GetText() return self.text or "" end
    function f:GetStringWidth() return #(self.text or "") * 5 end
    function f:SetChecked(v) self.checked = v end
    function f:SetEnabled(value) self.enabled = value end
    function f:SetAlpha(value) self.alpha = value end
    function f:SetTextColor(...) self.textColor = {...} end
    function f:GetChecked() return self.checked end
    function f:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:IsShown() return self.shown end
    function f:IsVisible()
        if not self.shown then return false end
        return not self.parent or not self.parent.IsVisible or self.parent:IsVisible()
    end
    function f:Hide()
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:CreateFontString() return CreateFrame("FontString") end
    if kind == "DropdownButton" then
        f.Text = CreateFrame("FontString")
        function f:SetDefaultText(text) self.defaultText = text end
        function f:CloseMenu() self.menuOpen = false end
        function f:SetupMenu(generator) self.menuGenerator = generator end
        function f:GenerateMenu()
            self.menuOptions = {}
            local dropdown = self
            local root = {}
            function root:CreateRadio(label, selected, choose, data)
                dropdown.menuOptions[data] = {label = label, selected = function() return selected(data) end,
                    choose = function() choose(data) end}
                if selected(data) then dropdown.selectedText = label end
            end
            self.menuGenerator(self, root)
        end
    end
    f.TitleText = {SetText = function() end}
    if template == "PortraitFrameTemplate" then
        f.NineSlice = CreateFrame("Frame")
        f.TitleContainer = CreateFrame("Frame")
        f.PortraitContainer = CreateFrame("Frame")
        f.Bg = Region()
    end
    if template == "GameTooltipTemplate" then
        for _, side in ipairs({"Left", "Right"}) do
            _G[name .. "Text" .. side .. "1"] = {
                SetFontObject = function(self, font) self.fontObject = font end,
                SetTextColor = function() end,
            }
        end
        function f:SetPoint(...) self.anchor = {...} end
        function f:ClearAllPoints() self.anchor = nil end
        function f:SetFrameLevel() end
        function f:SetOwner(owner, anchor) self.owner, self.ownerAnchor, self.lines, self.anchor = owner, anchor, {}, nil end
        function f:ClearLines() self.lines, self.doubleLines = {}, {} end
        function f:IsOwned(owner) return self.owner == owner end
        function f:SetText(text) self.lines = {text} end
        function f:AddLine(text) self.lines[#self.lines + 1] = text end
        function f:AddDoubleLine(left, right)
            self.lines[#self.lines + 1] = left .. right
            self.doubleLines = self.doubleLines or {}
            self.doubleLines[#self.doubleLines + 1] = {left, right}
        end
    end
    return f
end
NineSliceUtil = {ApplyLayoutByName = function(frame, layout) frame.layout = layout end}
GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent, "GameTooltipTemplate")
local registeredCanvas, registeredCategory
Settings = {
    RegisterCanvasLayoutCategory = function(canvas, name)
        assert(name == "AggeHealBot")
        registeredCanvas = canvas
        return {name = name, GetID = function() return 77 end}
    end,
    RegisterAddOnCategory = function(category) registeredCategory = category end,
}
tinsert = table.insert
C_Texture = {GetAtlasInfo = function()
    return {width = 96, height = 144, leftTexCoord = 0, rightTexCoord = 1, topTexCoord = 0, bottomTexCoord = 1}
end}
assert(loadfile("AggeHealBot/MouseBindings.lua"))("AggeHealBot", ns)
assert(loadfile("AggeHealBot/Options.lua"))("AggeHealBot", ns)
assert(registeredCanvas and registeredCategory, "editor registered in Options AddOns")
local category = ns.RegisterOptionsCategory()
assert(category == registeredCategory, "category registration is idempotent")
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
assert(AggeHealBotDB.hideRaidControls == true, "raid controls hidden by default")
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
assert(browser.filter == "suggested" and browser.tabs[1].category == "suggested", "Suggested must be the default")
local suggestedCategories = {}
for page = 1, browser.pages do
    browser.page = page
    browser:Render()
    for _, item in ipairs(browser.rows) do
        if item.choice then
            assert(item.choice.category == "heals" or item.choice.category == "buffs" or item.choice.category == "utility")
            suggestedCategories[item.choice.category] = true
        end
    end
end
assert(suggestedCategories.heals and suggestedCategories.buffs and suggestedCategories.utility,
    "Suggested combines healing, buffs and utility")
assert(browser.tabs[#browser.tabs].category == "all", "All must be the rightmost tab")
browser.search:SetText("Claw")
assert(browser.empty.shown, "Suggested excludes Other spells")
browser.tabs[6].scripts.OnClick(browser.tabs[6])
assert(browser.rows[1].choice.spell == "Claw", "All still includes Other spells")
browser.search:SetText("")
local allSpells, allActions = {}, {}
for page = 1, browser.pages do
    browser.page = page
    browser:Render()
    for _, item in ipairs(browser.rows) do
        if item.choice then
            if item.choice.action == "spell" then allSpells[item.choice.spell] = true
            else allActions[item.choice.action] = true end
        end
    end
end
for _, item in ipairs(browser.choices) do assert(allSpells[item.spell], "All must include every spell across its pages") end
for _, item in ipairs(browser.actions) do assert(allActions[item.action], "All must include every action across its pages") end
browser.search:SetText("AggeHealBot settings")
assert(browser.rows[1].choice.action == "settings", "All must search actions as well as spells")
browser.search:SetText("")
browser.tabs[5].scripts.OnClick(browser.tabs[5])
assert(browser.filter == "actions" and browser.rows[1].choice.action == "target", "actions have a separate tab")
browser.tabs[2].scripts.OnClick(browser.tabs[2])
assert(browser.filter == "heals" and browser.rows[1].choice.category == "heals", "heals filter")
browser.tabs[4].scripts.OnClick(browser.tabs[4])
assert(browser.filter == "utility" and browser.rows[1].choice.category == "utility", "utility spells have a category")
browser.search:SetText("no such spell")
assert(browser.empty.shown and not browser.rows[1].shown, "empty search state")
browser.search:SetText("")
browser.tabs[1].scripts.OnClick(browser.tabs[1])
assert(browser.rows[1].choice.category == "heals", "Suggested begins with heals")
local samePanel, sameBinding = AggeHealBotSettings, AggeHealBotSettings.rows[2].button
registeredCanvas:SetSize(650, 500)
registeredCanvas:SetFrameStrata("HIGH")
registeredCanvas:Show()
assert(AggeHealBotSettings == samePanel and samePanel.parent == registeredCanvas, "native settings uses the same editor instance")
assert(samePanel.rows[2].button == sameBinding and samePanel.scale < 1, "same controls fit native options area")
assert(samePanel:GetFrameStrata() == "HIGH", "embedded editor stays above native options background")
assert(not samePanel.NineSlice.shown and not samePanel.done.shown, "embedded editor hides standalone chrome")
registeredCanvas:Hide()
assert(not samePanel.shown, "changing category hides embedded editor")
SlashCmdList.AGGEHEALBOT("")
assert(samePanel.parent == UIParent and samePanel.shown and samePanel.scale == 1, "slash command restores standalone editor")
assert(samePanel.NineSlice.shown and samePanel.done.shown, "standalone chrome restored")
local escapeEntries = 0
for _, name in ipairs(UISpecialFrames) do if name == "AggeHealBotSettings" then escapeEntries = escapeEntries + 1 end end
assert(escapeEntries == 1, "standalone Escape entry is not duplicated")
print("PASS: inline UI, search/selection, category filters, passive removal, spell priority, raid controls optional/default visible")

ns.SetOption("playerFrame", true)
assert(ns.SaveBinding("shift-", 1, "spell", "Regrowth"))
assert(PlayerFrame.attrs["shift-type1"] == "macro", "saved Shift-left spell overrides the default target action")
assert(PlayerFrame.attrs["shift-type3"] == "click" and PlayerFrame.attrs["shift-clickbutton3"] == ns.settingsButton)
assert(PlayerFrame.attrs["shift-macrotext3"] == nil, "menu binding must not also cast a heal")
assert(CompactRaidFrame1.attrs["shift-type1"] == "macro", "party/raid Shift-left spell must remain unchanged")
manager:CloseMenus()
mouseEdge(PlayerFrame, "RightButton", true, "shift-")
assert(currentMenu, "Shift-right opens the unit context menu")
mouseEdge(PlayerFrame, "RightButton", false, "shift-")
assert(currentMenu, "releasing Shift-right leaves the context menu open")
mouseEdge(PlayerFrame, "RightButton", true, "shift-")
assert(not currentMenu, "pressing Shift-right again closes the context menu")
if AggeHealBotSettings.shown then ns.ToggleOptions() end
mouseEdge(PlayerFrame, "MiddleButton", true, "shift-")
assert(AggeHealBotSettings.shown, "Shift-middle opens the settings menu")
mouseEdge(PlayerFrame, "MiddleButton", false, "shift-")
assert(AggeHealBotSettings.shown, "mouse release must leave the menu open")
combat = true
mouseEdge(PlayerFrame, "MiddleButton", true, "shift-")
assert(not AggeHealBotSettings.shown, "preinstalled portrait shortcut works in combat")
combat = false

local shiftHeld, ctrlHeld = true, false
manager:CloseMenus()
GameTooltipHeaderText, GameFontHighlightSmall = {}, {}
IsShiftKeyDown = function() return shiftHeld end
IsControlKeyDown = function() return ctrlHeld end
IsAltKeyDown = function() return false end
IsModifierKeyDown = function() return shiftHeld or ctrlHeld end
GameTooltip = {lines = {}}
function GameTooltip:ClearAllPoints() self.anchor = nil end
function GameTooltip:SetPoint(...) self.anchor = {...} end
function GameTooltip:SetOwner(owner) self.owner, self.lines = owner, {} end
function GameTooltip:IsOwned(owner) return self.owner == owner end
function GameTooltip:SetUnit(unit) self.lines = {unit} end
function GameTooltip:SetText(text) self.lines = {text} end
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
function GameTooltip:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. right end
function GameTooltip:Show() self.shown = true end
function GameTooltip:Hide() self.shown = false end
PlayerFrame.scripts.OnEnter(PlayerFrame)
local shortcutTooltip = AggeHealBotTooltip
assert(GameTooltip.shown and GameTooltip:IsOwned(PlayerFrame), "self portrait must show Blizzard's original tooltip alongside the Shift hint")
assert(GameTooltip.anchor[1] == "BOTTOMRIGHT" and shortcutTooltip.ownerAnchor == "ANCHOR_RIGHT", "self portrait must use the shared native-tooltip position and keep addon information beside the frame")
assert(shortcutTooltip.shown and shortcutTooltip.lines[2] == "Shift + Middle Click to open AggeHealBot Menu.")
-- Simulate the stock unit tooltip being rebuilt/faded by Blizzard after hover.
GameTooltip:SetUnit("player")
GameTooltip:Hide()
assert(shortcutTooltip.shown and shortcutTooltip.lines[2] == "Shift + Middle Click to open AggeHealBot Menu.", "Blizzard tooltip refresh must not erase or fade the shortcut hint")
shiftHeld = false
event("MODIFIER_STATE_CHANGED")
assert(shortcutTooltip.shown and #shortcutTooltip.lines > 2 and shortcutTooltip.lines[2] ~= "Shift + Middle Click to open AggeHealBot Menu.", "releasing Shift must show the full persistent binding tooltip")
assert(GameTooltip.shown and GameTooltip:IsOwned(PlayerFrame), "normal self hover must keep Blizzard's tooltip visible beside addon information")
local normalTooltipLines = #shortcutTooltip.lines
GameTooltip:SetOwner(PlayerFrame, "ANCHOR_RIGHT")
GameTooltip:SetUnit("player")
GameTooltip:Hide()
assert(shortcutTooltip.shown and #shortcutTooltip.lines == normalTooltipLines, "stock tooltip updates must not erase the normal portrait binding tooltip")
shiftHeld = true
event("MODIFIER_STATE_CHANGED")
assert(shortcutTooltip.shown and #shortcutTooltip.lines == 7 and shortcutTooltip.lines[2] == "Shift + Middle Click to open AggeHealBot Menu.", "holding Shift during hover must update the tooltip without duplicate lines")
ctrlHeld = true
event("MODIFIER_STATE_CHANGED")
assert(shortcutTooltip.shown and shortcutTooltip.lines[2] ~= "Shift + Middle Click to open AggeHealBot Menu.", "Ctrl-Shift must show the normal persistent tooltip")
ctrlHeld = false
ns.SetOption("playerFrame", false)
assert(PlayerFrame.attrs["shift-type1"] == nil and PlayerFrame.attrs["shift-clickbutton1"] == nil)
assert(not GameTooltip.shown, "disabling portrait support must remove the hint")
assert(not shortcutTooltip.shown, "disabling portrait support must hide the dedicated hint")
ns.SetOption("playerFrame", true)
PlayerFrame.scripts.OnEnter(PlayerFrame)
PlayerFrame.scripts.OnLeave(PlayerFrame)
assert(not GameTooltip.shown, "leaving the portrait hides its tooltip")
assert(not shortcutTooltip.shown, "leaving the portrait must hide the dedicated hint")
event("MODIFIER_STATE_CHANGED")
assert(not GameTooltip.shown, "modifier changes after leaving must not reopen the tooltip")
assert(not shortcutTooltip.shown, "modifier changes after leaving must not reopen the dedicated hint")
print("PASS: rebindable Shift-middle menu toggles once, works in combat, restores on disable, and shows a live modifier tooltip")

local normalParty = CreateFrame("Button", "PartyMemberFrame1")
normalParty:SetAttribute("unit", "party1")
callbacks.SecureUnitButton_OnLoad(normalParty)
UnitName = function(unit) return "Member " .. unit end
shiftHeld = false
for _, frame in ipairs({normalParty, CompactRaidFrame1}) do
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    frame.scripts.OnEnter(frame)
    assert(GameTooltip.shown and GameTooltip:IsOwned(frame), "party/raid hover must preserve Blizzard's original unit tooltip")
    assert(AggeHealBotTooltip.shown and AggeHealBotTooltip:IsOwned(frame), "party/raid hover must own the persistent tooltip")
    assert(AggeHealBotTooltip.ownerAnchor == "ANCHOR_RIGHT" and AggeHealBotTooltip.anchor == nil, "binding panel must remain beside the hovered unit frame, independently of Blizzard's tooltip")
    local count = #AggeHealBotTooltip.lines
    assert(count > 2 and AggeHealBotTooltip.doubleLines[1][1] == "Member " .. frame:GetAttribute("unit") and AggeHealBotTooltip.doubleLines[1][2] == "AggeHealBot", "tooltip heading must show the member's name on the left and addon label on the right")
    assert(AggeHealBotTooltipTextLeft1.fontObject == GameTooltipHeaderText and AggeHealBotTooltipTextRight1.fontObject == GameFontHighlightSmall, "member name uses the large header font and addon label uses the small font")
    GameTooltip:SetUnit(frame:GetAttribute("unit"))
    GameTooltip:Hide()
    assert(AggeHealBotTooltip.shown and #AggeHealBotTooltip.lines == count, "stock refresh must not erase party/raid binding information")
    event("UNIT_AURA", frame:GetAttribute("unit"))
    assert(GameTooltip.shown and GameTooltip:IsOwned(frame), "aura updates must keep the original tooltip available")
    assert(AggeHealBotTooltip.shown and #AggeHealBotTooltip.lines == count, "aura refresh must update the tooltip without duplicated rows")
    shiftHeld = true
    event("MODIFIER_STATE_CHANGED")
    assert(#AggeHealBotTooltip.lines > 2, "party/raid Shift-hover must not show the portrait-only menu hint")
    shiftHeld = false
    frame.scripts.OnLeave(frame)
    assert(not AggeHealBotTooltip.shown, "party/raid tooltip must hide on leave")
    assert(not GameTooltip.shown, "original tooltip must also hide on leave")
end
normalParty.scripts.OnEnter(normalParty)
CompactRaidFrame1.scripts.OnEnter(CompactRaidFrame1)
normalParty.scripts.OnLeave(normalParty)
assert(AggeHealBotTooltip.shown and AggeHealBotTooltip:IsOwned(CompactRaidFrame1), "late leave from previous frame must not hide the new member's tooltip")
CompactRaidFrame1.scripts.OnLeave(CompactRaidFrame1)
print("PASS: regular party and raid hover tooltips survive stock refreshes and aura updates, identify their member, and hide on leave")

-- Aura access can be denied outside combat before any table is returned.
local auraGetter = C_UnitAuras.GetAuraDataByIndex
local globalRestriction, restrictedIndex, deniedIndex = false, nil, nil
local reads, partyReads, restrictedReads = 0, 0, 0
C_Secrets = {
    ShouldAurasBeSecret = function() return globalRestriction end,
    ShouldUnitAuraIndexBeSecret = function(unit, index)
        return unit == "party1" and index == restrictedIndex
    end,
}
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    reads = reads + 1
    assert(not globalRestriction, "aura getter must not run while aura access is globally restricted")
    if unit == "party1" then
        partyReads = partyReads + 1
        if index == restrictedIndex then restrictedReads = restrictedReads + 1 end
        assert(index ~= restrictedIndex, "restricted aura index must not be queried")
        if index == deniedIndex then error("Auras cannot be accessed when secret while tainted by 'AggeHealBot'") end
    end
    return auraGetter(unit, index, filter)
end
auras.party1, ranges.party1 = {}, true
ns.SetOption("smartBuffs", true)
assert(normalParty.attrs.spell1 == "Mark" and normalParty.regions[2].shown)
reads, partyReads = 0, 0
globalRestriction = true
tickers[1]()
assert(reads == 0, "secrecy changes must skip the aura getter even outside combat")
assert(normalParty.attrs.spell1 == "Regrowth" and not normalParty.regions[2].shown, "new restrictions must clear stale buff prompts and restore healing")
globalRestriction = false
tickers[1]()
assert(normalParty.attrs.spell1 == "Mark" and normalParty.regions[2].shown, "buff reminders must recover when secrecy clears without another aura event")

auras.party1 = {{name = "Thorns"}}
restrictedIndex, partyReads = 2, 0
event("UNIT_AURA", "party1")
assert(partyReads > 0 and restrictedReads == 0 and normalParty.attrs.spell1 == "Regrowth" and not normalParty.regions[2].shown, "a restricted index must discard the entire partial scan")
restrictedIndex, deniedIndex = nil, 1
event("UNIT_AURA", "party1")
assert(normalParty.attrs.spell1 == "Regrowth" and not normalParty.regions[2].shown, "a denied API call must not be treated as an empty aura list")
deniedIndex = 2
event("UNIT_AURA", "party1")
assert(normalParty.attrs.spell1 == "Regrowth" and not normalParty.regions[2].shown, "mid-scan API denial must not leave a partial buff decision")
deniedIndex = nil
C_Secrets.ShouldAurasBeSecret = function() error("secrecy unavailable") end
reads = 0
event("UNIT_AURA", "party1")
assert(reads == 0 and normalParty.attrs.spell1 == "Regrowth", "failed secrecy checks must not permit an aura read")

local previousSecretCheck = issecretvalue
local secretAura = setmetatable({}, {__index = function() error("secret aura field access") end})
issecretvalue = function(value) return value == secretAura end
C_Secrets.ShouldAurasBeSecret = function() return secretAura end
reads = 0
event("UNIT_AURA", "party1")
assert(reads == 0, "secret secrecy results must not permit an aura read")
C_Secrets.ShouldAurasBeSecret = function() return false end
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    if unit == "party1" then return secretAura end
    return auraGetter(unit, index, filter)
end
event("UNIT_AURA", "party1")
assert(normalParty.attrs.spell1 == "Regrowth" and not normalParty.regions[2].shown, "a secret aura table must not be inspected")
issecretvalue = previousSecretCheck
C_Secrets = nil
C_UnitAuras.GetAuraDataByIndex = auraGetter
auras.party1 = {}
event("UNIT_AURA", "party1")
assert(normalParty.attrs.spell1 == "Mark" and normalParty.regions[2].shown, "clients without secrecy predicates must still scan readable auras")
print("PASS: out-of-combat aura secrecy, API denial, partial scans, secret aura tables, automatic recovery and legacy compatibility")

local targetFriendly, targetExists = true, true
local oldUnitCanAssist, oldUnitExists = UnitCanAssist, UnitExists
UnitCanAssist = function(player, unit)
    if unit == "target" then return targetFriendly end
    return oldUnitCanAssist(player, unit)
end
UnitExists = function(unit)
    if unit == "target" then return targetExists end
    return oldUnitExists(unit)
end
local targetVisibility
local function secureTargetVisibility()
    if targetVisibility ~= "hide" and targetExists and targetFriendly then ns.targetButton:Show() else ns.targetButton:Hide() end
end
function RegisterStateDriver(frame, state, expression)
    assert(not combat and frame == ns.targetButton and state == "visibility")
    targetVisibility = expression
    secureTargetVisibility()
end
TargetFrame = CreateFrame("Button", "TargetFrame")
TargetFrame:SetAttribute("unit", "target")
TargetFrame:SetAttribute("type1", "target")
TargetFrame:SetAttribute("type2", "togglemenu")
TargetFrame:SetAttribute("menu-function", function(frame, unit)
    error("addon must not invoke the native target menu callback from Lua")
end)
auras.target, guids.target = {}, "friendly-A"
event("GROUP_ROSTER_UPDATE")
local targetButton = ns.targetButton
assert(targetButton.parent == TargetFrame and targetButton.template == "SecureUnitButtonTemplate")
assert(targetVisibility == "[@target,exists,help] show; hide" and targetButton.shown, "secure visibility must limit target clicks to friendly targets")
assert(targetButton.attrs.spell1 == "Mark" and targetButton.regions[2].shown, "friendly targets get default buff priority and an icon")
assert(TargetFrame.attrs.type1 == "target" and TargetFrame.attrs.type2 == "togglemenu", "native target bindings must remain untouched")
assert(targetButton.attrs["shift-clickbutton3"] == ns.settingsButton, "target gets the rebindable Shift-middle menu default")
mouseEdge(targetButton, "Button4", true)
assert(menuUnit == "target" and currentMenu, "target menu binding must use the secure native action for target")
currentMenu.PickPVP()
assert(targetButton:GetAttribute("menu-function") == nil, "target overlay must not install an addon menu wrapper")
combat = true
mouseEdge(targetButton, "RightButton", true, "shift-")
mouseEdge(targetButton, "RightButton", false, "shift-")
assert(not currentMenu, "combat modifier menu must toggle closed without protected writes")
mouseEdge(targetButton, "RightButton", true, "shift-")
assert(currentMenu and menuUnit == "target", "combat modifier menu must reopen through the secure action")
currentMenu.PickPVP()
combat = false
manager:CloseMenus()
auras.target = {{name = "Mark"}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Thorns", "target watcher advances through missing buffs")
auras.target[2] = {name = "Thorns"}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Regrowth" and not targetButton.regions[2].shown, "fully buffed targets return to healing")
auras.target, guids.target = {}, "friendly-B"
event("PLAYER_TARGET_CHANGED")
assert(targetButton.attrs.spell1 == "Mark" and targetButton.regions[2].shown, "switching friendly targets must refresh the watcher")
local targetCombatMacro = targetButton.attrs.macrotext1
assert(targetCombatMacro:find("combat,@target,help,nodead", 1, true) and targetCombatMacro:find("Regrowth", 1, true), "combat must heal the explicit friendly target instead of casting the pending buff")
combat = true
event("PLAYER_REGEN_DISABLED")
targetFriendly = false
secureTargetVisibility()
event("PLAYER_TARGET_CHANGED")
assert(not targetButton.shown and not targetButton.regions[2].shown, "hostile target switches in combat must hide the click surface and badge")
assert(TargetFrame.attrs.type1 == "target" and TargetFrame.attrs.type2 == "togglemenu")
targetFriendly = true
secureTargetVisibility()
event("PLAYER_TARGET_CHANGED")
assert(targetButton.shown and targetButton.attrs.macrotext1 == targetCombatMacro, "friendly target switches in combat must reuse preinstalled secure healing bindings")
combat = false
event("PLAYER_REGEN_ENABLED")
ranges.target = false
event("UNIT_AURA", "target")
assert(targetButton.attrs.type1 == "none" and not targetButton.regions[2].shown, "target buffs must respect range guards")
ranges.target = true
targetExists = false
secureTargetVisibility()
event("PLAYER_TARGET_CHANGED")
assert(not targetButton.shown and not targetButton.regions[2].shown, "clearing target must clear the indicator")
print("PASS: friendly target bindings, buffs, native menus, range guards, target switching and secure enemy pass-through during combat")

targetExists, targetFriendly = true, true
secureTargetVisibility()
event("PLAYER_TARGET_CHANGED")
ns.ShowOptions()
assert(AggeHealBotSettings.target:GetChecked(), "target setting must appear checked in the menu by default")
targetButton.scripts.OnEnter(targetButton)
assert(AggeHealBotTooltip.shown)
AggeHealBotSettings.target:SetChecked(false)
AggeHealBotSettings.target.scripts.OnClick(AggeHealBotSettings.target)
assert(AggeHealBotDB.targetFrame == false and not targetButton.shown and targetVisibility == "hide")
assert(not targetButton.regions[2].shown and not AggeHealBotTooltip.shown, "disabling target support must hide the buff icon and tooltip")
assert(not drivers[targetButton].spell1 and not drivers[targetButton].type1, "disabled target must not retain healing/buff drivers")
assert(TargetFrame.attrs.type1 == "target" and TargetFrame.attrs.type2 == "togglemenu", "disabling restores normal target interaction")
local auraReadsWhileDisabled = 0
local readableAuraGetter = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    if unit == "target" then auraReadsWhileDisabled = auraReadsWhileDisabled + 1 end
    return readableAuraGetter(unit, index, filter)
end
event("UNIT_AURA", "target")
assert(auraReadsWhileDisabled == 0, "disabled target support must stop watching target buffs")
event("ADDON_LOADED", "AggeHealBot")
assert(AggeHealBotDB.targetFrame == false, "saved opt-out must not reset to the default")
C_UnitAuras.GetAuraDataByIndex = readableAuraGetter
AggeHealBotSettings.target:SetChecked(true)
AggeHealBotSettings.target.scripts.OnClick(AggeHealBotSettings.target)
assert(ns.targetButton == targetButton and targetButton.shown and targetButton.regions[2].shown, "enabling must reuse the existing secure button and resume buff watching")
assert(targetButton.attrs.spell1 == "Mark" and targetButton.clicks[1] == "AnyDown")
combat = true
ns.SetOption("targetFrame", false)
assert(targetButton.shown and targetVisibility ~= "hide", "secure target disabling during combat must defer until combat ends")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not targetButton.shown and targetVisibility == "hide", "queued disable must apply after combat")
combat = true
ns.SetOption("targetFrame", true)
assert(not targetButton.shown, "enabling during combat must also defer")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(targetButton.shown and targetVisibility == "[@target,exists,help] show; hide", "queued enable must restore secure friendly-only support")
print("PASS: target option defaults on, preserves saved opt-out, disables watching and tooltips, reenables safely and defers combat changes")

local defaultAnchorCalls = 0
function GameTooltip_SetDefaultAnchor(tooltip, owner)
    defaultAnchorCalls = defaultAnchorCalls + 1
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
end
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
targetButton.scripts.OnEnter(targetButton)
assert(defaultAnchorCalls == 1 and GameTooltip.shown and GameTooltip:IsOwned(targetButton), "target hover must use Blizzard's default tooltip positioning")
assert(GameTooltip.anchor[1] == "BOTTOMRIGHT" and AggeHealBotTooltip.ownerAnchor == "ANCHOR_RIGHT", "native target details and addon bindings must have separate anchors")
event("UNIT_AURA", "target")
assert(defaultAnchorCalls == 1, "refreshes must preserve the existing native tooltip anchor")
targetButton.scripts.OnLeave(targetButton)
GameTooltip_SetDefaultAnchor = nil
GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
targetButton.scripts.OnEnter(targetButton)
assert(GameTooltip.anchor[1] == "BOTTOMRIGHT" and GameTooltip.owner == targetButton, "fallback must also place native details away from the frame-relative binding tooltip")
targetButton.scripts.OnLeave(targetButton)
print("PASS: original target tooltip uses the native default position while addon bindings remain next to the target frame")

assert(ns.SaveBinding("", 2, "spell", "Rejuvenation"))
AggeHealBotSettings.rightClickMenu:SetChecked(false)
AggeHealBotSettings.rightClickMenu.scripts.OnClick(AggeHealBotSettings.rightClickMenu)
local savedMenuAPI = Menu
Menu = nil
for _, frame in ipairs({PlayerFrame, normalParty, CompactRaidFrame1, targetButton}) do
    if frame == PlayerFrame or frame == targetButton then
    assert(frame.attrs.type2 == "click" and frame.attrs.spell2 == nil and frame.attrs.macrotext2 == nil,
        "right-click override must replace the spell action on player/target frames")
    assert(not drivers[frame].type2, "menu override must remove a prior spell/range driver")
    local owner = frame == targetButton and TargetFrame or frame
    local originalMenu = owner:GetAttribute("menu-function")
    owner:SetAttribute("menu-function", function(menuFrame)
        error("menu binding must not invoke addon Lua to build a native menu")
    end)
    mouseEdge(frame, "RightButton", true)
    mouseEdge(frame, "RightButton", false)
    assert(menuUnit == (frame == targetButton and "target" or "player"), "right-click menu uses the delegate's explicit unit")
    owner:SetAttribute("menu-function", originalMenu)
    else
        assert(frame.attrs.type2 == "macro" and frame.attrs.spell2 == "Rejuvenation" and frame.attrs.clickbutton2 == nil,
            "party and raid frames must retain their assigned right-click spell even with the menu override enabled")
    end
end
Menu = savedMenuAPI
manager:CloseMenus()
assert(PlayerFrame.attrs["ctrl-spell2"] == "Abolish Poison", "right-click override must preserve modifier spell bindings")
normalParty.scripts.OnEnter(normalParty)
local advertisesMenu = false
for _, line in ipairs(AggeHealBotTooltip.lines) do if line == "RightUnit menu" then advertisesMenu = true end end
assert(not advertisesMenu, "party tooltip must advertise its spell rather than the player/target menu override")
normalParty.scripts.OnLeave(normalParty)
combat = true
ns.SetOption("rightClickMenu", false)
assert(PlayerFrame.attrs.type2 == "click", "changing the override in combat must defer protected writes")
combat = false
event("PLAYER_REGEN_ENABLED")
for _, frame in ipairs({PlayerFrame, normalParty, CompactRaidFrame1, targetButton}) do
    assert(frame.attrs.type2 == "macro" and frame.attrs.spell2 == "Rejuvenation" and frame.attrs.clickbutton2 == nil,
        "turning off the menu override must restore the saved right-click spell")
end
event("ADDON_LOADED", "AggeHealBot")
assert(AggeHealBotDB.rightClickMenu == false, "saved right-click override opt-out must persist")
print("PASS: optional right-click menu override, all supported frames, saved spells, modifiers, tooltip accuracy and combat deferral")

local deadUnits, incoming = {}, {}
local normalResLearned = false
local oldBookItem = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
    if slot == 5 and not normalResLearned then return nil end
    return oldBookItem(slot, bank)
end
known[50769] = nil
UnitIsDeadOrGhost = function(unit) return deadUnits[unit] == true end
UnitIsPlayer = function() return true end
UnitHasIncomingResurrection = function(unit) return incoming[unit] == true end
known[20484], spellNames[20484] = "Rebirth", "Rebirth"
assert(AggeHealBotDB.combatResurrection == false and AggeHealBotDB.cureWatch == true)
deadUnits.target = true
event("SPELLS_CHANGED")
assert(not targetButton.regions[2].shown and not targetButton.attrs.macrotext1:find("Rebirth", 1, true), "reagent resurrection must not be selected by default")
known[50769], spellNames[50769] = "Revive", "Revive"
normalResLearned = true
event("SPELLS_CHANGED")
assert(targetButton.attrs.spell1 == "Revive" and targetButton.regions[2].shown, "dead friendly target gets reagent-free resurrection priority")
assert(targetButton.attrs.macrotext1:find("[nocombat,@target,help,dead] Revive", 1, true), "resurrection must use a dead-target condition")
assert(not targetButton.attrs.macrotext1:find("help,nodead] Revive", 1, true), "resurrection must never be attempted on a living target")
assert(not targetButton.attrs.macrotext1:find("Rebirth", 1, true))
local resColor = targetButton.regions[3].color
assert(resColor[1] == 0.65 and resColor[3] == 1, "resurrection uses its special pale-blue glow")
incoming.target = true
event("INCOMING_RESURRECT_CHANGED", "target")
assert(not targetButton.regions[2].shown and not targetButton.attrs.macrotext1:find("help,dead] Revive", 1, true), "incoming resurrection must suppress duplicate offers")
incoming.target = false
ranges.target = false
event("UNIT_AURA", "target")
assert(targetButton.attrs.type1 == "none" and not targetButton.regions[2].shown, "out-of-range resurrection must be blocked")
ranges.target = true
deadUnits.target = false
event("UNIT_HEALTH", "target")
assert(targetButton.attrs.spell1 == "Mark", "living target returns to missing buffs")
ns.SetOption("combatResurrection", true)
assert(targetButton.attrs.macrotext1:find("[combat,@target,help,dead,party] Rebirth", 1, true), "combat resurrection must require explicit opt-in and a group member")
assert(drivers[targetButton]["ahb-resurrection"]:find("dead", 1, true), "combat glow must be driven by secure dead-unit conditions")
combat = true
event("PLAYER_REGEN_DISABLED")
targetButton.scripts.OnAttributeChanged(targetButton, "ahb-resurrection", "combat")
assert(targetButton.regions[2].shown and targetButton.regions[2].texture == 120484, "secure combat-resurrection state must show its spell icon")
targetButton.scripts.OnAttributeChanged(targetButton, "ahb-resurrection", "none")
assert(not targetButton.regions[2].shown, "combat resurrection glow must clear when the secure condition clears")
combat = false
event("PLAYER_REGEN_ENABLED")
ns.SetOption("combatResurrection", false)
assert(not targetButton.attrs.macrotext1:find("Rebirth", 1, true) and not drivers[targetButton]["ahb-resurrection"])

local harmful = {}
local normalAuraGetter = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    if filter == "HARMFUL" then return harmful[unit] and harmful[unit][index] end
    return normalAuraGetter(unit, index, filter)
end
harmful.target = {{name = "Hex", dispelName = "Curse"}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Remove Curse", "a learned matching cure takes priority over missing buffs")
assert(targetButton.regions[3].color[1] == 1 and targetButton.regions[3].color[2] == 0.3, "cure watch uses its special red glow")
targetButton.scripts.OnEnter(targetButton)
local sawDebuff = false
for _, line in ipairs(AggeHealBotTooltip.lines) do if line == "Hex" then sawDebuff = true end end
assert(sawDebuff, "tooltip identifies the debuff being cured")
harmful.target = {{name = "Venom", dispelName = "Poison"}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Abolish Poison", "poison must select a learned poison cure")
harmful.target = {{name = "Fever", dispelName = "Disease"}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Mark", "uncurable debuffs must not replace the heal/buff binding")
harmful.target = {{name = "Hex", dispelName = "Curse"}}
deadUnits.target = true
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Revive", "resurrection must take priority over a debuff")
deadUnits.target = false
ns.SetOption("cureWatch", false)
assert(targetButton.attrs.spell1 == "Mark", "cure-watch opt-out must preserve normal buff priority")
ns.SetOption("cureWatch", true)
assert(targetButton.attrs.spell1 == "Remove Curse")
C_Secrets = {ShouldAurasBeSecret = function() return true end}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Regrowth" and not targetButton.regions[2].shown, "restricted aura data must never select a cure or buff")
C_Secrets = nil
harmful.target = {}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Mark", "cleared debuff returns to normal priority")
print("PASS: reagent-free resurrection, incoming resurrection, range, secure combat opt-in, learned matching cures, priority, colors and aura restrictions")

assert(AggeHealBotDB.watchNPCs == nil, "NPC watch setting must be removed")
local npcUnits = {target = true, party1 = true}
UnitIsPlayer = function(unit) return not npcUnits[unit] end
local npcAuraReads = 0
local filteredAuraGetter = C_UnitAuras.GetAuraDataByIndex
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    if npcUnits[unit] then npcAuraReads = npcAuraReads + 1 end
    return filteredAuraGetter(unit, index, filter)
end
harmful.target, harmful.party1 = {{name = "Hex", dispelName = "Curse"}}, {{name = "Hex", dispelName = "Curse"}}
event("UNIT_AURA", "target")
for _, frame in ipairs({targetButton, normalParty}) do
    assert(frame.attrs.spell1 == "Regrowth" and frame.attrs.type1 == "macro", "friendly NPCs retain normal healing bindings")
    assert(not frame.regions[2].shown, "NPCs must not get cure/buff indicators by default")
end
assert(npcAuraReads == 0, "player-only scope must skip NPC aura scans altogether")
deadUnits.target = true
event("UNIT_HEALTH", "target")
assert(not targetButton.regions[2].shown and not targetButton.attrs.macrotext1:find("Revive", 1, true), "NPCs must not get automatic resurrection by default")
AggeHealBotDB.watchNPCs = true -- Obsolete saved options must not enable NPC watches.
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Regrowth" and not targetButton.regions[2].shown, "obsolete NPC opt-in must not enable automatic watches")
ns.ShowOptions()
assert(AggeHealBotSettings.npcs == nil, "NPC watch checkbox must be removed")
local previousIsSecret = issecretvalue
local hiddenIdentity = {}
issecretvalue = function(value) return value == hiddenIdentity end
UnitIsPlayer = function(unit) return unit == "target" and hiddenIdentity or true end
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Regrowth" and not targetButton.regions[2].shown, "unknown player identity must not enable automatic watching")
issecretvalue = previousIsSecret
event("ADDON_LOADED", "AggeHealBot")
assert(AggeHealBotDB.watchNPCs == nil, "obsolete NPC settings must be cleaned up")
print("PASS: player-only watch defaults, no NPC scans, retained NPC healing, removed NPC opt-in and restricted identities")

UnitIsPlayer = function() return true end
deadUnits.target = false
harmful.target = {{name = "Hex", dispelName = "Curse"}}
event("UNIT_AURA", "target")
assert(AggeHealBotDB.combatCures == true, "combat cure alerts must default on")
ns.SetOption("combatCures", false)
local combatCureMacro = targetButton.attrs.macrotext1
combat = true
event("PLAYER_REGEN_DISABLED")
assert(not targetButton.regions[2].shown, "disabled combat cure alerts must stay hidden")
AggeHealBotSettings.combatCures:SetChecked(true)
AggeHealBotSettings.combatCures.scripts.OnClick(AggeHealBotSettings.combatCures)
assert(targetButton.regions[2].shown and targetButton.regions[3].color[1] == 1, "combat cure opt-in shows a readable matching cure alert")
assert(targetButton.attrs.macrotext1 == combatCureMacro, "combat cure alerts must not change protected cast macros")
targetButton.scripts.OnEnter(targetButton)
local sawCombatBinding = false
for _, line in ipairs(AggeHealBotTooltip.lines) do if line == "Cast with Ctrl + Left" then sawCombatBinding = true end end
assert(sawCombatBinding, "combat cure tooltip must show the actual cure keybind")
shiftHeld = true
event("MODIFIER_STATE_CHANGED")
assert(not targetButton.regions[2].shown, "modifier keys suppress the combat watch icon")
shiftHeld = false
event("MODIFIER_STATE_CHANGED")
assert(targetButton.regions[2].shown)
local restrictedCombatReads = 0
local combatAuraGetter = C_UnitAuras.GetAuraDataByIndex
C_Secrets = {ShouldAurasBeSecret = function() return true end}
C_UnitAuras.GetAuraDataByIndex = function(...)
    restrictedCombatReads = restrictedCombatReads + 1
    return combatAuraGetter(...)
end
event("UNIT_AURA", "target")
assert(not targetButton.regions[2].shown and restrictedCombatReads == 0, "combat cure watching must never read restricted auras")
C_Secrets = nil
event("UNIT_AURA", "target")
assert(targetButton.regions[2].shown, "readable combat alerts must recover")
UnitIsPlayer = function(unit) return unit ~= "target" end
event("UNIT_AURA", "target")
assert(not targetButton.regions[2].shown, "combat cure alerts must also exclude NPCs")
UnitIsPlayer = function() return true end
ns.SetOption("combatCures", false)
assert(not targetButton.regions[2].shown and targetButton.attrs.macrotext1 == combatCureMacro)
combat = false
event("PLAYER_REGEN_ENABLED")
print("PASS: default-on combat cure alerts, readable aura controls, existing binding hints, restricted data, NPC exclusion and protected macro preservation")

PlayerFrame.healthbar = CreateFrame("StatusBar")
PlayerFrame.manabar = CreateFrame("StatusBar")
event("GROUP_ROSTER_UPDATE")
local healthRegion, manaRegion = PlayerFrame.healthbar, PlayerFrame.manabar
GameTooltip:SetOwner(healthRegion, "ANCHOR_RIGHT")
GameTooltip:SetText("Health")
healthRegion.scripts.OnEnter(healthRegion)
assert(AggeHealBotTooltip.shown and GameTooltip.lines[1] == "Health", "health hover must show addon information while preserving the resource tooltip")
PlayerFrame.scripts.OnLeave(PlayerFrame)
assert(AggeHealBotTooltip.shown, "a late parent leave must not hide a child hover tooltip")
GameTooltip:SetOwner(manaRegion, "ANCHOR_RIGHT")
GameTooltip:SetText("Mana")
manaRegion.scripts.OnEnter(manaRegion)
healthRegion.scripts.OnLeave(healthRegion)
assert(AggeHealBotTooltip.shown and GameTooltip.lines[1] == "Mana", "moving between bars must preserve the active tooltip")
mouseEdge(PlayerFrame, "Button4", true)
assert(currentMenu and not AggeHealBotTooltip.shown, "opening the unit menu must hide the addon tooltip immediately")
event("UNIT_AURA", "player")
healthRegion.scripts.OnEnter(healthRegion)
assert(not AggeHealBotTooltip.shown, "menu-open aura refreshes and child hover must not reopen the addon tooltip")
manager:CloseMenus()
healthRegion.scripts.OnEnter(healthRegion)
assert(AggeHealBotTooltip.shown, "hovering after the menu closes restores the addon tooltip")
healthRegion.scripts.OnLeave(healthRegion)
assert(not AggeHealBotTooltip.shown)

local savedRightBinding = AggeHealBotDB.bindings["2"]
ns.SetOption("smartBuffs", false)
ns.SetOption("cureWatch", false)
ns.SetOption("combatCures", false)
ns.SetOption("combatResurrection", true)
ns.SetOption("rightClickMenu", true)
ns.SetOption("targetFrame", false)
ns.SetOption("hideRaidControls", false)
AggeHealBotSettings.resetSettings.scripts.OnClick(AggeHealBotSettings.resetSettings)
assert(AggeHealBotDB.smartBuffs and AggeHealBotDB.cureWatch and AggeHealBotDB.targetFrame)
assert(AggeHealBotDB.playerFrame and AggeHealBotDB.combatCures and AggeHealBotDB.hideRaidControls
    and not AggeHealBotDB.combatResurrection and not AggeHealBotDB.rightClickMenu, "reset button must restore all toggle defaults")
assert(AggeHealBotDB.bindings["2"] == savedRightBinding and targetButton.attrs.spell2 == "Rejuvenation", "reset settings must preserve saved spell bindings")
assert(AggeHealBotSettings.buffs:GetChecked() and AggeHealBotSettings.rightClickMenu:GetChecked(), "reset must refresh checkbox states, including the inverted right-click override")
ns.SetOption("targetFrame", false)
combat = true
ns.ResetOptions()
assert(not targetButton.shown, "reset during combat must defer secure target enabling")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(targetButton.shown and AggeHealBotDB.targetFrame, "queued reset must apply secure changes after combat")
print("PASS: resource-bar hover, native resource tooltip preservation, menu suppression, reset toggle defaults, saved bindings and combat deferral")

AggeHealBotSettings.cures:SetChecked(false)
AggeHealBotSettings.cures.scripts.OnClick(AggeHealBotSettings.cures)
assert(not AggeHealBotSettings.combatCures.enabled and AggeHealBotSettings.combatCures.alpha < 1,
    "combat cure control must be disabled and dimmed when Cure watcher is off")
assert(AggeHealBotDB.combatCures, "disabling the parent should preserve the combat cure preference")
AggeHealBotSettings.cures:SetChecked(true)
AggeHealBotSettings.cures.scripts.OnClick(AggeHealBotSettings.cures)
assert(AggeHealBotSettings.combatCures.enabled and AggeHealBotSettings.combatCures.alpha == 1
    and AggeHealBotSettings.combatCures:GetChecked(), "enabling Cure watcher restores the combat control and its saved choice")

-- Forever uses its own ranked Revive IDs, rather than the older 50769 spell.
spellNames[437138], spellNames[1237948] = "Forever Revive", "Forever Revive"
known[50769], known[1237948] = nil, "Forever Revive"
local rankedBookItem = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
    if slot == 5 then return {spellID = 1237948} end
    return rankedBookItem(slot, bank)
end
event("SPELLS_CHANGED")
local foundForeverRevive, foundRebirth = false, false
for _, choice in ipairs(ns.GetSpellChoices()) do
    if choice.label == "Forever Revive" then foundForeverRevive = choice.category == "utility" end
    if choice.label == "Rebirth" then foundRebirth = choice.category == "utility" end
end
assert(foundForeverRevive and foundRebirth, "Forever Revive and Rebirth must both be listed as Utility")
deadUnits.target = true
event("UNIT_HEALTH", "target")
assert(targetButton.attrs.spell1 == "Forever Revive", "resurrection watch must recognize the learned Forever rank without the old spell ID")
print("PASS: scoped player/target right-click menus and Forever-ranked Revive in Utility and resurrection watching")

-- Exercise actual class selection and watch priority with only the highest
-- resurrection rank available, rather than assuming a base-ID lookup succeeds.
AggeHealBotDB.bindings = {}
AggeHealBotDB.smartBuffs = false
local cases = {
    {class = "PRIEST", healID = 2061, heal = "Flash Heal", resID = 20770, res = "Resurrection", cureID = 527, cure = "Dispel Magic", kind = "Magic"},
    {class = "PALADIN", healID = 19750, heal = "Flash of Light", resID = 20773, res = "Redemption", cureID = 4987, cure = "Cleanse", kind = "Poison"},
    {class = "SHAMAN", healID = 331, heal = "Healing Wave", resID = 20777, res = "Ancestral Spirit", cureID = 526, cure = "Cure Poison", kind = "Poison"},
}
for _, case in ipairs(cases) do
    UnitClass = function() return case.class, case.class end
    for _, pair in ipairs({{case.healID, case.heal}, {case.resID, case.res}, {case.cureID, case.cure}}) do
        spellNames[pair[1]], known[pair[1]] = pair[2], pair[2]
    end
    C_SpellBook.GetSpellBookItemInfo = function(slot)
        return ({ {spellID = case.healID}, {spellID = case.resID}, {spellID = case.cureID} })[slot]
    end
    harmful.target = {}
    deadUnits.target = true
    event("PLAYER_LOGIN")
    assert(targetButton.attrs.spell1 == case.res, case.class .. " must recognize the learned high-rank resurrection")
    deadUnits.target = false
    harmful.target = {{name = "Test debuff", dispelName = case.kind}}
    event("UNIT_AURA", "target")
    assert(targetButton.attrs.spell1 == case.cure, case.class .. " must select its learned matching cure")
    if case.class == "PRIEST" then
        harmful.target = {{name = "Fever", dispelName = "Disease"}}
        event("UNIT_AURA", "target")
        assert(targetButton.attrs.spell1 == case.heal, "Dispel Magic cannot cure Disease")
        spellNames[528], known[528] = "Cure Disease", "Cure Disease"
        event("SPELLS_CHANGED")
        assert(targetButton.attrs.spell1 == "Cure Disease", "Disease must select Cure Disease instead of Dispel Magic")
    end
end
print("PASS: priest, paladin and shaman high-rank resurrection and matching cures; priest Magic/Disease separation")

for _, id in ipairs({1238214, 1238215, 402174, 1240720, 1240721, 1316995, 1240826, 1240827, 1239242, 1239243, 1311590, 1311595}) do
    spellNames[id], known[id] = "Forever healing spell " .. id, "Forever healing spell " .. id
end
event("SPELLS_CHANGED")
local classified = {}
for _, choice in ipairs(ns.GetSpellChoices()) do classified[choice.label] = choice.category end
for _, id in ipairs({1238214, 1238215, 402174, 1240720, 1240721, 1316995, 1240826, 1240827, 1239242, 1239243, 1311590, 1311595}) do
    assert(classified[spellNames[id]] == "heals", "Forever healing ID must be categorized without an older same-name lookup: " .. id)
end
print("PASS: distinct Forever healing spell/rank IDs retain Healing classification without legacy ID resolution")

-- Every watched buff family must offer a real rank upgrade and suppress
-- equal/stronger single-target and equivalent group versions.
deadUnits.target = false
harmful.target = {}
AggeHealBotDB.smartBuffs = true
AggeHealBotDB.bindings = {}
for _, case in ipairs({
    {class = "DRUID", base = 1126, healID = 8936, heal = "Regrowth"},
    {class = "DRUID", base = 467, healID = 8936, heal = "Regrowth"},
    {class = "PRIEST", base = 1243, healID = 2061, heal = "Flash Heal"},
    {class = "PRIEST", base = 14752, healID = 2061, heal = "Flash Heal"},
    {class = "PRIEST", base = 976, healID = 2061, heal = "Flash Heal"},
}) do
    local definition = ns.buffRanks[case.base]
    local buffName = spellNames[case.base] or ("Ranked buff " .. case.base)
    local groupName = "Group buff " .. case.base
    -- Isolate this family from other known buffs and test fixtures.
    for base, family in pairs(ns.buffRanks) do
        for _, id in ipairs(family.ranks) do known[id] = nil end
        for id in pairs(family.equivalents or {}) do known[id] = nil end
    end
    for _, id in ipairs(definition.ranks) do spellNames[id] = buffName end
    for id in pairs(definition.equivalents or {}) do spellNames[id] = groupName end
    UnitClass = function() return case.class, case.class end
    local highestID = definition.ranks[#definition.ranks]
    known[highestID] = buffName
    C_SpellBook.GetSpellBookItemInfo = function(slot)
        if slot == 1 then return {spellID = case.healID} end
        if slot == 2 then return {spellID = highestID} end
    end
    auras.target = {{name = "Buff display name", spellId = definition.ranks[1]}}
    event("PLAYER_LOGIN")
    assert(targetButton.attrs.spell1 == buffName, "weaker buff must offer highest learned rank: " .. case.base)
    assert(targetButton.regions[2].shown and targetButton.regions[3].shown, "upgrade must display the icon and glow")
    auras.target = {{name = "Buff display name", spellId = highestID}}
    event("UNIT_AURA", "target")
    assert(targetButton.attrs.spell1 == case.heal, "equal rank must retain healing: " .. case.base)
    for id, rank in pairs(definition.equivalents or {}) do
        auras.target = {{name = "Group display name", spellId = id}}
        event("UNIT_AURA", "target")
        assert(targetButton.attrs.spell1 == (rank < #definition.ranks and buffName or case.heal), "group equivalent must compare strength: " .. id)
    end
    known[highestID] = nil
    known[definition.ranks[1]] = buffName
    highestID = definition.ranks[1]
    event("SPELLS_CHANGED")
    auras.target = {{name = "Buff display name", spellId = definition.ranks[#definition.ranks]}}
    event("UNIT_AURA", "target")
    assert(targetButton.attrs.spell1 == case.heal, "stronger buff must retain healing: " .. case.base)
    auras.target = {{name = buffName, spellId = 987654}}
    event("UNIT_AURA", "target")
    assert(targetButton.attrs.spell1 == case.heal, "unknown matching rank must not be assumed weaker: " .. case.base)
end
print("PASS: all five buff families offer weaker-rank upgrades with icon/glow, suppress equal/higher ranks and compare group equivalents")

-- Shared hints never use secret power/cooldown/health values or change casts.
local usable, lowPower, cooldownInfo = true, false, nil
C_Spell.IsSpellUsable = function() return usable, lowPower end
C_Spell.GetSpellCooldown = function(id) return id == 61304 and {startTime = 0, duration = 0} or cooldownInfo end
assert(ns.CastProblem("Regrowth", "target") == nil)
lowPower = true
assert(ns.CastProblem("Regrowth", "target") == "Not enough mana / power")
lowPower, usable = false, false
assert(ns.CastProblem("Regrowth", "target") == "Spell unavailable")
usable, cooldownInfo = true, {startTime = now - 2, duration = 10}
assert(ns.CastProblem("Regrowth", "target") == "On cooldown (8s)")
C_Spell.GetSpellCooldown = function() return {startTime = now - 1, duration = 2} end
assert(ns.CastProblem("Regrowth", "target") == nil, "the global cooldown must not dim every spell")
local hiddenValue = setmetatable({}, {__add = function() error("secret arithmetic") end, __mul = function() error("secret arithmetic") end})
issecretvalue = function(value) return value == hiddenValue end
C_Spell.IsSpellUsable = function() return hiddenValue, hiddenValue end
C_Spell.GetSpellCooldown = function() return {startTime = hiddenValue, duration = hiddenValue} end
assert(ns.CastProblem("Regrowth", "target") == nil)
local healthValue = 100
UnitHealth, UnitHealthMax = function() return healthValue end, function() return 100 end
healthValue = hiddenValue
assert(not ns.NeedsHealing("target"), "restricted health must never be compared")
combat = true
UnitHealth = function() error("must not read combat health") end
assert(not ns.NeedsHealing("target") and ns.CastProblem("Regrowth", "target") == nil)
combat = false
UnitHealth = function() return healthValue end
healthValue = 89
assert(ns.NeedsHealing("target"))
healthValue = 90
assert(not ns.NeedsHealing("target"), "90 percent is the stable boundary")
issecretvalue = function() return false end
C_Spell.IsSpellUsable = function() return usable, lowPower end
C_Spell.GetSpellCooldown = function() return nil end

-- Injured players get the assigned heal instead of a missing buff; cure and
-- resurrection priorities remain intact. The event handles both directions.
UnitClass = function() return "Druid", "DRUID" end
known[1126], known[8936], known[2782] = "Mark", "Regrowth", "Remove Curse"
spellNames[1126], spellNames[8936], spellNames[2782] = "Mark", "Regrowth", "Remove Curse"
C_SpellBook.GetSpellBookItemInfo = function(slot)
    return ({ {spellID = 8936}, {spellID = 1126}, {spellID = 2782} })[slot]
end
auras.target, harmful.target, healthValue = {}, {}, 100
event("PLAYER_LOGIN")
assert(targetButton.attrs.spell1 == "Mark")
healthValue = 89
event("UNIT_HEALTH", "target")
assert(targetButton.attrs.spell1 == "Regrowth" and not targetButton.regions[2].shown, "injury suppresses the buff override and glow")
targetButton.scripts.OnEnter(targetButton)
local function HasTip(text)
    for _, line in ipairs(AggeHealBotTooltip.lines) do if line:find(text, 1, true) then return true end end
end
assert(HasTip("Healing first: below 90% health."))
harmful.target = {{name = "Hex", dispelName = "Curse"}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Remove Curse", "cure priority is independent of missing-buff injury protection")
harmful.target, healthValue = {}, 90
event("UNIT_HEALTH", "target")
assert(targetButton.attrs.spell1 == "Mark", "recovering past the threshold restores buff priority")
local beforeMacro = targetButton.attrs.macrotext1
lowPower = true
event("SPELL_UPDATE_USABLE")
assert(targetButton.attrs.macrotext1 == beforeMacro and HasTip("Not enough mana / power"), "availability hints do not change the secure action")
assert(not targetButton.regions[3].shown, "unavailable buff stops the urgent glow")
lowPower = false
event("SPELL_UPDATE_USABLE")
assert(targetButton.regions[3].shown, "availability recovery restores the glow")
assert(cvars.autoSelfCast == "1" and targetButton.attrs.checkselfcast == false and PlayerFrame.attrs.checkselfcast == false)
assert(not targetButton.attrs.macrotext1:find("@player", 1, true), "explicit frame macros must not contain a self fallback")
print("PASS: public-only range/mana/cooldown hints, global cooldown exclusion, injured-player healing priority, and unchanged global Auto Self Cast")

-- Paladin watch selects exactly one blessing; overrides are per target class.
AggeHealBotDB.bindings = {}
local recipientClass = "WARRIOR"
UnitClass = function(unit) return unit == "player" and "Paladin" or recipientClass, unit == "player" and "PALADIN" or recipientClass end
UnitPowerType = function() error("blessing rules must not inspect druid forms or resource types") end
for id, name in pairs({[19750] = "Flash of Light", [19740] = "Might", [19834] = "Might", [19742] = "Wisdom", [20217] = "Kings", [4987] = "Cleanse", [25782] = "Greater Might"}) do
    spellNames[id], known[id] = name, name
end
known[25782] = nil
C_SpellBook.GetSpellBookItemInfo = function(slot)
    return ({ {spellID = 19750}, {spellID = 19834}, {spellID = 19742}, {spellID = 20217}, {spellID = 4987} })[slot]
end
healthValue, auras.target, harmful.target = 100, {}, {}
event("PLAYER_LOGIN")
assert(targetButton.attrs.spell1 == "Might", "warriors default to Might")
recipientClass = "PRIEST"
event("PLAYER_TARGET_CHANGED")
assert(targetButton.attrs.spell1 == "Wisdom", "mana classes default to Wisdom")
recipientClass = "DRUID"
event("PLAYER_TARGET_CHANGED")
assert(targetButton.attrs.spell1 == "Wisdom")
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Wisdom", "druid Auto must stay on Wisdom without inspecting form")
assert(ns.SetPaladinRule("DRUID", "kings") and targetButton.attrs.spell1 == "Kings")
assert(ns.SetPaladinRule("DRUID", "off") and targetButton.attrs.spell1 == "Flash of Light")
assert(not ns.SetPaladinRule("DRUID", "bogus") and not ns.SetPaladinRule("BOGUS", "might"))
assert(ns.SetPaladinRule("DRUID", "might") and targetButton.attrs.spell1 == "Might", "users can explicitly choose Might for druids")
auras.target = {{name = "Old Might", spellId = 19740}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Might", "weaker blessing must offer an upgrade")
auras.target = {{name = "Greater Might", spellId = 25782}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Flash of Light", "a stronger greater blessing satisfies the watch")
auras.target = {{name = "Might", spellId = 19834}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Flash of Light", "a satisfied blessing must not cycle to Wisdom or Kings")
auras.target = {}
healthValue = 20
event("UNIT_HEALTH", "target")
assert(targetButton.attrs.spell1 == "Flash of Light")
harmful.target = {{name = "Venom", dispelName = "Poison"}}
event("UNIT_AURA", "target")
assert(targetButton.attrs.spell1 == "Cleanse")
RAID_CLASS_COLORS = {WARRIOR = {r = 0.78, g = 0.61, b = 0.43}}
ns.ShowOptions()
assert(AggeHealBotSettings.blessings.shown)
AggeHealBotSettings.blessings.scripts.OnClick()
assert(AggeHealBotTools.rows[1].class == "WARRIOR")
AggeHealBotTools.rows[1].dropdown.menuOptions.might.choose()
assert(ns.GetPaladinRule("WARRIOR") == "might")
AggeHealBotTools.defaults.scripts.OnClick()
assert(ns.GetPaladinRule("WARRIOR") == "auto")
combat = true
local protectedBeforeRule = targetButton.attrs.macrotext1
assert(ns.SetPaladinRule("DRUID", "kings") and targetButton.attrs.macrotext1 == protectedBeforeRule)
combat = false
harmful.target, healthValue = {}, 100
event("PLAYER_REGEN_ENABLED")
assert(targetButton.attrs.spell1 == "Kings", "combat rule edits must apply after combat")
ns.ResetOptions()
assert(ns.GetPaladinRule("DRUID") == "auto", "Reset settings restores suggested blessing rules")
print("PASS: paladin class suggestions, Wisdom for druids without form inspection, per-class overrides, rank upgrades, greater equivalents, injury/cure priority, settings and combat deferral")

-- Modifier defaults are ordinary bindings on every supported frame. A saved
-- spell/disabled action must win over a menu shortcut, including on portraits.
ns.ResetBindings()
for _, frame in ipairs({PlayerFrame, targetButton, normalParty, CompactRaidFrame1}) do
    assert(frame.attrs["shift-type1"] == "macro" and frame.attrs["shift-clickbutton1"] == nil)
    local expectedUnit = frame == PlayerFrame and "player" or frame == targetButton and "target" or frame:GetAttribute("unit") or frame.unit
    assert(frame.attrs["shift-macrotext1"] == "/target [@" .. expectedUnit .. ",exists]", "target binding must bypass the native interaction filter without a fallback")
    assert(frame.attrs["shift-type3"] == "click" and frame.attrs["shift-clickbutton3"] == ns.settingsButton)
    assert(frame.attrs["shift-type2"] == "click" and frame.attrs["shift-clickbutton2"] == frame.attrs.clickbutton4,
        "Shift-right must use the same unit context-menu delegate as Button 4")
end
local oldPartyRange = ranges.party1
ranges.party1 = false
normalParty.scripts.PreClick(normalParty, "LeftButton")
assert(normalParty.attrs["shift-type1"] == "macro"
    and normalParty.attrs["shift-macrotext1"] == "/target [@party1,exists]",
    "out-of-range party targeting must use the frame unit, without relying on mouseover or the healing range driver")
normalParty:SetAttribute("unit", "party2")
normalParty.scripts.PreClick(normalParty, "LeftButton")
assert(normalParty.attrs["shift-macrotext1"] == "/target [@party2,exists]", "target binding must follow a reassigned party frame")
normalParty:SetAttribute("unit", "party1")
ranges.party1 = oldPartyRange
normalParty.scripts.PreClick(normalParty, "LeftButton")
assert(ns.SaveBinding("shift-", 1, "none"))
assert(ns.SaveBinding("shift-", 2, "spell", "Flash of Light"))
assert(ns.SaveBinding("shift-", 3, "none"))
for _, frame in ipairs({PlayerFrame, targetButton, normalParty, CompactRaidFrame1}) do
    assert(frame.attrs["shift-type1"] == "none")
    assert(frame.attrs["shift-type2"] == "macro" and frame.attrs["shift-clickbutton2"] == nil)
    assert(frame.attrs["shift-macrotext2"]:find("Flash of Light", 1, true))
end
shiftHeld = true
targetButton.scripts.OnEnter(targetButton)
assert(not HasTip("Click to open AggeHealBot Menu."), "rebound settings shortcut must not leave a misleading hover hint")
assert(HasTip("Shift + RightFlash of Light"), "modifier hover must show the user's saved spell")
ns.SaveBinding("shift-", 1, "default")
ns.SaveBinding("shift-", 2, "default")
ns.SaveBinding("shift-", 3, "default")
event("MODIFIER_STATE_CHANGED")
assert(HasTip("Shift + Middle Click to open AggeHealBot Menu."))
assert(HasTip("Shift + LeftTarget unit"))
shiftHeld = false

-- Resource/cooldown events must not turn into full party/raid aura rescans.
local countedAuraGetter, hintAuraReads = C_UnitAuras.GetAuraDataByIndex, 0
C_UnitAuras.GetAuraDataByIndex = function(...)
    hintAuraReads = hintAuraReads + 1
    return countedAuraGetter(...)
end
local stableMacro = targetButton.attrs.macrotext1
event("UNIT_POWER_UPDATE", "player")
event("SPELL_UPDATE_USABLE")
event("SPELL_UPDATE_COOLDOWN")
assert(hintAuraReads == 0 and stableMacro == targetButton.attrs.macrotext1, "hint refresh must not scan auras or change protected macros")
C_UnitAuras.GetAuraDataByIndex = countedAuraGetter
assert(cvars.autoSelfCast == "1", "reloads, rebinds and combat transitions must preserve global Auto Self Cast")
print("PASS: editable Shift-left target and Shift-middle settings defaults on all frames, modifier tooltip overrides, and lightweight resource/cooldown refreshes")

-- Blessing choices are real dropdowns, not row clicks or mouse-wheel cycles.
ns.ShowOptions()
AggeHealBotSettings.blessings.scripts.OnClick()
assert(AggeHealBotTools.shown and not AggeHealBotSpellPicker.shown)
local warrior = AggeHealBotTools.rows[1]
assert(warrior.dropdown.template == "WowStyle1DropdownTemplate" and warrior.scripts.OnClick == nil)
assert(warrior.icon.texture == "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
assert(warrior.label.textColor[1] == 0.78 and warrior.label.textColor[2] == 0.61 and warrior.label.textColor[3] == 0.43,
    "class names must use their class color")
assert(warrior.label.point[2] == 42 and warrior.dropdown.point[2] == 174, "class label and dropdown use separate padded columns")
assert(AggeHealBotTools.back.point[3] == AggeHealBotTools.defaults.point[3], "footer buttons share one row")
local paneTop = -AggeHealBotTools.point[3]
local backBottom = paneTop - AggeHealBotTools.back.point[3] + AggeHealBotTools.back.height
assert(-AggeHealBotSettings.done.point[3] - backBottom >= 24, "Back to bindings has a clear gap above Done")
local previousRule = ns.GetPaladinRule("WARRIOR")
warrior.dropdown:GenerateMenu()
assert(ns.GetPaladinRule("WARRIOR") == previousRule, "opening a dropdown must not change the blessing")
for _, rule in ipairs({"auto", "might", "wisdom", "kings", "off"}) do assert(warrior.dropdown.menuOptions[rule]) end
warrior.dropdown.menuOptions.wisdom.choose()
assert(ns.GetPaladinRule("WARRIOR") == "wisdom" and warrior.dropdown.selectedText == "Wisdom")
AggeHealBotTools.defaults.scripts.OnClick()
assert(warrior.dropdown.selectedText == "Auto: Might", "reset refreshes dropdown selection labels")
warrior.dropdown.menuOpen = true
AggeHealBotSettings.blessings.scripts.OnClick()
assert(AggeHealBotSpellPicker.shown and not AggeHealBotTools.shown and not warrior.dropdown.menuOpen,
    "clicking Paladin blessings again returns to bindings and closes open dropdowns")
print("PASS: native blessing dropdown choices, padded class/icon columns, separated footer and pane toggle")

-- Advance binding is optional, support-only, and restricted to this class.
spellNames[635], spellNames[20271], spellNames[465] = "Holy Light", "Judgement", "Passive test aura"
known[635], known[20271], known[465] = nil, nil, nil
C_Spell.IsSpellPassive = function(id) return id == 465 end
local function FindChoice(spell, includeUnlearned)
    for _, choice in ipairs(ns.GetSpellChoices(includeUnlearned)) do if choice.spell == spell then return choice end end
end
assert(not AggeHealBotDB.showUnlearned and not FindChoice("Holy Light", false))
assert(not ns.SaveBinding("alt-", 1, "spell", "Holy Light"), "unlearned binding requires explicit opt-in")
local futureHolyLight = FindChoice("Holy Light", true)
assert(futureHolyLight and futureHolyLight.unlearned and futureHolyLight.category == "heals")
assert(not FindChoice("Judgement", true) and not FindChoice("Passive test aura", true), "unlearned catalogue must not add attacks or passives")
spellNames[402174], known[402174] = "Foreign Penance", nil
assert(not FindChoice("Foreign Penance", true), "other classes' unlearned spells must not be shown")
local spellPicker = AggeHealBotSpellPicker
AggeHealBotSettings.tabs[4].scripts.OnClick()
AggeHealBotSettings.rows[1].button.scripts.OnClick()
spellPicker.showUnlearned:SetChecked(true)
spellPicker.showUnlearned.scripts.OnClick(spellPicker.showUnlearned)
spellPicker.search:SetText("Holy Light")
assert(spellPicker.rows[1].choice.unlearned and spellPicker.rows[1].alpha < 1)
spellPicker.rows[1].scripts.OnEnter(spellPicker.rows[1])
assert(GameTooltip.shown and GameTooltip.lines[2] == "Not learned yet")
spellPicker.rows[1].scripts.OnLeave(spellPicker.rows[1])
assert(not GameTooltip.shown)
spellPicker.rows[1].scripts.OnClick(spellPicker.rows[1])
assert(AggeHealBotDB.bindings["alt-1"].spell == "Holy Light", "unlearned rows must be selectable through the normal binding editor")
assert(AggeHealBotSettings.rows[1].button.label.text:find("(unlearned)", 1, true), "the assigned binding must also explain its unlearned status")
assert(PlayerFrame.attrs["alt-type1"] == "none" and PlayerFrame.attrs["alt-macrotext1"] == nil,
    "unlearned spells must have no executable cast")
spellPicker.showUnlearned:SetChecked(false)
spellPicker.showUnlearned.scripts.OnClick(spellPicker.showUnlearned)
assert(AggeHealBotDB.bindings["alt-1"].spell == "Holy Light", "hiding unlearned spells must not erase planned bindings")
-- The live book may expose a future rank before it is learned.
Enum.SpellBookItemType = {FutureSpell = 4, Spell = 1}
local bookBeforeFuture = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
    if slot == 5 then return {spellID = 635, itemType = Enum.SpellBookItemType.FutureSpell} end
    return bookBeforeFuture(slot, bank)
end
event("SPELLS_CHANGED")
assert(not FindChoice("Holy Light", false) and PlayerFrame.attrs["alt-type1"] == "none", "future book entries do not count as learned")
-- Training a different rank with the same name activates the saved binding.
spellNames[639], known[639] = "Holy Light", "Holy Light"
C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
    if slot == 5 then return {spellID = 639, itemType = Enum.SpellBookItemType.Spell} end
    return bookBeforeFuture(slot, bank)
end
event("SPELLS_CHANGED")
assert(PlayerFrame.attrs["alt-type1"] == "macro" and PlayerFrame.attrs["alt-spell1"] == "Holy Light")
assert(FindChoice("Holy Light", false) and not FindChoice("Holy Light", false).unlearned)
AggeHealBotSettings.scripts.OnEvent(AggeHealBotSettings, "SPELLS_CHANGED")
assert(spellPicker.rows[1].choice.spell == "Holy Light" and spellPicker.rows[1].alpha == 1,
    "training must restore learned-row opacity")
assert(not AggeHealBotSettings.rows[1].button.label.text:find("(unlearned)", 1, true), "training must clear the assigned binding's unlearned label")
ns.SetOption("showUnlearned", true)
ns.ResetOptions()
assert(not AggeHealBotDB.showUnlearned, "reset restores Show unlearned to off")
print("PASS: optional support-only unlearned catalogue, dimmed rows and hover help, inactive planned bindings, future book handling and automatic activation on training")

-- A missing first candidate must not hide a real fallback spell name. If all
-- candidates are absent from this client, there is no spell to call unlearned.
spellNames[991101] = "Named fallback heal"
ns.presets.PALADIN[#ns.presets.PALADIN + 1] = {"Ctrl + Shift + Middle", "ctrl-shift-", 3, {991100, 991101}}
ns.presets.PALADIN[#ns.presets.PALADIN + 1] = {"Alt + Shift + Middle", "alt-shift-", 3, {991102}}
event("SPELLS_CHANGED")
ns.ShowOptions()
assert(AggeHealBotSpellPicker.filter == "suggested", "reopening the editor restores Suggested")
AggeHealBotSettings.tabs[5].scripts.OnClick()
assert(AggeHealBotSettings.rows[3].button.label.text:find("Named fallback heal", 1, true), "a valid fallback name replaces the generic Spell placeholder")
assert(AggeHealBotSettings.rows[3].button.label.text:find("(unlearned)", 1, true))
AggeHealBotSettings.tabs[6].scripts.OnClick()
assert(AggeHealBotSettings.rows[3].button.label.text == "Disabled", "a preset with no resolvable identity must show Disabled")
assert(PlayerFrame.attrs["alt-shift-type3"] == "none")
print("PASS: preset fallback names and disabled unavailable spell identities without generic Spell placeholders")

-- Learned Other spells must precede unlearned heals, across every page.
spellNames[991103], spellNames[991104] = "Known other skill", "Unlearned test heal"
known[991103], known[991104] = "Known other skill", nil
ns.spellCategories.heals[#ns.spellCategories.heals + 1] = 991104
ns.classSpells.PALADIN[#ns.classSpells.PALADIN + 1] = 991104
local bookBeforeSorting = C_SpellBook.GetSpellBookItemInfo
C_SpellBook.GetSpellBookItemInfo = function(slot, bank)
    if slot == 4 then return {spellID = 991103} end
    return bookBeforeSorting(slot, bank)
end
event("SPELLS_CHANGED")
local seenFuture, learnedOtherIndex, futureHealIndex = false, nil, nil
for index, item in ipairs(ns.GetSpellChoices(true)) do
    if item.unlearned then seenFuture = true else assert(not seenFuture, "no learned spell may follow an unlearned one") end
    if item.spell == "Known other skill" then learnedOtherIndex = index end
    if item.spell == "Unlearned test heal" then futureHealIndex = index end
end
assert(learnedOtherIndex and futureHealIndex and learnedOtherIndex < futureHealIndex)
ns.ShowOptions()
AggeHealBotSpellPicker.showUnlearned:SetChecked(true)
AggeHealBotSpellPicker.showUnlearned.scripts.OnClick(AggeHealBotSpellPicker.showUnlearned)
AggeHealBotSpellPicker.tabs[6].scripts.OnClick(AggeHealBotSpellPicker.tabs[6])
seenFuture = false
for page = 1, AggeHealBotSpellPicker.pages do
    AggeHealBotSpellPicker.page = page
    AggeHealBotSpellPicker:Render()
    for _, row in ipairs(AggeHealBotSpellPicker.rows) do
        if row.choice then
            if row.choice.unlearned then seenFuture = true
            else assert(not seenFuture, "All must put learned spells and available actions before unlearned spells") end
        end
    end
end
assert(seenFuture)
print("PASS: learned-first ordering across categories and pages, with available actions before unlearned spells in All")

-- Every physical region selects its real button number without changing the
-- binding. Modifier tabs operate on the same selected mouse button.
ns.ShowOptions()
local mouse = AggeHealBotSettings.mouse
assert(mouse.width == 315 and mouse.height == 264)
assert(mouse.body.texture == "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME"
    and mouse.body.texCoords[1] == 0.1542969 and mouse.body.texCoords[3] == 0.4257813,
    "neutral mouse must use the actual neutral tutorial sprite, not grey a selected button")
assert(mouse.buttons[1].overlay.texCoords[3] == 0.4257813)
assert(mouse.buttons[2].overlay.texCoords[3] == 0.6269531)
assert(mouse.buttons[3].overlay.texture == "Interface\\AddOns\\AggeHealBot\\Media\\MouseSideGlow",
    "Middle highlights only the wheel instead of replacing the whole mouse")
for index, button in ipairs(mouse.buttons) do
    assert(button.pulse.looping == "BOUNCE" and button.pulse.animation.duration == 0.8
        and button.pulse.animation.fromAlpha == 0 and button.pulse.animation.toAlpha == (index == 3 and 0.65 or 1)
        and button.pulse.animation.smoothing == "IN_OUT", "mouse click cues match the tutorial fade")
end
assert(mouse.buttons[4].point[2] >= mouse.art.point[2] and mouse.buttons[5].point[2] >= mouse.art.point[2],
    "side buttons must sit on the mouse shell rather than in external boxes")
assert(not mouse.buttons[1].icon.shown and not mouse.buttons[3].icon.shown,
    "spell icons must not cover the physical mouse controls")
for modifier, tab in ipairs(AggeHealBotSettings.tabs) do
    tab.scripts.OnClick(tab)
    for index, button in ipairs(mouse.buttons) do
        button.scripts.OnClick(button)
        assert(AggeHealBotSpellPicker.button == index and AggeHealBotSpellPicker.prefix == ns.modifiers[modifier].prefix)
        assert(mouse.captionTitle.text == ns.buttons[index])
        for other, region in ipairs(mouse.buttons) do
            assert(region.selected == (other == index), "only the selected physical button should glow")
            assert(region.overlay.alpha == (other == index and 1 or 0))
            assert(region.pulse.playing == (other == index), "only the selected physical button should animate")
        end
    end
end
assert(mouse.buttons[4].point[3] < mouse.buttons[5].point[3], "thumb back button sits below thumb forward")
AggeHealBotSettings.tabs[1].scripts.OnClick()
mouse.buttons[3].scripts.OnClick(mouse.buttons[3])
AggeHealBotSpellPicker.search:SetText("Holy Light")
AggeHealBotSpellPicker.rows[1].scripts.OnClick(AggeHealBotSpellPicker.rows[1])
assert(PlayerFrame.attrs.spell3 == "Holy Light", "clicking the wheel must edit Middle, not Right")
assert(mouse.caption.text == "Holy Light" and mouse.buttons[3].icon.texture == 100639)
mouse.buttons[3].scripts.OnEnter(mouse.buttons[3])
assert(GameTooltip.lines[1] == "Middle" and GameTooltip.lines[2] == "Holy Light")
mouse.buttons[3].scripts.OnLeave(mouse.buttons[3])
assert(not GameTooltip.shown)
AggeHealBotSettings.tabs[2].scripts.OnClick()
mouse.buttons[3].scripts.OnEnter(mouse.buttons[3])
assert(GameTooltip.lines[1] == "Shift + Middle" and GameTooltip.lines[2] == mouse.caption.text,
    "mouse hover and caption follow the active modifier")
mouse.buttons[3].scripts.OnLeave(mouse.buttons[3])
local currentPulsePlays = mouse.buttons[3].pulse.plays
mouse.buttons[3].scripts.OnClick(mouse.buttons[3])
assert(mouse.buttons[3].pulse.plays == currentPulsePlays, "refreshing the same selection must not restart the pulse")
mouse:Hide()
for _, button in ipairs(mouse.buttons) do assert(not button.pulse.playing, "hidden mouse diagrams must stop animating") end
mouse:Show()
assert(mouse.buttons[3].pulse.playing, "showing the diagram restores the current selection's animation")
for index, button in ipairs(mouse.buttons) do
    assert(button.callout.icon.texture == button.bindingIcon and button.callout.icon.alpha == button.bindingAlpha,
        "all five side callouts must show the current assigned icon and learned status")
    assert(button.callout.title.text == ns.buttons[index])
    button.callout.scripts.OnClick(button.callout)
    assert(AggeHealBotSpellPicker.button == index and mouse.captionTitle.text == ns.buttons[index],
        "icon callouts must select the same binding as physical mouse controls")
    button.callout.scripts.OnEnter(button.callout)
    assert(GameTooltip.owner == button.callout and GameTooltip.lines[2] == mouse.caption.text)
    button.scripts.OnLeave(button)
    assert(GameTooltip.shown, "a late leave from the physical button must not hide its icon callout tooltip")
    button.callout.scripts.OnLeave(button.callout)
    assert(not GameTooltip.shown)
end
assert(mouse.buttons[1].callout.point[2] + 16 + 26 < mouse.art.point[2]
    and mouse.buttons[2].callout.point[2] + 16 > mouse.art.point[2] + mouse.art.width,
    "spell icons must sit outside both sides of the mouse")
assert(-AggeHealBotSettings.blessings.point[3] - (-mouse.point[3] + mouse.height) >= 10,
    "mouse illustration must leave space before the blessing button")
print("PASS: five-button mouse hit regions, all modifier combinations, single selection highlight, wheel rebinding, live icons/caption and hover")
