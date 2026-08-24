package.path = table.concat({
    "src/mods/CompactProximityInventory/42.20/media/lua/client/?.lua",
    "src/mods/CompactProximityInventory/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local sourceList

package.preload["ISUI/ISInventoryPaneContextMenu"] = function() return true end

function getTexture(path) return path end
function getTextOrNull() return nil end
function getSpecificPlayer() return {} end
function instanceof() return false end

ArrayList = {}
function ArrayList.new()
    local list = { values = {} }
    function list:add(value) table.insert(self.values, value) end
    function list:get(index) return self.values[index + 1] end
    function list:size() return #self.values end
    return list
end

ItemContainer = {}
function ItemContainer.new(kind, parent)
    local items = { addAll = function() end }
    local container = { kind = kind, parent = parent }
    function container:getType() return self.kind end
    function container:setExplored() end
    function container:setOnlyAcceptCategory() end
    function container:setCapacity() end
    function container:clear() end
    function container:getItems() return items end
    return container
end

ISInventoryPaneContextMenu = {
    getContainers = function() return sourceList end,
}
Events = {
    OnRefreshInventoryWindowContainers = { Add = function() end },
}

local NearbyContainers = require("CompactProximityInventory/NearbyContainers")
local first = ItemContainer.new("crate", {})
local marker = NearbyContainers.getMarker(0)
local second = ItemContainer.new("counter", {})
sourceList = ArrayList.new()
sourceList:add(first)
sourceList:add(marker)
sourceList:add(second)

local filtered = ISInventoryPaneContextMenu.getContainers({})
assert(filtered:size() == 2, "craft list must exclude exactly one marker")
assert(filtered:get(0) == first, "first real container must retain identity and order")
assert(filtered:get(1) == second, "second real container must retain identity and order")
assert(sourceList:size() == 3, "filter must not mutate the compact loot source list")
assert(sourceList:get(1) == marker, "compact marker must remain in its loot source list")
assert(NearbyContainers.getMarker(0) == marker, "compact marker identity must remain stable")

print("Compact crafting-container filter passed; Nearby (Compact) remains intact.")
