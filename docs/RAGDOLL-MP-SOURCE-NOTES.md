# Build 42 Multiplayer Ragdoll Feasibility

Research date: 2026-08-20

Target: Project Zomboid `42.20.3`, Steam build `24909800`, hosted four-player multiplayer.

Scope: official Indie Stone announcements/patch notes, first-party Workshop pages, and public repositories owned by relevant authors. No decompiled game source was inspected or reproduced.

## Executive conclusion

There is no documented, supported switch that re-enables true character ragdolls in multiplayer as of Project Zomboid `42.20.3` on 2026-08-20.

The Indie Stone explicitly disabled ragdoll functionality for the first Build 42 multiplayer release on 2025-12-11 and said it would return in later patches. Later official notes contain ragdoll fixes, including vehicle handling described as applying in SP/MP, but no official release through the 2026-08-17 `42.20.3` hotfix explicitly reverses the multiplayer disablement.

A conventional Lua mod can choose when a zombie should fall, request ordinary synchronized knockdowns, and coordinate gameplay decisions through the server. The available primary evidence does not show a documented Lua API that can remove the engine's client/server ragdoll guard or add physics/corpse synchronization. Current mod authors instead describe true ragdolls as single-player-only, remove MP support after failures, or use synchronized knockdown as a fallback.

A Java-agent mod can patch the running game and at least two Workshop projects claim experimental MP ragdolls through ZombieBuddy. This makes a private proof of concept plausible, but not supported or production-safe. A reliable implementation must control the death decision, initial impulse, active-ragdoll lifecycle, final corpse transform, late-join state, relevancy, failure recovery, and exact-version compatibility. The claimed MP implementations do not publish author-owned source repositories that were discoverable under this research scope.

Recommendation for this four-player pack:

1. Do not build a Lua-only “enable MP ragdolls” mod; use synchronized animated knockdowns instead.
2. Treat any ZombieBuddy implementation as an exact-version experiment on a disposable save.
3. Keep death, loot and corpse placement server-authoritative; make the ragdoll a temporary client-local visual or synchronize only one validated final root transform.
4. Cap nearby active ragdolls aggressively and fail back to vanilla death processing.

## Follow-up: local displacement, loot identity, and lifecycle

Exact-build tracing on 2026-08-20 added three constraints to the feasibility result:

- The loot window scans only the player’s current square plus the eight adjacent squares.
- Multiplayer corpse containers are encoded as square X/Y/Z plus the corpse’s index in that square’s static-moving-object list. The server resolves that location/index against its authoritative world; extending the client loot radius alone cannot make a logically relocated client corpse resolve correctly.
- Active physics ends after the body stops moving, Bullet reports the island sleeping, and the controller’s settle timer expires. Dead zombies then become static `IsoDeadBody` objects that may retain frozen bone transforms locally. Living zombies can leave `onground-ragdoll` through front/back get-up transitions once simulation is inactive.

The viable local-displacement architecture is consequently a **presentation offset**: retain the authoritative corpse root, square, and index for networking while rendering and picking the frozen local pose at a bounded displaced position. A corpse-only proximity extension can bridge the visible-versus-logical distance. Moving the actual client `IsoDeadBody` between squares would require deeper patches to corpse container encoding and response resolution and is not recommended for the first prototype.

The installed Tripping Zombies Build 42 script uses the recoverable `knockDown -> falldown-ragdoll -> onground-ragdoll -> get-up` path and guards against repeat trips. Its trip decision is server-side in MP, however, while the dedicated server cannot initialize ragdoll physics. Live trip ragdolls therefore require a separate cosmetic client event and should not be enabled by merely opening the client ragdoll gate.

## Official status timeline

