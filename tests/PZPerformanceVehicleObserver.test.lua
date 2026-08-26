local repositoryRoot = PZPerformanceDiagnosticsRepositoryRoot or "."
package.path = table.concat({
    repositoryRoot .. "/src/mods/PZPerformanceDiagnostics/42.20/media/lua/client/?.lua",
    repositoryRoot .. "/src/mods/PZPerformanceDiagnostics/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local clock = 1000
getTimestampMs = function() return clock end
instanceof = function(value, className)
    return value and value.className == className or false
end

local handlers = { tick = {}, enter = {}, exit = {} }
Events = {
    OnTick = { Add = function(callback) handlers.tick[#handlers.tick + 1] = callback end },
    OnEnterVehicle = { Add = function(callback) handlers.enter[#handlers.enter + 1] = callback end },
    OnExitVehicle = { Add = function(callback) handlers.exit[#handlers.exit + 1] = callback end },
}

ISTimedActionQueue = { queues = {} }
package.preload["TimedActions/ISTimedActionQueue"] = function() return ISTimedActionQueue end

local events = {}
PZPerfDiagnostics_vehicleEvent = function(attempt, stage, character, vehicle, seat, action, details)
    events[#events + 1] = {
        attempt = attempt,
        stage = stage,
        character = character,
        vehicle = vehicle,
        seat = seat,
        action = action,
        details = details,
    }
end

local door = {}
function door:isOpen() return false end
function door:isLocked() return false end
local part = {}
function part:getDoor() return door end
function part:getId() return "DoorFrontLeft" end
local vehicle = { occupant = nil }
function vehicle:getPassengerDoor() return part end
function vehicle:getCharacter() return self.occupant end
function vehicle:getSeat(character) return character == self.occupant and 0 or -1 end

local player = {
    className = "IsoPlayer",
    variables = {},
    vehicle = nil,
}
function player:isLocalPlayer() return true end
function player:GetVariable(name) return self.variables[name] end
function player:getVehicle() return self.vehicle end

local remotePlayer = { className = "IsoPlayer" }
function remotePlayer:isLocalPlayer() return false end
function remotePlayer:GetVariable() return nil end
function remotePlayer:getVehicle() return nil end

local function tick(delta)
    clock = clock + (delta or 0)
    for _, callback in ipairs(handlers.tick) do callback() end
end

require("PZPerformanceDiagnostics/VehicleQueueObserver")

local pathAction = {
    Type = "ISPathFindAction",
    goal = { "VehicleSeat", vehicle, 0 },
    action = {},
    started = true,
}
local enterAction = {
    Type = "ISEnterVehicle",
    vehicle = vehicle,
    seat = 0,
    action = nil,
    started = false,
}
ISTimedActionQueue.queues[player] = {
    character = player,
    queue = { pathAction, enterAction },
    current = pathAction,
}

tick()
ISTimedActionQueue.queues[player].queue = { enterAction }
ISTimedActionQueue.queues[player].current = enterAction
tick(25)
enterAction.action = {}
enterAction.started = true
player.variables.bEnteringVehicle = "true"
tick(25)
tick(2000)
player.vehicle = vehicle
vehicle.occupant = player
for _, callback in ipairs(handlers.enter) do callback(player) end

local exitAction = {
    Type = "ISExitVehicle",
    vehicle = vehicle,
    action = {},
    started = true,
}
ISTimedActionQueue.queues[player].queue = { exitAction }
ISTimedActionQueue.queues[player].current = exitAction
player.variables.bExitingVehicle = "true"
tick(25)
player.vehicle = nil
vehicle.occupant = nil
for _, callback in ipairs(handlers.exit) do callback(player) end
ISTimedActionQueue.queues[player].queue = {}
ISTimedActionQueue.queues[player].current = nil

local beforeRemote = #events
ISTimedActionQueue.queues[remotePlayer] = {
    character = remotePlayer,
    queue = { { Type = "ISEnterVehicle", vehicle = vehicle, seat = 0 } },
}
tick(25)
if #events ~= beforeRemote then error("observer must ignore non-local player queues") end

local joined = {}
for _, event in ipairs(events) do
    joined[#joined + 1] = event.stage .. "|" .. tostring(event.action) .. "|" .. tostring(event.details)
end
joined = table.concat(joined, "\n")
local function assertContains(needle, label)
    if not string.find(joined, needle, 1, true) then
        error(label .. " missing: " .. needle .. "\n" .. joined)
    end
end

assertContains("queue-detected|ISPathFindAction", "entry queue detection")
assertContains("queue-transition|ISEnterVehicle", "entry queue transition")
assertContains("stall-2s|ISEnterVehicle", "entry stall milestone")
assertContains("entered|ISEnterVehicle", "entry completion event")
assertContains("queue-detected|ISExitVehicle", "exit queue detection")
assertContains("exited|ISExitVehicle", "exit completion event")
assertContains("nativeAction=false", "missing native action visibility")

print("PZ performance vehicle observer runtime fixture passed.")
