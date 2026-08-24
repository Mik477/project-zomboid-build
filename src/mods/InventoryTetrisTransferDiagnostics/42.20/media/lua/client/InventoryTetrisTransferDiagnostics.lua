local Diagnostics = require("InventoryTetrisTransferDiagnostics/InventoryDiagnostics")

Events.OnGameBoot.Add(function()
    Diagnostics.install()
end)
