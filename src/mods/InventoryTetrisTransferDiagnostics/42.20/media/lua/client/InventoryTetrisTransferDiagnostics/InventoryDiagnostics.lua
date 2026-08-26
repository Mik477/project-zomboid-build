local Core = require("InventoryTetrisTransferDiagnostics/InventoryDiagnosticsCore")
local KeyRingSupport = require("InventoryTetris/KeyRingSupport")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")

require("TimedActions/ISInventoryTransferAction")
require("TimedActions/ISTimedActionQueue")
require("TimedActions/ISEquipWeaponAction")
require("TimedActions/ISWearClothing")
require("TimedActions/ISInsertMagazine")
require("TimedActions/ISEjectMagazine")
require("TimedActions/ISLoadBulletsInMagazine")

local Diagnostics = {}
local PREFIX = "ITTransferDiag"
local VERSION = "0.3.1"
local MAX_LINES = 2500
local MAX_LIVE_TRACES = 64
local MAX_QUEUE_TYPES = 12
local TRACE_TTL_MS = 45000
local MISSING_NATIVE_MILESTONES = { 0, 250, 1000, 5000, 15000, 30000, 45000 }

local installed = false
local observerFailed = false
local traceCounter = 0
local lineCount = 0
local liveCount = 0
local traceCapReported = false
local actionTraces = {}
local recoveryTraces = {}
local retiredActions = {}
local retiredRecoveryItems = {}

InventoryTetrisTransferDiagnostics = InventoryTetrisTransferDiagnostics or {}
if InventoryTetrisTransferDiagnostics.enabled == nil then
    InventoryTetrisTransferDiagnostics.enabled = true
end

local function safeCall(callback, fallback)
    local ok, value = pcall(callback)
    if ok then return value end
    return fallback
end

local function nowMs()
    return safeCall(function() return getTimestampMs() end, 0)
end

local function emit(traceId, eventName, actionType, fields)
    if not InventoryTetrisTransferDiagnostics.enabled or lineCount >= MAX_LINES then return end
    lineCount = lineCount + 1
    pcall(function()
        local safeFields = fields or {}
        local line = Core.format(PREFIX, traceId or "SESSION", eventName, safeFields)
        pcall(function() print(line) end)

        local bridge = PZPerfDiagnostics_actionEvent
        if type(bridge) == "function" then
            local details = Core.details(safeFields)
            pcall(bridge, traceId or "SESSION", eventName, actionType or "observer", details)
        end
    end)
end

local function newTraceId()
    traceCounter = traceCounter + 1
    return "I" .. tostring(traceCounter)
end

local function reserveTrace()
    if liveCount >= MAX_LIVE_TRACES then
        if not traceCapReported then
            traceCapReported = true
            emit("SESSION", "trace-cap-reached", "observer", { maxLiveTraces = MAX_LIVE_TRACES })
        end
        return nil
    end
    liveCount = liveCount + 1
    if liveCount < MAX_LIVE_TRACES then traceCapReported = false end
    return newTraceId()
end

local function releaseTrace()
    liveCount = math.max(0, liveCount - 1)
    if liveCount < MAX_LIVE_TRACES then traceCapReported = false end
end

local function itemFullType(item)
    if not item then return "nil" end
    return safeCall(function() return item:getFullType() end, "unknown")
end

local function itemRuntimeId(item)
    if not item then return "nil" end
    return safeCall(function() return item:getID() end, "unknown")
end

local function isLocalCharacter(character)
    if not character then return false end
    return safeCall(function()
        return instanceof(character, "IsoPlayer") and character:isLocalPlayer()
    end, false)
end

local function isKeyRing(container)
    return safeCall(function() return KeyRingSupport.isContainer(container) end, false)
end

local function containerKind(container, character)
    if not container then return "nil" end
    local playerInventory = character and safeCall(function() return character:getInventory() end, nil) or nil
    if container == playerInventory then return "player-main" end
    local onPlayer = character and safeCall(function() return container:isInCharacterInventory(character) end, false) or false
    if isKeyRing(container) then return onPlayer and "player-keyring" or "external-keyring" end
    if onPlayer then return "player-contained" end
    local kind = safeCall(function() return container:getType() end, "unknown")
    return "external:" .. tostring(kind)
