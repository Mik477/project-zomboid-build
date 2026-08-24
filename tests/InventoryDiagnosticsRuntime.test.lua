package.path = table.concat({
    "src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?.lua",
    "src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local clock = 1000
local output = {}
local originalPrint = print
print = function(line) output[#output + 1] = tostring(line) end

getTimestampMs = function()
    clock = clock + 25
    return clock
end
isClient = function() return true end
isItemTransactionRejected = function() return false end
isItemTransactionDone = function() return false end
SandboxVars = { InventoryTetris = { UseItemTransferTime = true } }

instanceof = function(value, className)
    return value and value.className == className or false
end

local function makeContainer(containerType, onPlayer, keyRing)
    local container = {
        containerType = containerType,
        onPlayer = onPlayer,
        keyRing = keyRing,
        contents = {},
        className = "ItemContainer",
    }
    function container:getType() return self.containerType end
    function container:isInCharacterInventory() return self.onPlayer end
    function container:getContainingItem() return nil end
    function container:contains(item) return self.contents[item] == true end
    function container:isItemAllowed() return true end
    function container:isRemoveItemAllowed() return true end
    function container:hasRoomFor() return true end
    return container
end

local function makeItem(id, fullType, container)
    local item = { id = id, fullType = fullType, container = container, className = "InventoryItem" }
    function item:getID() return self.id end
    function item:getFullType() return self.fullType end
    function item:getContainer() return self.container end
    function item:getIsCraftingConsumed() return false end
    return item
end

local mainInventory = makeContainer("inventory", true, false)
local backpack = makeContainer("Bag", true, false)
local player = { className = "IsoPlayer", primary = nil, secondary = nil }
function player:isLocalPlayer() return true end
function player:getInventory() return mainInventory end
function player:getPlayerNum() return 0 end
function player:getPrimaryHandItem() return self.primary end
function player:getSecondaryHandItem() return self.secondary end
getSpecificPlayer = function() return player end

package.preload["InventoryTetris/KeyRingSupport"] = function()
    return { isContainer = function(container) return container and container.keyRing == true end }
end
package.preload["InventoryTetris/Model/ItemContainerGrid"] = function()
    return { FindInstance = function() return nil end }
end
local autoDrop = {
    _handleDropItem = function() return true end,
    _attemptToForcePositionItem = function() return true end,
    _attemptToForceEquipItem = function() return true end,
}
package.preload["InventoryTetris/System/GridAutoDropSystem"] = function() return autoDrop end
for _, moduleName in ipairs({
    "TimedActions/ISInventoryTransferAction",
    "TimedActions/ISTimedActionQueue",
    "TimedActions/ISEquipWeaponAction",
    "ISUI/ISInventoryPane",
    "ISUI/ISInventoryPaneContextMenu",
}) do
    package.preload[moduleName] = function() return true end
end

ISInventoryTransferAction = { Type = "ISInventoryTransferAction" }
function ISInventoryTransferAction:new(character, item, source, destination)
    local action = {
        Type = "ISInventoryTransferAction",
        character = character,
        item = item,
        srcContainer = source,
        destContainer = destination,
        maxTime = -1,
        queueList = {},
        transactionId = 0,
        action = { getWaitForFinished = function() return true end },
    }
    setmetatable(action, { __index = self })
    return action
end
function ISInventoryTransferAction:validateTetrisRules() return true end
function ISInventoryTransferAction:isValid() return self.srcContainer:contains(self.item) end
function ISInventoryTransferAction:start() self.transactionId = 77 end
function ISInventoryTransferAction:update() end
function ISInventoryTransferAction:transferItem(item)
    self.srcContainer.contents[item] = nil
    self.destContainer.contents[item] = true
    item.container = self.destContainer
end
function ISInventoryTransferAction:perform() end
function ISInventoryTransferAction:stop() end

ISTimedActionQueue = { queues = {} }
function ISTimedActionQueue.getTimedActionQueue(character)
    local queue = ISTimedActionQueue.queues[character]
    if queue then return queue end
    queue = { queue = {} }
    function queue:indexOf(action)
        for index, candidate in ipairs(self.queue) do
            if candidate == action then return index end
        end
        return -1
    end
    ISTimedActionQueue.queues[character] = queue
    return queue
end
function ISTimedActionQueue.add(action)
    local queue = ISTimedActionQueue.getTimedActionQueue(action.character)
    queue.queue[#queue.queue + 1] = action
    return queue
end

ISEquipWeaponAction = { Type = "ISEquipWeaponAction" }
function ISEquipWeaponAction:new(character, item, maxTime, primary, twoHands)
    local action = {
        Type = "ISEquipWeaponAction",
        character = character,
        item = item,
        maxTime = maxTime,
        primary = primary,
        twoHands = twoHands,
        fromHotbar = false,
    }
    setmetatable(action, { __index = self })
    return action
end
function ISEquipWeaponAction:getDuration() return self.maxTime end
function ISEquipWeaponAction:isAlreadyEquipped() return false end
function ISEquipWeaponAction:start() end
function ISEquipWeaponAction:complete()
    self.character.primary = self.item
    return true
end
function ISEquipWeaponAction:stop() end

ISInventoryPane = {
    refreshContainer = function() end,
    onMouseDown = function() end,
    onMouseUp = function() end,
    transferItemsByWeight = function() end,
    getActualItems = function(items) return items or {} end,
}

ISInventoryPaneContextMenu = {}
function ISInventoryPaneContextMenu.equipWeapon(weapon, primary, twoHands)
    local transfer = ISInventoryTransferAction:new(player, weapon, weapon:getContainer(), mainInventory)
    ISTimedActionQueue.add(transfer)
    local equip = ISEquipWeaponAction:new(player, weapon, 50, primary, twoHands)
    ISTimedActionQueue.add(equip)
end

local Diagnostics = require("InventoryTetrisTransferDiagnostics/InventoryDiagnostics")
Diagnostics.install()

local axe = makeItem("42", "Base.Axe", backpack)
backpack.contents[axe] = true
ISInventoryPaneContextMenu.equipWeapon(axe, true, true, 0)

local transfer = ISTimedActionQueue.queues[player].queue[1]
local equip = ISTimedActionQueue.queues[player].queue[2]
transfer:start()
clock = clock + 100
transfer:transferItem(axe)
transfer:perform()
equip:start()
clock = clock + 50
equip:complete()

local keyRing = makeContainer("KeyRing", false, true)
local key = makeItem("99", "Base.Key1", keyRing)
keyRing.contents[key] = true
local keyTransfer = ISInventoryTransferAction:new(player, key, keyRing, mainInventory)
keyRing.contents[key] = nil
keyTransfer:isValid()

print = originalPrint

local joined = table.concat(output, "\n")
local function assertContains(needle, label)
    if not string.find(joined, needle, 1, true) then
        error(label .. " missing: " .. needle .. "\n" .. joined)
    end
end

assertContains("event=equip-intent", "weapon trace")
assertContains("event=transfer-created", "transfer trace")
assertContains("reason=weapon-equip-transfer", "weapon transfer correlation")
assertContains("event=equip-complete", "equip completion timing")
assertContains("reason=keyring-extract", "key-ring classification")
assertContains("failure=source-no-longer-contains-item", "stale key rejection reason")

originalPrint("Inventory diagnostics runtime hooks passed.")
