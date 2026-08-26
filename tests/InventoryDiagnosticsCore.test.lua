local repositoryRoot = InventoryDiagnosticsRepositoryRoot or "."
package.path = table.concat({
    repositoryRoot .. "/src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?.lua",
    repositoryRoot .. "/src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local Core = require("InventoryTetrisTransferDiagnostics/InventoryDiagnosticsCore")

local function assertEqual(expected, actual, label)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

assertEqual(true, Core.isObservedActionType("ISInventoryTransferAction"), "transfer type")
assertEqual(true, Core.isObservedActionType("ISEquipWeaponAction"), "equip type")
assertEqual(true, Core.isObservedActionType("ISWearClothing"), "wear type")
assertEqual(true, Core.isObservedActionType("ISInsertMagazine"), "insert type")
assertEqual(true, Core.isObservedActionType("ISEjectMagazine"), "eject type")
assertEqual(true, Core.isObservedActionType("ISLoadBulletsInMagazine"), "load-magazine type")
assertEqual(true, Core.isObservedActionType("SetMagTypeAction"), "Gael set-magazine type")
assertEqual(true, Core.isObservedActionType("PostSwapAction"), "Gael post-swap type")
assertEqual(false, Core.isObservedActionType("ISWalkToTimedAction"), "unrelated action type")

local queueTypes, omitted = Core.summarizeQueueTypes({
    "A", "B", "C", "D",
}, 3)
assertEqual("A>B>C", queueTypes, "queue types must preserve order")
assertEqual(1, omitted, "queue types must report bounded omissions")

assertEqual("active", Core.transactionState(77), "active transaction")
assertEqual("none", Core.transactionState(0), "cleared transaction")
assertEqual("absent", Core.transactionState(nil), "missing transaction field")
assertEqual("destination-present", Core.transferOutcome(false, true, "none"), "completed transfer state")
assertEqual("source-present-transaction-active", Core.transferOutcome(true, false, "active"), "pending transfer state")
assertEqual("equipped-both", Core.equipOutcome(true, true, true), "two-hand equip")
assertEqual("removed-not-equipped", Core.equipOutcome(false, false, true), "unequipped removal")
assertEqual("state-worn", Core.wearOutcome(true, true), "wear final state")
assertEqual("state-not-worn-contained", Core.wearOutcome(false, true), "wear cancellation state")
assertEqual("state-contains-clip", Core.magazineOutcome("ISInsertMagazine", true, true), "insert final state")
assertEqual("state-no-clip", Core.magazineOutcome("ISInsertMagazine", false, true), "insert cancellation state")
assertEqual("state-no-clip", Core.magazineOutcome("ISEjectMagazine", false, true), "eject final state")
assertEqual("state-contains-clip", Core.magazineOutcome("ISEjectMagazine", true, true), "eject cancellation state")
assertEqual("state-magazine-ammo", Core.magazineOutcome("ISLoadBulletsInMagazine", nil, false), "load-magazine final state")

assertEqual("candidate", Core.recoveryPhase(499), "recovery grace")
assertEqual("remains", Core.recoveryPhase(500), "recovery remains")
assertEqual("timeout", Core.recoveryPhase(45000), "recovery timeout")

local line = Core.format("ITTransferDiag", "I42", "action-first-observed", {
    queueDepth = 2,
    item = "Base.Axe",
    note = "single\nline",
    unsafe = {},
})
assertEqual(
    "[ITTransferDiag] trace=I42 event=action-first-observed item=Base.Axe note=single_line queueDepth=2 unsafe=unsupported",
    line,
    "trace output must be stable, sanitized, and free of table addresses"
)

local details = Core.details({ z = "last", a = "first" })
assertEqual("a=first,z=last", details, "bridge details must be deterministic")

print("Inventory diagnostics core passed.")
