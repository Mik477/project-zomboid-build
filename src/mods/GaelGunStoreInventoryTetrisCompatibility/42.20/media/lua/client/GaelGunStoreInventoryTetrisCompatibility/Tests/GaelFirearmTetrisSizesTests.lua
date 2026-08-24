if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local Sizes = require("GaelGunStoreInventoryTetrisCompatibility/GaelFirearmTetrisSizes")
local TetrisItemData = require("InventoryTetris/Data/TetrisItemData")
local ItemGridUI = require("InventoryTetris/UI/Grid/ItemGridUI")

local function fakePart(fullType)
    return { getFullType = function() return fullType end }
end

local function fakeWeapon(fullType, reloadType, swingAnim, twoHanded, stockType, ammoType, scriptTwoHanded)
    local script = {
        hasTag = function(_, tag) return tag == "Firearm" end,
        getWeaponReloadType = function() return reloadType end,
        getSwingAnim = function() return swingAnim end,
        isTwoHandWeapon = function() return scriptTwoHanded end,
    }
    return {
        IsWeapon = function() return true end,
        isRanged = function() return true end,
        hasTag = function(_, tag) return tag == "Firearm" end,
        getFullType = function() return fullType end,
        getAmmoType = function() return ammoType or "base:bullets_9mm" end,
        getWeaponReloadType = function() return reloadType end,
        getSwingAnim = function() return swingAnim end,
        isTwoHandWeapon = function() return twoHanded end,
        getScriptItem = function() return script end,
        getWeaponPart = function(_, partType)
            if partType == "Stock" and stockType then return fakePart(stockType) end
            return nil
        end,
    }
end

local function assertSize(item, expectedWidth, expectedHeight, expectedClass)
    local width, height, reason = Sizes.getUnrotatedSize(item)
    TestUtils.assert(width == expectedWidth and height == expectedHeight)
    TestUtils.assert(string.find(reason, expectedClass, 1, true) ~= nil)
end

