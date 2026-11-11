local _, A = ...
local media = "Interface\\AddOns\\AggeHealBot\\Media\\"
local highlight = {1, 0.06, 0.025}
local actionIcons = {target = 132212, assist = 132179, togglemenu = 134331, settings = 136243, none = 132156}
-- Exact sprites and pulse timing used by Blizzard's classic TutorialFrame.
local tutorialTexture = "Interface\\TutorialFrame\\UI-TUTORIAL-FRAME"
local sprites = {
    neutral = {0.1542969, 0.3007813, 0.4257813, 0.6210938},
    {0.0019531, 0.1484375, 0.4257813, 0.6210938},
    {0.0019531, 0.1484375, 0.6269531, 0.8222656},
}
local function Sprite(texture, coords)
    -- Smooth the small native sprite at fractional UI scales. Pixel snapping
    -- otherwise creates uneven edges as the tutorial artwork is enlarged.
    texture:SetTexture(tutorialTexture, "CLAMP", "CLAMP", "TRILINEAR")
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
end

function A.CreateMouseBindings(parent, choose, hover)
    local canvas = CreateFrame("Frame", nil, parent)
    canvas:SetSize(315, 264)
    canvas:SetPoint("TOPLEFT", 24, -252)
    local width, height = 124, 124 * 101 / 76
    local artX, artY = 157.5 - width / 2, 47
    local art = CreateFrame("Frame", nil, canvas)
    art:SetSize(width, height)
    art:SetPoint("TOPLEFT", artX, -artY)
    local body = art:CreateTexture(nil, "BACKGROUND")
    body:SetAllPoints(art)
    Sprite(body, sprites.neutral)
    canvas.body = body
    canvas.art = art
    -- Primary regions follow the native artwork. Additional thumb buttons are
    -- drawn onto the shell, without spell icons covering the physical controls.
    local regions = {
        {x = artX + width * 0.14, y = artY + height * 0.03, width = width * 0.30, height = height * 0.36, icon = 23, sprite = sprites[1]},
        {x = artX + width * 0.56, y = artY + height * 0.03, width = width * 0.30, height = height * 0.36, icon = 23, sprite = sprites[2]},
        -- Keep the wheel's original shading visible. The tutorial's full red
        -- wheel sprite spills past the neutral wheel onto the shell seam.
        {x = artX + width * 0.4525, y = artY + height * 0.24, width = width * 0.095, height = height * 0.17, icon = 14, wheel = true},
        {x = artX + width * 0.055, y = artY + height * 0.64, width = 17, height = 29, icon = 18, tag = "4"},
        {x = artX + width * 0.015, y = artY + height * 0.43, width = 17, height = 29, icon = 18, tag = "5"},
    }
    canvas.buttons = {}
    for i, region in ipairs(regions) do
        local button = CreateFrame("Button", nil, canvas)
        button:SetSize(region.width, region.height)
        button:SetPoint("TOPLEFT", region.x, -region.y)
        if region.tag then
            local fill = button:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            fill:SetTexture(media .. "MouseSideButton")
            local tag = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tag:SetPoint("CENTER")
            tag:SetText(region.tag)
            tag:SetTextColor(1, 0.96, 0.9)
        end
        button.overlay = region.sprite and art:CreateTexture(nil, "ARTWORK") or button:CreateTexture(nil, "ARTWORK")
        if region.sprite then
            button.overlay:SetAllPoints(art)
            Sprite(button.overlay, region.sprite)
        else
            button.overlay:SetAllPoints()
            button.overlay:SetTexture(media .. "MouseSideGlow")
            button.overlay:SetVertexColor(highlight[1], highlight[2], highlight[3])
            if region.wheel then button.overlay:SetBlendMode("ADD") end
        end
        button.overlay:SetAlpha(0)
        button.pulse = button.overlay:CreateAnimationGroup()
        button.pulse:SetLooping("BOUNCE")
        local alpha = button.pulse:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(region.wheel and 0.65 or 1)
        alpha:SetDuration(0.8)
        alpha:SetSmoothing("IN_OUT")
        button.icon = button:CreateTexture(nil, "OVERLAY")
        button.icon:SetSize(region.icon, region.icon)
        button.icon:SetPoint("CENTER")
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon:Hide()
        -- Outside callouts show all assignments without covering the mouse.
        local callout = CreateFrame("Button", nil, canvas)
        local calloutX = (i == 2 or i == 3) and 245 or 12
        if i == 1 then calloutX = 48 elseif i == 2 then calloutX = 209 elseif i == 3 then calloutX = 128.5 end
        local calloutY = ({54, 54, 0, 156, 109})[i]
        callout:SetSize(58, 42)
        callout:SetPoint("TOPLEFT", calloutX, -calloutY)
        callout.title = callout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        callout.title:SetPoint("TOPLEFT", 0, 0)
        callout.title:SetWidth(58)
        callout.title:SetJustifyH("CENTER")
        callout.title:SetText(A.buttons[i])
        callout.icon = callout:CreateTexture(nil, "ARTWORK")
        callout.icon:SetSize(26, 26)
        callout.icon:SetPoint("TOPLEFT", 16, -16)
        callout.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.callout = callout
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.label:Hide()
        function button:SetText(value) self.label:SetText(value) end
        function button:Select(value)
            self.selected = value
            self.callout.title:SetTextColor(1, value and 0.82 or 1, value and 0 or 1)
            if region.sprite then self.overlay:SetDrawLayer("ARTWORK", value and 1 or 0) end
            if value then
                self.overlay:SetAlpha(1)
                if not self.pulse:IsPlaying() then self.pulse:Play() end
            else
                self.pulse:Stop()
                self.overlay:SetAlpha(0)
            end
        end
        function button:SetBinding(binding)
            local spell = binding and (binding.spellID or binding.spell or binding.expected)
            local isSpell = binding and binding.action == "spell"
            local info = isSpell and spell and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spell)
            self.bindingIcon = isSpell and (info and info.iconID or 134400) or actionIcons[binding and binding.action or "none"]
            self.icon:SetTexture(self.bindingIcon)
            self.callout.icon:SetTexture(self.bindingIcon)
            local learned = isSpell and binding.spell and A.IsSpellLearned(binding.spell, binding.spellID)
            self.bindingAlpha = isSpell and not learned and 0.4 or binding and binding.action == "none" and 0.25 or 1
            self.icon:SetAlpha(self.bindingAlpha)
            self.callout.icon:SetAlpha(self.bindingAlpha)
        end
        button:SetScript("OnClick", function() choose(i) end)
        callout:SetScript("OnClick", function() choose(i) end)
        local function Enter(owner)
            button.hoverOwner = owner
            if region.sprite then button.overlay:SetDrawLayer("ARTWORK", 2) end
            if not button.selected then button.overlay:SetAlpha(0.65) end
            button.callout.title:SetTextColor(1, 0.82, 0)
            hover(owner, i)
        end
        local function Leave(owner)
            if button.hoverOwner ~= owner then return end
            button.hoverOwner = nil
            button:Select(button.selected)
            if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
        end
        button:SetScript("OnEnter", Enter)
        button:SetScript("OnLeave", Leave)
        callout:SetScript("OnEnter", Enter)
        callout:SetScript("OnLeave", Leave)
        callout:SetScript("OnHide", Leave)
        button:SetScript("OnHide", function(self)
            self.pulse:Stop()
            self.overlay:SetAlpha(0)
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        canvas.buttons[i] = button
    end
    canvas:SetScript("OnHide", function(self)
        for _, button in ipairs(self.buttons) do
            button.pulse:Stop(); button.overlay:SetAlpha(0)
            button.hoverOwner = nil
            if GameTooltip and (GameTooltip:IsOwned(button) or GameTooltip:IsOwned(button.callout)) then GameTooltip:Hide() end
        end
    end)
    canvas:SetScript("OnShow", function(self)
        for _, button in ipairs(self.buttons) do button:Select(button.selected) end
    end)
    canvas.captionTitle = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    canvas.captionTitle:SetPoint("TOPLEFT", 0, -219)
    canvas.captionTitle:SetWidth(315)
    canvas.captionTitle:SetJustifyH("CENTER")
    canvas.captionTitle:SetTextColor(1, 0.82, 0)
    canvas.captionIcon = canvas:CreateTexture(nil, "OVERLAY")
    canvas.captionIcon:SetSize(24, 24)
    canvas.captionIcon:SetPoint("TOPLEFT", 24, -238)
    canvas.captionIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    canvas.caption = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    canvas.caption:SetPoint("TOPLEFT", 58, -238)
    canvas.caption:SetSize(233, 26)
    canvas.caption:SetJustifyH("LEFT")
    canvas.caption:SetWordWrap(true)
    function canvas:SetCaption(title, value, icon, alpha)
        self.captionTitle:SetText(title)
        self.caption:SetWidth(233)
        self.caption:SetText(value)
        local textWidth = math.max(1, math.min(233, math.ceil(self.caption:GetStringWidth())))
        local startX = (315 - textWidth - 34) / 2
        self.caption:SetWidth(textWidth)
        self.caption:ClearAllPoints()
        self.caption:SetPoint("TOPLEFT", startX + 34, -238)
        self.captionIcon:ClearAllPoints()
        self.captionIcon:SetPoint("TOPLEFT", startX, -238)
        self.captionIcon:SetTexture(icon)
        self.captionIcon:SetAlpha(alpha)
    end
    return canvas
end
