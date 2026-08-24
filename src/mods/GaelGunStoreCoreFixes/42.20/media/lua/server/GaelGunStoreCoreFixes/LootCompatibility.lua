if _G.GGSASF_LootCompatibilityApplied then return end
_G.GGSASF_LootCompatibilityApplied = true

local Definitions = require("GaelGunStoreCoreFixes/Definitions")

local function applyLootCompatibility(entries)
    if type(entries) ~= "table" then
        return 0, 0
    end

    local obsolete = Definitions.toSet(Definitions.obsoleteLootItems)
    local cloneTargets = {}
    for _, clone in ipairs(Definitions.lootClones) do
        cloneTargets[clone.source] = clone.item
    end

    local existing = {}
    for _, entry in ipairs(entries) do
        if entry.list and entry.item then
            existing[entry.list .. "\0" .. entry.item] = true
        end
    end

    local additions = {}
    for _, entry in ipairs(entries) do
        local target = cloneTargets[entry.item]
        local key = target and entry.list and (entry.list .. "\0" .. target) or nil
        if key and not existing[key] then
            additions[#additions + 1] = {
                list = entry.list,
                item = target,
                weight = entry.weight,
                sv = entry.sv,
            }
            existing[key] = true
        end
    end

    local removed = 0
    for index = #entries, 1, -1 do
        if obsolete[entries[index].item] then
            table.remove(entries, index)
            removed = removed + 1
        end
    end
    for _, entry in ipairs(additions) do
        entries[#entries + 1] = entry
    end

    return #additions, removed
end

_G.GGSASF_ApplyLootCompatibility = applyLootCompatibility

local ok, entries = pcall(require, "item/loot")
if not ok or type(entries) ~= "table" then
    print("[GaelGunStoreCoreFixes] Could not load Gael's loot table; magazine loot compatibility was skipped.")
    return
end

local added, removed = applyLootCompatibility(entries)
print(string.format(
    "[GaelGunStoreCoreFixes] Loot compatibility added %d restored-device entries and removed %d obsolete feed-device entries.",
    added,
    removed
))
