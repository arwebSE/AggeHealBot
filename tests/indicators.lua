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
    function r:SetTexCoord() end
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
assert(guide.points.TOPRIGHT.relative == PlayerFrame.healthbar, "right edge must follow the health bar through native anchors")
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
