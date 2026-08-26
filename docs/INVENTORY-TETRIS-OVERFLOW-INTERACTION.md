# Inventory Tetris Overflow Interaction

## Scope

`InventoryTetrisOverflowInteractionFix` is a client-only compatibility mod for Project Zomboid `42.20.3`, Steam build `24909800`, and Inventory Tetris Workshop item `3775513231`.

Inventory Tetris intentionally renders items that do not fit a container grid in a synthetic overflow strip to the right of that grid. The patch preserves that placement, container contents, and recovery behavior.

## Diagnosed gap

`GridOverflowRenderer` already draws overflow stacks and forwards mouse down, mouse up, right click, and double click to `ItemGridUI`. However:

- `ItemGridContainerUI.findGridStackUnderMouse` searches only real grid UIs, so the existing inventory tooltip path cannot resolve an overflow stack.
- `GridOverflowRenderer` has no mouse-move or outside-release handlers, so a drag prepared by its forwarded mouse-down never reaches Inventory Tetris's native drag start/cancellation path.
- Rendering skips stale overflow stacks whose item no longer resolves, but the original hit tester still advances one cell for them. Every later visible icon can therefore be tested at a different position from the one where it is drawn.

## Behavior

The compatibility wrapper:

- preserves real-grid hover precedence and falls back to `GridOverflowRenderer.findStackDataUnderMouse` only while the overflow renderer is hovered;
- forwards `onMouseMove` and `onMouseMoveOutside` to the owning `ItemGridUI`, retaining the original drag owner prepared by upstream mouse-down;
- converts renderer-local coordinates into grid-local coordinates before forwarding `onMouseUpOutside`;
- mirrors the renderer's valid-front-item filter and row/column spacing when resolving an overflow interaction cell;
- leaves upstream click, context menu, double-click, controller, rendering, stacking, transfer, multiplayer, and auto-recovery implementations unchanged.

Synthetic overflow coordinates are not valid placement cells. Dragging from overflow into a real grid/container or outside the UI is supported; dropping onto an overflow icon is not treated as a placement target.

## Verification

Run:

```powershell
./scripts/Test-InventoryTetrisOverflowInteractionFix.ps1
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
```

The focused validator exact-hashes the reviewed Inventory Tetris renderer, container hit-test, grid event, and tooltip seams. Its executable Lua fixture verifies normal-grid precedence, overflow tooltip fallback, stale-stack filtering, drag forwarding, outside-release coordinate conversion, upstream click preservation, and idempotent installation.

For runtime acceptance, open an intentionally overfilled world container and verify hover tooltips, configured click actions, right-click/double-click, and dragging from each overflow icon into a valid grid cell, another container, and outside the UI. Repeat after scrolling and with a grouped stack. Confirm overflow placement remains outside the grid and no duplicate transfers or ghost stacks appear.
