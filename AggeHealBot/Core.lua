local ADDON, A = ...
local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
A.version = getMetadata and getMetadata(ADDON, "Version") or "dev"
local frames, hooks, names, learned, bindings, hookedFrames = {}, {}, {}, {}, {}, {}
local ready, queued, refresh, discover, Apply, Queue
A.externalFrames = {}
local class
local spellDetails = {}
local spellRanks = {}
local openUnitMenu, openUnitMenuUnit
local raidControlsHiddenByUs = false
local raidControlsParent, raidControlsHolder, raidControlsWasShown
local rejectedBuffs, pendingBuffAttempt = {}, nil
local hoveredFrame, hoveredRegion, addonTooltip
local hoverHooks = {}
local targetVisibilityDrivers = {}
local optionDefaults = {
    smartBuffs = true, cureWatch = true, combatCures = true,
    combatResurrection = false, resurrectionWatch = true, showPaladinDebug = false,
    playerFrame = true, targetFrame = true, targetOfTargetFrame = true, focusFrame = true,
    rightClickMenu = false, hideRaidControls = true, hidePartyControls = true,
    showUnlearned = false,
    showAllRanks = false, showMinimap = true, targetOnCast = false,
    showTooltip = true, replaceBlizzardTooltip = false,
    watchPets = true, buffPets = false, hovercast = false,
    buffsBeforeCures = false, watcherModifiers = false,
}
local function secret(v) return issecretvalue and issecretvalue(v) end
local function ReadFlag(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if ok and not secret(value) then return value end
end
local function WatcherVisible()
    return AggeHealBotDB.watcherModifiers or not (IsModifierKeyDown and IsModifierKeyDown())
end
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
local function SpellRank(id, fallback)
    local api = C_Spell and C_Spell.GetSpellSubtext
    local ok, rank, unused
    if api then ok, rank = pcall(api, id)
    elseif GetSpellInfo then ok, unused, rank = pcall(GetSpellInfo, id) end
    if not ok or secret(rank) or type(rank) ~= "string" or rank == "" then rank = fallback end
    if not secret(rank) and type(rank) == "string" and rank:match("%d+") then return rank end
end
local function ReadSpellbook()
    wipe(learned)
    wipe(spellDetails)
    wipe(spellRanks)
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
                        local subtext
                        if C_SpellBook.GetSpellBookItemName then
                            local ok, _, value = pcall(C_SpellBook.GetSpellBookItemName, slot, bank)
                            if ok then subtext = value end
                        end
                        spellRanks[item.spellID] = {id = item.spellID, name = name, rank = SpellRank(item.spellID, subtext),
                            passive = item.isPassive == true, future = future}
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
                local name, rank = GetSpellBookItemName(slot, "spell")
                if name then
                    learned[name] = true
                    local _, id = GetSpellBookItemInfo(slot, "spell")
                    spellDetails[name] = {id = id, passive = IsPassiveSpell and IsPassiveSpell(slot, "spell") or false}
                    if id then spellRanks[id] = {id = id, name = name, rank = SpellRank(id, rank), passive = spellDetails[name].passive} end
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
local function IsLearned(name, spellID, exactRank)
    if exactRank then
        local rank = spellRanks[spellID]
        return (rank and not rank.future) or ReadFlag(IsPlayerSpell, spellID) == true
    end
    if learned[name] or (spellID and IsPlayerSpell and IsPlayerSpell(spellID)) then return true end
    for id, spellName in pairs(names) do
        if spellName == name and IsPlayerSpell and IsPlayerSpell(id) then return true end
    end
    return false
end
local function ResurrectionSpell(inCombat)
    local ids = (inCombat and A.combatResurrections or A.resurrections)[class] or {}
    local saved = AggeHealBotDB.resurrectionRanks
    local choice = saved and saved.class == class and saved[inCombat and "combat" or "normal"]
    if choice then
        local name = SpellName(choice.id)
        if name and IsLearned(name, choice.id, true) then return name .. "(" .. choice.rank .. ")", choice.id end
        return nil, choice.id
    end
    local name = Resolve(ids)
    return name, name and spellDetails[name] and spellDetails[name].id or ids[1]
end
function A.GetMouseButtons()
    local list, seen = {1, 2, 3, 4, 5}, {}
    local db = AggeHealBotDB or {}
    for number, enabled in pairs(type(db.extraMouseButtons) == "table" and db.extraMouseButtons or {}) do
        if enabled and type(number) == "number" and number % 1 == 0 and number > 5 and number <= A.maxMouseButtons then seen[number] = true end
    end
    for key in pairs(db.bindings or {}) do
        local number = type(key) == "string" and tonumber(key:match("(%d+)$"))
        if number and number > 5 and number <= A.maxMouseButtons then
            for _, mod in ipairs(A.modifiers) do if key == mod.prefix .. number then seen[number] = true; break end end
        end
    end
    for number = 6, A.maxMouseButtons do if seen[number] then list[#list + 1] = number end end
    return list
end
local function BuildBindings()
    ReadSpellbook()
    wipe(bindings)
    local defaults = {}
    for _, list in ipairs({A.presets[class] or {}, A.common}) do
        for _, b in ipairs(list) do
            local spell = type(b[4]) == "table" and Resolve(b[4]) or nil
            local expected = type(b[4]) == "table" and CandidateName(b[4]) or nil
            local spellID
            if type(b[4]) == "table" then
                for _, id in ipairs(b[4]) do
                    if SpellName(id) == (spell or expected) then spellID = id; break end
                end
            end
            defaults[b[2] .. b[3]] = {
                label = b[1], prefix = b[2], button = b[3],
                action = type(b[4]) == "string" and b[4] or "spell",
                spell = spell, expected = expected, spellID = spellID,
            }
        end
    end
    local buttonNumbers = A.GetMouseButtons()
    for _, mod in ipairs(A.modifiers) do
        for _, button in ipairs(buttonNumbers) do
            local key = mod.prefix .. button
            local b = defaults[key] or {label = mod.label .. A.buttons[button], prefix = mod.prefix,
                button = button, action = (key == "1" and "target" or "none")}
            local custom = AggeHealBotDB.bindings[key]
            if custom then
                local name = custom.spellID and SpellName(custom.spellID) or custom.spell
                b.action = custom.action
                local castName = name and custom.rank and (name .. "(" .. custom.rank .. ")") or name
                b.spellID, b.rank = custom.spellID, custom.rank
                b.spell = custom.action == "spell" and name and IsLearned(name, custom.spellID, custom.rank ~= nil) and castName or nil
                b.expected = custom.action == "spell" and castName or nil
            end
            -- An unsupported/missing spell identity is not an unlearned spell.
            if b.action == "spell" and not b.spell and not b.expected then b.action = "none" end
            bindings[#bindings + 1] = b
        end
    end
end
local function Unit(frame)
    local external = A.externalFrames[frame]
    local unit
    if external then unit = external.GetUnit() else unit = frame:GetAttribute("unit") end
    if secret(unit) then return end
    if not unit and not external then unit = frame.unit end
    if secret(unit) or type(unit) ~= "string" then return end
    return unit
end
local function TargetUnit(frame)
    local external = A.externalFrames[frame]
    if external then return external.fixedUnit end
    if frame == A.targetButton then return "target" end
    if frame == A.targetOfTargetButton then return "targettarget" end
    if frame == A.focusButton then return "focus" end
end
local function TargetVisual(frame)
    local external = A.externalFrames[frame]
    if external then return external.visual end
    if frame == A.targetButton then return TargetFrame end
    if frame == A.targetOfTargetButton then return TargetFrameToT or (TargetFrame and TargetFrame.totFrame) end
    if frame == A.focusButton then return FocusFrame end
end
local function Eligible(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or frame.namePlateFrame
        or not frame.GetAttribute or not frame.RegisterForClicks then return false end
    local name = frame:GetName() or ""
    local normalPartyMember = PartyFrame and frame.GetParent and frame:GetParent() == PartyFrame
    if not (A.externalFrames[frame] or (A.IsPetFrame and A.IsPetFrame(frame)) or TargetUnit(frame) or normalPartyMember or name == "PlayerFrame" or name:match("^PartyMemberFrame%d+$")
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
local function CureWatchDefaults()
    local result, byName = {}, {}
    for _, entry in ipairs(A.dispels[class] or {}) do
        local name = SpellName(entry[1]) or tostring(entry[1])
        local group = byName[name]
        if not group then
            group = {entry[1]}
            group.ids, group.types = {}, {}
            byName[name] = group
            result[#result + 1] = group
        end
        group.ids[#group.ids + 1] = entry[1]
        for index = 2, #entry do
            if not group.types[entry[index]] then
                group[#group + 1], group.types[entry[index]] = entry[index], true
            end
        end
    end
    return result
end
local function BuffWatchGroups(includeDisabled, kind)
    local defaults = kind == "cures" and CureWatchDefaults() or A.buffs[class] or {}
    local saved = AggeHealBotDB[kind == "cures" and "cureWatchRules" or "buffWatch"]
    if type(saved) ~= "table" or saved.class ~= class then saved = nil end
    local byID, result, seen = {}, {}, {}
    for _, group in ipairs(defaults) do byID[group[1]] = group end
    local function Add(id)
        if not byID[id] or seen[id] then return end
        seen[id] = true
        if includeDisabled or not (saved and type(saved.disabled) == "table" and saved.disabled[id]) then
            result[#result + 1] = byID[id]
        end
    end
    if saved and type(saved.order) == "table" then for _, id in ipairs(saved.order) do Add(id) end end
    for _, group in ipairs(defaults) do Add(group[1]) end
    return result
end
local function BuffTargetRule(id)
    local saved = AggeHealBotDB.buffWatch
    return type(saved) == "table" and saved.class == class and type(saved.targets) == "table" and saved.targets[id] or nil
end
A.buffTargetRoles = {
    {"healers", "Healers"}, {"tanks", "Tanks"}, {"dps", "DPS"},
}
A.buffTargetGroups = {
    {"casters", "Casters"}, {"melee", "Melee"},
    {"mana", "Mana users"}, {"rage", "Rage users"}, {"energy", "Energy users"},
}
A.buffTargetClasses = {
    casters = {"MAGE", "PRIEST", "SHAMAN", "WARLOCK"},
    melee = {"PALADIN", "ROGUE", "WARRIOR"},
}
A.buffTargetDruidModes = {casters = "casters+druid", melee = "melee+druid"}
local druidModeBase = {["casters+druid"] = "casters", ["melee+druid"] = "melee"}
local powerGroups = {mana = 0, rage = 1, energy = 3}
local roleGroups = {healers = "HEALER", tanks = "TANK", dps = "DAMAGER"}
local function IsBuffTargetMode(mode)
    if mode == "everyone" or mode == "self" or mode == "selected" then return true end
    if A.buffTargetClasses[mode] or druidModeBase[mode] or powerGroups[mode] ~= nil or roleGroups[mode] then return true end
    for _, token in ipairs(A.paladinClasses) do
        if mode == "class:" .. token then return true end
    end
    return false
end
local function BuffTargetAllowed(unit, group)
    local rule = BuffTargetRule(group[1])
    if group.selfOnly or (rule and rule.mode == "self") then return ReadFlag(UnitIsUnit, unit, "player") == true end
    if rule and rule.mode == "selected" then
        local key = ReadFlag(UnitIsUnit, unit, "player") == true and "self" or ReadFlag(UnitGUID, unit)
        return type(key) == "string" and type(rule.players) == "table" and rule.players[key] ~= nil
    end
    local mode = rule and rule.mode
    if not mode or mode == "everyone" then return true end
    local role = roleGroups[mode]
    if role then return ReadFlag(UnitGroupRolesAssigned, unit) == role end
    local power = powerGroups[mode]
    if power then return ReadFlag(UnitPowerType, unit) == power end
    local ok, _, token = pcall(UnitClass, unit)
    if not ok or secret(token) or type(token) ~= "string" then return false end
    local baseMode = druidModeBase[mode]
    if baseMode and token == "DRUID" then return true end
    local classes = A.buffTargetClasses[baseMode or mode]
    if classes then
        for _, memberClass in ipairs(classes) do
            if token == memberClass then return true end
        end
        return false
    end
    return mode == "class:" .. token
end
local function MissingBuff(unit, pet)
    if not AggeHealBotDB.smartBuffs or not unit or ReadFlag(UnitExists, unit) ~= true
        or ReadFlag(UnitCanAssist, "player", unit) ~= true or ReadFlag(UnitIsDeadOrGhost, unit) ~= false then return end
    local present, evidence, auras = HelpfulAuras(unit)
    if not present then return end
    local guid = UnitKey(unit)
    local groups = class == "PALADIN" and PaladinBuffGroups(unit) or BuffWatchGroups()
    for _, group in ipairs(groups) do
        local definition = A.buffRanks[group[1]]
        -- Only explicitly supported spells can be watched on pets. Player
        -- recipient filters apply to players, independently of Buff pets.
        local allowed = (pet and group.petEligible and not group.selfOnly)
            or (not pet and BuffTargetAllowed(unit, group))
        local name = allowed and (Resolve({group[1]}) or (definition and Resolve(definition.ranks)))
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
    if not unit or ReadFlag(UnitExists, unit) ~= true or ReadFlag(UnitIsConnected, unit) ~= true then return false end
    if ReadFlag(UnitIsUnit, unit, "player") == true then return true end
    local result = ReadFlag(C_Spell and C_Spell.IsSpellInRange or IsSpellInRange, spell, unit)
    return result == true or result == 1
end
local function WatchAllowed(unit)
    if not unit then return false end
    return ReadFlag(UnitIsPlayer, unit) == true or (AggeHealBotDB.watchPets and A.IsPetUnit and A.IsPetUnit(unit)) or false
end
local function ResurrectionCandidate(unit, spell)
    if not spell or not unit or unit == "player" or ReadFlag(UnitIsPlayer, unit) ~= true then return end
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
    for priority, entry in ipairs(BuffWatchGroups(false, "cures")) do
        local spell = Resolve(entry.ids or {entry[1]})
        if spell then
            for i = 2, #entry do
                if not available[entry[i]] then available[entry[i]] = {spell, entry[1], priority} end
            end
        end
    end
    if not next(available) then return end
    local auras = ReadAuras(unit, "HARMFUL", allowCombat)
    if not auras then return end
    local candidate, debuff
    local custom = type(AggeHealBotDB.cureWatchRules) == "table" and AggeHealBotDB.cureWatchRules.class == class
    for _, aura in ipairs(auras) do
        if secret(aura.dispelName) or secret(aura.name) then return end
        local cure = aura.dispelName and available[aura.dispelName]
        if cure and (not candidate or (custom and cure[3] < candidate[3])) then candidate, debuff = cure, aura.name end
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
    local visible = WatcherVisible()
    A.UpdateBuffIndicator(frame, visible and spell or nil, id, kind)
end
local function HealOutOfRange(spell, unit)
    if not unit then return true end
    if ReadFlag(UnitExists, unit) == false or ReadFlag(UnitIsConnected, unit) == false then return true end
    if ReadFlag(UnitIsUnit, unit, "player") == true then return false end
    local result = ReadFlag(C_Spell and C_Spell.IsSpellInRange or IsSpellInRange, spell, unit)
    -- Spells without a conventional range (e.g. self-centered area spells)
    -- can return nil. The explicit-target macro still prevents a target cursor.
    return result == false or result == 0
end
local function CastEnding(unit)
    return "\n/stopspelltarget" .. (AggeHealBotDB.targetOnCast and ("\n/target [@" .. unit .. ",help]") or "")
end
local function CastMacro(spell, combatSpell, explicitUnit)
    if not spell then return "nil" end
    local target = explicitUnit or "mouseover"
    -- The cursor is on this unit frame. No target/player fallback clause.
    -- Secure cleanup also works in combat, when addon range checks cannot run.
    if combatSpell and combatSpell ~= spell then
        return "/cast [combat,@" .. target .. ",help,nodead] " .. combatSpell
            .. "; [nocombat,@" .. target .. ",help,nodead] " .. spell .. CastEnding(target)
    end
    return "/cast [@" .. target .. ",help,nodead] " .. spell .. CastEnding(target)
end
local function TargetMacro(frame)
    -- Native UnitFrame click-binding routing can discard type="target" when
    -- no Blizzard interaction binding exists for this modifier/button. An
    -- explicit secure macro keeps targeting within our own saved bindings.
    -- A distant group member may not resolve as mouseover. Use the frame's
    -- actual unit token so selecting someone never depends on spell range.
    local unit = frame == PlayerFrame and "player" or TargetUnit(frame) or Unit(frame)
    if not unit then return end
    return "/target [@" .. unit .. ",exists]"
end
local function MenuButton(frame)
    local state = frames[frame]
    if not state.menuButton then
        -- Delegate to the secure action handler, not an addon Lua opener. Even
        -- ExecuteAttribute/securecallfunction from our OnClick can taint menu
        -- descriptions and block protected choices such as SetPVP later.
        -- SecureActionButtonTemplate also avoids UnitFrame's interaction filter.
        local button = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
        button:SetSize(1, 1)
        button:SetPoint("CENTER")
        button:EnableMouse(false)
        button:RegisterForClicks("AnyUp")
        -- Secure click delegation sends Click(button) without a down edge,
        -- even though the originating frame responds on mouse press.
        button:SetAttribute("useOnKeyDown", false)
        button:SetAttribute("*type*", "togglemenu")
        button:SetAttribute("checkselfcast", false)
        button:SetAttribute("checkfocuscast", false)
        local closeOnPress
        button:SetScript("PreClick", function()
            if addonTooltip then addonTooltip:Hide() end
            local manager = Menu and Menu.GetManager and Menu.GetManager()
            closeOnPress = manager and openUnitMenu and manager:GetOpenMenu() == openUnitMenu
                and openUnitMenuUnit == Unit(frame)
        end)
        button:SetScript("PostClick", function()
            local manager = Menu and Menu.GetManager and Menu.GetManager()
            if not manager then return end
            if closeOnPress then
                manager:CloseMenus()
                openUnitMenu, openUnitMenuUnit = nil, nil
            else
                openUnitMenu = manager:GetOpenMenu()
                openUnitMenuUnit = openUnitMenu and Unit(frame) or nil
            end
        end)
        state.menuButton = button
    end
    -- Apply runs outside combat, including after stock frames change units.
    if A.externalFrames[frame] then
        state.menuButton:SetAttribute("unit", nil)
        state.menuButton:SetAttribute("useparent-unit", true)
        state.menuButton:SetAttribute("useparent-unitsuffix", true)
    else state.menuButton:SetAttribute("unit", Unit(frame)) end
    return state.menuButton
end
function A.ConfigureHoverAction(button, frame, binding)
    local action, spell = binding.action, binding.spell
    button:SetAttribute("*type*", nil)
    button:SetAttribute("*macrotext*", nil)
    button:SetAttribute("*clickbutton*", nil)
    UnregisterAttributeDriver(button, "type")
    if action == "spell" then
        if not spell then button:SetAttribute("type", "none"); return false end
        local resurrection = false
        for _, ids in ipairs({A.resurrections[class] or {}, A.combatResurrections[class] or {}}) do
            for _, id in ipairs(ids) do if id == binding.spellID then resurrection = true end end
        end
        local target = TargetUnit(frame) or "mouseover"
        local macro = resurrection and ("/cast [@" .. target .. ",help,dead] " .. spell .. CastEnding(target))
            or CastMacro(spell, nil, TargetUnit(frame))
        button:SetAttribute("*macrotext*", macro)
        RegisterAttributeDriver(button, "type", "[combat] macro; " .. (HealOutOfRange(spell, Unit(frame)) and "none" or "macro"))
    elseif action == "settings" or action == "togglemenu" then
        button:SetAttribute("type", "click")
        button:SetAttribute("*clickbutton*", action == "settings" and A.settingsButton or MenuButton(frame))
    elseif action == "target" then
        button:SetAttribute("type", "target")
    elseif action == "assist" then
        button:SetAttribute("type", "assist")
    else button:SetAttribute("type", "none"); return false end
    return true
end
local function BindingAction(frame, binding)
    if (frame == PlayerFrame or (TargetUnit(frame) and (not A.externalFrames[frame] or A.externalFrames[frame].option))) and binding.prefix == "" and binding.button == 2 and AggeHealBotDB.rightClickMenu then return "togglemenu" end
    return binding.action
end
local function FindBuffShortcut(frame, spell)
    local function Matches(binding)
        return binding.spell and (binding.spell == spell
            or (binding.rank and binding.spell == spell .. "(" .. binding.rank .. ")"))
    end
    for _, binding in ipairs(bindings) do
        if BindingAction(frame, binding) == "spell" and Matches(binding) then
            return binding.label, binding.spell
        end
    end
    if AggeHealBotDB.hovercast and A.GetHoverKeys then
        for _, key in ipairs(A.GetHoverKeys()) do
            local binding = A.GetHoverBinding(key)
            if binding.action == "spell" and Matches(binding) then return key, binding.spell end
        end
    end
end
local function SuppressNativeTooltip()
    local frame = hoveredFrame
    if not frame or not frames[frame] or not AggeHealBotDB.showTooltip or not AggeHealBotDB.replaceBlizzardTooltip
        or not addonTooltip or not addonTooltip:IsShown() then return end
    local visual = TargetVisual(frame) or frame
    if GameTooltip:IsOwned(frame) or GameTooltip:IsOwned(visual)
        or (hoveredRegion and GameTooltip:IsOwned(hoveredRegion)) then GameTooltip:Hide() end
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
    if not AggeHealBotDB.showTooltip and addonTooltip then addonTooltip:Hide() end
    local replaceNative = AggeHealBotDB.showTooltip and AggeHealBotDB.replaceBlizzardTooltip
    if unit and not replaceNative then
        -- Leave Blizzard's unit details intact, including its normal live
        -- refreshes; our binding information lives in a separate panel.
        local ownsResourceTip = hoveredFrame == frame and hoveredRegion and hoveredRegion ~= frame
            and GameTooltip:IsOwned(hoveredRegion)
        local needsAnchor = not GameTooltip:IsOwned(frame)
        if not ownsResourceTip and GameTooltip.GetAnchorType then
            local ok, kind = pcall(GameTooltip.GetAnchorType, GameTooltip)
            if ok and not secret(kind) and kind ~= "ANCHOR_NONE" then needsAnchor = true end
        end
        if needsAnchor and not ownsResourceTip then
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
    if not AggeHealBotDB.showTooltip then return end
    -- Use an addon-owned tooltip; native unit-data refreshes must not replace
    -- its binding lines. Suppression is limited to this hovered unit's owners.
    if not addonTooltip then
        addonTooltip = CreateFrame("GameTooltip", "AggeHealBotTooltip", UIParent, "GameTooltipTemplate")
        addonTooltip:SetFrameStrata("TOOLTIP")
        addonTooltip:SetFrameLevel(100)
        addonTooltip:EnableMouse(false)
    end
    if replaceNative and not hooks.nativeTooltipShow then
        GameTooltip:HookScript("OnShow", SuppressNativeTooltip)
        hooks.nativeTooltipShow = true
    end
    local tooltip = addonTooltip
    tooltip:SetOwner(frame, "ANCHOR_NONE")
    local visual = TargetVisual(frame) or frame
    local content = visual.TargetFrameContent and visual.TargetFrameContent.TargetFrameContentMain
    local external = A.externalFrames[frame]
    local anchor = (external and external.tooltipAnchor) or visual.healthbar or visual.healthBar or visual.HealthBar
        or (content and content.HealthBarsContainer and content.HealthBarsContainer.HealthBar) or visual
    if frame == A.targetButton or frame == A.focusButton then
        anchor = (visual.GetPortrait and visual:GetPortrait()) or visual.portrait
            or (frame == A.focusButton and _G.FocusFramePortrait or _G.TargetFramePortrait) or anchor
    end
    tooltip:ClearAllPoints()
    tooltip:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 8, 8)
    tooltip:SetClampedToScreen(true)
    local name = unit and UnitName and UnitName(unit)
    if secret(name) or type(name) ~= "string" then name = "Unit" end
    -- Reset reused line-two regions before an NPC/binding row takes their place.
    local oldLeft = _G.AggeHealBotTooltipTextLeft2
    local oldRight = _G.AggeHealBotTooltipTextRight2
    if oldLeft and oldRight then
        oldLeft:SetAlpha(1)
        if GameTooltipText then oldLeft:SetFontObject(GameTooltipText); oldRight:SetFontObject(GameTooltipText) end
        oldRight:ClearAllPoints()
        oldRight:SetJustifyH("RIGHT")
        oldRight:SetPoint("RIGHT", tooltip, "RIGHT", -10, 0)
        oldRight:SetPoint("TOP", oldLeft, "TOP", 0, 0)
    end
    if tooltip.ahbInlineSpec then tooltip.ahbInlineSpec:Hide() end
    if tooltip.ahbHeaderParts then
        for _, text in pairs(tooltip.ahbHeaderParts) do text:Hide() end
    end
    tooltip:ClearLines()
    local r, g, b = 1, 0.82, 0
    local classLabel
    if unit and UnitClass and UnitIsPlayer then
        local playerOK, isPlayer = pcall(UnitIsPlayer, unit)
        local classOK, localizedClass, classToken = pcall(UnitClass, unit)
        if playerOK and not secret(isPlayer) and isPlayer == true and classOK
            and not secret(localizedClass) and type(localizedClass) == "string" then classLabel = localizedClass end
        if playerOK and not secret(isPlayer) and isPlayer == true and classOK
            and not secret(classToken) and type(classToken) == "string" then
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            if color then r, g, b = color.r, color.g, color.b end
        end
    end
    local title = name
    local levelText
    if unit and UnitLevel then
        local ok, level = pcall(UnitLevel, unit)
        if ok and not secret(level) and type(level) == "number" then
            if level > 0 then levelText = tostring(level)
            elseif level == -1 then levelText = "??" end
        end
    end
    if levelText then title = name .. " |cffffffff·|r |cffffd100Lv" .. levelText .. "|r" end
    tooltip:AddDoubleLine(title, "AggeHealBot", r, g, b, 0.5, 1, 0.7)
    local heading = _G.AggeHealBotTooltipTextLeft1
    local label = _G.AggeHealBotTooltipTextRight1
    if heading and GameTooltipHeaderText then
        heading:SetAlpha(1)
        heading:SetFontObject(GameTooltipHeaderText)
        heading:SetTextColor(r, g, b)
    end
    if label and GameFontHighlightSmall then
        label:SetFontObject(GameFontHighlightSmall)
        label:SetTextColor(0.5, 1, 0.7)
    end
    local spec = A.GetUnitSpec(unit)
    local details = spec
    if classLabel and details then tooltip:AddDoubleLine(details, classLabel, 0.8, 0.8, 0.8, r, g, b)
    elseif classLabel then
        -- An empty spec column has zero text height. Anchoring the larger class
        -- to it pulls the class into the name row; let the tooltip lay out a
        -- real class-only line when inspection data is not available.
        tooltip:AddLine(classLabel, r, g, b)
        local classOnly = _G.AggeHealBotTooltipTextLeft2
        if classOnly and GameFontHighlight then classOnly:SetFontObject(GameFontHighlight) end
    elseif details then tooltip:AddLine(details, 0.8, 0.8, 0.8) end
    local specText = classLabel and details and _G.AggeHealBotTooltipTextLeft2
    local classText = classLabel and details and _G.AggeHealBotTooltipTextRight2
    if specText and classText then
        if GameFontHighlightSmall then specText:SetFontObject(GameFontHighlightSmall) end
        if GameFontHighlight then classText:SetFontObject(GameFontHighlight) end
        classText:SetTextColor(r, g, b)
    end
    local prefix = (IsAltKeyDown and IsAltKeyDown() and "alt-" or "")
        .. (IsControlKeyDown and IsControlKeyDown() and "ctrl-" or "")
        .. (IsShiftKeyDown and IsShiftKeyDown() and "shift-" or "")
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
    elseif not InCombatLockdown() and state.buffShortcut and WatcherVisible() then
        tooltip:AddDoubleLine("Missing: " .. state.boundBuff, state.buffShortcut, 0.65, 1, 0.65, 1, 0.82, 0.35)
    elseif prefix == "" and not InCombatLockdown() and state.nextBuff then
        tooltip:AddLine((state.resurrection and "Resurrect with left click: " or state.cure and "Cure with left click: " or "Next left click: ") .. state.nextBuff, 0.65, 1, 0.65)
        if state.cure then tooltip:AddLine(state.cure, 1, 0.6, 0.5) end
    elseif prefix == "" and not InCombatLockdown() and state.blockedBuff then
        tooltip:AddLine(state.blockedBuff .. ": " .. (A.CastProblem(state.blockedBuff, unit) or "Range unavailable"), 1, 0.4, 0.3)
        tooltip:AddLine("Left click blocked until range is confirmed.", 1, 0.7, 0.4)
    elseif prefix ~= "" and AggeHealBotDB.watcherModifiers and not InCombatLockdown() and state.nextBuff then
        tooltip:AddLine("Watcher: " .. state.nextBuff, 0.65, 1, 0.65)
    elseif prefix == "" and not InCombatLockdown() and state.healingFirst then
        tooltip:AddLine("Healing first: below 90% health.", 0.65, 1, 0.65)
    end
    for _, b in ipairs(bindings) do
        if b.prefix == prefix and (b.button <= 5 or b.action ~= "none") then
            local action = BindingAction(frame, b)
            local value = action == "spell" and (b.spell or b.expected) or A.actionLabels[action] or action
            if b.button == 1 and prefix == "" and not InCombatLockdown() then value = state.nextBuff or value end
            if b.button == 1 and prefix == "" and InCombatLockdown() and state.combatResActive then value = state.combatResSpell end
            local problem = action == "spell" and b.spell and A.CastProblem(b.button == 1 and prefix == "" and state.nextBuff or b.spell, unit)
            if problem then value = value .. " |cffffb366(" .. problem .. ")|r" end
            tooltip:AddDoubleLine(b.label, value .. (action == "spell" and not b.spell and " (not learned)" or ""), 1, 1, 1, 0.6, 0.9, 0.7)
        end
    end
    if AggeHealBotDB.hovercast and A.GetHoverKeys then
        for _, key in ipairs(A.GetHoverKeys()) do
            local binding = A.GetHoverBinding(key)
            if binding.action ~= "none" then
                local value = binding.spell or binding.expected or A.actionLabels[binding.action]
                tooltip:AddDoubleLine(key, value .. (binding.action == "spell" and not binding.spell and " (not learned)" or ""), 1, 0.82, 0.35, 0.6, 0.9, 0.7)
            end
        end
    end
    tooltip:Show()
    SuppressNativeTooltip()
    if heading and levelText then
        if not tooltip.ahbHeaderParts then
            tooltip.ahbHeaderParts = {
                name = tooltip:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText"),
                label = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
                value = tooltip:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText"),
            }
        end
        local parts = tooltip.ahbHeaderParts
        parts.name:ClearAllPoints()
        parts.name:SetPoint("BOTTOMLEFT", heading, "BOTTOMLEFT", 0, 0)
        parts.name:SetText(name .. " |cffffffff·|r")
        parts.name:SetTextColor(r, g, b)
        parts.label:ClearAllPoints()
        parts.label:SetPoint("BOTTOMLEFT", parts.name, "BOTTOMRIGHT", 4, 2)
        parts.label:SetText("Lv")
        parts.label:SetTextColor(1, 0.82, 0)
        parts.value:ClearAllPoints()
        parts.value:SetPoint("BOTTOMLEFT", parts.label, "BOTTOMRIGHT", 1, -2)
        parts.value:SetText(levelText)
        parts.value:SetTextColor(1, 0.82, 0)
        heading:SetAlpha(0)
        for _, text in pairs(parts) do text:Show() end
    end
    if specText and classText then
        classText:ClearAllPoints()
        classText:SetJustifyH("LEFT")
        if details then
            -- Tooltip measurements can become secret. Let the UI anchor to an
            -- unconstrained addon-owned text region; never read its width.
            if not tooltip.ahbInlineSpec then
                tooltip.ahbInlineSpec = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            end
            local inline = tooltip.ahbInlineSpec
            inline:ClearAllPoints()
            inline:SetPoint("BOTTOMLEFT", specText, "BOTTOMLEFT", 0, 0)
            inline:SetText(details)
            inline:SetTextColor(0.8, 0.8, 0.8)
            inline:Show()
            specText:SetAlpha(0)
            classText:SetPoint("BOTTOMLEFT", inline, "BOTTOMRIGHT", 4, -1)
        else
            classText:SetPoint("BOTTOMLEFT", specText, "BOTTOMLEFT", 0, -1)
        end
    end
end
local function RefreshTooltip()
    if not AggeHealBotDB.showTooltip and addonTooltip then addonTooltip:Hide() end
    if hoveredFrame and frames[hoveredFrame] then ShowFrameTooltip(hoveredFrame) end
end
local function HookHover(frame, region)
    if A.RegisterHoverRegion then A.RegisterHoverRegion(frame, region) end
    if not region or not region.HookScript or hoverHooks[region] then return end
    hoverHooks[region] = true
    region:HookScript("OnEnter", function(self)
        if not frames[frame] or (TargetUnit(frame) and not frame:IsShown()) then return end
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
function A.HideFrameHover(frame)
    if hoveredFrame == frame then
        hoveredFrame, hoveredRegion = nil, nil
        if addonTooltip then addonTooltip:Hide() end
        if GameTooltip and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
    end
end
local function RefreshHint(frame)
    local state = frames[frame]
    if not state or InCombatLockdown() then return end
    local reminder = state.boundBuff or state.nextBuff
    local spell = state.boundBuffSpell or reminder
    A.UpdateBuffIndicator(frame, WatcherVisible() and reminder or nil,
        state.nextBuffID, state.watchKind, spell and A.CastProblem(spell, Unit(frame)))
end
Apply = function(frame)
    if not ready or InCombatLockdown() then return end
    if not frames[frame] then
        frames[frame] = {original = {}, bindingDrivers = {}}
    end
    HookHover(frame, frame)
    local visual = TargetVisual(frame) or frame
    local content = visual.TargetFrameContent and visual.TargetFrameContent.TargetFrameContentMain
    HookHover(frame, visual.healthbar or visual.healthBar or visual.HealthBar
        or (content and content.HealthBarsContainer and content.HealthBarsContainer.HealthBar))
    HookHover(frame, visual.manabar or visual.manaBar or visual.ManaBar or visual.powerBar or visual.PowerBar or (content and content.ManaBar))
    local external = A.externalFrames[frame]
    if external then
        for _, region in pairs(external.hoverRegions) do HookHover(frame, region) end
    end
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
                Set(frame, key, action == "target" and not A.externalFrames[frame] and "macro" or action)
            end
        end
        if not (b.prefix == "" and b.button == 1) then
            Set(frame, b.prefix .. "spell" .. b.button, bindingAction == "spell" and (b.spell or "") or nil)
            local macro = bindingAction == "target" and not A.externalFrames[frame] and TargetMacro(frame)
                or bindingAction == "spell" and b.spell and CastMacro(b.spell, nil, TargetUnit(frame)) or nil
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
    local isPlayer = ReadFlag(UnitIsPlayer, unit) == true
    local pet = not isPlayer and (AggeHealBotDB.buffPets or AggeHealBotDB.watchPets) and A.IsPetUnit(unit) or false
    local watches = left.action == "spell" and (isPlayer or (pet and AggeHealBotDB.watchPets))
    local watchesBuffs = left.action == "spell" and (isPlayer or (pet and AggeHealBotDB.buffPets))
    frames[frame].canHealFirst = (watches or watchesBuffs) and heal ~= nil
    frames[frame].healingFirst = frames[frame].canHealFirst and A.NeedsHealing(unit) or false
    if watchesBuffs and not frames[frame].healingFirst then buff, buffID, evidence = MissingBuff(unit, pet) end
    frames[frame].unitDead = ReadFlag(UnitIsDeadOrGhost, unit)
    local normalRes, normalResID = ResurrectionSpell(false)
    local combatRes, combatResID = ResurrectionSpell(true)
    if not watches or not AggeHealBotDB.resurrectionWatch then normalRes, combatRes = nil, nil end
    if not AggeHealBotDB.combatResurrection then combatRes = nil end
    if not isPlayer then normalRes, combatRes = nil, nil end
    local res = ResurrectionCandidate(unit, normalRes or combatRes)
    local cure, cureID, debuff
    if watches and not res then cure, cureID, debuff = CureCandidate(unit) end
    if cure and not (AggeHealBotDB.buffsBeforeCures and buff) then buff, buffID = cure, cureID
    else cure, debuff = nil, nil end
    frames[frame].cure = cure and (debuff or "Removable debuff") or nil
    frames[frame].resurrection = res ~= nil
    if res then buff, buffID = res, normalRes and normalResID or combatResID end
    frames[frame].combatResSpell, frames[frame].combatResID = combatRes, combatResID
    if combatRes and unit and unit ~= "player" then
        RegisterAttributeDriver(frame, "ahb-resurrection", "[@" .. unit .. ",combat,help,dead,party] combat; [@" .. unit .. ",combat,help,dead,raid] combat; none")
    else
        UnregisterAttributeDriver(frame, "ahb-resurrection")
    end
    local state = frames[frame]
    state.boundBuff, state.boundBuffSpell, state.buffShortcut = nil, nil, nil
    if AggeHealBotDB.watcherModifiers and buff and not res and not cure then
        local shortcut, spell = FindBuffShortcut(frame, buff)
        if shortcut then
            state.boundBuff, state.boundBuffSpell, state.buffShortcut = buff, spell, shortcut
            buff = nil
        end
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
    Set(frame, "macrotext1", livingSpell and CastMacro(livingSpell, heal, TargetUnit(frame)) or nil)
    if normalRes or combatRes then
        local target = TargetUnit(frame) or "mouseover"
        local clauses = {}
        if combatRes then
            clauses[#clauses + 1] = "[combat,@" .. target .. ",help,dead,party] " .. combatRes
            clauses[#clauses + 1] = "[combat,@" .. target .. ",help,dead,raid] " .. combatRes
        end
        if res then clauses[#clauses + 1] = "[nocombat,@" .. target .. ",help,dead] " .. res end
        local base = frame:GetAttribute("macrotext1")
        if base and base ~= "nil" then clauses[#clauses + 1] = base:match("^/cast (.-)\n") end
        Set(frame, "macrotext1", #clauses > 0 and ("/cast " .. table.concat(clauses, "; ") .. CastEnding(target)) or nil)
    end
    local action = (left.action == "settings" or left.action == "togglemenu") and "click" or left.action
    if action == "target" then
        action = A.externalFrames[frame] and "target" or "macro"
        Set(frame, "macrotext1", not A.externalFrames[frame] and TargetMacro(frame) or nil)
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
    RefreshHint(frame)
    if A.ApplyHoverCast then A.ApplyHoverCast(frame) end
end
local function Register(frame)
    -- Compact frame hooks also receive forbidden nameplate children.
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or frame.namePlateFrame then return end
    local external = A.externalFrames[frame]
    if external and external.option and not AggeHealBotDB[external.option] then return end
    if frame == PlayerFrame and not AggeHealBotDB.playerFrame then return end
    local option = frame == A.focusButton and "focusFrame"
        or frame == A.targetOfTargetButton and "targetOfTargetFrame" or "targetFrame"
    if not external and TargetUnit(frame) and not AggeHealBotDB[option] then return end
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
    if A.StopHoverCast then A.StopHoverCast(frame) end
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
local function RegisterTargetSurface(visual, key, unit, name, option)
    local enabled = AggeHealBotDB[option or "targetFrame"]
    if not visual or (not enabled and not A[key]) then return end
    if not A[key] then
        -- A secure friendly-only click surface leaves the stock target button
        -- and enemy interactions intact, including target switches in combat.
        local button = CreateFrame("Button", name, visual, "SecureUnitButtonTemplate")
        button:SetAllPoints(visual)
        local level = visual:GetFrameLevel()
        if unit == "targettarget" and A.targetButton then
            local targetLevel = A.targetButton:GetFrameLevel()
            if not secret(level) and not secret(targetLevel) then level = math.max(level, targetLevel) end
        end
        if not secret(level) then button:SetFrameLevel(level + 1) end
        button:EnableMouse(true)
        button.unit = unit
        button:SetAttribute("unit", unit)
        button:HookScript("OnHide", function(self)
            A.UpdateBuffIndicator(self)
            if hoveredFrame == self then
                hoveredFrame, hoveredRegion = nil, nil
                if addonTooltip and addonTooltip:IsOwned(self) then addonTooltip:Hide() end
                if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end
        end)
        A[key] = button
    end
    local button = A[key]
    local visibility = enabled and ("[@" .. unit .. ",exists,help] show; hide") or "hide"
    if targetVisibilityDrivers[button] ~= visibility then
        RegisterStateDriver(button, "visibility", visibility)
        targetVisibilityDrivers[button] = visibility
    end
    if enabled then Register(button)
    else RestoreFrame(button) end
end
discover = function()
    HookFunctions()
    if A.DiscoverXPerl then A.DiscoverXPerl(Register, RestoreFrame, Queue) end
    if A.DiscoverPetFrames then A.DiscoverPetFrames(Register) end
    Register(PlayerFrame)
    RegisterTargetSurface(TargetFrame, "targetButton", "target", "AggeHealBotTargetButton")
    RegisterTargetSurface(TargetFrameToT or (TargetFrame and TargetFrame.totFrame), "targetOfTargetButton", "targettarget", "AggeHealBotTargetOfTargetButton", "targetOfTargetFrame")
    RegisterTargetSurface(FocusFrame, "focusButton", "focus", "AggeHealBotFocusButton", "focusFrame")
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
local function HideGroupControls()
    if ReadFlag(IsInRaid) == true then return AggeHealBotDB.hideRaidControls end
    return AggeHealBotDB.hidePartyControls
end
local function ApplyRaidControls()
    local manager = CompactRaidFrameManager
    if not manager or InCombatLockdown() then return end
    if not hooks.raidControls then
        manager:HookScript("OnShow", function(self)
            if HideGroupControls() and not InCombatLockdown() then
                raidControlsHiddenByUs = true
                self:Hide()
            end
        end)
        hooks.raidControls = true
    end
    if HideGroupControls() then
        if not raidControlsHiddenByUs then
            raidControlsParent = manager:GetParent()
            raidControlsWasShown = manager:IsShown()
        end
        if not raidControlsHolder then
            raidControlsHolder = CreateFrame("Frame", nil, UIParent)
            raidControlsHolder:Hide()
        end
        -- Keep the sidebar under a hidden ancestor. Blizzard can Show() the
        -- manager during combat; that must not make the sidebar visible again.
        if manager:GetParent() ~= raidControlsHolder then manager:SetParent(raidControlsHolder) end
        raidControlsHiddenByUs = true
        manager:Hide()
    elseif raidControlsHiddenByUs then
        raidControlsHiddenByUs = false
        manager:SetParent(raidControlsParent or UIParent)
        if CompactRaidFrameManager_UpdateShown then CompactRaidFrameManager_UpdateShown(manager)
        elseif raidControlsWasShown then manager:Show() end
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
Queue = function()
    if queued or not ready or InCombatLockdown() then return end
    queued = true
    C_Timer.After(0, function() queued = false; refresh() end)
end
A.RefreshHoverBindings = function() Queue() end
A.GetBindings = function() return bindings end
A.GetPlayerClass = function() return class end
A.IsSpellLearned = IsLearned
local function GetWatchList(kind)
    local saved = AggeHealBotDB[kind == "cures" and "cureWatchRules" or "buffWatch"]
    if type(saved) ~= "table" or saved.class ~= class then saved = nil end
    local list = {}
    for _, group in ipairs(BuffWatchGroups(true, kind)) do
        local id, definition = group[1], kind ~= "cures" and A.buffRanks[group[1]]
        local learnedName = Resolve(group.ids or (definition and definition.ranks) or {id})
        local name = SpellName(id) or learnedName
        -- Cross-client candidate IDs may not exist on this client. They are
        -- different from valid, unlearned spells and have no configurable row.
        -- Resolve again on later refreshes rather than caching a missing name.
        if name then
            local info = C_Spell and C_Spell.GetSpellInfo and (C_Spell.GetSpellInfo(id) or C_Spell.GetSpellInfo(name))
            list[#list + 1] = {id = id, name = name,
                icon = info and info.iconID or 134400, learned = learnedName ~= nil,
                enabled = not (saved and type(saved.disabled) == "table" and saved.disabled[id]),
                selfOnly = group.selfOnly,
                targetMode = group.selfOnly and "self" or (BuffTargetRule(id) and BuffTargetRule(id).mode) or "everyone",
                kinds = kind == "cures" and table.concat(group, ", ", 2) or nil}
        end
    end
    return list
end
A.GetBuffWatchList = function() return GetWatchList("buffs") end
A.GetCureWatchList = function() return GetWatchList("cures") end
local function EditableBuffWatch(id, kind)
    local list, valid = GetWatchList(kind), false
    for _, entry in ipairs(list) do if entry.id == id then valid = true end end
    if not valid then return end
    local key = kind == "cures" and "cureWatchRules" or "buffWatch"
    local saved = AggeHealBotDB[key]
    if type(saved) ~= "table" or saved.class ~= class then
        saved = {class = class, disabled = {}}
        AggeHealBotDB[key] = saved
    end
    saved.disabled = type(saved.disabled) == "table" and saved.disabled or {}
    saved.order = {}
    for _, entry in ipairs(list) do saved.order[#saved.order + 1] = entry.id end
    return saved
end
function A.SetBuffWatchEnabled(id, enabled, kind)
    local saved = EditableBuffWatch(id, kind)
    if not saved then return false end
    saved.disabled[id] = not enabled or nil
    Queue()
    return true
end
local function SaveBuffTargetMode(id, mode, players)
    if not IsBuffTargetMode(mode) then return false end
    for _, group in ipairs(A.buffs[class] or {}) do if group[1] == id and group.selfOnly then return false end end
    local saved = EditableBuffWatch(id)
    if not saved then return false end
    saved.targets = type(saved.targets) == "table" and saved.targets or {}
    local old = saved.targets[id]
    saved.targets[id] = {mode = mode, players = players or (old and old.players) or {self = "Me"}}
    Queue()
    return true
end
function A.SetBuffTargetMode(id, mode)
    return SaveBuffTargetMode(id, mode)
end
function A.SaveBuffRecipients(id, recipients)
    local players = {}
    for _, recipient in ipairs(recipients) do
        if recipient.selected then
            players[recipient.key] = recipient.name:gsub(" %(not in group%)$", "")
        end
    end
    return SaveBuffTargetMode(id, "selected", players)
end
function A.GetBuffRecipients(id)
    local rule = BuffTargetRule(id)
    local selected = rule and type(rule.players) == "table" and rule.players or {self = "Me"}
    local list, seen = {{key = "self", name = "Me", selected = selected.self ~= nil}}, {}
    local function Add(unit)
        if ReadFlag(UnitExists, unit) ~= true or ReadFlag(UnitIsPlayer, unit) ~= true or ReadFlag(UnitIsUnit, unit, "player") ~= false then return end
        local guid, name = ReadFlag(UnitGUID, unit), ReadFlag(UnitName, unit)
        if type(guid) ~= "string" or type(name) ~= "string" or seen[guid] then return end
        seen[guid] = true
        list[#list + 1] = {key = guid, name = name, selected = selected[guid] ~= nil}
    end
    if ReadFlag(IsInRaid) == true then for i = 1, 40 do Add("raid" .. i) end
    else for i = 1, 4 do Add("party" .. i) end end
    for guid, name in pairs(selected) do
        if guid ~= "self" and not seen[guid] and type(guid) == "string" and type(name) == "string" then
            list[#list + 1] = {key = guid, name = name .. " (not in group)", selected = true}
        end
    end
    table.sort(list, function(a, b) if a.key == b.key then return false elseif a.key == "self" then return true elseif b.key == "self" then return false end; return a.name < b.name end)
    return list
end
function A.SetBuffRecipient(id, key, enabled)
    local label
    for _, entry in ipairs(A.GetBuffRecipients(id)) do if entry.key == key then label = entry.name:gsub(" %(not in group%)$", ""); break end end
    if not label or not A.SetBuffTargetMode(id, "selected") then return false end
    local rule = BuffTargetRule(id)
    rule.players[key] = enabled and label or nil
    Queue()
    return true
end
function A.MoveBuffWatch(id, direction, kind)
    if direction ~= -1 and direction ~= 1 then return false end
    local saved = EditableBuffWatch(id, kind)
    if not saved then return false end
    for index, value in ipairs(saved.order) do
        if value == id then
            local other = index + direction
            if other < 1 or other > #saved.order then return false end
            saved.order[index], saved.order[other] = saved.order[other], saved.order[index]
            Queue()
            return true
        end
    end
    return false
end
A.SetCureWatchEnabled = function(id, enabled) return A.SetBuffWatchEnabled(id, enabled, "cures") end
A.MoveCureWatch = function(id, direction) return A.MoveBuffWatch(id, direction, "cures") end
function A.ResetBuffWatch()
    AggeHealBotDB.buffWatch = nil
    Queue()
end
function A.ResetWatchers()
    AggeHealBotDB.buffWatch, AggeHealBotDB.cureWatchRules = nil, nil
    AggeHealBotDB.buffsBeforeCures = false
    AggeHealBotDB.watcherModifiers = false
    AggeHealBotDB.resurrectionWatch, AggeHealBotDB.combatResurrection = true, false
    AggeHealBotDB.resurrectionRanks = nil
    AggeHealBotDB.watchPets = true
    AggeHealBotDB.buffPets = optionDefaults.buffPets
    Queue()
end
function A.GetResurrectionSpell(inCombat)
    local ids = (inCombat and A.combatResurrections or A.resurrections)[class] or {}
    local name, id = ResurrectionSpell(inCombat)
    local label = (id and SpellName(id)) or CandidateName(ids)
    local info = id and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    return label, info and info.iconID or 134400, name ~= nil
end
function A.GetResurrectionRankChoices(inCombat)
    local ids = (inCombat and A.combatResurrections or A.resurrections)[class] or {}
    local families, candidates, seen = {}, {}, {}
    for _, id in ipairs(ids) do
        local name = SpellName(id)
        if name then families[name] = true end
        candidates[#candidates + 1] = id
    end
    for id, entry in pairs(spellRanks) do if families[entry.name] then candidates[#candidates + 1] = id end end
    local choices = {}
    for _, id in ipairs(candidates) do
        local entry = spellRanks[id]
        local rank = entry and entry.rank or SpellRank(id)
        if not seen[id] and rank and IsLearned(SpellName(id), id, true) then
            choices[#choices + 1] = {value = id, label = rank, rank = rank}
            seen[id] = true
        end
    end
    table.sort(choices, function(a, b) return tonumber(a.rank:match("%d+")) < tonumber(b.rank:match("%d+")) end)
    table.insert(choices, 1, {value = "auto", label = "Auto (highest learned)"})
    return choices
end
function A.GetResurrectionRank(inCombat)
    local saved = AggeHealBotDB.resurrectionRanks
    local choice = saved and saved.class == class and saved[inCombat and "combat" or "normal"]
    return choice and choice.id or "auto"
end
function A.SetResurrectionRank(inCombat, value)
    local selected
    for _, choice in ipairs(A.GetResurrectionRankChoices(inCombat)) do
        if choice.value == value then selected = choice; break end
    end
    if not selected then return false end
    local saved = AggeHealBotDB.resurrectionRanks
    if not saved or saved.class ~= class then saved = {class = class}; AggeHealBotDB.resurrectionRanks = saved end
    saved[inCombat and "combat" or "normal"] = value ~= "auto" and {id = value, rank = selected.rank} or nil
    Queue()
    return true
end
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
A.GetSpellChoices = function(includeUnlearned, includeRanks)
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
    if includeRanks then
        for id, rank in pairs(spellRanks) do
            if rank.rank and not rank.passive and (includeUnlearned or not rank.future) then
                local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
                choices[#choices + 1] = {label = rank.name .. " (" .. rank.rank .. ")", spell = rank.name,
                    spellID = id, rank = rank.rank, action = "spell", category = categoryByName[rank.name] or "other",
                    icon = info and info.iconID, unlearned = rank.future == true}
            end
        end
        for _, choice in ipairs(choices) do
            if not choice.rank and choice.category ~= "actions" then choice.label = choice.label .. " (Auto)" end
        end
    end
    local order = {heals = 1, buffs = 2, utility = 3, other = 4}
    table.sort(choices, function(a, b)
        if a.unlearned ~= b.unlearned then return not a.unlearned end
        if a.category ~= b.category then return order[a.category] < order[b.category] end
        if a.spell == b.spell and (a.rank or b.rank) then
            if not a.rank then return true end
            if not b.rank then return false end
            return tonumber(a.rank:match("%d+")) < tonumber(b.rank:match("%d+"))
        end
        return a.label < b.label
    end)
    return choices
end
A.SaveBinding = function(prefix, button, action, spell, spellID, rank)
    local validPrefix = false
    for _, m in ipairs(A.modifiers) do if m.prefix == prefix then validPrefix = true end end
    if not validPrefix or type(button) ~= "number" or button < 1 or button > A.maxMouseButtons or button % 1 ~= 0 then return false end
    if action == "default" then AggeHealBotDB.bindings[prefix .. button] = nil
    else
        if not A.actionLabels[action] then return false end
        if action == "spell" then
            local choice
            for _, item in ipairs(A.GetSpellChoices(AggeHealBotDB.showUnlearned, rank ~= nil)) do
                if item.spell == spell and item.rank == rank and (not rank or item.spellID == spellID) then choice = item; break end
            end
            if not choice then return false end
            AggeHealBotDB.bindings[prefix .. button] = {action = action,
                spell = rank and (spell .. "(" .. rank .. ")") or spell, spellID = choice.spellID, rank = rank}
        else
            AggeHealBotDB.bindings[prefix .. button] = {action = action}
        end
    end
    if button > 5 then
        AggeHealBotDB.extraMouseButtons = AggeHealBotDB.extraMouseButtons or {}
        AggeHealBotDB.extraMouseButtons[button] = true
    end
    -- Keep the displayed bindings consistent with the active secure attributes in combat.
    if not InCombatLockdown() then BuildBindings() end
    Queue()
    return true
end
function A.RememberMouseButton(number)
    if type(number) ~= "number" or number % 1 ~= 0 or number < 1 or number > A.maxMouseButtons then return false end
    if number > 5 then
        AggeHealBotDB.extraMouseButtons = AggeHealBotDB.extraMouseButtons or {}
        if not AggeHealBotDB.extraMouseButtons[number] then
            AggeHealBotDB.extraMouseButtons[number] = true
            if not InCombatLockdown() then BuildBindings() end
            Queue()
        end
    end
    return true
end
A.SetOption = function(key, value)
    if optionDefaults[key] == nil then return end
    AggeHealBotDB[key] = value and true or false
    if key == "showTooltip" or key == "replaceBlizzardTooltip" then RefreshTooltip(); return end
    if key == "showMinimap" then if A.UpdateMinimap then A.UpdateMinimap() end; return end
    if key == "showUnlearned" or key == "showAllRanks" then return end
    Queue()
    if InCombatLockdown() then for frame in pairs(frames) do UpdateCombatWatch(frame) end end
end
A.ResetBindings = function()
    wipe(AggeHealBotDB.bindings)
    AggeHealBotDB.hoverBindings = nil
    if not InCombatLockdown() then BuildBindings() end
    Queue()
end
A.ResetOptions = function()
    for key, value in pairs(optionDefaults) do AggeHealBotDB[key] = value end
    AggeHealBotDB.paladinBlessings = nil
    AggeHealBotDB.buffWatch = nil
    AggeHealBotDB.cureWatchRules = nil
    AggeHealBotDB.resurrectionRanks = nil
    if A.UpdateMinimap then A.UpdateMinimap() end
    RefreshTooltip()
    Queue()
    if InCombatLockdown() then for frame in pairs(frames) do UpdateCombatWatch(frame) end end
end
function A.ResetAdvancedOptions()
    for _, key in ipairs({"playerFrame", "targetFrame", "targetOfTargetFrame", "focusFrame",
        "rightClickMenu", "hidePartyControls", "hideRaidControls", "showPaladinDebug", "replaceBlizzardTooltip"}) do
        AggeHealBotDB[key] = optionDefaults[key]
    end
    RefreshTooltip()
    Queue()
    if InCombatLockdown() then for frame in pairs(frames) do UpdateCombatWatch(frame) end end
end
A.GetPaladinRule = function(targetClass)
    local rule = AggeHealBotDB.paladinBlessings and AggeHealBotDB.paladinBlessings[targetClass]
    return (rule == "off" or A.paladinBlessings[rule]) and rule or "auto"
end
A.SetPaladinRule = function(targetClass, rule)
    if (class ~= "PALADIN" and not AggeHealBotDB.showPaladinDebug) or (rule ~= "auto" and rule ~= "off" and not A.paladinBlessings[rule]) then return false end
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
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UNIT_TARGET", "INSPECT_READY", "UNIT_FACTION", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "MODIFIER_STATE_CHANGED", "SPELLS_CHANGED", "UNIT_AURA", "UNIT_HEALTH", "UNIT_DISPLAYPOWER", "UNIT_POWER_UPDATE", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN", "UNIT_FLAGS", "UNIT_CONNECTION", "INCOMING_RESURRECT_CHANGED", "UNIT_PET", "UI_ERROR_MESSAGE", "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED"}) do
    eventFrame:RegisterEvent(event)
end
eventFrame:SetScript("OnEvent", function(_, event, arg, message, castGUID, spellID)
    if event == "ADDON_LOADED" and arg == ADDON then
        AggeHealBotDB = AggeHealBotDB or {}
        -- Preserve the previous shared opt-out when upgrading saved settings.
        if AggeHealBotDB.targetOfTargetFrame == nil and AggeHealBotDB.targetFrame ~= nil then
            AggeHealBotDB.targetOfTargetFrame = AggeHealBotDB.targetFrame
        end
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
        if event == "INSPECT_READY" then
            A.UnitSpecReady(arg)
            if hoveredFrame then ShowFrameTooltip(hoveredFrame) end
            return
        end
        if event == "UNIT_DISPLAYPOWER" then Queue(); return end
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
        if event == "PLAYER_FOCUS_CHANGED" and A.focusButton then
            pendingBuffAttempt = nil
            A.UpdateBuffIndicator(A.focusButton)
            if hoveredFrame == A.focusButton and addonTooltip then addonTooltip:Hide() end
        end
        if (event == "PLAYER_TARGET_CHANGED" or (event == "UNIT_TARGET" and not secret(arg) and arg == "target"))
            and A.targetOfTargetButton then
            pendingBuffAttempt = nil
            A.UpdateBuffIndicator(A.targetOfTargetButton)
            if hoveredFrame == A.targetOfTargetButton and addonTooltip then addonTooltip:Hide() end
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
        if InCombatLockdown() and (event == "MODIFIER_STATE_CHANGED" or event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED") then
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
