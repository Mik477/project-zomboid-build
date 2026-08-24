local CompactRows = require("CompactProximityInventory/CompactRows")
local NearbyContainers = require("CompactProximityInventory/NearbyContainers")
local SelectionGuard = require("CompactProximityInventory/SelectionGuard")
local ItemGridUI = require("InventoryTetris/UI/Grid/ItemGridUI")
local ItemGridContainerUI = require("InventoryTetris/UI/Container/ItemGridContainerUI")
local ItemStack = require("InventoryTetris/Model/ItemStack")
local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local OPT = require("InventoryTetris/Settings")
require("ISUI/LootWindow/ISLootWindowContainerControls")

local function buildProjection(gridUi)
    local rectangles = {}
    for _, stack in ipairs(gridUi.grid:getStacks()) do
        local item = ItemStack.getFrontItem(stack, gridUi.grid.inventory)
        local height
        if item then
            local width
            width, height = TetrisItemData.tryGetItemSize(item, stack.isRotated)
        end
        rectangles[#rectangles + 1] = { y = stack.y or 0, height = height or 1 }
    end
    return CompactRows.build(gridUi.grid.height, rectangles)
end

local function refreshProjection(gridUi)
    local projection = buildProjection(gridUi)
    local oldSignature = gridUi.compactRowProjection and gridUi.compactRowProjection.signature or nil
    gridUi.compactRowProjection = projection
    gridUi.compactProximity = true
    gridUi:setVisible(projection.count > 0)
    return oldSignature ~= projection.signature
end

local function refreshContainerGeometry(containerUi)
    local changed = false
    for _, gridUis in pairs(containerUi.gridUis) do
        for _, gridUi in ipairs(gridUis) do
            if refreshProjection(gridUi) then changed = true end
        end
    end

    local isEmpty = containerUi.inventory:isEmpty()
    if containerUi.compactProximityEmpty ~= isEmpty then changed = true end
    containerUi.compactProximityEmpty = isEmpty
    containerUi.isGridCollapsed = isEmpty
    return changed
end

local function decorateContainerUi(containerUi, entry)
    containerUi.compactProximity = true
    containerUi.compactProximityTitle = entry.name
        or getTextOrNull("IGUI_ContainerTitle_" .. containerUi.inventory:getType())
        or "Container"
    refreshContainerGeometry(containerUi)
    containerUi:applyScales(OPT.SCALE, 0)
end

local function restoreAfterCall(ok, failure)
    if not ok then error(failure) end
end

Events.OnGameBoot.Add(function()
    if ISInventoryPane.compactProximityPatched then return end
    ISInventoryPane.compactProximityPatched = true
    SelectionGuard.install(ISInventoryPage, NearbyContainers.isMarker)

    local oldRefreshItemGrids = ISInventoryPane.refreshItemGrids
    function ISInventoryPane:refreshItemGrids(forceFullRefresh)
        local compactActive = NearbyContainers.isMarker(self.inventory)
        if not compactActive then
            local leavingCompactMode = self.compactProximityActive
            self.compactProximityActive = false
            return oldRefreshItemGrids(self, leavingCompactMode or forceFullRefresh)
        end

        self.compactProximityActive = true
        local inventoryPage = self.parent
        local entries = NearbyContainers.collect(inventoryPage)
        local temporaryButtons = {}
        local oldButtonY = {}
        for index, entry in ipairs(entries) do
            temporaryButtons[index] = entry.button
            oldButtonY[entry.button] = entry.button:getY()
            entry.button:setY(index)
        end

        local oldOnCharacter = inventoryPage.onCharacter
        local oldBackpacks = inventoryPage.backpacks
        local oldApplyBackpackOrder = inventoryPage.applyBackpackOrder
        inventoryPage.onCharacter = true
        inventoryPage.backpacks = temporaryButtons
        inventoryPage.applyBackpackOrder = function() end

        local ok, failure = pcall(oldRefreshItemGrids, self, forceFullRefresh)

        inventoryPage.onCharacter = oldOnCharacter
        inventoryPage.backpacks = oldBackpacks
        inventoryPage.applyBackpackOrder = oldApplyBackpackOrder
        for button, oldY in pairs(oldButtonY) do button:setY(oldY) end
        restoreAfterCall(ok, failure)

        local entriesByInventory = {}
        for _, entry in ipairs(entries) do entriesByInventory[entry.inventory] = entry end
        for _, containerUi in ipairs(self.gridContainerUis) do
            local entry = entriesByInventory[containerUi.inventory]
            if entry then decorateContainerUi(containerUi, entry) end
        end
        self:relayoutItemGrids()
    end

    local oldContainerTitle = ItemGridContainerUI.getInventoryName
    function ItemGridContainerUI:getInventoryName(inventory)
        if not self.compactProximity then return oldContainerTitle(self, inventory) end
        local title = self.compactProximityTitle or oldContainerTitle(self, inventory)
        if self.compactProximityEmpty then
            return title .. " - " .. (getTextOrNull("IGUI_CompactProximity_Empty") or "Empty")
        end
        return title
    end

    local oldUpdateItemGridPositions = ItemGridContainerUI.updateItemGridPositions
    function ItemGridContainerUI:updateItemGridPositions(gridUis, scale, containerDef)
        if not self.compactProximity then
            return oldUpdateItemGridPositions(self, gridUis, scale, containerDef)
        end
        if #gridUis == 0 then return 0, 0 end
        return oldUpdateItemGridPositions(self, gridUis, scale, containerDef)
    end

    local oldApplyScales = ItemGridContainerUI.applyScales
    function ItemGridContainerUI:applyScales(gridScale, infoScale)
        if not self.compactProximity then return oldApplyScales(self, gridScale, infoScale) end

        self:_sortRenderers()
        local visibleRenderers = {}
        for _, renderer in ipairs(self.multiGridRenderer.sortedRenderers) do
            renderer.compactAllGrids = renderer.compactAllGrids or renderer.grids
            local visibleGrids = {}
            for _, gridUi in ipairs(renderer.compactAllGrids) do
                refreshProjection(gridUi)
                if gridUi.compactRowProjection.count > 0 then
                    visibleGrids[#visibleGrids + 1] = gridUi
                end
            end
            renderer.grids = visibleGrids
            renderer:setVisible(#visibleGrids > 0)
            if #visibleGrids > 0 then visibleRenderers[#visibleRenderers + 1] = renderer end
        end
        self.multiGridRenderer.sortedRenderers = visibleRenderers

        oldApplyScales(self, gridScale, 0)
        self.infoRenderer:setVisible(false)
    end

    local oldContainerPrerender = ItemGridContainerUI.prerender
    function ItemGridContainerUI:prerender()
        oldContainerPrerender(self)
        if not self.compactProximity then return end

        local geometryChanged = refreshContainerGeometry(self)
        if geometryChanged then
            self:applyScales(OPT.SCALE, 0)
            if self.inventoryPane.relayoutItemGrids then self.inventoryPane:relayoutItemGrids() end
        end

        local overflowPadding = #self.containerGrid.overflow > 0 and 8 or 0
        self:setWidth(self.multiGridRenderer:getWidth() + 2 + self.overflowRenderer:getWidth() + overflowPadding)
        self.infoRenderer:setVisible(false)
        self.collapseButton:setVisible(false)
    end

    local oldCollapseClick = ItemGridContainerUI.onCollapseButtonClick
    function ItemGridContainerUI:onCollapseButtonClick(button)
        if self.compactProximity then return end
        return oldCollapseClick(self, button)
    end

    local oldCalculateHeight = ItemGridUI.calculateHeight
    function ItemGridUI:calculateHeight()
        if not self.compactProximity then return oldCalculateHeight(self) end
        local count = self.compactRowProjection and self.compactRowProjection.count or 0
        if count == 0 then return 0 end
        return count * OPT.CELL_SIZE - count + 1
    end

    local oldRenderBackGrid = ItemGridUI.renderBackGrid
    function ItemGridUI:renderBackGrid()
        if not self.compactProximity then return oldRenderBackGrid(self) end
        local oldHeight = self.grid.height
        self.grid.height = self.compactRowProjection.count
        local ok, failure = pcall(oldRenderBackGrid, self)
        self.grid.height = oldHeight
        restoreAfterCall(ok, failure)
    end

    local oldFindStack = ItemGridUI.findGridStackUnderMouse
    function ItemGridUI:findGridStackUnderMouse(mouseX, mouseY)
        if not self.compactProximity then return oldFindStack(self, mouseX, mouseY) end
        local effectiveCellSize = OPT.CELL_SIZE - 1
        local gridX = math.floor(mouseX / effectiveCellSize)
        local displayRow = math.floor(mouseY / effectiveCellSize)
        local sourceRow = CompactRows.toSource(self.compactRowProjection, displayRow)
        if sourceRow == nil then return nil end
        return self.grid:getStack(gridX, sourceRow, self.playerNum)
    end

    local oldRenderStackLoop = ItemGridUI.renderStackLoop
    function ItemGridUI:renderStackLoop(inventory, stacks, alphaMult, searchSession)
        if not self.compactProximity then
            return oldRenderStackLoop(self, inventory, stacks, alphaMult, searchSession)
        end

        local oldRows = {}
        for _, stack in ipairs(stacks) do
            oldRows[stack] = stack.y
            local displayRow = CompactRows.toDisplay(self.compactRowProjection, stack.y)
            if displayRow ~= nil then stack.y = displayRow end
        end
        local ok, failure = pcall(oldRenderStackLoop, self, inventory, stacks, alphaMult, searchSession)
        for stack, sourceRow in pairs(oldRows) do stack.y = sourceRow end
        restoreAfterCall(ok, failure)
    end

    local oldRenderIncomingTransfers = ItemGridUI.renderIncomingTransfers
    function ItemGridUI:renderIncomingTransfers()
        if self.compactProximity then return end
        return oldRenderIncomingTransfers(self)
    end

    local oldRenderDragItemPreview = ItemGridUI.renderDragItemPreview
    function ItemGridUI:renderDragItemPreview()
        if self.compactProximity then return end
        return oldRenderDragItemPreview(self)
    end

    local oldRenderControllerSelection = ItemGridUI.renderControllerSelection
    function ItemGridUI:renderControllerSelection()
        if not self.compactProximity then return oldRenderControllerSelection(self) end
        local stack = self.grid:getStack(self.selectedX, self.selectedY, self.playerNum)
        local x = stack and stack.x or self.selectedX
        local sourceY = stack and stack.y or self.selectedY
        local y = CompactRows.toDisplayOrNearest(self.compactRowProjection, sourceY)
        local width, height = 1, 1
        if stack then
            local item = ItemStack.getFrontItem(stack, self.grid.inventory)
            width, height = TetrisItemData.tryGetItemSize(item, stack.isRotated)
            width, height = width or 1, height or 1
        end
        self:drawRect(x * OPT.CELL_SIZE - x, y * OPT.CELL_SIZE - y,
            width * OPT.CELL_SIZE - width + 1, height * OPT.CELL_SIZE - height + 1,
            0.5, 0.2, 1, 1)
    end

    local oldGridPositionToScreen = ItemGridUI.gridPositionToScreenPosition
    function ItemGridUI:gridPositionToScreenPosition(gridX, gridY)
        if not self.compactProximity then return oldGridPositionToScreen(self, gridX, gridY) end
        local displayRow = CompactRows.toDisplayOrNearest(self.compactRowProjection, gridY)
        local effectiveCellSize = OPT.CELL_SIZE - 1
        return self:getAbsoluteX() + gridX * effectiveCellSize,
            self:getAbsoluteY() + displayRow * effectiveCellSize
    end

    local oldControllerDirection = ItemGridUI.controllerNodeOnJoypadDir
    function ItemGridUI:controllerNodeOnJoypadDir(dx, dy, joypadData)
        if not self.compactProximity or dy == 0 then
            return oldControllerDirection(self, dx, dy, joypadData)
        end
        if self.compactRowProjection.count == 0 then return false end

        local stack = self.grid:getStack(self.selectedX, self.selectedY, self.playerNum)
        local sourceRow = stack and stack.y or self.selectedY
        if stack and dy > 0 then
            local item = ItemStack.getFrontItem(stack, self.grid.inventory)
            local _, itemHeight = TetrisItemData.tryGetItemSize(item, stack.isRotated)
            sourceRow = sourceRow + (itemHeight or 1) - 1
        end
        local displayRow = CompactRows.toDisplayOrNearest(self.compactRowProjection, sourceRow)
        local nextDisplayRow = displayRow + (dy < 0 and -1 or 1)
        local nextSourceRow = CompactRows.toSource(self.compactRowProjection, nextDisplayRow)
        if nextSourceRow == nil then return false end

        self.selectedY = nextSourceRow
        local screenX, screenY = self:gridPositionToScreenPosition(self.selectedX, self.selectedY)
        local ControllerNode = require("InventoryTetris/UI/ControllerNode")
        ControllerNode.ensureVisibleXY(self, screenX, screenY)
        return true
    end

    local oldHandleDragAndDrop = ItemGridUI.handleDragAndDrop
    function ItemGridUI:handleDragAndDrop(mouseX, mouseY)
        if not self.compactProximity then return oldHandleDragAndDrop(self, mouseX, mouseY) end

        local hoveredStack = self:findGridStackUnderMouse(mouseX, mouseY)
        local vanillaStacks = require("InventoryTetris/System/DragAndDrop").getDraggedStacks()
        if not hoveredStack or not vanillaStacks or #vanillaStacks > 1 then return end
        local vanillaStack = vanillaStacks.items and vanillaStacks or vanillaStacks[1]
        if vanillaStack then
            self:handleDragAndDrop_generic(vanillaStack, hoveredStack.x, hoveredStack.y, hoveredStack)
        end
    end

    local oldToggleStackSelection = ItemGridUI.toggleStackSelection
    function ItemGridUI:toggleStackSelection(mouseX, mouseY)
        if not self.compactProximity then return oldToggleStackSelection(self, mouseX, mouseY) end
        local stack = self:findGridStackUnderMouse(mouseX, mouseY)
        if stack then
            self._selectedStacks = self._selectedStacks or {}
            self._selectedStacks[stack] = not self._selectedStacks[stack]
        end
    end

    local oldStartMultiDrag = ItemGridUI.startMultiDrag
    function ItemGridUI:startMultiDrag(mouseX, mouseY)
        if self.compactProximity then
            self.readyToMultiDrag = false
            return
        end
        return oldStartMultiDrag(self, mouseX, mouseY)
    end

    local oldQuickMoveItems = ItemGridUI.quickMoveItems
    function ItemGridUI:quickMoveItems(gridStack)
        local playerNum = self.playerNum
        local lootPage = getPlayerLoot(playerNum)
        if self.grid.inventory:isInCharacterInventory(getSpecificPlayer(playerNum))
            and lootPage and NearbyContainers.isMarker(lootPage.inventoryPane.inventory)
        then
            local targets = {}
            for _, entry in ipairs(NearbyContainers.getEntries(playerNum)) do
                targets[#targets + 1] = entry.inventory
            end
            self:quickMoveItemToContainer(gridStack, targets)
            lootPage.isCollapsed = false
            lootPage:clearMaxDrawHeight()
            lootPage.collapseCounter = 0
            return
        end
        return oldQuickMoveItems(self, gridStack)
    end

    -- Vanilla chooses its floor Take All / Take Same Type handlers from the
    -- displayed container type. Present the marker as floor only for that
    -- synchronous decision, then restore its distinct type immediately.
    local oldArrangeLootControls = ISLootWindowContainerControls.arrange
    function ISLootWindowContainerControls:arrange()
        local container = self:getDisplayedContainer()
        if not NearbyContainers.isMarker(container) then
            return oldArrangeLootControls(self)
        end

        local markerType = container:getType()
        container:setType("floor")
        local ok, failure = pcall(oldArrangeLootControls, self)
        container:setType(markerType)
        restoreAfterCall(ok, failure)
    end

    local oldJoypadLootControls = ISLootWindowContainerControls.handleJoypadContextMenu
    function ISLootWindowContainerControls:handleJoypadContextMenu(context)
        local container = self:getDisplayedContainer()
        if not NearbyContainers.isMarker(container) then
            return oldJoypadLootControls(self, context)
        end

        local markerType = container:getType()
        container:setType("floor")
        local ok, failure = pcall(oldJoypadLootControls, self, context)
        container:setType(markerType)
        restoreAfterCall(ok, failure)
    end
end)
