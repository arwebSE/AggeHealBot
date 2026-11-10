local _, A = ...
local panel, picker, selected, selectedButton = nil, nil, 1, 1
local optionsCanvas, optionsCategory
local categoryLabels = {heals = "Heal", buffs = "Buff", utility = "Utility", other = "Other", actions = "Action"}
local categoryColors = {heals = {0.5, 1, 0.7}, buffs = {0.5, 0.75, 1}, utility = {0.8, 0.6, 1}, other = {0.6, 0.62, 0.66}, actions = {0.85, 0.75, 0.5}}
local selectionGold = {1, 0.76, 0.2}
local function Text(parent, value, x, y, font)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    text:SetPoint("TOPLEFT", x, y)
    text:SetText(value)
    text:SetJustifyH("LEFT")
    if font == "GameFontHighlightSmall" then text:SetTextColor(0.8, 0.73, 0.6) end
    return text
end
local function Button(parent, value, width, x, y, fn)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 27)
    b:SetPoint("TOPLEFT", x, y)
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetAllPoints()
    b.fill:SetAtlas("UI-Character-Info-Title")
    b.fill:SetVertexColor(0.65, 0.65, 0.68)
    b.highlight = b:CreateTexture(nil, "ARTWORK")
    b.highlight:SetAllPoints()
    b.highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    b.highlight:SetVertexColor(0.78, 0.81, 0.86)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", 9, 0)
    b.label:SetPoint("RIGHT", -9, 0)
    b.label:SetJustifyH("CENTER")
    function b:SetText(s) self.label:SetText(s) end
    function b:Select(v)
        self.selected = v
        self.highlight:SetAlpha(v and 0.45 or 0)
        if self.pulseSelection then self.label:SetTextColor(1, v and 0.82 or 0.95, v and 0.2 or 0.85)
        else self.label:SetTextColor(1, 0.95, 0.85) end
        if self.pulseSelection then
            if v and not self.glow then self.glow = A.CreateGlow(self, self, true) end
            if self.glow then A.SetGlow(self.glow, selectionGold, v) end
        end
    end
    function b:EnableSelectionGlow()
        self.pulseSelection = true
        self:HookScript("OnHide", function(self)
            if self.glow then A.SetGlow(self.glow, selectionGold, false) end
        end)
        self:HookScript("OnShow", function(self) self:Select(self.selected) end)
    end
    b:SetText(value)
    b:Select(false)
    b:SetScript("OnEnter", function(self) self.highlight:SetAlpha(self.selected and 0.55 or 0.25) end)
    b:SetScript("OnLeave", function(self) self:Select(self.selected) end)
    b:SetScript("OnClick", fn)
    return b
end
local function Value(binding)
    if not binding then return "Disabled" end
    if binding.action == "spell" then
        return (binding.spell or binding.expected or "Spell") .. (not binding.spell and " |cff888888(unlearned)|r" or "")
    end
    return A.actionLabels[binding.action] or binding.action
end
local function Current(prefix, button)
    local custom = AggeHealBotDB.bindings[prefix .. button]
    if custom then return custom end
    for _, b in ipairs(A.GetBindings()) do
        if b.prefix == prefix and b.button == button then return b end
    end
end
local function Update()
    if not panel then return end
    panel.buffs:SetChecked(AggeHealBotDB.smartBuffs)
    panel.player:SetChecked(AggeHealBotDB.playerFrame)
    panel.target:SetChecked(AggeHealBotDB.targetFrame)
    panel.raidControls:SetChecked(AggeHealBotDB.hideRaidControls)
    for i, tab in ipairs(panel.tabs) do tab:Select(i == selected) end
    for i, row in ipairs(panel.rows) do
        local binding = Current(A.modifiers[selected].prefix, i)
        row.button:SetText(Value(binding))
        row.button:Select(i == selectedButton)
    end
    panel.status:SetText(InCombatLockdown() and "|cffffcc66Saved. Changes apply after combat.|r" or "Saved automatically for this character.")
