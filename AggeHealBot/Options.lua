local _, A = ...
local panel, picker, selected, selectedButton = nil, nil, 1, 1
local optionsCanvas, optionsCategory
local toolsPane
local categoryLabels = {heals = "Heal", buffs = "Buff", utility = "Utility", other = "Other", actions = "Action"}
local categoryColors = {heals = {0.5, 1, 0.7}, buffs = {0.5, 0.75, 1}, utility = {0.8, 0.6, 1}, other = {0.6, 0.62, 0.66}, actions = {0.85, 0.75, 0.5}}
local selectionGold = {1, 0.76, 0.2}
local classIcons = {
    WARRIOR = {0, 0.25, 0, 0.25}, MAGE = {0.25, 0.5, 0, 0.25},
    ROGUE = {0.5, 0.75, 0, 0.25}, DRUID = {0.75, 1, 0, 0.25},
    HUNTER = {0, 0.25, 0.25, 0.5}, SHAMAN = {0.25, 0.5, 0.25, 0.5},
    PRIEST = {0.5, 0.75, 0.25, 0.5}, WARLOCK = {0.75, 1, 0.25, 0.5},
    PALADIN = {0, 0.25, 0.5, 0.75},
}
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
        local name = binding.spell or binding.expected
        if not name or name == "" then return A.actionLabels.none end
        local learned = binding.spell and A.IsSpellLearned(binding.spell, binding.spellID)
        return name .. (not learned and " |cff888888(unlearned)|r" or "")
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
    panel.cures:SetChecked(AggeHealBotDB.cureWatch)
    panel.combatRes:SetChecked(AggeHealBotDB.combatResurrection)
    panel.combatCures:SetChecked(AggeHealBotDB.combatCures)
    panel.combatCures:SetEnabled(AggeHealBotDB.cureWatch)
    panel.combatCures:SetAlpha(AggeHealBotDB.cureWatch and 1 or 0.45)
    panel.player:SetChecked(AggeHealBotDB.playerFrame)
    panel.target:SetChecked(AggeHealBotDB.targetFrame)
    panel.rightClickMenu:SetChecked(not AggeHealBotDB.rightClickMenu)
    panel.raidControls:SetChecked(AggeHealBotDB.hideRaidControls)
    if panel.blessings then
        if A.GetPlayerClass() == "PALADIN" then panel.blessings:Show() else panel.blessings:Hide() end
    end
    for i, tab in ipairs(panel.tabs) do tab:Select(i == selected) end
    for i, row in ipairs(panel.rows) do
        local binding = Current(A.modifiers[selected].prefix, i)
        row.button:SetText(Value(binding))
        row.button:Select(i == selectedButton)
        row.button:SetBinding(binding)
    end
    panel.mouse:SetCaption(A.buttons[selectedButton], Value(Current(A.modifiers[selected].prefix, selectedButton)),
        panel.mouse.buttons[selectedButton].bindingIcon, panel.mouse.buttons[selectedButton].bindingAlpha)
    panel.status:SetText(InCombatLockdown() and "|cffffcc66Saved. Changes apply after combat.|r" or "Saved automatically for this character.")
    if picker then
        picker.showUnlearned:SetChecked(AggeHealBotDB.showUnlearned)
        picker.choices = A.GetSpellChoices(AggeHealBotDB.showUnlearned)
        picker:Render()
    end
    if toolsPane and toolsPane:IsShown() then toolsPane:Render() end
