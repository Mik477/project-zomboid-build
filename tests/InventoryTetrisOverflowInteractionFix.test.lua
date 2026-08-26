local repositoryRoot = InventoryTetrisOverflowInteractionFixRepositoryRoot or "."
package.path = table.concat({
    repositoryRoot .. "/src/mods/InventoryTetrisOverflowInteractionFix/42.20/media/lua/client/?.lua",
    repositoryRoot .. "/src/mods/InventoryTetrisOverflowInteractionFix/42.20/media/lua/client/?/?.lua",
    package.path,
}, ";")

local callbacks = {}
Events = {
    OnGameStart = {
        Add = function(callback) callbacks[#callbacks + 1] = callback end,
    },
}

local originalFindCalls = 0
local ItemGridContainerUI = {
    findGridStackUnderMouse = function(self)
        originalFindCalls = originalFindCalls + 1
        return self.normalStack
    end,
}
local originalMouseDown = function() return "upstream-mouse-down" end
local GridOverflowRenderer = {
    onMouseDown = originalMouseDown,
    getYPositionsForOverflow = function() return { 0, 35 } end,
    findStackDataUnderMouse = function(self, x, y)
        if x >= 0 and x < 32 and y >= 0 and y < 32 then
            return self.containerGrid.overflow[1]
        end
        if x >= 0 and x < 32 and y >= 35 and y < 67 then
            return self.containerGrid.overflow[2]
        end
        return nil
    end,
}
local ItemStack = {
    getFrontItem = function(stack) return stack.item end,
}

package.preload["InventoryTetris/UI/Container/ItemGridContainerUI"] = function()
    return ItemGridContainerUI
end
package.preload["InventoryTetris/UI/Container/GridOverflowRenderer"] = function()
    return GridOverflowRenderer
end
package.preload["InventoryTetris/Model/ItemStack"] = function() return ItemStack end
package.preload["InventoryTetris/Settings"] = function() return { CELL_SIZE = 32 } end

local Fix = require("InventoryTetrisOverflowInteractionFix")
assert(#callbacks == 1, "entry point must register one startup installer")
callbacks[1]()

local normalStack = {}
local overflowStack = {}
local overflowRenderer = {
    hovered = true,
    getMouseX = function() return 12 end,
    getMouseY = function() return 34 end,
    isMouseOver = function(self) return self.hovered end,
    findStackDataUnderMouse = function(self, x, y)
        assert(x == 12 and y == 34, "overflow hit test must use renderer-local mouse coordinates")
        return overflowStack
    end,
}
local containerUi = setmetatable({
    normalStack = normalStack,
    overflowRenderer = overflowRenderer,
}, { __index = ItemGridContainerUI })

assert(containerUi:findGridStackUnderMouse() == normalStack, "normal grid hit must retain precedence")
containerUi.normalStack = nil
assert(containerUi:findGridStackUnderMouse() == overflowStack, "overflow stack must participate in tooltip hit testing")
overflowRenderer.hovered = false
assert(containerUi:findGridStackUnderMouse() == nil, "non-hovered overflow must not produce a stack")
assert(originalFindCalls == 3, "wrapper must delegate to the original hit test exactly once")

local calls = {}
local gridUi = {
    getAbsoluteX = function() return 10 end,
    getAbsoluteY = function() return 20 end,
    onMouseMove = function(self, dx, dy)
        calls[#calls + 1] = { "move", dx, dy }
        return "move-result"
    end,
    onMouseMoveOutside = function(self, dx, dy)
        calls[#calls + 1] = { "move-outside", dx, dy }
        return "move-outside-result"
    end,
    onMouseUpOutside = function(self, x, y)
        calls[#calls + 1] = { "up-outside", x, y }
        return "up-outside-result"
    end,
}
local renderer = setmetatable({
    gridUi = gridUi,
    getAbsoluteX = function() return 100 end,
    getAbsoluteY = function() return 200 end,
}, { __index = GridOverflowRenderer })

assert(renderer:onMouseMove(3, 4) == "move-result", "overflow movement must start the native grid drag")
assert(renderer:onMouseMoveOutside(5, 6) == "move-outside-result", "outside movement must retain native drag ownership")
assert(renderer:onMouseUpOutside(7, 8) == "up-outside-result", "outside release must reach native cancellation/drop handling")
assert(calls[1][1] == "move" and calls[1][2] == 3 and calls[1][3] == 4)
assert(calls[2][1] == "move-outside" and calls[2][2] == 5 and calls[2][3] == 6)
assert(calls[3][1] == "up-outside" and calls[3][2] == 97 and calls[3][3] == 188,
    "outside release coordinates must be converted into grid-local space")
assert(GridOverflowRenderer.onMouseDown == originalMouseDown, "upstream click dispatch must remain unchanged")

local staleStack = { item = nil }
local visibleStack = { item = {} }
local staleRenderer = setmetatable({
    containerGrid = { overflow = { staleStack, visibleStack } },
    inventory = {},
}, { __index = GridOverflowRenderer })
assert(staleRenderer:findStackDataUnderMouse(10, 10) == visibleStack,
    "hit-test layout must skip the same stale stacks skipped by rendering")
assert(staleRenderer:findStackDataUnderMouse(10, 40) == nil,
    "stale stacks must not leave invisible interaction cells")

local wrappedFind = ItemGridContainerUI.findGridStackUnderMouse
Fix.install()
assert(ItemGridContainerUI.findGridStackUnderMouse == wrappedFind, "installer must be idempotent")

print("Inventory Tetris overflow interaction fixtures passed.")
