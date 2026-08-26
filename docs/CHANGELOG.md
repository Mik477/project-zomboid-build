# Change Log

## 0.11.2

- Fixed the remaining Downloads-folder bootstrap failure by resolving the package root inside the script body from `PSCommandPath`/`MyInvocation`, rather than relying on `PSScriptRoot` during parameter-default evaluation.
- Expanded the focused bootstrap regression to pass both package and profile paths as empty values from an extracted Downloads-style directory and require a controlled post-discovery stop.

## 0.11.1

- Fixed the friend installer failing before discovery when Windows PowerShell supplied an empty user-profile path. Profile resolution now falls back to `USERPROFILE` and otherwise reports an actionable error instead of passing an empty value to `Join-Path`.
- Added a focused empty-profile bootstrap regression and made Steam discovery ignore incomplete library/app-manifest entries.
- Revalidated the generated Java patches against the same public game version's Steam republish, build `24909800` (`projectzomboid.jar` SHA-256 `80E405A4BFC42F6072E75B3735F458A6514143DA011D3226007DED305A442F44`); deterministic patch JAR hashes remain unchanged.
- Changed friend setup to download the complete third-party Workshop list through an initial server join before running the custom-mod installer; missing prerequisites now produce that single recovery instruction instead of opening individual Workshop pages.

## 0.11.0

- Replaced the path-prompt package flow with a double-click `Install.cmd` friend bootstrap that auto-discovers the Steam installation, verifies Build 42.20.3 / Steam build 24775755, installs every repo-owned mod, and backs up then writes the exact 207-Mod-ID client activation order.
- Added the official MIT-licensed ZombieBuddy Windows installer v4.2 to generated release archives from its pinned upstream release and SHA-256. The bootstrap runs that installer rather than taking ownership of ZombieBuddy's launcher integration, update, or uninstall lifecycle.
- Integrated the exact-hash-gated Better Vehicle Dynamics manual overlay into the friend bootstrap. ZombieBuddy and Better Vehicle Dynamics remain Steam Workshop payloads; all other third-party mods remain server/Steam-distributed and are never copied into the release.
- Added archive-level validation for the official installer fingerprint, license notice, bootstrap files, complete repo-owned payload, manifest activation order, and absence of Workshop trees.
- Preserved exact installed-upstream gates for the Trash and Corpses and SecretZ Java patches, verified ZombieBuddy's native loader and launcher postconditions, and made BVD installs change-only with a rollback manifest.
- Updated `GaelGunStoreCoreFixes` to 1.0.2 by retiring its stale Walther P38 icon override and following Build 42.20.3's consolidated `.30-30` box recipe; the still-required runtime P38 magazine-map alias remains.

## 0.10.9

- Added `SwapItWeaponSlingCompatibility` 0.3.0 immediately after Swap It. The primary-hand item now has a separate display-only `H` cell with Clean Hot Bar state/ammo rendering, while numbered attachment hotkeys keep their existing positions.
- Restored Swap It's original immediate replacement ordering when Alice Weapon Sling intercepts the attach call: the formerly held firearm or melee weapon owns the vacated Back slot before the selected weapon's queued equip runs, preventing Inventory Tetris migration from erasing the hotbar entry.
- Reconciled idempotent multiplayer completion and Fancy Handwork's late off-hand restoration without changing unrelated equip actions.
- Added exact upstream hash gates and executable Kahlua fixtures for immediate call-site attachment, held-item rendering, idempotent already-equipped completion, Fancy's late restoration, final Back metadata/model, synchronization, unrelated actions, and idempotent installation.

## 0.10.8

- Corrected `InventoryTetrisOverflowInteractionFix` 0.1.1 after live acceptance found that visible overflow icons and their interaction cells could diverge. Inventory Tetris rendering skips stale stacks whose item is no longer present, while its original hit tester still consumed a slot for each stale stack.
- Replaced only the overflow hit tester with the renderer's existing valid-front-item filtering and identical row/column spacing. A deterministic stale-first/visible-second fixture now proves that the visible item owns the first cell and no invisible interaction cell remains.

## 0.10.7

- Audited all 66 Gael feed devices. Reused close installed Gael artwork for unresolved `.303` box/drum, Bizon, saved obsolete `.30-06`, and MG 131 inventory icons, and corrected invalid vintage 9mm ground-model names without redistributing assets.
- Added `InventoryTetrisOverflowInteractionFix` after the existing Inventory Tetris adapters. Overflow remains outside full grids, but its existing synthetic stacks now participate in tooltip hit testing and forward mouse drag movement/outside release to Inventory Tetris's native grid handler.
- Added exact upstream hash gates and executable Lua fixtures proving normal-grid hover precedence, overflow hover fallback, drag ownership, coordinate conversion, outside cancellation/drop dispatch, click-handler preservation, and idempotent installation.
- Live acceptance of `KahluaObjectPoolConcurrencyFix` 0.1.3 showed the isolated-pool marker, successful CS5/SV-98/Mosin equip completion, and no recurrence of the prior `ReturnValues.put(null)` failure.

## 0.10.6

- Corrected `KahluaObjectPoolConcurrencyFix` 0.1.3 after live acceptance disproved the 0.1.2 startup sanitizer. The first guarded access found zero pooled duplicates, but objects already checked out by multiple pre-patch owners were later returned into the shared pool twice and immediately restored the `ReturnValues.put(null)` failures.
- Replaced access around Kahlua's legacy static pools with isolated patch-owned pools. Only objects issued by the replacement pools are accepted back; all pre-activation returns are ignored, while weak active-owner records avoid retaining invocations abandoned by exceptions.
- Added an agent-loaded, full-`LuaJavaInvoker` regression for the exact in-flight lifecycle. It fails under 0.1.2 with `invokerFailures=2`, then completes with zero alongside the normal stress and pooled-duplicate recovery cases under 0.1.3.
- Live reproduction covered QBA, CS5, a magazine, and a baseball bat: each transfer completed, no `ISEquipWeaponAction` was queued, and repeated Kahlua exceptions affected all item types rather than firearm-specific handling.

## 0.10.5

