if _G.GGSASF_MagazineCompatibilityRegistered then return end
_G.GGSASF_MagazineCompatibilityRegistered = true

local Definitions = require("GaelGunStoreCoreFixes/Definitions")
local summaryPrinted = false

local function mergeUnique(target, values)
    local seen = {}
    for _, value in ipairs(target) do
        seen[value] = true
    end
    local added = 0
    for _, value in ipairs(values or {}) do
        if not seen[value] then
            target[#target + 1] = value
            seen[value] = true
            added = added + 1
        end
    end
    return added
end

local function applyMagazineCompatibility()
    local weaponMap = _G.AWCWF_WeaponMagazineType
    local partMap = _G.AWCWF_MagazineTypeToPart
    if type(weaponMap) ~= "table" or type(partMap) ~= "table" then
        return false
    end

    local changed = 0
    for _, alias in ipairs(Definitions.magazineMapAliases) do
        local source = weaponMap[alias.from]
        if type(source) == "table" then
            weaponMap[alias.to] = weaponMap[alias.to] or {}
            changed = changed + mergeUnique(weaponMap[alias.to], source)
        end
        if weaponMap[alias.from] ~= nil then
            weaponMap[alias.from] = nil
            changed = changed + 1
        end
    end

    for _, key in ipairs(Definitions.magazineMapRemovals) do
        if weaponMap[key] ~= nil then
            weaponMap[key] = nil
            changed = changed + 1
        end
    end

    for weaponType, magazines in pairs(Definitions.magazineMapUnions) do
        weaponMap[weaponType] = weaponMap[weaponType] or {}
        changed = changed + mergeUnique(weaponMap[weaponType], magazines)
    end

    for _, expansion in ipairs(Definitions.magazineFamilyExpansions or {}) do
        for _, magazines in pairs(weaponMap) do
            local matches = false
            for _, marker in ipairs(expansion.markers or {}) do
                for _, magazineType in ipairs(magazines) do
                    if magazineType == marker then
                        matches = true
                        break
                    end
                end
                if matches then break end
            end
            if matches then
                changed = changed + mergeUnique(magazines, expansion.magazines)
            end
        end
    end

    for magazineType, partType in pairs(Definitions.magazinePartPatches) do
        if partMap[magazineType] ~= partType then
            partMap[magazineType] = partType
            changed = changed + 1
        end
    end

    if _G.GGS_MagMapping then
        _G.GGS_MagMapping._reverseMap = nil
        _G.GGS_MagMapping._reverseSize = nil
    end

    if not summaryPrinted then
        summaryPrinted = true
        print(string.format(
            "[GaelGunStoreCoreFixes] Magazine compatibility map ready (%d corrections applied).",
            changed
        ))
    end
    return true
end

_G.GGSASF_ApplyMagazineCompatibility = applyMagazineCompatibility
applyMagazineCompatibility()

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(applyMagazineCompatibility)
end
