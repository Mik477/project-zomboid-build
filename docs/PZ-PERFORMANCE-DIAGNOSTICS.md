# PZ Performance Diagnostics

Date: 2026-08-24

## Purpose

`PZPerformanceDiagnostics` is the measurement-only first stage of the modpack performance patch. It targets Project Zomboid `42.20.3`, Steam build `24909800`, and ZombieBuddy `2.3.2`.

It is designed to answer three concrete questions from one short session:

1. Why can vehicle entry take an abnormally long time after Vanilla Vehicles Animated and `VASinked` are enabled?
2. Why does frame pacing collapse while driving or running quickly into unvisited map cells?
3. Where do inventory transfer/equip actions or the shared timed-action queue stop progressing?

The mod does not skip actions, alter timeouts, preload chunks, delete map data, change vehicle state, or modify a Workshop file. It records enough correlated evidence to choose a narrow performance-changing patch afterward.

## Static audit findings that motivated the probes

The active modpack already contains Vanilla Vehicles Animated, `VASinked`, and DAMN Library.

- Vanilla `ISEnterVehicle` has no maximum duration. Its update loop completes only after the animation graph sets `EnterAnimationFinished=true`.
- Entry is a queue: pathfind to seat, optionally unlock, open door, enter, then close door. A delay before the enter action is different from an enter-animation stall.
- `VASinked` wraps open/close-door action starts and sends asynchronous `VAS_Sync` commands before delegating to the prior implementation.
- DAMN Library replaces `ISEnterVehicle.start` for its managed vehicles, so vanilla and KI5/DAMN vehicles can follow different code paths.
- The current local map log has CRC sanity failures for chunks `1039,1454` and `1045,1454`. The engine catches those failures, marks the chunks as blam, and creates replacements. The diagnostics correlate any repeat with a frame spike; this stage does not delete or repair the save.
- `IsoChunkMap.update` performs `IsoChunk.doLoadGridsquare` integration on the main thread. Worker-thread loading can therefore be fast while main-thread integration still creates visible stutter.
- The installed `VASinked` client handler sets the remote door to open in both its open and close branches. That is a compatibility defect worth confirming in the trace, but it is not assumed to be the entry-delay cause.

## Measured baseline and applied fixes

The first complete trace ran for 393 seconds and recorded 1,110 frame spikes, 2,151 slow Lua callbacks, and 5,166 slow/queued chunk events.

- TYL's `TYL_ProcessPlayerRadius` ran 735 times for 24.6 seconds total, reached 361.6 ms, and directly preceded 362 of 389 update spikes. Preset 3 uses radius 65, so every player-tile movement can inspect 17,161 squares.
- The same client-side generator produced 16,331 packet-limit warnings; the host logged 5,216 nonexistent-object packets and 300 `ReceiveModDataPacket.processServer` null-square exceptions.
- Main-thread chunk integration remained secondary: `doLoadGridsquare` reached 102.3 ms and `IsoChunkMap.update` reached 184.5 ms, but only 20 update spikes immediately followed chunk integration.
- Heap use peaked at 3,189,768,192 bytes, 99% of the 3 GB maximum. The heap is deliberately unchanged until a post-TYL trace proves whether pressure remains.
- PZ Map and PZ Pulse contributed more than 4.5 seconds of captured render-event work.
- Every `BaseVehicle.enter` returned true in under 1.4 ms. One first entry produced a 254 ms cold update afterward, but the original Lua action tracer did not load.

The 0.9.19 client policy removed the measured FPS stutter: its final 512-frame window reached update `p95=6.5 ms` and `p99=15.4 ms`, with no client `TYL_ProcessPlayerRadius`. It also exposed the next bottleneck: the host printed `ZombieBuddy.Events unavailable`, retained TYL's movement and synchronous square callbacks, and delayed server chunks enough to stop vehicles at unrendered borders.

The later Lua queue and common-Java gate experiments also failed to restore reliable TYL generation and introduced marker risk. They remain retired: no original TYL callback is removed or suppressed and no compatibility marker is written. `TYLIndoorBushFix` now owns only the independent indoor-bush correctness guard.

The worst 0.3.0 session was additionally dominated by an unrelated selected-mod defect: Inventory Tetris's `KnownAndCollectedRenderHandler.lua:157` calls removed Build 41 API `Literature:getTeachedRecipes()`. It generated 4,516 stack entries and drove update/render p99 toward 0.8 seconds. The Lua-only compatibility wrapper now skips literature instructions for that handler while preserving map and recorded-media overlays, restores hidden flags after delegation, and contains unexpected handler failures. The independent one-second PZ Map/Pulse cadence, VAS close correction, and outside/room guard plus cleanup for indoor TYL bushes remain active.

