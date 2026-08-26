local Module = {}

Module.FIREARM_MARKER = "GGS_LootState_0_2_Firearm"
Module.MAGAZINE_MARKER = "GGS_LootState_0_2_Magazine"

local ranges = {
    secure = {
        condition = { 70, 100 },
        magazine = { 50, 100 },
    },
    world = {
        condition = { 45, 90 },
        magazine = { 25, 90 },
    },
    zombie = {
        condition = { 20, 60 },
        magazine = { 10, 60 },
    },
}

local secureTokens = {
    "armory",
    "armoury",
    "gun",
    "locker",
    "military",
    "police",
    "security",
    "weapon",
}

local function normalizeRoll(roll)
    roll = math.floor(tonumber(roll) or 0) % 10000
    if roll < 0 then
        roll = roll + 10000
    end
    return roll
end

local function percentageInRange(range, roll)
    return range[1] + math.floor((range[2] - range[1] + 1) * normalizeRoll(roll) / 10000)
end

local function amountFor(maximum, range, roll)
    maximum = math.max(0, math.floor(tonumber(maximum) or 0))
    if maximum == 0 then
        return 0
    end
    local percentage = percentageInRange(range, roll)
    return math.max(1, math.min(maximum, math.ceil(maximum * percentage / 100)))
end

function Module.contextForContainer(roomName, containerType)
    local description = (tostring(roomName or "") .. " " .. tostring(containerType or "")):lower()
    for _, token in ipairs(secureTokens) do
        if description:find(token, 1, true) then
            return "secure"
        end
    end
    return "world"
end

function Module.conditionFor(context, conditionMax, roll)
    local policy = ranges[context] or ranges.world
    return amountFor(conditionMax, policy.condition, roll)
end

function Module.magazineAmmoFor(context, maxAmmo, roll)
    local policy = ranges[context] or ranges.world
    return amountFor(maxAmmo, policy.magazine, roll)
end

return Module
