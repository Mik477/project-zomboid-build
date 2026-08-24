local Core = require("InventoryTetrisTransferDiagnostics/InventoryDiagnosticsCore")
local KeyRingSupport = require("InventoryTetris/KeyRingSupport")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local GridAutoDropSystem = require("InventoryTetris/System/GridAutoDropSystem")

require("TimedActions/ISInventoryTransferAction")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISEquipWeaponAction")
require("ISUI/ISInventoryPane")
require("ISUI/ISInventoryPaneContextMenu")

local Diagnostics = {}
local PREFIX = "ITTransferDiag"
local MAX_LINES = 2500
local traceCounter = 0
local lineCount = 0
local suppressed = 0
local installed = false
local currentEquipIntent = nil
local currentKeyRingIntent = nil
local traceByItemId = {}

InventoryTetrisTransferDiagnostics = InventoryTetrisTransferDiagnostics or {}
if InventoryTetrisTransferDiagnostics.enabled == nil then
    InventoryTetrisTransferDiagnostics.enabled = true
end

local function nowMs()
    return getTimestampMs and getTimestampMs() or 0
end

local function safeCall(callback, fallback)
    local ok, value = pcall(callback)
    if ok then return value end
    return fallback
end

local function bool(value)
    return value and "true" or "false"
end

local function itemId(item)
    return item and safeCall(function() return tostring(item:getID()) end, nil) or nil
end

local function itemType(item)
    return item and safeCall(function() return item:getFullType() end, nil) or "nil"
end

local function isLocalPlayer(character)
    if not character then return false end
    return safeCall(function()
        return instanceof(character, "IsoPlayer") and character:isLocalPlayer()
    end, false)
end

local function isKeyRingContainer(container)
    return safeCall(function() return KeyRingSupport.isContainer(container) end, false)
end

local function isContainerOnPlayer(container, character)
    if not container or not character then return false end
    local inventory = safeCall(function() return character:getInventory() end, nil)
    if not inventory then return false end
    if container == inventory then return true end
    return safeCall(function() return container:isInCharacterInventory(character) end, false)
end

local function describeContainer(container, character)
    if not container then return "nil" end
    local inventory = character and safeCall(function() return character:getInventory() end, nil) or nil
    if container == inventory then return "player-main" end
    if isKeyRingContainer(container) then
        return isContainerOnPlayer(container, character) and "player-keyring" or "external-keyring"
    end

    local containerType = safeCall(function() return container:getType() end, "unknown")
    if isContainerOnPlayer(container, character) then
        local containingItem = safeCall(function() return container:getContainingItem() end, nil)
        if containingItem then
            return "player-nested:" .. itemType(containingItem)
        end
        return "player:" .. tostring(containerType)
    end
    return "external:" .. tostring(containerType)
end

local function newTraceId()
    traceCounter = traceCounter + 1
    return "I" .. tostring(traceCounter)
end

local function emit(traceId, eventName, fields)
    if not InventoryTetrisTransferDiagnostics.enabled then return end
    if lineCount >= MAX_LINES then
        suppressed = suppressed + 1
        if suppressed == 1 then
            print(Core.format(PREFIX, "SESSION", "log-cap-reached", { maxLines = MAX_LINES }))
        end
        return
    end
    lineCount = lineCount + 1
    print(Core.format(PREFIX, traceId or "SESSION", eventName, fields or {}))
end

local function rememberTrace(item, traceId)
    local id = itemId(item)
    if id then traceByItemId[id] = traceId end
end

local function findRememberedTrace(item)
    local id = itemId(item)
    return id and traceByItemId[id] or nil
end

