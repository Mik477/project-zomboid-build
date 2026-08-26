require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISReloadWeaponAction"
pcall(require, "WeaponAbility/ChangeMagazineType")

if _G.GGSASF_AutomaticMagazineSelectionRegistered then
    return _G.GGSASF_AutomaticMagazineSelection
end

local Module = {}
local installedReloadWrappers = {}
local installedMagazineMenuWrapper = nil
local installedWeaponMenuWrapper = nil

local function shortType(typeName)
    if not typeName then return nil end
    local raw = tostring(typeName)
    return raw:match("([^.]+)$") or raw
end

local function eachItemRecursive(container, visit)
    if not (container and container.getItems) then return end
    local items = container:getItems()
    for index = 0, items:size() - 1 do
        local item = items:get(index)
        if item then
            visit(item)
            if instanceof(item, "InventoryContainer") and item.getInventory then
                eachItemRecursive(item:getInventory(), visit)
            end
        end
    end
end

local function allowedMagazineSet(weapon)
    local byWeapon = _G.AWCWF_WeaponMagazineType
    if not (byWeapon and weapon and weapon.getType) then return nil end
    local allowed = byWeapon[weapon:getType()]
    if type(allowed) ~= "table" then return nil end
    local result = {}
    for _, magazineType in ipairs(allowed) do
        result[shortType(magazineType)] = tostring(magazineType)
    end
    return result
end

local function isBetterMagazine(candidate, current)
    if not current then return true end
    local candidateAmmo = tonumber(candidate.getCurrentAmmoCount and candidate:getCurrentAmmoCount() or 0) or 0
    local currentAmmo = tonumber(current.getCurrentAmmoCount and current:getCurrentAmmoCount() or 0) or 0
    if candidateAmmo ~= currentAmmo then return candidateAmmo > currentAmmo end
    local candidateCapacity = tonumber(candidate.getMaxAmmo and candidate:getMaxAmmo() or 0) or 0
    local currentCapacity = tonumber(current.getMaxAmmo and current:getMaxAmmo() or 0) or 0
    if candidateCapacity ~= currentCapacity then return candidateCapacity > currentCapacity end
    local candidateCondition = tonumber(candidate.getCondition and candidate:getCondition() or 0) or 0
    local currentCondition = tonumber(current.getCondition and current:getCondition() or 0) or 0
    return candidateCondition > currentCondition
end

function Module.findCompatibleMagazines(playerObj, weapon)
    local result = {}
    local allowed = allowedMagazineSet(weapon)
    local inventory = playerObj and playerObj.getInventory and playerObj:getInventory() or nil
    if not (allowed and inventory) then return result end

    eachItemRecursive(inventory, function(item)
        local itemFull = item.getFullType and item:getFullType() or nil
        local itemShort = shortType(itemFull)
        if itemShort and allowed[itemShort] and item.getMaxAmmo then
            local current = result[itemShort]
            if isBetterMagazine(item, current) then result[itemShort] = item end
        end
    end)
    return result
end

function Module.findBestCompatibleMagazine(playerObj, weapon)
    local magazines = Module.findCompatibleMagazines(playerObj, weapon)
    local best = nil
    for _, magazine in pairs(magazines) do
        if isBetterMagazine(magazine, best) then best = magazine end
    end
    return best
end

local function queueCompatibleMagazine(playerObj, weapon, magazine, source)
    if not (playerObj and weapon and magazine and type(_G.ChangeMagazine) == "function") then
        return false
    end
    local intentGuard = _G.InventoryActionIntentFix_isPending
    if type(intentGuard) == "function" then
        local ok, pending = pcall(intentGuard, "insert-magazine", playerObj, weapon, magazine)
        if ok and pending then return true end
    end
    if ISInventoryPaneContextMenu.transferIfNeeded then
        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
    end
    if ISInventoryPaneContextMenu.equipWeapon then
        ISInventoryPaneContextMenu.equipWeapon(weapon, true, false, playerObj:getPlayerNum())
    end
    local magazineType = magazine.getFullType and magazine:getFullType() or nil
    return _G.ChangeMagazine(playerObj, weapon, magazineType, source or "Automatic", true) == true
end