- Fixed the remaining live `ReturnValues.put(null)` timed-action failures. ZombieBuddy retransforms Kahlua pool classes after they have already been used during bootstrap, so `KahluaObjectPoolConcurrencyFix` 0.1.2 now removes null and duplicate identity entries from all argument/return pools once under the shared lock before allowing the first patched access.
- Replaced the pool-only false-positive regression with an additional full `LuaJavaInvoker` recovery case. It deterministically reproduces the live shared-`MethodArguments` lifecycle and fails under 0.1.1; 0.1.2 reports the recovered entry and completes without invoker failures.
- Confirmed from the live trace that ground guns were transferred into main inventory but never reached `ISEquipWeaponAction`; Inventory Tetris returned those unpositioned items to the floor only after the Kahlua exception aborted queue construction. The displaced-hand floor fallback did not run.

## 0.10.4

- Fixed `KahluaObjectPoolConcurrencyFix` 0.1.1 so ZombieBuddy strict matching receives the exact arguments for all four `ReturnValues` and `MethodArguments` pool methods. The regression now loads the generated JAR through the actual ZombieBuddy agent: unguarded access produces millions of corruptions, while direct-lock and agent-patched modes both complete with zero.
- Expanded `InventoryActionIntentFix` to 0.2.0. Before an equip displaces a held item, the mod now queues Inventory Tetris's normal near-instant floor transfer only when no player grid can hold the item; positioned, hotbar, worn, force-heavy, undroppable, vehicle, and invalid-floor cases remain protected, and equivalent pending floor transfers are not duplicated.
- Expanded `InventoryTetrisTransferDiagnostics` to 0.3.1 with observer-only `ISLoadBulletsInMagazine` state. Magazine items no longer receive the firearm-only `isContainsClip()` call that polluted diagnostic sessions with secondary Kahlua errors.

## 0.10.3

- Added `InventoryActionIntentFix` 0.1.0 after all gameplay mods and before observer-only diagnostics. Equivalent repeated Wear requests for one item and insert/eject/swap requests for the same firearm, operation, and selected magazine are suppressed only while the existing terminal action remains in that player's timed-action queue; the first click still delegates to the final installed context-menu wrapper and retains vanilla transfer, equip, and FIFO ordering.
- Connected Gael's alternate-family automatic magazine path to the same optional pending-intent interface. No timed-action queue, transfer validation, multiplayer transaction, or Inventory Tetris recovery method is replaced, and different clothing items or firearms remain independent.
- Expanded `InventoryTetrisTransferDiagnostics` to 0.3.0 so restarted-session evidence includes `ISWearClothing`, `ISInsertMagazine`, `ISEjectMagazine`, `SetMagTypeAction`, and `PostSwapAction`, including native-action/start evidence, main-inventory weight/capacity, Tetris overflow candidacy, worn state, clip/ammo state, magazine-container transitions, and final state at queue removal.
- Added executable Kahlua fixtures and exact Build 42.20.3, Inventory Tetris, and Gael seam hashes. The previous runtime started before the Kahlua common JAR was approved, so every participant must fully exit and restart after applying this revision before gameplay acceptance.

## 0.10.2

- Added the exact-build `KahluaObjectPoolConcurrencyFix` common-JAR mod after a deterministic 4.8-million-operation harness reproduced null, duplicate, and exception failures in Build 42.20.3's unsynchronized `ReturnValues` and `MethodArguments` pools. One throwable-safe shared lock now covers only each pool's `get`/`put` boundary; the guarded harness completes with zero failures.
- Added server-authoritative condition and magazine-fill variety for newly generated firearm loot. Secure gun, police, military, security, and locker storage produces 70-100% condition firearms and 50-100% filled magazines; ordinary world containers use 45-90% and 25-90%; zombie loot uses 20-60% and 10-60%.
- Limited loot-state initialization to `OnFillContainer` and `IsoZombie.DoZombieInventory(boolean)` completion, including newly generated nested bags. Unique per-item markers prevent repeat processing, saved/player items are never rescanned, and the strict magazine predicate excludes weapons and requires positive capacity plus a non-empty gun-type list.
- Added exact game/ZombieBuddy gates, deterministic JAR and Java policy tests, focused static/in-game regressions, generated-package support, and a new authoritative mod-list revision for the Kahlua guard.

## 0.10.1

- Replaced `InventoryTetrisTransferDiagnostics` 0.1.0 method wrappers with a 0.2.0 observer that reads existing local-player queues and Inventory Tetris recovery candidates without invoking or replacing timed-action, UI, validation, transaction, or recovery methods. Bounded transition logs now identify missing native actions, queue progression, container membership, inferred transfer/equip outcomes, key-ring involvement, and recovery resolution.
- Added `PZPerformanceDiagnostics` 0.2.0 observer-only vehicle queue timelines with entry/exit event correlation, door/seat/animation state, and 2/5/15-second stall milestones. Inventory traces can also enter the bounded JSONL stream through a generic action-event API; universal Lua/Kahlua hooks remain forbidden.
- Enabled the transfer observer immediately before the last-loaded performance diagnostics mod, added exact Build 42.20.3/Inventory Tetris seam validation, and advanced the authoritative mod-list revision for synchronized hosted-server and client setup.

## 0.10.0

- Removed `PZPerformanceDiagnostics` interception of `LuaEventManager.triggerEvent` and every `KahluaThread.pcallvoid` overload after timed actions began failing in the shared Kahlua return-value path. Version 0.1.3 retains targeted frame, chunk, GC, animation, and `BaseVehicle.enter` probes; its validator now rejects universal Lua/Kahlua execution hooks.
- Added an agent-facing responsibility map that routes symptoms and change types to owning modules, edit paths, focused validators, deployment scripts, and cross-cutting migration rules.
- Pinned and fixture-tested all 18 Better Vehicle Dynamics overlay classes, added ZombieBuddy hash gates to diagnostics/ragdoll builders, blocked live ragdoll JAR replacement, and enforced that the client-only prototype remains absent from the shared manifest.
- Replaced the three mixed-purpose catch-all mod IDs with focused patch mods organized by upstream seam or explicit loot policy; `PZPerformanceDiagnostics` and the ragdoll prototype remain coherent standalone modules.
- Extracted Gael firearm Tetris sizing and Inventory Tetris transfer diagnostics from `CompactProximityInventory`; diagnostics are now packaged but disabled by default.
- Split Gael correctness, firearm loot diversification, and cross-mod item visuals while retaining one shared corrected ammo/magazine model inside `GaelGunStoreCoreFixes`.
- Split the ZombieBuddy common-JAR guards for Trash and Corpses and SecretZ and added one parameterized exact-hash-gated builder; the cosmetic MWP self-import log guard was retired rather than retaining a global parser hook.
- Added backup-first migration for obsolete local mod directories and moved-out Compact files, updated manifest ordering/revision, and added focused validation/documentation for the new layout.

