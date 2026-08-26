# Multiplayer Ragdoll Prototype

Date: 2026-08-23

## Purpose

`MultiplayerRagdollPrototype` is a first, deliberately narrow test of client-local zombie ragdolls in multiplayer. It targets only Project Zomboid `42.20.3`, Steam build `24909800`, with ZombieBuddy `2.3.2`.

The prototype answers one question: **can an off-ground or getting-up zombie killed by a melee attack or firearm enter the existing client-local ragdoll path before the authoritative death packet creates its corpse?**

It is included in the package but is not present in `config/modpack.json`, so it is disabled by default and is not added to the hosted server's mod list.

Prototype `1.2.7` keeps the restrained death model but removes the tighter shoulder/elbow profile that caused Bullet to snap incompatible opening poses during its first solver step. Marked deaths retain vanilla joint constraints and instead use moderately weighted, low-friction arms with collision capsules reduced to 85% of vanilla radius. Coherent locomotion still reaches all 11 bodies before Bullet selects the fall, firearm pitch remains zero-net with the modified masses, arms receive no direct impulses, and delayed follower correction remains leg-only. Bounded arm and torso/leg snapshots are copied to the general debug log so first-step instability remains measurable even if the dedicated telemetry file fails.

This is a hybrid passive ragdoll, not a GTA/Euphoria-style active ragdoll. Project Zomboid exposes whole-body dynamics and impulses but no reviewed per-joint motor, pose target, or muscle controller. The animation therefore supplies only the opening posture; Bullet physics owns the body after the ragdoll transition.

## Scope and safety boundary

The Java patch:

- runs only on a multiplayer client;
- fails closed at runtime unless `projectzomboid.jar` has the exact reviewed SHA-256 for `42.20.3` / Steam build `24909800`;
- records whether the target was alive and either off-ground or getting up when melee or non-explosive ranged hit consequences begin;
- at the final `applyDamage(float)` seam, recognizes lethal damage before health subtraction and selects the fast generic ragdoll handoff in default `restrained` mode; older modes retain their existing firearm, spear, knife, and stagger opening poses;
- for ranged deaths only, requests `fallOnFront` before the forced transition when captured movement is at least `0.75 m/s` and points toward the shooter with a direction dot product of `-0.60` or lower; slow, retreating, melee, and grounded deaths keep vanilla orientation selection;
- preserves the opening animation pose but skips the previous-transform velocity upload for marked lethal ragdolls in `stabilized`, `assisted`, or `restrained` mode, leaving vanilla, vehicle, trip, unmarked, and `legacy` ragdolls unchanged;
- samples zombie position at most every `40 ms` into a bounded, expiring client-local history; each velocity sample is clamped to `2.5 m/s` and history samples are exponentially blended to suppress one-frame multiplayer root corrections; lethal hits prefer current `x-lastX` / `y-lastY` displacement, then use the newest nonzero history sample for at most `180 ms`, and record the selected source and age in diagnostics;
- converts captured velocity one-for-one into a clamped total impulse and distributes it coherently by normalized body mass across all 11 bodies before the first physics step, so melee and firearm deaths retain their movement without creating torso-to-limb velocity splits;
- after Bullet establishes a baseline and one measured rigid-body frame, applies a gentle zero-net forward pitch to moving firearm deaths: the pelvis, spine, head, and arms receive closely matched forward velocity while the legs receive only a small retaining adjustment;
- keeps attacker-to-target direction separate from locomotion and uses it only for a tiny localized reaction after the pitch adjustment: head reactions target the head, while chest, belly, shoulder, arm, and leg reaction names redirect to the spine; firearm reactions target a small velocity change and scale the applied impulse by the selected body's mass so a shotgun cannot launch the light head much faster than the heavy spine;
- applies no restrained upward impulse, never applies a direct hit impulse to an arm or leg, and classifies 9 mm SMGs before the generic `Rifle` category so the Sten remains at the lowest firearm reaction tier;
- creates only marked restrained ragdolls with moderate upper/lower-arm masses (`0.040` / `0.035`) and arm collision capsules at 85% of vanilla radius; native shoulder and elbow constraints are never redefined, and the vanilla body template is restored immediately after that ragdoll enters the world;
- applies one restrained dynamics pass with upper/lower-arm linear damping of `0.12` / `0.18`, arm friction of `0.35` / `0.20`, zero arm rolling friction, strong arm and leg angular damping, and near-vanilla sleep thresholds;
- between `80` and `180 ms`, compares measured forward displacement with 75% of captured pre-death speed and, only when needed, applies one no-lift correction capped at `0.30` total impulse, distributed coherently across all 11 bodies;
- never applies direct arm correction; arms receive the same pitch velocity as their spine parent and then remain passive under native constraints and strong angular damping; through `280 ms`, legs may still receive tightly bounded parent-relative correction beginning at `120 ms`, and all later correction stops at floor contact or sleep;
- copies the shared native `77`-float rigid-body output immediately after every physics step and processes all valid frames in fixed per-ragdoll buffers; the direct simulation hook is preferred, the known-working controller-update exit is the primary fallback, and controller post-update is a deduplicated second chance;
- writes compact lifecycle, arm, and core-body milestone diagnostics through Project Zomboid's native general log while routing full `rigid-frame`, `rigid-joints`, and limb-correction records to a dedicated file below the active Project Zomboid cache directory; peak frame/time and airborne-versus-floor values are accumulated for every body;
- defaults to `restrained` mode with only telemetry-driven, tightly budgeted early correction; optional `assisted` remains available only as an older A/B mode with its bounded `150 ms` pelvis impulse;
- keeps walking, attacking, staggered, falling-but-not-grounded, and getting-up zombies eligible without depending on their current animation state;
- leaves nonlethal hits and zombies that remain prone, crawling, knocked down on the floor, or sitting on the ground untouched;
- allows at most five active ragdoll simulations per client;
- preserves the clothing, scene-culling, animation-player, active-ragdoll-cap, and debug-disable checks;
- skips premature dead-zombie fall-state execution for at most 1.5 seconds while the ragdoll controller starts;
- suppresses the network dead-body timeout while startup is pending or ragdoll simulation is active, then releases vanilla corpse creation after settlement or startup timeout;
- keeps the marker only until the matching authoritative corpse packet completes, with a ten-second watchdog fallback;
- allows the resulting `IsoDeadBody` to copy the current client bone transforms when available.

