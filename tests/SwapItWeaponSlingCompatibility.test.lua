local repositoryRoot = SwapItWeaponSlingCompatibilityRepositoryRoot or "."
package.path = table.concat({
    repositoryRoot .. "/src/mods/SwapItWeaponSlingCompatibility/42.20/media/lua/client/?.lua",
    repositoryRoot .. "/src/mods/SwapItWeaponSlingCompatibility/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local gameStartCallbacks = {}
local tickCallbacks = {}
Events = {
    OnGameStart = { Add = function(callback) gameStartCallbacks[#gameStartCallbacks + 1] = callback end },
    OnTick = { Add = function(callback) tickCallbacks[#tickCallbacks + 1] = callback end },
}
ISTimedActionQueue = { queues = {} }

local function newItem(name)
    local item = {
        name = name,
        slot = -1,
        slotType = nil,
        model = nil,
    }
    function item:getAttachedSlot() return self.slot end
    function item:setAttachedSlot(value) self.slot = value end
    function item:getAttachedSlotType() return self.slotType end
    function item:setAttachedSlotType(value) self.slotType = value end
    function item:getAttachedToModel() return self.model end
    function item:setAttachedToModel(value) self.model = value end
    function item:getTexture() return self end
    return item
end

local character = {
    primary = nil,
    secondary = nil,
    attached = {},
}
function character:getPlayerNum() return 0 end
function character:getPrimaryHandItem() return self.primary end
function character:getSecondaryHandItem() return self.secondary end
function character:setPrimaryHandItem(item) self.primary = item end
function character:setSecondaryHandItem(item) self.secondary = item end
function character:setAttachedItem(model, item) self.attached[model] = item end
function character:getAttachedItem(model) return self.attached[model] end
function character:removeAttachedItem(item)
    for model, attachedItem in pairs(self.attached) do
        if attachedItem == item then self.attached[model] = nil end
    end
end

local hotbar = {
    chr = character,
    attachedItems = {},
    slotWidth = 60,
    slotHeight = 60,
    slotPad = 4,
    margins = 5,
    width = 180,
}
function hotbar:reloadIcons() end
function hotbar:drawRect() end
function hotbar:drawText() end
function hotbar:drawTextureScaledAspect(texture)
    self.lastRenderedTexture = texture
end

ISHotbar = {
    render = function(self)
        self.baseRenderCount = (self.baseRenderCount or 0) + 1
    end,
    setSizeAndPosition = function(self)
        self.width = 180
    end,
    equipItem = function(self, item)
        local heldItem = self.chr:getPrimaryHandItem()
        local slotIndex = item:getAttachedSlot()
        self.attachedItems[slotIndex] = nil
        item:setAttachedSlot(-1)
        item:setAttachedSlotType(nil)
        item:setAttachedToModel(nil)
        self.AliceWeaponSling_PendingSwapItAttach = {
            item = heldItem,
            equipItem = item,
            slotIndex = slotIndex,
            slotType = "AliceSlingBack",
            model = "AliceSlingRifle Back",
        }
    end,
    attachItem = function(self, item, model, slotIndex, slotDef, doAnim)
        self.lastAttachAnimated = doAnim
        self.chr:setAttachedItem(model, item)
        item:setAttachedSlot(slotIndex)
        item:setAttachedSlotType(slotDef.type)
        item:setAttachedToModel(model)
        self.attachedItems[slotIndex] = item
    end,
}

local lastAmmoItem = nil
CHBConfig = { getConfig = function() return {} end }
CleanHotbarItemState = { renderItemState = function() end }
CleanHotbarWeaponState = {
    renderWeaponState = function(_, item)
        lastAmmoItem = item
    end,
}

getPlayerHotbar = function() return hotbar end
ISInventoryPage = { renderDirty = false }
local equipSyncs = 0
isClient = function() return true end
sendEquip = function() equipSyncs = equipSyncs + 1 end

AliceWeaponSling = {}
function AliceWeaponSling.repairHotbarItem(targetHotbar, item, slotIndex, slotType, model)
    if targetHotbar.chr:getPrimaryHandItem() == item or targetHotbar.chr:getSecondaryHandItem() == item then
        return false
    end
    targetHotbar.chr:setAttachedItem(model, item)
    item:setAttachedSlot(slotIndex)
    item:setAttachedSlotType(slotType)
    item:setAttachedToModel(model)
    targetHotbar.attachedItems[slotIndex] = item
    return true
end

local function currentAliceComplete(action)
    local result = action:vanillaComplete()
    local pending = hotbar.AliceWeaponSling_PendingSwapItAttach
    if pending and pending.equipItem == action.item then
        hotbar.AliceWeaponSling_PendingSwapItAttach = nil
        if result ~= false then
            AliceWeaponSling.repairHotbarItem(
                hotbar, pending.item, pending.slotIndex, pending.slotType, pending.model)
        end
    end
    return result
end

local function currentFancyComplete(action)
    local result = currentAliceComplete(action)
    if action.hgun and result ~= false and character:getSecondaryHandItem() == nil then
        character:setSecondaryHandItem(action.hgun)
        sendEquip(character)
    end
    return result
end

ISEquipWeaponAction = {
    complete = currentFancyComplete,
    stop = function() return nil end,
}

local compatibilityLoaded, Compatibility = pcall(require, "SwapItWeaponSlingCompatibility")
hotbar.attachItem = ISHotbar.attachItem

local function reset()
    character.primary = nil
    character.secondary = nil
    character.attached = {}
    hotbar.attachedItems = {}
    hotbar.availableSlot = {
        [4] = { def = { type = "AliceSlingBack", name = "Back" } },
    }
    hotbar.AliceWeaponSling_PendingSwapItAttach = nil
    hotbar.lastRenderedTexture = nil
    hotbar.baseRenderCount = 0
    hotbar.width = 180
    lastAmmoItem = nil
    equipSyncs = 0
end

local function pendingSwap(heldItem, selectedItem)
    hotbar.AliceWeaponSling_PendingSwapItAttach = {
        item = heldItem,
        equipItem = selectedItem,
        slotIndex = 4,
        slotType = "AliceSlingBack",
        model = "AliceSlingRifle Back",
    }
end

reset()
local alreadyHeld = newItem("A-already")
local alreadySelected = newItem("B-already")
character.primary = alreadySelected
pendingSwap(alreadyHeld, alreadySelected)
local alreadyAction = {
    character = character,
    item = alreadySelected,
    vanillaComplete = function() return false end,
}
ISEquipWeaponAction.complete(alreadyAction)
assert(hotbar.attachedItems[4] == alreadyHeld,
    "an idempotent already-equipped completion must still put the displaced item in Back")
assert(alreadyHeld:getAttachedSlot() == 4 and alreadyHeld:getAttachedSlotType() == "AliceSlingBack")

reset()
local restoredHeld = newItem("A-fancy")
local restoredSelected = newItem("B-fancy")
character.primary = restoredHeld
character.secondary = restoredHeld
pendingSwap(restoredHeld, restoredSelected)
local fancyAction = {
    character = character,
    item = restoredSelected,
    hgun = restoredHeld,
    vanillaComplete = function(self)
        character.primary = self.item
        character.secondary = nil
        return true
    end,
}
ISEquipWeaponAction.complete(fancyAction)
assert(character.primary == restoredSelected and character.secondary == nil,
    "the displaced item must not be restored to an off hand after the Back swap")
assert(hotbar.attachedItems[4] == restoredHeld,
    "the formerly held item must occupy the vacated Back hotbar slot")
assert(character:getAttachedItem("AliceSlingRifle Back") == restoredHeld,
    "the formerly held item must use the Back attachment model")
assert(equipSyncs == 2, "Fancy restore and compatibility correction must each synchronize once")

reset()
local ordinary = newItem("ordinary")
character.primary = ordinary
local ordinaryAction = {
    character = character,
    item = ordinary,
    vanillaComplete = function() return false end,
}
assert(ISEquipWeaponAction.complete(ordinaryAction) == false,
    "actions without a Swap It handoff must preserve their original result")
assert(hotbar.attachedItems[4] == nil, "ordinary actions must not synthesize hotbar state")

reset()
local heldDisplay = newItem("A-held-display")
local backDisplay = newItem("B-back-display")
character.primary = heldDisplay
backDisplay:setAttachedSlot(4)
backDisplay:setAttachedSlotType("AliceSlingBack")
backDisplay:setAttachedToModel("AliceSlingRifle Back")
hotbar.attachedItems[4] = backDisplay
ISHotbar.setSizeAndPosition(hotbar)
ISHotbar.render(hotbar)
assert(hotbar.baseRenderCount == 1, "the existing Clean Hot Bar render must still run")
assert(hotbar.width > 180, "the held-item display must reserve its own bottom-bar width")
assert(hotbar.lastRenderedTexture == heldDisplay,
    "the primary-hand item must be rendered beside the numbered attachment slots")
assert(lastAmmoItem == heldDisplay,
    "the held-item display must delegate ammo rendering to Clean Hot Bar")
assert(hotbar.attachedItems[4] == backDisplay,
    "the display-only held item must not replace the physical Back-slot item")

reset()
local relocatedHeld = newItem("A-relocated-after-equip")
local relocatedSelected = newItem("B-relocated-after-equip")
character.primary = relocatedHeld
character.secondary = relocatedHeld
relocatedSelected:setAttachedSlot(4)
relocatedSelected:setAttachedSlotType("AliceSlingBack")
relocatedSelected:setAttachedToModel("AliceSlingRifle Back")
hotbar.attachedItems[4] = relocatedSelected
ISHotbar.equipItem(hotbar, relocatedSelected)
assert(hotbar.AliceWeaponSling_PendingSwapItAttach == nil,
    "compatibility must consume Alice's pending handoff at the Swap It call site")
assert(hotbar.attachedItems[4] == relocatedHeld,
    "the displaced item must own Back before the selected weapon's equip action runs")
assert(hotbar.lastAttachAnimated == false,
    "the call-site repair must commit metadata immediately instead of queueing a late animation")

character.primary = relocatedSelected
character.secondary = relocatedSelected
assert(hotbar.attachedItems[4] == relocatedHeld,
    "the selected weapon completing must not erase the displaced item's Back assignment")
assert(character:getAttachedItem("AliceSlingRifle Back") == relocatedHeld,
    "settled reconciliation must restore the displaced item's physical Back model")

if compatibilityLoaded then
    local wrappedComplete = ISEquipWeaponAction.complete
    Compatibility.install()
    assert(ISEquipWeaponAction.complete == wrappedComplete, "compatibility installer must be idempotent")
end

print("Swap It weapon-sling compatibility fixtures passed.")
