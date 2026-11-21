local _, A = ...
local states, regions, serial = {}, {}, 0
local function PublicTrue(method, frame)
    if not method then return false end
    local ok, value = pcall(method, frame)
    return ok and not (issecretvalue and issecretvalue(value)) and value == true
end
local enter = [[
    if not control:GetAttribute("enabled") then return end
    control:ClearBindings()
    control:SetAttribute("active-region", self:GetAttribute("ahb-hover-region"))
    local count = control:GetAttribute("count") or 0
    for i = 1, count do
        control:SetBindingClick(true, control:GetAttribute("key" .. i), control:GetAttribute("button" .. i), "LeftButton")
    end
]]
local leave = [[
    if control:GetAttribute("active-region") == self:GetAttribute("ahb-hover-region") then
        control:ClearBindings()
        control:SetAttribute("active-region", nil)
    end
]]
local function ValidKey(key)
    if type(key) ~= "string" or #key > 64 then return false end
    local base = key:gsub("ALT%-", ""):gsub("CTRL%-", ""):gsub("SHIFT%-", "")
    if base == "" or base == "ESCAPE" or base:find("BUTTON", 1, true) or base:find("MOUSEWHEEL", 1, true) then return false end
    if not base:match("^[A-Z0-9%-%[%];',./=\\]+$") then return false end
    return key == ((key:find("ALT%-") and "ALT-" or "") .. (key:find("CTRL%-") and "CTRL-" or "")
        .. (key:find("SHIFT%-") and "SHIFT-" or "") .. base)
end
A.IsHoverKey = ValidKey
function A.GetHoverKeys()
    local list = {}
    for key in pairs(AggeHealBotDB.hoverBindings or {}) do if ValidKey(key) then list[#list + 1] = key end end
    table.sort(list)
    return list
end
function A.GetHoverBinding(key)
    local saved = (AggeHealBotDB.hoverBindings or {})[key]
    if not saved then return {action = "none"} end
    local binding = {action = saved.action, spellID = saved.spellID, rank = saved.rank, expected = saved.rank and (saved.spell .. "(" .. saved.rank .. ")") or saved.spell}
    if saved.action == "spell" and saved.spell and A.IsSpellLearned(saved.spell, saved.spellID, saved.rank ~= nil) then
        binding.spell = binding.expected
    end
    return binding
end
function A.SaveHoverBinding(key, action, spell, spellID, rank)
    if not ValidKey(key) then return false end
    AggeHealBotDB.hoverBindings = AggeHealBotDB.hoverBindings or {}
    if action == "default" then AggeHealBotDB.hoverBindings[key] = nil
    elseif action == "spell" then
        local valid
        for _, choice in ipairs(A.GetSpellChoices(AggeHealBotDB.showUnlearned, rank ~= nil)) do
            if choice.spell == spell and choice.rank == rank and (not rank or choice.spellID == spellID) then valid = choice; break end
        end
        if not valid then return false end
        AggeHealBotDB.hoverBindings[key] = {action = action, spell = spell, spellID = valid.spellID, rank = rank}
    elseif A.actionLabels[action] then AggeHealBotDB.hoverBindings[key] = {action = action}
    else return false end
    A.RefreshHoverBindings()
    return true
end
function A.RegisterHoverRegion(frame, region)
    if not AggeHealBotDB.hovercast or not region or not region.HookScript or regions[region] then return end
    local state = states[frame]
    if not state then
        state = {owner = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate"), buttons = {}, regions = {}}
        states[frame] = state
    end
    -- The wrappers run in Blizzard's restricted environment, including combat.
    -- Never change override bindings in an ordinary OnEnter/OnLeave callback.
    serial = serial + 1
    region:SetAttribute("ahb-hover-region", serial)
    SecureHandlerWrapScript(region, "OnEnter", state.owner, enter)
    SecureHandlerWrapScript(region, "OnLeave", state.owner, leave)
    SecureHandlerWrapScript(region, "OnHide", state.owner, leave)
    regions[region] = frame
    state.regions[#state.regions + 1] = region
end
function A.StopHoverCast(frame)
    local state = states[frame]
    if not state then return end
    state.owner:SetAttribute("enabled", false)
    state.owner:SetAttribute("active-region", nil)
    ClearOverrideBindings(state.owner)
end
function A.ApplyHoverCast(frame)
    local state = states[frame]
    if not state then return end
    A.StopHoverCast(frame)
    local count = 0
    if AggeHealBotDB.hovercast then
        for _, key in ipairs(A.GetHoverKeys()) do
            local saved = A.GetHoverBinding(key)
            if saved.action ~= "none" then
                local button = state.buttons[key]
                if not button then
                    serial = serial + 1
                    button = CreateFrame("Button", "AggeHealBotHoverKey" .. serial, frame, "SecureActionButtonTemplate")
                    button:RegisterForClicks("AnyUp", "AnyDown")
                    button:SetAttribute("useOnKeyDown", true)
                    button:SetAttribute("useparent-unit", true)
                    button:SetAttribute("useparent-unitsuffix", true)
                    button:SetAttribute("checkselfcast", false)
                    button:SetAttribute("checkfocuscast", false)
                    button:EnableMouse(false)
                    state.buttons[key] = button
                end
                if A.ConfigureHoverAction(button, frame, saved) then
                    count = count + 1
                    state.owner:SetAttribute("key" .. count, key)
                    state.owner:SetAttribute("button" .. count, button:GetName())
                end
            end
        end
    end
    state.owner:SetAttribute("count", count)
    state.owner:SetAttribute("enabled", AggeHealBotDB.hovercast and count > 0)
    -- An out-of-combat refresh can occur without a new mouse-enter event.
    if AggeHealBotDB.hovercast and count > 0 then
        for _, region in ipairs(state.regions) do
            if PublicTrue(region.IsShown, region) and PublicTrue(region.IsMouseOver, region) then
                state.owner:SetAttribute("active-region", region:GetAttribute("ahb-hover-region"))
                for i = 1, count do SetOverrideBindingClick(state.owner, true, state.owner:GetAttribute("key" .. i), state.owner:GetAttribute("button" .. i), "LeftButton") end
                break
            end
        end
    end
end
