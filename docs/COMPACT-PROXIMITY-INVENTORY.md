# Compact Proximity Inventory

## Purpose

`CompactProximityInventory` adds a separate `Nearby (Compact)` entry to the loot-window container selector. Selecting it shows every eligible nearby container in one vertically scrollable Inventory Tetris view. Selecting an individual world container or the ground continues to show Inventory Tetris's normal, uncompressed layout.

This is original compatibility code. It was informed by the public behavior of Proximity Inventory (Workshop item `2847184718`, mod ID `ProximityInventory`) and the installed Inventory Tetris integration points (Workshop item `3775513231`, mod ID `INVENTORY_TETRIS`); it does not redistribute either Workshop mod.

## Supported versions

| Dependency | Inspected version |
| --- | --- |
| Project Zomboid | `42.20.3` / Steam build `24775755` |
| Inventory Tetris | `6.11.5-beta` |
| Proximity Inventory reference | Build 42 variant installed on 2026-08-20 |

The patch mod is version-gated to Project Zomboid `42.20.3` and declares Inventory Tetris as a required mod. `CompactProximityInventory` `0.4.0` loads immediately after `INVENTORY_TETRIS` and owns only the compact selector/projection behavior.

## Design

The synthetic selector is only a marker and compatibility list for vanilla loot controls. When it is selected, the patch passes the real nearby `ItemContainer` objects through Inventory Tetris's existing container UI. This retains the original item grids, saved positions, search state, transfers, context menus, and container rules.

The marker remains fully available to the loot UI, but it is deliberately excluded from `ISInventoryPaneContextMenu.getContainers`, the list Build 42 serializes for networked crafting. The marker has no world/player parent because it is not a physical container; serializing it caused `ContainerID.set` to reject every craft while the compact view was visible. Only that display marker is filtered. Every real nearby container—and Inventory Tetris's injected key-ring containers—remains in the crafting list, so vanilla and Neat Crafting can still use legitimate nearby ingredients.

Each displayed grid receives a view-only row projection:

- Every source row touched by an item remains visible.
- Empty rows before, between, and after items are omitted.
- A multi-row item keeps all rows it spans, so its visual shape is not cut apart.
- A grid/compartment with no occupied rows is omitted.
- A wholly empty container is collapsed to a title ending in `Empty` and sorted after non-empty containers.

The projection never changes Tetris grid data or item coordinates. Clicking the normal container button rebuilds an ordinary Inventory Tetris UI, which is the full-space editing view. The compact mode is optimized for looting: clicking, context actions, quick-transfer, dragging items out, and dropping onto an existing visible stack remain available. To place or rearrange an item in empty space, select the individual container.

Inventory transfer actions normally reselect their real source container while turning the character toward it. The patch suppresses those automatic method calls while `Nearby (Compact)` is active and restores the marker after a refresh if vanilla or another mod directly changed the selected inventory. The overview remains selected until the player explicitly chooses another container through the container controls.

## Gael firearm Tetris compatibility

The separate enabled `GaelGunStoreInventoryTetrisCompatibility` `0.1.0` mod replaces Inventory Tetris's script-weight firearm sizing with a gameplay-oriented, per-instance policy whenever GaelGunStore is active:

| Class | Footprint | Examples |
| --- | --- | --- |
| Pistol/revolver | `2×1` | M9, Glock 17, M1911, ordinary revolvers |
| Compact | `2×2` | MP5K, APC9K, short/CQB rifles, sawed-off shotguns |
| Standard long gun | `3×2` | MP5, M4, ordinary rifles, sniper rifles, shotguns |
| Large/heavy | `4×2` | M82A3, M200, belt-fed LMGs/GPMGs, grenade/rocket launchers |

The active firearm audit found 372 effective firearms and classifies them by runtime weapon properties plus explicit compact/large exception sets. Bows, crossbows, melee weapons, containers, and unrelated ranged items continue using Inventory Tetris's native calculations.

Stock state is read from the live weapon instance:

- an extended stock changes a pistol from `2×1` to `2×2`;
- an extended stock changes a compact weapon from `2×2` to `3×2`;
- an explicitly folded/collapsed/removed stock changes a standard long gun from `3×2` to `2×2`;
- large weapons remain `4×2` because the receiver/barrel/feed system dominates their packed size.

