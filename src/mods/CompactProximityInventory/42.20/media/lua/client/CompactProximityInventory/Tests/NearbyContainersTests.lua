if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local NearbyContainers = require("CompactProximityInventory/NearbyContainers")

TestFramework.registerTestModule("Compact Proximity Inventory", "Craft container filter", function()
    local Tests = TestUtils.newTestModule("client/CompactProximityInventory/Tests/NearbyContainersTests.lua")

    function Tests.test_filters_only_the_compact_display_marker()
        local first = ItemContainer.new("crate", nil, nil)
        local marker = NearbyContainers.getMarker(0)
        local second = ItemContainer.new("counter", nil, nil)
        local containers = ArrayList.new()
        containers:add(first)
        containers:add(marker)
        containers:add(second)

        local filtered = NearbyContainers.filterCraftContainers(containers)

        TestUtils.assert(filtered:size() == 2)
        TestUtils.assert(filtered:get(0) == first)
        TestUtils.assert(filtered:get(1) == second)
        TestUtils.assert(NearbyContainers.getMarker(0) == marker)
    end

    function Tests.test_preserves_nil_container_list()
        TestUtils.assert(NearbyContainers.filterCraftContainers(nil) == nil)
    end

    TestFramework.addCodeCoverage(Tests, NearbyContainers, "NearbyContainers")
    return Tests
end)
