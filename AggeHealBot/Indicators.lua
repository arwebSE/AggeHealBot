local _, A = ...
local indicators = {}
local colors = {
    [1126] = {0.8, 0.3, 1},       -- Mark of the Wild
    [467] = {1, 0.6, 0.12},       -- Thorns
    [1243] = {1, 0.85, 0.45},     -- Fortitude
    [14752] = {0.55, 0.75, 1},    -- Divine Spirit
    [976] = {0.6, 0.3, 0.95},     -- Shadow Protection
    [1459] = {0.3, 0.65, 1},      -- Arcane Intellect
}
local fallbackColor = {0.5, 1, 0.65}

-- A continuous alpha mask avoids the clipped dashes produced by rotating small
-- solid-color textures. All pieces share one pulse and one stroke profile.
local function CreatePlayerGlow(host, portrait, health, mana)
    local glow = {}
    local overlay = CreateFrame("Frame", nil, host)
    overlay:SetFrameLevel(host:GetFrameLevel() + 10)
    overlay:SetAllPoints(host)
    overlay:EnableMouse(false)
    local media = "Interface\\AddOns\\AggeHealBot\\Media\\"
    local function piece(asset)
        local texture = overlay:CreateTexture(nil, "OVERLAY", nil, 7)
        texture:SetTexture(media .. asset, "CLAMP", "CLAMP")
        glow[#glow + 1] = {texture = texture, alpha = 1, asset = true}
        return texture
    end

    -- Three horizontal slices preserve the portrait/level circles and panel
    -- corners while allowing the middle of the bar stack to stretch.
    local arc = piece("PlayerGlowArc")
    local middle = piece("PlayerGlowHorizontal")
    local cap = piece("PlayerGlowVertical")
    local function layout()
        local width, height = portrait:GetWidth(), portrait:GetHeight()
        local scale = (height + 16) / 112
        local capWidth = 32 * scale
        local frameScale = overlay:GetEffectiveScale()
        local left = portrait:GetLeft()
        local right = health:GetRight()
        if not left or not right then return end
        local span = (right * health:GetEffectiveScale() - left * portrait:GetEffectiveScale()) / frameScale
        -- Expanded transparent margins keep the blur intact on every side,
        -- without moving the established portrait, level or panel contours.
        local paddedTop = 8 + 8 * scale
        arc:SetPoint("TOPLEFT", portrait, "TOPLEFT", -8 - (width + 16) * 16 / 112, paddedTop)
        arc:SetSize((width + 16) * 128 / 112, (height + 16) * 144 / 112)
        cap:SetPoint("TOPLEFT", portrait, "TOPLEFT", span + 1 - capWidth / 2, paddedTop)
        cap:SetSize(capWidth, (height + 16) * 128 / 112)
        middle:SetPoint("TOPLEFT", arc, "TOPRIGHT")
        middle:SetPoint("BOTTOMRIGHT", cap, "BOTTOMLEFT")
    end
    glow.layout = layout
    layout()

    local pulse = overlay:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local animation = pulse:CreateAnimation("Alpha")
    animation:SetFromAlpha(0.6)
    animation:SetToAlpha(1)
    animation:SetDuration(0.9)
    animation:SetSmoothing("IN_OUT")
    glow.pulse, glow.overlay = pulse, overlay
    return glow
end

local function CreateGlow(host, frame, compact, bounds)
    local glow = {}
    -- Animate texture alpha through the client, with no Lua OnUpdate loop.
    local layers = compact and {{2, 3, 0.10}, {1, 2, 0.24}, {0, 1, 0.9}}
        or {{4, 5, 0.10}, {2, 3, 0.24}, {0, 1, 0.9}}
    for _, layer in ipairs(layers) do
        local spread, width, alpha = layer[1], layer[2], layer[3]
        for _, side in ipairs({"TOP", "BOTTOM", "LEFT", "RIGHT"}) do
            local edge = host:CreateTexture(nil, "OVERLAY", nil, 4)
            if side == "TOP" or side == "BOTTOM" then
                local y = side == "TOP" and spread or -spread
                local left = bounds and bounds.left or frame
                local right = bounds and bounds.right or frame
                edge:SetPoint(side .. "LEFT", left, side .. "LEFT", -spread, y)
                edge:SetPoint(side .. "RIGHT", right, side .. "RIGHT", spread, y)
                edge:SetHeight(width)
            else
                local x = side == "LEFT" and -spread or spread
                local top = bounds and bounds[side == "LEFT" and "left" or "right"] or frame
                local bottom = top
                if bounds then
                    top = bounds[side == "LEFT" and "leftTop" or "rightTop"]
                    bottom = bounds[side == "LEFT" and "leftBottom" or "rightBottom"]
                end
                edge:SetPoint("TOP" .. side, top, "TOP" .. side, x, spread)
                edge:SetPoint("BOTTOM" .. side, bottom, "BOTTOM" .. side, x, -spread)
                edge:SetWidth(width)
            end
            local pulse = edge:CreateAnimationGroup()
            pulse:SetLooping("BOUNCE")
            local animation = pulse:CreateAnimation("Alpha")
            animation:SetFromAlpha(0.4)
            animation:SetToAlpha(1)
            animation:SetDuration(0.9)
            animation:SetSmoothing("IN_OUT")
            glow[#glow + 1] = {texture = edge, alpha = alpha, pulse = pulse}
        end
    end
    return glow
end
A.CreateGlow = CreateGlow
A.SetGlow = function(glow, color, active)
    if active and glow.layout then glow.layout() end
    if glow.pulse then
        if active then
            if not glow.pulse:IsPlaying() then glow.pulse:Play() end
        else
            glow.pulse:Stop()
        end
    end
    for _, edge in ipairs(glow) do
        if active then
            if edge.asset then
                edge.texture:SetVertexColor(color[1], color[2], color[3], edge.alpha)
            else
                edge.texture:SetColorTexture(color[1], color[2], color[3], edge.alpha)
            end
            edge.texture:Show()
            if edge.pulse and not edge.pulse:IsPlaying() then edge.pulse:Play() end
        else
            if edge.pulse then edge.pulse:Stop() end
            edge.texture:Hide()
        end
    end
end

-- Regions on the existing stock frame: no extra clickable frame intercepts heals.
-- Texture visibility can change in combat without touching protected buttons.
function A.UpdateBuffIndicator(frame, spell, spellID)
    local view = indicators[frame]
    if not spell then
        if view then
            view.background:Hide()
            view.icon:Hide()
            A.SetGlow(view.glow, fallbackColor, false)
        end
        return
    end
    if not view then
        view = {}
        -- Keep the outline above the health bar, but anchor the next-buff badge
        -- outside the whole unit frame so it cannot cover Blizzard's aura row.
        -- PlayerFrame's health bar is a nested status bar; parent the outline
        -- to the whole portrait so the pulse frames its name and both bars.
        local isPlayerFrame = frame == PlayerFrame
        local host = isPlayerFrame and frame
            or frame.healthBar or frame.healthbar or frame.HealthBar or frame
        view.background = frame:CreateTexture(nil, "OVERLAY", nil, 5)
        view.background:SetColorTexture(0.04, 0.08, 0.04, 0.9)
        view.background:SetSize(22, 22)
        view.background:SetPoint("TOPLEFT", frame, "TOPRIGHT", 6, -2)
        view.icon = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        view.icon:SetSize(20, 20)
        view.icon:SetPoint("TOPLEFT", view.background, "TOPLEFT", 1, -1)
        view.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local playerPortrait, playerHealth, playerMana
        if isPlayerFrame then
            playerPortrait = frame.portrait or _G.PlayerFramePortrait
            playerHealth = frame.healthbar or frame.healthBar or _G.PlayerFrameHealthBar
            playerMana = frame.manabar or frame.manaBar or _G.PlayerFrameManaBar
        end
        view.glow = playerPortrait and playerHealth and playerMana
            and CreatePlayerGlow(host, playerPortrait, playerHealth, playerMana)
            or CreateGlow(host, frame)
        indicators[frame] = view
    end
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID or spell)
    view.icon:SetTexture(info and info.iconID or 134400)
    local color = colors[spellID] or fallbackColor
    view.background:SetColorTexture(color[1], color[2], color[3], 1)
    A.SetGlow(view.glow, color, true)
    view.background:Show()
    view.icon:Show()
end

function A.HideBuffIndicators()
    for frame in pairs(indicators) do A.UpdateBuffIndicator(frame) end
end
