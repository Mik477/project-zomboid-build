local Module = {}

local function isActive(modId)
    return getActivatedMods and getActivatedMods():contains(modId)
end

if not (isActive("INVENTORY_TETRIS") and isActive("GaelGunStore_B42")) then
    return Module
end

local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local ItemGridUI = require("InventoryTetris/UI/Grid/ItemGridUI")
local ItemContainerGrid = require("InventoryTetris/Model/ItemContainerGrid")
local ItemStack = require("InventoryTetris/Model/ItemStack")

local compactTypes = {
    Base = {
        APC9K = true,
        AK_minidrako = true,
        AK74u = true,
        AK74u_long = true,
        FAL_CQB = true,
        KAC_PDW = true,
        ACE52_CQB = true,
        Micro_UZI = true,
        MP5K = true,
        MP9 = true,
        PP93 = true,
        SVD_short = true,
        SVDK_short = true,
        SKS_carbine_short = true,
        TMP = true,
        UMP9 = true,
        VZ61 = true,
        X86 = true,
        Shorty = true,
        ShotgunSawnoff = true,
        DoubleBarrelShotgunSawnoff = true,
        DB_Condor_sawn = true,
        M1887_Short = true,
        Remington870_Short = true,
        Becker_Shotgun_Short = true,
        Beretta_A400_Short = true,
        Browning_Auto_Short = true,
        MTS_255_Short = true,
        QBS09_Short = true,
        Remington1100_Short = true,
        Sjorgen_Short = true,
    },
}

local largeTypes = {
    Base = {
        AWS = true, BAR = true, CETME = true, HK_121 = true, L86 = true, Lewis = true,
        LSAT = true, M240B = true, M249 = true, M60E4 = true, MG131 = true,
        MG4 = true, MG42 = true, MG710 = true, Minimi = true, Negev = true,
        PKM = true, PKP = true, QBB95 = true, RPD = true, RPK = true,
        RPK12 = true, RPK16 = true, Type88 = true,
        M82A3 = true, M200 = true, M98B = true, VSSK = true,
        TankgewehrM1918 = true, RPG7 = true, M202A1 = true,
        GM94 = true, ChinaLake = true, M79 = true, MLG = true, RG6 = true,
        Minigun = true,
    },
}

local stocklessPartTokens = {
    "grip",
}

local extendedStockTokens = {
    "unfold", "extended",
}

local foldedStockTokens = {
    "fold", "collapsed", "short", "removed", "no_stock", "nostock",
}

local function splitFullType(fullType)
    local moduleName, itemType = tostring(fullType or ""):match("^([^.]+)%.(.+)$")
    return moduleName or "Base", itemType or tostring(fullType or "")
end

local function safeCall(target, methodName, defaultValue, ...)
    local method = target and target[methodName]
    if type(method) ~= "function" then return defaultValue end
    local ok, value = pcall(method, target, ...)
    return ok and value or defaultValue
end

local function isFirearm(item)
    if not (item and safeCall(item, "IsWeapon", false) and safeCall(item, "isRanged", false)) then
        return false
    end
    local ammoType = tostring(safeCall(item, "getAmmoType", "")):lower()
    if ammoType:find("arrow", 1, true) or ammoType:find("bolt", 1, true) then return false end
    if safeCall(item, "hasTag", false, "Firearm") then return true end
    local script = safeCall(item, "getScriptItem", nil)
    if script and safeCall(script, "hasTag", false, "Firearm") then return true end
    return ammoType:find("bullet", 1, true) ~= nil
        or ammoType:find("shotgun", 1, true) ~= nil
        or ammoType:find("grenadeammo", 1, true) ~= nil
        or ammoType:find("rocketammo", 1, true) ~= nil
end

local function isPistol(item)
    local script = safeCall(item, "getScriptItem", nil)
    if safeCall(item, "isTwoHandWeapon", false) or safeCall(script, "isTwoHandWeapon", false) then
        return false
    end

    local reloadType = safeCall(item, "getWeaponReloadType", nil)
        or safeCall(script, "getWeaponReloadType", "")
    local swingAnim = safeCall(item, "getSwingAnim", nil)
        or safeCall(script, "getSwingAnim", "")
    reloadType = tostring(reloadType):lower()
    swingAnim = tostring(swingAnim):lower()
    return reloadType == "handgun" or reloadType == "revolver" or swingAnim == "handgun"
