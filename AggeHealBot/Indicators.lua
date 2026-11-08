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

local function CreateGlow(host, frame, compact)
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
                edge:SetPoint(side .. "LEFT", frame, side .. "LEFT", -spread, y)
                edge:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", spread, y)
                edge:SetHeight(width)
            else
                local x = side == "LEFT" and -spread or spread
                edge:SetPoint("TOP" .. side, frame, "TOP" .. side, x, spread)
                edge:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, x, -spread)
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
    for _, edge in ipairs(glow) do
        if active then
            edge.texture:SetColorTexture(color[1], color[2], color[3], edge.alpha)
            edge.texture:Show()
            if not edge.pulse:IsPlaying() then edge.pulse:Play() end
        else
            edge.pulse:Stop()
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
        -- Compact frame health bars are child frames; draw on their overlay layer
        -- so the icon stays above the health fill without changing frame levels.
        local host = frame.healthBar or frame.healthbar or frame.HealthBar or frame
        view.background = host:CreateTexture(nil, "OVERLAY", nil, 5)
        view.background:SetColorTexture(0.04, 0.08, 0.04, 0.9)
        view.background:SetSize(22, 22)
        view.background:SetPoint("BOTTOMRIGHT", -2, 2)
        view.icon = host:CreateTexture(nil, "OVERLAY", nil, 6)
        view.icon:SetSize(20, 20)
        view.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        view.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        view.glow = CreateGlow(host, frame)
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
