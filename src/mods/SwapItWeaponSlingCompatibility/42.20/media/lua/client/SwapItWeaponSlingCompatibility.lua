local Fix = { completionHandoffs = {} }

local function heldItem(hotbar)
    if not hotbar or not hotbar.chr then return nil end
    return hotbar.chr:getPrimaryHandItem()
end

local function heldItemWidth(hotbar)
    if not heldItem(hotbar) then return 0 end
    return (hotbar.slotWidth or 0) + (hotbar.slotPad or 0)
end

local function setPanelWidth(panel, width)
    if panel.setWidth then
        panel:setWidth(width)
    else
        panel.width = width
    end
end

local function renderHeldItem(hotbar)
    local item = heldItem(hotbar)
    if not item then return end

    local slotWidth = hotbar.slotWidth or 60
    local slotHeight = hotbar.slotHeight or 60
    local margins = hotbar.margins or 0
    local slotX = (hotbar.width or slotWidth) - margins - slotWidth - 1
    local slotY = margins + 1

    if hotbar.drawRect then
        hotbar:drawRect(slotX, slotY, slotWidth, slotHeight, 0.6, 0.35, 0.35, 0.35)
    end

    local config = CHBConfig and CHBConfig.getConfig and CHBConfig.getConfig() or nil
    local previousEquippedFlag = hotbar.isEquippedItem
    hotbar.isEquippedItem = true
    if CleanHotbarItemState and CleanHotbarItemState.renderItemState then
        CleanHotbarItemState.renderItemState(hotbar, item, slotX, slotY, slotWidth, slotHeight, config)
    end
    if CleanHotbarWeaponState and CleanHotbarWeaponState.renderWeaponState then
        CleanHotbarWeaponState.renderWeaponState(hotbar, item, slotX, slotY, slotWidth, slotHeight, config)
    end
    hotbar.isEquippedItem = previousEquippedFlag

    if hotbar.drawTextureScaledAspect and item.getTexture then
        local textureSize = math.min(slotWidth, slotHeight) * 0.54
        hotbar:drawTextureScaledAspect(
            item:getTexture(),
            slotX + (slotWidth - textureSize) / 2,
            slotY + (slotHeight - textureSize) / 2,
            textureSize,
            textureSize,
            1, 1, 1, 1
        )
    end
    if hotbar.drawText then
        hotbar:drawText("H", slotX + 3, slotY + 2, 0.85, 0.95, 0.95, 1, hotbar.font)
    end
end

local function getPendingHandoff(action)
    if not action or not action.character or not action.item then return nil, nil end

    local hotbar = getPlayerHotbar(action.character:getPlayerNum())
    local pending = hotbar and hotbar.AliceWeaponSling_PendingSwapItAttach or nil
    if (not pending or pending.equipItem ~= action.item) and hotbar then
        pending = Fix.completionHandoffs[hotbar]
    end
    if not pending or pending.equipItem ~= action.item then return nil, nil end
    return hotbar, pending
end

local function itemInHands(character, item)
    return character:getPrimaryHandItem() == item or character:getSecondaryHandItem() == item
end

local function selectedItemIsEquipped(action)
    return itemInHands(action.character, action.item)
end

local function hasExpectedAttachment(hotbar, pending)
    local item = pending.item
    return hotbar.attachedItems
        and hotbar.attachedItems[pending.slotIndex] == item
        and item:getAttachedSlot() == pending.slotIndex
        and item:getAttachedSlotType() == pending.slotType
        and item:getAttachedToModel() == pending.model
        and hotbar.chr:getAttachedItem(pending.model) == item
end

