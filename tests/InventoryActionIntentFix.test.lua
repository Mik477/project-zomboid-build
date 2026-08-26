local repositoryRoot = InventoryActionIntentFixRepositoryRoot or "."
package.path = table.concat({
    repositoryRoot .. "/src/mods/InventoryActionIntentFix/42.20/media/lua/client/?.lua",
    repositoryRoot .. "/src/mods/InventoryActionIntentFix/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local function assertEqual(expected, actual, label)
    if expected ~= actual then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local bootHandlers = {}
local startHandlers = {}
Events = {
    OnGameBoot = { Add = function(callback) bootHandlers[#bootHandlers + 1] = callback end },
    OnGameStart = { Add = function(callback) startHandlers[#startHandlers + 1] = callback end },
}

local playerInventory = { canFit = false, hasStack = false }
local floorInventory = {}
local floorAvailable = true
local floorSquareAvailable = true
local hotbarItem = nil
local wornItems = { items = {} }
function wornItems:size() return #self.items end
function wornItems:get(index) return self.items[index + 1] end

local player = { playerNum = 0, primary = nil, secondary = nil, vehicle = nil }
function player:getPlayerNum() return self.playerNum end
function player:getInventory() return playerInventory end
function player:getPrimaryHandItem() return self.primary end
function player:getSecondaryHandItem() return self.secondary end
function player:getWornItems() return wornItems end
function player:getVehicle() return self.vehicle end
getSpecificPlayer = function(playerNum) return playerNum == 0 and player or nil end
getPlayerHotbar = function()
    return { isInHotbar = function(_, item) return item == hotbarItem end }
end
ISInventoryPage = { GetFloorContainer = function() return floorAvailable and floorInventory or nil end }
ISTransferAction = { getNotFullFloorSquare = function() return floorSquareAvailable and {} or nil end }
instanceof = function(item, className)
    return item ~= nil and (className == "InventoryItem" or (className == "HandWeapon" and item.handWeapon == true))
end

local function makeItem(id, fullType)
    local item = { id = id, fullType = fullType, container = playerInventory }
    function item:getID() return self.id end
    function item:getFullType() return self.fullType end
    function item:getContainer() return self.container end
    function item:isRequiresEquippedBothHands() return self.requiresBoth == true end
    function item:isForceDropHeavyItem() return self.forceHeavy == true end
    return item
end

local queue = { queue = {} }
ISTimedActionQueue = { queues = { [player] = queue } }

local wearCalls = 0
local insertCalls = 0
local ejectCalls = 0
local equipCalls = 0
local floorDrops = 0
local callOrder = {}
ISInventoryPaneContextMenu = {}
ISInventoryPaneContextMenu.wearItem = function(item, playerNum)
    wearCalls = wearCalls + 1
    queue.queue[#queue.queue + 1] = { Type = "ISWearClothing", item = item }
    return "wear", playerNum
end
ISInventoryPaneContextMenu.onInsertMagazine = function(playerObj, weapon, magazine)
    insertCalls = insertCalls + 1
    queue.queue[#queue.queue + 1] = { Type = "ISInsertMagazine", gun = weapon, magazine = magazine }
    return "insert", playerObj
end
ISInventoryPaneContextMenu.onEjectMagazine = function(playerObj, weapon)
    ejectCalls = ejectCalls + 1
    queue.queue[#queue.queue + 1] = { Type = "ISEjectMagazine", gun = weapon }
    return "eject", playerObj
end
ISInventoryPaneContextMenu.equipWeapon = function(item, primary, twoHands, playerNum)
    equipCalls = equipCalls + 1
    callOrder[#callOrder + 1] = "equip"
    return "equip", playerNum
end

for _, moduleName in ipairs({
    "ISUI/ISInventoryPaneContextMenu",
    "TimedActions/ISTimedActionQueue",
    "TimedActions/ISWearClothing",
    "TimedActions/ISInsertMagazine",
    "TimedActions/ISEjectMagazine",
    "TimedActions/ISTransferAction",
    "TimedActions/ISReloadWeaponAction",
    "WeaponAbility/ChangeMagazineType",
}) do
    package.preload[moduleName] = function() return true end
end
package.preload["InventoryTetris/Model/ItemContainerGrid"] = function()
    return {
        GetOrCreate = function(container)
            return {
                findStackByItem = function() return container.hasStack == true and {} or nil end,
                canAddItem = function() return container.canFit == true end,
            }
        end,
    }
end
package.preload["InventoryTetris/System/GridAutoDropSystem"] = function()
    return {
        _isItemUndroppable = function(item) return item.undroppable == true end,
        _handleDropItem = function(item)
            floorDrops = floorDrops + 1
            callOrder[#callOrder + 1] = "drop:" .. item:getFullType()
            queue.queue[#queue.queue + 1] = {
                Type = "ISInventoryTransferAction",
                item = item,
                destContainer = floorInventory,
            }
            return true
        end,
    }
end

local Fix = require("InventoryActionIntentFix/InventoryActionIntentFix")
local Policy = require("InventoryActionIntentFix/IntentPolicy")
Fix.install()

local helmet = makeItem(10, "Base.Hat_Army")
local sameHelmet = makeItem(10, "Base.Hat_Army")
local pants = makeItem(11, "Base.Trousers")
local wearResult, wearPlayer = ISInventoryPaneContextMenu.wearItem(helmet, 0)
assertEqual("wear", wearResult, "first wear delegates")
assertEqual(0, wearPlayer, "delegate return values are preserved")
assertEqual(1, wearCalls, "first wear call count")
assertEqual(true, Policy.hasPending(queue.queue, "wear", sameHelmet), "same runtime ID matches")
assertEqual(nil, ISInventoryPaneContextMenu.wearItem(sameHelmet, 0), "duplicate wear is suppressed")
assertEqual(1, wearCalls, "duplicate wear call count")
assertEqual("wear", ISInventoryPaneContextMenu.wearItem(pants, 0), "different clothing delegates")
assertEqual(2, wearCalls, "different clothing call count")
assertEqual(false, Policy.sameItem(makeItem(0, "Base.A"), makeItem(0, "Base.B")), "zero IDs do not collide")
assertEqual(false, Policy.sameItem(makeItem(-1, "Base.A"), makeItem(-1, "Base.B")), "negative IDs do not collide")

queue.queue = {}
local gun = makeItem(20, "Base.Pistol")
local sameGun = makeItem(20, "Base.Pistol")
local otherGun = makeItem(21, "Base.Revolver")
local magazine = makeItem(30, "Base.9mmClip")
local otherMagazine = makeItem(31, "Base.9mmDrum50")
assertEqual("insert", ISInventoryPaneContextMenu.onInsertMagazine(player, gun, magazine), "first insert delegates")
assertEqual(1, insertCalls, "first insert call count")
assertEqual(true, Fix.isPending("insert-magazine", player, sameGun, magazine), "insert blocks equivalent gun intent")
assertEqual(nil, ISInventoryPaneContextMenu.onInsertMagazine(player, sameGun, magazine), "equivalent insert is suppressed")
assertEqual(1, insertCalls, "equivalent insert call count")
assertEqual("insert", ISInventoryPaneContextMenu.onInsertMagazine(player, sameGun, otherMagazine), "different magazine choice delegates")
assertEqual(2, insertCalls, "different magazine call count")
assertEqual("eject", ISInventoryPaneContextMenu.onEjectMagazine(player, sameGun), "opposite magazine operation delegates")
assertEqual(1, ejectCalls, "opposite operation call count")
assertEqual("eject", ISInventoryPaneContextMenu.onEjectMagazine(player, otherGun), "different gun delegates")
assertEqual(2, ejectCalls, "different gun eject count")

queue.queue = { { Type = "PostSwapAction", gun = gun, magType = "Base.9mmClip" } }
assertEqual(nil, ISInventoryPaneContextMenu.onInsertMagazine(player, sameGun, magazine), "Gael post-swap blocks repeat insert")
assertEqual(2, insertCalls, "Gael-blocked insert count")
assertEqual("insert", ISInventoryPaneContextMenu.onInsertMagazine(player, sameGun, otherMagazine), "Gael permits a different family")
assertEqual(3, insertCalls, "Gael different-family count")

queue.queue = {}
assertEqual("insert", ISInventoryPaneContextMenu.onInsertMagazine(player, sameGun, magazine), "intent delegates after terminal removal")
assertEqual(4, insertCalls, "retry insert call count")

local wearWrapper = ISInventoryPaneContextMenu.wearItem
local insertWrapper = ISInventoryPaneContextMenu.onInsertMagazine
local ejectWrapper = ISInventoryPaneContextMenu.onEjectMagazine
Fix.install()
assertEqual(wearWrapper, ISInventoryPaneContextMenu.wearItem, "wear install is idempotent")
assertEqual(insertWrapper, ISInventoryPaneContextMenu.onInsertMagazine, "insert install is idempotent")
assertEqual(ejectWrapper, ISInventoryPaneContextMenu.onEjectMagazine, "eject install is idempotent")
assertEqual(3, Fix.status().suppressed, "suppression count")

local bat = makeItem(40, "Base.BaseballBat")
local rifle = makeItem(41, "Base.CS5")
rifle.handWeapon = true
player.primary = bat
player.secondary = nil
playerInventory.canFit = false
callOrder = {}
local equipResult, equipPlayer = ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual("equip", equipResult, "full-grid equip delegates")
assertEqual(0, equipPlayer, "full-grid equip preserves return values")
assertEqual(1, floorDrops, "displaced item drops when no player grid fits")
assertEqual("drop:Base.BaseballBat", callOrder[1], "floor transfer queues before equip")
assertEqual("equip", callOrder[2], "equip delegates after floor transfer")

ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(1, floorDrops, "pending floor transfer is not duplicated")
queue.queue = {}

local axe = makeItem(42, "Base.Axe")
player.primary = axe
playerInventory.canFit = true
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(1, floorDrops, "fitting displaced item remains on player")

playerInventory.canFit = false
playerInventory.hasStack = true
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(1, floorDrops, "positioned displaced item remains on player")
playerInventory.hasStack = false

local backpackInventory = { canFit = true, hasStack = false }
local backpackItem = {
    IsInventoryContainer = function() return true end,
    getInventory = function() return backpackInventory end,
}
wornItems.items = { { getItem = function() return backpackItem end } }
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(1, floorDrops, "fitting worn-container grid keeps displaced item on player")
wornItems.items = {}

local hammer = makeItem(43, "Base.Hammer")
local torch = makeItem(44, "Base.Torch")
player.primary = hammer
player.secondary = torch
ISInventoryPaneContextMenu.equipWeapon(rifle, true, true, 0)
assertEqual(3, floorDrops, "two-hand equip drops both displaced items")
queue.queue = {}

local protected = makeItem(45, "Base.Protected")
player.primary = protected
protected.forceHeavy = true
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "force-heavy item remains vanilla-owned")
protected.forceHeavy = false

hotbarItem = protected
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "hotbar item is protected")
hotbarItem = nil

protected.undroppable = true
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "undroppable item is protected")
protected.undroppable = false

wornItems.items = { { getItem = function() return protected end } }
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "worn item is protected")
wornItems.items = {}

player.vehicle = {}
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "vehicle state defers to vanilla")
player.vehicle = nil

floorAvailable = false
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "missing floor container fails safe")
floorAvailable = true
floorSquareAvailable = false
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "full or invalid floor fails safe")
floorSquareAvailable = true

local externalInventory = { isInCharacterInventory = function() return false end }
protected.container = externalInventory
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(3, floorDrops, "external source is not moved by fallback")
protected.container = playerInventory

local secondaryOnly = makeItem(46, "Base.SecondaryOnly")
player.primary = protected
player.secondary = secondaryOnly
ISInventoryPaneContextMenu.equipWeapon(rifle, true, false, 0)
assertEqual(4, floorDrops, "one-hand primary equip drops only displaced primary item")
queue.queue = {}

local requiresBoth = makeItem(47, "Base.RequiresBoth")
requiresBoth.requiresBoth = true
player.primary = protected
player.secondary = secondaryOnly
ISInventoryPaneContextMenu.equipWeapon(requiresBoth, true, false, 0)
assertEqual(5, floorDrops, "displacement follows vanilla twoHands flag")
queue.queue = {}

local gaelTransfers = 0
local gaelChanges = 0
ISReloadWeaponAction = {}
ISInventoryPaneContextMenu.transferIfNeeded = function() gaelTransfers = gaelTransfers + 1 end
ChangeMagazine = function(_, _, magazineType)
    gaelChanges = gaelChanges + 1
    return magazineType == "Base.9mmClip"
end
local GaelSelection = require("GaelGunStoreCoreFixes/AutomaticMagazineSelection")
queue.queue = { { Type = "PostSwapAction", gun = gun, magType = "Base.9mmClip" } }
local equipBaseline = equipCalls
assertEqual(true, GaelSelection.queueCompatibleMagazine(player, gun, magazine, "fixture"), "Gael duplicate is handled")
assertEqual(0, gaelTransfers, "Gael duplicate does not transfer")
assertEqual(equipBaseline, equipCalls, "Gael duplicate does not equip")
assertEqual(0, gaelChanges, "Gael duplicate does not change magazine")
queue.queue = {}
assertEqual(true, GaelSelection.queueCompatibleMagazine(player, gun, magazine, "fixture"), "Gael first intent delegates")
assertEqual(1, gaelTransfers, "Gael first intent transfers")
assertEqual(equipBaseline + 1, equipCalls, "Gael first intent equips")
assertEqual(1, gaelChanges, "Gael first intent changes magazine")

print("Inventory action intent fix passed.")
