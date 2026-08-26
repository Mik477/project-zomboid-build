require "TimedActions/ISTimedActionQueue"

local MAX_EVENTS_PER_ATTEMPT = 32
local ATTEMPT_TTL_MS = 45000
local STALL_THRESHOLDS_MS = { 2000, 5000, 15000 }
local MAX_QUEUE_ACTIONS = 10

local sequence = 0
local actionSequence = 0
local actionIds = setmetatable({}, { __mode = "k" })
local attemptsByCharacter = setmetatable({}, { __mode = "k" })
local activeAttempts = {}

local function safeCall(object, methodName, fallback, ...)
    if not object then return fallback end
    local method = object[methodName]
    if type(method) ~= "function" then return fallback end
    local ok, value = pcall(method, object, ...)
    if not ok or value == nil then return fallback end
    return value
end

local function actionType(action)
    if not action or type(action.Type) ~= "string" then return "unknown" end
    return action.Type
end

local function isLocalPlayer(character)
    return character
        and instanceof(character, "IsoPlayer")
        and safeCall(character, "isLocalPlayer", false)
end

local function actionId(action)
    if not action then return 0 end
    local id = actionIds[action]
    if id then return id end
    actionSequence = actionSequence + 1
    actionIds[action] = actionSequence
    return actionSequence
end

local function queueActions(queue)
    if not queue or type(queue.queue) ~= "table" then return nil end
    return queue.queue
end

local function findVehicleAction(character, actions)
    if not actions then return nil end
    for _, candidate in ipairs(actions) do
        local kind = actionType(candidate)
        if kind == "ISPathFindAction" then
            local goal = candidate.goal
            if type(goal) == "table" and goal[1] == "VehicleSeat" and goal[2] then
                return "entry", candidate, goal[2], tonumber(goal[3]) or -1
            end
        elseif kind == "ISEnterVehicle" then
            return "entry", candidate, candidate.vehicle, tonumber(candidate.seat) or -1
        elseif kind == "ISExitVehicle" then
            local vehicle = candidate.vehicle or safeCall(character, "getVehicle", nil)
            local seat = tonumber(candidate.seat)
                or tonumber(safeCall(vehicle, "getSeat", -1, character))
                or -1
            return "exit", candidate, vehicle, seat
        end
    end
    return nil
end