local function completeHandoff(action, hotbar, pending)
    if not hotbar or not pending or not selectedItemIsEquipped(action) then return end

    local slotOwner = hotbar.attachedItems and hotbar.attachedItems[pending.slotIndex] or nil
    if slotOwner and slotOwner ~= pending.item then return end

    local handsChanged = false
    if action.character:getPrimaryHandItem() == pending.item then
        action.character:setPrimaryHandItem(nil)
        handsChanged = true
    end
    if action.character:getSecondaryHandItem() == pending.item then
        action.character:setSecondaryHandItem(nil)
        handsChanged = true
    end

    if hotbar.AliceWeaponSling_PendingSwapItAttach == pending then
        hotbar.AliceWeaponSling_PendingSwapItAttach = nil
    end
    if Fix.completionHandoffs[hotbar] == pending then
        Fix.completionHandoffs[hotbar] = nil
    end

    local repaired = false
    if not hasExpectedAttachment(hotbar, pending)
            and AliceWeaponSling and AliceWeaponSling.repairHotbarItem then
        repaired = AliceWeaponSling.repairHotbarItem(
            hotbar,
            pending.item,
            pending.slotIndex,
            pending.slotType,
            pending.model
        )
    end

    if repaired and AliceWeaponSling.refreshWeightReductionPart then
        AliceWeaponSling.refreshWeightReductionPart(action.character, pending.item)
    end
    if handsChanged and isClient() and sendEquip then
        sendEquip(action.character)
    end
end

local function commitPendingHandoff(hotbar, selectedItem)
    local pending = hotbar and hotbar.AliceWeaponSling_PendingSwapItAttach or nil
    if not pending or pending.equipItem ~= selectedItem then return end

    local slot = hotbar.availableSlot and hotbar.availableSlot[pending.slotIndex] or nil
    if not slot or not slot.def or not hotbar.attachItem then return end

    hotbar.AliceWeaponSling_PendingSwapItAttach = nil
    Fix.completionHandoffs[hotbar] = pending
    hotbar:attachItem(
        pending.item,
        pending.model,
        pending.slotIndex,
        slot.def,
        false
    )
end

local function installActionWrappers()
    if ISEquipWeaponAction and ISEquipWeaponAction.complete ~= Fix.completeWrapper then
        local previousComplete = ISEquipWeaponAction.complete
        local previousStop = ISEquipWeaponAction.stop

        Fix.completeWrapper = function(self, ...)
            local hotbar, pending = getPendingHandoff(self)
            local result = previousComplete(self, ...)
            completeHandoff(self, hotbar, pending)
            return result
        end

        Fix.stopWrapper = function(self, ...)
            local hotbar, pending = getPendingHandoff(self)
            local result = previousStop(self, ...)
            completeHandoff(self, hotbar, pending)
            return result
        end

        ISEquipWeaponAction.complete = Fix.completeWrapper
        ISEquipWeaponAction.stop = Fix.stopWrapper
    end
end

local function installHeldItemDisplay()
    if ISHotbar and not ISHotbar.SwapItWeaponSlingCompatibilityDisplay then
        ISHotbar.SwapItWeaponSlingCompatibilityDisplay = true
        local previousRender = ISHotbar.render
        local previousSetSizeAndPosition = ISHotbar.setSizeAndPosition

        function ISHotbar:setSizeAndPosition(...)
            local result = previousSetSizeAndPosition(self, ...)
            local extraWidth = heldItemWidth(self)
            if extraWidth > 0 then
                setPanelWidth(self, (self.width or 0) + extraWidth)
            end
            return result
        end

        function ISHotbar:render(...)
            local result = previousRender(self, ...)
            renderHeldItem(self)
            return result
        end
    end
end

local function installEquipWrapper()
    if ISHotbar and ISHotbar.equipItem and ISHotbar.equipItem ~= Fix.equipItemWrapper then
        local previousEquipItem = ISHotbar.equipItem
        Fix.equipItemWrapper = function(self, item, ...)
            local result = previousEquipItem(self, item, ...)
            commitPendingHandoff(self, item)
            return result
        end
        ISHotbar.equipItem = Fix.equipItemWrapper
    end
end

function Fix.install()
    installActionWrappers()
    installHeldItemDisplay()
    installEquipWrapper()
end

Fix.install()
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(Fix.install)
end

return Fix