Module.queueCompatibleMagazine = queueCompatibleMagazine
Module.isBetterMagazine = isBetterMagazine
Module.allowedMagazineSet = allowedMagazineSet
Module.shortType = shortType

local function wrapReloadMethod(methodName)
    local current = ISReloadWeaponAction and ISReloadWeaponAction[methodName]
    if type(current) ~= "function" or current == installedReloadWrappers[methodName] then return end

    local wrapper = function(playerObj, weapon, ...)
        if weapon and weapon.getMagazineType and weapon:getMagazineType()
                and not weapon:isContainsClip() and weapon.getBestMagazine then
            local currentMagazine = weapon:getBestMagazine(playerObj)
            if not currentMagazine then
                local compatibleMagazine = Module.findBestCompatibleMagazine(playerObj, weapon)
                if compatibleMagazine and queueCompatibleMagazine(playerObj, weapon, compatibleMagazine, methodName) then
                    return
                end
            end
        end
        return current(playerObj, weapon, ...)
    end
    installedReloadWrappers[methodName] = wrapper
    ISReloadWeaponAction[methodName] = wrapper
end

local function installReloadWrappers()
    wrapReloadMethod("BeginAutomaticReload")
    wrapReloadMethod("ReloadBestMagazine")
end

local function addMagazineOption(context, playerObj, weapon, magazine, label)
    local option = context:addOption(label, playerObj, queueCompatibleMagazine, weapon, magazine, "ContextMenu")
    if ISInventoryPaneContextMenu.addToolTip then
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip.description = getText("ContextMenu_GunType") .. ": " .. weapon:getDisplayName()
        option.toolTip = tooltip
    end
end

local function installContextMenuWrappers()
    local currentMagazineMenu = ISInventoryPaneContextMenu.doReloadMenuForMagazine
    if type(currentMagazineMenu) == "function" and currentMagazineMenu ~= installedMagazineMenuWrapper then
        local wrapper = function(playerObj, magazine, context, ...)
            currentMagazineMenu(playerObj, magazine, context, ...)
            local weapons = playerObj:getInventory():getItemsFromCategory("Weapon")
            local magazineShort = shortType(magazine and magazine.getFullType and magazine:getFullType())
            for index = 0, weapons:size() - 1 do
                local weapon = weapons:get(index)
                local allowed = allowedMagazineSet(weapon)
                if allowed and allowed[magazineShort] and not weapon:isContainsClip()
                        and shortType(weapon:getMagazineType()) ~= magazineShort then
                    addMagazineOption(
                        context,
                        playerObj,
                        weapon,
                        magazine,
                        getText("ContextMenu_InsertMagazine") .. ": " .. weapon:getDisplayName())
                end
            end
        end
        installedMagazineMenuWrapper = wrapper
        ISInventoryPaneContextMenu.doReloadMenuForMagazine = wrapper
    end

    local currentWeaponMenu = ISInventoryPaneContextMenu.doReloadMenuForWeapon
    if type(currentWeaponMenu) == "function" and currentWeaponMenu ~= installedWeaponMenuWrapper then
        local wrapper = function(playerObj, weapon, context, ...)
            currentWeaponMenu(playerObj, weapon, context, ...)
            if not (weapon and weapon.getMagazineType and weapon:getMagazineType()) or weapon:isContainsClip() then return end
            local currentShort = shortType(weapon:getMagazineType())
            local magazines = Module.findCompatibleMagazines(playerObj, weapon)
            for magazineShort, magazine in pairs(magazines) do
                if magazineShort ~= currentShort then
                    addMagazineOption(
                        context,
                        playerObj,
                        weapon,
                        magazine,
                        getText("ContextMenu_InsertMagazine") .. ": " .. magazine:getDisplayName())
                end
            end
        end
        installedWeaponMenuWrapper = wrapper
        ISInventoryPaneContextMenu.doReloadMenuForWeapon = wrapper
    end
end

local function install()
    installReloadWrappers()
    installContextMenuWrappers()
end

Module.install = install
_G.GGSASF_AutomaticMagazineSelection = Module
_G.GGSASF_AutomaticMagazineSelectionRegistered = true

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(install)
end

return Module
