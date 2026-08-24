if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local Definitions = require("GaelGunStoreLootDiversification/Definitions")
local Diversification = require("GaelGunStoreLootDiversification/FirearmSpawnDiversification")

local function assertNear(actual, expected)
    TestUtils.assert(math.abs(actual - expected) < 0.000001)
end

local function totalWeight(items)
    local total = 0
    for index = 2, #items, 2 do
        total = total + items[index]
    end
    return total
end

local function allItemsExist()
    return true
end

TestFramework.registerTestModule("Gael Gun Store Ammo & Storage Fixes", "Firearm spawn diversification", function()
    local Tests = TestUtils.newTestModule("client/GaelGunStoreLootDiversification/Tests/FirearmSpawnDiversificationTests.lua")

    function Tests.test_policy_definitions_are_complete_and_bounded()
        local count = 0
        for sourceType, pool in pairs(Definitions.firearmSpawnPools) do
            count = count + 1
            TestUtils.assert(pool.retain > 0 and pool.retain < 1)
            TestUtils.assert(type(pool.ammoType) == "string")
            TestUtils.assert(#pool.replacements > 0)
            local replacements = {}
            for _, replacement in ipairs(pool.replacements) do
                TestUtils.assert(replacement ~= sourceType)
                TestUtils.assert(not replacements[replacement])
                replacements[replacement] = true
            end
        end
        TestUtils.assert(count == 19)
        TestUtils.assert(Definitions.firearmSpawnPools.Pistol.retain == 0.025)
        TestUtils.assert(Definitions.firearmSpawnPools.Shotgun.retain == 0.025)
        TestUtils.assert(Definitions.firearmSpawnPools.L94_Rifle == nil)
        TestUtils.assert(Definitions.suppressedLootItems["Base.Minigun"] == true)
    end

    function Tests.test_weighted_items_conserve_weight_and_are_idempotent()
        local items = { "Pistol", 20, "Other", 5 }
        local pools = {
            Pistol = { retain = 0.10, replacements = { "G17", "CZ75" } },
        }
        local before = totalWeight(items)
        local first = Diversification.transformWeightedItems(items, pools, allItemsExist)
        TestUtils.assert(first.occurrences == 1)
        TestUtils.assert(items[1] == "Pistol")
        assertNear(items[2], 2)
        TestUtils.assert(items[3] == "G17" and items[5] == "CZ75")
        TestUtils.assert(items[7] == "Other")
        assertNear(items[4], 9)
        assertNear(items[6], 9)
        assertNear(totalWeight(items), before)

        local length = #items
        local second = Diversification.transformWeightedItems(items, pools, allItemsExist)
        TestUtils.assert(second.occurrences == 0)
        TestUtils.assert(#items == length)
    end

    function Tests.test_namespaced_items_preserve_namespace_style()
        local items = { "Base.Shotgun", 10 }
        local pools = {
            Shotgun = { retain = 0.10, replacements = { "Mossber500" } },
        }
        Diversification.transformWeightedItems(items, pools, allItemsExist)
        TestUtils.assert(items[3] == "Base.Mossber500")
        assertNear(items[2], 1)
        assertNear(items[4], 9)
    end

    function Tests.test_missing_replacements_leave_source_unchanged()
        local items = { "Pistol", 20 }
        local pools = {
            Pistol = { retain = 0.10, replacements = { "MissingGun" } },
        }
        local stats = Diversification.transformWeightedItems(items, pools, function() return false end)
        TestUtils.assert(stats.occurrences == 0)
        TestUtils.assert(#items == 2)
        TestUtils.assert(items[2] == 20)
    end

    function Tests.test_gael_records_preserve_metadata_and_weight()
        local records = {
            { list = "PoliceStorageGuns", item = "Base.Pistol", weight = 20, sv = "prob_pistol" },
        }
        local pools = {
            Pistol = { retain = 0.25, replacements = { "G17", "CZ75", "P228" } },
        }
        local stats = Diversification.transformRecords(records, pools, allItemsExist)
        TestUtils.assert(stats.occurrences == 1)
        TestUtils.assert(#records == 4)
        assertNear(records[1].weight, 5)
        local total = 0
        for _, record in ipairs(records) do
            TestUtils.assert(record.list == "PoliceStorageGuns")
            TestUtils.assert(record.sv == "prob_pistol")
            total = total + record.weight
        end
        assertNear(total, 20)
    end

    return Tests
end)