end

local function isTypeInSet(item, set)
    local moduleName, itemType = splitFullType(safeCall(item, "getFullType", ""))
    return set[moduleName] and set[moduleName][itemType] == true
end

local function getStockState(item)
    local stock = safeCall(item, "getWeaponPart", nil, "Stock")
    if not stock then return "none", nil end
    local fullType = tostring(safeCall(stock, "getFullType", ""))
    local lower = fullType:lower()
    for _, token in ipairs(stocklessPartTokens) do
        if lower:find(token, 1, true) then return "stockless", fullType end
    end
    for _, token in ipairs(extendedStockTokens) do
        if lower:find(token, 1, true) then return "extended", fullType end
    end
    for _, token in ipairs(foldedStockTokens) do
        if lower:find(token, 1, true) then return "folded", fullType end
    end
    return "extended", fullType
end

function Module.getUnrotatedSize(item)
    if not isFirearm(item) then return nil, nil, nil end

    local class
    local width
    local height
    if isTypeInSet(item, largeTypes) then
        class, width, height = "large", 4, 2
    elseif isTypeInSet(item, compactTypes) then
        class, width, height = "compact", 2, 2
    elseif isPistol(item) then
        class, width, height = "pistol", 2, 1
    else
        class, width, height = "standard", 3, 2
    end

    local stockState = getStockState(item)
    if stockState == "extended" then
        if class == "pistol" then width, height = 2, 2
        elseif class == "compact" then width, height = 3, 2 end
    elseif stockState == "folded" then
        if class == "standard" then width, height = 2, 2 end
    end

    return width, height, class .. ":" .. stockState
end

function Module.getSize(item, isRotated)
    local width, height, reason = Module.getUnrotatedSize(item)
    if not width then return nil, nil, nil end
    if isRotated then return height, width, reason end
    return width, height, reason
end

function Module.applySizePolicy(item, width, height, isRotated)
    local policyWidth, policyHeight, reason = Module.getSize(item, isRotated)
    if not policyWidth then return width, height, nil end
    return policyWidth, policyHeight, reason
end

local sessionId = tostring(getTimestamp and getTimestamp() or os.time())
local traceCount = 0
local TRACE_LIMIT = 100
local function trace(message)
    if traceCount >= TRACE_LIMIT then return end
    traceCount = traceCount + 1
    print("[GaelFirearmTetris] session=" .. sessionId .. " " .. message)
end

local installedGetItemData = nil
local installedRenderStackLoop = nil
local installedBulkRenderGridStacks = nil
local installedUpgradeComplete = nil
local installedRemoveComplete = nil
local adjustedDataByItem = setmetatable({}, { __mode = "k" })
local correctedRenderStateByItem = setmetatable({}, { __mode = "k" })
local observedPolicyByItem = setmetatable({}, { __mode = "k" })
local pendingPolicyReflowByItem = setmetatable({}, { __mode = "k" })
local renderCorrectionCount = 0
local RENDER_CORRECTION_TRACE_LIMIT = 20

local function rectanglesOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

local function stackFitsCurrentPolicy(grid, targetStack, weapon)
    local width, height = Module.getSize(weapon, targetStack.isRotated)
    local x, y = targetStack.x, targetStack.y
    if not width or type(x) ~= "number" or type(y) ~= "number"
            or x < 0 or y < 0 or x + width > grid.width or y + height > grid.height then
        return false
    end

    for _, stack in ipairs(grid:getStacks()) do
        if stack ~= targetStack then
            local item = ItemStack.getFrontItem(stack, grid.inventory)
            local otherWidth, otherHeight = TetrisItemData.tryGetItemSize(item, stack.isRotated)
            local otherX, otherY = stack.x, stack.y
            if otherWidth and type(otherX) == "number" and type(otherY) == "number"
                    and rectanglesOverlap(x, y, width, height,
                        otherX, otherY, otherWidth, otherHeight) then
                return false
            end
        end
    end
    return true