TestFramework.registerTestModule("Compact Proximity Inventory", "Gael firearm Tetris sizes", function()
    local Tests = TestUtils.newTestModule("client/GaelGunStoreInventoryTetrisCompatibility/Tests/GaelFirearmTetrisSizesTests.lua")

    function Tests.test_representative_firearm_classes()
        assertSize(fakeWeapon("Base.G17", "handgun", "Handgun", false), 2, 1, "pistol")
        assertSize(fakeWeapon("Base.MP5K", "boltaction", "Rifle", true), 2, 2, "compact")
        assertSize(fakeWeapon("Base.AK_minidrako", "boltaction", "Rifle", true), 2, 2, "compact")
        assertSize(fakeWeapon("Base.MP5", "boltaction", "Rifle", true), 3, 2, "standard")
        assertSize(fakeWeapon("Base.M4", "boltaction", "Rifle", true), 3, 2, "standard")
        assertSize(fakeWeapon("Base.M82A3", "boltaction", "Rifle", true), 4, 2, "large")
        assertSize(fakeWeapon("Base.M240B", "boltaction", "Rifle", true), 4, 2, "large")
        assertSize(fakeWeapon("Base.BAR", "boltaction", "Rifle", true), 4, 2, "large")
        assertSize(fakeWeapon("Base.M79", "boltaction", "Rifle", true), 4, 2, "large")
        assertSize(fakeWeapon("Base.Minigun", "boltaction", "Rifle", true), 4, 2, "large")
    end

    function Tests.test_stock_state_changes_only_long_axis_policy()
        assertSize(fakeWeapon("Base.G17", "handgun", "Handgun", false, "Base.FixedStock"), 2, 2, "pistol:extended")
        assertSize(fakeWeapon("Base.MP5K", "boltaction", "Rifle", true, "Base.FixedStock"), 3, 2, "compact:extended")
        assertSize(fakeWeapon("Base.M4", "boltaction", "Rifle", true, "Base.ak_stock_fold"), 2, 2, "standard:folded")
        assertSize(fakeWeapon("Base.M4", "boltaction", "Rifle", true, "Base.ak_stock_unfolded"), 3, 2, "standard:extended")
        assertSize(fakeWeapon("Base.M4", "boltaction", "Rifle", true, "Base.FoldingStockExtended"), 3, 2, "standard:extended")
        assertSize(fakeWeapon("Base.M82A3", "boltaction", "Rifle", true, "Base.ak_stock_fold"), 4, 2, "large:folded")
    end

    function Tests.test_stock_slot_grips_do_not_extend_compact_weapons()
        assertSize(fakeWeapon(
            "Base.Remington870_Short", "shotgun", "Rifle", true, "Base.R870_Tactical_Grip"),
            2, 2, "compact:stockless")
    end

    function Tests.test_rotation_swaps_dimensions()
        local width, height = Sizes.getSize(fakeWeapon("Base.M4", "boltaction", "Rifle", true), true)
        TestUtils.assert(width == 2 and height == 3)
    end

    function Tests.test_non_firearm_is_not_overridden()
        local item = {
            IsWeapon = function() return true end,
            isRanged = function() return false end,
        }
        local width, height = Sizes.getUnrotatedSize(item)
        TestUtils.assert(width == nil and height == nil)
    end

    function Tests.test_bows_and_crossbows_keep_native_sizes_even_with_firearm_tag()
        for _, ammoType in ipairs({ "ggs:arrow_wood", "ggs:bolt_wood" }) do
            local width, height = Sizes.getUnrotatedSize(
                fakeWeapon("Base.ArcheryWeapon", "bow", "Rifle", true, nil, ammoType))
            TestUtils.assert(width == nil and height == nil)
        end
    end

    function Tests.test_explicit_classes_win_over_handgun_fallbacks()
        assertSize(fakeWeapon("Base.MP5K", "handgun", "Handgun", false), 2, 2, "compact")
        assertSize(fakeWeapon("Base.M82A3", "handgun", "Handgun", false), 4, 2, "large")
        assertSize(fakeWeapon("Base.LightLongGun", "handgun", "Handgun", false, nil, nil, true),
            3, 2, "standard")
    end

    function Tests.test_render_instructions_override_stale_weight_sizes()
        local cases = {
            { fakeWeapon("Base.M4", "boltaction", "Rifle", true), 3, 2 },
            { fakeWeapon("Base.MP5", "boltaction", "Rifle", true), 3, 2 },
            { fakeWeapon("Base.Remington870", "shotgun", "Rifle", true), 3, 2 },
            { fakeWeapon("Base.M82A3", "boltaction", "Rifle", true), 4, 2 },
        }
        local instructions = {}
        for index, case in ipairs(cases) do
            instructions[index] = { {}, case[1], 0, 0, 2, 1, 1, false }
        end

        TestUtils.assert(Sizes.correctRenderInstructions(instructions, #instructions) == #instructions)
        for index, case in ipairs(cases) do
            TestUtils.assert(instructions[index][5] == case[2])
            TestUtils.assert(instructions[index][6] == case[3])
        end
    end

    function Tests.test_render_instruction_rotation_and_instance_stock_state()
        local noStock = fakeWeapon("Base.G17", "handgun", "Handgun", false)
        local fixedStock = fakeWeapon("Base.G17", "handgun", "Handgun", false, "Base.FixedStock")
        local instructions = {
            { {}, noStock, 0, 0, 1, 1, 1, true },
            { {}, fixedStock, 0, 0, 1, 1, 1, false },
        }

        Sizes.correctRenderInstructions(instructions, #instructions)
        TestUtils.assert(instructions[1][5] == 1 and instructions[1][6] == 2)
        TestUtils.assert(instructions[2][5] == 2 and instructions[2][6] == 2)
    end

    function Tests.test_render_overlay_prevents_stale_dimension_culling()
        local inventory = {}
        local weapon = fakeWeapon("Base.M4", "boltaction", "Rifle", true)
        weapon.getContainer = function() return inventory end
        local stack = { _frontItem = weapon, itemType = "Base.M4", itemIDs = {} }
        local sourceData = { ["Base.M4"] = { width = 2, height = 1, maxStackSize = 1 } }

        local overlay = Sizes.buildRenderDataOverlay(inventory, { stack }, sourceData)
        TestUtils.assert(sourceData["Base.M4"].width == 2 and sourceData["Base.M4"].height == 1)
        TestUtils.assert(overlay["Base.M4"].width == 3 and overlay["Base.M4"].height == 2)
        TestUtils.assert(overlay["Base.M4"].maxStackSize == 1)
    end

    function Tests.test_non_firearm_render_instruction_is_untouched()
        local item = {
            IsWeapon = function() return false end,
            isRanged = function() return false end,
        }
        local instruction = { {}, item, 7, 9, 5, 6, 0.5, true }
        TestUtils.assert(Sizes.correctRenderInstructions({ instruction }, 1) == 0)
        TestUtils.assert(instruction[3] == 7 and instruction[4] == 9)
        TestUtils.assert(instruction[5] == 5 and instruction[6] == 6)
        TestUtils.assert(instruction[7] == 0.5 and instruction[8] == true)
    end

    function Tests.test_install_is_idempotent()
        Sizes.install()
        local getItemData = TetrisItemData._getItemData
        local renderStackLoop = ItemGridUI.renderStackLoop
        local bulkRender = ItemGridUI._bulkRenderGridStacks
        Sizes.install()
        Sizes.install()
        TestUtils.assert(TetrisItemData._getItemData == getItemData)
        TestUtils.assert(ItemGridUI.renderStackLoop == renderStackLoop)
        TestUtils.assert(ItemGridUI._bulkRenderGridStacks == bulkRender)
    end

    return Tests
end)
