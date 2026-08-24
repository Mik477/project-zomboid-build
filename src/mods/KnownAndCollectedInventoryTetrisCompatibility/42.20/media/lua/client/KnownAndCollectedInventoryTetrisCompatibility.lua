KnownAndCollectedInventoryTetrisCompatibility = KnownAndCollectedInventoryTetrisCompatibility or {
    handlersWrapped = 0,
    literatureSkipped = 0,
    failuresCaught = 0,
}

local Compatibility = KnownAndCollectedInventoryTetrisCompatibility
local HANDLER_SOURCE = "knownandcollectedrenderhandler.lua"

local function normalizePath(path)
    return string.lower(string.gsub(tostring(path or ""), "\\", "/"))
end

local function callbackInfo(callback)
    if not ZombieBuddy or type(ZombieBuddy.getClosureInfo) ~= "function" then return nil end
    local ok, info = pcall(ZombieBuddy.getClosureInfo, callback)
    if not ok then return nil end
    return info
end

local function isTargetHandler(handler)
    if not handler or type(handler.call) ~= "function" then return false end
    local info = callbackInfo(handler.call)
    if not info then return false end
    return string.find(normalizePath(info.filename or info.file), HANDLER_SOURCE, 1, true) ~= nil
end

local function wrapHandler(handler)
    if handler._KACInventoryTetrisCompatibilityWrapped or not isTargetHandler(handler) then return false end
    local originalCall = handler.call
    handler.call = function(eventData, drawingContext, renderInstructions, instructionCount, playerObj)
        local hiddenInstructions = {}
        for index = 1, instructionCount do
            local instruction = renderInstructions[index]
            local item = instruction and instruction[2] or nil
            if item and instanceof(item, "Literature") and not instruction[9] then
                hiddenInstructions[#hiddenInstructions + 1] = instruction
                instruction[9] = true
            end
        end

        Compatibility.literatureSkipped = Compatibility.literatureSkipped + #hiddenInstructions
        local ok, errorMessage = pcall(
            originalCall, eventData, drawingContext, renderInstructions, instructionCount, playerObj)
        for _, instruction in ipairs(hiddenInstructions) do instruction[9] = false end
        if not ok then
            Compatibility.failuresCaught = Compatibility.failuresCaught + 1
            if Compatibility.failuresCaught == 1 then
                print("[KnownAndCollectedInventoryTetrisCompatibility] contained render failure: " .. tostring(errorMessage))
            end
        end
    end
    handler._KACInventoryTetrisCompatibilityWrapped = true
    Compatibility.handlersWrapped = Compatibility.handlersWrapped + 1
    return true
end

function Compatibility.install()
    if not isClient() then return false end
    local ok, TetrisEvents = pcall(require, "InventoryTetris/Events")
    if not ok or not TetrisEvents or not TetrisEvents.OnPostRenderGrid then return false end
    local handlers = TetrisEvents.OnPostRenderGrid._eventHandlers
    if not handlers then return false end
    local installed = false
    for _, handler in ipairs(handlers) do installed = wrapHandler(handler) or installed end
    return installed or Compatibility.handlersWrapped > 0
end

if Events.OnConnected then Events.OnConnected.Add(Compatibility.install) end
if Events.OnGameStart then Events.OnGameStart.Add(Compatibility.install) end
Compatibility.install()

KnownAndCollectedInventoryTetrisCompatibility_status = function()
    return "handlersWrapped=" .. tostring(Compatibility.handlersWrapped)
        .. ";literatureSkipped=" .. tostring(Compatibility.literatureSkipped)
        .. ";failuresCaught=" .. tostring(Compatibility.failuresCaught)
end
