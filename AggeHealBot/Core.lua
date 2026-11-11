local ADDON, A = ...
local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
A.version = getMetadata and getMetadata(ADDON, "Version") or "dev"
local frames, hooks, names, learned, bindings, hookedFrames = {}, {}, {}, {}, {}, {}
local ready, queued, refresh, discover, Apply
local class
local spellDetails = {}
local openUnitMenu, openUnitMenuUnit
local raidControlsHiddenByUs = false
local rejectedBuffs, pendingBuffAttempt = {}, nil
local hoveredFrame, hoveredRegion, addonTooltip
local hoverHooks = {}
local targetVisibilityDriver
local optionDefaults = {
    smartBuffs = true, cureWatch = true, combatCures = true,
    combatResurrection = false, playerFrame = true, targetFrame = true,
    rightClickMenu = false, hideRaidControls = true,
    showUnlearned = false,
}
local function secret(v) return issecretvalue and issecretvalue(v) end
local function Print(s) print("|cff80e5b0AggeHealBot:|r " .. s) end
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
                        local future = Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell ~= nil
                            and item.itemType == Enum.SpellBookItemType.FutureSpell
                        if not future then learned[name] = true end
                        local previous = spellDetails[name]
                        if not previous or not future then
                            spellDetails[name] = {id = item.spellID, passive = item.isPassive == true, future = future}
                        end
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
local function CandidateName(ids)
    for _, id in ipairs(ids) do
        local name = SpellName(id)
        if name then return name end
    end
end
local function IsLearned(name, spellID)
    if learned[name] or (spellID and IsPlayerSpell and IsPlayerSpell(spellID)) then return true end
    for id, spellName in pairs(names) do
        if spellName == name and IsPlayerSpell and IsPlayerSpell(id) then return true end
    end
    return false
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
                expected = type(b[4]) == "table" and CandidateName(b[4]) or nil,
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
                local name = custom.spellID and SpellName(custom.spellID) or custom.spell
                b.action = custom.action
                b.spell = custom.action == "spell" and name and IsLearned(name, custom.spellID) and name or nil
                b.expected = custom.action == "spell" and name or nil
            end
            -- An unsupported/missing spell identity is not an unlearned spell.
            if b.action == "spell" and not b.spell and not b.expected then b.action = "none" end
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
    local normalPartyMember = PartyFrame and frame.GetParent and frame:GetParent() == PartyFrame
    if not (frame == A.targetButton or normalPartyMember or name == "PlayerFrame" or name:match("^PartyMemberFrame%d+$")
        or name:match("^PartyFrameMemberFrame%d+$") or name:match("^CompactPartyFrameMember%d+$")
        or name:match("^CompactRaidFrame%d+$") or name:match("^CompactRaidGroup%d+Member%d+$")) then return false end
    return true
end
local function AuraQueryRestricted(predicate, ...)
    if not predicate then return false end
    local ok, restricted = pcall(predicate, ...)
    -- A failed/unknown secrecy query is not permission to inspect auras.
    if not ok or secret(restricted) then return true end
    return restricted ~= false