end
local function OpenPicker(button)
    if toolsPane then toolsPane:Hide() end
    selectedButton = button
    if not picker then
        -- Inline browser, not a second window covering the bindings.
        picker = CreateFrame("Frame", "AggeHealBotSpellPicker", panel)
        picker:SetSize(390, 451)
        picker:SetPoint("TOPLEFT", 365, -43)
        picker.heading = Text(picker, "", 0, 0)
        picker.heading:SetWidth(230)
        picker.heading:SetWordWrap(false)
        picker.showUnlearned = CreateFrame("CheckButton", nil, picker, "UICheckButtonTemplate")
        picker.showUnlearned:SetSize(24, 24)
        picker.showUnlearned:SetPoint("TOPLEFT", 252, 7)
        picker.showUnlearned:SetHitRectInsets(0, -100, 0, 0)
        local unlearnedLabel = picker.showUnlearned:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        unlearnedLabel:SetPoint("LEFT", picker.showUnlearned, "RIGHT", 2, 0)
        unlearnedLabel:SetText("Show unlearned")
        picker.showUnlearned:SetScript("OnClick", function(self)
            A.SetOption("showUnlearned", self:GetChecked())
            picker.page = 1
            Update()
        end)
        Text(picker, "Search", 0, -39, "GameFontHighlightSmall")
        picker.search = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
        picker.search:SetSize(323, 25)
        picker.search:SetPoint("TOPLEFT", 60, -32)
        picker.search:SetAutoFocus(false)
        picker.tabs = {}
        local tabX = 0
        for i, item in ipairs({{"suggested", "Suggested", 80}, {"heals", "Heals", 54}, {"buffs", "Buffs", 54},
            {"utility", "Utility", 62}, {"actions", "Actions", 68}, {"all", "All", 46}}) do
            local tab = Button(picker, item[2], item[3], tabX, -68, function()
                picker.filter, picker.page = item[1], 1
                picker:Render()
            end)
            tabX = tabX + item[3] + 4
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
            row:HookScript("OnEnter", function(self)
                if not self.choice or not self.choice.unlearned then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.choice.label, 1, 0.82, 0)
                GameTooltip:AddLine("Not learned yet", 1, 0.6, 0.3)
                GameTooltip:AddLine("You can bind this now. It stays inactive until you learn the spell.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            local function HideTip(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end
            row:HookScript("OnLeave", HideTip)
            row:HookScript("OnHide", HideTip)
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
            if self.filter == "all" then
                source = {}
                for _, choice in ipairs(self.choices) do
                    if not choice.unlearned then source[#source + 1] = choice end
                end
                for _, choice in ipairs(self.actions or {}) do source[#source + 1] = choice end
                for _, choice in ipairs(self.choices) do
                    if choice.unlearned then source[#source + 1] = choice end
                end
            end
            local filtered = {}
            for _, choice in ipairs(source) do
                local suggested = self.filter == "suggested"
                    and (choice.category == "heals" or choice.category == "buffs" or choice.category == "utility")
                if (self.filter == "all" or self.filter == "actions" or suggested or choice.category == self.filter)
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
                if GameTooltip:IsOwned(row) then GameTooltip:Hide() end
                if row.choice then
                    local choice = row.choice
                    row:SetText(choice.label)
                    row.icon:SetTexture(choice.icon or 134400)
                    row.category:SetText(categoryLabels[choice.category])
                    local color = categoryColors[choice.category]
                    row.category:SetTextColor(color[1], color[2], color[3])
                    row:SetAlpha(choice.unlearned and 0.45 or 1)
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
    picker.choices = A.GetSpellChoices(AggeHealBotDB.showUnlearned)
    picker.actions = {}
    local actionIcons = {target = 132212, assist = 132179, togglemenu = 134331, settings = 136243, none = 132156}
    for _, action in ipairs({"target", "assist", "togglemenu", "settings", "none"}) do
        picker.actions[#picker.actions + 1] = {label = A.actionLabels[action], action = action, category = "actions", icon = actionIcons[action]}
    end
    picker.filter, picker.page = "suggested", 1
    picker.search:SetText("")
    picker:Render()
    picker:Show()
    Update()
end
local function OpenBlessings()
    if A.GetPlayerClass() ~= "PALADIN" then return end
    if toolsPane and toolsPane:IsShown() then OpenPicker(selectedButton); return end
    if picker then picker:Hide() end
    if not toolsPane then
        toolsPane = CreateFrame("Frame", "AggeHealBotTools", panel)
        toolsPane:SetSize(390, 451)
        toolsPane:SetPoint("TOPLEFT", 365, -43)
        toolsPane.heading = Text(toolsPane, "", 0, 0)
        toolsPane.description = Text(toolsPane, "", 0, -33, "GameFontHighlightSmall")
        toolsPane.description:SetWidth(384)
        toolsPane.description:SetWordWrap(true)
        toolsPane.message = Text(toolsPane, "", 0, -380, "GameFontHighlightSmall")
        toolsPane.message:SetWidth(384)
        toolsPane.message:SetWordWrap(true)
        toolsPane.rows = {}
        for i = 1, 9 do
            local token = A.paladinClasses[i]
            local row = CreateFrame("Frame", nil, toolsPane)
            row:SetSize(384, 29)
            row:SetPoint("TOPLEFT", 0, -86 - (i - 1) * 32)
            row.class = token
            row.fill = row:CreateTexture(nil, "BACKGROUND")
            row.fill:SetAllPoints()
            row.fill:SetAtlas("UI-Character-Info-Line-Bounce")
            row.fill:SetVertexColor(0.3, 0.3, 0.34, 0.35)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(18, 18)
            row.icon:SetPoint("LEFT", 14, 0)
            row.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[token] or classIcons[token]
            row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", 42, 0)
            row.label:SetWidth(112)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
            if color then row.label:SetTextColor(color.r, color.g, color.b) end
            row.dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
            row.dropdown:SetSize(194, 24)
            row.dropdown:SetPoint("LEFT", 174, 0)
            row.dropdown.Text:SetJustifyH("LEFT")
            row.dropdown:SetDefaultText("Auto")
            row.dropdown:EnableMouseWheel(false)
            row.dropdown:SetupMenu(function(_, root)
                local suggested = (token == "WARRIOR" or token == "ROGUE") and "Might" or "Wisdom"
                for _, choice in ipairs({{"auto", "Auto: " .. suggested}, {"might", "Might"}, {"wisdom", "Wisdom"}, {"kings", "Kings"}, {"off", "Off"}}) do
                    root:CreateRadio(choice[2], function(rule) return A.GetPaladinRule(token) == rule end, function(rule)
                        A.SetPaladinRule(token, rule)
                        toolsPane:Render()
                    end, choice[1])
                end
            end)
            toolsPane.rows[i] = row
        end
        toolsPane.defaults = Button(toolsPane, "Suggested defaults", 186, 0, -410, function()
            for _, token in ipairs(A.paladinClasses) do A.SetPaladinRule(token, "auto") end
            toolsPane:Render()
        end)
        toolsPane.back = Button(toolsPane, "Back to bindings", 174, 210, -410, function() OpenPicker(selectedButton) end)
        toolsPane:SetScript("OnHide", function(self)
            for _, row in ipairs(self.rows) do row.dropdown:CloseMenu() end
        end)
        function toolsPane:Render()
            local names = LOCALIZED_CLASS_NAMES_MALE or {}
            for i, row in ipairs(self.rows) do
                local token = A.paladinClasses[i]
                row.class = token
                row.label:SetText(names[token] or token)
                row.dropdown:GenerateMenu()
                row:Show()
            end
        end
    end
    toolsPane.heading:SetText("Paladin blessings")
    toolsPane.description:SetText("Choose a blessing for each class. Auto suggests Might for warriors and rogues, Wisdom for everyone else including druids; Kings is a fallback if learned.")
    toolsPane.message:SetText("Single-target blessings; equal or stronger greater blessings count.")
    toolsPane:Render()
    toolsPane:Show()
end
local function FitEditor(host)
    if not panel or panel.embeddedHost ~= host then return end
    local width, height = host:GetWidth(), host:GetHeight()
    if width > 0 and height > 0 then panel:SetScale(math.min(1, width / 780, height / panel:GetHeight())) end
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
        local resetY = A.GetPlayerClass() == "PALADIN" and 558 or 526
        panel:SetSize(780, resetY + 66)
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
        divider:SetSize(1, resetY - 32)
        divider:SetPoint("TOPLEFT", 349, -43)
        local function Check(key, label, x, y, description, inverted)
            local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            check:SetPoint("TOPLEFT", x, y)
            -- Include the label in the hover/click area without stretching the
            -- stock checkbox artwork or overlapping adjacent rows.
            check:SetHitRectInsets(0, -124, 2, 2)
            local text = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", check, "RIGHT", 2, 0)
            text:SetText(label)
            check:SetScript("OnClick", function(self)
                local value = self:GetChecked()
                if inverted then value = not value end
                A.SetOption(key, value)
                Update()
            end)
            check:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 0.82, 0)
                GameTooltip:AddLine(description, 1, 1, 1, true)
                GameTooltip:Show()
            end)
            local function HideTip(self)
                if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end
            check:SetScript("OnLeave", HideTip)
            check:SetScript("OnHide", HideTip)
            return check
        end
        panel.buffs = Check("smartBuffs", "Buff watcher", 18, -37,
            "Prioritize missing class buffs and known rank upgrades on plain left-click outside combat. Below 90% health, your assigned heal takes priority over buffs. The icon and glow show the next buff; an unavailable spell is dimmed.")
        panel.cures = Check("cureWatch", "Cure watcher", 18, -65,
            "Prioritize a learned cure on plain left-click when a removable debuff is present. Runs outside combat while aura data is readable.")
        panel.combatRes = Check("combatResurrection", "Combat resurrection", 182, -37,
            "Include learned combat resurrection spells, such as Rebirth, in left-click priority for dead party or raid members. These spells may consume reagents. Off by default.")
        panel.player = Check("playerFrame", "Player frame", 18, -93,
            "Enable click healing and watch indicators on your own portrait. Shift + middle-click opens the AggeHealBot menu by default; all modifier bindings can be changed below.")
        panel.target = Check("targetFrame", "Target frame", 182, -93,
            "Enable click healing and watch indicators on the stock friendly target frame. Shift + middle-click opens the AggeHealBot menu by default; all modifier bindings can be changed below.")
        panel.rightClickMenu = Check("rightClickMenu", "Override rightclick", 18, -121,
            "Use your assigned plain right-click binding instead of the native unit menu on player and target frames. On by default. Turn this off to open the unit menu instead. Party and raid frames always use their assigned bindings; modifier bindings are unchanged.", true)
        panel.raidControls = Check("hideRaidControls", "Hide raid controls", 182, -121,
            "Hide Blizzard's raid-control side panel and its tab. Your party and raid unit frames stay visible.")
        panel.combatCures = Check("combatCures", "Cure in combat", 182, -65,
            "Show cure alerts during combat when debuff data is readable. Requires Cure watcher. The tooltip shows your assigned cure binding. Automatic left-click cure priority runs outside combat because combat bindings cannot change based on debuffs. On by default.")
        Text(panel, "MODIFIERS", 24, -164, "GameFontHighlightSmall")
        panel.tabs = {}
        local labels = {"None", "Shift", "Ctrl", "Alt", "Ctrl+Shift", "Alt+Shift", "Alt+Ctrl", "All 3"}
        for i, label in ipairs(labels) do
            panel.tabs[i] = Button(panel, label, 75, 24 + ((i - 1) % 4) * 78, -186 - math.floor((i - 1) / 4) * 30, function()
                selected = i
                OpenPicker(selectedButton)
            end)
            panel.tabs[i]:EnableSelectionGlow()
        end
        panel.mouse = A.CreateMouseBindings(panel, OpenPicker, function(button, index)
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetText(A.modifiers[selected].label .. A.buttons[index], 1, 0.82, 0)
            GameTooltip:AddLine(Value(Current(A.modifiers[selected].prefix, index)), 1, 1, 1, true)
            GameTooltip:Show()
        end)
        panel.rows = {}
        for i, button in ipairs(panel.mouse.buttons) do
            panel.rows[i] = {button = button}
        end
        panel.blessings = Button(panel, "Paladin blessings...", 315, 24, -526, OpenBlessings)
        Button(panel, "Reset all bindings", 155, 24, -resetY, function()
            A.ResetBindings()
            OpenPicker(selectedButton)
        end)
        panel.resetSettings = Button(panel, "Reset settings", 155, 184, -resetY, function()
            A.ResetOptions()
            Update()
        end)
        panel.status = Text(panel, "", 24, -resetY - 34, "GameFontHighlightSmall")
        panel.done = Button(panel, "Done", 100, 655, -resetY - 26, function() panel:Hide() end)
        panel:SetScript("OnHide", function() if picker then picker:Hide() end; if toolsPane then toolsPane:Hide() end end)
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