Stock-slot parts whose names contain `grip` are treated as stockless, because Gael exposes several pistol grips through the same `Stock` part slot. Only explicit stock-part names containing `fold`, `folding`, `collapsed`, `short`, `removed`, `no_stock`, or `nostock` are treated as folded. Fixed/built-in stocks are not guessed. Gael currently exposes folding-stock attachment types rather than a universal fold/unfold action, so those attachments use their compact footprint while installed.

The compatibility layer wraps Inventory Tetris's live item-size query rather than permanently replacing global full-type data. Two instances of the same gun can therefore occupy different space when their stocks differ. Version `0.3.1` also corrects the optimized render loop: Inventory Tetris otherwise reads its cached weight-based full-type data directly and can draw a long gun as `2×1` while its placement grid reserves `3×2`. A temporary per-render overlay supplies conservative policy dimensions before viewport culling, then the shared bulk-render sink applies the exact per-instance stock and rotation dimensions. The original full-type caches are restored before the call returns. Grid occupancy, stack-map collision, culling, normal rendering, compact-row projection, drag/controller previews, and rotation therefore agree without losing stock-specific sizing.

Completing a stock attachment/removal invalidates that weapon's adjusted data, marks its container dirty, and fully refreshes open inventory/loot grids. A weak per-instance policy observer also detects initial migration from stale weight-based data and server-authoritative multiplayer stock changes that bypass local timed-action completion. If an expanded footprint overlaps another stack or crosses a grid boundary, the weapon is removed only from its saved Tetris coordinates and passed through Inventory Tetris's native auto-position/overflow path; the inventory item itself is never deleted or overlapped.

Every game session logs one bounded line beginning with `[GaelFirearmTetris] session=... event=installed` and reports the data-query, render-loop, and bulk-render wrappers. The first corrected stale render states and stock-driven footprint changes log their before/after dimensions automatically; no manual trace-start marker is required.

## Manual verification

Use a disposable test save with the game and hosted server otherwise stopped during deployment.

1. Run `./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod CompactProximityInventory -WhatIf`, review the target list, then run it without `-WhatIf`.
2. Ensure `INVENTORY_TETRIS;CompactProximityInventory` are adjacent in the enabled mod order and start Project Zomboid 42.20.3.
3. Place items in two non-adjacent rows of a nearby container. Select `Nearby (Compact)` and confirm only the occupied rows render.
4. Use a multi-row item and confirm every row it spans remains contiguous.
5. Test a multi-grid world container (for example, a refrigerator) and confirm an empty compartment is absent while a non-empty compartment remains.
6. Put on an item with multiple pocket grids where supported and confirm empty pocket grids are absent in the compact projection.
7. Leave several nearby containers empty and confirm they appear after all non-empty containers as one-line `Empty` entries.
8. Click each individual container and the ground. Confirm its full original Tetris space returns and item placement/rearrangement works normally.
9. Exercise single click, double click/quick move, context menu, drag-out, loot-all, and player-to-loot quick transfer in the compact mode.
10. While `Nearby (Compact)` remains selected, complete one ordinary recipe using an ingredient in a real nearby container.
11. Unpack a Gael ammo box through both its inventory action and Neat Crafting. Confirm the box is consumed, the correct rounds appear, and the compact overview remains selected.
12. Repeat while hosting multiplayer and confirm the view does not change item positions, create duplicate transfers, or log `ContainerID.set` / `Unable to resolve container location`.
13. Verify representative firearm footprints: M9/G17 `2×1`, MP5K `2×2`, MP5/M4/ordinary shotgun `3×2`, and M82A3/M200/LMG `4×2`.
14. Attach an ordinary stock to a pistol/compact gun, then attach/remove an explicitly folding stock on a standard rifle. Confirm the grid refreshes, the expected long-axis dimension changes, and no item overlaps or disappears.
15. End the 5–10 minute session normally and confirm `[GaelFirearmTetris]` installation/size-change lines were written automatically.

