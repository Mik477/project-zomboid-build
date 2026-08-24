VASRemoteDoorSyncFix = VASRemoteDoorSyncFix or { corrections = 0 }

local Fix = VASRemoteDoorSyncFix

local function correctRemoteDoor(module, command, args)
    if not isClient() or module ~= "VAS_Sync" or command ~= "doorStatus" then return end
    args = args or {}
    if args.doorOpen ~= false then return end
    local player = getPlayer()
    if not player or tostring(args.username or "") == tostring(player:getUsername()) then return end
    local vehicle = getVehicleById(args.vehicleID or -1)
    if not vehicle then return end
    local part = vehicle:getPartById(args.partID or "")
    local door = part and part:getDoor() or nil
    if not door or not door:isOpen() then return end
    door:setOpen(false)
    Fix.corrections = Fix.corrections + 1
end

Events.OnServerCommand.Add(correctRemoteDoor)

VASRemoteDoorSyncFix_status = function()
    return "corrections=" .. tostring(Fix.corrections)
end