The 691.7-second 0.9.25 capture then identified the current vehicle-entry regression in diagnostics itself. Five vehicle-use attempts reached `PZPerformanceDiagnostics/Bootstrap.lua`, queried `ISBaseTimedAction:getJobDelta()` before `begin()` created `self.action`, and rethrew queue-start failures through both `ISVehicleMenu.onEnterAux` and `onEnter`. This aborted the first path/open/enter/close queue and caused repeated clicks plus error popups. Completed entries into `Base.ModernCarLightsMeadeSheriff` reached the Java engine successfully: all four nested/overloaded `BaseVehicle.enter` observations returned true in 0.04–1.212 ms. Version 0.1.2 therefore retires the Lua action tracer rather than changing VVA or VAS. One first-entry update had an unassigned 1.163-second wall stall; the second entry was clean, so that isolated outlier requires a post-fix paired capture before any further patch.

Later August 24 sessions failed at the shared `ISBaseTimedAction.begin()` seam for inventory transfers, Fancy Handwork, and vehicle actions with `ReturnValues.put(ReturnValues.java:61)`. Version 0.1.3 removed the remaining universal `LuaEventManager.triggerEvent` and `KahluaThread.pcallvoid` diagnostics hooks so targeted measurements no longer weave every Lua callback. Version 0.2.0 adds observer-only queue timelines: it reads existing local-player queue/action fields and event outcomes but never calls or replaces timed-action methods. The simultaneous packet-cache warning storm remains a separate measured TYL/networking issue because prior callback suppression broke authoritative vegetation generation.

## Instrumentation

### Frame pacing

ZombieBuddy advice records:

- `IngameState.update`;
- `IngameState.render` and render-start interval;
- `IngameState.UpdateStuff`;
- main-thread CPU time versus wall time;
- heap use and garbage-collection count/time deltas;
- player movement mode, chunk, and vehicle speed/script;
- the most recent chunk event and its age.

A frame/update/render event is written when wall time or render interval reaches `33 ms`, or when the patched call throws. Events at `75 ms` or above are labelled severe. A rolling update/render/update-stuff summary is written every five seconds.

### Chunk streaming

The exact reviewed Build 42.20.3 seams are timed:

| Thread/path | Hook | What it distinguishes |
| --- | --- | --- |
| Main | `IsoChunkMap.ProcessChunkPos` | Boundary crossing, lock delay, and chunk-map movement |
| Main | `IsoChunkMap.update` | Integration queue before/after and estimated chunks integrated |
| Main | `IsoChunk.doLoadGridsquare` | Per-chunk world integration cost |
| Main | `WorldStreamer.updateMain` | Client request/cancel dispatch cost |
| Worker | `WorldStreamer.addJob` | Aggregate requested-chunk count without one log line per request |
| Worker | `WorldStreamer.DoChunkAlways` | Complete worker load/postprocess cost |
| Worker | `IsoChunk.LoadChunk` / `LoadOrCreate` | Disk, server-buffer, or brand-new source; loaded/blam/error result |
| Worker | `IsoChunk.loadInWorldStreamerThread` | Recalculation and neighbour postprocessing cost |

Main-thread chunk phases are retained at `3 ms` or above. Worker phases are retained at `12 ms` or above. Failures and blam states are always retained.

### Lua execution boundary

Version 0.2.0 does not patch `LuaEventManager`, Kahlua callback execution, Java timed-action lifecycle, `ReturnValues`, or `MethodArguments`. Its Lua observers subscribe to standard events and inspect existing tables without replacing handlers. This deliberately gives up live Lua source attribution so diagnostics cannot alter the shared execution path used by timed actions. The summarizer still reads `slow-callback` events from historical 0.1.2-and-earlier traces.

### Inventory actions

`InventoryTetrisTransferDiagnostics` 0.3.1 observes existing local-player queue entries for transfer, equip, Wear, vanilla insert/eject, magazine loading, and Gael magazine swap terminal actions. Transition-only `[ITTransferDiag]` lines and matching JSONL action events record queue position/shape, current/native-action state, start/max-time/transaction state, source/destination membership, key-ring involvement, main-inventory weight/capacity, Tetris overflow candidacy, worn state, clip/ammo state, magazine-container transitions, state at queue removal, and Inventory Tetris recovery-candidate resolution. Queue shape is computed once per player/tick and detailed work is capped at 64 live traces. A current action that remains without its native Java action emits bounded `0/250/1000/5000/15000/30000/45000 ms` milestones, directly exposing failures during `ISBaseTimedAction.begin()` without invoking `getJobDelta()`. Magazine items are read only through magazine-safe state methods; firearm-only clip queries are limited to `HandWeapon`. The observer does not call Tetris fit validation and therefore cannot report grid occupancy or a synchronous rejection that never creates a queue entry.

