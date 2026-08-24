if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local Selection = require("GaelGunStoreCoreFixes/AutomaticMagazineSelection")

local function fakeMagazine(ammo, capacity, condition)
    return {
        getCurrentAmmoCount = function() return ammo end,
        getMaxAmmo = function() return capacity end,
        getCondition = function() return condition end,
    }
end

local function fakeWeapon(typeName)
    return {
        getType = function() return typeName end,
    }
end

TestFramework.registerTestModule("Gael Gun Store Ammo & Storage Fixes", "Automatic magazine selection", function()
    local Tests = TestUtils.newTestModule("client/GaelGunStoreCoreFixes/Tests/AutomaticMagazineSelectionTests.lua")

    function Tests.test_magazine_scoring_prefers_ammo_then_capacity_then_condition()
        TestUtils.assert(Selection.isBetterMagazine(fakeMagazine(10, 30, 5), fakeMagazine(9, 100, 10)))
        TestUtils.assert(Selection.isBetterMagazine(fakeMagazine(10, 60, 5), fakeMagazine(10, 30, 10)))
        TestUtils.assert(Selection.isBetterMagazine(fakeMagazine(10, 60, 9), fakeMagazine(10, 60, 5)))
        TestUtils.assert(not Selection.isBetterMagazine(fakeMagazine(0, 100, 10), fakeMagazine(1, 15, 1)))
    end

    function Tests.test_expected_drum_families_are_allowed()
        local m16 = Selection.allowedMagazineSet(fakeWeapon("AssaultRifle"))
        local bren = Selection.allowedMagazineSet(fakeWeapon("CZ805"))
        local mp5 = Selection.allowedMagazineSet(fakeWeapon("MP5"))
        local mp5k = Selection.allowedMagazineSet(fakeWeapon("MP5K"))
        local mp5sd = Selection.allowedMagazineSet(fakeWeapon("MP5SD"))
        TestUtils.assert(m16["556Drum_60rnd"] and m16["556Drum_100rnd"])
        TestUtils.assert(bren["556Drum_60rnd"] and bren["556Drum_100rnd"])
        for _, allowed in ipairs({ mp5, mp5k, mp5sd }) do
            TestUtils.assert(allowed["9mmDrum50"] and allowed["9mmDrum75"] and allowed["9mmDrum100"])
        end
    end

    function Tests.test_wrapper_installation_is_idempotent()
        Selection.install()
        local beginReload = ISReloadWeaponAction.BeginAutomaticReload
        local bestReload = ISReloadWeaponAction.ReloadBestMagazine
        local magazineMenu = ISInventoryPaneContextMenu.doReloadMenuForMagazine
        local weaponMenu = ISInventoryPaneContextMenu.doReloadMenuForWeapon
        Selection.install()
        TestUtils.assert(ISReloadWeaponAction.BeginAutomaticReload == beginReload)
        TestUtils.assert(ISReloadWeaponAction.ReloadBestMagazine == bestReload)
        TestUtils.assert(ISInventoryPaneContextMenu.doReloadMenuForMagazine == magazineMenu)
        TestUtils.assert(ISInventoryPaneContextMenu.doReloadMenuForWeapon == weaponMenu)
    end

    return Tests
end)
