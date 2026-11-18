-- Secret-value regression coverage for the real player-portrait glow path.
local secret = setmetatable({}, {
    __add = function() error("secret arithmetic") end,
    __sub = function() error("secret arithmetic") end,
    __mul = function() error("secret arithmetic") end,
    __div = function() error("secret arithmetic") end,
})
function issecretvalue(value) return value == secret end
local restrictedDimensions = false
local function forbiddenCoordinateRead() error("glow must not read screen coordinates or scales") end
local function region()
    local r = {points = {}}
    function r:SetPoint(point, relative, relativePoint, x, y)
        assert(x ~= secret and y ~= secret, "secret offset passed to SetPoint")
        self.points[point] = {relative = relative, point = relativePoint, x = x, y = y}
    end
    function r:SetSize(width, height)
        assert(type(width) == "number" and type(height) == "number", "secret dimensions passed to SetSize")
        self.width, self.height = width, height
    end
    function r:SetWidth(width) self.width = width end
    function r:ClearAllPoints() self.points = {} end
    function r:SetHeight(height) self.height = height end
    function r:SetTexture(texture) self.texture = texture end
    function r:SetAtlas(atlas) self.atlas = atlas end
    function r:GetAtlas() return self.atlas end
    function r:SetDesaturated(value) self.desaturated = value end
    function r:SetBlendMode(value) self.blendMode = value end
    function r:SetColorTexture() end
    function r:SetVertexColor() end
    function r:SetAlpha(value) self.alpha = value end
    function r:SetTexCoord(...) self.texCoord = {...} end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    r.GetLeft, r.GetRight, r.GetEffectiveScale = forbiddenCoordinateRead, forbiddenCoordinateRead, forbiddenCoordinateRead
    return r