local function queueShape(actions)
    if not actions then return "unavailable", -1 end
    local names = {}
    local depth = #actions
    local count = math.min(depth, MAX_QUEUE_ACTIONS)
    for index = 1, count do
        names[#names + 1] = actionType(actions[index])
    end
    if depth > MAX_QUEUE_ACTIONS then
        names[#names + 1] = "+" .. tostring(depth - MAX_QUEUE_ACTIONS)
    end
    return table.concat(names, ">"), depth
end

local function findDoorPart(actions, vehicle, seat)
    if actions then
        for _, candidate in ipairs(actions) do
            if candidate.part then return candidate.part end
        end
    end
    return safeCall(vehicle, "getPassengerDoor", nil, seat)
end

local function animationVariable(character, name)
    return tostring(safeCall(character, "GetVariable", "unavailable", name))
end

local function snapshot(character, queue, vehicle, seat)
    local actions = queueActions(queue)
    local current = actions and actions[1] or nil
    local shape, depth = queueShape(actions)
    local part = findDoorPart(actions, vehicle, seat)
    local door = safeCall(part, "getDoor", nil)
    local occupant = seat >= 0 and safeCall(vehicle, "getCharacter", nil, seat) or nil
    local seatState = occupant == character and "character"
        or (occupant and "occupied" or "empty")
    local fields = {
        "queueDepth=" .. tostring(depth),
        "queueShape=" .. shape,
        "current=" .. actionType(current),
        "currentRef=" .. tostring(actionId(current)),
        "nativeAction=" .. tostring(current ~= nil and current.action ~= nil),
        "started=" .. tostring(current and current.started or false),
        "seat=" .. tostring(seat),
        "bEnteringVehicle=" .. animationVariable(character, "bEnteringVehicle"),
        "enterAnimationFinished=" .. animationVariable(character, "EnterAnimationFinished"),
        "bExitingVehicle=" .. animationVariable(character, "bExitingVehicle"),
        "exitAnimationFinished=" .. animationVariable(character, "ExitAnimationFinished"),
        "characterInVehicle=" .. tostring(safeCall(character, "getVehicle", nil) == vehicle),
        "seatState=" .. seatState,
        "doorPart=" .. tostring(safeCall(part, "getId", "none")),
        "doorPresent=" .. tostring(door ~= nil),
        "doorOpen=" .. tostring(safeCall(door, "isOpen", "unavailable")),
        "doorLocked=" .. tostring(safeCall(door, "isLocked", "unavailable")),
    }
    return table.concat(fields, ";"), table.concat(fields, "|"), actionType(current)
end

local function emit(attempt, stage, action, details)
    if attempt.eventCount >= MAX_EVENTS_PER_ATTEMPT then return end
    if type(PZPerfDiagnostics_vehicleEvent) ~= "function" then return end
    attempt.eventCount = attempt.eventCount + 1
    pcall(
        PZPerfDiagnostics_vehicleEvent,
        attempt.id,
        stage,
        attempt.character,
        attempt.vehicle,
        attempt.seat,
        action,
        details)
end

local function release(attempt)
    if attemptsByCharacter[attempt.character] == attempt then
        attemptsByCharacter[attempt.character] = nil
    end
    activeAttempts[attempt.id] = nil
end

local function createAttempt(character, mode, vehicle, seat, now)
    sequence = sequence + 1
    local attempt = {
        id = "vehicle-queue-" .. tostring(now) .. "-" .. tostring(sequence),
        character = character,
        mode = mode,
        vehicle = vehicle,
        seat = seat,
        startedAt = now,
        transitionAt = now,
        stallIndex = 1,
        eventCount = 0,
        queueAbsent = false,
    }
    attemptsByCharacter[character] = attempt
    activeAttempts[attempt.id] = attempt
    return attempt
end

local function observeQueue(character, queue, now)
    local actions = queueActions(queue)
    local mode, _, vehicle, seat = findVehicleAction(character, actions)
    local attempt = attemptsByCharacter[character]

    if mode and (not attempt
            or attempt.queueAbsent
            or attempt.mode ~= mode
            or attempt.vehicle ~= vehicle) then
        if attempt then release(attempt) end
        attempt = createAttempt(character, mode, vehicle, seat, now)
    end
    if not attempt then return end

    if mode then
        attempt.vehicle = vehicle
        attempt.seat = seat
        attempt.queueAbsent = false
    else
        attempt.queueAbsent = true
    end

    local details, stateKey, current = snapshot(
        character, queue, attempt.vehicle, attempt.seat)
    if stateKey ~= attempt.stateKey then
        attempt.stateKey = stateKey
        attempt.transitionAt = now
        attempt.stallIndex = 1
        emit(attempt, attempt.eventCount == 0 and "queue-detected" or "queue-transition",
            current, "mode=" .. attempt.mode .. ";" .. details)
    elseif not attempt.queueAbsent then
        while attempt.stallIndex <= #STALL_THRESHOLDS_MS
                and now - attempt.transitionAt >= STALL_THRESHOLDS_MS[attempt.stallIndex] do
            local threshold = STALL_THRESHOLDS_MS[attempt.stallIndex]
            attempt.stallIndex = attempt.stallIndex + 1
            emit(attempt, "stall-" .. tostring(threshold / 1000) .. "s", current,
                "unchangedMs=" .. tostring(now - attempt.transitionAt) .. ";" .. details)
        end
    end
end

local function completeAttempt(character, mode, stage)
    local attempt = attemptsByCharacter[character]
    if not attempt or attempt.mode ~= mode then return end
    local queue = ISTimedActionQueue.queues and ISTimedActionQueue.queues[character] or nil
    local details, _, current = snapshot(character, queue, attempt.vehicle, attempt.seat)
    emit(attempt, stage, current, "mode=" .. mode .. ";" .. details)
    release(attempt)
end

local function onEnterVehicle(character)
    completeAttempt(character, "entry", "entered")
end

local function onExitVehicle(character)
    completeAttempt(character, "exit", "exited")
end

local function onTick()
    local now = getTimestampMs()
    local queues = ISTimedActionQueue.queues
    local seenCharacters = {}
    if type(queues) == "table" then
        for character, queue in pairs(queues) do
            if isLocalPlayer(character) then
                seenCharacters[character] = true
                observeQueue(character, queue, now)
            end
        end
    end

    local attempts = {}
    for _, attempt in pairs(activeAttempts) do
        attempts[#attempts + 1] = attempt
    end
    for _, attempt in ipairs(attempts) do
        if not seenCharacters[attempt.character] then
            observeQueue(attempt.character, nil, now)
        end
        if now - attempt.startedAt >= ATTEMPT_TTL_MS then
            emit(attempt, "ttl-expired", "none",
                "mode=" .. attempt.mode .. ";ttlMs=" .. tostring(ATTEMPT_TTL_MS))
            release(attempt)
        end
    end
end

Events.OnTick.Add(onTick)
Events.OnEnterVehicle.Add(onEnterVehicle)
Events.OnExitVehicle.Add(onExitVehicle)

PZPerformanceDiagnosticsVehicleQueueObserverOnly = true
