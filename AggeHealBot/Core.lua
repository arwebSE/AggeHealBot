local ADDON, A = ...
local frames, hooks, names, learned, bindings, hookedFrames = {}, {}, {}, {}, {}, {}
local ready, queued, refresh, discover
local class
local spellDetails = {}
local openUnitMenu, openUnitMenuUnit
local raidControlsHiddenByUs = false
local function secret(v) return issecretvalue and issecretvalue(v) end
local function Print(s) print("|cff80e5b0AggeHealBot:|r " .. s) end
local function EnsureExplicitTargeting()
    if InCombatLockdown() then return end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if get and set and get("autoSelfCast") ~= "0" then
        set("autoSelfCast", "0")
        Print("Auto Self Cast turned off: failed heals stay on the clicked unit instead of falling back to you.")
    end
end
local function SpellName(id)
    if not names[id] then
        if C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(id)
            names[id] = info and info.name
        elseif GetSpellInfo then names[id] = GetSpellInfo(id) end
    end
    return names[id]
end
local function ReadSpellbook()
    wipe(learned)
    wipe(spellDetails)
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = Enum.SpellBookSpellBank.Player
        for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
            if line then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                    local name = item and item.spellID and SpellName(item.spellID)
                    if name then
                        learned[name] = true
                        spellDetails[name] = {id = item.spellID, passive = item.isPassive == true}
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        for i = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(i)
            for slot = offset + 1, offset + count do
                local name = GetSpellBookItemName(slot, "spell")
                if name then
                    learned[name] = true
                    local _, id = GetSpellBookItemInfo(slot, "spell")
                    spellDetails[name] = {id = id, passive = IsPassiveSpell and IsPassiveSpell(slot, "spell") or false}
                end
            end
        end
    end
end
local function Resolve(ids)
    for _, id in ipairs(ids) do
        local name = SpellName(id)
        if name and (learned[name] or (IsPlayerSpell and IsPlayerSpell(id))) then return name end
    end