end
local function OpenPicker(button)
    selectedButton = button
    if not picker then
        -- Inline browser, not a second window covering the bindings.
        picker = CreateFrame("Frame", "AggeHealBotSpellPicker", panel)
        picker:SetSize(390, 451)
        picker:SetPoint("TOPLEFT", 365, -43)
        picker.heading = Text(picker, "", 0, 0)
        Text(picker, "Search", 0, -39, "GameFontHighlightSmall")
        picker.search = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
        picker.search:SetSize(323, 25)
        picker.search:SetPoint("TOPLEFT", 60, -32)
        picker.search:SetAutoFocus(false)
        picker.tabs = {}
        for i, item in ipairs({{"all", "All"}, {"heals", "Heals"}, {"buffs", "Buffs"}, {"utility", "Utility"}, {"other", "Other"}, {"actions", "Actions"}}) do
            local tab = Button(picker, item[2], 61, (i - 1) * 65, -68, function()
                picker.filter, picker.page = item[1], 1
                picker:Render()
            end)
            tab.category = item[1]
            tab:EnableSelectionGlow()
            picker.tabs[i] = tab
        end
        picker.rows = {}
        for i = 1, 9 do
            local row = Button(picker, "", 384, 0, -104 - (i - 1) * 31, function(self)
                local choice = self.choice
                if choice and A.SaveBinding(picker.prefix, picker.button, choice.action, choice.spell) then
                    Update()
                    picker:Render()
                end
            end)
            row:SetSize(384, 29)
            row.fill:SetAtlas("UI-Character-Info-Line-Bounce")
            row.fill:SetVertexColor(0.55, 0.57, 0.62)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(23, 23)
            row.icon:SetPoint("LEFT", 4, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            row.iconBorder = row:CreateTexture(nil, "OVERLAY")
            row.iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
            row.iconBorder:SetSize(34, 34)
            row.iconBorder:SetPoint("CENTER", row.icon, "CENTER", 0, 0)
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", 35, 0)
            row.label:SetPoint("RIGHT", -55, 0)
            row.label:SetJustifyH("LEFT")
            row.category = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.category:SetPoint("RIGHT", -7, 0)
            picker.rows[i] = row
        end
        picker.empty = Text(picker, "No matching spells.", 12, -125)
        picker.pageText = Text(picker, "", 166, -398, "GameFontHighlightSmall")
        local function Page(delta)
            picker.page = math.max(1, math.min(picker.pages, picker.page + delta))
            picker:Render()
        end
        Button(picker, "< Previous", 98, 0, -391, function() Page(-1) end)
        Button(picker, "Next >", 98, 286, -391, function() Page(1) end)
        local function Assign(action)
            A.SaveBinding(picker.prefix, picker.button, action)
            Update()
            picker:Render()
        end
        Button(picker, "Restore this click", 186, 0, -425, function() Assign("default") end)
        Button(picker, "Disable this click", 186, 198, -425, function() Assign("none") end)
        picker:EnableMouseWheel(true)
        picker:SetScript("OnMouseWheel", function(_, delta) Page(-delta) end)
        function picker:Render()
            if not self.choices then return end
            local query = self.search:GetText():lower()
            local source = self.filter == "actions" and self.actions or self.choices
            local filtered = {}
            for _, choice in ipairs(source) do
                if (self.filter == "all" or self.filter == "actions" or choice.category == self.filter)
                    and (query == "" or choice.label:lower():find(query, 1, true)) then
                    filtered[#filtered + 1] = choice
                end
            end
            for _, tab in ipairs(self.tabs) do tab:Select(tab.category == self.filter) end
            self.pages = math.max(1, math.ceil(#filtered / 9))
            self.page = math.min(self.page, self.pages)
            local current = Current(self.prefix, self.button)
            for i, row in ipairs(self.rows) do
                row.choice = filtered[(self.page - 1) * 9 + i]
                if row.choice then
                    local choice = row.choice
                    row:SetText(choice.label)
                    row.icon:SetTexture(choice.icon or 134400)
                    row.category:SetText(categoryLabels[choice.category])
                    local color = categoryColors[choice.category]
                    row.category:SetTextColor(color[1], color[2], color[3])
                    row:Select(current and current.action == choice.action and current.spell == choice.spell)
                    row:Show()
                else row:Hide() end
            end
            if #filtered == 0 then self.empty:Show() else self.empty:Hide() end
            self.pageText:SetText(self.page .. " / " .. self.pages)
        end
        picker.search:SetScript("OnTextChanged", function() picker.page = 1; picker:Render() end)
        picker.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        picker:SetScript("OnHide", function() picker.search:ClearFocus() end)
    end
    picker.prefix, picker.button = A.modifiers[selected].prefix, button
    picker.heading:SetText("Assign: " .. A.modifiers[selected].label .. A.buttons[button])
    picker.choices = A.GetSpellChoices()
    picker.actions = {}
    local actionIcons = {target = 132212, assist = 132179, togglemenu = 134331, settings = 136243, none = 132156}
    for _, action in ipairs({"target", "assist", "togglemenu", "settings", "none"}) do
        picker.actions[#picker.actions + 1] = {label = A.actionLabels[action], action = action, category = "actions", icon = actionIcons[action]}
    end
    picker.filter, picker.page = "all", 1
    picker.search:SetText("")
    picker:Render()
    picker:Show()
    Update()
end
local function FitEditor(host)
    if not panel or panel.embeddedHost ~= host then return end
    local width, height = host:GetWidth(), host:GetHeight()
    if width > 0 and height > 0 then panel:SetScale(math.min(1, width / 780, height / 548)) end
end
local function PlaceEditor(host)
    panel.embeddedHost = host
    panel:SetParent(host or UIParent)
    panel:ClearAllPoints()
    if host then panel:SetPoint("CENTER", host, "CENTER", 0, 0)
    else panel:SetPoint("CENTER") end
    panel:SetScale(1)
    panel:SetFrameStrata(host and host:GetFrameStrata() or "DIALOG")
    panel:SetMovable(not host)
    panel:SetClampedToScreen(not host)
    -- The native Options window supplies its own frame and close controls.
    for _, key in ipairs({"NineSlice", "TitleContainer", "CloseButton", "Bg", "TopTileStreaks", "done"}) do
        local region = panel[key]
        if region then
            if host then region:Hide() else region:Show() end
        end
    end
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "AggeHealBotSettings" then table.remove(UISpecialFrames, i) end
    end
    if host then FitEditor(host)
    else tinsert(UISpecialFrames, "AggeHealBotSettings") end
end
function A.ShowOptions(host)
    if not host and panel and panel.embeddedHost and panel.embeddedHost:IsVisible() then host = panel.embeddedHost end
    if not panel then
        panel = CreateFrame("Frame", "AggeHealBotSettings", UIParent, "PortraitFrameTemplate")
        -- Use the same frame art as Forever's character window, without a portrait.
        if panel.PortraitContainer then panel.PortraitContainer:Hide() end
        if panel.NineSlice and NineSliceUtil then
            NineSliceUtil.ApplyLayoutByName(panel.NineSlice, "ButtonFrameTemplateNoPortrait")
        end
        if panel.TitleContainer then
            panel.TitleContainer:ClearAllPoints()
            panel.TitleContainer:SetPoint("TOPLEFT", 18, -1)
            panel.TitleContainer:SetPoint("TOPRIGHT", -24, -1)
        end
        panel:SetSize(780, 548)
        panel:SetPoint("CENTER")
        panel:SetFrameStrata("DIALOG")
        panel:SetClampedToScreen(true)
        panel:EnableMouse(true)
        panel:SetMovable(true)
        panel:RegisterForDrag("LeftButton")
        panel:SetScript("OnDragStart", function(self) if not self.embeddedHost then self:StartMoving() end end)
        panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
        local title = panel.TitleContainer and panel.TitleContainer.TitleText or panel.TitleText
        title:SetText("AggeHealBot")
        if panel.Bg then
            panel.Bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
            panel.Bg:SetVertexColor(0.65, 0.65, 0.65)
        end
        tinsert(UISpecialFrames, "AggeHealBotSettings")
        local divider = panel:CreateTexture(nil, "BACKGROUND")
        divider:SetColorTexture(0.65, 0.45, 0.2, 0.45)
        divider:SetSize(1, 450)
        divider:SetPoint("TOPLEFT", 349, -43)
        local function Check(key, label, y)
            local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", 18, y)
            local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", check, "RIGHT", 2, 0)
            text:SetText(label)
            check:SetScript("OnClick", function(self) A.SetOption(key, self:GetChecked()); Update() end)
            return check
        end
        panel.buffs = Check("smartBuffs", "Buff missing buffs outside combat", -37)
        panel.player = Check("playerFrame", "Click-heal my player portrait", -67)
        panel.target = Check("targetFrame", "Click-heal and watch buffs on my target", -97)
        panel.raidControls = Check("hideRaidControls", "Hide Blizzard raid controls", -127)
        Text(panel, "MODIFIERS — CLICK TO CHANGE", 24, -172, "GameFontHighlightSmall")
        panel.tabs = {}
        local labels = {"None", "Shift", "Ctrl", "Alt", "Ctrl+Shift", "Alt+Shift", "Alt+Ctrl", "All 3"}
        for i, label in ipairs(labels) do
            panel.tabs[i] = Button(panel, label, 75, 24 + ((i - 1) % 4) * 78, -194 - math.floor((i - 1) / 4) * 30, function()
                selected = i
                OpenPicker(selectedButton)
            end)
            panel.tabs[i]:EnableSelectionGlow()
        end
        Text(panel, "CLICK", 24, -269, "GameFontHighlightSmall")
        Text(panel, "ASSIGNED SPELL / ACTION", 104, -269, "GameFontHighlightSmall")
        panel.rows = {}
        for i = 1, 5 do
            local row = {}
            row.label = Text(panel, A.buttons[i], 24, -305 - (i - 1) * 33)
            row.button = Button(panel, "", 228, 104, -297 - (i - 1) * 33, function() OpenPicker(i) end)
            row.button.label:SetJustifyH("LEFT")
            panel.rows[i] = row
        end
        Button(panel, "Reset all bindings", 155, 24, -476, function()
            A.ResetBindings()
            OpenPicker(selectedButton)
        end)
        panel.status = Text(panel, "", 24, -516, "GameFontHighlightSmall")
        panel.done = Button(panel, "Done", 100, 655, -508, function() panel:Hide() end)
        panel:SetScript("OnHide", function() if picker then picker:Hide() end end)
        for _, event in ipairs({"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED"}) do panel:RegisterEvent(event) end
        panel:SetScript("OnEvent", Update)
    end
    PlaceEditor(host)
    panel:Show()
    OpenPicker(selectedButton)
end
function A.ToggleOptions()
    if panel and panel:IsVisible() then
        if panel.embeddedHost and HideUIPanel then
            local root = SettingsPanel and SettingsPanel:IsShown() and SettingsPanel
                or InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() and InterfaceOptionsFrame
            if root then HideUIPanel(root) else panel:Hide() end
        else panel:Hide() end
    else A.ShowOptions() end
end

function A.RegisterOptionsCategory()
    if optionsCategory then return optionsCategory end
    local modern = Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
    if not modern and not InterfaceOptions_AddCategory then return end
    optionsCanvas = CreateFrame("Frame", "AggeHealBotOptionsCanvas", UIParent)
    optionsCanvas.name = "AggeHealBot"
    optionsCanvas:Hide()
    optionsCanvas:SetScript("OnShow", function(self) A.ShowOptions(self) end)
    optionsCanvas:SetScript("OnHide", function(self)
        if panel and panel.embeddedHost == self then panel:Hide() end
    end)
    optionsCanvas:SetScript("OnSizeChanged", function(self) FitEditor(self) end)
    if modern then
        optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsCanvas, "AggeHealBot")
        Settings.RegisterAddOnCategory(optionsCategory)
    else
        InterfaceOptions_AddCategory(optionsCanvas)
        optionsCategory = optionsCanvas
    end
    return optionsCategory
end
local registration = CreateFrame("Frame")
registration:RegisterEvent("PLAYER_LOGIN")
registration:RegisterEvent("ADDON_LOADED")
registration:SetScript("OnEvent", function() A.RegisterOptionsCategory() end)
A.RegisterOptionsCategory()