The patch does **not**:

- change health, damage, kill credit, inventory, reanimation, saves, or corpse identity;
- patch or run ragdoll physics on the dedicated-server path;
- move the authoritative `IsoDeadBody` root or square;
- increase corpse-looting range;
- enable vehicle, explosive, environmental, or living-zombie trip ragdolls;
- synchronize bone transforms between clients or persist them on the server;
- add joint motors, pose matching, balance recovery, procedural bracing, or other true active-ragdoll behavior.

Because the server death packet still corrects the character to its authoritative root before creating the corpse, loot remains attached to the normal server corpse location. This first prototype therefore avoids the corpse-addressing problem instead of compensating with a larger loot radius.

## Build and install

Close Project Zomboid and the hosted server. Preview the targeted source sync:

```powershell
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod MultiplayerRagdollPrototype -WhatIf
./scripts/Install-MultiplayerRagdollPrototype.ps1 -WhatIf
```

Install the source and generate the client JAR:

```powershell
./scripts/Test-MultiplayerRagdollPrototype.ps1
./scripts/Install-MultiplayerRagdollPrototype.ps1
```

The build script:

- checks the local game version, Steam build, and `projectzomboid.jar` SHA-256;
- locates and exact-hash checks the local Project Zomboid JAR and ZombieBuddy JAR;
- downloads Eclipse ECJ `3.46.0` only into `%LOCALAPPDATA%\project-zomboid-build\tools` and verifies its pinned SHA-256;
- compiles into `%LOCALAPPDATA%\project-zomboid-build\build`;
- writes a deterministic JAR only to the deployed mod or package staging tree.

The prototype preflight builds that JAR, compiles a direct caller in the external `zombie.characters` package, and executes a fake-engine lifecycle probe. It reproduces the access boundary created by ZombieBuddy weaving and verifies off-ground/grounded/getting-up filtering, final-damage lethality, melee and firearm eligibility, explosive rejection, frame-rate-normalized movement capture, ranged forward-fall gating, pre-simulation mass-proportional 11-body momentum, zero-net firearm pitch, one displacement-window correction, leg-only follower correction, floor-contact shutdown, head/spine-only reactions, mode isolation, optional legacy assistance, startup deferral, active-simulation preservation, and final corpse release.