end
local function BuildBindings()
    ReadSpellbook()
    wipe(bindings)
    local defaults = {}
    for _, list in ipairs({A.presets[class] or {}, A.common}) do
        for _, b in ipairs(list) do
            defaults[b[2] .. b[3]] = {
                label = b[1], prefix = b[2], button = b[3],
                action = type(b[4]) == "string" and b[4] or "spell",
                spell = type(b[4]) == "table" and Resolve(b[4]) or nil,
                expected = type(b[4]) == "table" and SpellName(b[4][1]) or nil,
            }
        end
    end
    for _, mod in ipairs(A.modifiers) do
        for button = 1, 5 do
            local key = mod.prefix .. button
            local b = defaults[key] or {label = mod.label .. A.buttons[button], prefix = mod.prefix,
                button = button, action = (key == "1" and "target" or "none")}
            local custom = AggeHealBotDB.bindings[key]
            if custom then
                b.action, b.spell, b.expected = custom.action, custom.spell, nil
            end
            bindings[#bindings + 1] = b
        end
    end
end
local function Unit(frame)
    local unit = frame:GetAttribute("unit") or frame.unit
    if secret(unit) or type(unit) ~= "string" then return end
    return unit
end
local function Eligible(frame)
    if not frame or not frame.GetAttribute or not frame.RegisterForClicks then return false end
    local name = frame:GetName() or ""
    if not (name == "PlayerFrame" or name:match("^PartyMemberFrame%d+$")
        or name:match("^PartyFrameMemberFrame%d+$") or name:match("^CompactPartyFrameMember%d+$")
        or name:match("^CompactRaidFrame%d+$") or name:match("^CompactRaidGroup%d+Member%d+$")) then return false end
    return true
end
local function MissingBuff(unit)
    if not AggeHealBotDB.smartBuffs or not unit or not UnitExists(unit)
        or not UnitCanAssist("player", unit) or UnitIsDeadOrGhost(unit) then return end
    local present = {}
    for i = 1, 80 do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        -- Forever can restrict aura data. Unknown data must never select a buff.
        if secret(aura.name) or secret(aura.spellId) then return end
        if aura.name then present[aura.name] = true end
    end
    for _, group in ipairs(A.buffs[class] or {}) do
        local name = Resolve({group[1]})
        local exists = false
        for _, id in ipairs(group) do
            local buffName = SpellName(id)
            if buffName and present[buffName] then exists = true end
        end
        if name and not exists then return name, group[1] end
    end
end
local function Set(frame, key, value)
    local original = frames[frame].original
    if not original[key] then original[key] = {frame:GetAttribute(key)} end
    if frame:GetAttribute(key) ~= value then frame:SetAttribute(key, value) end
end
local function BuffInRange(spell, unit)
    if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then return false end
    if UnitIsUnit(unit, "player") then return true end
    local result
    if C_Spell and C_Spell.IsSpellInRange then result = C_Spell.IsSpellInRange(spell, unit)
    elseif IsSpellInRange then result = IsSpellInRange(spell, unit) end
    if secret(result) then return false end
    return result == true or result == 1
end
local function HealOutOfRange(spell, unit)
    if not unit or not UnitExists(unit) or not UnitIsConnected(unit) then return true end
    if UnitIsUnit(unit, "player") then return false end
    local result
    if C_Spell and C_Spell.IsSpellInRange then result = C_Spell.IsSpellInRange(spell, unit)
    elseif IsSpellInRange then result = IsSpellInRange(spell, unit) end
    if secret(result) then return false end
    -- Spells without a conventional range (e.g. self-centered area spells)
    -- can return nil. The explicit-target macro still prevents a target cursor.
    return result == false or result == 0
end
local function CastMacro(spell, combatSpell)
    if not spell then return "nil" end
    -- The cursor is on this unit frame. No target/player fallback clause.
    -- Secure cleanup also works in combat, when addon range checks cannot run.
    if combatSpell and combatSpell ~= spell then
        return "/cast [combat,@mouseover,help,nodead] " .. combatSpell
            .. "; [nocombat,@mouseover,help,nodead] " .. spell .. "\n/stopspelltarget"
    end
    return "/cast [@mouseover,help,nodead] " .. spell .. "\n/stopspelltarget"
end
local function MenuButton(frame)
    local state = frames[frame]
    if not state.menuButton then
        -- UnitFrame's native OnClick filters interaction bindings through
        -- C_ClickBindings, which can discard side-button menu actions. A normal
        -- click delegate opens the stock menu without changing global bindings.
        local button = CreateFrame("Button", nil, UIParent)
        button:SetScript("OnClick", function(_, mouseButton)
            if not frames[frame] then return end
            local unit = Unit(frame)
            if not unit then return end
            local manager = Menu and Menu.GetManager and Menu.GetManager()
            if manager and openUnitMenu and manager:GetOpenMenu() == openUnitMenu and openUnitMenuUnit == unit then
                manager:CloseMenus()
                openUnitMenu, openUnitMenuUnit = nil, nil
                return
            end
            local menu = frame:GetAttribute("menu-function")
            if type(menu) == "function" then menu(frame, unit, mouseButton)
            elseif CompactUnitFrame_OpenMenu then CompactUnitFrame_OpenMenu(frame, unit, mouseButton) end
            openUnitMenu = manager and manager:GetOpenMenu() or nil
            openUnitMenuUnit = openUnitMenu and unit or nil
        end)
        button:Hide()
        state.menuButton = button
    end
    return state.menuButton
end
local function Apply(frame)
    if not ready or InCombatLockdown() then return end
    if not frames[frame] then
        frames[frame] = {original = {}, bindingDrivers = {}}
    end
    if not hookedFrames[frame] then
        hookedFrames[frame] = true
        frame:HookScript("PreClick", function(self)
            -- Recheck immediately before an out-of-combat click, including when
            -- the target moved out of range while the mouse stayed on its frame.
            if frames[self] and not InCombatLockdown() then Apply(self) end
        end)
        frame:HookScript("OnEnter", function(self)
            if not frames[self] then return end
            if not InCombatLockdown() then Apply(self) end
            if not GameTooltip then return end
            if not GameTooltip:IsOwned(self) then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local unit = Unit(self)
                if unit then GameTooltip:SetUnit(unit) end
            end
            GameTooltip:AddLine("AggeHealBot", 0.5, 1, 0.7)
            if not InCombatLockdown() and frames[self].nextBuff then
                GameTooltip:AddLine("Next left click: " .. frames[self].nextBuff, 0.65, 1, 0.65)
            elseif not InCombatLockdown() and frames[self].blockedBuff then
                GameTooltip:AddLine(frames[self].blockedBuff .. ": out of range / unavailable", 1, 0.4, 0.3)
                GameTooltip:AddLine("Left click blocked until this unit is in range.", 1, 0.7, 0.4)
            end
            for _, b in ipairs(bindings) do
                if b.prefix == "" then
                local value = b.spell or b.expected or A.actionLabels[b.action] or b.action
                if b.button == 1 and not InCombatLockdown() then
                    value = frames[self].nextBuff or value
                end
                GameTooltip:AddDoubleLine(b.label, value .. (b.action == "spell" and not b.spell and " (not learned)" or ""), 1, 1, 1, 0.6, 0.9, 0.7)
                end
            end
            GameTooltip:Show()
        end)
        frame:HookScript("OnLeave", function(self)
            if frames[self] and GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
    end
    -- These use SecureUnitButton_OnClick, which executes on every registered
    -- edge. Register only press: one physical click must execute exactly once.
    frame:RegisterForClicks("AnyDown")
    Set(frame, "checkselfcast", false)
    Set(frame, "checkfocuscast", false)
    for _, b in ipairs(bindings) do
        local key = b.prefix .. "type" .. b.button
        local plainLeft = b.prefix == "" and b.button == 1
        if not plainLeft and b.action ~= "spell" and frames[frame].bindingDrivers[key] then
            UnregisterAttributeDriver(frame, key)
            frames[frame].bindingDrivers[key] = nil
        end
        local delegate
        if b.action == "settings" then delegate = A.settingsButton
        elseif b.action == "togglemenu" then delegate = MenuButton(frame) end
        Set(frame, b.prefix .. "clickbutton" .. b.button, delegate)
        if delegate then
            Set(frame, key, "click")
        elseif not plainLeft then
            local action = b.action
            if action == "spell" then
                action = b.spell and not HealOutOfRange(b.spell, Unit(frame)) and "macro" or "none"
                local expression = "[combat] " .. (b.spell and "macro" or "none") .. "; " .. action
                if frames[frame].bindingDrivers[key] ~= expression then
                    Set(frame, key, frame:GetAttribute(key))
                    RegisterAttributeDriver(frame, key, expression)
                    frames[frame].bindingDrivers[key] = expression
                end
            else
                Set(frame, key, action)
            end
        end
        if not (b.prefix == "" and b.button == 1) then
            Set(frame, b.prefix .. "spell" .. b.button, b.action == "spell" and (b.spell or "") or nil)
            Set(frame, b.prefix .. "macrotext" .. b.button, b.action == "spell" and b.spell and CastMacro(b.spell) or nil)
        end
    end
    local heal, left
    for _, b in ipairs(bindings) do
        if b.prefix == "" and b.button == 1 then heal, left = b.spell, b end
    end
    -- The secure driver restores healing when combat starts, without addon writes.
    -- Only plain left click changes; modifier bindings stay fixed.
    local buff, buffID
    if left.action == "spell" then buff, buffID = MissingBuff(Unit(frame)) end
    local blocked = buff and not BuffInRange(buff, Unit(frame)) or false
    frames[frame].candidateBuff = buff
    frames[frame].rangeBlocked = blocked
    frames[frame].blockedBuff = blocked and buff or nil
    if blocked then buff = nil end
    local driver = "[combat] " .. (heal or "nil") .. "; " .. (blocked and "nil" or buff or heal or "nil")
    if frames[frame].driver ~= driver then
        Set(frame, "spell1", frame:GetAttribute("spell1"))
        RegisterAttributeDriver(frame, "spell1", driver)
        frames[frame].driver = driver
    end
    -- Never pass macro commands through SecureCmdOptionParse/state drivers:
    -- they parse slash commands and can strip /cast from the payload.
    -- Keep the complete macro intact; its own conditions select combat healing.
    Set(frame, "macrotext1", (buff or heal) and CastMacro(buff or heal, heal) or nil)
    local action = (left.action == "settings" or left.action == "togglemenu") and "click" or left.action
    if action == "spell" then action = heal and "macro" or "none" end
    local healBlocked = left.action == "spell" and heal and not buff and HealOutOfRange(heal, Unit(frame))
    local typeDriver = "[combat] " .. action .. "; " .. ((blocked or healBlocked) and "none" or buff and "macro" or action)
    if frames[frame].typeDriver ~= typeDriver then
        Set(frame, "type1", frame:GetAttribute("type1"))
        RegisterAttributeDriver(frame, "type1", typeDriver)
        frames[frame].typeDriver = typeDriver
    end
    frames[frame].nextBuff = buff
    -- Use the same decision as the secure click binding, never a separate scan.
    A.UpdateBuffIndicator(frame, not (IsModifierKeyDown and IsModifierKeyDown()) and buff or nil, buffID)
end
local function Register(frame)
    if frame == PlayerFrame and not AggeHealBotDB.playerFrame then return end
    if Eligible(frame) and not InCombatLockdown() then Apply(frame) end
end
local function HookFunctions()
    for _, name in ipairs({"CompactUnitFrame_SetUnit", "CompactUnitFrame_SetUpFrame", "SecureUnitButton_OnLoad"}) do
        if type(_G[name]) == "function" and not hooks[name] then
            hooksecurefunc(name, Register)
            hooks[name] = true
        end
    end
end
discover = function()
    HookFunctions()
    Register(PlayerFrame)
    for i = 1, 5 do
        Register(_G["PartyMemberFrame" .. i])
        Register(_G["PartyFrameMemberFrame" .. i])
        Register(_G["CompactPartyFrameMember" .. i])
    end
    if PartyFrame then
        for i = 1, 5 do Register(PartyFrame["MemberFrame" .. i]) end
    end
    for i = 1, 40 do Register(_G["CompactRaidFrame" .. i]) end
    for group = 1, 8 do
        for i = 1, 5 do Register(_G["CompactRaidGroup" .. group .. "Member" .. i]) end
    end
end
local function ApplyRaidControls()
    local manager = CompactRaidFrameManager
    if not manager or InCombatLockdown() then return end
    if not hooks.raidControls then
        manager:HookScript("OnShow", function(self)
            if AggeHealBotDB.hideRaidControls and not InCombatLockdown() then
                raidControlsHiddenByUs = true
                self:Hide()
            end
        end)
        hooks.raidControls = true
    end
    if AggeHealBotDB.hideRaidControls then
        raidControlsHiddenByUs = raidControlsHiddenByUs or manager:IsShown()
        manager:Hide()
    elseif raidControlsHiddenByUs then
        raidControlsHiddenByUs = false
        if CompactRaidFrameManager_UpdateShown then CompactRaidFrameManager_UpdateShown()
        else manager:Show() end
    end
end
refresh = function()
    if not ready or InCombatLockdown() then return end
    ApplyRaidControls()
    if PlayerFrame and frames[PlayerFrame] and not AggeHealBotDB.playerFrame then
        local state = frames[PlayerFrame]
        UnregisterAttributeDriver(PlayerFrame, "spell1")
        UnregisterAttributeDriver(PlayerFrame, "type1")
        for key in pairs(state.bindingDrivers) do UnregisterAttributeDriver(PlayerFrame, key) end
        for key, original in pairs(state.original) do PlayerFrame:SetAttribute(key, original[1]) end
        PlayerFrame:RegisterForClicks("AnyUp")
        A.UpdateBuffIndicator(PlayerFrame)
        frames[PlayerFrame] = nil
    end
    discover()
    for frame in pairs(frames) do Apply(frame) end
end
local function Queue()
    if queued or not ready or InCombatLockdown() then return end
    queued = true
    C_Timer.After(0, function() queued = false; refresh() end)
end
A.GetBindings = function() return bindings end
local function Passive(id, detail)
    if detail and detail.passive then return true end
    return id and C_Spell and C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(id) == true
end
A.GetSpells = function()
    local list, seen = {}, {}
    for name in pairs(learned) do
        local detail = spellDetails[name]
        seen[name] = true
        if not Passive(detail and detail.id, detail) then list[#list + 1] = name end
    end
    -- Also works on clients where only IsPlayerSpell was available.
    for id, name in pairs(names) do
        if not seen[name] and IsPlayerSpell and IsPlayerSpell(id) and not Passive(id) then list[#list + 1] = name; seen[name] = true end
    end
    table.sort(list)
    return list
end
A.GetSpellChoices = function()
    local categoryByName = {}
    for category, ids in pairs(A.spellCategories) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then categoryByName[name] = category end
        end
    end
    local choices = {}
    for _, name in ipairs(A.GetSpells()) do
        local detail = spellDetails[name]
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(detail and detail.id or name)
        choices[#choices + 1] = {label = name, spell = name, action = "spell", category = categoryByName[name] or "other", icon = info and info.iconID}
    end
    local order = {heals = 1, buffs = 2, utility = 3, other = 4}
    table.sort(choices, function(a, b)
        if a.category ~= b.category then return order[a.category] < order[b.category] end
        return a.label < b.label
    end)
    return choices
end
A.SaveBinding = function(prefix, button, action, spell)
    local validPrefix = false
    for _, m in ipairs(A.modifiers) do if m.prefix == prefix then validPrefix = true end end
    if not validPrefix or type(button) ~= "number" or button < 1 or button > 5 or button % 1 ~= 0 then return false end
    if action == "default" then AggeHealBotDB.bindings[prefix .. button] = nil
    else
        if not A.actionLabels[action] then return false end
        if action == "spell" then
            local valid = false
            for _, name in ipairs(A.GetSpells()) do if name == spell then valid = true end end
            if not valid then return false end
        end
        AggeHealBotDB.bindings[prefix .. button] = {action = action, spell = action == "spell" and spell or nil}
    end
    -- Keep the displayed bindings consistent with the active secure attributes in combat.
    if not InCombatLockdown() then BuildBindings() end
    Queue()
    return true
end
A.SetOption = function(key, value)
    if key ~= "smartBuffs" and key ~= "playerFrame" and key ~= "hideRaidControls" then return end
    AggeHealBotDB[key] = value and true or false
    Queue()
end
A.ResetBindings = function()
    wipe(AggeHealBotDB.bindings)
    if not InCombatLockdown() then BuildBindings() end
    Queue()
end
local function ShowSettings() if ready and A.ShowOptions then A.ShowOptions() end end
A.settingsButton = CreateFrame("Button", "AggeHealBotOpenSettings", UIParent)
A.settingsButton:SetScript("OnClick", function()
    if ready and A.ToggleOptions then A.ToggleOptions() end
end)
A.settingsButton:Hide()
SLASH_AGGEHEALBOT1 = "/ahb"
SlashCmdList.AGGEHEALBOT = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "buffs off" or msg == "buffs on" then
        AggeHealBotDB.smartBuffs = msg == "buffs on"
        Queue()
        Print("Missing buffs " .. (AggeHealBotDB.smartBuffs and "on" or "off") .. ".")
    elseif msg == "status" then
        local n = 0
        for _ in pairs(frames) do n = n + 1 end
        Print("0.4.2 | " .. n .. " stock frames registered | buffs " .. (AggeHealBotDB.smartBuffs and "on" or "off"))
    else ShowSettings() end
end
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "MODIFIER_STATE_CHANGED", "SPELLS_CHANGED", "UNIT_AURA", "UNIT_PET"}) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" and arg == ADDON then
        AggeHealBotDB = AggeHealBotDB or {}
        if AggeHealBotDB.smartBuffs == nil then AggeHealBotDB.smartBuffs = true end
        if AggeHealBotDB.playerFrame == nil then AggeHealBotDB.playerFrame = false end
        if AggeHealBotDB.hideRaidControls == nil then AggeHealBotDB.hideRaidControls = false end
        AggeHealBotDB.bindings = AggeHealBotDB.bindings or {}
    elseif event == "PLAYER_LOGIN" then
        local token
        token, class = UnitClass("player")
        ready = true
        EnsureExplicitTargeting()
        BuildBindings()
        refresh()
        -- Movement doesn't emit UNIT_AURA. Poll only range for pending buffs;
        -- rescan auras/reapply bindings only when the range state changes.
        C_Timer.NewTicker(0.2, function()
            if InCombatLockdown() then return end
            for frame, state in pairs(frames) do
                if state.candidateBuff then
                    local blocked = not BuffInRange(state.candidateBuff, Unit(frame))
                    if blocked ~= state.rangeBlocked then
                        Queue()
                        break
                    end
                end
            end
        end)
        Print("Loaded. /ahb for bindings and settings.")
    elseif ready then
        if event == "PLAYER_REGEN_DISABLED" then
            A.HideBuffIndicators()
            -- Hide a precombat tooltip rather than leave an obsolete buff hint up.
            if GameTooltip then
                for frame in pairs(frames) do
                    if GameTooltip:IsOwned(frame) then GameTooltip:Hide(); break end
                end
            end
            return
        end
        if event == "SPELLS_CHANGED" and not InCombatLockdown() then BuildBindings() end
        if event == "PLAYER_REGEN_ENABLED" then EnsureExplicitTargeting(); BuildBindings() end
        -- Never inspect auras, unit health, or protected attributes in combat.
        if not InCombatLockdown() then Queue() end
    end
end)