## 0.9.26

- Fixed repeated-click vehicle entry and error popups caused by the repo-owned `PZPerformanceDiagnostics` 0.1.1 Lua action tracer. The tracer queried `getJobDelta()` before a timed action existed, wrapped queue construction in protected calls, and rethrew through `ISVehicleMenu.onEnterAux`/`onEnter`, aborting the first path/open/enter/close queue.
- Replaced the behavior-changing Lua tracer with an inert bootstrap and bumped `PZPerformanceDiagnostics` to 0.1.2. Passive Java frame, chunk, Lua-callback, animation, and `BaseVehicle.enter` probes remain; no diagnostic Lua code now replaces vehicle-menu, queue, or timed-action methods.
- Added a regression that rejects future Lua interception and compiles both client Lua entry files with Build 42's Kahlua compiler. The latest trace showed every completed `BaseVehicle.enter` returning true in 0.04–1.212 ms, so no unproven VVA/VAS behavior patch was added.

## 0.9.25

- Fixed intermittent `2×1` firearm footprints by applying conservative Gael dimensions before Inventory Tetris's optimized viewport culling and exact per-instance dimensions in its bulk renderer, keeping placement, collision, compact projection, drag previews, controller selection, and rotation consistent.
- Hardened firearm classification so explicit compact/heavy types, stock-slot grips, unfolded names, and script-level two-handed state cannot be misclassified; initial migration and multiplayer stock changes now trigger collision-aware native repositioning/overflow before a full-grid refresh.
- Added stale-render, rotation, same-type stock-state, non-firearm-preservation, and installer-idempotency regressions; bumped `CompactProximityInventory` to `0.3.1`.

## 0.9.24

- Fixed the `ModpackCompatibilityFixes` startup crash: ZombieBuddy inlines advice into game/Kahlua classes, so every runtime helper, result type, and result field reached by advice is now public across package boundaries.
- Added an executable probe compiled in an unrelated Java package to reproduce JVM access checks and prevent another package-private `IllegalAccessError` regression.
- Added guarded synchronization for the local client's `mods/default.txt`, including process checks, removal preview, and full-file backup, so client and hosted-server selections both follow the authoritative manifest.
- Bumped `ModpackCompatibilityFixes` to `0.1.1`; all participants must approve the replacement common-JAR fingerprint and fully restart.

## 0.9.23

- Removed Efficiency Skill Mod 2 (Workshop item `3374408921`, mod ID `efficiencySkillMod2`) after its timed-action wrapper produced the dominant client error storm.
- Added `ModpackCompatibilityFixes`, an exact-build ZombieBuddy common Java mod that protects dead/detached zombie clothing from Trash and Corpses' condition-zero network-removal path, lets SecretZ continue loading after its invalid `DespawnDoor` registration, and removes MWP Weapons' two no-op `Base` self-imports before the parser logs them.
- Added deterministic common-JAR build/install/package support, executable helper probes, process/backup guards, and exact SHA-256 checks for the game, ZombieBuddy, and all four reviewed Workshop source seams.
- Kept TYL/10 Years Later enabled and unchanged; its known performance and packet behavior remains outside this compatibility pass.

## 0.9.22

- Deactivated the unstable TYL callback gate/queue and retired its common Java JAR after repeated live tests prevented vegetation generation and left unreliable square markers. Original TYL `OnPlayerUpdate` and `LoadGridsquare` behavior is restored as the known baseline.
- Fixed a 4,516-error Inventory Tetris render storm when `KnownAndCollected` is active. The bundled compatibility handler calls removed Build 41 `Literature:getTeachedRecipes()` every frame; the repo-owned wrapper now temporarily hides literature instructions, delegates maps/media to the original handler, restores flags, and contains unexpected failures.
- Preserved safe independent fixes: one-second PZ Map/Pulse cadence, VAS remote close-door correction, and the outside/room guard plus cleanup for TYL bushes inside buildings.
- Reconciled the selected KnownAndCollected/SwapIt dependency set into the manifest (five Workshop items and five mod IDs), while continuing to reject redundant `ETO_B`.
- Converted `PZPerformanceFixes` back to Lua-only version `0.4.0`; its installer backs up and removes only the known obsolete common-JAR fingerprint. Added exact upstream hash and executable Build 42 Literature API regressions.

## 0.9.21

- Replaced the unavailable server-side Lua event reflection fallback with an exact-build common ZombieBuddy Java callback gate. The host now suppresses TYL `TYL_ProcessPlayerRadius` and `LoadGridsquare` closures directly in `KahluaThread.pcallvoid`; clients suppress unqueued originals while explicitly permitted bounded queue calls still run.
- Added nested, thread-local queued-TYL permits and public Lua APIs with suppression/permit/unbalanced-cleanup counters. The common JAR loads on both client and server and fails closed on a `projectzomboid.jar` hash mismatch.
- Recovered undecorated squares poisoned by the failed 0.2.0 server-marker run: outside a protected 32-tile spawn anchor, stale `TYLVEG` is cleared once, the original TYL closure runs through the bounded queue, and a compatibility marker prevents repeated processing.
- Fixed TYL bushes spawning indoors by wrapping the original global `TYL_SpawnBush` with an outside/room guard and removing existing objects carrying `modData.TYLBush` from interior squares as they load.
- Added deterministic common-JAR build/install/package support, exact callback matching and nested-permit probes, public advice visibility checks, Kahlua syntax validation, and upstream hash guards. Bumped `PZPerformanceFixes` to `0.3.0`.

## 0.9.20

- Reworked `PZPerformanceFixes` after the 0.9.19 A/B run eliminated client stutter but exposed synchronous server-side TYL processing as the new chunk-streaming bottleneck. The post-fix client window was healthy (`update p95 6.5 ms`, `p99 15.4 ms`), while the host reported `ZombieBuddy.Events unavailable` and retained both upstream callbacks.
- Added an exact-build reflection fallback that reaches the underlying `zombie.Lua.Event` callback list when ZombieBuddy's Lua API is absent, allowing the host to remove both `TYL_ProcessPlayerRadius` and synchronous TYL `LoadGridsquare` processing.
- Replaced immediate TYL square processing with a deduplicated, 768-square client queue. Work is distance-pruned to 24 tiles, limited to one square every 75 ms, and fully deferred above 8 km/h so vanilla chunk streaming/rendering always wins while driving.
- Retained the original TYL `LoadGridsquare` closure as the only behavior implementation, allowing nearby visual generation to catch up gradually when the player slows or stops without copying Workshop code.
- Added queue depth/queued/processed/dropped/pruned/deferred/failure and reflection-fallback counters to `PZPerformanceFixes_status()`, bumped the compatibility mod to `0.2.0`, and expanded exact-source and syntax regressions for the new queue policy.

