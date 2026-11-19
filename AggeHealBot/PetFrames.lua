local _, A = ...
local function public(value) return not (issecretvalue and issecretvalue(value)) end
function A.IsPetToken(unit)
    if not public(unit) or type(unit) ~= "string" then return false end
    return unit == "pet" or unit:match("^partypet%d+$") ~= nil or unit:match("^raidpet%d+$") ~= nil
end
function A.IsPetUnit(unit)
    if A.IsPetToken(unit) then return true end
    if not public(unit) or type(unit) ~= "string" then return false end
    for _, check in pairs({UnitIsOtherPlayersPet, UnitIsUnit and function(token) return UnitIsUnit(token, "pet") end}) do
        local ok, value = pcall(check, unit)
        if ok and public(value) and value == true then return true end
    end
    return false
end
local function partyPet(frame)
    local parent = frame.GetParent and frame:GetParent()
    return parent and parent.PetFrame == frame
end
function A.IsPetFrame(frame)
    if not frame or (frame.IsForbidden and frame:IsForbidden()) or frame.namePlateFrame or not frame.GetAttribute then return false end
    if frame == PetFrame or partyPet(frame) then return true end
    local name = frame.GetName and frame:GetName() or ""
    local unit = frame:GetAttribute("unit")
    if not public(unit) then return false end
    if not unit then unit = frame.unit end
    return name:match("^PartyMemberFrame%d+PetFrame$") ~= nil
        or name:match("^Compact.*Frame") ~= nil and A.IsPetToken(unit)
end
function A.PetFrameArtwork(frame)
    if frame == PetFrame then return PetFrame, _G.PetFrameTexture or frame.FrameTexture end
    if partyPet(frame) then return frame, frame.Texture or frame.FrameTexture end
end
function A.DiscoverPetFrames(register)
    register(PetFrame)
    for i = 1, 5 do
        register(_G["PartyMemberFrame" .. i .. "PetFrame"])
        for _, prefix in ipairs({"PartyMemberFrame", "PartyFrameMemberFrame"}) do
            local member = _G[prefix .. i]
            if member then register(member.PetFrame) end
        end
        local member = PartyFrame and ((PartyFrame.GetPartyMemberFrame and PartyFrame:GetPartyMemberFrame(i)) or PartyFrame["MemberFrame" .. i])
        if member then register(member.PetFrame) end
    end
    local mini = CompactRaidFrameContainer and CompactRaidFrameContainer.frameUpdateList and CompactRaidFrameContainer.frameUpdateList.mini
    for _, frame in pairs(mini or {}) do if A.IsPetFrame(frame) then register(frame) end end
    -- Fallback for compact frames created before their container lists settle.
    for i = 1, 80 do
        local frame = _G["CompactRaidFrame" .. i]
        if A.IsPetFrame(frame) then register(frame) end
    end
end