| Date | Primary source | Evidence | Interpretation |
| --- | --- | --- | --- |
| 2025-05-20 | [42.8.1 Unstable announcement](https://steamcommunity.com/games/108600/announcements/detail/1799817379626544) | Indie Stone introduced ragdolls for vehicle collisions and gunplay, said melee ragdolls were planned but not imminent, requested performance reports, and made the feature optional. | The first implementation was experimental, performance-sensitive and did not include general melee activation. |
| 2025-06-10 | [Build 42.9.0 Unstable](https://theindiestone.com/forums/topic/83299-build-4290-unstable-released/) | Added explosive physics reactions and fixed non-lootable ragdoll corpses, corpse-position problems, shadows, and dead ragdolls getting up. | Corpse creation, lootability and final placement were already correctness risks before MP shipped. |
| 2025-06-30 | [Build 42.10 Unstable](https://steamcommunity.com/games/108600/announcements/detail/1803527891638864) | Fixed ragdolls interacting with vehicles, walls and other ragdoll corpses; a vehicle fix was still described as partial. | Ragdoll/world collision remained an active engine issue, not merely a visual concern. |
| 2025-09-25 | [Build 42.12.0 Unstable](https://theindiestone.com/forums/topic/87117-42120-unstable-released/) | Added runtime control of ragdoll body dynamics and adjusted vehicle friction. | The implementation was still changing immediately before B42 MP release. |
| 2025-12-11 | [Unstable 42 MP Released](https://steamcommunity.com/games/108600/announcements/detail/1818752592123010) | Indie Stone states: “Ragdoll functionality has been disabled in MP. This will be added in later patches.” | This is the clearest official status statement and requires an explicit later reversal. |
| 2025-12-11 | [Build 42.13.0 MP patch notes](https://theindiestone.com/forums/topic/88501-build-42130-unstable-multiplayer-released/) | MP test guidance says to disable ragdoll physics; the combined build still contains ragdoll fixes. | Ragdoll code existing in the build does not mean the MP guard is removed. |
| 2026-02-16 | [Build 42.14.0 Unstable](https://theindiestone.com/forums/topic/91647-42140-unstable-released/) | Notes tune `VehicleHit` mechanics “in SP/MP, for regular and Ragdoll zombies,” correct MP/SP vehicle damage, fix corpse dragging and fix several ragdoll bugs. | Shared MP code can encounter ragdoll-related states, but this is not a general MP re-enable announcement. |
| 2026-03-09 | [Build 42.15.0 Unstable](https://theindiestone.com/forums/topic/92435-42150-unstable-released/) | Fixed ragdoll zombies flipping before getting up when run over. | Continued maintenance without reversing the MP-disable statement. |
| 2026-03-31 to 2026-07-29 | [42.16](https://theindiestone.com/forums/topic/93251-42160-unstable-released/), [42.17](https://theindiestone.com/forums/topic/94253-build-42170-unstable-released/), [42.18](https://theindiestone.com/forums/topic/95091-build-42180-unstable-released/), [42.19](https://theindiestone.com/forums/topic/95733-build-42190-unstable-released/), [42.20 Stable](https://theindiestone.com/forums/topic/96975-build-4220-stable-released/) | Published notes contain no MP-ragdoll re-enable announcement. | No documented reversal was found in the intervening release trail. |
| 2026-08-17 | [42.20.3 Stable hotfix](https://steamcommunity.com/games/108600/announcements/detail/1840944183785895) | Latest official release before this audit; no ragdoll or MP-ragdoll re-enable entry. | The official public record still lacks the promised re-enable at `42.20.3`. |

Absence from patch notes cannot prove an internal code path does not exist. It does establish that there is no documented, supported MP-ragdoll feature or configuration on which a normal modpack should rely.

## Why multiplayer ragdolls are different

The official sources do not publish a complete current protocol specification for zombie death and corpse ownership. The following is an engineering inference from Build 42's server-authoritative direction and the failure classes documented in official ragdoll patch notes.

A zombie death is gameplay state: the server must agree that the zombie is dead, award the kill, remove the live zombie, create a persistent corpse, preserve its inventory, and expose one lootable object to current and later clients. Ragdoll physics adds a locally simulated, time-dependent path between the live zombie and that corpse.

If peers simulate that path independently, frame rate, collision timing, loaded geometry and floating-point behavior can produce different resting locations. If the server creates the corpse at the pre-ragdoll position, a client can see the body snap back when physics ends. If a client chooses the final location, the server must validate and replicate it, and late joiners need the settled authoritative corpse rather than a simulation they never observed.

Official fixes show why this matters: Indie Stone has fixed non-lootable ragdoll corpses, incorrect corpse positions, standing death poses after falls, wall/vehicle entrapment, and ragdolls getting up after death. These become network-visible defects when physics determines where a persistent corpse finishes.

The minimum synchronization problem is more than a ragdoll on/off flag. It includes:

- authoritative victim, damage source, death time and kill credit;
- identical initial root transform, direction and impulse parameters;
- ownership while the body is physically moving;
- transition from active physics entity to persistent corpse;
- one authoritative final corpse square/root transform;
- join-in-progress and relevancy behavior;
- recovery when a client lacks the patch, times out, exceeds its ragdoll cap, or computes an invalid location.

Streaming every bone or rigid body each tick would be bandwidth-heavy and fragile. Sending only an event and seed is cheap but does not guarantee deterministic settlement. Sending a start event plus one validated final root transform is a reasonable compromise, but still requires engine hooks at both the physics and corpse-creation boundaries.

## Existing Workshop claims

These are first-party descriptions written by the uploaders. They are claims, not independent verification.

| Mod | Page status | Author claim | Evidentiary limit |
| --- | --- | --- | --- |
| [Melee Ragdolls — B42.20](https://steamcommunity.com/sharedfiles/filedetails/?id=3779997883), updated 2026-08-10 | Current B42.20 melee mod | True physics ragdolls are single-player-only because B42.20 disables them whenever a client or server is active. MP offers ordinary server-synchronized knockdown. Blunt melee hits can trigger real physics in SP. | Strong first-party evidence for the Lua-visible limitation and safe fallback. It does not enable MP physics. |
| [Tripping Zombies: Reborn](https://steamcommunity.com/sharedfiles/filedetails/?id=3746603021), updated 2026-08-19 | Enabled in this modpack | Advertises full MP support with server-authoritative trip logic, but explicitly limits actual ragdolls to single-player B42. | Demonstrates that synchronized trip gameplay and ragdoll presentation are separate concerns. |
| [Zombies Trippin'](https://steamcommunity.com/sharedfiles/filedetails/?id=3780010932), updated 2026-08-09 | B42.20+ hit/stair mod | MP was temporarily removed after working in testing but failing after upload. The author reports that physics may fail to update the zombie's location, causing it to return to its earlier position/height. | Direct first-party report of location reconciliation and deployment failure. |
| [Ragdolls in Multiplayer](https://steamcommunity.com/sharedfiles/filedetails/?id=3775936786), created 2026-08-01 | Requires ZombieBuddy | Claims zombie/player ragdolls for all death sources and identical resting positions for all players. | No author-owned public source repository was located. The page gives no protocol, authority, failure-recovery, benchmark or exact-version detail. Treat as an unaudited Java binary. |
| [MP Ragdolls (Experimental)](https://steamcommunity.com/sharedfiles/filedetails/?id=3776721222), created 2026-08-03 | Requires ZombieBuddy | Claims B42.20 MP zombie ragdolls tested on one home server and explicitly says more testing is probably needed. | Useful proof-of-concept claim, but explicitly experimental; no author-owned source was located. |

Both mods claiming real MP ragdolls depend on ZombieBuddy. This is evidence that runtime Java patching may bypass guarded engine behavior, not that Lua can enable the feature.

### Search gaps and negative findings

- No Indie Stone announcement, forum patch note or hotfix through 2026-08-20 was found that explicitly re-enables MP ragdolls after the 2025-12-11 disablement.
- No official setting, server option, Lua API or supported modding recipe for MP ragdoll synchronization was found.
- No author-owned public source repository was found for Workshop items `3775936786`, `3776721222`, `3779997883` or `3780010932`.
- Because source was unavailable, this review could not verify whether the two ZombieBuddy MP mods synchronize final corpse state, merely trigger client-local physics, patch packet handling, or rely on undocumented behavior.
- No primary-source B42.20.3 MP performance benchmark for simultaneous ragdolls was found.

## Lua-only versus Java-agent approaches

### Lua-only mod

A Lua-only implementation can reasonably provide melee-hit/death chance calculation, server-side selection, cooldowns, distance budgets and an ordinary synchronized knockdown/fall animation.

The primary evidence does not support a Lua-only implementation that can:

- remove the engine condition disabling true ragdolls while a client/server is active;
- add physics state to the engine's network protocol;
- redirect corpse construction at the required internal boundary through documented APIs;
- guarantee that every client settles the physics body at one location;
- make a local physics body authoritative and persistent for late joiners.

The first-party mod pages reinforce this conclusion: Melee Ragdolls uses synchronized knockdown as its MP fallback, Tripping Zombies keeps server-authoritative trips but limits ragdolls to SP, and Zombies Trippin' removed MP after location/update failures.

### Java-agent or coremod

[ZombieBuddy](https://github.com/zed-0xff/ZombieBuddy) is an author-owned public framework that uses ByteBuddy and Java instrumentation to transform Project Zomboid classes at runtime. Its [README](https://github.com/zed-0xff/ZombieBuddy/blob/master/README.md) and [modding guide](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/ModdingGuide.md) document method interception, skipping/replacing original methods, retransformation of loaded classes, Java-to-Lua exposure, and separate client/server JAR paths. In principle, that is enough to bypass a mode guard and patch internal death/corpse lifecycle boundaries that Lua cannot reach.

The costs are substantial:

- Every client and the server need compatible agent installation and mod code.
- Windows setup changes launcher configuration and places a native loader/JAR in the game directory; macOS/Linux require `-javaagent` launch configuration.
- ZombieBuddy's [installation guide](https://github.com/zed-0xff/ZombieBuddy/blob/master/doc/Installation.md) warns that Java mods are unrestricted and can access files, networks and arbitrary Java APIs. Only reviewed source should be trusted.
- Game updates can change method signatures, ordering and invariants. Exact build gating and fail-closed behavior are mandatory.
- ZombieBuddy's [Workshop page](https://steamcommunity.com/sharedfiles/filedetails/?id=3619862853) lists older explicit B42 support than this pack's `42.20.3`, while its repository describes broader B42 support. The discrepancy requires local validation.
- Entering ragdoll mode does not by itself solve authoritative corpse placement, join-in-progress state or compatibility with unpatched peers.

The `Ragdolls in Multiplayer` uploader is linked to ZombieBuddy's signing ecosystem by the framework maintainer's [2026-08-16 author-list commit](https://github.com/zed-0xff/ZombieBuddy/commit/d1af5a9af60df538a77c361106bd76a864c2ad2f). This connects the Workshop identity to the framework, but is not a source audit of the ragdoll mod.

## Feasible prototype architecture

If this project experiments, the least risky design is hybrid Java/Lua: the server remains authoritative over gameplay and corpses, while clients own only temporary presentation.

1. **Exact-version gate:** load only on game `42.20.3` and Steam build `24909800`; abort cleanly on mismatch.
2. **Normal server death:** let the server process the lethal melee hit, kill credit, inventory and corpse creation.
3. **Compact visual event:** send zombie identity, root transform, facing, impulse class, seed and expiry time to relevant clients.
4. **Client-local physics:** create the approximate ragdoll presentation without letting it decide death, drops or credit.
5. **Server corpse authority:** initially preserve the server's normal corpse location even if a client's visual body settles elsewhere.
6. **Optional final correction:** only after the basic system is stable, accept one bounded final root transform from a designated authority. Validate distance, floor, room, obstruction and timing before moving the corpse once.
7. **No full-pose streaming:** send start parameters and, at most, one final root transform. Do not replicate bone state every tick.
8. **Hard fallback:** missing/denied Java code, mixed versions, disconnects, late joins, invalid positions and exhausted budgets must all produce a normal corpse.

This can plausibly deliver “a lethal melee hit makes the zombie locally collapse as a ragdoll.” It cannot cheaply guarantee identical limb poses for all players. Identical final poses would be a much larger networking project.

## Performance assessment

For four players, a tightly bounded cosmetic implementation is plausibly performant, but no primary-source benchmark establishes a safe MP budget for `42.20.3`.

Indie Stone introduced ragdolls with a request for performance reports, kept them optional, and continued changing collision/body dynamics. The Melee Ragdolls author notes that the game's maximum-active-ragdoll and clothing restrictions still apply. These support conservative budgeting, not a blanket “no performance impact” conclusion.

Expected costs are client rigid-body simulation and skinning, collision against vehicles/walls/stairs, Java interception in hot update methods, network corrections, and retained transition state before corpse settlement.

A reasonable first test budget is `4–8` nearby active zombie ragdolls per client, death-only activation, a short settle timeout and no continuous pose replication. This is a proposed test starting point, not an official limit.

## Decision for this repository

The modpack already references ZombieBuddy (`3619862853`) and Tripping Zombies (`3746603021`), but Workshop subscription does not prove that the Java agent is installed, compatible and approved on every machine.

Do not add either unaudited MP-ragdoll Workshop mod to the release profile solely on its description. If the group wants a trial, use a separate experimental profile and disposable world, verify agent hashes/source availability, and record:

- server timing with `0`, `4`, `8` and `16` simultaneous deaths;
- client frame-time spikes near walls, stairs and vehicles;
- final corpse-square agreement across all four clients;
- lootability and inventory persistence;
- late-join corpse visibility;
- reconnect, chunk unload/reload and server restart behavior;
- failure when one client has physics disabled or denies the Java patch.

Until those tests pass, synchronized knockdown animations are the maintainable MP solution. A private Java-agent proof of concept is technically feasible; a reliable synchronized MP ragdoll system is a core networking modification, not a small melee-effect mod.
