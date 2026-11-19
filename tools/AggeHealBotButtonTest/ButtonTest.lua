-- Separate development helper. No input injection, game hooks or secure casts.
local panel
local selectedModifier = 1
local modifiers = {
    {"None", ""}, {"Shift", "shift-"}, {"Ctrl", "ctrl-"}, {"Alt", "alt-"},
    {"Ctrl + Shift", "ctrl-shift-"}, {"Alt + Shift", "alt-shift-"},
    {"Alt + Ctrl", "alt-ctrl-"}, {"Alt + Ctrl + Shift", "alt-ctrl-shift-"},
}
local rawNames = {[1] = "LeftButton", [2] = "RightButton", [3] = "MiddleButton"}
local function Text(parent, value, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width or 300)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetText(value)
    return text
end
local function OpenMain()
    local open = SlashCmdList and SlashCmdList.AGGEHEALBOT
    if not open then return nil, "AggeHealBot is not loaded." end
    open("")
    local main = _G.AggeHealBotSettings
    if not main or not main.identifier then return nil, "Install the Identify buttons build of AggeHealBot first." end
    return main
end
local function Simulate(number)
    if type(number) ~= "number" or number % 1 ~= 0 or number < 1 or number > 31 then
        return false, "Choose a button number from 1 to 31."
    end
    local main, problem = OpenMain()
    if not main then return false, problem end
    local control = main.identifier
    if not control.active then
        local start = control.identify:GetScript("OnClick")
        if not start then return false, "The identification control is unavailable." end
        start(control.identify)
    end
    local handler = control.capture:GetScript("OnMouseDown")
    if not handler then return false, "The capture handler is unavailable." end
    -- Exercise the same decoder, discovery, selection and highlight path as
    -- an incoming mouse event. This is deliberately NOT a hardware event.
    handler(control.capture, rawNames[number] or ("Button" .. number))
    local tab = main.tabs[selectedModifier]
    local selectModifier = tab and tab:GetScript("OnClick")
    if selectModifier then selectModifier(tab) end
    local label = selectedModifier == 1 and "" or (modifiers[selectedModifier][1] .. " + ")
    control.hint:SetText("Simulation: " .. label .. "Button " .. number .. " (not hardware input)")
    return true, "Simulated " .. label .. "Button " .. number .. ". Choose its spell in AggeHealBot."
end
local function Show()
    if panel then panel:Show(); return end
    panel = CreateFrame("Frame", "AggeHealBotButtonTestWindow", UIParent, "PortraitFrameTemplate")
    panel:SetSize(340, 390)
    panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -160)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    local nativeClose = panel.CloseButton
    if nativeClose then nativeClose:SetScript("OnClick", function() panel:Hide() end) end
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    if panel.PortraitContainer then panel.PortraitContainer:Hide() end
    if panel.NineSlice and NineSliceUtil then NineSliceUtil.ApplyLayoutByName(panel.NineSlice, "ButtonFrameTemplateNoPortrait") end
    local title = panel.TitleContainer and panel.TitleContainer.TitleText or panel.TitleText
    title:SetText("AHB Button Test")
    Text(panel, "UI simulation only. No mouse driver, input injection or spell casting.", 20, -45)
    Text(panel, "Button", 20, -91, 45)
    panel.number = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.number:SetSize(50, 24)
    panel.number:SetPoint("TOPLEFT", 72, -84)
    panel.number:SetAutoFocus(false)
    panel.number:SetNumeric(true)
    panel.number:SetText("6")
    panel.status = Text(panel, "Pick a test button. Bind it in the main window after it highlights.", 20, -278)
    panel.status:SetHeight(60)
    local function Send(number)
        local ok, result = Simulate(number)
        panel.status:SetText(result)
        panel.status:SetTextColor(ok and 0.65 or 1, ok and 1 or 0.45, ok and 0.7 or 0.3)
        if ok then panel.number:SetText(tostring(number)); panel.number:ClearFocus() end
    end
    local function Button(label, width, x, y, onClick)
        local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        button:SetSize(width, 26)
        button:SetPoint("TOPLEFT", x, y)
        button:SetText(label)
        button:SetScript("OnClick", onClick)
        return button
    end
    panel.send = Button("Simulate button", 160, 145, -85, function() Send(tonumber(panel.number:GetText())) end)
    panel.number:SetScript("OnEnterPressed", function() Send(tonumber(panel.number:GetText())) end)
    panel.quick = {}
    for index = 1, 6 do
        local number = index + 5
        panel.quick[index] = Button("Button " .. number, 90, 20 + ((index - 1) % 3) * 102,
            -130 - math.floor((index - 1) / 3) * 35, function() Send(number) end)
    end
    Text(panel, "Modifiers", 20, -211)
    panel.modifier = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    panel.modifier:SetSize(285, 26)
    panel.modifier:SetPoint("TOPLEFT", 20, -233)
    panel.modifier:SetDefaultText("None")
    panel.modifier:SetupMenu(function(_, root)
        for index, modifier in ipairs(modifiers) do
            root:CreateRadio(modifier[1], function(value) return selectedModifier == value end,
                function(value) selectedModifier = value; panel.modifier:GenerateMenu() end, index)
        end
    end)
    panel.modifier:GenerateMenu()
    panel.close = Button("Close tester", 125, 180, -345, function() panel:Hide() end)
    panel:SetScript("OnHide", function()
        panel.modifier:CloseMenu()
        local main = _G.AggeHealBotSettings
        if main and main.identifier then main.identifier:Stop() end
    end)
    tinsert(UISpecialFrames, "AggeHealBotButtonTestWindow")
    panel:Show()
end
-- Exposed by this optional helper only, for its own regression checks.
AggeHealBotButtonTest = {Simulate = Simulate, Show = Show}
SLASH_AGGEHEALBOTBUTTONTEST1 = "/ahbtest"
SlashCmdList.AGGEHEALBOTBUTTONTEST = function(message)
    Show()
    local number = tonumber(message)
    if number then
        local _, result = Simulate(number)
        panel.status:SetText(result)
    end
end
