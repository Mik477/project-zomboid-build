package.path = table.concat({
    "src/mods/CompactProximityInventory/42.20/media/lua/client/?.lua",
    "src/mods/CompactProximityInventory/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local SelectionPolicy = require("CompactProximityInventory/SelectionPolicy")
local SelectionGuard = require("CompactProximityInventory/SelectionGuard")

local function assertEqual(expected, actual, label)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

assertEqual(true, SelectionPolicy.shouldKeepCompact(true, false),
    "automatic source-container selection must keep compact mode")
assertEqual(false, SelectionPolicy.shouldKeepCompact(true, true),
    "explicit container click may leave compact mode")
assertEqual(false, SelectionPolicy.shouldKeepCompact(false, false),
    "ordinary container selection stays ordinary")

local marker = { kind = "marker" }
local source = { kind = "source" }
local calls = { force = 0, automatic = 0, explicit = 0, refresh = 0, restore = 0 }
local InventoryPage = {}

function InventoryPage:setForceSelectedContainer(container, ms)
    calls.force = calls.force + 1
    self.forceSelectedContainer = container
    self.forceSelectedContainerTime = ms
end

function InventoryPage:selectButtonForContainer(container)
    calls.automatic = calls.automatic + 1
    self.inventoryPane.inventory = container
end

function InventoryPage:selectContainer(button)
    calls.explicit = calls.explicit + 1
    self.inventoryPane.inventory = button.inventory
end

function InventoryPage:onBackpackClick(button)
    self:selectContainer(button)
end

function InventoryPage:refreshBackpacks()
    calls.refresh = calls.refresh + 1
    self.inventoryPane.inventory = source
end

function InventoryPage:setNewContainer(container)
    calls.restore = calls.restore + 1
    self.inventoryPane.inventory = container
    self.inventory = container
end

SelectionGuard.install(InventoryPage, function(container) return container == marker end)

local page = setmetatable({
    inventoryPane = { inventory = marker },
    forceSelectedContainer = source,
    forceSelectedContainerTime = 999,
    backpacks = {
        { inventory = marker, name = "Nearby (Compact)", capacity = 0 },
        { inventory = source, name = "Cupboard", capacity = 20 },
    },
}, { __index = InventoryPage })

-- This is the sequence used by ISInventoryTransferAction while moving an item.
page:setForceSelectedContainer(source, 1000)
page:selectButtonForContainer(source)
assertEqual(marker, page.inventoryPane.inventory,
    "transfer sequence must not replace compact marker")
assertEqual(nil, page.forceSelectedContainer,
    "transfer force-selection must be cleared in compact mode")
assertEqual(0, calls.force, "guard must suppress force-selection delegate")
assertEqual(0, calls.automatic, "guard must suppress automatic button selection")

page:selectContainer({ inventory = source })
assertEqual(marker, page.inventoryPane.inventory,
    "non-user direct selection must not leave compact mode")

page:onBackpackClick({ inventory = source })
assertEqual(source, page.inventoryPane.inventory,
    "explicit container selection must leave compact mode")
assertEqual(1, calls.explicit, "explicit selection must reach original handler")

page:setForceSelectedContainer(marker, 1000)
page:onBackpackClick({ inventory = marker })
assertEqual(nil, page.forceSelectedContainer,
    "explicit compact selection must clear stale forced container")

-- Reproduce the fallback path: vanilla refresh assigns the source container
-- directly without calling any selection method.
page:refreshBackpacks()
assertEqual(marker, page.inventoryPane.inventory,
    "refresh fallback must restore compact marker")
assertEqual(1, calls.restore, "refresh fallback must rebuild compact view once")

print("Compact proximity selection policy passed.")