## 0.9.19

- Added the measured `PZPerformanceFixes` compatibility mod after a 393-second trace showed 10 Years Later's `TYL_ProcessPlayerRadius` caused 362 of 389 update spikes, scanning up to 17,161 squares per player-tile movement and consuming 24.6 seconds of main-thread time.
- Removed TYL's redundant movement-radius callback on clients and servers, removed its `LoadGridsquare` processor on multiplayer clients, and retained authoritative server-side one-time square processing so established-save assets remain available without client-originated mod-data floods.
- Enforced a minimum 1,000 ms runtime cadence for PZ Map and PZ Pulse exporters while preserving both dashboards and slower user-selected settings.
- Added a late VAS synchronization correction so remote close-door broadcasts finish with `door:setOpen(false)` instead of the upstream close branch's erroneous open state.
- Removed redundant `ETO_B` while retaining the effective `ETO_P` variant and shared Workshop item.
- Added a direct diagnostics Lua entrypoint, changed chunk enqueue telemetry from one line per request to a counter, and bumped `PZPerformanceDiagnostics` to `0.1.1` so the next A/B run captures correlated vehicle action timelines without startup log noise.
- Added exact upstream hash guards and regression checks for TYL callback policy, exporter cadence, VAS state correction, diagnostics loading, and mod order.

## 0.9.18

- Added the exact-build, client-side `PZPerformanceDiagnostics` ZombieBuddy mod as the measurement-only first stage of the vehicle-entry and fast-travel performance patch.
- Added bounded asynchronous JSONL telemetry for update/render frame spikes, CPU versus wall time, heap/GC deltas, slow Lua callback attribution, and worker/main-thread chunk streaming phases.
- Added correlated vehicle-entry timelines across pathfinding, door actions, VAS server-command returns, `BaseVehicle.enter`, entry-animation variables, queue completion, and diagnostic-only watchdog milestones.
- Added deterministic build/tests, a local installer, package integration, and `Summarize-PZPerformanceDiagnostics.ps1` for ranking frame, Lua, chunk, and vehicle-entry outliers after a 5–10 minute session.
- Added the diagnostics mod last in the shared mod order so it observes the final VVA, VASinked, DAMN, and timed-action wrappers without modifying third-party Workshop files.

## 0.9.17

- Removed the restrained shoulder and elbow limit overrides after live frame telemetry showed Bullet correcting incompatible opening poses during its first native solver step. Restrained ragdolls now retain the vanilla joint constraints without redefining the global constraint template.
- Reduced restrained upper/lower-arm masses from `0.055` / `0.052` to `0.040` / `0.035` and reduced arm collision-capsule radii to 85% of vanilla. This lowers constraint torque and the chance of opening arm-to-torso self-contact while preserving enough mass for stable torso following.
- Retained low arm friction, zero rolling friction, arm-specific linear damping, strong angular damping, coherent whole-body locomotion, zero-net firearm pitch, and the prohibition on direct arm impulses.
- Fixed rigid-body peak frame/time and airborne-versus-floor accumulation. Added bounded `rigid-core-snapshot` events for pelvis, spine, head, legs, and their joints so first-step torso spin can be compared directly with arm motion.
- Made dedicated telemetry write its header before opening the buffered append stream and added a dynamic user-cache fallback. Extended regression coverage and bumped `MultiplayerRagdollPrototype` to `1.2.7`.

## 0.9.16

- Added a per-ragdoll native template swap around `RagdollController.addToWorld()`. Restrained deaths now create with heavier upper/lower arms (`0.055` / `0.052`), shoulder limits of `0.75`, `0.75`, `1.35`, and an elbow bend limit of `1.30`, then immediately restore the vanilla global templates.
- Reduced upper/lower-arm contact friction to `0.35` / `0.20`, disabled arm rolling friction, and added moderate arm-specific linear damping while retaining strong angular damping. No direct arm impulse or follower correction was added.
- Made coherent locomotion, firearm pitch, reaction reporting, and later correction use the same per-death mass profile. Fixed the pitch normalization so the heavier arm profile cannot add or remove whole-body momentum.
- Corrected native left/right body and joint labels. Added bounded `rigid-arm-snapshot` and `rigid-arm-summary` events with peak frame/time and airborne-versus-floor arm motion, plus explicit arm-profile apply/restore/failure counters.
- Hardened dedicated telemetry with a fresh session file, critical-event flushes, ready/failure reporting in the general debug log, and general-log arm snapshots even if the dedicated file is unavailable.
- Extended the deterministic regression harness to verify native template application/restoration, restrained masses and constraints, reduced arm friction, mass-consistent momentum, and arm telemetry. Bumped `MultiplayerRagdollPrototype` to `1.2.6`.

## 0.9.15

- Changed restrained locomotion from a deferred impulse to one coherent mass-weighted 11-body impulse before Bullet's first simulation step, so native fall selection sees the zombie's captured running velocity.
- Added a narrowly gated firearm forward-fall request for zombies moving at least `0.75 m/s` toward the shooter. Slow, retreating, melee, grounded, vehicle, explosive, and living-trip cases keep their existing orientation behavior.
- Replaced the previous tenfold torso-to-feet firearm velocity split with a gentle zero-net pitch adjustment after the first measured rigid-body frame. The pelvis, spine, head, and arms remain velocity-coherent while the legs receive only a small retaining bias.
- Removed all direct arm cancellation and continuous arm follower impulses. Arms now inherit the spine's pitch velocity and remain governed by the existing angular damping and native joint constraints.
- Replaced repeated momentum maintenance with one displacement-window correction between `80` and `180 ms`, capped at `0.30` total impulse and distributed coherently across all 11 bodies. Delayed correction remains leg-only after `120 ms`.
- Added deterministic regressions for forward-fall gating, pre-simulation locomotion, matched arm pitch velocity, zero-net pitch, one coherent displacement correction, and the absence of direct arm impulses. Bumped `MultiplayerRagdollPrototype` to `1.2.5`.

## 0.9.14

