if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local CompactRows = require("CompactProximityInventory/CompactRows")
local SelectionPolicy = require("CompactProximityInventory/SelectionPolicy")

TestFramework.registerTestModule("Compact Proximity Inventory", "Compact row projection", function()
    local Tests = TestUtils.newTestModule("client/CompactProximityInventory/Tests/CompactRowsTests.lua")

    function Tests.test_hides_empty_rows_between_items()
        local projection = CompactRows.build(6, {
            { y = 1, height = 1 },
            { y = 4, height = 1 },
        })
        TestUtils.assert(projection.count == 2)
        TestUtils.assert(CompactRows.toSource(projection, 0) == 1)
        TestUtils.assert(CompactRows.toSource(projection, 1) == 4)
        TestUtils.assert(CompactRows.toDisplay(projection, 1) == 0)
        TestUtils.assert(CompactRows.toDisplay(projection, 4) == 1)
    end

    function Tests.test_keeps_every_row_spanned_by_tall_item()
        local projection = CompactRows.build(8, {{ y = 2, height = 3 }})
        TestUtils.assert(projection.count == 3)
        TestUtils.assert(CompactRows.toSource(projection, 0) == 2)
        TestUtils.assert(CompactRows.toSource(projection, 1) == 3)
        TestUtils.assert(CompactRows.toSource(projection, 2) == 4)
    end

    function Tests.test_empty_grid_has_no_visible_rows()
        local projection = CompactRows.build(4, {})
        TestUtils.assert(projection.count == 0)
        TestUtils.assert(CompactRows.toSource(projection, 0) == nil)
    end

    function Tests.test_automatic_container_selection_keeps_compact_mode()
        TestUtils.assert(SelectionPolicy.shouldKeepCompact(true, false))
        TestUtils.assert(not SelectionPolicy.shouldKeepCompact(true, true))
        TestUtils.assert(not SelectionPolicy.shouldKeepCompact(false, false))
    end

    TestFramework.addCodeCoverage(Tests, CompactRows, "CompactRows")
    TestFramework.addCodeCoverage(Tests, SelectionPolicy, "SelectionPolicy")
    return Tests
end)
