local GridOverflowRenderer = require("InventoryTetris/UI/Container/GridOverflowRenderer")
local ItemGridContainerUI = require("InventoryTetris/UI/Container/ItemGridContainerUI")
local ItemStack = require("InventoryTetris/Model/ItemStack")
local OPT = require("InventoryTetris/Settings")

local Fix = {}
local installed = false
local OVERFLOW_MARGIN = 3

local function convertCoordinates(x, y, localSpace, targetSpace)
    return x + localSpace:getAbsoluteX() - targetSpace:getAbsoluteX(),
        y + localSpace:getAbsoluteY() - targetSpace:getAbsoluteY()
end

function Fix.install()
    if installed then return end
    installed = true

    local originalFindGridStackUnderMouse = ItemGridContainerUI.findGridStackUnderMouse
    ItemGridContainerUI.findGridStackUnderMouse = function(self)
        local stack = originalFindGridStackUnderMouse(self)
        if stack then return stack end

        local overflowRenderer = self.overflowRenderer
        if overflowRenderer and overflowRenderer:isMouseOver() then
            return overflowRenderer:findStackDataUnderMouse(
                overflowRenderer:getMouseX(), overflowRenderer:getMouseY())
        end
        return nil
    end

    GridOverflowRenderer.findStackDataUnderMouse = function(self, x, y)
        local overflow = self.containerGrid.overflow
        if #overflow == 0 then return nil end

        local yPositions = self:getYPositionsForOverflow()
        if #yPositions == 0 then return nil end

        local xPos = 0
        local yi = 1
        for _, stack in ipairs(overflow) do
            if ItemStack.getFrontItem(stack, self.inventory) then
                local yPos = yPositions[yi]
                if x >= xPos and x < xPos + OPT.CELL_SIZE
                    and y >= yPos and y < yPos + OPT.CELL_SIZE then
                    return stack
                end

                yi = yi + 1
                if yi > #yPositions then
                    yi = 1
                    xPos = xPos + OPT.CELL_SIZE + OVERFLOW_MARGIN
                end
            end
        end
        return nil
    end

    GridOverflowRenderer.onMouseMove = function(self, dx, dy)
        return self.gridUi:onMouseMove(dx, dy)
    end

    GridOverflowRenderer.onMouseMoveOutside = function(self, dx, dy)
        return self.gridUi:onMouseMoveOutside(dx, dy)
    end

    GridOverflowRenderer.onMouseUpOutside = function(self, x, y)
        x, y = convertCoordinates(x, y, self, self.gridUi)
        return self.gridUi:onMouseUpOutside(x, y)
    end
end

return Fix
