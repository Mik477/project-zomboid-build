require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISWearClothing"
require "TimedActions/ISInsertMagazine"
require "TimedActions/ISEjectMagazine"
require "TimedActions/ISTransferAction"

local Policy = require("InventoryActionIntentFix/IntentPolicy")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local GridAutoDropSystem = require("InventoryTetris/System/GridAutoDropSystem")

if _G.InventoryActionIntentFix then
    return _G.InventoryActionIntentFix
end

local Module = { suppressed = 0, displacedDrops = 0 }
local installedWrappers = {}
local activationReported = false

local function recordSuppression(kind, playerObj)
    Module.suppressed = Module.suppressed + 1
    if Module.suppressed <= 20 then
        local playerNum = playerObj and playerObj.getPlayerNum and playerObj:getPlayerNum() or -1
        print("[InventoryActionIntentFix] Suppressed duplicate " .. tostring(kind)
            .. " intent for player " .. tostring(playerNum) .. ".")
    end
end

local function alreadyEquipped(playerObj, item, primary, twoHands)
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    if twoHands then return primaryItem == item and secondaryItem == item end
    if primary then return primaryItem == item and secondaryItem ~= item end
    return secondaryItem == item and primaryItem ~= item
end

local function displacedHandItems(playerObj, item, primary, twoHands)
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    local effectiveTwoHands = twoHands == true
    if alreadyEquipped(playerObj, item, primary, effectiveTwoHands) then return {} end

    local displaced = {}
    local seen = {}
    local function add(candidate)
        if candidate and candidate ~= item and not seen[candidate] then
            seen[candidate] = true
            displaced[#displaced + 1] = candidate
        end
    end

    if effectiveTwoHands then
        add(primaryItem)
        add(secondaryItem)
    elseif primary then
        add(primaryItem)
        if secondaryItem and (secondaryItem:isRequiresEquippedBothHands()
                or secondaryItem == primaryItem
                or (instanceof(item, "HandWeapon") and instanceof(secondaryItem, "HandWeapon")
                    and item:getSwingAnim() == "Handgun")) then
            add(secondaryItem)
        end
    else
        add(secondaryItem)
        if primaryItem and (primaryItem:isRequiresEquippedBothHands()
                or primaryItem == secondaryItem
                or (instanceof(item, "HandWeapon") and instanceof(primaryItem, "HandWeapon")
                    and primaryItem:getSwingAnim() == "Handgun")) then
            add(primaryItem)
        end
    end
    return displaced
end

local function isWorn(playerObj, item)
    local wornItems = playerObj:getWornItems()
    for index = 0, wornItems:size() - 1 do
        if wornItems:get(index):getItem() == item then return true end
    end
    return false
end

local function playerContainers(playerObj)
    local containers = { playerObj:getInventory() }
    local seen = { [containers[1]] = true }
    local wornItems = playerObj:getWornItems()
    for index = 0, wornItems:size() - 1 do
        local wornItem = wornItems:get(index):getItem()
        if wornItem and wornItem:IsInventoryContainer() then
            local container = wornItem:getInventory()
            if container and not seen[container] then
                seen[container] = true
                containers[#containers + 1] = container
            end
        end
    end
    return containers
end

local function canStoreOnPlayer(playerObj, item, playerNum)
    local ok, containers = pcall(playerContainers, playerObj)
    if not ok then return true end
    for _, container in ipairs(containers) do
        local gridOk, grid = pcall(ItemContainerGrid.GetOrCreate, container, playerNum)
        if not gridOk or not grid then return true end
        local stackOk, stack = pcall(grid.findStackByItem, grid, item)
        if not stackOk then return true end
        if stack then return true end
        local fitOk, fits = pcall(grid.canAddItem, grid, item)
        if not fitOk then return true end
        if fits == true then return true end
    end
    return false
end

local function hasPendingFloorTransfer(playerObj, item, floorContainer)
    local queue = ISTimedActionQueue.queues and ISTimedActionQueue.queues[playerObj] or nil
    for _, action in ipairs(queue and queue.queue or {}) do
        if action.Type == "ISInventoryTransferAction"
                and action.item == item
                and action.destContainer == floorContainer then
            return true
        end
    end
    return false
end

local function canDropNow(playerObj, item, playerNum)
    if playerObj:getVehicle() then return false end
    local source = item:getContainer()
    if not source then return false end
    local inventory = playerObj:getInventory()
    if source ~= inventory and not source:isInCharacterInventory(playerObj) then return false end
    if item:isForceDropHeavyItem() or isWorn(playerObj, item) then return false end
    local hotbar = getPlayerHotbar(playerNum)
    if hotbar and hotbar:isInHotbar(item) then return false end
    if GridAutoDropSystem._isItemUndroppable(item) then return false end
    if canStoreOnPlayer(playerObj, item, playerNum) then return false end

    local floorContainer = ISInventoryPage.GetFloorContainer(playerNum)
    if not floorContainer then return false end
    if hasPendingFloorTransfer(playerObj, item, floorContainer) then return false end
    return ISTransferAction:getNotFullFloorSquare(playerObj, item, floorContainer) ~= nil
end

local function queueDisplacedDrops(item, primary, twoHands, playerNum)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not item then return end
    for _, displacedItem in ipairs(displacedHandItems(playerObj, item, primary, twoHands)) do
        local ok, shouldDrop = pcall(canDropNow, playerObj, displacedItem, playerNum)
        if ok and shouldDrop and GridAutoDropSystem._handleDropItem(displacedItem, playerNum) then
            Module.displacedDrops = Module.displacedDrops + 1
            if Module.displacedDrops <= 20 then
                print("[InventoryActionIntentFix] Queued displaced hand item for floor fallback: "
                    .. tostring(displacedItem:getFullType()) .. ".")
            end
        end
    end
end

function Module.isPending(kind, playerObj, primaryItem, secondaryItem)
    if not (kind and playerObj and primaryItem) then return false end
    local ok, pending = pcall(function()
        local queue = ISTimedActionQueue.queues and ISTimedActionQueue.queues[playerObj] or nil
        return Policy.hasPending(queue and queue.queue or nil, kind, primaryItem, secondaryItem)
    end)
    return ok and pending == true
end

local function installWearWrapper()
    if installedWrappers.wearItem then return end
    local current = ISInventoryPaneContextMenu.wearItem
    if type(current) ~= "function" then return end
    local delegate = current
    local wrapper = function(item, playerNum, ...)
        local playerObj = getSpecificPlayer(playerNum)
        if Module.isPending("wear", playerObj, item) then
            recordSuppression("wear", playerObj)
            return nil
        end
        return delegate(item, playerNum, ...)
    end
    installedWrappers.wearItem = wrapper
    ISInventoryPaneContextMenu.wearItem = wrapper
end

local function installInsertWrapper()
    if installedWrappers.onInsertMagazine then return end
    local current = ISInventoryPaneContextMenu.onInsertMagazine
    if type(current) ~= "function" then return end
    local delegate = current
    local wrapper = function(playerObj, weapon, magazine, ...)
        if Module.isPending("insert-magazine", playerObj, weapon, magazine) then
            recordSuppression("insert-magazine", playerObj)
            return nil
        end
        return delegate(playerObj, weapon, magazine, ...)
    end
    installedWrappers.onInsertMagazine = wrapper
    ISInventoryPaneContextMenu.onInsertMagazine = wrapper
end

local function installEjectWrapper()
    if installedWrappers.onEjectMagazine then return end
    local current = ISInventoryPaneContextMenu.onEjectMagazine
    if type(current) ~= "function" then return end
    local delegate = current
    local wrapper = function(playerObj, weapon, ...)
        if Module.isPending("eject-magazine", playerObj, weapon) then
            recordSuppression("eject-magazine", playerObj)
            return nil
        end
        return delegate(playerObj, weapon, ...)
    end
    installedWrappers.onEjectMagazine = wrapper
    ISInventoryPaneContextMenu.onEjectMagazine = wrapper
end

local function installEquipWrapper()
    if installedWrappers.equipWeapon then return end
    local current = ISInventoryPaneContextMenu.equipWeapon
    if type(current) ~= "function" then return end
    local delegate = current
    local wrapper = function(item, primary, twoHands, playerNum, ...)
        queueDisplacedDrops(item, primary, twoHands, playerNum)
        return delegate(item, primary, twoHands, playerNum, ...)
    end
    installedWrappers.equipWeapon = wrapper
    ISInventoryPaneContextMenu.equipWeapon = wrapper
end

function Module.install()
    installWearWrapper()
    installInsertWrapper()
    installEjectWrapper()
    installEquipWrapper()
    if not activationReported then
        activationReported = true
        print("[InventoryActionIntentFix] Duplicate intent and displaced-hand floor fallback active.")
    end
end

function Module.status()
    return { suppressed = Module.suppressed, displacedDrops = Module.displacedDrops }
end

_G.InventoryActionIntentFix = Module
_G.InventoryActionIntentFix_isPending = function(kind, playerObj, primaryItem, secondaryItem)
    return Module.isPending(kind, playerObj, primaryItem, secondaryItem)
end
_G.InventoryActionIntentFix_status = function()
    return "suppressed=" .. tostring(Module.suppressed)
        .. ";displacedDrops=" .. tostring(Module.displacedDrops)
end

return Module
