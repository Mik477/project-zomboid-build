local repositoryRoot = InventoryDiagnosticsRepositoryRoot or "."
package.path = table.concat({
    repositoryRoot .. "/src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?.lua",
    repositoryRoot .. "/src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local clock = 1000
local output = {}
local performanceEvents = {}
local originalPrint = print
print = function(line) output[#output + 1] = tostring(line) end
getTimestampMs = function() return clock end
PZPerfDiagnostics_actionEvent = function(traceId, stage, actionType, details)
    performanceEvents[#performanceEvents + 1] = table.concat({ traceId, stage, actionType, details }, "|")
end

local tickHandlers = {}
Events = {
    OnTick = { Add = function(callback) tickHandlers[#tickHandlers + 1] = callback end },
}

instanceof = function(value, className)
    return value and value.className == className or false
end

local function tick(delta)
    clock = clock + (delta or 0)
    for _, callback in ipairs(tickHandlers) do callback() end
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
    return container
end

local function makeItem(id, fullType, container)
    local item = {
        id = id,
        fullType = fullType,
        container = container,
        className = "InventoryItem",
        equipped = false,
        containsClip = false,
        currentAmmo = 0,
    }
    function item:getID() return self.id end
    function item:getFullType() return self.fullType end
    function item:getContainer() return self.container end
    function item:isEquipped() return self.equipped end
    function item:isContainsClip() return self.containsClip end
    function item:getCurrentAmmoCount() return self.currentAmmo end
    return item
end

local mainInventory = makeContainer("inventory", true, false)
function mainInventory:getCapacityWeight() return 48 end
function mainInventory:getEffectiveCapacity() return 50 end
function mainInventory:getMaxWeight() return 50 end
local backpack = makeContainer("Bag", true, false)
local floor = makeContainer("floor", false, false)
local keyRing = makeContainer("KeyRing", true, true)
local nativeActions = { values = {} }
function nativeActions:contains(value) return self.values[value] == true end

local player = { className = "IsoPlayer", primary = nil, secondary = nil }
function player:isLocalPlayer() return true end
function player:getInventory() return mainInventory end
function player:getPlayerNum() return 0 end
function player:getPrimaryHandItem() return self.primary end
function player:getSecondaryHandItem() return self.secondary end
function player:getCharacterActions() return nativeActions end
getSpecificPlayer = function(playerNum) return playerNum == 0 and player or nil end

local ItemContainerGrid = { _unpositionedItemSetsByPlayer = {} }
package.preload["InventoryTetris/Model/ItemContainerGrid"] = function() return ItemContainerGrid end
package.preload["InventoryTetris/KeyRingSupport"] = function()
    return { isContainer = function(container) return container and container.keyRing == true end }
end

ISInventoryTransferAction = { Type = "ISInventoryTransferAction" }
function ISInventoryTransferAction:new() end
function ISInventoryTransferAction:isValid() end
function ISInventoryTransferAction:start() end
function ISInventoryTransferAction:update() end
function ISInventoryTransferAction:transferItem() end
function ISInventoryTransferAction:perform() end
function ISInventoryTransferAction:stop() end
function ISInventoryTransferAction:begin() error("observer invoked begin") end
function ISInventoryTransferAction:getJobDelta() error("observer invoked getJobDelta") end

ISEquipWeaponAction = { Type = "ISEquipWeaponAction" }
function ISEquipWeaponAction:new() end
function ISEquipWeaponAction:isValid() end
function ISEquipWeaponAction:start() end
function ISEquipWeaponAction:update() end
function ISEquipWeaponAction:complete() end
function ISEquipWeaponAction:stop() end
function ISEquipWeaponAction:begin() error("observer invoked begin") end
function ISEquipWeaponAction:getJobDelta() error("observer invoked getJobDelta") end

ISTimedActionQueue = { queues = {} }
function ISTimedActionQueue.getTimedActionQueue() error("observer created or fetched a queue") end
function ISTimedActionQueue.add() error("observer mutated a queue") end
function ISTimedActionQueue:onCompleted() end
function ISTimedActionQueue:tick() end

ISInventoryPane = {
    refreshContainer = function() end,
    onMouseDown = function() end,
    onMouseUp = function() end,
    transferItemsByWeight = function() end,
}
ISInventoryPaneContextMenu = { equipWeapon = function() end }
GridAutoDropSystem = {
    _handleDropItem = function() end,
    _attemptToForcePositionItem = function() end,
    _attemptToForceEquipItem = function() end,
}

for _, moduleName in ipairs({
    "TimedActions/ISInventoryTransferAction",
    "TimedActions/ISTimedActionQueue",
    "TimedActions/ISEquipWeaponAction",
    "TimedActions/ISWearClothing",
    "TimedActions/ISInsertMagazine",
    "TimedActions/ISEjectMagazine",
    "TimedActions/ISLoadBulletsInMagazine",
}) do
    package.preload[moduleName] = function() return true end
end

local protectedTables = {
    ISInventoryTransferAction,
    ISEquipWeaponAction,
    ISTimedActionQueue,
    ISInventoryPane,
    ISInventoryPaneContextMenu,
    GridAutoDropSystem,
}
local identities = {}
for _, protectedTable in ipairs(protectedTables) do
    identities[protectedTable] = {}
    for key, value in pairs(protectedTable) do identities[protectedTable][key] = value end
end

local Diagnostics = require("InventoryTetrisTransferDiagnostics/InventoryDiagnostics")
Diagnostics.install()

for _, protectedTable in ipairs(protectedTables) do
    for key, value in pairs(identities[protectedTable]) do
        if protectedTable[key] ~= value then error("observer replaced method: " .. tostring(key)) end
    end
end

local axe = makeItem(42, "Base.Axe", backpack)
backpack.contents[axe] = true
local transfer = {
    Type = "ISInventoryTransferAction",
    character = player,
    item = axe,
    srcContainer = backpack,
    destContainer = mainInventory,
    started = false,
    maxTime = -1,
    transactionId = 0,
    action = nil,
}
local equip = {
    Type = "ISEquipWeaponAction",
    character = player,
    item = axe,
    started = false,
    maxTime = 50,
    action = nil,
    primary = true,
    twoHands = true,
}
local queue = { character = player, queue = { transfer, equip }, current = transfer }
ISTimedActionQueue.queues[player] = queue

tick()
tick(300)
transfer.action = {}
nativeActions.values[transfer.action] = true
transfer.started = true
transfer.maxTime = 120
transfer.transactionId = 77
tick(25)
backpack.contents[axe] = nil
mainInventory.contents[axe] = true
axe.container = mainInventory
tick(25)
queue.queue = { equip }
queue.current = equip
tick(25)
equip.action = {}
nativeActions.values[equip.action] = true
equip.started = true
player.primary = axe
player.secondary = axe
tick(25)
queue.queue = {}
queue.current = nil
tick(25)

local key = makeItem(99, "Base.Key1", keyRing)
keyRing.contents[key] = true
local keyTransfer = {
    Type = "ISInventoryTransferAction",
    character = player,
    item = key,
    srcContainer = keyRing,
    destContainer = mainInventory,
    started = false,
    maxTime = -1,
    transactionId = 0,
    action = nil,
}
queue.queue = { keyTransfer }
queue.current = keyTransfer
tick(25)
keyRing.contents[key] = nil
mainInventory.contents[key] = true
key.container = mainInventory
queue.queue = {}
queue.current = nil
tick(25)

local overflow = makeItem(123, "Base.Fridge", mainInventory)
mainInventory.contents[overflow] = true
ItemContainerGrid._unpositionedItemSetsByPlayer[0] = {
    [overflow] = { sourceContainer = mainInventory, detectedAt = clock },
}
tick(25)
tick(600)
mainInventory.contents[overflow] = nil
floor.contents[overflow] = true
overflow.container = floor
ItemContainerGrid._unpositionedItemSetsByPlayer[0][overflow] = nil
tick(25)

local stuck = makeItem(124, "Base.LargeObject", mainInventory)
mainInventory.contents[stuck] = true
ItemContainerGrid._unpositionedItemSetsByPlayer[0][stuck] = {
    sourceContainer = mainInventory,
    detectedAt = clock,
}
tick(25)
tick(500)
tick(44500)

local crowdedQueue = {}
for index = 1, 65 do
    local item = makeItem(1000 + index, "Base.QueueProbe", mainInventory)
    mainInventory.contents[item] = true
    crowdedQueue[index] = {
        Type = "ISEquipWeaponAction",
        character = player,
        item = item,
        started = false,
        maxTime = 10,
        action = {},
    }
end
queue.queue = crowdedQueue
queue.current = nil
tick(25)
queue.queue = {}
tick(25)

local helmet = makeItem(130, "Base.Hat_Army", mainInventory)
mainInventory.contents[helmet] = true
local wear = {
    Type = "ISWearClothing",
    character = player,
    item = helmet,
    started = true,
    maxTime = 50,
    action = {},
}
queue.queue = { wear }
queue.current = wear
tick(25)
helmet.equipped = true
queue.queue = {}
queue.current = nil
tick(25)

local gun = makeItem(131, "Base.Pistol", mainInventory)
gun.className = "HandWeapon"
local magazine = makeItem(132, "Base.9mmClip", mainInventory)
mainInventory.contents[gun] = true
mainInventory.contents[magazine] = true
player.primary = gun
player.secondary = nil
local insert = {
    Type = "ISInsertMagazine",
    character = player,
    gun = gun,
    magazine = magazine,
    started = true,
    maxTime = -1,
    action = {},
}
queue.queue = { insert }
queue.current = insert
tick(25)
gun.containsClip = true
gun.currentAmmo = 12
mainInventory.contents[magazine] = nil
magazine.container = nil
queue.queue = {}
queue.current = nil
tick(25)

local eject = {
    Type = "ISEjectMagazine",
    character = player,
    gun = gun,
    started = true,
    maxTime = -1,
    action = {},
}
queue.queue = { eject }
queue.current = eject
tick(25)
gun.containsClip = false
gun.currentAmmo = 0
queue.queue = {}
queue.current = nil
tick(25)

magazine.container = mainInventory
mainInventory.contents[magazine] = true
magazine.currentAmmo = 28
local loadMagazine = {
    Type = "ISLoadBulletsInMagazine",
    character = player,
    magazine = magazine,
    started = true,
    maxTime = -1,
    action = {},
}
queue.queue = { loadMagazine }
queue.current = loadMagazine
tick(25)
magazine.currentAmmo = 29
queue.queue = {}
queue.current = nil
tick(25)

local setMagType = {
    Type = "SetMagTypeAction",
    character = player,
    gun = gun,
    magType = "Base.9mmClip",
    started = nil,
    maxTime = 1,
    action = {},
}
queue.queue = { setMagType }
queue.current = setMagType
tick(25)
queue.queue = {}
queue.current = nil
tick(25)

local postSwap = {
    Type = "PostSwapAction",
    character = player,
    gun = gun,
    magType = "Base.9mmClip",
    started = nil,
    maxTime = 1,
    action = {},
}
queue.queue = { postSwap }
queue.current = postSwap
tick(25)
queue.queue = {}
queue.current = nil
tick(25)

ITTransferDiag_mark("fixture checkpoint\nclean")
for index = 1, 2600 do ITTransferDiag_mark("line-cap-probe") end
print = originalPrint

local joined = table.concat(output, "\n")
local bridgeJoined = table.concat(performanceEvents, "\n")
local function assertContains(haystack, needle, label)
    if not string.find(haystack, needle, 1, true) then
        error(label .. " missing: " .. needle .. "\n" .. haystack)
    end
end

assertContains(joined, "event=action-first-observed", "first observation")
assertContains(joined, "event=missing-native-action-stall", "begin failure milestone")
assertContains(joined, "milestoneMs=250", "bounded missing-native progression")
assertContains(joined, "event=native-action-changed", "native action transition")
assertContains(joined, "event=transaction-changed", "transaction transition")
assertContains(joined, "event=container-membership-changed", "transfer progression")
assertContains(joined, "outcome=destination-present", "transfer final state")
assertContains(joined, "outcome=equipped-both", "equip completion inference")
assertContains(joined, "action=ISWearClothing", "wear action observation")
assertContains(joined, "outcome=state-worn", "wear final state")
assertContains(joined, "action=ISInsertMagazine", "insert action observation")
assertContains(joined, "outcome=state-contains-clip", "insert final state")
assertContains(joined, "action=ISEjectMagazine", "eject action observation")
assertContains(joined, "outcome=state-no-clip", "eject final state")
assertContains(joined, "action=ISLoadBulletsInMagazine", "load-magazine action observation")
assertContains(joined, "outcome=state-magazine-ammo", "load-magazine final state")
assertContains(joined, "action=SetMagTypeAction", "Gael set-magazine action observation")
assertContains(joined, "action=PostSwapAction", "Gael post-swap action observation")
assertContains(joined, "everStarted=true", "terminal start evidence")
assertContains(joined, "inventoryWeight=48", "inventory weight evidence")
assertContains(joined, "inventoryEffectiveCapacity=50", "inventory capacity evidence")
assertContains(joined, "sourceKeyRing=true", "key-ring source detection")
assertContains(joined, "event=recovery-candidate", "recovery candidate")
assertContains(joined, "event=recovery-remains", "recovery remains")
assertContains(joined, "event=recovery-resolved", "recovery resolution")
assertContains(joined, "outcome=moved", "recovery move inference")
assertContains(joined, "event=recovery-timeout", "recovery timeout")
assertContains(joined, "event=trace-cap-reached", "live trace cap")
assertContains(joined, "queueTypesOmitted=53", "bounded queue types")
assertContains(joined, "label=fixture_checkpoint_clean", "sanitized explicit marker")
assertContains(bridgeJoined, "action-first-observed|ISInventoryTransferAction", "performance bridge")
if #output ~= 2500 then error("line cap expected 2500 entries, got " .. tostring(#output)) end
if #performanceEvents ~= 2500 then error("bridge must share the line cap") end

originalPrint("Inventory diagnostics observer runtime fixture passed.")