end

local function reflowExpandedWeapon(weapon, playerNum)
    local container = safeCall(weapon, "getContainer", nil)
    if not container then return "no-container" end

    local containerGrid = ItemContainerGrid.GetOrCreate(container, playerNum)
    containerGrid:refresh()
    local stack, grid = containerGrid:findStackByItem(weapon)
    if not stack or not grid then return "unpositioned" end
    if stackFitsCurrentPolicy(grid, stack, weapon) then return "kept" end

    grid:removeItem(weapon)
    containerGrid:refresh()
    local replacementStack = containerGrid:findStackByItem(weapon)
    return replacementStack and "repositioned" or "overflow"
end

local function refreshWeaponGrid(weapon, beforeWidth, beforeHeight, reason, playerNum)
    adjustedDataByItem[weapon] = nil
    correctedRenderStateByItem[weapon] = nil
    local afterWidth, afterHeight, afterReason = Module.getUnrotatedSize(weapon)
    if not afterWidth or (afterWidth == beforeWidth and afterHeight == beforeHeight) then return end

    local placement = "unchanged"
    if afterWidth > (beforeWidth or 0) or afterHeight > (beforeHeight or 0) then
        placement = reflowExpandedWeapon(weapon, playerNum or 0)
    end

    local container = safeCall(weapon, "getContainer", nil)
    if container and container.setDrawDirty then container:setDrawDirty(true) end
    for activePlayerNum = 0, getNumActivePlayers() - 1 do
        local inventoryPage = getPlayerInventory(activePlayerNum)
        local lootPage = getPlayerLoot(activePlayerNum)
        if inventoryPage and inventoryPage.inventoryPane and inventoryPage.inventoryPane.refreshItemGrids then
            inventoryPage.inventoryPane:refreshItemGrids(true)
        end
        if lootPage and lootPage.inventoryPane and lootPage.inventoryPane.refreshItemGrids then
            lootPage.inventoryPane:refreshItemGrids(true)
        end
    end
    observedPolicyByItem[weapon] = {
        width = afterWidth,
        height = afterHeight,
        reason = afterReason,
    }
    pendingPolicyReflowByItem[weapon] = nil
    trace(string.format(
        "event=size-changed item=%s before=%dx%d after=%dx%d reason=%s state=%s placement=%s",
        tostring(safeCall(weapon, "getFullType", "unknown")), beforeWidth or 0, beforeHeight or 0,
        afterWidth, afterHeight, tostring(reason), tostring(afterReason), tostring(placement)))
end

local function observePolicy(item, width, height, reason, sourceData)
    local previous = observedPolicyByItem[item]
    local sourceWidth = type(sourceData) == "table" and tonumber(sourceData.width) or nil
    local sourceHeight = type(sourceData) == "table" and tonumber(sourceData.height) or nil
    local beforeWidth = previous and previous.width or sourceWidth
    local beforeHeight = previous and previous.height or sourceHeight

    if beforeWidth and beforeHeight and (width > beforeWidth or height > beforeHeight) then
        pendingPolicyReflowByItem[item] = {
            beforeWidth = beforeWidth,
            beforeHeight = beforeHeight,
            reason = previous and "observed-policy-change" or "initial-policy-migration",
        }
    end
    observedPolicyByItem[item] = { width = width, height = height, reason = reason }
end

local function adjustedItemData(item, sourceData)
    local width, height, reason = Module.getUnrotatedSize(item)
    if not width or type(sourceData) ~= "table" then return sourceData end
    observePolicy(item, width, height, reason, sourceData)

    local cached = adjustedDataByItem[item]
    if cached and cached.source == sourceData and cached.reason == reason then
        return cached.data
    end

    local data = {}
    for key, value in pairs(sourceData) do data[key] = value end
    setmetatable(data, getmetatable(sourceData))
    data.width = width
    data.height = height
    adjustedDataByItem[item] = { source = sourceData, reason = reason, data = data }
    return data
