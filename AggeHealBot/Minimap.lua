local _, A = ...
local button
local function number(value)
    return not (issecretvalue and issecretvalue(value)) and type(value) == "number"
end
local function Position()
    if not button or not Minimap then return end
    local width, height = Minimap:GetWidth(), Minimap:GetHeight()
    if not number(width) or not number(height) then return end
    local angle = AggeHealBotDB.minimapAngle
    if not number(angle) then angle = 225 end
    local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    local shape = GetMinimapShape and GetMinimapShape()
    if not (issecretvalue and issecretvalue(shape)) and shape == "SQUARE" then
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * (width / 2 + 8), y * (height / 2 + 8))
end
local function Drag()
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not number(cursorX) or not number(cursorY) or not number(centerX) or not number(centerY)
        or not number(scale) or scale <= 0 then return end
    local x, y = cursorX / scale - centerX, cursorY / scale - centerY
    local angle
    if math.atan2 then angle = math.atan2(y, x)
    elseif x > 0 then angle = math.atan(y / x)
    elseif x < 0 then angle = math.atan(y / x) + (y >= 0 and math.pi or -math.pi)
    else angle = y >= 0 and math.pi / 2 or -math.pi / 2 end
    AggeHealBotDB.minimapAngle = math.deg(angle) % 360
    Position()
end
function A.UpdateMinimap()
    if not AggeHealBotDB or not Minimap then return end
    if not AggeHealBotDB.showMinimap then
        if button then button:Hide(); button:SetScript("OnUpdate", nil) end
        return
    end
    if not button then
        button = CreateFrame("Button", "AggeHealBotMinimapButton", Minimap)
        button:SetSize(31, 31)
        button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        local icon = button:CreateTexture(nil, "BACKGROUND")
        icon:SetSize(20, 20)
        icon:SetPoint("TOPLEFT", 7, -5)
        icon:SetTexture("Interface\\AddOns\\AggeHealBot\\Media\\Icon")
        local border = button:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetPoint("TOPLEFT")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        button:SetScript("OnClick", function(self)
            if not self.dragging and not self.ignoreClick and A.ToggleOptions then A.ToggleOptions() end
        end)
        button:SetScript("OnDragStart", function(self)
            self.dragging = true
            self:SetScript("OnUpdate", Drag)
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        button:SetScript("OnDragStop", function(self)
            Drag()
            self:SetScript("OnUpdate", nil)
            self.dragging, self.ignoreClick = false, true
            C_Timer.After(0.05, function() self.ignoreClick = false end)
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("AggeHealBot", 1, 0.82, 0)
            GameTooltip:AddLine("Click to toggle settings. Drag to move.", 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        button:SetScript("OnHide", function(self)
            self:SetScript("OnUpdate", nil)
            self.dragging = false
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        A.minimapButton = button
    end
    Position()
    button:Show()
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", A.UpdateMinimap)
A.UpdateMinimap()
