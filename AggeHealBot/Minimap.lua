local ADDON, A = ...
local icon = LibStub("LibDBIcon-1.0")
local broker = LibStub("LibDataBroker-1.1")
local launcher = broker:GetDataObjectByName(ADDON) or broker:NewDataObject(ADDON, {
    type = "launcher",
    text = ADDON,
    icon = "Interface\\AddOns\\AggeHealBot\\Media\\Icon",
    OnClick = function(_, button)
        if (button == "LeftButton" or button == "RightButton") and A.ToggleOptions then A.ToggleOptions() end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:SetText(ADDON, 1, 0.82, 0)
        tooltip:AddLine("Click to toggle settings. Drag to move.", 1, 1, 1)
    end,
})
function A.UpdateMinimap()
    if not AggeHealBotDB then return end
    local db = AggeHealBotDB.minimap
    if type(db) ~= "table" then
        local angle = AggeHealBotDB.minimapAngle
        local valid = not (issecretvalue and issecretvalue(angle)) and type(angle) == "number"
        db = {minimapPos = valid and angle or 225}
        AggeHealBotDB.minimap = db
    end
    db.hide = not AggeHealBotDB.showMinimap
    if not icon:IsRegistered(ADDON) then icon:Register(ADDON, launcher, db)
    elseif icon:GetMinimapButton(ADDON).db ~= db then icon:Refresh(ADDON, db) end
    if db.hide then icon:Hide(ADDON) else icon:Show(ADDON) end
    A.minimapButton = icon:GetMinimapButton(ADDON)
    AggeHealBotDB.minimapAngle = nil
end
local events = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent", A.UpdateMinimap)
A.UpdateMinimap()
