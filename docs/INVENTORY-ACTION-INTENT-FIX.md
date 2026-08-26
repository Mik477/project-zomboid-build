# Inventory Action Intent Fix

Date: 2026-08-25
Target: Project Zomboid 42.20.3, Steam build 24775755

## Problem

Vanilla Wear and detachable-magazine context actions are ordered multi-action sequences. Clothing from a bag or world container is transferred to the player main inventory before `ISWearClothing`. Magazine insertion transfers the magazine and firearm as needed, equips the firearm in the primary hand, and then runs `ISInsertMagazine`; ejection similarly stages/equips the firearm before `ISEjectMagazine`.

The observed session started before ZombieBuddy approved `KahluaObjectPoolConcurrencyFix`. Repeated `ReturnValues.put(ReturnValues.java:61)` failures then reset those sequences after a prerequisite transfer, leaving the item in main inventory. Inventory Tetris later rehomed unpositioned items after its queue-idle grace period. Repeated clicks also queued duplicate sequences whose later terminal actions became invalid after the first sequence changed item state.

## Behavior

`InventoryActionIntentFix` wraps only the final installed `ISInventoryPaneContextMenu.wearItem`, `onInsertMagazine`, `onEjectMagazine`, and `equipWeapon` functions. The first Wear or magazine request delegates unchanged. A later equivalent request is ignored only while the same player's queue already contains:

- `ISWearClothing` for the same clothing runtime ID.
- The same insert operation for the same firearm and selected magazine runtime ID, or the same eject operation for the same firearm runtime ID.
- Gael `SetMagTypeAction` or `PostSwapAction` for the same firearm and selected magazine family.

Gael's repo-owned alternate-family selector consults the same optional pending-intent function before staging another magazine swap. Different items, opposite insert/eject operations, and an explicitly different magazine family remain independent. Runtime object identity is preferred, with positive runtime ID matching for multiplayer reference replacement; unset or negative IDs never establish equivalence.

Before delegating an equip, the wrapper predicts only the hand references that vanilla `ISEquipWeaponAction:complete()` will displace. If a displaced item is not already positioned and cannot fit in the main inventory or a worn player container, it queues Inventory Tetris's existing one-tick `_handleDropItem()` transfer before the equip. Existing floor transfers are not duplicated. Hotbar, worn, force-heavy, undroppable, vehicle, external-source, unavailable-floor, and full-floor cases remain vanilla-owned or fail safe.

The module does not replace `ISTimedActionQueue`, `ISInventoryTransferAction`, multiplayer item transactions, or Inventory Tetris auto-drop. It does not bypass main-inventory or hand staging, synthesize retries, mutate world inventory directly, or return items to an external source that may no longer be safe or reachable.

## Validation

```powershell
./scripts/Test-KahluaObjectPoolRace.ps1
./scripts/Test-InventoryActionIntentFix.ps1
./scripts/Test-InventoryTetrisTransferDiagnostics.ps1
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
```

The intent validator exact-hashes the reviewed vanilla context menu and timed-action queue, vanilla Wear/insert/eject/equip/floor-transfer actions, Inventory Tetris grid/auto-drop implementation, and Gael magazine swap source. Its executable Kahlua fixture verifies first-click delegation, equivalent-repeat suppression, different-family and opposite-operation independence, Gael post-swap handling, retry after terminal removal, return-value preservation, idempotent installation, no-fit displacement, duplicate floor-transfer suppression, and protected/fail-safe cases.

## Runtime acceptance

Fully exit Project Zomboid after approving any changed ZombieBuddy JAR, then restart. Before testing, require both activation messages:

```text
[KahluaObjectPoolConcurrencyFix] Isolated object pools active; legacy pool returns quarantined.
[InventoryActionIntentFix] Duplicate intent and displaced-hand floor fallback active.
```

Test one click and rapid repeated clicks for helmet/pants Wear and magazine insert/eject from main inventory, a worn backpack, and a world container. Repeat with free space and with the Inventory Tetris grid near capacity. Then fill every player grid, hold a disposable item, and equip another item; the displaced item must transfer to the floor before the equip completes and require manual pickup. Acceptance requires no Kahlua pool exception, one terminal action per equivalent intent, no duplicate floor transfers, start evidence plus the expected final worn/clip/hand state, and no recovery move before the timed-action queue is genuinely idle. Gael's one-tick `SetMagTypeAction` and `PostSwapAction` may complete between observer ticks, so validate their selected family through final modData, visual, and clip state rather than requiring an individual trace. Observer outcomes describe state at removal and do not claim that one particular action caused an already-existing state.