No generated class or JAR is written below repository source.

Every participating client that should see ragdolls must install the ZombieBuddy native agent, enable `ZombieBuddy` and `MultiplayerRagdollPrototype`, approve the generated JAR fingerprint, and restart the game. Do not add the prototype to the hosted server's `Mods=` list for this test.

The default quality mode is `restrained`. For A/B testing in the debug Lua console:

```lua
MPRagdollPrototype_setQualityMode("legacy")
MPRagdollPrototype_setQualityMode("stabilized")
MPRagdollPrototype_setQualityMode("assisted")
MPRagdollPrototype_setQualityMode("restrained")
```

`legacy` retains the death-ragdoll lifecycle but preserves animation-derived initial velocities and does not replace the controller's impulse or tune its bodies. `stabilized` suppresses those velocities and retains the older pelvis-only impact. `assisted` additionally applies the short pelvis guidance window. `restrained` suppresses independent bone velocities, applies coherent locomotion before the first physics step, requests a front fall for approaching ranged deaths, adds only a gentle zero-net pitch and tiny localized reaction after measured physics begins, allows one coherent displacement correction, and keeps delayed follower correction leg-only.

## Diagnostic logging

Detailed lines use the prefix `[MPRagdollPrototype][TRACE]`. Every game run has a `session` value, and every intercepted weapon hit has a correlated `hit` number. The diagnostic build emits at most 12,000 detailed lines per session; additional lines are counted in `traceDropped` but suppressed. The dedicated file is written below the active Project Zomboid cache as `Logs/MultiplayerRagdollPrototype/ragdoll-<session>.log`, so it survives normal debug-log replacement. Every valid physics frame is analyzed in memory, but full body data is logged only at frames `1`, `2`, `3`, `4`, `6`, `8`, `12`, `16`, `24`, `32`, `48`, `64`, `96`, `128`, `192`, and `256`.

Rigid-body positions are always written relative to the pelvis, never as absolute world coordinates. The buffer uses Bullet axes: horizontal `x`, vertical `y`, and horizontal `z`. Each body entry includes its relative position, quaternion, estimated linear and angular velocity vectors, velocity relative to the torso, and displacement from the opening pose.

The expected successful sequence is:

1. `hit-enter eligible=true`
2. `damage-eval lethal=true`
3. `gate-granted source=pre-damage`
4. optional `forward-fall-requested` for an approaching ranged death, then `transition-prepared forcedState=... fallOnFrontRequested=...`
5. `hit-exit dead=true transitionPrepared=true`
6. `fall-state-deferred waitingFor=ragdoll-simulation`
7. `ragdoll-started ragdollTrack=true ragdollController=true ragdollActive=true`
8. `initial-velocities-suppressed` while the current animation pose is uploaded without per-bone momentum
9. `coherent-momentum-applied phase=pre-simulation`, then `custom-impulse-queued waitingFor=first-measured-rigid-frame-pitch-and-reaction` and `dynamics-tuned` after the controller starts
10. `rigid-fallback-capture source=update-exit` once per ragdoll when the direct simulation advice is missed
11. `rigid-frame-deferred reason=controller-first-frame` when the engine's uninitialized opening callback is ignored
12. `rigid-baseline`, followed by the first updated `rigid-frame` and `rigid-joints` sample
13. `custom-impulse-applied phase=first-measured-rigid-frame` after the ranged pitch and localized reaction
14. optional `momentum-window-correction-applied` between `80` and `180 ms`
15. `torso-assist-started` only in assisted mode
16. `death-packet-armed` after physics settles and vanilla corpse creation resumes
17. `rigid-summary`, `rigid-body-summary`, and `rigid-joint-summary` before marker cleanup

Failure lines identify the stage directly:

- `hit-enter eligible=false reason=...` explains client/server mode, grounded state, ignored damage, or weapon classification rejection;
- `damage-unmatched` means `applyDamage(float)` ran without the expected hit context;
- `damage-eval lethal=false` means the final damage passed to health subtraction was not lethal;
- `gate-rejected reason=...` identifies culling, animation-player, debug-option, clothing, active-ragdoll-cap, or reflection failures;
- `transition-failed stage=... error=...` identifies the exact setter or event call that failed;
- `ragdoll-start-timeout fallback=vanilla-death` means no active simulation appeared within 1.5 seconds, so the mod stopped deferring the normal death path;
- `death-timeout-deferred` confirms the queued authoritative corpse packet was preserved during startup or active physics;
- absence of `initial-velocities-suppressed` on a stabilized, assisted, or restrained marked death means the private controller initialization hook did not run;
- absence of `custom-impulse-queued` in restrained mode means the vanilla hit reaction was not replaced; a queued impulse without a later `custom-impulse-applied phase=first-measured-rigid-frame` means no updated rigid-body frame reached deferred initialization;
- absence of `coherent-momentum-applied` for a moving restrained death means the pre-simulation whole-body locomotion pass failed;
- `momentum-window-correction-applied` records elapsed time, measured forward displacement, average forward velocity, target velocity, and the single coherent correction impulse;
- `custom-impulse-failed` means the native Bullet impulse adapter did not accept the selected ragdoll/body parameters;
- `dynamics-tuning-failed` means at least one rigid body could not receive the reviewed stabilization parameters;
- `rigid-fallback-capture` confirms the direct simulation advice was missed and the same native output was recovered from controller update or post-update without duplicating a frame;
- `rigid-fallback-unavailable` means the exact-build private native buffer could not be resolved or read; its `reason` identifies the reflection failure;
- `rigid-frame-invalid` means the native buffer was absent, too short, non-finite, or still contained invalid zero quaternions;
- absence of `rigid-baseline` after `ragdoll-started` means no valid post-first-frame native body pose reached the telemetry hook;
- `torso-assist-finished reason=...` records whether assistance ended at its deadline or when simulation became inactive;
- `hit-exit dead=true transitionPrepared=false` means vanilla killed the zombie after the prototype rejected or missed the transition;
- `death-packet-unarmed` means the authoritative death arrived without a prepared prototype marker;
- `pose-rejected reason=...` explains why the current ragdoll pose could not be copied to the corpse.

After reproducing the problem, close Project Zomboid normally and ask for the recent ragdoll logs to be analyzed. Keep the test to roughly five to ten representative deaths so the newest `session` remains easy to isolate in the newest `Logs/*_DebugLog.txt` and `console.txt` files.

## Test procedure

Use a disposable two-player hosted world first. Keep both players near the same zombie and capture each client's `console.txt` separately.

1. Kill walking and attacking zombies with a normal melee weapon; the lethal hit should immediately enter a physics ragdoll instead of the normal animated death fall.
2. Kill walking and attacking zombies with a firearm; the lethal shot should enter the same physics death path.
3. Kill a zombie while it is getting up; the lethal melee hit or firearm shot should still enter the ragdoll path.
4. Hit eligible zombies nonlethally with both melee and firearms; neither hit should force this death-only ragdoll path.
5. Kill prone, crawling, or otherwise grounded zombies with both melee and firearms; they should use the normal on-ground death path.
6. Kill a zombie with a vehicle or explosion; it should use the normal multiplayer death path.
7. Trigger a nonlethal knockdown or Tripping Zombies trip; the living zombie must not enter this prototype's ragdoll path.
8. Compare `legacy`, `stabilized`, `assisted`, and default `restrained` with the same melee weapon and firearm. Restrained should keep a running zombie moving in its prior direction while the head or spine reacts only slightly and the limbs remain close followers.
9. Shoot a zombie running directly toward the player in the head. Its center of mass should continue toward the player, the head should move slightly away from the shot, and neither arm should receive an independent launch.
10. Kill a stationary zombie with the same firearm. It should mostly collapse under gravity with only the small localized reaction rather than receiving artificial forward momentum.
11. Kill six or more nearby zombies quickly and watch for frame-time spikes or stuck bodies; the local physics cap is five and each restrained ragdoll receives one 11-body momentum pass, one 11-body dynamics pass, and at most one optional 11-body displacement correction.
12. Loot every affected corpse from its visible server location.
13. Leave and re-enter the area, reconnect, and restart the hosted world. Expect any custom local pose to revert to server-supported corpse presentation.

