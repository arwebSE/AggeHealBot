local _, A = ...
local cache, pending, lastRequest = {}, nil, -math.huge
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local function call(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if ok and public(value) then return value end
end
local function validName(name, unit)
    if not public(name) or type(name) ~= "string" or name == "" then return end
    local className = call(UnitClass, unit)
    -- Forever can return the generic class as its specialization name.
    if name ~= className then return name end
end
local function positive(value)
    return public(value) and type(value) == "number" and value > 0
end
local function tableValue(value) return public(value) and type(value) == "table" end
local function traitSpec(unit, own)
    if not C_Traits then return end
    local configID
    if own then
        configID = call(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
        if not configID and C_SpecializationInfo then
            local group = call(C_SpecializationInfo.GetActiveSpecGroup)
            if positive(group) then configID = call(C_SpecializationInfo.GetCombatConfigIDForSpecGroup, group) end
        end
    else
        configID = Constants and Constants.TraitConsts and Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
    end
    if not public(configID) or type(configID) ~= "number" then return end
    local config = call(C_Traits.GetConfigInfo, configID)
    if not tableValue(config) or not tableValue(config.treeIDs) then return end
    local best, maximum, tied = nil, 0, false
    for _, treeID in ipairs(config.treeIDs) do
        local displays = positive(treeID) and call(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
        if tableValue(displays) then
            local groupIDs, names = {}, {}
            for _, display in ipairs(displays) do
                if tableValue(display) and positive(display.groupID) then
                    local name = validName(display.displayName, unit)
                    if name then
                        groupIDs[#groupIDs + 1] = display.groupID
                        names[display.groupID] = name
                    end
                end
            end
            local groups = #groupIDs > 0 and call(C_Traits.GetGroupCurrencyInfo, configID, groupIDs)
            if tableValue(groups) then
                for _, group in ipairs(groups) do
                    if tableValue(group) and positive(group.traitNodeGroupID) then
                        local name = names[group.traitNodeGroupID]
                        local currency = tableValue(group.currencyInfos) and group.currencyInfos[1]
                        local spent = tableValue(currency) and currency.spent
                        if name and positive(spent) then
                            if spent > maximum then best, maximum, tied = name, spent, false
                            elseif spent == maximum then tied = true end
                        end
                    end
                end
            end
        end
    end
    if not tied then return best end
end
local function readSpec(unit, own, inspectReady)
    local api = C_SpecializationInfo
    local id, info
    if own then
        id = call((api and api.GetSpecialization) or GetSpecialization)
        info = (api and api.GetSpecializationInfo) or GetSpecializationInfo
    else
        id = call((api and api.GetInspectSpecialization) or GetInspectSpecialization, unit)
        info = GetSpecializationInfoForSpecID or GetSpecializationInfoByID
    end
    if positive(id) and info then
        local ok, returnedID, name = pcall(info, id)
        if ok and positive(returnedID) then
            local result = validName(name, unit)
            if result then return result end
        end
    end
    -- Classic/Forever builds can expose talent trees instead of a selected
    -- specialization. Only use inspected trees after the matching response.
    if not own and not inspectReady then return end
    local traits = traitSpec(unit, own)
    if traits then return traits end
    local treeInfo = GetTalentTabInfo or (api and api.GetSpecializationInfo) or GetSpecializationInfo
    if not treeInfo then return end
    local count = call(GetNumTalentTabs, not own) or 3
    if not positive(count) or count > 8 then return end
    local best, maximum, tied = nil, 0, false
    for index = 1, count do
        local ok, first, second, third, fourth, fifth, sixth, seventh
        if GetTalentTabInfo then
            ok, first, second, third, fourth, fifth, sixth, seventh = pcall(treeInfo, index, not own, false)
        else
            ok, first, second, third, fourth, fifth, sixth, seventh = pcall(treeInfo, index, not own, false, unit)
        end
        if ok then
            local name, points
            if GetTalentTabInfo then
                if public(first) and type(first) == "string" then name, points = first, third
                else name, points = second, fifth end
            else name, points = second, seventh end
            name = validName(name, unit)
            if name and positive(points) then
                if points > maximum then best, maximum, tied = name, points, false
                elseif points == maximum then tied = true end
            end
        end
    end
    if not tied then return best end
end
local function key(unit)
    local guid = call(UnitGUID, unit)
    if type(guid) == "string" then return guid end
end
local function specClock() return GetServerTime and GetServerTime() or GetTime() end
local function savedSpecs()
    if type(AggeHealBotDB.specCache) ~= "table" then AggeHealBotDB.specCache = {} end
    return AggeHealBotDB.specCache
end
local function cachedName(guid)
    local saved = cache[guid] or savedSpecs()[guid]
    if type(saved) ~= "table" or not public(saved.name) or type(saved.name) ~= "string" then return end
    if public(saved.expires) and type(saved.expires) == "number" and saved.expires > specClock() then
        cache[guid] = saved
        return saved.name
    end
    cache[guid], savedSpecs()[guid] = nil, nil
end
local function remember(guid, name)
    if name then
        local saved = {name = name, expires = specClock() + 3600}
        cache[guid], savedSpecs()[guid] = saved, saved
    else
        cache[guid], savedSpecs()[guid] = {time = GetTime()}, nil
    end
end
function A.GetUnitSpec(unit)
    if not unit then return end
    local guid = key(unit)
    if not guid then return end
    -- Combat only reads a confirmed GUID-keyed cache. No talent/inspection API
    -- is needed, and a different unit reusing this frame cannot inherit a spec.
    if InCombatLockdown() then return cachedName(guid) end
    if call(UnitIsPlayer, unit) ~= true then return end
    local own = call(UnitIsUnit, unit, "player")
    if own == nil then return end
    if own then
        local name = readSpec(unit, true)
        remember(guid, name)
        return name
    end
    local confirmed = cachedName(guid)
    if confirmed then return confirmed end
    local now, saved = GetTime(), cache[guid]
    if saved and saved.time and now - saved.time < 10 then return end
    local name = readSpec(unit, false)
    if name then remember(guid, name); return name end
    -- Hover refreshes are frequent. Keep one request in flight and respect
    -- manual inspection; never request inspection from combat or aura scans.
    if not NotifyInspect or not CanInspect or now - lastRequest < 2
        or (pending and now - pending.time < 5)
        or (InspectFrame and call(InspectFrame.IsShown, InspectFrame))
        or call(CanInspect, unit, false) ~= true then return end
    pending = {unit = unit, guid = guid, time = now}
    lastRequest = now
    if not pcall(NotifyInspect, unit) then
        cache[guid], pending = {time = now}, nil
    end
end
function A.UnitSpecReady(guid)
    if not public(guid) or type(guid) ~= "string" or not pending or guid ~= pending.guid then return end
    local request = pending
    pending = nil
    if InCombatLockdown() or key(request.unit) ~= guid then return end
    remember(guid, readSpec(request.unit, false, true))
end
