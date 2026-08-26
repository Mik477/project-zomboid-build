# Swap It Weapon Sling Compatibility

Target: Project Zomboid 42.20.3, Steam build 24909800

## Scope

`SwapItWeaponSlingCompatibility` is a client-only ordering and display patch for the enabled combination of Swap It, Alice's Weapon Sling, Fancy Handwork, and Clean Hot Bar. It does not replace hotbar activation, Inventory Tetris placement, transfers, or networking.

For a Swap It exchange where item A is held and item B occupies an Alice Sling Back slot, the required terminal state is:

- B is equipped;
- A is no longer in either hand;
- A owns B's former hotbar slot and retains the Alice Sling Back slot type and attachment model.
- the currently equipped primary-hand item also appears in a separate display-only `H` cell without consuming or shifting a numbered hotkey.

The equipped B does not remain in that same attachment slot. The numbered hotbar icon represents A, the item now attached to Back; `H` represents equipped B and delegates state/ammo rendering to Clean Hot Bar. Firearms and melee weapons use the same exchange path, provided the item is valid for the target slot.

## Diagnosed failures

Swap It normally attaches A at its call site before queueing B's equip. Alice intercepts that attach, records A as `AliceWeaponSling_PendingSwapItAttach`, and leaves only B's equip queued. Inventory Tetris can then migrate A into a worn container before Alice's late metadata repair; vanilla hotbar reload scans only the main inventory, so A may appear physically on Back without a numbered icon or working hotkey. Two completion outcomes also required correction:

- Vanilla returns `false` when B is already equipped. In multiplayer this is an idempotent success state, but Alice treats every false result as failure and clears pending A.
- Fancy Handwork wraps Alice's completion and may restore displaced two-handed A into the secondary hand after Alice has attached A to Back.

The compatibility patch loads after all providers. At the final Swap It `equipItem` seam it consumes only Alice's exact pending handoff and commits A through the final `attachItem` chain immediately, while A is still in the main inventory. It then delegates to the final completion/stop chain, clears a late Fancy restoration, repairs only a matching handoff when necessary, and synchronizes changed hands in multiplayer. Unrelated actions and slots claimed by another item are untouched.

## Validation

Run:

```powershell
./scripts/Test-SwapItWeaponSlingCompatibility.ps1
```

The focused validator exact-hashes the reviewed Swap It, Alice Weapon Sling, Fancy Handwork, Clean Hot Bar, vanilla equip-action, and vanilla hotbar seams. Its executable fixture covers immediate call-site attachment, held-item rendering/state delegation, already-equipped completion, Fancy's late off-hand restoration, final Back metadata/model, synchronization, unrelated actions, and idempotent installation.

Runtime acceptance:

1. Equip a firearm or melee weapon A that can use Alice Sling Back.
2. Attach a different compatible weapon B to Alice Sling Back and enable Swap It for that slot.
3. Activate B from the hotbar.
4. Confirm B is equipped and visible in `H`, A is immediately visible in B's former numbered slot and physically on Back, and A is not also in the off hand.
5. Activate the same slot again and confirm the exchange reverses without an empty slot, duplicate item, floor drop, or stuck timed action.