end

local function installSizeWrapper()
    if TetrisItemData._getItemData == installedGetItemData then return false end

    local original = TetrisItemData._getItemData
    if type(original) ~= "function" then return false end
    local wrapper = function(item, noSquish)
        return adjustedItemData(item, original(item, noSquish))
    end
    installedGetItemData = wrapper
    TetrisItemData._getItemData = wrapper
    return true
end

local function collectPolicyDimensions(inventory, stacks)
    local dimensions = {}
    for _, stack in ipairs(stacks or {}) do
        local item = ItemStack.getFrontItem(stack, inventory)
        local width, height = Module.getUnrotatedSize(item)
        if width then
            local fullType = tostring(safeCall(item, "getFullType", ""))
            local size = dimensions[fullType]
            if size then
                size.width = math.max(size.width, width)
                size.height = math.max(size.height, height)
            else
                dimensions[fullType] = { width = width, height = height }
            end
        end
    end
    return dimensions
end

local function buildRenderDataOverlayFromDimensions(sourceData, fallbackData, dimensions)
    local overlay = setmetatable({}, { __index = sourceData })
    for fullType, size in pairs(dimensions) do
        local source = sourceData[fullType] or (fallbackData and fallbackData[fullType]) or {}
        local data = {}
        for key, value in pairs(source) do data[key] = value end
        setmetatable(data, getmetatable(source))
        data.width = math.max(tonumber(data.width) or 0, size.width)
        data.height = math.max(tonumber(data.height) or 0, size.height)
        overlay[fullType] = data
    end
    return overlay
end

function Module.buildRenderDataOverlay(inventory, stacks, sourceData, fallbackData)
    return buildRenderDataOverlayFromDimensions(
        sourceData, fallbackData, collectPolicyDimensions(inventory, stacks))
end

local function installRenderStackLoopWrapper()
    if ItemGridUI.renderStackLoop == installedRenderStackLoop then return false end

    local original = ItemGridUI.renderStackLoop
    if type(original) ~= "function" then return false end
    local wrapper = function(self, inventory, stacks, alphaMult, searchSession)
        local itemData = TetrisItemData._itemData
        local devItemData = TetrisItemData._devItemData
        local dimensions = collectPolicyDimensions(inventory, stacks)
        TetrisItemData._itemData = buildRenderDataOverlayFromDimensions(itemData, nil, dimensions)
        TetrisItemData._devItemData = buildRenderDataOverlayFromDimensions(
            devItemData, itemData, dimensions)

        local ok, result = pcall(original, self, inventory, stacks, alphaMult, searchSession)
        TetrisItemData._itemData = itemData
        TetrisItemData._devItemData = devItemData
        if not ok then error(result) end
        return result
    end
    installedRenderStackLoop = wrapper
    ItemGridUI.renderStackLoop = wrapper
    return true
end

function Module.correctRenderInstructions(renderInstructions, instructionCount)
    local corrected = 0
    for index = 1, tonumber(instructionCount) or 0 do
        local instruction = renderInstructions and renderInstructions[index]
        local item = instruction and instruction[2]
        if item then
            local beforeWidth, beforeHeight = instruction[5], instruction[6]
            local width, height, reason = Module.applySizePolicy(
                item, beforeWidth, beforeHeight, instruction[8] == true)
            if reason and (width ~= beforeWidth or height ~= beforeHeight) then
                instruction[5], instruction[6] = width, height
                corrected = corrected + 1

                local state = reason .. ":" .. tostring(instruction[8] == true)
                    .. ":" .. tostring(width) .. "x" .. tostring(height)
                if correctedRenderStateByItem[item] ~= state then
                    correctedRenderStateByItem[item] = state
                    renderCorrectionCount = renderCorrectionCount + 1
                    if renderCorrectionCount <= RENDER_CORRECTION_TRACE_LIMIT then
                        trace(string.format(
                            "event=render-size-corrected item=%s before=%sx%s after=%dx%d state=%s",
                            tostring(safeCall(item, "getFullType", "unknown")),
                            tostring(beforeWidth), tostring(beforeHeight), width, height, state))
                    end
                end
            end
        end
    end
    return corrected