end

local function contains(container, item)
    if not container or not item then return nil end
    return safeCall(function() return container:contains(item) end, nil)
end

local function itemContainer(item)
    if not item then return nil end
    return safeCall(function() return item:getContainer() end, nil)
end

local function itemEquipped(item)
    if not item then return nil end
    return safeCall(function() return item:isEquipped() end, nil)
end

local function itemContainsClip(item)
    if not item or not instanceof(item, "HandWeapon") then return nil end
    return safeCall(function() return item:isContainsClip() end, nil)
end

local function itemCurrentAmmo(item)
    if not item then return nil end
    return safeCall(function() return item:getCurrentAmmoCount() end, nil)
end

local function inventoryState(character, item)
    local inventory = character and safeCall(function() return character:getInventory() end, nil) or nil
    local playerNum = character and safeCall(function() return character:getPlayerNum() end, -1) or -1
    local candidates = ItemContainerGrid._unpositionedItemSetsByPlayer
        and ItemContainerGrid._unpositionedItemSetsByPlayer[playerNum] or nil
    return {
        weight = inventory and safeCall(function() return inventory:getCapacityWeight() end, nil) or nil,
        effectiveCapacity = inventory and safeCall(function() return inventory:getEffectiveCapacity(character) end, nil) or nil,
        maxWeight = inventory and safeCall(function() return inventory:getMaxWeight() end, nil) or nil,
        overflowCandidate = candidates and candidates[item] ~= nil or false,
    }
end

local function nativeActionState(action, character)
    if not action or action.action == nil then return "missing" end
    local actions = character and safeCall(function() return character:getCharacterActions() end, nil) or nil
    if not actions then return "present" end
    local registered = safeCall(function() return actions:contains(action.action) end, nil)
    if registered == nil then return "present" end
    return registered and "registered" or "unregistered"
end

