local _, A = ...
local function Number(name)
    local number = ({LeftButton = 1, RightButton = 2, MiddleButton = 3})[name]
        or (type(name) == "string" and tonumber(name:match("^Button(%d+)$")))
    if number and number >= 1 and number <= A.maxMouseButtons then return number end
end
local function Prefix()
    return (IsAltKeyDown and IsAltKeyDown() and "alt-" or "")
        .. (IsControlKeyDown and IsControlKeyDown() and "ctrl-" or "")
        .. (IsShiftKeyDown and IsShiftKeyDown() and "shift-" or "")
end

function A.CreateButtonIdentifier(canvas, makeButton, detected, choose, hover)
    local control = {page = 1, active = false, chips = {}}
    local root = CreateFrame("Frame", nil, canvas)
    root:SetAllPoints(canvas)
    root:EnableMouse(false)
    local capture = CreateFrame("Frame", nil, root)
    capture:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -43)
    capture:SetSize(315, 172)
    capture:SetFrameLevel(root:GetFrameLevel() + 20)
    capture:EnableMouse(true)
    -- Focus only inside the capture area; propagation APIs are protected in combat.
    local input = CreateFrame("EditBox", nil, capture)
    input:SetSize(1, 1)
    input:SetPoint("BOTTOMLEFT")
    input:SetAutoFocus(false)
    input:EnableMouse(false)
    input:SetFontObject("GameFontNormalSmall")
    input:SetMaxLetters(1)
    control.input = input
    capture:SetScript("OnEnter", function() if control.active then input:SetFocus() end end)
    capture:SetScript("OnLeave", function() input:ClearFocus() end)
    local shade = capture:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0.02, 0.02, 0.02, 0.22)
    control.capture = capture
    local hint = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 6, 3)
    hint:SetPoint("BOTTOMRIGHT", -6, 3)
    hint:SetHeight(45)
    hint:SetWordWrap(true)
    control.hint = hint
    function control:Stop()
        self.active = false
        capture:Hide()
        input:ClearFocus()
        self.identify:SetText("Identify buttons")
        self.identify:Select(false)
    end
    control.identify = makeButton(root, "Identify buttons", 112, 0, 0, function()
        if control.active then control:Stop(); return end
        control.active = true
        if control.onStart then control.onStart() end
        control.identify:SetText("Stop identifying")
        control.identify:Select(true)
        hint:SetText("Hover here and press a button. Hold modifiers if desired.")
        capture:Show()
        if GameTooltip then GameTooltip:Hide() end
    end)
    capture:SetScript("OnMouseDown", function(_, name)
        if not control.active then return end
        local number = Number(name)
        if not number then hint:SetText("This mouse button is not supported by the client."); return end
        local prefix = Prefix()
        detected(number, prefix)
        local label = ""
        for _, mod in ipairs(A.modifiers) do if mod.prefix == prefix then label = mod.label; break end end
        hint:SetText("Detected: " .. label .. A.buttons[number])
    end)
    input:SetScript("OnKeyDown", function(self, key)
        if not control.active or not capture:IsMouseOver() then self:ClearFocus(); return end
        if key == "ESCAPE" then control:Stop(); return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
        hint:SetText("Received keyboard key " .. key .. ". This is not a mouse click; check your mouse software's button mapping.")
    end)
    input:SetScript("OnTextChanged", function(self) if self:GetText() ~= "" then self:SetText("") end end)
    local title = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("TOPLEFT", 0, -278)
    title:SetText("Extra buttons")
    control.title = title
    control.pageText = root:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    control.pageText:SetPoint("TOPLEFT", 193, -280)
    for slot = 1, 6 do
        local chip = makeButton(root, "", 47, (slot - 1) * 53, -298, function(self) if self.number then choose(self.number) end end)
        chip:EnableSelectionGlow()
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(18, 18)
        chip.icon:SetPoint("LEFT", 4, 0)
        chip.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        chip.label:ClearAllPoints()
        chip.label:SetPoint("LEFT", 24, 0)
        chip.label:SetPoint("RIGHT", -3, 0)
        chip:SetScript("OnEnter", function(self) if self.number then hover(self, self.number) end end)
        chip:SetScript("OnLeave", function(self)
            self:Select(self.selected)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        control.chips[slot] = chip
    end
    local function Page(delta)
        control.page = math.max(1, math.min(control.pages or 1, control.page + delta))
        control:Render(control.numbers, control.prefix, control.selected, control.current)
    end
    control.previous = makeButton(root, "<", 27, 254, -272, function() Page(-1) end)
    control.next = makeButton(root, ">", 27, 287, -272, function() Page(1) end)
    function control:Render(numbers, prefix, selected, current)
        self.numbers, self.prefix, self.current = numbers, prefix, current
        local extra = {}
        for _, number in ipairs(numbers) do if number > 5 then extra[#extra + 1] = number end end
        self.pages = math.max(1, math.ceil(#extra / 6))
        self.page = math.min(self.page, self.pages)
        if selected ~= self.selected then
            for index, number in ipairs(extra) do if number == selected then self.page = math.ceil(index / 6); break end end
        end
        self.selected = selected
        title:SetShown(#extra > 0)
        self.previous:SetShown(self.pages > 1)
        self.next:SetShown(self.pages > 1)
        self.pageText:SetText(self.pages > 1 and (self.page .. "/" .. self.pages) or "")
        self.previous:SetEnabled(self.page > 1)
        self.next:SetEnabled(self.page < self.pages)
        for slot, chip in ipairs(self.chips) do
            local number = extra[(self.page - 1) * 6 + slot]
            chip.number = number
            if number then
                chip:SetText(tostring(number))
                local icon, alpha = A.GetBindingVisual(current(prefix, number))
                chip.icon:SetTexture(icon)
                chip.icon:SetAlpha(alpha)
            end
            chip:Select(number ~= nil and number == selected)
            chip:SetShown(number ~= nil)
        end
        self.hasExtras = #extra > 0
    end
    root:SetScript("OnHide", function() control:Stop() end)
    control:Stop()
    return control
end