end

function Module.getRenderCorrectionCount()
    return renderCorrectionCount
end

local function installRenderWrapper()
    if ItemGridUI._bulkRenderGridStacks == installedBulkRenderGridStacks then return false end

    local original = ItemGridUI._bulkRenderGridStacks
    if type(original) ~= "function" then return false end
    local wrapper = function(drawingContext, renderInstructions, instructionCount, playerObj, itemBgTex)
        Module.correctRenderInstructions(renderInstructions, instructionCount)
        return original(drawingContext, renderInstructions, instructionCount, playerObj, itemBgTex)
    end
    installedBulkRenderGridStacks = wrapper
    ItemGridUI._bulkRenderGridStacks = wrapper
    return true
end

local function installAttachmentWrappers()
    require "TimedActions/ISUpgradeWeapon"
    require "TimedActions/ISRemoveWeaponUpgrade"

    if ISUpgradeWeapon.complete ~= installedUpgradeComplete then
        local original = ISUpgradeWeapon.complete
        local wrapper = function(self, ...)
            local beforeWidth, beforeHeight = Module.getUnrotatedSize(self.weapon)
            local result = original(self, ...)
            refreshWeaponGrid(self.weapon, beforeWidth, beforeHeight, "attach",
                safeCall(self.character, "getPlayerNum", 0))
            return result
        end
        installedUpgradeComplete = wrapper
        ISUpgradeWeapon.complete = wrapper
    end

    if ISRemoveWeaponUpgrade.complete ~= installedRemoveComplete then
        local original = ISRemoveWeaponUpgrade.complete
        local wrapper = function(self, ...)
            local beforeWidth, beforeHeight = Module.getUnrotatedSize(self.weapon)
            local result = original(self, ...)
            refreshWeaponGrid(self.weapon, beforeWidth, beforeHeight, "detach",
                safeCall(self.character, "getPlayerNum", 0))
            return result
        end
        installedRemoveComplete = wrapper
        ISRemoveWeaponUpgrade.complete = wrapper
    end
end

local function getOwningPlayerNum(item)
    local container = safeCall(item, "getContainer", nil)
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and container and safeCall(container, "isInCharacterInventory", false, player) then
            return playerNum
        end
    end
    return 0
end

local processingPendingPolicyReflow = false
local function processPendingPolicyReflows()
    if processingPendingPolicyReflow then return end
    for weapon, pending in pairs(pendingPolicyReflowByItem) do
        pendingPolicyReflowByItem[weapon] = nil
        processingPendingPolicyReflow = true
        local ok, failure = pcall(refreshWeaponGrid, weapon,
            pending.beforeWidth, pending.beforeHeight, pending.reason, getOwningPlayerNum(weapon))
        processingPendingPolicyReflow = false
        if not ok then
            trace("event=reflow-failed item="
                .. tostring(safeCall(weapon, "getFullType", "unknown"))
                .. " error=" .. tostring(failure))
        end
        return
    end
end

local installationLogged = false
function Module.install()
    installSizeWrapper()
    installRenderStackLoopWrapper()
    installRenderWrapper()
    installAttachmentWrappers()
    if not installationLogged then
        installationLogged = true
        trace("event=installed dataWrapper="
            .. tostring(TetrisItemData._getItemData == installedGetItemData)
            .. " renderLoopWrapper="
            .. tostring(ItemGridUI.renderStackLoop == installedRenderStackLoop)
            .. " renderWrapper="
            .. tostring(ItemGridUI._bulkRenderGridStacks == installedBulkRenderGridStacks)
            .. " pistol=2x1 compact=2x2 standard=3x2 large=4x2")
    end
end

_G.CPI_GaelFirearmTetrisSizes = Module

if Events and Events.OnGameStart and Events.OnGameStart.Add then
    Events.OnGameStart.Add(Module.install)
end
if Events and Events.OnTick and Events.OnTick.Add then
    Events.OnTick.Add(processPendingPolicyReflows)
end

return Module
