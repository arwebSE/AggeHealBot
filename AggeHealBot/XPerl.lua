local _, A = ...
local options = {player = "playerFrame", target = "targetFrame", focus = "focusFrame", targettarget = "targetOfTargetFrame"}
local fixedUnits = {player = "player", target = "target", focus = "focus", targettarget = "targettarget"}
local function public(value) return not (issecretvalue and issecretvalue(value)) end
local visibility = {}
local hooked
local function Unit(frame)
    -- Party pets inherit their owner's unit and append a pet suffix.
    local unit = SecureButton_GetUnit and SecureButton_GetUnit(frame)
    if not public(unit) then return end
    if not unit then unit = frame.partyid end
    if not unit then unit = frame:GetAttribute("unit") end
    if public(unit) and type(unit) == "string" then return unit end
end

-- Use X-Perl's registry rather than guessing secure header child names.
-- Party targets, arena and other unsupported unit types are left alone.
function A.VisitXPerlFrames(visit)
    if type(XPerl_ForEachUnitFrame) ~= "function" then return end
    XPerl_ForEachUnitFrame(function(frame)
        if frame.IsForbidden and frame:IsForbidden() then return end
        local kind = frame.frameKey
        if not public(kind) or type(kind) ~= "string" then return end
        local pet = kind == "pet" or kind == "partypet" or kind == "raidpet"
        if not options[kind] and kind ~= "party" and kind ~= "raid" and not pet then return end
        local suffix = frame:GetAttribute("unitsuffix")
        if not public(suffix) or (suffix and not (pet and suffix == "pet")) then return end
        local unit = Unit(frame)
        if not public(unit) then return end
        if unit and (type(unit) ~= "string" or not (fixedUnits[kind] == unit
            or kind == "party" and (unit == "player" or unit:match("^party%d+$"))
            or kind == "raid" and unit:match("^raid%d+$")
            or pet and A.IsPetToken and A.IsPetToken(unit))) then return end
        visit(frame, kind, options[kind], fixedUnits[kind] or (kind == "pet" and "pet" or nil))
    end)
end

-- All X-Perl discovery, secure surfaces, visual references and lifecycle hooks
-- live here. Core supplies only its shared binding and restoration operations.
function A.DiscoverXPerl(register, restore, requestRefresh)
    if type(XPerl_ForEachUnitFrame) ~= "function" then return end
    A.xperlButtons = A.xperlButtons or {}
    if not hooked and type(XPerl_UnitFrame_OnLoad) == "function" then
        hooked = true
        hooksecurefunc("XPerl_UnitFrame_OnLoad", function() requestRefresh() end)
    end
    local seen = {}
    A.VisitXPerlFrames(function(visual, kind, option, fixedUnit)
        seen[visual] = true
        local enabled = public(visual.active) and visual.active ~= false and (not option or AggeHealBotDB[option])
        if kind == "target" then
            A.ConfigureEnemyWand(visual, enabled)
            A.ConfigureEnemyWand(visual.nameFrame, enabled)
        end
        local button = A.xperlButtons[visual]
        if not button and not enabled then return end
        if not button then
            button = CreateFrame("Button", nil, visual, "SecureActionButtonTemplate")
            A.xperlButtons[visual] = button
            A.externalFrames[button] = {visual = visual, kind = kind, option = option, fixedUnit = fixedUnit,
                GetUnit = function() return Unit(visual) end,
                tooltipAnchor = visual.statsFrame or visual,
                hoverRegions = {visual.nameFrame, visual.statsFrame,
                    visual.statsFrame and visual.statsFrame.healthBar,
                    visual.statsFrame and visual.statsFrame.manaBar, visual.portraitFrame}}
            button:SetAllPoints(visual)
            -- Header reassignment is inherited securely, including in combat.
            button:SetAttribute("useparent-unit", true)
            button:SetAttribute("useparent-unitsuffix", true)
            button:SetAttribute("toggleForVehicle", visual:GetAttribute("toggleForVehicle"))
            button:HookScript("OnHide", function(self)
                A.UpdateBuffIndicator(self)
                A.HideFrameHover(self)
            end)
        end
        local level = visual:GetFrameLevel()
        if not public(level) or type(level) ~= "number" then return end
        for _, region in pairs({visual.nameFrame, visual.statsFrame, visual.portraitFrame}) do
            local childLevel = region.GetFrameLevel and region:GetFrameLevel()
            if public(childLevel) and type(childLevel) == "number" then level = math.max(level, childLevel) end
        end
        button:SetFrameLevel(level + 5)
        local expression = not enabled and "hide" or fixedUnit and ("[@" .. fixedUnit .. ",exists,help] show; hide") or "show"
        if visibility[button] ~= expression then
            RegisterStateDriver(button, "visibility", expression)
            visibility[button] = expression
        end
        if enabled then register(button) else restore(button) end
    end)
    for visual, button in pairs(A.xperlButtons) do
        if not seen[visual] then
            if A.externalFrames[button].kind == "target" then
                A.ConfigureEnemyWand(visual, false)
                A.ConfigureEnemyWand(visual.nameFrame, false)
            end
            if visibility[button] ~= "hide" then
                RegisterStateDriver(button, "visibility", "hide")
                visibility[button] = "hide"
            end
            restore(button)
        end
    end
end
