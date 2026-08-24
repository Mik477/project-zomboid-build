TYLIndoorBushFix = TYLIndoorBushFix or {
    indoorBushGuardApplied = false,
    indoorBushesRemoved = 0,
}

local Fix = TYLIndoorBushFix

local function isInteriorSquare(square)
    if not square then return false end
    return not square:isOutside() or square:getRoom() ~= nil
end

local function removeIndoorBushes(square)
    if not isInteriorSquare(square) then return 0 end
    local objects = square:getObjects()
    if not objects then return 0 end

    local removed = 0
    for index = objects:size() - 1, 0, -1 do
        local object = objects:get(index)
        local modData = object and object:getModData() or nil
        if modData and modData.TYLBush == true then
            if isServer() then pcall(square.transmitRemoveItemFromSquare, square, object) end
            square:RemoveTileObject(object)
            removed = removed + 1
        end
    end
    Fix.indoorBushesRemoved = Fix.indoorBushesRemoved + removed
    return removed
end

function Fix.guardSpawnBush(square)
    if isInteriorSquare(square) then
        removeIndoorBushes(square)
        return false
    end
    if not Fix.originalSpawnBush then return false end
    return Fix.originalSpawnBush(square)
end

function Fix.install()
    if Fix.originalSpawnBush then
        Fix.indoorBushGuardApplied = true
        return true
    end
    if type(TYL_SpawnBush) ~= "function" then return false end
    Fix.originalSpawnBush = TYL_SpawnBush
    TYL_SpawnBush = Fix.guardSpawnBush
    Fix.indoorBushGuardApplied = true
    return true
end

Events.LoadGridsquare.Add(removeIndoorBushes)
if Events.OnInitWorld then Events.OnInitWorld.Add(Fix.install) end
if Events.OnGameStart then Events.OnGameStart.Add(Fix.install) end
if Events.OnServerStarted then Events.OnServerStarted.Add(Fix.install) end
Fix.install()

TYLIndoorBushFix_status = function()
    return "guardApplied=" .. tostring(Fix.indoorBushGuardApplied)
        .. ";indoorBushesRemoved=" .. tostring(Fix.indoorBushesRemoved)
end