The observer cannot prove that an unobserved UI click was accepted or identify the exact branch inside `isValid()`, because doing so would require the unsafe UI/action wrappers that were retired. An explicit `ITTransferDiag_mark("label")` marker is available for such attempts.

### Vehicle entry

Versions 0.1.2 and later intentionally do not replace `ISVehicleMenu`, `ISTimedActionQueue`, or any path/open/enter/close timed-action method. The retired Lua tracer changed the call environment it was supposed to observe and could abort queue construction.

The 0.2.0 Lua observer reads local-player entry/exit queues and correlates `ISPathFindAction` vehicle-seat goals, `ISEnterVehicle`, `ISExitVehicle`, `OnEnterVehicle`, and `OnExitVehicle`. It emits only queue/state transitions plus 2/5/15-second unchanged-state milestones. Each event includes bounded queue shape, current/native-action state, seat occupancy, door state, and enter/exit animation variables.

The remaining Java advice passively records:

- `BaseVehicle.enter` duration, return value, seat, vehicle ID/script, and thrown exception;
- passenger animations;
- vehicle-part animations;
- frame state after entry, including player mode, vehicle speed/script, CPU versus wall time, GC deltas, and nearest chunk work.

Together, the observer and Java signals distinguish pre-engine queue construction/progression, animation stalls, engine rejection or slow `BaseVehicle.enter`, and later frame stalls without modifying the vehicle action chain.

## Log format and safety limits

The Java patch writes JSON Lines to:

```text
%USERPROFILE%/Zomboid/Logs/PZPerformanceDiagnostics/perf-<session>.jsonl
```

The actual cache root is obtained from Project Zomboid through ZombieBuddy rather than hard-coded.

- Writes go through a non-blocking queue with capacity `8,192`.
- The game thread never waits for the file writer.
- The writer is a daemon and flushes every second or 32 lines.
- A session accepts at most `60,000` lines; queue/full-limit drops are counted in `PZPerfDiagnostics_status()`.
- Generic action events are capped at `10,000`; the Inventory Tetris observer independently caps console/bridge output at `2,500` lines and `64` live traces.
- The log contains its local absolute path, local coordinates/chunk IDs, vehicle identifiers, and diagnostic item full types/runtime IDs because they are required to correlate failures. The path can contain the Windows profile name. It does not intentionally record server addresses, passwords, save databases, item display names, item mod data, or full inventory/container contents; redact paths and identifiers before sharing excerpts.
- Raw logs stay local and must not be committed.

## Build and install

Close Project Zomboid and the hosted test server. Then run:

```powershell
./scripts/Test-LuaPatchMods.ps1
./scripts/Test-InventoryTetrisTransferDiagnostics.ps1
./scripts/Test-PZPerformanceDiagnostics.ps1
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod InventoryTetrisTransferDiagnostics -WhatIf
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod InventoryTetrisTransferDiagnostics
./scripts/Install-PZPerformanceDiagnostics.ps1 -WhatIf
./scripts/Install-PZPerformanceDiagnostics.ps1
```

The selected KnownAndCollected/SwapIt dependency set is now represented in the manifest. Preview the profile apply and confirm that its removals are limited to redundant `ETO_B` and the retired catch-all patch IDs before using the guarded `-AllowRemovals` flow in `docs/PATCH-MOD-LAYOUT.md`.

Install the complete replacement patch package and run the one-time `Migrate-PatchModLayout.ps1` flow in `docs/PATCH-MOD-LAYOUT.md` before applying the new manifest. The diagnostics build verifies the exact game version, Steam build, `projectzomboid.jar`, and `ZombieBuddy.jar` SHA-256 fingerprints; compiles with the pinned external ECJ; and writes its generated JAR only to the local user mod or package staging tree. The migration backs up and removes the retired `PZPerformanceFixes` directory so it cannot load beside the focused Lua mods.

Every client must have ZombieBuddy and fully restart after deployment. Approve the diagnostics client JAR plus the `KahluaObjectPoolConcurrencyFix`, `GaelGunStoreLootDiversification`, `TrashAndCorpsesSafetyFix`, and `SecretZCommandRegistrationFix` common JAR fingerprints; no active common TYL gate remains.

