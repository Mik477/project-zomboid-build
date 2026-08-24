if _G.GGSASF_ScriptPatchesApplied then return end
_G.GGSASF_ScriptPatchesApplied = true

local Definitions = require("GaelGunStoreCoreFixes/Definitions")
local scriptManager = getScriptManager()
local missingItems = {}
local missingRecipes = {}
local patchedDoubleClicks = 0
local patchedFirearms = 0
local patchedVisualItems = 0
local addedTags = 0

local function getItem(fullType)
    local item = scriptManager:getItem(fullType)
    if not item then
        missingItems[fullType] = true
    end
    return item
end

local function requireRecipe(recipeName)
    if not scriptManager:getCraftRecipe(recipeName) then
        missingRecipes[recipeName] = true
        return false
    end
    return true
end

local function setDoubleClickRecipe(fullType, recipeName)
    local item = getItem(fullType)
    if item and requireRecipe(recipeName) then
        item:setDoubleClickRecipe(recipeName)
        patchedDoubleClicks = patchedDoubleClicks + 1
    end
end

local function addTag(fullType, tag)
    local item = getItem(fullType)
    if item and not item:hasTag(tag) then
        item:getTags():add(tag)
        addedTags = addedTags + 1
    end
end

local function patchFirearm(definition)
    local item = getItem(definition.item)
    if not item then
        return
    end
    local parameters = {
        AmmoType = definition.ammoType,
        AmmoBox = definition.ammoBox,
        MagazineType = definition.magazineType,
        MaxAmmo = definition.maxAmmo,
        ClipSize = definition.clipSize,
    }
    for name, value in pairs(parameters) do
        if value ~= nil then
            item:DoParam(name .. " = " .. tostring(value))
        end
    end
    patchedFirearms = patchedFirearms + 1
end

for _, firearm in ipairs(Definitions.firearmScriptPatches) do
    patchFirearm(firearm)
end

local function patchVisualItem(definition)
    local item = getItem(definition.item)
    if not item then
        return
    end
    for name, value in pairs(definition.parameters or {}) do
        item:DoParam(name .. " = " .. tostring(value))
    end
    for _, modelWeaponPart in ipairs(definition.modelWeaponParts or {}) do
        item:DoParam("ModelWeaponPart = " .. modelWeaponPart)
    end
    patchedVisualItems = patchedVisualItems + 1
end

for _, definition in ipairs(Definitions.itemVisualPatches or {}) do
    patchVisualItem(definition)
end
for _, package in ipairs(Definitions.boxes) do
    setDoubleClickRecipe(package.item, package.recipe)
end
for _, package in ipairs(Definitions.projectilePacks) do
    setDoubleClickRecipe(package.item, package.recipe)
end
for _, carton in ipairs(Definitions.cartons) do
    setDoubleClickRecipe(carton, Definitions.cartonRecipe)
end
for _, recipeName in ipairs(Definitions.customRecipes) do
    requireRecipe(recipeName)
end

local ok, ammoProfiles = pcall(require, "GGS_AmmoProfiles")
if ok and ammoProfiles and ammoProfiles.rounds then
    for _, profile in pairs(ammoProfiles.rounds) do
        if profile.ammoFullType then
            addTag(profile.ammoFullType, ItemTag.AMMO)
        end
    end
else
    print("[GaelGunStoreCoreFixes] Could not load GGS_AmmoProfiles; using the tags already supplied by GaelGunStore.")
end

for _, fullType in ipairs({
    "Base.GrenadeAmmo",
    "Base.GrenadeAmmo_incendiary",
    "Base.RPG7_RocketAmmo",
}) do
    addTag(fullType, ItemTag.AMMO)
end
for _, fullType in ipairs(Definitions.shotgunAmmo) do
    addTag(fullType, ItemTag.AMMO)
    addTag(fullType, ItemTag.SHOTGUN_SHELL)
end
for _, fullType in ipairs(Definitions.pistolMagazines) do
    addTag(fullType, ItemTag.PISTOL_MAGAZINE)
end

local function sortedKeys(values)
    local keys = {}
    for key in pairs(values) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local itemFailures = sortedKeys(missingItems)
local recipeFailures = sortedKeys(missingRecipes)
print(string.format(
    "[GaelGunStoreCoreFixes] Patched %d firearm definitions, %d Gael visual items, %d package actions, and %d compatibility tags (%d missing items, %d missing recipes).",
    patchedFirearms,
    patchedVisualItems,
    patchedDoubleClicks,
    addedTags,
    #itemFailures,
    #recipeFailures
))
if #itemFailures > 0 then
    print("[GaelGunStoreCoreFixes] Missing items: " .. table.concat(itemFailures, ", "))
end
if #recipeFailures > 0 then
    print("[GaelGunStoreCoreFixes] Missing recipes: " .. table.concat(recipeFailures, ", "))
end