- Deferred restrained locomotion and localized firearm reaction impulses until Bullet has produced a baseline and one measured rigid-body frame. This avoids losing the intended forward-fall velocity during ragdoll initialization.
- Added a one-shot mass-scaled arm-to-parent velocity cancellation on that first measured frame. It removes up to `8 m/s` of observed relative arm velocity while leaving a small `0.35 m/s` target instead of repeatedly chasing the arm after it has already launched.
- Removed arms from the continuous parent-velocity follower. Only legs may receive later follower correction, still beginning after `120 ms`, so changing parent motion cannot repeatedly pump energy back into the arms.
- Prevented momentum maintenance from running against the same pre-initialization telemetry sample. Maintenance begins only after a subsequent measured physics frame can report the effect of the deferred impulse.
- Added deterministic regressions proving no restrained impulse occurs before measured physics, initialization occurs exactly once on the first updated frame, severe opening lower-arm velocity receives one bounded cancellation, later arm outliers receive no follower impulse, and firearm maintenance waits one additional frame.
- Bumped `MultiplayerRagdollPrototype` to `1.2.4`; clients must approve the new generated JAR fingerprint and fully restart before testing.

## 0.9.13

- Delayed parent-relative leg correction until `120 ms` after ragdoll startup so the firearm forward-fall profile can keep the feet slower than the torso during the decisive opening pitch.
- Reduced opening and sustained arm-correction gains and budgets, increased the opening deadzone, and kept every correction center-of-mass-only so forearms and upper arms follow the torso without receiving large artificial recovery velocities.
- Changed firearm hit reactions from fixed impulse magnitudes to small target velocity changes scaled by the struck rigid body's mass. Shotgun head and spine reactions now remain comparable despite their very different masses, while melee behavior remains unchanged.
- Clamped captured locomotion to `2.5 m/s` and exponentially smoothed movement-history samples, preventing single-frame multiplayer root corrections from becoming exaggerated death momentum while preserving genuine forward travel.
- Added deterministic regressions for delayed leg correction, reduced arm budgets, mass-scaled firearm reactions, direct movement clamping, and smoothed history-spike recovery.
- Bumped `MultiplayerRagdollPrototype` to `1.2.3`; clients must approve the new generated JAR fingerprint and fully restart before testing.

## 0.9.12

- Added a bounded client-local movement history sampled from `IsoZombie.update`, allowing lethal hits to recover the newest nonzero direction and speed for up to `180 ms` when the exact lethal frame reports zero displacement.
- Added a normalized firearm forward-fall profile that conserves total movement impulse while giving the pelvis, spine, head, and attached arms substantially more forward velocity than the upper and lower legs. The same profile is retained by early momentum maintenance, while melee deaths keep coherent mass-weighted movement.
- Moved parent-relative limb correction to the first measured physics frame and added a stronger, tightly bounded `0-80 ms` opening phase for arm outliers. Corrections remain center-of-mass-only, stop at floor contact or sleep, and never add direct angular impact.
- Added deterministic regressions for current-motion precedence, recent-history fallback, stale-history rejection, conserved torso-over-feet firearm momentum, ranged maintenance weighting, and immediate lower-arm stabilization.
- Bumped `MultiplayerRagdollPrototype` to `1.2.2`; clients must approve the new generated JAR fingerprint and fully restart before testing.

## 0.9.11

- Fixed rigid-body telemetry remaining at zero callbacks because the exact-build `RagdollController.simulateRagdoll(...)` exit advice could silently fail to invoke even while all other ragdoll hooks remained active.
- Added a deduplicated capture sequence around every controller update. The native `77`-float rigid-body buffer is now copied immediately from the known-working `RagdollController.update(...)` exit, with `postUpdate(...)` retained as a second-chance fallback and the original direct simulation hook retained when it works.
- Cached both successful and failed private-buffer reflection lookup so the fallback adds no repeated field-discovery work during active ragdolls. Added `rigid-fallback-capture`, `rigid-fallback-unavailable`, `rigidFallbackCaptures`, and `rigidFallbackUnavailable` diagnostics.
- Added a deterministic regression proving a missed direct advice callback still establishes exactly one valid telemetry baseline and that a working direct callback is not duplicated by either fallback layer.
- Bumped `MultiplayerRagdollPrototype` to `1.2.1`; clients must approve the new generated JAR fingerprint and fully restart before collecting another telemetry session.

## 0.9.10

- Added a short adaptive momentum-maintenance window for restrained deaths. When native telemetry proves the center of mass retained less than 75% of the captured pre-death speed, the prototype adds at most `0.18` impulse per frame and `0.45` total, distributed coherently over all 11 bodies with no lift.
- Added parent-relative limb following from `60-280 ms` after ragdoll start. Only limbs exceeding a `1.25` relative-speed deadzone receive center-of-mass correction, with strict per-frame and lifetime budgets and no angular or off-center limb impulse.
- Reduced restrained limb sleeping thresholds toward vanilla and lengthened deactivation time so arms and legs are not frozen early in a collision-created pose; strong angular damping remains in place while the follower suppresses severe translational whipping.
- Moved full `rigid-frame`, `rigid-joints`, and per-correction telemetry into a dedicated bounded session log below the Project Zomboid cache `Logs/MultiplayerRagdollPrototype` directory. Project Zomboid's rotating debug log now keeps only compact lifecycle, momentum, and final-summary events.
- Added deterministic regressions proving low forward velocity produces exactly one coherent 11-body correction, coherent motion produces no limb correction, one lower-arm outlier receives one small opposing impulse, and correction stops at floor contact.
- Bumped `MultiplayerRagdollPrototype` to `1.2.0`; clients must approve the new generated JAR fingerprint and fully restart before testing.

## 0.9.9

- Added exact native rigid-body telemetry for marked death ragdolls by copying the `77`-float `RagdollController.simulateRagdoll(...)` output immediately after every physics step.
- Added bounded full-pose snapshots at valid frames `1`, `2`, `3`, `4`, `6`, `8`, `12`, `16`, `24`, `32`, `48`, `64`, `96`, `128`, `192`, and `256`; intermediate frames are still processed in memory without producing log strings.
- Each `rigid-frame` records all 11 body positions relative to the pelvis, quaternions, estimated linear and angular velocity vectors, movement relative to the torso, center-of-mass displacement and velocity, forward/lateral/vertical velocity, coherence RMS, sleeping, floor, upright, and back-facing state. Absolute world positions are never written.
- Added all 10 anatomical joint traces for baseline distance, current stretch/compression, and relative-angle change, plus final per-body and per-joint maxima before the authoritative death-packet marker is removed.
- Fixed the old `motion-sample` baseline so `RagdollController.isFirstFrame()` and invalid controller coordinates cannot create a false displacement from world origin.
- Increased the diagnostic trace ceiling from `2,000` to a still-bounded `12,000` lines per session and added aggregate rigid-frame, snapshot, invalid-frame, and summary counters.
- Added deterministic fake-buffer regressions proving coherent translation remains coherent, world coordinates stay redacted, and isolated lower-arm displacement, spin, elbow stretch, and elbow-angle change are detected.
- Bumped `MultiplayerRagdollPrototype` to `1.1.0`; clients must approve the new generated JAR fingerprint and fully restart before collecting new telemetry.