local function queueTypes(character)
    if not character then return {}, 0 end
    local queue = safeCall(function() return ISTimedActionQueue.getTimedActionQueue(character) end, nil)
    if not queue or not queue.queue then return {}, 0 end
    local blockers = {}
    for _, queuedAction in ipairs(queue.queue) do
        blockers[#blockers + 1] = queuedAction.Type or "unknown"
    end
    return blockers, #queue.queue
end

local function transferState(action)
    if not action or not action.item then return "missing-item" end
    if action.destContainer and safeCall(function() return action.destContainer:contains(action.item) end, false) then
        return "destination"
    end
    if action.srcContainer and safeCall(function() return action.srcContainer:contains(action.item) end, false) then
        return "source"
    end
    return "neither-container"
end

local function safeItemAllowed(container, item)
    if not container or not item then return nil end
    return safeCall(function() return container:isItemAllowed(item) end, nil)
end

local function safeRemoveAllowed(container, item)
    if not container or not item then return nil end
    return safeCall(function() return container:isRemoveItemAllowed(item) end, nil)
end

local function safeHasRoom(container, character, item)
    if not container or not character or not item then return nil end
    return safeCall(function() return container:hasRoomFor(character, item) end, nil)
end

local function validationSnapshot(action)
    local item = action and action.item or nil
    local source = action and action.srcContainer or nil
    local destination = action and action.destContainer or nil
    local sourceContains = nil
    if source and item then
        sourceContains = safeCall(function() return source:contains(item) end, nil)
    end
    return {
        hasItem = item ~= nil,
        hasSource = source ~= nil,
        hasDestination = destination ~= nil,
        sameContainer = source ~= nil and source == destination,
        craftingConsumed = item and safeCall(function() return item:getIsCraftingConsumed() end, false) or false,
        sourceContains = sourceContains,
        sourceAllowsRemoval = safeRemoveAllowed(source, item),
        destinationAllows = safeItemAllowed(destination, item),
        destinationHasRoom = safeHasRoom(destination, action and action.character, item),
        tetrisFits = action and action.cpiTetrisFits or nil,
    }
end

local function transferFields(action)
    local inventoryTetris = SandboxVars and SandboxVars.InventoryTetris or nil
    return {
        item = itemType(action and action.item),
        itemId = itemId(action and action.item),
        reason = action and action.cpiMoveReason,
        source = describeContainer(action and action.srcContainer, action and action.character),
        destination = describeContainer(action and action.destContainer, action and action.character),
        maxTime = action and action.maxTime,
        useTransferTime = inventoryTetris and bool(inventoryTetris.UseItemTransferTime) or "unknown",
        client = isClient and bool(isClient()) or "unknown",
        enforceTetris = action and bool(action.enforceTetrisRules) or "false",
        grid = action and action.gridIndex or "none",
    }
end

local function installTransferTracing()
    local oldNew = ISInventoryTransferAction.new
    function ISInventoryTransferAction:new(character, item, source, destination, time, ...)
        local action = oldNew(self, character, item, source, destination, time, ...)
        if not action or not isLocalPlayer(character) then return action end

        local pendingEquip = currentEquipIntent and currentEquipIntent.item == item
        local pendingKeyRing = currentKeyRingIntent and currentKeyRingIntent.itemId == itemId(item)
        local reason = Core.classifyMove({
            pendingEquip = pendingEquip,
            sourceKeyRing = isKeyRingContainer(source),
            destinationKeyRing = isKeyRingContainer(destination),
            sourceOnPlayer = isContainerOnPlayer(source, character),
            destinationOnPlayer = isContainerOnPlayer(destination, character),
        })
        if not reason then return action end

        action.cpiTraceId = pendingEquip and currentEquipIntent.traceId
            or pendingKeyRing and currentKeyRingIntent.traceId
            or newTraceId()
        action.cpiMoveReason = reason
        action.cpiCreatedAt = nowMs()
        action.cpiLastMaxTime = action.maxTime
        action.cpiLastState = transferState(action)
        rememberTrace(item, action.cpiTraceId)
        emit(action.cpiTraceId, "transfer-created", transferFields(action))
        return action
    end

    local oldValidateTetrisRules = ISInventoryTransferAction.validateTetrisRules
    if oldValidateTetrisRules then
        function ISInventoryTransferAction:validateTetrisRules(...)
            local result = oldValidateTetrisRules(self, ...)
            self.cpiTetrisFits = result
            if self.cpiTraceId and result == false and not self.cpiLoggedTetrisFailure then
                self.cpiLoggedTetrisFailure = true
                emit(self.cpiTraceId, "tetris-validation-failed", transferFields(self))
            end
            return result
        end
    end

    local oldIsValid = ISInventoryTransferAction.isValid
    function ISInventoryTransferAction:isValid(...)
        local result = oldIsValid(self, ...)
        if self.cpiTraceId and result == false then
            local snapshot = validationSnapshot(self)
            local reason = Core.validationReason(snapshot)
            if self.cpiLastValidationReason ~= reason then
                self.cpiLastValidationReason = reason
                local fields = transferFields(self)
                fields.failure = reason
                fields.state = transferState(self)
                emit(self.cpiTraceId, "transfer-validation-failed", fields)
            end
        end
        return result
    end

    local oldStart = ISInventoryTransferAction.start
    function ISInventoryTransferAction:start(...)
        if self.cpiTraceId then
            self.cpiStartedAt = nowMs()
            local fields = transferFields(self)
            fields.queueWaitMs = self.cpiEnqueuedAt and (self.cpiStartedAt - self.cpiEnqueuedAt) or "unknown"
            fields.blockers = self.cpiBlockers or "none"
            fields.state = transferState(self)
            emit(self.cpiTraceId, "transfer-start", fields)
        end
        local result = oldStart(self, ...)
        if self.cpiTraceId then
            local fields = transferFields(self)
            fields.transactionId = self.transactionId or 0
            fields.waitForServer = bool(self.maxTime == -1 or (self.action and safeCall(function() return self.action:getWaitForFinished() end, false)))
            emit(self.cpiTraceId, "transfer-started", fields)
        end
        return result
    end

    local oldUpdate = ISInventoryTransferAction.update
    function ISInventoryTransferAction:update(...)
        local result = oldUpdate(self, ...)
        if not self.cpiTraceId then return result end

        if self.maxTime ~= self.cpiLastMaxTime then
            emit(self.cpiTraceId, "transfer-duration-changed", {
                before = self.cpiLastMaxTime,
                after = self.maxTime,
                transactionId = self.transactionId or 0,
                elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
            })
            self.cpiLastMaxTime = self.maxTime
        end

        local state = transferState(self)
        if state ~= self.cpiLastState then
            emit(self.cpiTraceId, "transfer-state-changed", {
                before = self.cpiLastState,
                after = state,
                transactionId = self.transactionId or 0,
                elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
            })
            self.cpiLastState = state
        end

        if isClient and isClient() and self.transactionId and self.transactionId > 0 then
            if not self.cpiTransactionRejected and isItemTransactionRejected and isItemTransactionRejected(self.transactionId) then
                self.cpiTransactionRejected = true
                emit(self.cpiTraceId, "transfer-server-rejected", {
                    transactionId = self.transactionId,
                    elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
                    state = state,
                })
            elseif not self.cpiTransactionDone and isItemTransactionDone and isItemTransactionDone(self.transactionId) then
                self.cpiTransactionDone = true
                emit(self.cpiTraceId, "transfer-server-confirmed", {
                    transactionId = self.transactionId,
                    elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
                    state = state,
                })
            end
        end
        return result
    end

    local oldTransferItem = ISInventoryTransferAction.transferItem
    function ISInventoryTransferAction:transferItem(item, ...)
        local startedAt = nowMs()
        local result = oldTransferItem(self, item, ...)
        if self.cpiTraceId then
            local gridFound = false
            if self.destContainer and not isKeyRingContainer(self.destContainer) then
                local grid = safeCall(function()
                    return ItemContainerGrid.FindInstance(self.destContainer, self.character:getPlayerNum())
                end, nil)
                gridFound = grid and safeCall(function() return grid:findStackByItem(item) ~= nil end, false) or false
            end
            emit(self.cpiTraceId, "transfer-item-applied", {
                item = itemType(item),
                itemId = itemId(item),
                elapsedMs = nowMs() - startedAt,
                state = transferState(self),
                keyRingDestination = bool(isKeyRingContainer(self.destContainer)),
                destinationGridFound = bool(gridFound),
            })
        end
        return result
    end

    local oldPerform = ISInventoryTransferAction.perform
    function ISInventoryTransferAction:perform(...)
        local beforeQueue = self.queueList and #self.queueList or 0
        local result = oldPerform(self, ...)
        if self.cpiTraceId then
            emit(self.cpiTraceId, "transfer-perform", {
                elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
                totalElapsedMs = self.cpiCreatedAt and (nowMs() - self.cpiCreatedAt) or "unknown",
                state = transferState(self),
                mergedBefore = beforeQueue,
                mergedAfter = self.queueList and #self.queueList or 0,
                transactionId = self.transactionId or 0,
            })
        end
        return result
    end

    local oldStop = ISInventoryTransferAction.stop
    function ISInventoryTransferAction:stop(...)
        if self.cpiTraceId then
            emit(self.cpiTraceId, "transfer-stopped", {
                elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
                state = transferState(self),
                transactionId = self.transactionId or 0,
                failure = Core.validationReason(validationSnapshot(self)),
            })
        end
        return oldStop(self, ...)
    end
end

local function installQueueTracing()
    local oldAdd = ISTimedActionQueue.add
    ISTimedActionQueue.add = function(action)
        if not action or not action.cpiTraceId then
            return oldAdd(action)
        end

        local blockers, countBefore = queueTypes(action.character)
        action.cpiEnqueuedAt = nowMs()
        action.cpiBlockers = Core.summarizeBlockers(blockers)
        local result = oldAdd(action)
        local queue = safeCall(function() return ISTimedActionQueue.getTimedActionQueue(action.character) end, nil)
        local index = queue and safeCall(function() return queue:indexOf(action) end, -1) or -1
        emit(action.cpiTraceId, index == -1 and "action-not-enqueued" or "action-enqueued", {
            action = action.Type or "unknown",
            queueBefore = countBefore,
            queuePosition = index,
            blockers = action.cpiBlockers,
        })
        return result
    end
end

local function installEquipTracing()
    local oldEquipWeapon = ISInventoryPaneContextMenu.equipWeapon
    ISInventoryPaneContextMenu.equipWeapon = function(weapon, primary, twoHands, playerNum, alwaysTurnOn)
        local playerObj = getSpecificPlayer(playerNum)
        local traceId = newTraceId()
        currentEquipIntent = { traceId = traceId, item = weapon }
        rememberTrace(weapon, traceId)
        local blockers, queueDepth = queueTypes(playerObj)
        emit(traceId, "equip-intent", {
            item = itemType(weapon),
            itemId = itemId(weapon),
            source = describeContainer(weapon and weapon:getContainer(), playerObj),
            primary = bool(primary),
            twoHands = bool(twoHands),
            queueDepth = queueDepth,
            blockers = Core.summarizeBlockers(blockers),
        })

        local ok, result = pcall(oldEquipWeapon, weapon, primary, twoHands, playerNum, alwaysTurnOn)
        currentEquipIntent = nil
        if not ok then
            emit(traceId, "equip-intent-error", { error = "wrapped-handler-failed" })
            error(result)
        end
        return result
    end

    local oldNew = ISEquipWeaponAction.new
    function ISEquipWeaponAction:new(character, item, maxTimeInit, primary, twoHands, alwaysTurnOn, ...)
        local action = oldNew(self, character, item, maxTimeInit, primary, twoHands, alwaysTurnOn, ...)
        if not action or not isLocalPlayer(character) then return action end
        local traceId = currentEquipIntent and currentEquipIntent.item == item and currentEquipIntent.traceId
            or findRememberedTrace(item)
            or newTraceId()
        action.cpiTraceId = traceId
        action.cpiCreatedAt = nowMs()
        emit(traceId, "equip-action-created", {
            item = itemType(item),
            itemId = itemId(item),
            maxTime = action.maxTime,
            fromHotbar = bool(action.fromHotbar),
            primary = bool(action.primary),
            twoHands = bool(action.twoHands),
        })
        return action
    end

    local oldStart = ISEquipWeaponAction.start
    function ISEquipWeaponAction:start(...)
        if self.cpiTraceId then
            self.cpiStartedAt = nowMs()
            emit(self.cpiTraceId, "equip-start", {
                item = itemType(self.item),
                queueWaitMs = self.cpiEnqueuedAt and (self.cpiStartedAt - self.cpiEnqueuedAt) or "unknown",
                blockers = self.cpiBlockers or "none",
                maxTime = self.maxTime,
                duration = safeCall(function() return self:getDuration() end, "unknown"),
                fromHotbar = bool(self.fromHotbar),
                alreadyEquipped = bool(safeCall(function() return self:isAlreadyEquipped() end, false)),
            })
        end
        return oldStart(self, ...)
    end

    local oldComplete = ISEquipWeaponAction.complete
    function ISEquipWeaponAction:complete(...)
        local result = oldComplete(self, ...)
        if self.cpiTraceId then
            emit(self.cpiTraceId, "equip-complete", {
                item = itemType(self.item),
                result = result,
                elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
                totalElapsedMs = self.cpiCreatedAt and (nowMs() - self.cpiCreatedAt) or "unknown",
                primaryMatch = bool(self.character and self.character:getPrimaryHandItem() == self.item),
                secondaryMatch = bool(self.character and self.character:getSecondaryHandItem() == self.item),
            })
        end
        return result
    end

    local oldStop = ISEquipWeaponAction.stop
    function ISEquipWeaponAction:stop(...)
        if self.cpiTraceId then
            emit(self.cpiTraceId, "equip-stopped", {
                item = itemType(self.item),
                elapsedMs = self.cpiStartedAt and (nowMs() - self.cpiStartedAt) or "unknown",
                itemInMainInventory = bool(self.character and self.character:getInventory():contains(self.item)),
            })
        end
        return oldStop(self, ...)
    end
end

local function rowItem(pane, row)
    local entry = pane and pane.items and pane.items[row] or nil
    if not entry then return nil, 0 end
    if safeCall(function() return instanceof(entry, "InventoryItem") end, false) then return entry, 1 end
    if not entry.items then return nil, 0 end
    local count = 0
    local first = nil
    for index, item in ipairs(entry.items) do
        if index > 1 and safeCall(function() return instanceof(item, "InventoryItem") end, false) then
            count = count + 1
            first = first or item
        end
    end
    return first, count
end

local function actualItems(value)
    if not value then return {} end
    return safeCall(function() return ISInventoryPane.getActualItems(value) end, {}) or {}
end

local function keyRingSignature(pane)
    local ids = {}
    local inventory = pane and pane.inventory or nil
    local items = inventory and inventory:getItems() or nil
    if items then
        for index = 0, items:size() - 1 do
            ids[#ids + 1] = itemId(items:get(index)) or "nil"
        end
    end
    table.sort(ids)
    return table.concat(ids, ","), #ids
end

local function installKeyRingUiTracing()
    local oldRefresh = ISInventoryPane.refreshContainer
    function ISInventoryPane:refreshContainer(...)
        local result = oldRefresh(self, ...)
        if self.tetrisVanillaPane then
            local signature, count = keyRingSignature(self)
            if signature ~= self.cpiKeyRingSignature then
                self.cpiKeyRingSignature = signature
                emit(self.cpiKeyRingTraceId or "KEYRING", "keyring-rows-refreshed", {
                    count = count,
                    itemIds = signature == "" and "none" or signature,
                    splitByKeyId = bool(self.tetrisSplitKeysById),
                })
            end
        end
        return result
    end

    local oldMouseDown = ISInventoryPane.onMouseDown
    function ISInventoryPane:onMouseDown(x, y, ...)
        if not self.tetrisVanillaPane then return oldMouseDown(self, x, y, ...) end
        local row = math.floor((y - self.headerHgt) / self.itemHgt) + 1
        local item, groupCount = rowItem(self, row)
        local traceId = newTraceId()
        self.cpiKeyRingTraceId = traceId
        self.cpiKeyRingMouseItemId = itemId(item)
        emit(traceId, "keyring-mouse-down", {
            row = row,
            item = itemType(item),
            itemId = itemId(item),
            groupCount = groupCount,
            mouseOverBefore = self.mouseOverOption or 0,
            source = describeContainer(self.inventory, getSpecificPlayer(self.player)),
        })
        local result = oldMouseDown(self, x, y, ...)
        emit(traceId, "keyring-mouse-down-result", {
            mouseOverAfter = self.mouseOverOption or 0,
            dragging = bool(ISMouseDrag and ISMouseDrag.dragging),
            draggingFocusIsPane = bool(ISMouseDrag and ISMouseDrag.draggingFocus == self),
        })
        return result
    end

    local oldMouseUp = ISInventoryPane.onMouseUp
    function ISInventoryPane:onMouseUp(x, y, ...)
        if not self.tetrisVanillaPane then return oldMouseUp(self, x, y, ...) end
        local traceId = self.cpiKeyRingTraceId or newTraceId()
        local draggedItems = actualItems(ISMouseDrag and ISMouseDrag.dragging or nil)
        local draggedItem = draggedItems[1]
        local selectedItem, groupCount = rowItem(self, self.mouseOverOption or 0)
        currentKeyRingIntent = {
            traceId = traceId,
            itemId = itemId(draggedItem) or self.cpiKeyRingMouseItemId or itemId(selectedItem),
        }
        emit(traceId, "keyring-mouse-up", {
            row = self.mouseOverOption or 0,
            selectedItem = itemType(selectedItem),
            selectedItemId = itemId(selectedItem),
            groupCount = groupCount,
            draggedItem = itemType(draggedItem),
            draggedItemId = itemId(draggedItem),
            draggingFocusIsPane = bool(ISMouseDrag and ISMouseDrag.draggingFocus == self),
            hasDragOwner = bool(ISMouseDrag and ISMouseDrag.dragOwner),
        })
        local ok, result = pcall(oldMouseUp, self, x, y, ...)
        currentKeyRingIntent = nil
        if not ok then
            emit(traceId, "keyring-mouse-up-error", { error = "wrapped-handler-failed" })
            error(result)
        end
        emit(traceId, "keyring-mouse-up-result", {
            mouseOver = self.mouseOverOption or 0,
            dragging = bool(ISMouseDrag and ISMouseDrag.dragging),
            itemStillInKeyRing = bool(draggedItem and self.inventory:contains(draggedItem)),
        })
        return result
    end

    local oldTransferItemsByWeight = ISInventoryPane.transferItemsByWeight
    function ISInventoryPane:transferItemsByWeight(items, container, ...)
        if not self.tetrisVanillaPane then
            return oldTransferItemsByWeight(self, items, container, ...)
        end
        local traceId = currentKeyRingIntent and currentKeyRingIntent.traceId or self.cpiKeyRingTraceId or newTraceId()
        local count = #actualItems(items)
        emit(traceId, "keyring-transfer-request", {
            count = count,
            source = describeContainer(self.inventory, getSpecificPlayer(self.player)),
            destination = describeContainer(container, getSpecificPlayer(self.player)),
        })
        return oldTransferItemsByWeight(self, items, container, ...)
    end
end

local function installAutoDropTracing()
    local function wrapAttempt(name, eventName)
        local old = GridAutoDropSystem[name]
        if not old then return end
        GridAutoDropSystem[name] = function(item, ...)
            local traceId = findRememberedTrace(item)
            local startedAt = nowMs()
            local result = old(item, ...)
            if traceId then
                emit(traceId, eventName, {
                    item = itemType(item),
                    itemId = itemId(item),
                    result = bool(result),
                    elapsedMs = nowMs() - startedAt,
                    container = describeContainer(item and item:getContainer(), getSpecificPlayer(0)),
                })
            end
            return result
        end
    end

    wrapAttempt("_handleDropItem", "tetris-auto-drop-to-floor")
    wrapAttempt("_attemptToForcePositionItem", "tetris-recovery-position")
    wrapAttempt("_attemptToForceEquipItem", "tetris-recovery-equip")
end

function Diagnostics.install()
    if installed then return end
    installed = true
    installTransferTracing()
    installQueueTracing()
    installEquipTracing()
    installKeyRingUiTracing()
    installAutoDropTracing()
    emit("SESSION", "installed", {
        version = "0.1.0",
        enabled = bool(InventoryTetrisTransferDiagnostics.enabled),
        maxLines = MAX_LINES,
    })
end

return Diagnostics