The optional in-game test-framework modules cover the pure row projection cases and prove that the crafting filter removes only the synthetic marker while preserving the identity and order of real containers. Runtime UI and multiplayer behavior still require the manual pass above.

## Inventory transfer diagnostics

The enabled `InventoryTetrisTransferDiagnostics` `0.3.1` mod adds bounded client-side observation for item movement involving the local player's inventory, Wear and reload terminal actions, standalone magazine loading, weapon equip requests, Inventory Tetris recovery placement, and key-ring transfers. This is instrumentation only: it does not shorten actions, change transfer validation, or alter key-ring item data.

Every line starts with `[ITTransferDiag]` and uses a correlation ID such as `trace=I17`. Logging is enabled by default and stops after 2,500 detailed lines per game session. It records item type and runtime item ID, container kind, queue position, native-action/start evidence, multiplayer transaction state, main-inventory weight/capacity, worn/clip/ammo state, and Tetris overflow/recovery state. It does not record usernames, world coordinates, server addresses, save names, or filesystem paths.

The source inspection found two important latency stages when equipping a weapon from a backpack:

- Vanilla first queues an inventory transfer into the player's main inventory, then queues a separate `ISEquipWeaponAction` with a base duration of 50.
- On a multiplayer client, Inventory Tetris deliberately preserves vanilla's `maxTime=-1` sentinel even when its transfer-time option is disabled. The action waits for the item transaction to receive a server duration or completion/rejection result before the equip action can begin.

This means a slow swap may be queue wait, server-acknowledged transfer time, the fixed equip action, or a later Tetris recovery. The trace distinguishes those instead of reporting one combined delay.

The zombie-key-ring path has a different risk boundary. Inventory Tetris renders a key ring through a vanilla `ISInventoryPane`, splits visually identical keys into rows by key ID, clears selection whenever that pane refreshes, and bridges vanilla mouse-drag state into the Tetris UI. A failed extraction can therefore occur before an action exists (wrong/stale row or drag focus), during transfer creation/validation, during multiplayer transaction handling, or after transfer while Tetris places the key. The diagnostic covers each boundary; a live trace is still required before naming one as the actual cause.

### Capturing a useful trace

After installing the updated mod and fully restarting the game:

1. Confirm enabled `InventoryTetrisTransferDiagnostics` reports `event=installed` with `version=0.3.1` and `mode=observer-only`.
2. Start with no unrelated timed actions. Equip one weapon, place another weapon in an equipped backpack, then equip the backpack weapon once.
3. Open a key ring inside a zombie corpse. Drag one key into the main inventory, then repeat into an equipped backpack. If it fails intermittently, make three attempts without closing the popup.
4. Wear one helmet or pair of pants from a backpack, then insert and eject one firearm magazine from a backpack. Repeat each once with the main inventory near capacity.
5. Exit to the menu and copy only the `[ITTransferDiag]` lines for those attempts from `console.txt`. Keep each trace ID's lines together.

For transfer, Wear, and reload traces, the decisive fields are:

- `action-first-observed`, `queueTypes`, `queuePosition`, and `current`: the actual FIFO sequence and wait position.
- `native-action-changed`, `started-changed`, `everStarted`, and `missing-native-action-stall`: whether the queued Lua action reached its native timed action.
- `transaction-changed`, `sourceContains`, and `destinationContains`: multiplayer transfer progression.
- `inventoryWeight`, `inventoryEffectiveCapacity`, and `overflowCandidate`: capacity pressure and transient Tetris overflow.
- `worn-state-changed`, `magazine-state-changed`, and `magazine-container-changed`: final clothing/firearm/magazine state transitions.
- `action-removed outcome=...`: state when the action left the queue, not proof that this particular action caused that state.
- `recovery-candidate`, `recovery-remains`, and `recovery-resolved`: post-queue Tetris recovery progression.

For key rings, compare the first observed transfer's source/destination membership, queue position, transaction, and native-action milestones. The observer cannot see a click that never created a queue entry or name the exact `isValid()` branch; absence of a trace is therefore evidence that the fault occurred before its observation seam.

Logging can be disabled for the rest of the current game process from a Lua-capable debug console with:

```lua
InventoryTetrisTransferDiagnostics.enabled = false
```
