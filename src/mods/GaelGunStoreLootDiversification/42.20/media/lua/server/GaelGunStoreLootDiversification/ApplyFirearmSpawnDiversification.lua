if _G.GGSASF_FirearmSpawnDiversificationApplied then return end
_G.GGSASF_FirearmSpawnDiversificationApplied = true

local Definitions = require("GaelGunStoreLootDiversification/Definitions")
local Diversification = require("GaelGunStoreLootDiversification/FirearmSpawnDiversification")

pcall(require, "Items/ProceduralDistributions")
pcall(require, "Items/Distributions")
pcall(require, "Items/Distribution_BagsAndContainers")
pcall(require, "Vehicles/VehicleDistributions")

local function ensureWeightedItem(items, itemType, weight)
    if type(items) ~= "table" then
        return false
    end
    for index = 1, #items - 1, 2 do
        if items[index] == itemType and tonumber(items[index + 1]) == weight then
            return false
        end
    end
    items[#items + 1] = itemType
    items[#items + 1] = weight
    return true
end

local rifleCaseUpdated = false
if BagsAndContainers and BagsAndContainers.RifleCase1 then
    local items = BagsAndContainers.RifleCase1.items
    rifleCaseUpdated = ensureWeightedItem(items, "556Clip", 200) or rifleCaseUpdated
    rifleCaseUpdated = ensureWeightedItem(items, "556Clip", 10) or rifleCaseUpdated
end

local roots = {}
local function addRoot(root)
    if type(root) == "table" then
        roots[#roots + 1] = root
    end
end
addRoot(ProceduralDistributions and ProceduralDistributions.list)
addRoot(SuburbsDistributions)
addRoot(Distributions)
addRoot(VehicleDistributions)
addRoot(BagsAndContainers)

local stats = Diversification.transformRoots(roots, Definitions.firearmSpawnPools)
_G.GGSASF_FirearmSpawnDiversificationStats = stats

print(string.format(
    "[GaelGunStoreLootDiversification] Diversified %d firearm entries across %d world/vehicle/bag arrays (retained %.3f weight; reassigned %.3f; RifleCase1 magazine support: %s).",
    stats.occurrences,
    stats.arrays,
    stats.retainedWeight,
    stats.replacementWeight,
    tostring(rifleCaseUpdated)
))

local reparsed = false
local function reparseDistributions()
    if reparsed then
        return
    end
    reparsed = true
    if ItemPickerJava and ItemPickerJava.Parse then
        ItemPickerJava.Parse()
    end
end

if Events and Events.OnInitWorld and Events.OnInitWorld.Add then
    Events.OnInitWorld.Add(reparseDistributions)
end
if Events and Events.OnLoadMapZones and Events.OnLoadMapZones.Add then
    Events.OnLoadMapZones.Add(reparseDistributions)
end
if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(reparseDistributions)
end
