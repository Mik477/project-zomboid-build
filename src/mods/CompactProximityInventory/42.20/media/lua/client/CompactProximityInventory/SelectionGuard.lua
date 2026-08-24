local SelectionPolicy = require("CompactProximityInventory/SelectionPolicy")

local SelectionGuard = {}

---@param inventoryPageClass table
---@param isMarker fun(container: ItemContainer?): boolean
function SelectionGuard.install(inventoryPageClass, isMarker)
    if inventoryPageClass.compactProximitySelectionGuardPatched then return end
    inventoryPageClass.compactProximitySelectionGuardPatched = true

    local function isCompactSelected(inventoryPage)
        return inventoryPage and inventoryPage.inventoryPane
            and isMarker(inventoryPage.inventoryPane.inventory)
    end

    local function runExplicitSelection(inventoryPage, callback, ...)
        inventoryPage.compactProximityExplicitSelection = true
        local ok, result = pcall(callback, inventoryPage, ...)
        inventoryPage.compactProximityExplicitSelection = false
        if not ok then error(result) end
        return result
    end

    local function restoreCompactSelection(inventoryPage)
        if isCompactSelected(inventoryPage) then return end

        local markerButton
        for _, button in ipairs(inventoryPage.backpacks or {}) do
            if isMarker(button.inventory) then
                markerButton = button
                break
            end
        end
        if not markerButton then return end

        inventoryPage.forceSelectedContainer = nil
        inventoryPage.forceSelectedContainerTime = nil
        inventoryPage.inventoryPane.lastinventory = markerButton.inventory
        inventoryPage:setNewContainer(markerButton.inventory)
        inventoryPage.inventory = markerButton.inventory
        inventoryPage.selectedButton = markerButton
        inventoryPage.capacity = markerButton.capacity
        inventoryPage.title = markerButton.name

        for _, button in ipairs(inventoryPage.backpacks or {}) do
            if button.setBackgroundRGBA then
                if button == markerButton then
                    button:setBackgroundRGBA(0.7, 0.7, 0.7, 1.0)
                else
                    button:setBackgroundRGBA(0.0, 0.0, 0.0, 0.0)
                end
            end
        end

        if inventoryPage.refreshWeight then inventoryPage:refreshWeight() end
        if inventoryPage.updateItemCount then inventoryPage:updateItemCount() end
        if inventoryPage.controlsUI then inventoryPage.controlsUI:arrange() end
    end

    local oldSetForceSelectedContainer = inventoryPageClass.setForceSelectedContainer
    function inventoryPageClass:setForceSelectedContainer(container, ms)
        if SelectionPolicy.shouldKeepCompact(isCompactSelected(self), false) then
            self.forceSelectedContainer = nil
            self.forceSelectedContainerTime = nil
            return
        end
        return oldSetForceSelectedContainer(self, container, ms)
    end

    local oldSelectButtonForContainer = inventoryPageClass.selectButtonForContainer
    function inventoryPageClass:selectButtonForContainer(container)
        if SelectionPolicy.shouldKeepCompact(isCompactSelected(self), false) then
            return
        end
        return oldSelectButtonForContainer(self, container)
    end

    local oldSelectContainer = inventoryPageClass.selectContainer
    function inventoryPageClass:selectContainer(button)
        if button and isMarker(button.inventory) then
            self.compactProximityStickySelected = true
            self.forceSelectedContainer = nil
            self.forceSelectedContainerTime = nil
        elseif SelectionPolicy.shouldKeepCompact(
            self.compactProximityStickySelected == true or isCompactSelected(self),
            self.compactProximityExplicitSelection == true
        ) then
            return
        elseif self.compactProximityExplicitSelection then
            self.compactProximityStickySelected = false
        end
        return oldSelectContainer(self, button)
    end


    local oldOnBackpackClick = inventoryPageClass.onBackpackClick
    function inventoryPageClass:onBackpackClick(button)
        return runExplicitSelection(self, oldOnBackpackClick, button)
    end

    local oldSelectNextContainer = inventoryPageClass.selectNextContainer
    if oldSelectNextContainer then
        function inventoryPageClass:selectNextContainer()
            return runExplicitSelection(self, oldSelectNextContainer)
        end
    end

    local oldSelectPrevContainer = inventoryPageClass.selectPrevContainer
    if oldSelectPrevContainer then
        function inventoryPageClass:selectPrevContainer()
            return runExplicitSelection(self, oldSelectPrevContainer)
        end
    end

    local oldRefreshBackpacks = inventoryPageClass.refreshBackpacks
    function inventoryPageClass:refreshBackpacks(...)
        local shouldKeepCompact = self.compactProximityStickySelected == true
            or (not self.compactProximityExplicitSelection and isCompactSelected(self))

        local result = oldRefreshBackpacks(self, ...)

        if shouldKeepCompact then
            self.compactProximityStickySelected = true
            restoreCompactSelection(self)
        elseif isCompactSelected(self) then
            self.compactProximityStickySelected = true
        end
        return result
    end
end

return SelectionGuard
