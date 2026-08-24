local CompactRows = {}

---Builds a stable projection from source grid rows to visible rows.
---A rectangle occupies every row it spans; only rows occupied by at least one
---rectangle are included in the projection.
---@param gridHeight number
---@param rectangles table[] { y: number, height: number }
---@return table
function CompactRows.build(gridHeight, rectangles)
    local occupied = {}

    for _, rectangle in ipairs(rectangles or {}) do
        local firstRow = math.max(0, math.floor(rectangle.y or 0))
        local height = math.max(1, math.floor(rectangle.height or 1))
        local lastRow = math.min(gridHeight - 1, firstRow + height - 1)
        for sourceRow = firstRow, lastRow do
            occupied[sourceRow] = true
        end
    end

    local sourceRows = {}
    local displayBySource = {}
    for sourceRow = 0, gridHeight - 1 do
        if occupied[sourceRow] then
            local displayRow = #sourceRows
            sourceRows[displayRow + 1] = sourceRow
            displayBySource[sourceRow] = displayRow
        end
    end

    return {
        count = #sourceRows,
        sourceRows = sourceRows,
        displayBySource = displayBySource,
        signature = table.concat(sourceRows, ","),
    }
end

---@param projection table
---@param displayRow number
---@return number?
function CompactRows.toSource(projection, displayRow)
    if not projection then return nil end
    return projection.sourceRows[math.floor(displayRow) + 1]
end

---@param projection table
---@param sourceRow number
---@return number?
function CompactRows.toDisplay(projection, sourceRow)
    if not projection then return nil end
    return projection.displayBySource[math.floor(sourceRow)]
end

---@param projection table
---@param sourceRow number
---@return number
function CompactRows.toDisplayOrNearest(projection, sourceRow)
    local exact = CompactRows.toDisplay(projection, sourceRow)
    if exact ~= nil then return exact end
    if not projection or projection.count == 0 then return 0 end

    local nearestDisplay = 0
    local nearestDistance = math.huge
    for displayIndex, candidateSource in ipairs(projection.sourceRows) do
        local distance = math.abs(candidateSource - sourceRow)
        if distance < nearestDistance then
            nearestDistance = distance
            nearestDisplay = displayIndex - 1
        end
    end
    return nearestDisplay
end

return CompactRows
