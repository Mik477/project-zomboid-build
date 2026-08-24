require "ISUI/ISInventoryPaneContextMenu"

local NearbyContainers = {}

local MARKER_TYPE = "compactProxInv"
local MARKER_ICON = getTexture("media/ui/Icon_InventoryBasic.png")

local markers = {}
local entriesByPlayer = {}

---@param container ItemContainer?
---@return boolean
function NearbyContainers.isMarker(container)
    return container ~= nil and container:getType() == MARKER_TYPE
end

---@param containers ArrayList?
---@return ArrayList?
function NearbyContainers.filterCraftContainers(containers)
    if not containers then return nil end

    local filtered = ArrayList.new()
    for index = 0, containers:size() - 1 do
        local container = containers:get(index)
        if not NearbyContainers.isMarker(container) then
            filtered:add(container)
        end
    end
    return filtered
end

---@param playerNum number
---@return ItemContainer
function NearbyContainers.getMarker(playerNum)
    if not markers[playerNum] then
        local marker = ItemContainer.new(MARKER_TYPE, nil, nil)
        marker:setExplored(true)
        marker:setOnlyAcceptCategory("none")
        marker:setCapacity(0)
        markers[playerNum] = marker
    end
    return markers[playerNum]
end

local function canInclude(container, playerObj)
    if not container or NearbyContainers.isMarker(container) then return false end

    local containerType = container:getType()
    if containerType == "proxInv" or containerType == "local" then return false end

    local parent = container:getParent()
    if parent and instanceof(parent, "IsoThumpable") and parent:isLockedToCharacter(playerObj) then
        return false
    end

    return true
end

---@param inventoryPage ISInventoryPage
---@return table[]
function NearbyContainers.collect(inventoryPage)
    local playerObj = getSpecificPlayer(inventoryPage.player)
    local seen = {}
    local entries = {}

    for index, button in ipairs(inventoryPage.backpacks or {}) do
        local container = button.inventory
        if canInclude(container, playerObj) and not seen[container] then
            seen[container] = true
            entries[#entries + 1] = {
                button = button,
                inventory = container,
                name = button.name,
                isEmpty = container:isEmpty(),
                sourceOrder = index,
            }
        end
    end

    table.sort(entries, function(a, b)
        if a.isEmpty ~= b.isEmpty then return not a.isEmpty end
        return a.sourceOrder < b.sourceOrder
    end)

    entriesByPlayer[inventoryPage.player] = entries
    return entries
end

---@param playerNum number
---@return table[]
function NearbyContainers.getEntries(playerNum)
    local lootPage = getPlayerLoot(playerNum)
    if lootPage then return NearbyContainers.collect(lootPage) end
    return entriesByPlayer[playerNum] or {}
end

---@param marker ItemContainer
---@param entries table[]
local function populateMarker(marker, entries)
    marker:clear()
    local markerItems = marker:getItems()
    for _, entry in ipairs(entries) do
        markerItems:addAll(entry.inventory:getItems())
    end
end

if not _G.CompactProximityInventoryCraftContainerFilterApplied then
    _G.CompactProximityInventoryCraftContainerFilterApplied = true
    local getContainers = ISInventoryPaneContextMenu.getContainers

    ISInventoryPaneContextMenu.getContainers = function(character)
        return NearbyContainers.filterCraftContainers(getContainers(character))
    end
end

Events.OnRefreshInventoryWindowContainers.Add(function(inventoryPage, state)
    if inventoryPage.onCharacter then return end

    if state == "begin" then
        local marker = NearbyContainers.getMarker(inventoryPage.player)
        local title = getTextOrNull("IGUI_CompactProximity_Title") or "Nearby (Compact)"
        inventoryPage:addContainerButton(marker, MARKER_ICON, title)
        return
    end

    if state == "buttonsAdded" then
        local entries = NearbyContainers.collect(inventoryPage)
        populateMarker(NearbyContainers.getMarker(inventoryPage.player), entries)
    end
end)

return NearbyContainers
