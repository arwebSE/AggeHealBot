local _, A = ...
local function secret(v) return issecretvalue and issecretvalue(v) end
local function number(v) return not secret(v) and type(v) == "number" end
local function flag(api, ...)
    if not api then return false end
    local ok, value = pcall(api, ...)
    return ok and not secret(value) and value == true
end
local function UnavailableReason()
    if flag(UnitIsGhost, "player") then return "Ghost" end
    if flag(UnitIsDeadOrGhost, "player") then return "Dead" end
    if flag(IsMounted) then return "Mounted" end
    if flag(UnitInVehicle, "player") then return "In a vehicle" end
    return "Spell unavailable"
end

-- Hints only. The game validates resource/cooldown failures; these never
-- replace protected combat bindings or make decisions from secret values.
function A.CastProblem(spell, unit)
    if not spell or InCombatLockdown() then return end
    local range = C_Spell and C_Spell.IsSpellInRange or IsSpellInRange
    local sameOK, same = pcall(UnitIsUnit, unit, "player")
    if range and unit and sameOK and not secret(same) and same == false then
        local ok, value = pcall(range, spell, unit)
        if ok and not secret(value) and (value == false or value == 0) then return "Out of range" end
    end
    local usable = C_Spell and C_Spell.IsSpellUsable or IsUsableSpell
    local unavailable
    if usable then
        local ok, canCast, insufficientPower = pcall(usable, spell)
        if ok and not secret(canCast) and not secret(insufficientPower) then
            if insufficientPower == true then return "Not enough mana / power" end
            unavailable = canCast == false
        end
    end
    local cooldown = C_Spell and C_Spell.GetSpellCooldown
    if cooldown then
        local ok, info = pcall(cooldown, spell)
        if ok and not secret(info) and type(info) == "table"
            and number(info.startTime) and number(info.duration) then
            -- Exclude the shared global cooldown, including a slowed GCD.
            local gcdOK, gcd = pcall(cooldown, 61304)
            local global = gcdOK and not secret(gcd) and type(gcd) == "table"
                and number(gcd.startTime) and number(gcd.duration)
                and info.startTime == gcd.startTime and info.duration == gcd.duration
            local remaining = info.startTime + info.duration - GetTime()
            if info.duration > 1.5 and remaining > 0 and not global then
                return "On cooldown (" .. math.ceil(remaining) .. "s)"
            end
        end
    end
    if unavailable then return UnavailableReason() end
end

function A.NeedsHealing(unit)
    if InCombatLockdown() or not UnitHealth or not UnitHealthMax then return false end
    local ok, health = pcall(UnitHealth, unit)
    local maxOK, maximum = pcall(UnitHealthMax, unit)
    return ok and maxOK and number(health) and number(maximum)
        and maximum > 0 and health > 0 and health < maximum * 0.9
end
