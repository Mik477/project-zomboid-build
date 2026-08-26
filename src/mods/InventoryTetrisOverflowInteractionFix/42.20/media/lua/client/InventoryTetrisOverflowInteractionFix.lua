local Fix = require("InventoryTetrisOverflowInteractionFix/OverflowInteraction")

Events.OnGameStart.Add(Fix.install)

return Fix
