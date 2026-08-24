package.path = table.concat({
    "src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?.lua",
    "src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local Core = require("InventoryTetrisTransferDiagnostics/InventoryDiagnosticsCore")

local function assertEqual(expected, actual, label)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

assertEqual("weapon-equip-transfer", Core.classifyMove({
    pendingEquip = true,
    sourceOnPlayer = true,
    destinationOnPlayer = true,
}), "an equip precursor must retain the weapon intent")

assertEqual("keyring-extract", Core.classifyMove({
    sourceKeyRing = true,
    destinationOnPlayer = true,
}), "moving a key out of a ring must be identifiable")

assertEqual("keyring-insert", Core.classifyMove({
    sourceOnPlayer = true,
    destinationKeyRing = true,
}), "moving a key into a ring must be identifiable")

assertEqual("player-inventory-move", Core.classifyMove({
    sourceOnPlayer = true,
    destinationOnPlayer = true,
}), "ordinary nested inventory moves must be logged")

assertEqual(nil, Core.classifyMove({}), "unrelated world-container moves must stay quiet")

assertEqual("source-no-longer-contains-item", Core.validationReason({
    sourceContains = false,
}), "stale key rows must produce a useful rejection reason")

assertEqual("destination-rejected-item", Core.validationReason({
    sourceContains = true,
    destinationAllows = false,
}), "key-ring acceptance failures must be distinguishable")

assertEqual("tetris-no-fit", Core.validationReason({
    sourceContains = true,
    destinationAllows = false,
    tetrisFits = false,
}), "spatial placement failures must take precedence over replaced vanilla rules")

assertEqual("ISInventoryTransferAction>ISUnequipAction", Core.summarizeBlockers({
    "ISInventoryTransferAction",
    "ISUnequipAction",
}), "queue blockers must retain their execution order")

local line = Core.format("ITTransferDiag", "I42", "transfer-start", {
    waitMs = 125,
    reason = "weapon equip\nfrom backpack",
    item = "Base.Axe",
})
assertEqual(
    "[ITTransferDiag] trace=I42 event=transfer-start item=Base.Axe reason=weapon_equip_from_backpack waitMs=125",
    line,
    "trace output must be stable, single-line, and grep-friendly"
)

print("Inventory diagnostics core passed.")