end
function CreateFrame(_, _, parent)
    local frame = region()
    frame.textures, frame.children = {}, {}
    if parent then parent.children[#parent.children + 1] = frame end
    function frame:SetAllPoints() end
    function frame:GetFrameLevel() return 1 end
    function frame:SetFrameLevel() end
    function frame:EnableMouse() end
    function frame:CreateTexture()
        local texture = region()
        self.textures[#self.textures + 1] = texture
        return texture
    end
    function frame:CreateAnimationGroup()
        local pulse = {plays = 0}
        function pulse:SetLooping() end
        function pulse:CreateAnimation()
            return {SetFromAlpha = function() end, SetToAlpha = function() end,
                SetDuration = function() end, SetSmoothing = function() end}
        end
        function pulse:IsPlaying() return self.playing end
        function pulse:Play() self.playing = true; self.plays = self.plays + 1 end
        function pulse:Stop() self.playing = false end
        self.pulse = pulse
        return pulse
    end
    return frame
end
PlayerFrame = CreateFrame("Frame")
PlayerFrame.portrait = region()
function PlayerFrame.portrait:GetWidth() return restrictedDimensions and secret or 60 end
function PlayerFrame.portrait:GetHeight() return restrictedDimensions and secret or 60 end
PlayerFrame.healthbar, PlayerFrame.manabar = region(), region()
C_Spell = {GetSpellInfo = function() return {iconID = 123} end}
local A = {}
assert(loadfile("AggeHealBot/PetFrames.lua"))("AggeHealBot", A)
assert(loadfile("AggeHealBot/Indicators.lua"))("AggeHealBot", A)
A.UpdateBuffIndicator(PlayerFrame, "Mark of the Wild", 1126)
local overlay = PlayerFrame.children[1]
local arc, middle, cap, guide = overlay.textures[1], overlay.textures[2], overlay.textures[3], overlay.textures[4]
assert(arc.shown and middle.shown and cap.shown, "portrait glow must appear without readable screen coordinates")
assert(guide.points.BOTTOMRIGHT.relative == PlayerFrame.healthbar, "right edge must follow the health bar through native anchors")
assert(cap.points.TOP.relative == guide, "cap must follow the native right-edge guide")
assert(PlayerFrame.textures[1].points.TOPLEFT.relative == cap, "buff badge must follow the visible panel corner")
assert(PlayerFrame.textures[1].points.TOPLEFT.x == 3, "badge must sit just outside the panel")
assert(overlay.pulse.playing and overlay.pulse.plays == 1)
local previousSize = arc.width
restrictedDimensions = true
A.UpdateBuffIndicator(PlayerFrame, "Thorns", 467)
assert(arc.width == previousSize and arc.shown, "secret dimensions must preserve the previous layout")
assert(overlay.pulse.plays == 1, "restricted updates must not restart the pulse")
A.UpdateBuffIndicator(PlayerFrame)
assert(not arc.shown and not middle.shown and not cap.shown and not overlay.pulse.playing)
print("PASS: player glow uses native anchors, avoids secret coordinate arithmetic, retains safe geometry and clears its pulse")

restrictedDimensions = false
TargetFrame = CreateFrame("Frame")
local targetPortrait, targetHealth, targetMana = region(), region(), region()
function targetPortrait:GetWidth() return 60 end
function targetPortrait:GetHeight() return 60 end
function TargetFrame:GetPortrait() return targetPortrait end
TargetFrame.TargetFrameContent = {TargetFrameContentMain = {
    HealthBarsContainer = {HealthBar = targetHealth}, ManaBar = targetMana,
}}
A.targetButton = CreateFrame("Button", nil, TargetFrame)
A.UpdateBuffIndicator(A.targetButton, "Mark of the Wild", 1126)
local targetOverlay = A.targetButton.children[1]
local targetArc, targetMiddle, targetCap, targetGuide = targetOverlay.textures[1], targetOverlay.textures[2], targetOverlay.textures[3], targetOverlay.textures[4]
assert(targetArc.texCoord[1] == 1 and targetArc.texCoord[2] == 0, "target portrait outline must be mirrored")
assert(targetArc.points.TOPRIGHT.relative == targetPortrait and targetGuide.points.BOTTOMLEFT.relative == targetHealth)
assert(targetMiddle.points.TOPRIGHT.relative == targetArc and targetCap.points.TOP.relative == targetGuide)
assert(A.targetButton.textures[1].points.TOPLEFT.relative == targetPortrait and A.targetButton.textures[1].points.TOPLEFT.point == "TOPRIGHT", "target buff icon must sit outside the portrait, clear of its aura row")
A.UpdateBuffIndicator(A.targetButton)
assert(not targetArc.shown and not targetOverlay.pulse.playing, "clearing a target indicator must stop its glow")
print("PASS: mirrored target portrait/level outline, native anchor layout and external buff badge without coordinate reads")

-- Resolve the actual recorded anchor constraints with offset portrait/bar
-- heights. This catches conflicting TOP anchors that a no-op mock misses.
local function verticalBounds(region, cache)
    if region.testBounds then return region.testBounds[1], region.testBounds[2] end
    cache = cache or {}
    if cache[region] then return cache[region][1], cache[region][2] end
    local equations = {}
    local function topWeight(point)
        if point:find("TOP", 1, true) then return 1 end
        if point:find("BOTTOM", 1, true) then return 0 end
        return 0.5
    end
    for point, anchor in pairs(region.points) do
        local top, bottom = verticalBounds(anchor.relative, cache)
        local weight = topWeight(anchor.point)
        local value = weight * top + (1 - weight) * bottom + (anchor.y or 0)
        weight = topWeight(point)
        equations[#equations + 1] = {weight, 1 - weight, value}
    end
    if region.height then equations[#equations + 1] = {1, -1, region.height} end
    local top, bottom
    for i, a in ipairs(equations) do
        for j = i + 1, #equations do
            local b = equations[j]
            local determinant = a[1] * b[2] - a[2] * b[1]
            if math.abs(determinant) > 0.00001 then
                top = (a[3] * b[2] - a[2] * b[3]) / determinant
                bottom = (a[1] * b[3] - a[3] * b[1]) / determinant
                break
            end
        end
        if top then break end
    end
    assert(top and bottom, "outline anchors must determine vertical position")
    for _, equation in ipairs(equations) do
        assert(math.abs(equation[1] * top + equation[2] * bottom - equation[3]) < 0.00001,
            "outline has conflicting vertical anchors")
    end
    cache[region] = {top, bottom}
    return top, bottom
end
PlayerFrame.portrait.testBounds = {200, 140}
PlayerFrame.healthbar.testBounds = {180, 170}
targetPortrait.testBounds, targetHealth.testBounds = {320, 260}, {298, 288}
for _, pieces in ipairs({{arc, middle, cap}, {targetArc, targetMiddle, targetCap}}) do
    local arcTop = verticalBounds(pieces[1])
    local middleTop, middleBottom = verticalBounds(pieces[2])
    local capTop, capBottom = verticalBounds(pieces[3])
    assert(math.abs(arcTop - middleTop) < 0.00001 and math.abs(arcTop - capTop) < 0.00001,
        "portrait, middle and end cap must share the same top despite lower health bars")
    assert(math.abs(middleBottom - capBottom) < 0.00001, "middle and end cap must join at the same bottom")
end
print("PASS: player and mirrored target panels align vertically with offset portrait and health bar geometry")

TargetFrameToT = CreateFrame("Frame")
TargetFrameToT.FrameTexture = region()
TargetFrameToT.FrameTexture:SetAtlas("UI-HUD-UnitFrame-TargetofTarget-PortraitOn")
TargetFrameToT.HealthBar = region()
TargetFrameToT.FrameTexture.GetWidth = forbiddenCoordinateRead
TargetFrameToT.FrameTexture.GetHeight = forbiddenCoordinateRead
A.targetOfTargetButton = CreateFrame("Button", nil, TargetFrameToT)
A.UpdateBuffIndicator(A.targetOfTargetButton, "Thorns", 467)
local totOverlay = A.targetOfTargetButton.children[1]
assert(#totOverlay.textures == 3 and totOverlay.pulse.playing)
for _, texture in ipairs(totOverlay.textures) do
    assert(texture.atlas == "UI-HUD-UnitFrame-TargetofTarget-PortraitOn"
        and texture.desaturated and texture.blendMode == "ADD")
    assert(texture.points.TOPLEFT.relative == TargetFrameToT.FrameTexture
        and texture.points.BOTTOMRIGHT.relative == TargetFrameToT.FrameTexture,
        "mini-frame glow must trace the native portrait-and-bars artwork without reading geometry")
end
assert(A.targetOfTargetButton.textures[1].points.TOPLEFT.relative == TargetFrameToT.HealthBar,
    "buff badge follows the visible bar edge")
A.UpdateBuffIndicator(A.targetOfTargetButton)
assert(not totOverlay.pulse.playing and not totOverlay.textures[1].shown)
print("PASS: target-of-target glow traces native circular portrait/bar artwork, uses fade layers, avoids geometry reads and hides cleanly")

local compactFrame = CreateFrame("Frame")
local makeTexture = compactFrame.CreateTexture
function compactFrame:CreateTexture()
    local texture = makeTexture(self)
    texture.CreateAnimationGroup = self.CreateAnimationGroup
    return texture
end
compactFrame.GetWidth, compactFrame.GetHeight = forbiddenCoordinateRead, forbiddenCoordinateRead
local rounded = A.CreateGlow(compactFrame, compactFrame)
assert(#rounded == 8, "rounded frame glow uses four edges and four non-overlapping corners")
assert(rounded[1].texture.texture == "Interface\\AddOns\\AggeHealBot\\Media\\FrameGlowEdge")
assert(rounded[1].texture.points.TOPLEFT.x == 8 and rounded[1].texture.points.TOPRIGHT.x == -8)
for index = 5, 8 do
    assert(rounded[index].texture.texture == "Interface\\AddOns\\AggeHealBot\\Media\\FrameGlowCorner")
    assert(rounded[index].texture.points.CENTER.relative == compactFrame)
end
assert(rounded[6].texture.texCoord[1] == 1 and rounded[7].texture.texCoord[3] == 1,
    "corner masks must mirror into the correct quadrants")
A.SetGlow(rounded, {1, 0.6, 0.12}, true)
assert(rounded[1].pulse.playing and rounded[8].texture.shown)
A.SetGlow(rounded, {1, 0.6, 0.12}, false)
assert(not rounded[1].pulse.playing and not rounded[8].texture.shown)
print("PASS: rounded rectangular frame glow uses matching non-overlapping soft masks, native anchors, correct corner orientation and pulse cleanup")

FocusFrame = CreateFrame("Frame")
local focusPortrait = region()
function focusPortrait:GetWidth() return 40 end
function focusPortrait:GetHeight() return 40 end
function FocusFrame:GetPortrait() return focusPortrait end
FocusFrame.healthbar, FocusFrame.manabar = region(), region()
A.focusButton = CreateFrame("Button", nil, FocusFrame)
A.UpdateBuffIndicator(A.focusButton, "Thorns", 467)
local focusOverlay = A.focusButton.children[1]
assert(focusOverlay.textures[1].texCoord[1] == 1 and focusOverlay.textures[1].texCoord[2] == 0)
assert(focusOverlay.textures[1].points.TOPRIGHT.relative == focusPortrait)
assert(focusOverlay.textures[4].points.BOTTOMLEFT.relative == FocusFrame.healthbar,
    "focus glow follows its own bar geometry instead of the target's")
assert(A.focusButton.textures[1].points.TOPLEFT.relative == focusPortrait)
A.UpdateBuffIndicator(A.focusButton)
assert(not focusOverlay.pulse.playing and not focusOverlay.textures[1].shown)
print("PASS: mirrored focus outline follows its own portrait and bars at small frame sizes, anchors its badge and stops cleanly")

-- Pet frames must trace their own artwork, rather than the target's contour.
PetFrame = CreateFrame("Frame")
PetFrameTexture = region()
PetFrameTexture:SetAtlas("UI-HUD-UnitFrame-TargetofTarget-PortraitOn")
PetFrame.healthbar = region()
PetFrameTexture.GetWidth, PetFrameTexture.GetHeight = forbiddenCoordinateRead, forbiddenCoordinateRead
A.UpdateBuffIndicator(PetFrame, "Mark", 1126)
local petGlow = PetFrame.children[1]
assert(#petGlow.textures == 3 and petGlow.pulse.playing)
for _, texture in ipairs(petGlow.textures) do
    assert(texture.points.TOPLEFT.relative == PetFrameTexture and texture.points.BOTTOMRIGHT.relative == PetFrameTexture)
end
A.UpdateBuffIndicator(PetFrame)
assert(not petGlow.pulse.playing)
local partyOwner = CreateFrame("Frame")
local partyPet = CreateFrame("Frame", nil, partyOwner)
partyOwner.PetFrame = partyPet
function partyPet:GetParent() return partyOwner end
partyPet.Texture = region()
partyPet.Texture:SetAtlas("ui-hud-unitframe-party-portraiton")
partyPet.Texture.GetWidth, partyPet.Texture.GetHeight = forbiddenCoordinateRead, forbiddenCoordinateRead
partyPet.HealthBar = region()
A.UpdateBuffIndicator(partyPet, "Mark", 1126)
assert(partyPet.children[1].textures[1].points.TOPLEFT.relative == partyPet.Texture)
assert(partyPet.children[1].textures[1].atlas == "ui-hud-unitframe-party-portraiton")
print("PASS: pet and normal party-pet glow traces the correct native circle/bar artwork, avoids restricted geometry reads and stops cleanly")