end
local function ReadAuras(unit, filter, allowCombat)
    if (InCombatLockdown() and not allowCombat) or not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex
        or AuraQueryRestricted(C_Secrets and C_Secrets.ShouldAurasBeSecret) then return end
    local result = {}
    for i = 1, 80 do
        if AuraQueryRestricted(C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret, unit, i, filter) then return end
        -- Access itself can be denied before an aura is returned, including
        -- when restrictions change during a scan. Discard partial evidence.
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
        if not ok or secret(aura) then return end
        if not aura then break end
        if type(aura) ~= "table" then return end
        result[#result + 1] = aura
    end
    return result
end
local function HelpfulAuras(unit)
    local auras = ReadAuras(unit, "HELPFUL")
    if not auras then return end
    local present, evidence = {}, {}
    for _, aura in ipairs(auras) do
        -- Forever can restrict aura data. Unknown data must never select a buff.
        if secret(aura.name) or secret(aura.spellId) then return end
        if aura.name then present[aura.name] = true end
        -- Forever aura display names can differ from their spell's canonical
        -- name. Resolve the live rank ID too, not just the displayed name.
        local canonical = aura.spellId and SpellName(aura.spellId)
        if canonical then present[canonical] = true end
        if secret(aura.auraInstanceID) then return end
        local key = aura.auraInstanceID or (aura.spellId and ("spell:" .. aura.spellId)) or aura.name
        if key then evidence[key] = true end
    end
    return present, evidence, auras
end
local function UnitKey(unit)
    local guid = UnitGUID(unit)
    if not secret(guid) and type(guid) == "string" then return guid end
end
local function RejectedBuffStillActive(guid, spell, evidence)
    local list = guid and rejectedBuffs[guid]
    local rejected = list and list[spell]
    if not rejected then return false end
    -- Additions/refreshes don't invalidate a rejection; a removed/replaced
    -- aura can be the blocker disappearing, so allow the client to retry then.
    local hasEvidence = false
    for key in pairs(rejected) do
        hasEvidence = true
        if not evidence[key] then
            list[spell] = nil
            return false
        end
    end
    if not hasEvidence and next(evidence) then list[spell] = nil; return false end
    return true
end
local function BuffRank(definition, id)
    if not definition or not id then return end
    for rank, spellID in ipairs(definition.ranks) do
        if spellID == id then return rank end
    end
    return definition.equivalents and definition.equivalents[id]
end
local function LearnedBuffRank(definition, name)
    if not definition then return end
    local highest
    local detail = spellDetails[name]
    for rank, id in ipairs(definition.ranks) do
        -- A learned name alone cannot identify its rank. Do not count learned
        -- group buffs: the watcher casts the single-target spell by name.
        if (detail and detail.id == id) or (IsPlayerSpell and IsPlayerSpell(id)) then highest = rank end
    end
    return highest
end
local function BuffSatisfied(group, definition, ourRank, auras)
    local matchingNames = {}
    for _, id in ipairs(group) do
        local name = SpellName(id)
        if name then matchingNames[name] = true end
    end
    for _, aura in ipairs(auras) do
        local rank = BuffRank(definition, aura.spellId)
        if rank then
            if not ourRank or rank >= ourRank then return true end
        else
            local canonical = aura.spellId and SpellName(aura.spellId)
            -- Unknown rank/equivalent strength is not evidence of an upgrade.
            if matchingNames[aura.name] or (canonical and matchingNames[canonical]) then return true end
        end
    end
    return false
end
local function PaladinBuffGroups(unit)
    local ok, _, targetClass = pcall(UnitClass, unit)
    if not ok or secret(targetClass) or type(targetClass) ~= "string" then return {} end
    local rule = A.GetPaladinRule(targetClass)
    if rule == "off" then return {} end
    if rule == "auto" then
        rule = (targetClass == "WARRIOR" or targetClass == "ROGUE") and "might" or "wisdom"
        local group = A.paladinBlessings[rule]
        if not Resolve(A.buffRanks[group[1]].ranks) then rule = "kings" end
    end
    local group = A.paladinBlessings[rule]
    return group and {group} or {}
end
local function MissingBuff(unit)
    if not AggeHealBotDB.smartBuffs or not unit or not UnitExists(unit)
        or not UnitCanAssist("player", unit) or UnitIsDeadOrGhost(unit) then return end
    local present, evidence, auras = HelpfulAuras(unit)
    if not present then return end
    local guid = UnitKey(unit)
    local groups = class == "PALADIN" and PaladinBuffGroups(unit) or A.buffs[class] or {}
    for _, group in ipairs(groups) do
        local definition = A.buffRanks[group[1]]
        local name = Resolve({group[1]}) or (definition and Resolve(definition.ranks))
        local exists = name and BuffSatisfied(group, definition, LearnedBuffRank(definition, name), auras)
        if name and not exists and not RejectedBuffStillActive(guid, name, evidence) then return name, group[1], evidence end
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
local function ReadFlag(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if ok and not secret(value) then return value end
end
local function WatchAllowed(unit)
    if not unit then return false end
    return ReadFlag(UnitIsPlayer, unit) == true
end
local function ResurrectionCandidate(unit, spell)
    if not spell or not unit or unit == "player" then return end
    if ReadFlag(UnitCanAssist, "player", unit) ~= true or ReadFlag(UnitIsUnit, unit, "player") == true
        or ReadFlag(UnitIsDeadOrGhost, "player") ~= false then return end
    if ReadFlag(UnitExists, unit) ~= true
        or ReadFlag(UnitIsConnected, unit) ~= true or ReadFlag(UnitIsDeadOrGhost, unit) ~= true then return end
    if UnitHasIncomingResurrection and ReadFlag(UnitHasIncomingResurrection, unit) ~= false then return end
    return spell
end
local function CureCandidate(unit, allowCombat)
    if not AggeHealBotDB.cureWatch or not unit or ReadFlag(UnitCanAssist, "player", unit) ~= true
        or ReadFlag(UnitIsDeadOrGhost, unit) ~= false then return end
    local available = {}
    for _, entry in ipairs(A.dispels[class] or {}) do
        local spell = Resolve({entry[1]})
        if spell then
            for i = 2, #entry do
                if not available[entry[i]] then available[entry[i]] = {spell, entry[1]} end
            end
        end
    end
    if not next(available) then return end
    local auras = ReadAuras(unit, "HARMFUL", allowCombat)
    if not auras then return end
    local candidate, debuff
    for _, aura in ipairs(auras) do
        if secret(aura.dispelName) or secret(aura.name) then return end
        local cure = aura.dispelName and available[aura.dispelName]
        if cure and not candidate then candidate, debuff = cure, aura.name end
    end
    if candidate then return candidate[1], candidate[2], debuff end
end
local function UpdateCombatWatch(frame)
    local state = frames[frame]
    if not state then return end
    local spell, id, kind, debuff
    if state.combatResActive and AggeHealBotDB.combatResurrection then
        spell, id, kind = state.combatResSpell, state.combatResID, "resurrection"
    elseif AggeHealBotDB.combatCures and WatchAllowed(Unit(frame)) then
        spell, id, debuff = CureCandidate(Unit(frame), true)
        if spell then kind = "cure" end
    end
    state.combatCureSpell = kind == "cure" and spell or nil
    state.combatCureDebuff = debuff
    local visible = not (IsModifierKeyDown and IsModifierKeyDown())
    A.UpdateBuffIndicator(frame, visible and spell or nil, id, kind)
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
local function CastMacro(spell, combatSpell, explicitUnit)
    if not spell then return "nil" end
    local target = explicitUnit or "mouseover"
    -- The cursor is on this unit frame. No target/player fallback clause.
    -- Secure cleanup also works in combat, when addon range checks cannot run.
    if combatSpell and combatSpell ~= spell then
        return "/cast [combat,@" .. target .. ",help,nodead] " .. combatSpell
            .. "; [nocombat,@" .. target .. ",help,nodead] " .. spell .. "\n/stopspelltarget"
    end
    return "/cast [@" .. target .. ",help,nodead] " .. spell .. "\n/stopspelltarget"
end
local function TargetMacro(frame)
    -- Native UnitFrame click-binding routing can discard type="target" when
    -- no Blizzard interaction binding exists for this modifier/button. An
    -- explicit secure macro keeps targeting within our own saved bindings.
    local unit = frame == PlayerFrame and "player" or frame == A.targetButton and "target" or "mouseover"
    return "/target [@" .. unit .. ",exists]"
end
local function MenuButton(frame)
    local state = frames[frame]
    if not state.menuButton then
        -- UnitFrame's native OnClick filters interaction bindings through
        -- C_ClickBindings, which can discard side-button menu actions. A normal
        -- click delegate opens the stock menu without changing global bindings.
        local button = CreateFrame("Button", nil, UIParent)
        button:SetScript("OnClick", function(_, mouseButton)
            if addonTooltip then addonTooltip:Hide() end
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
local function BindingAction(frame, binding)
    if (frame == PlayerFrame or frame == A.targetButton) and binding.prefix == "" and binding.button == 2 and AggeHealBotDB.rightClickMenu then return "togglemenu" end
    return binding.action
end
local function ShowFrameTooltip(frame)
    local state = frames[frame]
    if not state or not GameTooltip then return end
    local manager = Menu and Menu.GetManager and Menu.GetManager()
    if manager and manager:GetOpenMenu() then
        if addonTooltip then addonTooltip:Hide() end
        return
    end
    local unit = Unit(frame)
    -- Use an addon-owned tooltip for every supported unit frame. SetUnit would
    -- enable automatic unit-data refreshes that can replace custom lines.
    if not addonTooltip then
        addonTooltip = CreateFrame("GameTooltip", "AggeHealBotTooltip", UIParent, "GameTooltipTemplate")
        addonTooltip:SetFrameStrata("TOOLTIP")
        addonTooltip:SetFrameLevel(100)
        addonTooltip:EnableMouse(false)
    end
    if unit then
        -- Leave Blizzard's unit details intact, including its normal live
        -- refreshes; our binding information lives in a separate panel.
        local ownsResourceTip = hoveredFrame == frame and hoveredRegion and GameTooltip:IsOwned(hoveredRegion)
        if not GameTooltip:IsOwned(frame) and not ownsResourceTip then
            -- The friendly-target click surface has no native OnEnter to
            -- position GameTooltip. Use Blizzard's default anchor so it does
            -- not occupy the same frame-relative position as our panel.
            if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, frame)
            else
                GameTooltip:SetOwner(frame, "ANCHOR_NONE")
                GameTooltip:ClearAllPoints()
                GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -16, 16)
            end
            GameTooltip:SetUnit(unit)
        end
        GameTooltip:Show()
    end
    local tooltip = addonTooltip
    tooltip:SetOwner(frame, "ANCHOR_RIGHT")
    tooltip:SetClampedToScreen(true)
    local name = unit and UnitName and UnitName(unit)
    if secret(name) or type(name) ~= "string" then name = "Unit" end
    tooltip:ClearLines()
    tooltip:AddDoubleLine(name, "AggeHealBot", 1, 0.82, 0, 0.5, 1, 0.7)
    local heading = _G.AggeHealBotTooltipTextLeft1
    local label = _G.AggeHealBotTooltipTextRight1
    if heading and GameTooltipHeaderText then
        heading:SetFontObject(GameTooltipHeaderText)
        heading:SetTextColor(1, 0.82, 0)
    end
    if label and GameFontHighlightSmall then
        label:SetFontObject(GameFontHighlightSmall)
        label:SetTextColor(0.5, 1, 0.7)
    end
    local prefix = (IsAltKeyDown and IsAltKeyDown() and "alt-" or "")
        .. (IsControlKeyDown and IsControlKeyDown() and "ctrl-" or "")
        .. (IsShiftKeyDown and IsShiftKeyDown() and "shift-" or "")
    if prefix ~= "" then
        for _, binding in ipairs(bindings) do
            if binding.prefix == prefix and BindingAction(frame, binding) == "settings" then
                tooltip:AddLine(binding.label .. " Click to open AggeHealBot Menu.", 1, 1, 1)
                break
            end
        end
    end
    if InCombatLockdown() and state.combatResActive then
        tooltip:AddLine("Left click: " .. state.combatResSpell .. " (combat resurrection)", 0.65, 0.95, 1)
    elseif InCombatLockdown() and state.combatCureSpell then
        tooltip:AddLine("Cure alert: " .. state.combatCureSpell, 1, 0.4, 0.3)
        if state.combatCureDebuff then tooltip:AddLine(state.combatCureDebuff, 1, 0.6, 0.5) end
        local shortcut
        for _, binding in ipairs(bindings) do
            if binding.spell == state.combatCureSpell and BindingAction(frame, binding) == "spell" then shortcut = binding.label; break end
        end
        tooltip:AddLine(shortcut and ("Cast with " .. shortcut) or "Bind this cure in /ahb to cast it in combat.", 1, 1, 1)
    elseif prefix == "" and not InCombatLockdown() and state.nextBuff then
        tooltip:AddLine((state.resurrection and "Resurrect with left click: " or state.cure and "Cure with left click: " or "Next left click: ") .. state.nextBuff, 0.65, 1, 0.65)
        if state.cure then tooltip:AddLine(state.cure, 1, 0.6, 0.5) end
    elseif prefix == "" and not InCombatLockdown() and state.blockedBuff then
        tooltip:AddLine(state.blockedBuff .. ": " .. (A.CastProblem(state.blockedBuff, unit) or "Range unavailable"), 1, 0.4, 0.3)
        tooltip:AddLine("Left click blocked until range is confirmed.", 1, 0.7, 0.4)
    elseif prefix == "" and not InCombatLockdown() and state.healingFirst then
        tooltip:AddLine("Healing first: below 90% health.", 0.65, 1, 0.65)
    end
    for _, b in ipairs(bindings) do
        if b.prefix == prefix then
            local action = BindingAction(frame, b)
            local value = action == "spell" and (b.spell or b.expected) or A.actionLabels[action] or action
            if b.button == 1 and prefix == "" and not InCombatLockdown() then value = state.nextBuff or value end
            if b.button == 1 and prefix == "" and InCombatLockdown() and state.combatResActive then value = state.combatResSpell end
            local problem = action == "spell" and b.spell and A.CastProblem(b.button == 1 and prefix == "" and state.nextBuff or b.spell, unit)
            if problem then value = value .. " |cffffb366(" .. problem .. ")|r" end
            tooltip:AddDoubleLine(b.label, value .. (action == "spell" and not b.spell and " (not learned)" or ""), 1, 1, 1, 0.6, 0.9, 0.7)
        end
    end
    tooltip:Show()
end
local function HookHover(frame, region)
    if not region or not region.HookScript or hoverHooks[region] then return end
    hoverHooks[region] = true
    region:HookScript("OnEnter", function(self)
        if not frames[frame] or (frame == A.targetButton and not frame:IsShown()) then return end
        hoveredFrame, hoveredRegion = frame, self
        if not InCombatLockdown() then Apply(frame) end
        ShowFrameTooltip(frame)
    end)
    region:HookScript("OnLeave", function(self)
        if hoveredRegion ~= self then return end
        hoveredFrame, hoveredRegion = nil, nil
        if addonTooltip and addonTooltip:IsOwned(frame) then addonTooltip:Hide() end
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end
local function RefreshHint(frame)
    local state = frames[frame]
    if not state or InCombatLockdown() then return end
    A.UpdateBuffIndicator(frame, not (IsModifierKeyDown and IsModifierKeyDown()) and state.nextBuff or nil,
        state.nextBuffID, state.watchKind, state.nextBuff and A.CastProblem(state.nextBuff, Unit(frame)))
end
Apply = function(frame)
    if not ready or InCombatLockdown() then return end
    if not frames[frame] then
        frames[frame] = {original = {}, bindingDrivers = {}}
    end
    HookHover(frame, frame)
    local visual = frame == A.targetButton and TargetFrame or frame
    local content = visual.TargetFrameContent and visual.TargetFrameContent.TargetFrameContentMain
    HookHover(frame, visual.healthbar or visual.healthBar or visual.HealthBar
        or (content and content.HealthBarsContainer and content.HealthBarsContainer.HealthBar))
    HookHover(frame, visual.manabar or visual.manaBar or visual.ManaBar or visual.powerBar or visual.PowerBar or (content and content.ManaBar))
    if not hookedFrames[frame] then
        hookedFrames[frame] = true
        frame:HookScript("PreClick", function(self, button)
            pendingBuffAttempt = nil
            -- Recheck immediately before an out-of-combat click, including when
            -- the target moved out of range while the mouse stayed on its frame.
            if frames[self] and not InCombatLockdown() then
                Apply(self)
                local state = frames[self]
                if button == "LeftButton" and state.nextBuff and not state.resurrection and not state.cure and not (IsModifierKeyDown and IsModifierKeyDown()) then
                    local unit = Unit(self)
                    local guid = unit and UnitKey(unit)
                    if guid then
                        pendingBuffAttempt = {unit = unit, guid = guid, spell = state.nextBuff,
                            evidence = state.buffEvidence, time = GetTime()}
                    end
                end
            end
        end)
        frame:HookScript("OnAttributeChanged", function(self, key, value)
            if key ~= "ahb-resurrection" or not frames[self] then return end
            local state = frames[self]
            state.combatResActive = value == "combat" and AggeHealBotDB.combatResurrection
            if InCombatLockdown() then
                UpdateCombatWatch(self)
                if hoveredFrame == self then ShowFrameTooltip(self) end
            end
        end)
    end
    -- These use SecureUnitButton_OnClick, which executes on every registered
    -- edge. Register only press: one physical click must execute exactly once.
    frame:RegisterForClicks("AnyDown")
    Set(frame, "checkselfcast", false)
    Set(frame, "checkfocuscast", false)
    for _, b in ipairs(bindings) do
        -- All shortcuts, including modifier-click menus, use saved bindings.
        local bindingAction = BindingAction(frame, b)
        local key = b.prefix .. "type" .. b.button
        local plainLeft = b.prefix == "" and b.button == 1
        if not plainLeft and bindingAction ~= "spell" and frames[frame].bindingDrivers[key] then
            UnregisterAttributeDriver(frame, key)
            frames[frame].bindingDrivers[key] = nil
        end
        local delegate
        if bindingAction == "settings" then delegate = A.settingsButton
        elseif bindingAction == "togglemenu" then delegate = MenuButton(frame) end
        Set(frame, b.prefix .. "clickbutton" .. b.button, delegate)
        if delegate then
            Set(frame, key, "click")
        elseif not plainLeft then
            local action = bindingAction
            if action == "spell" then
                action = b.spell and not HealOutOfRange(b.spell, Unit(frame)) and "macro" or "none"
                local expression = "[combat] " .. (b.spell and "macro" or "none") .. "; " .. action
                if frames[frame].bindingDrivers[key] ~= expression then
                    Set(frame, key, frame:GetAttribute(key))
                    RegisterAttributeDriver(frame, key, expression)
                    frames[frame].bindingDrivers[key] = expression
                end
            else
                Set(frame, key, action == "target" and "macro" or action)
            end
        end
        if not (b.prefix == "" and b.button == 1) then
            Set(frame, b.prefix .. "spell" .. b.button, bindingAction == "spell" and (b.spell or "") or nil)
            local macro = bindingAction == "target" and TargetMacro(frame)
                or bindingAction == "spell" and b.spell and CastMacro(b.spell, nil, frame == A.targetButton and "target" or nil) or nil
            Set(frame, b.prefix .. "macrotext" .. b.button, macro)
        end
    end
    local heal, left
    for _, b in ipairs(bindings) do
        if b.prefix == "" and b.button == 1 then heal, left = b.spell, b end
    end
    -- The secure driver restores healing when combat starts, without addon writes.
    -- Only plain left click changes; modifier bindings stay fixed.
    local buff, buffID, evidence
    local unit = Unit(frame)
    local watches = WatchAllowed(unit) and left.action == "spell"
    frames[frame].canHealFirst = watches and heal ~= nil
    frames[frame].healingFirst = frames[frame].canHealFirst and A.NeedsHealing(unit) or false
    if watches and not frames[frame].healingFirst then buff, buffID, evidence = MissingBuff(unit) end
    frames[frame].unitDead = ReadFlag(UnitIsDeadOrGhost, unit)
    local normalResIDs = A.resurrections[class] or {}
    local combatResIDs = A.combatResurrections[class] or {}
    local normalRes = watches and Resolve(normalResIDs) or nil
    local combatRes = watches and AggeHealBotDB.combatResurrection and Resolve(combatResIDs) or nil
    local res = ResurrectionCandidate(unit, normalRes or combatRes)
    local cure, cureID, debuff
    if watches and not res then cure, cureID, debuff = CureCandidate(unit) end
    frames[frame].cure = cure and (debuff or "Removable debuff") or nil
    if cure then buff, buffID = cure, cureID end
    frames[frame].resurrection = res ~= nil
    if res then buff, buffID = res, normalRes and normalResIDs[1] or combatResIDs[1] end
    frames[frame].combatResSpell, frames[frame].combatResID = combatRes, combatResIDs[1]
    if combatRes and unit and unit ~= "player" then
        RegisterAttributeDriver(frame, "ahb-resurrection", "[@" .. unit .. ",combat,help,dead,party] combat; [@" .. unit .. ",combat,help,dead,raid] combat; none")
    else
        UnregisterAttributeDriver(frame, "ahb-resurrection")
    end
    frames[frame].buffEvidence = evidence
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
    local livingSpell = buff or heal
    if res then livingSpell = heal end
    Set(frame, "macrotext1", livingSpell and CastMacro(livingSpell, heal, frame == A.targetButton and "target" or nil) or nil)
    if normalRes or combatRes then
        local target = frame == A.targetButton and "target" or "mouseover"
        local clauses = {}
        if combatRes then
            clauses[#clauses + 1] = "[combat,@" .. target .. ",help,dead,party] " .. combatRes
            clauses[#clauses + 1] = "[combat,@" .. target .. ",help,dead,raid] " .. combatRes
        end
        if res then clauses[#clauses + 1] = "[nocombat,@" .. target .. ",help,dead] " .. res end
        local base = frame:GetAttribute("macrotext1")
        if base and base ~= "nil" then clauses[#clauses + 1] = base:match("^/cast (.-)\n") end
        Set(frame, "macrotext1", #clauses > 0 and ("/cast " .. table.concat(clauses, "; ") .. "\n/stopspelltarget") or nil)
    end
    local action = (left.action == "settings" or left.action == "togglemenu") and "click" or left.action
    if action == "target" then
        action = "macro"
        Set(frame, "macrotext1", TargetMacro(frame))
    end
    if action == "spell" then action = heal and "macro" or "none" end
    if combatRes then action = "macro" end
    local healBlocked = left.action == "spell" and heal and not buff and HealOutOfRange(heal, Unit(frame))
    local typeDriver = "[combat] " .. action .. "; " .. ((blocked or healBlocked) and "none" or buff and "macro" or action)
    if frames[frame].typeDriver ~= typeDriver then
        Set(frame, "type1", frame:GetAttribute("type1"))
        RegisterAttributeDriver(frame, "type1", typeDriver)
        frames[frame].typeDriver = typeDriver
    end
    frames[frame].nextBuff = buff
    frames[frame].nextBuffID = buffID
    frames[frame].watchKind = res and "resurrection" or cure and "cure" or nil
    -- Use the same decision as the secure click binding, never a separate scan.
    A.UpdateBuffIndicator(frame, not (IsModifierKeyDown and IsModifierKeyDown()) and buff or nil, buffID,
        frames[frame].watchKind, buff and A.CastProblem(buff, unit))
end
local function Register(frame)
    if frame == PlayerFrame and not AggeHealBotDB.playerFrame then return end
    if frame == A.targetButton and not AggeHealBotDB.targetFrame then return end
    if Eligible(frame) and not InCombatLockdown() then Apply(frame) end
end
local function HookFunctions()
    for _, name in ipairs({"CompactUnitFrame_SetUnit", "CompactUnitFrame_SetUpFrame", "SecureUnitButton_OnLoad"}) do
        if type(_G[name]) == "function" and not hooks[name] then
            hooksecurefunc(name, Register)
            hooks[name] = true
        end
    end
    -- Forever's standard party frames are pooled anonymous children of
    -- PartyFrame; refresh them after Blizzard reassigns their unit tokens.
    if PartyMemberFrameMixin and PartyMemberFrameMixin.UpdateMember and not hooks.normalPartyFrames then
        hooksecurefunc(PartyMemberFrameMixin, "UpdateMember", Register)
        hooks.normalPartyFrames = true
    end
end
local function RestoreFrame(frame)
    local state = frame and frames[frame]
    if not state then return end
    UnregisterAttributeDriver(frame, "spell1")
    UnregisterAttributeDriver(frame, "type1")
    UnregisterAttributeDriver(frame, "ahb-resurrection")
    for key in pairs(state.bindingDrivers) do UnregisterAttributeDriver(frame, key) end
    for key, original in pairs(state.original) do frame:SetAttribute(key, original[1]) end
    frame:RegisterForClicks("AnyUp")
    A.UpdateBuffIndicator(frame)
    if hoveredFrame == frame then
        if addonTooltip and addonTooltip:IsOwned(frame) then addonTooltip:Hide() end
        if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
        hoveredFrame, hoveredRegion = nil, nil
    end
    frames[frame] = nil
end
local function RegisterTargetFrame()
    if not TargetFrame or (not AggeHealBotDB.targetFrame and not A.targetButton) then return end
    if not A.targetButton then
        -- A secure friendly-only click surface leaves the stock target button
        -- and enemy interactions intact, including target switches in combat.
        local button = CreateFrame("Button", "AggeHealBotTargetButton", TargetFrame, "SecureUnitButtonTemplate")
        button:SetAllPoints(TargetFrame)
        local level = TargetFrame:GetFrameLevel()
        if not secret(level) then button:SetFrameLevel(level + 1) end
        button:EnableMouse(true)
        button.unit = "target"
        button:SetAttribute("unit", "target")
        button:SetAttribute("menu-function", function(_, unit, mouseButton)
            local menu = TargetFrame:GetAttribute("menu-function")
            if type(menu) == "function" then menu(TargetFrame, unit, mouseButton)
            elseif CompactUnitFrame_OpenMenu then CompactUnitFrame_OpenMenu(TargetFrame, unit, mouseButton) end
        end)
        button:HookScript("OnHide", function(self)
            A.UpdateBuffIndicator(self)
            if hoveredFrame == self then
                hoveredFrame, hoveredRegion = nil, nil
                if addonTooltip and addonTooltip:IsOwned(self) then addonTooltip:Hide() end
                if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end
        end)
        A.targetButton = button
    end
    local visibility = AggeHealBotDB.targetFrame and "[@target,exists,help] show; hide" or "hide"
    if targetVisibilityDriver ~= visibility then
        RegisterStateDriver(A.targetButton, "visibility", visibility)
        targetVisibilityDriver = visibility
    end
    if AggeHealBotDB.targetFrame then Register(A.targetButton)
    else RestoreFrame(A.targetButton) end
end
discover = function()
    HookFunctions()
    Register(PlayerFrame)
    RegisterTargetFrame()
    for i = 1, 5 do
        Register(_G["PartyMemberFrame" .. i])
        Register(_G["PartyFrameMemberFrame" .. i])
        Register(_G["CompactPartyFrameMember" .. i])
    end
    if PartyFrame then
        for i = 1, 5 do
            local member = PartyFrame.GetPartyMemberFrame and PartyFrame:GetPartyMemberFrame(i)
                or PartyFrame["MemberFrame" .. i]
            Register(member)
        end
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
        RestoreFrame(PlayerFrame)
    end
    discover()
    for frame in pairs(frames) do Apply(frame) end
    if hoveredFrame and frames[hoveredFrame] then ShowFrameTooltip(hoveredFrame) end
end
local function Queue()
    if queued or not ready or InCombatLockdown() then return end
    queued = true
    C_Timer.After(0, function() queued = false; refresh() end)
end
A.GetBindings = function() return bindings end
A.GetPlayerClass = function() return class end
A.IsSpellLearned = IsLearned
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
A.GetSpellChoices = function(includeUnlearned)
    local categoryByName = {}
    for category, ids in pairs(A.spellCategories) do
        for _, id in ipairs(ids) do
            local name = SpellName(id)
            if name then categoryByName[name] = category end
        end
    end
    local choices, seen = {}, {}
    local function Add(name, id, unlearned)
        if not name or seen[name] or Passive(id, spellDetails[name]) then return end
        seen[name] = true
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id or name)
        choices[#choices + 1] = {label = name, spell = name, spellID = id, action = "spell",
            category = categoryByName[name] or "other", icon = info and info.iconID, unlearned = unlearned == true}
    end
    for _, name in ipairs(A.GetSpells()) do
        local detail = spellDetails[name]
        Add(name, detail and detail.id, false)
    end
    if includeUnlearned then
        for _, id in ipairs(A.classSpells[class] or {}) do
            local name = SpellName(id)
            local detail = name and spellDetails[name]
            Add(name, detail and detail.id or id, name and not IsLearned(name, id))
        end
    end
    local order = {heals = 1, buffs = 2, utility = 3, other = 4}
    table.sort(choices, function(a, b)
        if a.unlearned ~= b.unlearned then return not a.unlearned end
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
            local choice
            for _, item in ipairs(A.GetSpellChoices(AggeHealBotDB.showUnlearned)) do if item.spell == spell then choice = item; break end end
            if not choice then return false end
            AggeHealBotDB.bindings[prefix .. button] = {action = action, spell = spell, spellID = choice.spellID}
        else
            AggeHealBotDB.bindings[prefix .. button] = {action = action}
        end
    end
    -- Keep the displayed bindings consistent with the active secure attributes in combat.
    if not InCombatLockdown() then BuildBindings() end
    Queue()
    return true
end
A.SetOption = function(key, value)
    if optionDefaults[key] == nil then return end
    AggeHealBotDB[key] = value and true or false
    if key == "showUnlearned" then return end
    Queue()
    if InCombatLockdown() then for frame in pairs(frames) do UpdateCombatWatch(frame) end end
end
A.ResetBindings = function()
    wipe(AggeHealBotDB.bindings)
    if not InCombatLockdown() then BuildBindings() end
    Queue()
end
A.ResetOptions = function()
    for key, value in pairs(optionDefaults) do AggeHealBotDB[key] = value end
    AggeHealBotDB.paladinBlessings = nil
    Queue()
    if InCombatLockdown() then for frame in pairs(frames) do UpdateCombatWatch(frame) end end
end
A.GetPaladinRule = function(targetClass)
    local rule = AggeHealBotDB.paladinBlessings and AggeHealBotDB.paladinBlessings[targetClass]
    return (rule == "off" or A.paladinBlessings[rule]) and rule or "auto"
end
A.SetPaladinRule = function(targetClass, rule)
    if class ~= "PALADIN" or (rule ~= "auto" and rule ~= "off" and not A.paladinBlessings[rule]) then return false end
    local valid
    for _, token in ipairs(A.paladinClasses) do if token == targetClass then valid = true end end
    if not valid then return false end
    AggeHealBotDB.paladinBlessings = AggeHealBotDB.paladinBlessings or {}
    AggeHealBotDB.paladinBlessings[targetClass] = rule ~= "auto" and rule or nil
    wipe(rejectedBuffs)
    Queue()
    return true
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
        Print(A.version .. " | " .. n .. " stock frames registered | buffs " .. (AggeHealBotDB.smartBuffs and "on" or "off"))
    else ShowSettings() end
end
local eventFrame = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "UNIT_FACTION", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "MODIFIER_STATE_CHANGED", "SPELLS_CHANGED", "UNIT_AURA", "UNIT_HEALTH", "UNIT_POWER_UPDATE", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "UNIT_FLAGS", "UNIT_CONNECTION", "INCOMING_RESURRECT_CHANGED", "UNIT_PET", "UI_ERROR_MESSAGE", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED"}) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event, arg, message, castGUID, spellID)
    if event == "ADDON_LOADED" and arg == ADDON then
        AggeHealBotDB = AggeHealBotDB or {}
        for key, value in pairs(optionDefaults) do
            if AggeHealBotDB[key] == nil then AggeHealBotDB[key] = value end
        end
        AggeHealBotDB.watchNPCs = nil
        AggeHealBotDB.bindings = AggeHealBotDB.bindings or {}
    elseif event == "PLAYER_LOGIN" then
        local token
        token, class = UnitClass("player")
        ready = true
        BuildBindings()
        refresh()
        -- Movement and secrecy transitions need not emit UNIT_AURA. Poll
        -- access/range, rescanning only when either state changes.
        local auraRestrictions = AuraQueryRestricted(C_Secrets and C_Secrets.ShouldAurasBeSecret)
        C_Timer.NewTicker(0.2, function()
            if InCombatLockdown() then
                local restricted = AuraQueryRestricted(C_Secrets and C_Secrets.ShouldAurasBeSecret)
                if restricted ~= auraRestrictions then
                    auraRestrictions = restricted
                    for frame in pairs(frames) do UpdateCombatWatch(frame) end
                end
                return
            end
            -- Secrecy can change without a combat/aura event. Clear stale
            -- prompts on restriction and resume scanning when access returns.
            local restricted = AuraQueryRestricted(C_Secrets and C_Secrets.ShouldAurasBeSecret)
            if restricted ~= auraRestrictions then
                auraRestrictions = restricted
                Queue()
                return
            end
            if hoveredFrame and frames[hoveredFrame] then
                RefreshHint(hoveredFrame)
                ShowFrameTooltip(hoveredFrame)
            end
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
        Print("v" .. A.version .. " loaded. /ahb for bindings and settings.")
    elseif ready then
        if event == "UNIT_POWER_UPDATE" or event == "SPELL_UPDATE_USABLE" or event == "SPELL_UPDATE_COOLDOWN" then
            if InCombatLockdown() or (event == "UNIT_POWER_UPDATE" and (secret(arg) or arg ~= "player")) then return end
            -- Mana and cooldown ticks update hints, not aura scans or secure
            -- bindings. Only roster, aura and priority changes need a rebuild.
            for frame in pairs(frames) do RefreshHint(frame) end
            if hoveredFrame then ShowFrameTooltip(hoveredFrame) end
            return
        end
        if event == "UNIT_HEALTH" then
            if InCombatLockdown() or secret(arg) then return end
            local dead = ReadFlag(UnitIsDeadOrGhost, arg)
            local changed = false
            for frame, state in pairs(frames) do
                if Unit(frame) == arg and (state.unitDead ~= dead
                    or state.healingFirst ~= (state.canHealFirst and A.NeedsHealing(arg))) then changed = true; break end
            end
            if not changed then return end
        end
        if event == "PLAYER_TARGET_CHANGED" and A.targetButton then
            -- Never leave a previous target's badge/evidence on the new one.
            pendingBuffAttempt = nil
            A.UpdateBuffIndicator(A.targetButton)
            if hoveredFrame == A.targetButton and addonTooltip then addonTooltip:Hide() end
        end
        if event == "UI_ERROR_MESSAGE" then
            if not pendingBuffAttempt or InCombatLockdown() or secret(arg) or secret(message) then return end
            local attempt = pendingBuffAttempt
            pendingBuffAttempt = nil
            if GetTime() - attempt.time > 1 or UnitKey(attempt.unit) ~= attempt.guid then return end
            local errorName = GetGameMessageInfo and GetGameMessageInfo(arg)
            if secret(errorName) then return end
            local bounced = errorName == "SPELL_FAILED_AURA_BOUNCED" or errorName == "ERR_SPELL_FAILED_AURA_BOUNCED"
                or (SPELL_FAILED_AURA_BOUNCED and message == SPELL_FAILED_AURA_BOUNCED)
                or (ERR_SPELL_FAILED_AURA_BOUNCED and message == ERR_SPELL_FAILED_AURA_BOUNCED)
            if bounced then
                rejectedBuffs[attempt.guid] = rejectedBuffs[attempt.guid] or {}
                rejectedBuffs[attempt.guid][attempt.spell] = attempt.evidence or {}
                Queue()
            end
            return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            if arg == "player" then pendingBuffAttempt = nil end
            return
        end
        if event == "UNIT_SPELLCAST_SENT" then
            if arg == "player" and pendingBuffAttempt and SpellName(spellID) ~= pendingBuffAttempt.spell then pendingBuffAttempt = nil end
            return
        end
        if event == "PLAYER_REGEN_DISABLED" then
            pendingBuffAttempt = nil
            A.HideBuffIndicators()
            for frame in pairs(frames) do UpdateCombatWatch(frame) end
            if hoveredFrame then ShowFrameTooltip(hoveredFrame) end
            return
        end
        if InCombatLockdown() and (event == "MODIFIER_STATE_CHANGED" or event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED") then
            for frame in pairs(frames) do UpdateCombatWatch(frame) end
            if hoveredFrame then ShowFrameTooltip(hoveredFrame) end
        end
        if event == "SPELLS_CHANGED" then
            wipe(rejectedBuffs)
            pendingBuffAttempt = nil
            if not InCombatLockdown() then BuildBindings() end
        end
        if event == "PLAYER_REGEN_ENABLED" then BuildBindings() end
        -- Never inspect auras, unit health, or protected attributes in combat.
        if not InCombatLockdown() then Queue() end
        if event == "MODIFIER_STATE_CHANGED" and hoveredFrame then ShowFrameTooltip(hoveredFrame) end
    end
end)