## 0.9.8

- Fixed restrained ragdolls losing forward momentum because the arms and legs used much stronger linear damping than the torso. Every rigid body now shares the vanilla `0.05` linear damping, preserving the coherent velocity change applied at death.
- Kept limbs visually restrained through angular damping instead: arms use `0.9997`, legs use `0.997`, and their shorter deactivation windows and higher sleeping thresholds help them settle without pulling against torso translation.
- Changed pre-death locomotion transfer from `0.75x` to a one-for-one velocity-to-impulse conversion while retaining the existing `3.25` multiplayer-correction clamp.
- Routed Java diagnostics through Project Zomboid's native `DebugType.General` logger when available, with `System.out` retained only as a test/startup fallback.
- Added bounded `motion-sample` traces at simulation samples `1`, `2`, `4`, `8`, `16`, and `32`, reporting only relative pelvis, desired-root, and character displacement plus forward projection and sleeping state.
- Expanded `hit-enter` traces with frame duration, raw frame displacement, and the engine-reported displacement used to calculate locomotion velocity.
- Updated the regression probe to enforce one-for-one movement transfer, uniform linear damping, angular-only limb restraint, native log routing, and the new motion-sample diagnostics.
- Bumped `MultiplayerRagdollPrototype` to `1.0.1`; clients must approve the new generated JAR fingerprint and fully restart before testing.
- Kept the prototype client-only and absent from the `servertest1` server `Mods=` list.

## 0.9.7

- Added default `restrained` ragdoll mode for lethal melee and firearm hits. It captures the zombie's pre-hit movement, normalizes it by real frame time, clamps multiplayer corrections, and distributes one coherent velocity change across all 11 rigid bodies according to their exact normalized masses.
- Split impact reaction from locomotion: head hits receive only a tiny head impulse, every other reaction redirects to the spine, arms and legs never receive direct hit impulses, and restrained deaths add no upward launch or repeated torso assistance.
- Replaced staged weapon-specific death falls in restrained mode with the fast generic ragdoll handoff so running zombies keep moving in their existing direction instead of being animated into a backward collapse.
- Added strong arm linear/angular follower damping, moderate leg damping, and low pelvis/spine damping so limbs settle around the moving torso without removing root momentum.
- Corrected localized firearm classification so a 9 mm Sten carrying the generic `Rifle` category no longer receives rifle reaction force.
- Expanded trace output with movement direction, frame-normalized speed, source, total movement impulse, affected-part count, localized reaction part, and localized reaction impulse.
- Expanded the fake-engine regression to verify frame-rate normalization, correction clamping, mass-proportional whole-body impulses, no limb hit impulses, head/spine mapping, restrained dynamics, and absence of repeated assistance.
- Bumped `MultiplayerRagdollPrototype` to `1.0.0`; clients must approve the new generated JAR fingerprint and fully restart before testing.
- Kept the prototype client-only and absent from the `servertest1` server `Mods=` list.

## 0.9.6

- Suppress `RagdollController.uploadAnimationBonePreviousTransformsToRagdoll()` only for marked lethal death ragdolls in `stabilized` and `assisted` modes, preserving the current animation pose while preventing raw per-bone animation deltas from launching the arms.
- Keep `legacy`, unmarked, vehicle, trip, and ordinary single-player ragdolls on the vanilla initial-velocity path.
- Added the `initial-velocities-suppressed` trace event and `initialVelocitySuppressions` status counter so each live test can prove that the initialization hook ran before the controlled pelvis impulse.
- Extended the fake-engine regression to require mode isolation, repeated suppression during controller reinitialization, and public advice visibility.
- Bumped `MultiplayerRagdollPrototype` to `0.9.0`; clients must approve the new generated JAR fingerprint and fully restart before testing.
- Kept the prototype client-only and absent from the `servertest1` server `Mods=` list.

## 0.9.5

- Redirect every custom lethal-hit impulse to the pelvis, including head, shoulder, arm, and leg reactions, so hit location selects animation/force scale without injecting torque into the neck or limbs.
- Reduced firearm and melee force substantially: shotgun `16/1` horizontal/upward, rifles `13/0.75`, ordinary handguns `10/0.5`, and melee `6–10/0.25`.
- Corrected the previous stabilization pass, which had unintentionally lowered upper-arm angular damping below vanilla and reduced sleeping thresholds. Upper arms now use `0.995` angular damping, limbs retain vanilla contact friction, and `1.9/3.0` sleep thresholds settle residual motion sooner.
- Changed the default quality mode from `assisted` to `stabilized`. Optional assisted mode now adds only a `150 ms`, `1.2`-total pelvis impulse and never pushes the spine or limbs.
- Expanded the fake-engine regression to require pelvis-only impulses, bounded weapon force/lift, reinforced upper-arm damping, restored friction, higher sleep thresholds, and single-body optional assistance.
- Bumped `MultiplayerRagdollPrototype` to `0.8.0`; clients must approve the new generated JAR fingerprint and fully restart before testing.
- Kept the prototype client-only and absent from the `servertest1` server `Mods=` list; corpse ownership, inventory, square, and loot position remain authoritative.

## 0.9.4

