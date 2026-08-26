if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local Definitions = require("GaelGunStoreCoreFixes/Definitions")

TestFramework.registerTestModule("Gael Gun Store Core Fixes", "Definitions", function()
    local Tests = TestUtils.newTestModule("client/GaelGunStoreCoreFixes/Tests/DefinitionsTests.lua")

    function Tests.test_package_items_and_recipes_are_unique()
        local items = {}
        local recipes = {}
        for _, package in ipairs(Definitions.boxes) do
            TestUtils.assert(not items[package.item])
            items[package.item] = true
            TestUtils.assert(package.rounds > 0)
            recipes[package.recipe] = true
        end
        for _, package in ipairs(Definitions.projectilePacks) do
            TestUtils.assert(not items[package.item])
            items[package.item] = true
            TestUtils.assert(package.rounds == 8)
            recipes[package.recipe] = true
        end
        TestUtils.assert(recipes[Definitions.cartonRecipe] == nil)
    end

    function Tests.test_all_unpack_recipes_are_registered_for_safe_transfer()
        local unpackRecipes = Definitions.getUnpackRecipeSet()
        for _, package in ipairs(Definitions.boxes) do
            TestUtils.assert(unpackRecipes[package.recipe] == true)
        end
        for _, package in ipairs(Definitions.projectilePacks) do
            TestUtils.assert(unpackRecipes[package.recipe] == true)
        end
        TestUtils.assert(unpackRecipes[Definitions.cartonRecipe] == true)
    end

    function Tests.test_storage_sets_are_disjoint_and_exclude_drums()
        local magazines = Definitions.toSet(Definitions.pistolMagazines)
        local shells = Definitions.toSet(Definitions.shotgunAmmo)
        for fullType in pairs(magazines) do
            TestUtils.assert(not string.find(fullType, "Drum", 1, true))
            TestUtils.assert(not shells[fullType])
        end
    end

    function Tests.test_carton_definition_has_twenty_unique_types()
        local cartons = Definitions.toSet(Definitions.cartons)
        local count = 0
        for _ in pairs(cartons) do
            count = count + 1
        end
        TestUtils.assert(count == 20)
        TestUtils.assert(cartons["Base.3030Carton"] == true)
        TestUtils.assert(cartons["Base.ShotgunShellsCarton"] == true)
    end

    function Tests.test_every_custom_recipe_loaded()
        TestUtils.assert(#Definitions.customRecipes == 14)
        for _, recipeName in ipairs(Definitions.customRecipes) do
            TestUtils.assert(getScriptManager():getCraftRecipe(recipeName) ~= nil)
        end
    end

    function Tests.test_feed_device_catalog_is_complete_and_unique()
        local devices = {}
        for _, device in ipairs(Definitions.feedDevices) do
            TestUtils.assert(not devices[device.item])
            TestUtils.assert(device.rounds > 0)
            devices[device.item] = device.rounds
        end
        TestUtils.assert(#Definitions.feedDevices == 66)
        TestUtils.assert(devices["Base.22LRClip"] == 25)
        TestUtils.assert(devices["Base.303Drum50"] == 40)
        TestUtils.assert(devices["Base.308Clip30"] == 30)
        TestUtils.assert(devices["Base.Bullets50Clip"] == 30)
        TestUtils.assert(devices["Base.762x39Drum73"] == 73)
        TestUtils.assert(devices["Base.792x57Clip40"] == 40)
    end

    function Tests.test_compatibility_definition_sets_are_targeted()
        TestUtils.assert(#Definitions.firearmScriptPatches == 4)
        TestUtils.assert(#Definitions.magazineMapAliases == 3)
        TestUtils.assert(#Definitions.magazineMapRemovals == 3)
        TestUtils.assert(#Definitions.lootClones == 3)
        TestUtils.assert(#Definitions.obsoleteLootItems == 2)
        TestUtils.assert(#Definitions.itemVisualPatches == 13)
        TestUtils.assert(#Definitions.magazineFamilyExpansions == 1)

        local obsolete = Definitions.toSet(Definitions.obsoleteLootItems)
        for _, clone in ipairs(Definitions.lootClones) do
            TestUtils.assert(clone.source ~= clone.item)
            TestUtils.assert(not obsolete[clone.source])
            TestUtils.assert(not obsolete[clone.item])
        end
    end

    function Tests.test_visual_compatibility_patches_are_targeted()
        local patches = {}
        for _, patch in ipairs(Definitions.itemVisualPatches) do
            TestUtils.assert(not patches[patch.item])
            patches[patch.item] = patch
        end
        TestUtils.assert(patches["Base.BenelliM3"].parameters.Icon == "BenelliM4")
        TestUtils.assert(patches["Base.G36"].parameters.Icon == "G36C")
        TestUtils.assert(patches["Base.M9A3"].parameters.Icon == "M9")
        TestUtils.assert(patches["Base.PKM"].parameters.Icon == "PKP")
        TestUtils.assert(patches["Base.Rhino60DS"].parameters.Icon == "Rhino20DS")
        TestUtils.assert(patches["Base.303Clip20"].parameters.Icon == "792x57Clip")
        TestUtils.assert(patches["Base.303Drum50"].parameters.Icon == "308Drum60")
        TestUtils.assert(patches["Base.BizonClip64"].parameters.Icon == "22LRDrum100")
        TestUtils.assert(patches["Base.30_06Clip"].parameters.Icon == "792x57Clip")
        TestUtils.assert(patches["Base.30_06Clip40"].parameters.Icon == "308Clip40")
        TestUtils.assert(patches["Base.Bullets50Clip"].parameters.Icon == "308Box150")
        TestUtils.assert(patches["Base.9mmClip70old"].parameters.WorldStaticModel == "Clip_9mmClip70old")
        TestUtils.assert(patches["Base.9mmClip100old"].parameters.WorldStaticModel == "Clip_9mmClip100old")
    end

    return Tests
end)
