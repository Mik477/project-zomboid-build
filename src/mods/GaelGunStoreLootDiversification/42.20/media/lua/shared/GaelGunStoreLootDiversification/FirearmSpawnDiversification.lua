local Module = {}

local transformedArrays = setmetatable({}, { __mode = "k" })
local transformedRecordLists = setmetatable({}, { __mode = "k" })

local function newStats()
    return {
        arrays = 0,
        occurrences = 0,
        retainedWeight = 0,
        replacementWeight = 0,
    }
end

local function mergeStats(target, source)
    target.arrays = target.arrays + source.arrays
    target.occurrences = target.occurrences + source.occurrences
    target.retainedWeight = target.retainedWeight + source.retainedWeight
    target.replacementWeight = target.replacementWeight + source.replacementWeight
end

local function shortType(typeName)
    if type(typeName) ~= "string" then
        return nil
    end
    local module, itemType = typeName:match("^([^.]+)%.(.+)$")
    if module and module ~= "Base" then
        return nil
    end
    return itemType or typeName
end

local function replacementType(sourceType, replacement)
    if sourceType:find("%.") then
        return "Base." .. replacement
    end
    return replacement
end

local function defaultItemExists(fullType)
    local manager = getScriptManager and getScriptManager() or (ScriptManager and ScriptManager.instance)
    return manager and manager:getItem(fullType) ~= nil
end

local function availableReplacements(definition, itemExists)
    local result = {}
    itemExists = itemExists or defaultItemExists
    for _, replacement in ipairs(definition.replacements or {}) do
        if itemExists("Base." .. replacement) then
            result[#result + 1] = replacement
        end
    end
    return result
end

function Module.transformWeightedItems(items, pools, itemExists)
    local stats = newStats()
    if type(items) ~= "table" or transformedArrays[items] then
        return stats
    end
    transformedArrays[items] = true

    local originalLength = #items
    local rebuilt = {}
    local changed = false
    for index = 1, originalLength - 1, 2 do
        local sourceType = items[index]
        local originalValue = items[index + 1]
        local originalWeight = tonumber(originalValue)
        local definition = pools[shortType(sourceType)]
        local replacements = definition and originalWeight and originalWeight > 0
            and availableReplacements(definition, itemExists)
            or nil

        rebuilt[#rebuilt + 1] = sourceType
        if replacements and #replacements > 0 then
            local retain = math.max(0, math.min(1, tonumber(definition.retain) or 1))
            local retainedWeight = originalWeight * retain
            local displacedWeight = originalWeight - retainedWeight
            rebuilt[#rebuilt + 1] = retainedWeight
            if displacedWeight > 0 then
                local replacementWeight = displacedWeight / #replacements
                for _, replacement in ipairs(replacements) do
                    -- Keep each replacement adjacent to its source. Small firearm cases
                    -- process items in order and may reject guns appended after ammo/accessories.
                    rebuilt[#rebuilt + 1] = replacementType(sourceType, replacement)
                    rebuilt[#rebuilt + 1] = replacementWeight
                end
                stats.replacementWeight = stats.replacementWeight + displacedWeight
            end
            stats.occurrences = stats.occurrences + 1
            stats.retainedWeight = stats.retainedWeight + retainedWeight
            changed = true
        else
            rebuilt[#rebuilt + 1] = originalValue
        end
    end
    if originalLength % 2 == 1 then
        rebuilt[#rebuilt + 1] = items[originalLength]
    end
    if changed then
        for index = #items, 1, -1 do items[index] = nil end
        for index, value in ipairs(rebuilt) do items[index] = value end
        stats.arrays = 1
    end
    return stats
end

function Module.transformRoots(roots, pools, itemExists)
    local stats = newStats()
    local visited = {}

    local function visit(value)
        if type(value) ~= "table" or visited[value] then
            return
        end
        visited[value] = true
        mergeStats(stats, Module.transformWeightedItems(value, pools, itemExists))
        for _, child in pairs(value) do
            if type(child) == "table" then
                visit(child)
            end
        end
    end

    for _, root in ipairs(roots or {}) do
        visit(root)
    end
    return stats
end

function Module.transformRecords(records, pools, itemExists)
    local stats = newStats()
    if type(records) ~= "table" or transformedRecordLists[records] then
        return stats
    end
    transformedRecordLists[records] = true

    local originalLength = #records
    local additions = {}
    for index = 1, originalLength do
        local record = records[index]
        local definition = type(record) == "table" and pools[shortType(record.item)] or nil
        local originalWeight = definition and tonumber(record.weight) or nil
        if definition and originalWeight and originalWeight > 0 then
            local replacements = availableReplacements(definition, itemExists)
            if #replacements > 0 then
                local retain = math.max(0, math.min(1, tonumber(definition.retain) or 1))
                local retainedWeight = originalWeight * retain
                local displacedWeight = originalWeight - retainedWeight
                record.weight = retainedWeight
                if displacedWeight > 0 then
                    local replacementWeight = displacedWeight / #replacements
                    for _, replacement in ipairs(replacements) do
                        local clone = {}
                        for key, value in pairs(record) do
                            clone[key] = value
                        end
                        clone.item = replacementType(record.item, replacement)
                        clone.weight = replacementWeight
                        additions[#additions + 1] = clone
                    end
                    stats.replacementWeight = stats.replacementWeight + displacedWeight
                end
                stats.occurrences = stats.occurrences + 1
                stats.retainedWeight = stats.retainedWeight + retainedWeight
            end
        end
    end
    for _, record in ipairs(additions) do
        records[#records + 1] = record
    end
    if stats.occurrences > 0 then
        stats.arrays = 1
    end
    return stats
end

return Module