- Added a client-local hybrid ragdoll quality pass for eligible lethal melee and firearm hits: a one-shot directional impact impulse, normalized per-body damping/friction/sleep tuning, and a maximum 350 ms pelvis/spine assistance window.
- Seed firearm, spear, knife/small-blade, and general melee deaths from existing ragdoll animation nodes before passive Bullet physics takes over; this improves the initial silhouette without pretending the engine exposes GTA-style joint motors or target-pose control.
- Added runtime A/B modes: `legacy` leaves the ragdoll controller untouched, `stabilized` applies the initial impulse and body tuning, and default `assisted` also applies bounded torso guidance.
- Added bounded diagnostics for custom impulses, dynamics tuning, and torso assistance plus deterministic regressions for mode isolation, all 11 rigid-body updates, weapon animation selection, and left/right reaction mapping.
- Bumped `MultiplayerRagdollPrototype` to `0.7.0`; clients must approve the new generated JAR fingerprint and fully restart before testing.
- Kept the prototype client-only and absent from the `servertest1` server `Mods=` list; authoritative corpse identity, inventory, square, and loot position remain unchanged.

## 0.9.3

- Retired the obsolete Gael `OnNewCraft` transfer-completion wrapper now that the Compact Proximity marker is excluded from networked crafting containers.
- Restored Build 42's native one-click queue: packages in backpacks/nearby containers transfer into Pockets and then unpack automatically without a second command.
- Kept `SafeAmmoUnpack.lua` as a compatibility no-op so additive deployments overwrite the previously installed wrapper; bumped `GaelGunStoreAmmoStorageFixes` to `0.1.1`.
- Added static rejection of future `OnNewCraft` overrides and an executable function-identity regression proving vanilla crafting remains untouched.

## 0.9.2

- Fixed the remaining multiplayer ragdoll failure proven by the lethal-hit traces: setting ragdoll flags and reporting `wasHit` opened permission checks but never selected a ragdoll animation track, so Bullet never created a ragdoll controller.
- Force the exact `staggerback-knockeddown-ragdoll` action and advanced-animation state before lethal melee or firearm damage is applied, including walking, attacking, staggered, falling-but-not-grounded, and getting-up zombies.
- Defer `ZombieFallDownState.execute()` for at most 1.5 seconds while ragdoll physics starts, preserve the queued authoritative death packet while simulation is active, and release vanilla corpse creation immediately after settlement or startup timeout.
- Added bounded transition-state traces and a deterministic fake-engine lifecycle regression covering the ragdoll track, controller startup, active simulation, timeout suppression, and final corpse release.
- Bumped `MultiplayerRagdollPrototype` to `0.6.0`; clients must approve the new generated JAR fingerprint and fully restart before testing.
- Kept the client-only prototype out of the `servertest1` server mod list and preserved server ownership of corpse identity, inventory, square, and loot position.

## 0.9.1

- Fixed multiplayer crafting while `Nearby (Compact)` is selected by excluding only its parentless display marker from Build 42's networked crafting-container list.
- Preserved the complete compact stacked looting view, row/compartment projection, selection persistence, real nearby containers, and Inventory Tetris key-ring containers.
- Restored both vanilla inventory crafting and Neat Crafting, allowing Gael ammo boxes to be consumed and produce their configured rounds instead of merely moving to main inventory before `ContainerID.set` failed.
- Added an in-game marker-filter regression module, static project guards, and a composed Lua harness; bumped `CompactProximityInventory` to `0.2.1`.

## 0.9.0

- Added correlated `[CPInvDiag]` lifecycle logging for local-player inventory transfers, weapon equip requests, timed-action queue wait, multiplayer transaction duration/acknowledgement, final hand state, and Inventory Tetris recovery placement.
- Added key-ring popup diagnostics for row identity, vanilla/Tetris drag ownership, transfer requests, stale source-item rejection, destination rules, server rejection, and final container state.
- Kept instrumentation behavior-neutral and privacy-bounded: no usernames, coordinates, server addresses, save names, or filesystem paths; detailed logging is capped at 2,500 lines per session.
- Added deterministic core and mocked runtime-hook regression tests and bumped `CompactProximityInventory` to `0.2.0`.

## 0.8.0

- Diagnosed the missing hosted-server ragdolls from the new per-hit traces: lethal axe damage was recognized correctly, but every hit was rejected as `not-client` before the ragdoll gate.
- Confirmed ZombieBuddy `2.3.2` implements `Utils.isClient()` through `Accessor.klass("zombie.Lua.LuaManager.GlobalObject")`; the nested Java class actually requires `LuaManager$GlobalObject`, so the helper silently returned `false`.
- Replaced that helper in all prototype eligibility, ragdoll-gate, and corpse-pose checks with exact-build reads of `zombie.network.GameClient.client` and `zombie.network.GameServer.server`.
- Retained ZombieBuddy's values only in the startup diagnostic banner so the direct and helper flags can be compared after restart.
- Added a regression guard requiring the exact game network flags for client enablement.
- Bumped `MultiplayerRagdollPrototype` to `0.5.0`; clients must approve the new JAR fingerprint and fully restart before retesting.
- Preserved the concurrent `0.7.0` Gael ammo-storage work and kept the ragdoll prototype out of the `servertest1` server mod list.

## 0.7.0

- Added the original, MIT-licensed `GaelGunStoreAmmoStorageFixes` mod immediately after `GaelGunStore_B42` for Project Zomboid `42.20.3`.
- Corrected Build 42 names and exact counts for 67 Gael ammo boxes/projectile packs, 20 cartons, launcher packages, belt boxes, and ammunition-component boxes.
- Repaired every broken package `DoubleClickRecipe` link and translated the internal `GGS_...` open/pack actions into clear caliber-specific labels.
- Completed reciprocal `.30-30`, shotgun, 40 mm grenade, RPG-7 rocket, arrow, bolt, and carton conversion paths without copying or overriding Gael's complete item files.
- Added vanilla ammo, shotgun-shell, and non-drum pistol-magazine compatibility for bullet/shell bandoliers and the two-slot chest/shoulder holster, including saved-item fallbacks on the server.
- Added a narrow transfer-first client hook for Gael package unpacking after recent MP logs showed stale nested-container references failing in `ActionManager.sendAction`.
- Added static installed-upstream validation, gated in-game definition tests, original poster/icon artwork, attribution, and a non-automatic Steam Workshop publishing checklist.
- Verified an isolated dedicated-server script/Lua initialization: 87 package actions patched, zero missing items/recipes, and no patch-specific recipe or Lua errors.
- Kept removed/unlicensed Workshop patch `3669616334` disabled; only the local Mod ID is added until this patch receives its own Workshop ID.

## 0.6.0

