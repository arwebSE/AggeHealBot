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
