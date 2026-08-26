local Core = {}

local FIELD_LIMIT = 96
local DETAILS_LIMIT = 512

local function sanitize(value, limit)
    local valueType = type(value)
    local text
    if value == nil then
        text = "nil"
    elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
        text = tostring(value)
    else
        text = "unsupported"
    end

    text = string.gsub(text, "%s+", "_")
    text = string.gsub(text, "[^%w%._:%-%/>=,]", "_")
    if text == "" then text = "_" end
    limit = limit or FIELD_LIMIT
    if #text > limit then
        text = string.sub(text, 1, limit - 3) .. "..."
    end
    return text
end

local function sortedFields(fields)
    local keys = {}
    for key, _ in pairs(fields or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)

    local parts = {}
    for _, key in ipairs(keys) do
        parts[#parts + 1] = sanitize(key) .. "=" .. sanitize(fields[key])
    end
    return parts
end

function Core.isObservedActionType(actionType)
    return actionType == "ISInventoryTransferAction"
        or actionType == "ISEquipWeaponAction"
        or actionType == "ISWearClothing"
        or actionType == "ISInsertMagazine"
        or actionType == "ISEjectMagazine"
        or actionType == "ISLoadBulletsInMagazine"
        or actionType == "SetMagTypeAction"
        or actionType == "PostSwapAction"
end

function Core.state(value)
    if value == nil then return "unknown" end
    return value and "true" or "false"
end

function Core.transactionState(transactionId)
    if transactionId == nil then return "absent" end
    if type(transactionId) == "number" and transactionId > 0 then return "active" end
    return "none"
end

function Core.summarizeQueueTypes(actionTypes, maximum)
    maximum = maximum or 12
    local values = {}
    local count = actionTypes and #actionTypes or 0
    local retained = math.min(count, maximum)
    for index = 1, retained do
        values[index] = sanitize(actionTypes[index], 48)
    end
    return #values == 0 and "none" or table.concat(values, ">"), count - retained
end

function Core.transferOutcome(sourceContains, destinationContains, transactionState)
    if destinationContains == true then return "destination-present" end
    if sourceContains == true then
        if transactionState == "active" then return "source-present-transaction-active" end
        return "source-present"
    end
    if sourceContains == false and destinationContains == false then return "absent-from-source-and-destination" end
    return "containment-unknown"
end

function Core.equipOutcome(primaryMatch, secondaryMatch, itemContained)
    if primaryMatch and secondaryMatch then return "equipped-both" end
    if primaryMatch then return "equipped-primary" end
    if secondaryMatch then return "equipped-secondary" end
    if itemContained == true then return "removed-not-equipped" end
    return "removed-item-uncontained"
end

function Core.wearOutcome(itemEquipped, itemContained)
    if itemEquipped == true then return "state-worn" end
    if itemContained == true then return "state-not-worn-contained" end
    return "state-item-uncontained"
end

function Core.magazineOutcome(actionType, containsClip, primaryMatch)
    if actionType == "ISLoadBulletsInMagazine" then return "state-magazine-ammo" end
    if containsClip == true then return "state-contains-clip" end
    if containsClip == false then return "state-no-clip" end
    return primaryMatch == true and "sequence-advanced-primary" or "sequence-advanced"
end

function Core.recoveryPhase(elapsedMs)
    if elapsedMs >= 45000 then return "timeout" end
    if elapsedMs >= 500 then return "remains" end
    return "candidate"
end

function Core.details(fields, limit)
    local text = table.concat(sortedFields(fields), ",")
    limit = limit or DETAILS_LIMIT
    if #text > limit then
        text = string.sub(text, 1, limit - 3) .. "..."
    end
    return text == "" and "none" or text
end

function Core.format(prefix, traceId, eventName, fields)
    local parts = {
        "[" .. sanitize(prefix) .. "]",
        "trace=" .. sanitize(traceId),
        "event=" .. sanitize(eventName),
    }
    local fieldParts = sortedFields(fields)
    for _, part in ipairs(fieldParts) do
        parts[#parts + 1] = part
    end
    return table.concat(parts, " ")
end

return Core
