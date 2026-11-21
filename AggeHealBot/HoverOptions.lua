local _, A = ...
function A.CreateHoverKeyEditor(parent, makeButton, text, choose, changed)
    local editor = CreateFrame("Frame", nil, parent)
    editor:SetPoint("TOPLEFT", 24, -178)
    editor:SetSize(315, 380)
    editor.page = 1
    text(editor, "Click the field and press a key to add it.", 0, 0, "GameFontHighlightSmall")
    local input = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    editor.input = input
    input:SetSize(299, 27)
    input:SetPoint("TOPLEFT", 8, -27)
    input:SetAutoFocus(false)
    input:SetMaxLetters(1)
    input:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:ClearFocus(); return end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
        local full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "")
            .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
        if not A.IsHoverKey(full) then self:SetText("Unsupported key"); return end
        if not (AggeHealBotDB.hoverBindings or {})[full] then A.SaveHoverBinding(full, "none") end
        self:ClearFocus()
        self:SetText("")
        choose(full)
        changed()
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnTextChanged", function(self, user) if user then self:SetText("") end end)
    editor.empty = text(editor, "No keys yet. Add one above, then choose a spell.", 0, -79, "GameFontHighlightSmall")
    editor.empty:SetWidth(310)
    editor.empty:SetWordWrap(true)
    editor.rows = {}
    for i = 1, 8 do
        local row = makeButton(editor, "", 315, 0, -70 - (i - 1) * 33, function(self) choose(self.key) end)
        row.label:SetJustifyH("LEFT")
        editor.rows[i] = row
    end
    editor.pageText = text(editor, "", 141, -345, "GameFontHighlightSmall")
    editor.previous = makeButton(editor, "<", 34, 0, -336, function() editor.page = editor.page - 1; changed() end)
    editor.next = makeButton(editor, ">", 34, 281, -336, function() editor.page = editor.page + 1; changed() end)
    function editor:Render(selected, value)
        local keys = A.GetHoverKeys()
        self.pages = math.max(1, math.ceil(#keys / 8))
        self.page = math.max(1, math.min(self.page, self.pages))
        if selected ~= self.selected then
            for index, key in ipairs(keys) do if key == selected then self.page = math.ceil(index / 8); break end end
        end
        self.selected = selected
        self.empty:SetShown(#keys == 0)
        self.previous:SetEnabled(self.page > 1)
        self.next:SetEnabled(self.page < self.pages)
        self.pageText:SetText(self.page .. " / " .. self.pages)
        for index, row in ipairs(self.rows) do
            local key = keys[(self.page - 1) * 8 + index]
            row.key = key
            if key then row:SetText(key .. "  —  " .. value(A.GetHoverBinding(key))) end
            row:Select(key ~= nil and key == selected)
            row:SetShown(key ~= nil)
        end
    end
    editor:SetScript("OnHide", function() input:ClearFocus() end)
    return editor
end
