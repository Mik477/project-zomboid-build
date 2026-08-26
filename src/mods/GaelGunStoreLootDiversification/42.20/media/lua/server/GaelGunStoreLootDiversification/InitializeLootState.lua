local Policy = require("GaelGunStoreLootDiversification/LootStatePolicy")

local function isFirearm(item)
    return item
        and instanceof(item, "HandWeapon")
        and item:isRanged()
        and item:getMaxAmmo() > 0
end

local function isMagazine(item)
    if not item or instanceof(item, "HandWeapon") or item:getMaxAmmo() <= 0 then
        return false
    end
    local gunTypes = item:getGunType()
    return gunTypes and not gunTypes:isEmpty()
end

local function initializeItem(item, context)
    if isFirearm(item) then
        local modData = item:getModData()
        if modData[Policy.FIREARM_MARKER] == nil then
            item:setCondition(Policy.conditionFor(context, item:getConditionMax(), ZombRand(10000)))
            modData[Policy.FIREARM_MARKER] = true
        end
    elseif isMagazine(item) then
        local modData = item:getModData()
        if modData[Policy.MAGAZINE_MARKER] == nil then
            item:setCurrentAmmoCount(Policy.magazineAmmoFor(context, item:getMaxAmmo(), ZombRand(10000)))
            modData[Policy.MAGAZINE_MARKER] = true
        end
    end

    if item and instanceof(item, "InventoryContainer") then
        local nested = item:getInventory()
        if nested then
            local nestedItems = nested:getItems()
            for index = 0, nestedItems:size() - 1 do
                initializeItem(nestedItems:get(index), context)
            end
        end
    end
end

local function initializeContainer(roomName, containerType, ...)
    local container = nil
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if candidate and instanceof(candidate, "ItemContainer") then
            container = candidate
            break
        end
    end
    if not container then
        return
    end

    local context = Policy.contextForContainer(roomName, containerType)
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        initializeItem(items:get(index), context)
    end
end

if (not isClient or not isClient()) and Events and Events.OnFillContainer then
    Events.OnFillContainer.Add(initializeContainer)
end
