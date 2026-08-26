local Policy = {}

local actionKinds = {
    ISWearClothing = { kind = "wear", field = "item" },
    ISInsertMagazine = { kind = "insert-magazine", field = "gun", secondaryField = "magazine" },
    ISEjectMagazine = { kind = "eject-magazine", field = "gun" },
    SetMagTypeAction = { kind = "insert-magazine", field = "gun", secondaryTypeField = "magType" },
    PostSwapAction = { kind = "insert-magazine", field = "gun", secondaryTypeField = "magType" },
}

local function runtimeId(item)
    if not (item and item.getID) then return nil end
    local ok, value = pcall(item.getID, item)
    value = ok and tonumber(value) or nil
    if not value or value <= 0 then return nil end
    return value
end

local function itemType(item)
    if not (item and item.getFullType) then return nil end
    local ok, value = pcall(item.getFullType, item)
    if not ok or value == nil then return nil end
    return tostring(value)
end

local function sameType(left, right)
    if not left or not right then return false end
    left = tostring(left)
    right = tostring(right)
    if left == right then return true end
    return left:match("([^.]+)$") == right:match("([^.]+)$")
end

function Policy.sameItem(left, right)
    if left == right then return left ~= nil end
    local leftId = runtimeId(left)
    local rightId = runtimeId(right)
    return leftId ~= nil and rightId ~= nil and leftId == rightId
end

function Policy.hasPending(actions, kind, primaryItem, secondaryItem)
    if type(actions) ~= "table" or not kind or not primaryItem then return false end
    for _, action in ipairs(actions) do
        local descriptor = action and actionKinds[action.Type] or nil
        if descriptor and descriptor.kind == kind
                and Policy.sameItem(action[descriptor.field], primaryItem) then
            if descriptor.secondaryField then
                if Policy.sameItem(action[descriptor.secondaryField], secondaryItem) then return true end
            elseif descriptor.secondaryTypeField then
                if sameType(action[descriptor.secondaryTypeField], itemType(secondaryItem)) then return true end
            else
                return true
            end
        end
    end
    return false
end

return Policy
