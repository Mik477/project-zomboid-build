local Core = {}

local function sanitize(value)
    if value == nil then return "nil" end
    local text = tostring(value)
    text = string.gsub(text, "%s+", "_")
    text = string.gsub(text, "[^%w%._:%-%/>=,]", "_")
    if text == "" then return "_" end
    return text
end

function Core.classifyMove(context)
    context = context or {}
    if context.pendingEquip then return "weapon-equip-transfer" end
    if context.sourceKeyRing then return "keyring-extract" end
    if context.destinationKeyRing then return "keyring-insert" end
    if context.sourceOnPlayer or context.destinationOnPlayer then
        return "player-inventory-move"
    end
    return nil
end

function Core.validationReason(snapshot)
    snapshot = snapshot or {}
    if snapshot.hasItem == false then return "missing-item" end
    if snapshot.hasSource == false then return "missing-source-container" end
    if snapshot.hasDestination == false then return "missing-destination-container" end
    if snapshot.sameContainer then return "same-container" end
    if snapshot.craftingConsumed then return "crafting-consumed" end
    if snapshot.sourceContains == false then return "source-no-longer-contains-item" end
    if snapshot.tetrisFits == false then return "tetris-no-fit" end
    if snapshot.sourceAllowsRemoval == false then return "source-rejected-removal" end
    if snapshot.destinationAllows == false then return "destination-rejected-item" end
    if snapshot.destinationHasRoom == false then return "destination-has-no-room" end
    if snapshot.transactionConsistent == false then return "multiplayer-transaction-inconsistent" end
    return "unknown-validation-failure"
end

function Core.summarizeBlockers(blockers)
    if not blockers or #blockers == 0 then return "none" end
    local values = {}
    for index, blocker in ipairs(blockers) do
        values[index] = sanitize(blocker)
    end
    return table.concat(values, ">")
end

function Core.format(prefix, traceId, eventName, fields)
    local parts = {
        "[" .. sanitize(prefix) .. "]",
        "trace=" .. sanitize(traceId),
        "event=" .. sanitize(eventName),
    }

    local keys = {}
    for key, _ in pairs(fields or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)

    for _, key in ipairs(keys) do
        parts[#parts + 1] = sanitize(key) .. "=" .. sanitize(fields[key])
    end
    return table.concat(parts, " ")
end

return Core
