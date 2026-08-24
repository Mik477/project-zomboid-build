local Definitions = require("GaelGunStoreLootDiversification/Definitions")
local Diversification = require("GaelGunStoreLootDiversification/FirearmSpawnDiversification")

local ok, entries = pcall(require, "item/loot")
if not ok or type(entries) ~= "table" then
    print("[GaelGunStoreLootDiversification] Could not load Gael's loot table; diversification was skipped.")
    return
end

local removed = 0
for index = #entries, 1, -1 do
    if Definitions.suppressedLootItems[entries[index].item] then
        table.remove(entries, index)
        removed = removed + 1
    end
end

local stats = Diversification.transformRecords(entries, Definitions.firearmSpawnPools)
_G.GGSASF_GaelLootDiversificationStats = stats
print(string.format(
    "[GaelGunStoreLootDiversification] Removed %d policy-suppressed entries and diversified %d Gael firearm records (retained %.3f weight; reassigned %.3f).",
    removed,
    stats.occurrences,
    stats.retainedWeight,
    stats.replacementWeight
))
