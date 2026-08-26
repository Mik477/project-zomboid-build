# Multiplayer ragdoll feasibility for Project Zomboid 42.20.3

Date: 2026-08-20

## Decision

A **client-local cosmetic multiplayer ragdoll mod is feasible** for the current four-player hosted build, but it requires a Java bytecode patch through ZombieBuddy. A normal Lua-only mod cannot enable the engine's ragdoll path.

A **server-authoritative, synchronized physics ragdoll implementation is not a reasonable first mod**. Build 42.20.3 does not transmit ragdoll simulation state or corpse bone poses, and the dedicated-server path explicitly skips ragdoll-pose physics initialization. Building true synchronization would require a custom authority model, packet protocol, interpolation, final-pose persistence, and extensive compatibility work.

The recommended next step is an opt-in, client-only prototype restricted to lethal zombie hits. Its physics must be cosmetic: it must not decide zombie health, corpse identity, inventory, reanimation, or authoritative world position.

## Evidence from the exact build

The repository targets Project Zomboid `42.20.3`, Steam build `24909800`. The inspected `projectzomboid.jar` SHA-256 was:

```text
80E405A4BFC42F6072E75B3735F458A6514143DA011D3226007DED305A442F44
```

This fingerprint is evidence for this investigation, not a redistributable artifact. No game class or decompiled source is stored in the repository.

### Hard multiplayer gates

Bytecode inspection of the installed Build 42.20.3 classes found two direct multiplayer exclusions:

1. `zombie.characters.IsoGameCharacter.canRagdoll()` returns `false` when either `GameClient.client` or `GameServer.server` is true.
2. `zombie.characters.IsoGameCharacter.canUseCurrentPoseForCorpse()` also returns `false` in client or server mode.

The first gate prevents the animation graph from starting a ragdoll. The second prevents `IsoDeadBody` from capturing the simulated bone transforms when the zombie becomes a corpse.

The current English UI text independently says that **Use Physics Hit Reactions** is automatically unchecked in multiplayer because ragdolls are not yet available in MP. The official first Build 42 multiplayer announcement also states that ragdoll functionality was disabled in multiplayer and would return in later patches. No official release through the August 17, 2026 `42.20.3` hotfix explicitly reverses that statement:

- <https://steamcommunity.com/games/108600/announcements/detail/1818752592123010>
- See `docs/RAGDOLL-MP-SOURCE-NOTES.md` for the dated release timeline.

### Dormant server setting is not working support

Build 42.20.3 exposes `UsePhysicsHitReaction=false` in server options, and `canRagdoll()` contains a later check for that server option. However, that check is unreachable in ordinary multiplayer because the method returns at the earlier client/server gate.

This looks like partial or future-facing scaffolding, not an activation switch.

More importantly, `zombie.characters.RagdollBuilder.initializeRagdollPose()` returns immediately when `GameServer.server` is true. Therefore, simply removing the first gate and changing the server option would not give a dedicated server an initialized ragdoll simulation.

### Current packets do not synchronize ragdolls

The Build 42.20.3 `ZombiePacket` contains root position, health, state, direction, movement prediction, target, and boolean state flags. It has no ragdoll-controller state, rigid-body transforms, bone transforms, simulation timestamp, or physics seed.

`NetworkZombieVariables.Flag` includes normal zombie state such as on-floor and fall-on-front, but no ragdoll or ragdoll-simulation flag.

`DeadCharacterPacket` synchronizes the character/corpse identifiers, root position, angle, fall-on-front state, reanimation time, and inventory handling. It does not transmit the corpse's `diedBoneTransforms`.

`IsoDeadBody` does have `ragdollFall` and `diedBoneTransforms`, and those fields participate in local save/load and rendering. When a corpse is constructed, it can copy every current animation bone transform—but the multiplayer pose gate prevents this in the unmodified game, and the death packet does not distribute those transforms.

Consequences:

- separate clients cannot produce identical Bullet simulations;
- clients may see different resting limb poses;
- the server remains authoritative for the corpse root location and inventory;
- a locally captured ragdoll pose may disappear after cell unload/reload or server restart because the server never stored that client pose.

## Why Lua alone is insufficient

Lua can set animation variables, knock a zombie down, choose hit reactions, and send client/server commands. The existing `TrippingZombies` mod already does this and documents that its Build 42 ragdoll chance is single-player only.

However, all animation transitions into `*-ragdoll` states require `canRagdoll`. Because that method is hard-disabled in multiplayer below Lua, a Lua mod cannot unlock the physics controller.

Lua can still be useful for configuration, event selection, diagnostics, and optional one-shot synchronization messages after a Java patch opens the engine gate.

## Existing multiplayer claims

Two current Workshop items claim experimental real MP ragdolls through ZombieBuddy:

- [Ragdolls in Multiplayer](https://steamcommunity.com/sharedfiles/filedetails/?id=3775936786) claims synchronized resting positions.
- [MP Ragdolls (Experimental)](https://steamcommunity.com/sharedfiles/filedetails/?id=3776721222) says it was tested on one home server and needs more testing.

These pages are evidence that other authors have also found a Java-agent route around the engine guard. They are not evidence that corpse authority, late joins, persistence, performance, or failure recovery are solved. No author-owned public source repository was found for either item, so neither binary should be added to this private build without an isolated audit and disposable-world test.

## Practical prototype: cosmetic client-local deaths

The smallest viable prototype needs two Java patches on every participating client:

1. Permit `IsoGameCharacter.canRagdoll()` on a multiplayer client while preserving the remaining safety checks: active-model availability, scene culling, clothing compatibility, current-state compatibility, and the maximum-active-ragdoll cap.
2. Permit `IsoGameCharacter.canUseCurrentPoseForCorpse()` on a multiplayer client so the locally created corpse can retain the final visual bone pose.

It also needs a controlled activation rule:

- zombies only;
- lethal hits only for the first version;
- melee deaths first, with firearms/vehicles left to vanilla behavior;
- close to the local player and not scene-culled;
- maximum five active simulations initially;
- no physics-derived authoritative displacement;
- immediate fallback to vanilla animations when any prerequisite fails.

The prototype should deliberately accept that two players may see different limb poses. That is the main tradeoff that makes it possible without a new network protocol.

## Local root movement and corpse looting

The proposed combination of local root movement plus a larger loot radius is **conditionally feasible**, but only if “local root movement” is implemented as a presentation offset rather than by relocating the client-side `IsoDeadBody` in the world model.

Build 42.20.3 discovers loot containers by scanning the player’s current square and the eight surrounding squares. A small corpse-only extension to that discovery radius is straightforward. The multiplayer inventory protocol is the harder constraint: a corpse container is identified by its square coordinates and its index in that square’s static-moving-object list. The server resolves those values against its own authoritative world. It does not identify the corpse container by the corpse’s newer object ID.

Therefore:

- Merely increasing the loot radius does **not** repair a corpse whose actual client-side square/index was changed by local physics. The client would serialize the displaced coordinates and index, while the server would look for the corpse at its original coordinates and reject or misresolve the container.
- The safe design keeps the logical `IsoDeadBody` at the server-provided root, square, and static-object index. It stores a separate client-local settled root/pose offset and applies that offset only to corpse rendering, shadows, highlighting, and object picking.
- A corpse-only proximity scan can then expose the authoritative container when the player is near the visually displaced body. It should not globally extend access to every container.
- The visual offset should be bounded, same-floor only, and rejected or clamped when it crosses a wall, closed door, window, stair boundary, unloaded square, or a configured maximum distance. A first limit of roughly `2.5` tiles is more defensible than an unrestricted offset.
- Vehicle deaths should remain vanilla in the first version. They generate the largest displacements and the most collision edge cases, while the requested benefit is specifically melee deaths.

The engine normally follows the physics root during an active ragdoll: `AnimationPlayer` calculates movement toward the ragdoll controller’s desired character position, and `IsoGameCharacter.doDeferredMovementFromRagdoll()` changes the character’s actual X/Y/Z. In multiplayer, however, `DeadCharacterPacket.processClient()` teleports the dying character to the server-supplied root before creating the corpse. Preserving the locally settled result without changing corpse identity therefore requires capturing the client-local final transform before that correction and converting the displacement into the separate render offset described above.

This design keeps ordinary item transactions, corpse removal, server saves, reanimation, and late joins tied to the authoritative corpse. The local visual offset is disposable presentation state: it may be lost on chunk reload or reconnect unless the mod stores and restores it client-side.

## What happens when a ragdoll settles or dies

A ragdoll does not remain an active physics simulation forever under the normal engine path.

1. The Bullet ragdoll reports a simulation state such as active, wanting deactivation, or sleeping.
2. The controller tracks head and pelvis movement. Movement greater than a small threshold refreshes a `1.5`-second settle timer; vehicle contact also refreshes it.
3. Once the body is no longer moving, Bullet reports the island sleeping, and the settle timer expires, the controller marks `isSimulating=false` and deactivates the rigid bodies.
4. The animation graph sees `isSimulationActive=false`.
5. A living zombie can then transition from `onground-ragdoll` into the appropriate front/back get-up animation. A dead zombie transitions into ordinary `onground`, where `ZombieOnGroundState` calls the death/corpse path.
6. `IsoDeadBody` copies the zombie root and, when allowed, copies every current bone transform into `diedBoneTransforms`. The zombie is removed and the corpse becomes a static world object. The corpse is a frozen pose, not a continuously simulated ragdoll.

That sequence describes the natural local animation path. In multiplayer, the authoritative death packet can arrive before the client’s ragdoll has naturally reached its sleeping transition. The packet corrects the character to the server root and calls the network death path immediately. The prototype must therefore snapshot the latest safe local bones and displacement before that correction, create the authoritative corpse without delay, and apply only the saved presentation pose/offset afterward. It must never postpone server-owned corpse creation while waiting for local physics to finish.

In single player, those frozen transforms are serialized with the corpse. In unmodified multiplayer, the death packet contains the root position, angle, front/back flag, reanimation time, identity, and inventory, but not the ragdoll bone transforms. A patched client can freeze its own local pose for the current session, but the server cannot persist or reproduce that pose. After reconnect, chunk reload, or server restart, the custom local pose should be expected to disappear or fall back to the server’s ordinary corpse representation unless the mod adds separate client-side pose persistence.

An important failure case is a ragdoll that never reaches the sleeping condition because it jitters against a vehicle, wall, stair, another ragdoll, or a compatibility mod. Since get-up and dead-body transitions wait for `isSimulationActive=false`, the prototype needs a hard watchdog that abandons physics after a bounded wall-clock timeout, freezes the best available pose, and returns to the vanilla state path.

### Proof of technical expressibility

A non-deployed proof-of-concept was compiled under the ignored `.local/ragdoll-poc/` directory against ZombieBuddy `2.3.2`. It successfully expresses both required return-value patches:

- `IsoGameCharacter.canRagdoll()`
- `IsoGameCharacter.canUseCurrentPoseForCorpse()`

The proof was **not loaded into Project Zomboid**, did not alter game files, and did not modify the server or save. Compilation only proves that ZombieBuddy's patch API can represent the required hooks; it does not prove runtime stability.

ZombieBuddy's first-party modding guide documents Java JAR patches and client/server path selection:

- <https://github.com/zed-0xff/ZombieBuddy>
- Workshop item `3619862853`

Each player would have to install the ZombieBuddy native agent and approve the exact Java-mod JAR fingerprint. Java mods run with unrestricted system permissions, so the source and reproducible build should be reviewable by the group.

## Hosted-server behavior

Local server logs show that the hosted server loads the Workshop mod's Lua content but does not show ZombieBuddy agent initialization. The current standalone server launcher also lacks the ZombieBuddy agent argument.

That prevents the same Java patch from silently becoming server-side. For the recommended cosmetic design this is desirable: the server should remain unmodified and authoritative.

If later work requires a server Java patch, it must use a separate, explicit, reversible server launcher change. That would be a different deployment project and would need its own version gate and rollback path.

## Interactions with the current modpack

### Tripping Zombies

The current hosted profile sets `ragdollTripChance = 100`, but the installed mod itself labels this behavior single-player-only because the engine returns false in multiplayer.

Once the gate is patched, this setting would suddenly become active and could ragdoll living zombies, not only dying zombies. That expands the state-machine and synchronization risk substantially. The first prototype should force the effective ragdoll trip chance to zero or explicitly reject live-zombie ragdolls.

The installed Build 42 version deliberately routes a ragdoll trip through `knockDown(true)` and the normal `falldown -> falldown-ragdoll -> onground-ragdoll` chain. When physics settles, `isSimulationActive` becomes false; the on-ground reanimation timer then permits a front- or back-facing get-up. This is the correct recovery route.

The mod also documents a separate broken route: the `bumped` sprinter-ragdoll animation can hand control to physics before animation-end variables are emitted, leaving a living zombie stranded in the bumped state. Its current code avoids that route for ragdoll-capable zombies, refuses to retrip zombies already on the floor or ragdolling, and adds a post-trip cooldown.

For multiplayer, enabling live trip ragdolls still needs custom integration. The trip decision runs in server-side Lua, where the unpatched server reports that it cannot ragdoll. Patching only clients will not safely turn the server’s trip decision into a physics trip. Patching the dedicated server’s ragdoll gate is also unsafe because the server skips ragdoll-pose physics initialization. A future trip implementation should leave the server on the ordinary synchronized knockdown state and send a small cosmetic trip-start event to clients.

Expected live-ragdoll risks are:

- temporary mismatch between the server hitbox/root and each client’s visible body;
- correction snaps when the server resumes movement or the zombie gets up;
- a zombie killed while locally ragdolling being teleported to the server death root before corpse creation;
- get-up being blocked indefinitely if physics never sleeps;
- incompatible collision mods moving the local root again while physics owns it;
- reanimation starting at the authoritative corpse root rather than the local visual offset.

Live-zombie ragdolls should therefore remain a later stage after death-only ragdolls prove stable. They require a hard simulation timeout, suppression of repeat trips, offset clearing on get-up/death/reanimation, and acceptance that hit detection remains server-authoritative at a location that may not exactly match the visible limbs.

### Skully's Zombie Collision

This mod recognizes falling, dying, and ragdoll states and moves nearby zombie roots apart. Its default work is bounded, but combining local collision pushes with client-local physics may increase visible divergence or corpse snapping.

The first test should compare:

1. ragdoll prototype alone;
2. prototype plus Skully's Zombie Collision;
3. prototype plus Skully's collision with reduced hitboxes/distance.

### Bandits and other state-aware mods

Bandits code checks `isRagdoll()` and `isRagdollSimulationActive()`. Enabling those states in MP activates code paths that are currently normally unreachable. This does not prove incompatibility, but it makes Bandits a required test case.

## Performance assessment

A client-local design adds no continuous ragdoll network traffic. Its cost is mainly per-client Bullet physics, bone updates, and rendering. The engine already exposes a maximum-active-ragdoll setting because lower values improve performance.

For the first four-player test:

- cap active ragdolls at `5`;
- only simulate within the local combat area;
- do not ragdoll living/tripping zombies;
- measure host and remote-client frame time, not only average FPS;
- record a dense-horde melee test and a repeated-kill test;
- watch for corpse interaction failures, animation-state stalls, and increasing memory use.

The engine's internal controller allocates fixed buffers of 245 floats for skeleton data and 77 floats for rigid-body data per active update path. This does not indicate the total cost, but it shows why continuously synchronizing full poses would be much more expensive than a purely local effect.

A future synchronized implementation would need to send at least rigid-body or selected-bone transforms plus identifiers, sequence numbers, and timestamps. Even before protocol overhead, frequent snapshots for multiple simultaneous ragdolls would add meaningful bandwidth and packet-rate pressure to a game already limited to `300` processed packets per client per second in the current server configuration.

## Full synchronization: what would be required

A true shared ragdoll result would require all of the following:

1. Select a ragdoll authority, probably the client currently controlling that zombie or a specially instrumented server.
2. Send a reliable ragdoll-start event containing zombie identity, start time, reaction, impulse, orientation, and authority epoch.
3. Stream compressed rigid-body snapshots or periodically corrected poses.
4. Interpolate snapshots on non-authoritative clients.
5. Reconcile root movement against server-authoritative zombie coordinates.
6. Send and validate one final settled pose.
7. Persist that pose with the server-owned corpse and reproduce it after cell reload.
8. Handle authority transfer, disconnects, late joiners, packet loss, corpse removal, reanimation, and save migration.
9. Patch or extend networking on every client and the server without conflicting with packet validation or future game updates.

This is possible in the broad sense that unrestricted Java code can implement a custom protocol, but it is effectively an engine feature rather than a small gameplay mod. It should not be attempted before a cosmetic prototype proves that the underlying ragdoll state machine survives multiplayer at all.

## Recommended staged plan

### Stage 0: static proof — complete

- Confirmed both multiplayer gates.
- Confirmed dedicated-server ragdoll-pose initialization is skipped.
- Confirmed current zombie/death packets contain no pose synchronization.
- Compiled a non-deployed ZombieBuddy patch proof.

### Stage 1: isolated client prototype

- Create a repo-owned, disabled-by-default mod for exact version `42.20.3`.
- Patch client ragdoll and corpse-pose gates only.
- Add a sandbox/client option and an unmistakable experimental warning.
- Restrict activation to lethal melee deaths.
- Keep server configuration and authoritative corpse root/square/index unchanged.
- Preserve local displacement as a bounded render/picking offset, not by moving `IsoDeadBody` between squares.
- Add corpse-only proximity discovery for the bounded visual offset.
- Add a hard settle watchdog and vanilla fallback.

### Stage 2: controlled two-client test

- Use a disposable save and a minimal mod list.
- Test host view versus one remote-client view.
- Verify corpse looting, removal, reanimation, reconnect, cell reload, and server restart.
- Record frame-time and error-log evidence.

### Stage 3: current-pack compatibility test

- Add Tripping Zombies with ragdoll trips disabled.
- Add Skully's Zombie Collision.
- Add Bandits and other state-aware mods.
- Increase to four players only after the two-client matrix passes.

### Stage 4: decide whether divergence is acceptable

If local pose differences and reload resets are acceptable, keep the feature cosmetic and stop. If the group requires identical corpse poses, the project changes into a custom synchronized-physics protocol and should be reassessed before implementation.

## Final recommendation

Proceed only with **Stage 1: a disabled-by-default, client-only, lethal-death cosmetic prototype**. It is technically plausible, bounded, reversible, and should be performant with a five-ragdoll cap.

Local settled displacement is acceptable only as a bounded visual offset over the server-owned corpse. Do not relocate the logical corpse, patch the hosted server, enable live-zombie trip ragdolls, or attempt continuous bone synchronization in the first version.