local function buildQueueContext(queue)
    local types = {}
    local positions = {}
    local actions = queue and queue.queue or {}
    for index, queuedAction in ipairs(actions) do
        types[#types + 1] = queuedAction and queuedAction.Type or "unknown"
        positions[queuedAction] = index
    end
    local queueTypes, queueTypesOmitted = Core.summarizeQueueTypes(types, MAX_QUEUE_TYPES)
    return {
        depth = #actions,
        positions = positions,
        queueTypes = queueTypes,
        queueTypesOmitted = queueTypesOmitted,
    }
end

local function handMatch(character, getterName, item)
    if not character or not item then return false end
    return safeCall(function() return character[getterName](character) == item end, false)
end

local function actionSnapshot(action, queue, queueContext, character)
    local item = action and (action.item or action.gun or action.magazine) or nil
    local secondaryItem = action and action.gun and action.magazine or nil
    local source = action and action.srcContainer or nil
    local destination = action and action.destContainer or nil
    local currentContainer = itemContainer(item)
    local inventory = inventoryState(character, item)
    return {
        item = item,
        sourceContainer = source,
        destinationContainer = destination,
        itemFullType = itemFullType(item),
        itemRuntimeId = itemRuntimeId(item),
        secondaryItemFullType = itemFullType(secondaryItem),
        secondaryItemRuntimeId = itemRuntimeId(secondaryItem),
        secondaryItemContainer = containerKind(itemContainer(secondaryItem), character),
        itemContainer = containerKind(currentContainer, character),
        queuePosition = queueContext.positions[action] or 0,
        queueDepth = queueContext.depth,
        queueTypes = queueContext.queueTypes,
        queueTypesOmitted = queueContext.queueTypesOmitted,
        current = queue and queue.current == action or false,
        nativeAction = nativeActionState(action, character),
        started = Core.state(action and action.started),
        maxTime = action and action.maxTime or "nil",
        transaction = Core.transactionState(action and action.transactionId),
        source = containerKind(source, character),
        destination = containerKind(destination, character),
        sourceContains = contains(source, item),
        destinationContains = contains(destination, item),
        sourceKeyRing = isKeyRing(source),
        destinationKeyRing = isKeyRing(destination),
        primaryMatch = handMatch(character, "getPrimaryHandItem", item),
        secondaryMatch = handMatch(character, "getSecondaryHandItem", item),
        itemEquipped = itemEquipped(item),
        containsClip = itemContainsClip(item),
        currentAmmo = itemCurrentAmmo(item),
        inventoryWeight = inventory.weight,
        inventoryEffectiveCapacity = inventory.effectiveCapacity,
        inventoryMaxWeight = inventory.maxWeight,
        overflowCandidate = inventory.overflowCandidate,
    }
end

local function identityFields(snapshot)
    return {
        item = snapshot.itemFullType,
        itemId = snapshot.itemRuntimeId,
        itemContainer = snapshot.itemContainer,
    }
end

local function queueFields(snapshot)
    return {
        current = Core.state(snapshot.current),
        nativeAction = snapshot.nativeAction,
        queueDepth = snapshot.queueDepth,
        queuePosition = snapshot.queuePosition,
        queueTypes = snapshot.queueTypes,
        queueTypesOmitted = snapshot.queueTypesOmitted,
    }
end

local function observeMissingNative(trace, snapshot, now)
    if not snapshot.current or snapshot.nativeAction ~= "missing" then
        trace.missingSince = nil
        trace.missingMilestone = nil
        return
    end
    if trace.missingSince == nil then
        trace.missingSince = now
        trace.missingMilestone = 1
    end
    local elapsed = math.max(0, now - trace.missingSince)
    while trace.missingMilestone <= #MISSING_NATIVE_MILESTONES
            and elapsed >= MISSING_NATIVE_MILESTONES[trace.missingMilestone] do
        local milestone = MISSING_NATIVE_MILESTONES[trace.missingMilestone]
        emit(trace.id, "missing-native-action-stall", trace.actionType, {
            action = trace.actionType,
            milestoneMs = milestone,
            observedMs = elapsed,
            queueDepth = snapshot.queueDepth,
            queuePosition = snapshot.queuePosition,
            queueTypes = snapshot.queueTypes,
            queueTypesOmitted = snapshot.queueTypesOmitted,
        })
        trace.missingMilestone = trace.missingMilestone + 1
    end
end

local function emitActionTransitions(trace, before, after, now)
    if before.current ~= after.current then
        emit(trace.id, "current-changed", trace.actionType, {
            action = trace.actionType, before = Core.state(before.current), after = Core.state(after.current),
        })
    end
    if before.nativeAction ~= after.nativeAction then
        emit(trace.id, "native-action-changed", trace.actionType, {
            action = trace.actionType, before = before.nativeAction, after = after.nativeAction,
        })
    end
    if before.started ~= after.started then
        emit(trace.id, "started-changed", trace.actionType, {
            action = trace.actionType, before = before.started, after = after.started,
        })
    end
    if before.maxTime ~= after.maxTime then
        emit(trace.id, "max-time-changed", trace.actionType, {
            action = trace.actionType, before = before.maxTime, after = after.maxTime,
        })
    end
    if before.transaction ~= after.transaction then
        emit(trace.id, "transaction-changed", trace.actionType, {
            action = trace.actionType, before = before.transaction, after = after.transaction,
        })
    end
    if before.sourceContains ~= after.sourceContains or before.destinationContains ~= after.destinationContains then
        emit(trace.id, "container-membership-changed", trace.actionType, {
            action = trace.actionType,
            sourceBefore = Core.state(before.sourceContains),
            sourceAfter = Core.state(after.sourceContains),
            destinationBefore = Core.state(before.destinationContains),
            destinationAfter = Core.state(after.destinationContains),
        })
    end
    if before.item ~= after.item then
        local fields = identityFields(after)
        fields.action = trace.actionType
        emit(trace.id, "item-changed", trace.actionType, fields)
    elseif before.itemContainer ~= after.itemContainer then
        emit(trace.id, "item-container-changed", trace.actionType, {
            action = trace.actionType, before = before.itemContainer, after = after.itemContainer,
        })
    end
    if before.queuePosition ~= after.queuePosition or before.queueDepth ~= after.queueDepth
            or before.queueTypes ~= after.queueTypes or before.queueTypesOmitted ~= after.queueTypesOmitted then
        local fields = queueFields(after)
        fields.action = trace.actionType
        emit(trace.id, "queue-changed", trace.actionType, fields)
    end
    if before.primaryMatch ~= after.primaryMatch or before.secondaryMatch ~= after.secondaryMatch then
        emit(trace.id, "hand-membership-changed", trace.actionType, {
            action = trace.actionType,
            primary = Core.state(after.primaryMatch),
            secondary = Core.state(after.secondaryMatch),
        })
    end
    if before.itemEquipped ~= after.itemEquipped then
        emit(trace.id, "worn-state-changed", trace.actionType, {
            action = trace.actionType,
            equipped = Core.state(after.itemEquipped),
        })
    end
    if before.containsClip ~= after.containsClip or before.currentAmmo ~= after.currentAmmo then
        emit(trace.id, "magazine-state-changed", trace.actionType, {
            action = trace.actionType,
            containsClip = Core.state(after.containsClip),
            currentAmmo = after.currentAmmo or "nil",
        })
    end
    if before.secondaryItemContainer ~= after.secondaryItemContainer then
        emit(trace.id, "magazine-container-changed", trace.actionType, {
            action = trace.actionType,
            magazine = after.secondaryItemFullType,
            magazineId = after.secondaryItemRuntimeId,
            before = before.secondaryItemContainer,
            after = after.secondaryItemContainer,
        })
    end
    if before.inventoryWeight ~= after.inventoryWeight
            or before.inventoryEffectiveCapacity ~= after.inventoryEffectiveCapacity
            or before.overflowCandidate ~= after.overflowCandidate then
        emit(trace.id, "inventory-capacity-state-changed", trace.actionType, {
            action = trace.actionType,
            inventoryWeight = after.inventoryWeight or "nil",
            inventoryEffectiveCapacity = after.inventoryEffectiveCapacity or "nil",
            inventoryMaxWeight = after.inventoryMaxWeight or "nil",
            overflowCandidate = Core.state(after.overflowCandidate),
        })
    end
    observeMissingNative(trace, after, now)
end

local function hasStartEvidence(action, snapshot)
    return snapshot.started == "true"
        or snapshot.nativeAction == "registered"
        or (action and action.action ~= nil)
end

local function observeAction(action, queue, queueContext, character, observed, now)
    observed[action] = true
    if retiredActions[action] then return end
    local actionType = action and action.Type or nil
    if not Core.isObservedActionType(actionType) then return end

    local trace = actionTraces[action]
    if not trace then
        local traceId = reserveTrace()
        if not traceId then return end
        local snapshot = actionSnapshot(action, queue, queueContext, character)
        trace = {
            id = traceId,
            actionType = actionType,
            firstObservedAt = now,
            snapshot = snapshot,
            character = character,
            everStarted = hasStartEvidence(action, snapshot),
        }
        actionTraces[action] = trace
        local fields = identityFields(snapshot)
        fields.action = actionType
        fields.source = snapshot.source
        fields.destination = snapshot.destination
        fields.sourceContains = Core.state(snapshot.sourceContains)
        fields.destinationContains = Core.state(snapshot.destinationContains)
        fields.sourceKeyRing = Core.state(snapshot.sourceKeyRing)
        fields.destinationKeyRing = Core.state(snapshot.destinationKeyRing)
        fields.started = snapshot.started
        fields.maxTime = snapshot.maxTime
        fields.transaction = snapshot.transaction
        fields.magazine = snapshot.secondaryItemFullType
        fields.magazineId = snapshot.secondaryItemRuntimeId
        fields.magazineContainer = snapshot.secondaryItemContainer
        fields.itemEquipped = Core.state(snapshot.itemEquipped)
        fields.containsClip = Core.state(snapshot.containsClip)
        fields.currentAmmo = snapshot.currentAmmo or "nil"
        fields.inventoryWeight = snapshot.inventoryWeight or "nil"
        fields.inventoryEffectiveCapacity = snapshot.inventoryEffectiveCapacity or "nil"
        fields.inventoryMaxWeight = snapshot.inventoryMaxWeight or "nil"
        fields.overflowCandidate = Core.state(snapshot.overflowCandidate)
        local queued = queueFields(snapshot)
        for key, value in pairs(queued) do fields[key] = value end
        emit(trace.id, "action-first-observed", actionType, fields)
        observeMissingNative(trace, snapshot, now)
        return
    end

    local snapshot = actionSnapshot(action, queue, queueContext, character)
    emitActionTransitions(trace, trace.snapshot, snapshot, now)
    trace.everStarted = trace.everStarted or hasStartEvidence(action, snapshot)
    trace.snapshot = snapshot
    if now - trace.firstObservedAt >= TRACE_TTL_MS then
        emit(trace.id, "action-trace-timeout", trace.actionType, {
            action = trace.actionType,
            ageMs = now - trace.firstObservedAt,
            current = Core.state(snapshot.current),
            nativeAction = snapshot.nativeAction,
        })
        actionTraces[action] = nil
        retiredActions[action] = true
        releaseTrace()
    end
end

local function finalActionOutcome(trace)
    local snapshot = trace.snapshot
    if trace.actionType == "ISInventoryTransferAction" then
        return Core.transferOutcome(snapshot.sourceContains, snapshot.destinationContains, snapshot.transaction)
    end
    local itemContained = itemContainer(snapshot.item) ~= nil
    if trace.actionType == "ISEquipWeaponAction" then
        return Core.equipOutcome(snapshot.primaryMatch, snapshot.secondaryMatch, itemContained)
    end
    if trace.actionType == "ISWearClothing" then
        return Core.wearOutcome(snapshot.itemEquipped, itemContained)
    end
    return Core.magazineOutcome(trace.actionType, snapshot.containsClip, snapshot.primaryMatch)
end

local function finishRemovedActions(observed, now)
    for action, trace in pairs(actionTraces) do
        if not observed[action] then
            local snapshot = trace.snapshot
            trace.everStarted = trace.everStarted
                or action.started == true
                or action.action ~= nil
                or nativeActionState(action, trace.character) == "registered"
            snapshot.itemContainer = containerKind(itemContainer(snapshot.item), trace.character)
            snapshot.sourceContains = contains(snapshot.sourceContainer, snapshot.item)
            snapshot.destinationContains = contains(snapshot.destinationContainer, snapshot.item)
            snapshot.primaryMatch = handMatch(trace.character, "getPrimaryHandItem", snapshot.item)
            snapshot.secondaryMatch = handMatch(trace.character, "getSecondaryHandItem", snapshot.item)
            snapshot.itemEquipped = itemEquipped(snapshot.item)
            snapshot.containsClip = itemContainsClip(snapshot.item)
            snapshot.currentAmmo = itemCurrentAmmo(snapshot.item)
            snapshot.secondaryItemContainer = containerKind(itemContainer(action and action.magazine), trace.character)
            snapshot.transaction = Core.transactionState(action and action.transactionId)
            local inventory = inventoryState(trace.character, snapshot.item)
            snapshot.inventoryWeight = inventory.weight
            snapshot.inventoryEffectiveCapacity = inventory.effectiveCapacity
            snapshot.inventoryMaxWeight = inventory.maxWeight
            snapshot.overflowCandidate = inventory.overflowCandidate
            emit(trace.id, "action-removed", trace.actionType, {
                action = trace.actionType,
                ageMs = now - trace.firstObservedAt,
                outcome = finalActionOutcome(trace),
                sourceContains = Core.state(snapshot.sourceContains),
                destinationContains = Core.state(snapshot.destinationContains),
                primary = Core.state(snapshot.primaryMatch),
                secondary = Core.state(snapshot.secondaryMatch),
                transaction = snapshot.transaction,
                itemEquipped = Core.state(snapshot.itemEquipped),
                containsClip = Core.state(snapshot.containsClip),
                currentAmmo = snapshot.currentAmmo or "nil",
                magazineContainer = snapshot.secondaryItemContainer,
                everStarted = Core.state(trace.everStarted),
                inventoryWeight = snapshot.inventoryWeight or "nil",
                inventoryEffectiveCapacity = snapshot.inventoryEffectiveCapacity or "nil",
                inventoryMaxWeight = snapshot.inventoryMaxWeight or "nil",
                overflowCandidate = Core.state(snapshot.overflowCandidate),
            })
            actionTraces[action] = nil
            releaseTrace()
        end
    end
    for action, _ in pairs(retiredActions) do
        if not observed[action] then retiredActions[action] = nil end
    end
end

local function recoverySnapshot(item, candidate, character)
    local source = type(candidate) == "table" and candidate.sourceContainer or nil
    local current = itemContainer(item)
    return {
        item = item,
        itemFullType = itemFullType(item),
        itemRuntimeId = itemRuntimeId(item),
        sourceContainer = source,
        source = containerKind(source, character),
        currentContainer = current,
        current = containerKind(current, character),
        sourceContains = contains(source, item),
        currentContains = contains(current, item),
        sourceKeyRing = isKeyRing(source),
        currentKeyRing = isKeyRing(current),
    }
end

local function observeRecovery(item, candidate, character, observed, now)
    observed[item] = true
    if retiredRecoveryItems[item] then return end
    local snapshot = recoverySnapshot(item, candidate, character)
    local trace = recoveryTraces[item]
    if not trace then
        local traceId = reserveTrace()
        if not traceId then return end
        trace = { id = traceId, firstObservedAt = now, phase = "candidate", snapshot = snapshot }
        recoveryTraces[item] = trace
        emit(trace.id, "recovery-candidate", "InventoryTetrisRecovery", {
            item = snapshot.itemFullType,
            itemId = snapshot.itemRuntimeId,
            source = snapshot.source,
            current = snapshot.current,
            sourceContains = Core.state(snapshot.sourceContains),
            currentContains = Core.state(snapshot.currentContains),
            sourceKeyRing = Core.state(snapshot.sourceKeyRing),
            currentKeyRing = Core.state(snapshot.currentKeyRing),
        })
        return
    end

    local before = trace.snapshot
    if before.sourceContains ~= snapshot.sourceContains or before.currentContains ~= snapshot.currentContains
            or before.current ~= snapshot.current or before.sourceKeyRing ~= snapshot.sourceKeyRing
            or before.currentKeyRing ~= snapshot.currentKeyRing then
        emit(trace.id, "recovery-state-changed", "InventoryTetrisRecovery", {
            item = snapshot.itemFullType,
            itemId = snapshot.itemRuntimeId,
            source = snapshot.source,
            current = snapshot.current,
            sourceContains = Core.state(snapshot.sourceContains),
            currentContains = Core.state(snapshot.currentContains),
            sourceKeyRing = Core.state(snapshot.sourceKeyRing),
            currentKeyRing = Core.state(snapshot.currentKeyRing),
        })
    end
    trace.snapshot = snapshot

    local elapsed = now - trace.firstObservedAt
    local phase = Core.recoveryPhase(elapsed)
    if phase ~= trace.phase then
        trace.phase = phase
        if phase == "remains" then
            emit(trace.id, "recovery-remains", "InventoryTetrisRecovery", {
                item = snapshot.itemFullType, itemId = snapshot.itemRuntimeId, ageMs = elapsed,
                source = snapshot.source, current = snapshot.current,
            })
        elseif phase == "timeout" then
            emit(trace.id, "recovery-timeout", "InventoryTetrisRecovery", {
                item = snapshot.itemFullType, itemId = snapshot.itemRuntimeId, ageMs = elapsed,
                source = snapshot.source, current = snapshot.current,
            })
            recoveryTraces[item] = nil
            retiredRecoveryItems[item] = true
            releaseTrace()
        end
    end
end

local function recoveryOutcome(trace, character)
    local snapshot = recoverySnapshot(trace.snapshot.item, { sourceContainer = trace.snapshot.sourceContainer }, character)
    if snapshot.currentKeyRing then return "keyring-protected", snapshot end
    if snapshot.currentContainer and snapshot.currentContainer ~= snapshot.sourceContainer then return "moved", snapshot end
    if snapshot.sourceContains == true then return "repositioned-or-protected", snapshot end
    if not snapshot.currentContainer then return "detached", snapshot end
    return "absent-from-source", snapshot
end

local function finishRemovedRecovery(observed, charactersByPlayer, now)
    for item, trace in pairs(recoveryTraces) do
        if not observed[item] then
            local character = charactersByPlayer[trace.playerNum or -1]
            local outcome, snapshot = recoveryOutcome(trace, character)
            emit(trace.id, "recovery-resolved", "InventoryTetrisRecovery", {
                item = snapshot.itemFullType,
                itemId = snapshot.itemRuntimeId,
                ageMs = now - trace.firstObservedAt,
                outcome = outcome,
                source = snapshot.source,
                current = snapshot.current,
            })
            recoveryTraces[item] = nil
            releaseTrace()
        end
    end
    for item, _ in pairs(retiredRecoveryItems) do
        if not observed[item] then retiredRecoveryItems[item] = nil end
    end
end

local function localQueues()
    local values = {}
    for _, queue in pairs(ISTimedActionQueue.queues or {}) do
        local character = queue and queue.character or nil
        if isLocalCharacter(character) then
            values[#values + 1] = {
                queue = queue,
                character = character,
                playerNum = safeCall(function() return character:getPlayerNum() end, -1),
            }
        end
    end
    table.sort(values, function(left, right) return left.playerNum < right.playerNum end)
    return values
end

local function observeTick()
    local now = nowMs()
    local observedActions = {}
    local observedRecovery = {}
    local charactersByPlayer = {}
    local queues = localQueues()

    for _, value in ipairs(queues) do
        local queue = value.queue
        local queueContext = buildQueueContext(queue)
        charactersByPlayer[value.playerNum] = value.character
        for _, action in ipairs(queue.queue or {}) do
            observeAction(action, queue, queueContext, value.character, observedActions, now)
        end
        if queue.current and not observedActions[queue.current] then
            observeAction(queue.current, queue, queueContext, value.character, observedActions, now)
        end
    end
    finishRemovedActions(observedActions, now)

    for playerNum, itemSet in pairs(ItemContainerGrid._unpositionedItemSetsByPlayer or {}) do
        local character = charactersByPlayer[playerNum]
        if not character then
            character = safeCall(function() return getSpecificPlayer(playerNum) end, nil)
            if not isLocalCharacter(character) then character = nil end
            if character then charactersByPlayer[playerNum] = character end
        end
        if character and type(itemSet) == "table" then
            for item, candidate in pairs(itemSet) do
                observeRecovery(item, candidate, character, observedRecovery, now)
                local trace = recoveryTraces[item]
                if trace then trace.playerNum = playerNum end
            end
        end
    end
    finishRemovedRecovery(observedRecovery, charactersByPlayer, now)
end

local function onTick()
    local ok = pcall(observeTick)
    if not ok and not observerFailed then
        observerFailed = true
        emit("SESSION", "observer-error", "observer", { status = "disabled-until-next-tick" })
    elseif ok then
        observerFailed = false
    end
end

function Diagnostics.install()
    if installed then return end
    installed = true
    Events.OnTick.Add(onTick)
    ITTransferDiag_mark = function(label)
        emit("MARK", "explicit-marker", "marker", { label = label })
    end
    emit("SESSION", "installed", "observer", {
        version = VERSION,
        mode = "observer-only",
        maxLines = MAX_LINES,
        maxLiveTraces = MAX_LIVE_TRACES,
        queueTypeLimit = MAX_QUEUE_TYPES,
        traceTtlMs = TRACE_TTL_MS,
    })
end

return Diagnostics
