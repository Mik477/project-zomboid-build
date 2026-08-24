local SelectionPolicy = {}

---@param compactWasSelected boolean
---@param explicitContainerClick boolean
---@return boolean
function SelectionPolicy.shouldKeepCompact(compactWasSelected, explicitContainerClick)
    return compactWasSelected and not explicitContainerClick
end

return SelectionPolicy