## Short reproduction session

Use the normal `servertest1` test world and keep the run to roughly 5–10 minutes.

1. Start the game, join the hosted test world, and confirm the console prints `[PZPerformanceDiagnostics] ... enabled` plus the JSONL path.
2. Repeatedly transfer single items and stacks between the player inventory and a nearby container until at least 20 timed actions complete.
3. Enter the same VVA `Base.ModernCarLightsMeadeSheriff` on the first click at least three times, exiting between attempts.
4. Enter and exit one DAMN-managed KI5 vehicle at least three times.
5. Run or sprint across an already visited area for about 30 seconds as a control.
6. Drive the same vehicle through an already visited area for about one minute.
7. Drive into genuinely unvisited cells for two to three minutes at the speed that normally causes stutter. If practical, pass near the area containing the known CRC failures without deliberately modifying the save.
8. Exit to the menu normally, then close the game so the shutdown hook drains and flushes the queue.

The diagnostics rework is accepted only if inventory transfers complete, every vehicle attempt builds the normal queue on the first click, and the console contains no `PZ Performance Diagnostics).onEnter`, `onEnterAux`, premature `getJobDelta`, or timed-action `ReturnValues.put` error. Stop the test if diagnostics cause a crash, queue drops remain sustained, or inventory/vehicle behavior changes. Disabling both diagnostics mods removes their observers; neither writes save data.

## Summarize and interpret

Run:

```powershell
./scripts/Summarize-PZPerformanceDiagnostics.ps1
```

Or provide a specific session:

```powershell
./scripts/Summarize-PZPerformanceDiagnostics.ps1 -Path <perf-session.jsonl>
```

The report ranks:

- frame/update/render spikes, including GC and the nearest chunk event;
- historical Lua callbacks by total captured time and maximum duration, when present in an older trace;
- chunk phases by maximum duration and failures;
- inventory/equip action trace timelines;
- observer-only vehicle queue attempt timelines;
- passive `BaseVehicle.enter` and vehicle-animation observations;
- the last rolling window.

The summarizer continues to understand historical manual markers and Lua callback events. Current diagnostics emit action and vehicle queue timelines but do not emit Lua callback attribution.

The 0.4.0 safe-baseline run is accepted only when:

- no `PZPerformanceFixes.jar` or `[PZPerformanceFixes/Java]` gate loads;
- focused status functions report the TYL guard, exporter policy, KnownAndCollected wrapper, and VAS correction independently;
- Inventory Tetris can display books for several minutes with zero `KnownAndCollectedRenderHandler.lua:157` or `Object tried to call nil` errors;
- map and recorded-media KnownAndCollected overlays remain available, while literature overlay icons are intentionally skipped;
- original TYL callbacks and generation are restored, with no compatibility queue/permit/marker status fields;
- `indoorBushGuardApplied=true`, interior `TYLBush` objects are removed as squares load, and no new bushes appear in rooms;
- PZ Map/Pulse cadence remains no faster than one second and VAS remote close state remains correct;
- frame diagnostics return to the original TYL baseline without the 0.3.0 per-frame error storm.

Interpret passive vehicle evidence as follows:

- no `base-enter` after a visible delay: inspect the vehicle queue timeline to identify the last path/door/entry state reached before the engine call;
- slow `base-enter`: the engine entry call itself is involved;
- `base-enter entered=false`: seat/state rejection inside `BaseVehicle.enter`;
- fast successful `base-enter` followed by a wall-heavy update spike: entry succeeded and a later blocking path is involved; compare CPU, GC, and chunk fields before assigning a cause;
- passenger/part animations without a successful `base-enter`: animation or synchronization work occurred without completed engine entry.

Interpret fast-travel spikes as follows:

- frame spike within a few milliseconds of `main-integrate` or `chunk-map-update`: main-thread chunk integration is dominant;
- slow `worker-total`/`load-or-create` without a main-frame spike: storage/network is slow but sufficiently asynchronous;
- `loaded=false`, `blam=true`, or CRC errors: damaged chunk recovery is involved;
- GC time rising with the frame spike: allocation/heap pressure is involved;
- a historical trace shows one Lua source repeatedly dominating `OnTick`/`OnPlayerUpdate`: target that mod callback before changing streaming; current traces require separate mod-specific attribution;
- render spikes with low update/chunk/Lua time: investigate models, textures, vegetation, and GPU-side work.

The next performance-changing patch should address only the dominant measured path and should be compared against the same route at least three times.