In a debug Lua console, print the current counters after the test:

```lua
print(MPRagdollPrototype_status())
```

Interpret them as follows:

- `armed`: eligible lethal melee or firearm hits prepared by this client;
- `gateGrants`: animation evaluations for which the multiplayer ragdoll gate was opened;
- `poseCaptures`: corpse creations allowed to copy current client bone transforms;
- `matchedDeathPackets`: armed zombies that reached the authoritative corpse packet;
- `activeAtDeathPacket`: zombies already running a ragdoll simulation when that packet began.
- `meleeDeaths` / `firearmDeaths`: successful forced transitions split by weapon category;
- `transitionFailures`: reflective state transitions that failed closed and reverted the physics flags.
- `forcedActionStates`: lethal transitions that successfully selected the exact ragdoll action and animation state;
- `ragdollStarts`: prepared zombies observed with an active ragdoll simulation;
- `startupDeferrals` / `startupTimeouts`: fall-state executions delayed for startup and transitions that fell back after the 1.5-second limit;
- `deathTimeoutDeferrals`: authoritative dead-body timeouts suppressed during startup or active physics;
- `initialVelocitySuppressions`: marked ragdolls whose animation-derived per-bone velocity upload was suppressed;
- `customImpulses`: ragdolls that completed their selected one-shot initialization path;
- `dynamicsTunings`: ragdolls whose 11 bodies received the selected dynamics pass;
- `restrainedMomentum`: restrained ragdolls that received coherent pre-simulation whole-body locomotion momentum;
- `momentumCorrections`: restrained ragdolls that received the single measured displacement-window correction;
- `forwardFallRequests`: approaching ranged deaths for which the prototype requested a front fall before the state transition;
- `localizedReactions`: restrained ragdolls that received the tiny head or spine reaction;
- `torsoAssists` / `torsoAssistTicks`: assisted ragdolls and the bounded update ticks that applied pelvis-only guidance;
- `hitContexts`: supported weapon hits that began while the zombie was off-ground or getting up;
- `lethalPreparations`: those hit contexts whose final damage was lethal and successfully prepared before health subtraction;
- `preparedSurvivals`: prepared targets that unexpectedly remained alive or threw during hit processing and were reset.
- `zombieHitEntries`: zombie weapon-hit entries observed by the `hitConsequences` hook;
- `rejectedHits`: observed zombie hits rejected before lethality evaluation;
- `applyDamageCalls`: final damage calls matched to their pending hit context;
- `unmatchedZombieDamage`: zombie damage calls observed without the expected hit context;
- `rigidCallbacks`: native rigid-body output callbacks copied for marked ragdolls;
- `rigidValidFrames`: callbacks accepted after first-frame and buffer validation;
- `rigidSnapshots`: milestone frames for which complete body and joint lines were emitted;
- `rigidSummaries`: ragdolls whose aggregate body and joint maxima were written before cleanup;
- `rigidInvalidFrames`: native callbacks rejected because their buffer was missing or invalid;
- `rigidFallbackCaptures`: controller updates recovered because the direct simulation advice did not capture that update;
- `rigidFallbackUnavailable`: fallback attempts that could not read the exact-build private native buffer;
- `traceSession`: identifier shared by every detailed trace line from the current run;
- `traceLines` / `traceDropped`: detailed lines emitted and suppressed by the 12,000-line safety cap.

If `hitContexts` remains zero, the hit hook is not running or the target was already grounded. If `hitContexts` increases but `lethalPreparations` does not, the final damage was nonlethal or the `applyDamage(float)` hook did not match the hit context. If `forcedActionStates` increases but `ragdollStarts` remains zero, inspect the correlated state traces for a missing ragdoll track/controller or a startup timeout. If `ragdollStarts` increases but the corpse never appears, inspect `deathTimeoutDeferrals`, `death-packet-armed`, and `death-packet-exit`; the mod must release vanilla corpse creation after simulation settles and must never move the logical corpse.

## Stop conditions

Disable the prototype immediately if a test produces an invisible corpse, missing inventory, unlootable corpse, duplicate corpse, failed reanimation, stuck zombie, crash, or persistent state-machine error. The fallback is simply to disable `MultiplayerRagdollPrototype`; it changes no save schema and adds no server-owned data.