- Added bounded diagnostic tracing for the multiplayer ragdoll prototype with a unique session ID and correlated hit ID for each zombie weapon-hit path.
- Logs hit eligibility and rejection reasons, declared and final damage, lethal prediction, ragdoll-gate decisions, individual transition failures, final hit state, corpse-pose decisions, and armed or unarmed death packets.
- Added counters for zombie hit entries, rejected hits, matched `applyDamage` calls, unmatched zombie damage, emitted trace lines, and suppressed trace lines.
- Capped each game session at 2,000 detailed trace lines to prevent runaway console growth while preserving aggregate dropped-line diagnostics.
- Extended the external ZombieBuddy regression preflight to require every load-bearing trace event and the logging cap.
- Bumped `MultiplayerRagdollPrototype` to `0.4.0`; clients must approve the newly generated JAR fingerprint and fully restart before collecting logs.
- Kept the client-only prototype out of the `servertest1` server mod list.

## 0.5.0

- Kept `Nearby (Compact)` selected across transfer actions and inventory refreshes, including direct source-container assignments; only explicit container controls leave the overview. Bumped the patch mod to `0.1.2`.
- Moved lethal-hit recognition to the final damage seam: `hitConsequences` now records the eligible weapon hit and `applyDamage(float)` prepares the ragdoll before vanilla subtracts health.
- Forces the physics death transition for lethal melee and non-explosive firearm hits while zombies are walking, attacking, otherwise off-ground, or getting up; zombies that remain grounded keep the normal death path.
- Leaves nonlethal hits, vehicles, explosions, environmental deaths, and living-zombie trips unchanged, and resets the prepared flags if the target unexpectedly survives.
- Expanded runtime diagnostics with `hitContexts`, `lethalPreparations`, and `preparedSurvivals`, and extended the executable probe for equal-health lethality and getting-up eligibility.
- Bumped `MultiplayerRagdollPrototype` to `0.3.0`; clients must approve the newly generated JAR fingerprint in ZombieBuddy and fully restart before testing.
- Kept the client-only prototype out of the hosted server's `Mods=` list, so the `servertest1` authoritative corpse, inventory, identity, and loot location remain unchanged.

## 0.4.0

- Fixed the ragdoll prototype's decisive timing bug: vanilla queries ragdoll eligibility before hit damage, while the old prototype armed zombies only after packet processing had already selected the normal death animation.
- Patched the exact six-argument `IsoGameCharacter.Hit` overload to snapshot whether a zombie is standing before damage and force the existing ragdoll-capable knockdown transition only when that hit leaves the zombie dead.
- Enabled the same client-local death ragdoll path for non-explosive ranged weapons, while keeping nonlethal hits, prone/crawling/getting-up zombies, vehicles, explosions, environmental deaths, and living-zombie trips on their normal paths.
- Expanded `Test-MultiplayerRagdollPrototype.ps1` with an executable fake-zombie regression probe covering standing/prone classification, melee/firearm selection, explosive rejection, and every animation-graph field used by the forced transition.
- Bumped `MultiplayerRagdollPrototype` to `0.2.0`; clients must approve the new generated JAR fingerprint in ZombieBuddy and restart before testing.
- Kept the client-only prototype out of the hosted server's `Mods=` list; authoritative corpse roots, inventory, identity, and loot location remain server-owned.

## 0.3.2

- Restored the established `servertest1` Workshop and mod lists after a stale manifest sync removed 20 Workshop items and 27 mod IDs from the hosted profile.
- Re-exported the public profile fields as 160 Workshop items, 188 server mod IDs, and six maps with revision `sha256:44b9ab455d748642e87200d47e5896654149a05d692faac88d28c25c4e709c8f`.
- Restored Neat Crafting and `NeatUI_Framework`, resolving the client world-dictionary failure for `NC_HandCraftPanelLayout`.
- Kept the client-only `MultiplayerRagdollPrototype` out of the hosted server's `Mods=` list.
- Added a destructive-change guard so hosted-profile syncs preview removals and require an explicit `-AllowRemovals` override before deleting established entries.

## 0.3.1

- Fixed a client crash caused by ZombieBuddy weaving calls from Project Zomboid classes into a package-private `PrototypeRuntime` class and methods.
- Made the prototype runtime entry points public so transformed game classes can invoke them without `IllegalAccessError`.
- Added `Test-MultiplayerRagdollPrototype.ps1`, which builds the JAR and compiles an external `zombie.characters` probe against every advice-facing runtime entry point.
- Bumped the experimental mod to `0.1.1`; users must approve the new generated JAR fingerprint in ZombieBuddy before retesting.

## 0.3.0

- Added the disabled-by-default `MultiplayerRagdollPrototype` for exact Project Zomboid `42.20.3` / Steam build `24775755` testing.
- Restricted the client-side ZombieBuddy patches to alive-to-dead melee hit packets, a five-ragdoll cap, and the matching authoritative corpse packet.
- Kept logical corpse position, inventory, identity, reanimation, saves, and server authority unchanged; firearm, vehicle, environmental, and living-zombie trip ragdolls remain disabled.
- Added a pinned external ECJ build, deterministic JAR generation, targeted local installation, package staging, runtime counters, and a disposable-world test matrix.

## 0.2.0

- Added the group-owned `CompactProximityInventory` compatibility mod for Inventory Tetris 6.11.5 beta on Project Zomboid 42.20.3.
- Added a selectable nearby-container entry to the loot window without requiring or redistributing Proximity Inventory.
- In that mode only, nearby containers are stacked in the Tetris pane, empty grid rows and wholly empty compartments are hidden, and empty containers are reduced to a final one-line entry.
- Preserved the normal full Tetris layout whenever an individual container or the ground is selected.

## 0.1.0

- Established the manifest, validation, packaging, backup, and installation workflow.
- Added the performance investigation plan and repository safety rules.
- Recorded the local reference version, Steam build, ordered hosted modpack, maps, and deterministic mod-list revision.
- Added ignored local discovery, allowlisted server-profile export, and guarded bidirectional sync for repo-owned files.
- Audited effective Build 42 mod metadata, map cells, Lua/script interactions, runtime logs, and author compatibility guidance.
- Revised the hosted modpack to 140 Workshop items, 161 mod IDs, and six maps: retained only `ETO_P`, removed Project RV and the active PZK family, corrected the Arcadia/vanilla map order, and admitted eight reviewed KI5 base vehicles plus the S10 Rust replacement.
- Kept the incompatible M911, unmaintained `VASinked` patch, and optional E-150 modules downloaded but inactive pending separate decisions and tests.
- Added guarded, backup-producing scripts to apply the public manifest to the local hosted profile and install/verify Better Vehicle Dynamics' version-gated Java overlay.
