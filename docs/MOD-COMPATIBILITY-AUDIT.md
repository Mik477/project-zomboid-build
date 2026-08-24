# Activated Mod Compatibility and Load-Order Audit

Audit date: 2026-08-20

Tested configuration: Project Zomboid `42.20.3`, Steam build `24775755`, hosted four-player profile, modpack revision `sha256:a2f956ec37845464e3da03e3246339dc79862fe0bda2a9999318899de7e8ab0f`.

This is a static and observed-runtime audit of the 138 Workshop items, 162 enabled mod IDs, and 10 configured map folders in `config/modpack.json`. It combines effective Build 42 `mod.info` metadata, the installed Lua/script assets, the latest local client and hosted-server logs, map cell inventories, and the mod authors' current Workshop documentation. No live configuration was changed.

> **Applied cleanup:** This document preserves the original audited baseline. The requested first cleanup was applied later on 2026-08-20 as modpack revision `sha256:43fdbb301194d431a1bb8d872c5c1a60af50ac5b00cbc71f97e13b26e4ed9d06`: Project RV and all active PZK-branded IDs were removed, only `ETO_P` was retained, Arcadia's map was moved first with `Muldraugh, KY` last, and the BVD Java overlay was installed locally. The revised profile contains 140 Workshop items, 161 mod IDs, and six map folders. See `docs/NEW-VEHICLE-MODS-AUDIT.md` for the separately reviewed vehicle additions and exclusions.

## Verdict

The current order satisfies all 80 active hard `require=` relationships, and every configured mod ID resolves to installed Workshop content. That is not enough to make the pack compatible. Several conflicts use advisory metadata, replace the same assets or functions, or are documented only by their authors.

The current profile should not be treated as release-ready. The principal blockers are:

1. Two explicitly incompatible RV-interior systems are enabled together.
2. The map order contradicts the Arcadia RV requirement and places `Muldraugh, KY` first instead of last.
3. Most enabled map payloads are absent from `Map=`, while blindly adding them would introduce known cell collisions.
4. Both mutually exclusive Every Texture Optimized variants are enabled; the second completely shadows the first.
5. `PzkVanillaPlusCarPack` violates four of its active `loadAfter` constraints and is enabled with two IDs that its own metadata marks incompatible.
6. Better Vehicle Dynamics reports that its required Java-side installation is missing.
7. Several enabled mods have reproducible, order-independent runtime or source defects.

Changing mod or map order on an established save is risky. Back up the save and validate this plan on a cloned or new world before adopting it. The [Mod Load Order Sorter author](https://steamcommunity.com/sharedfiles/filedetails/?id=3423660713) also warns that mid-save order changes can prevent a save from loading; that mod edits client option screens and does not enforce the hosted server's runtime order.

## High-confidence incompatibilities and faults

| Severity | Finding | Local evidence | Recommended action |
| --- | --- | --- | --- |
| Critical | Arcadia RV and Project RV Interior are both enabled. | `ArcadiaRVInterior_B42_MP`/`ArcadiaRVInterior_B42_Vanilla` coexist with `PROJECTRVInterior42`, both expansion parts, the military add-on, and `rvinteriormanager`. Both systems patch the vehicle radial menu and maintain different interior-map assignments. | Keep exactly one family. For this MP pack, prefer the smaller Arcadia pair and remove the Project RV family and its four map folders. Alternatively, remove Arcadia completely. Do not attempt to solve this by ordering both. |
| Critical | Arcadia's map is in the wrong position. | `vehicle_interior_arcadia75` is ninth; `Muldraugh, KY` is first. | If Arcadia is retained, put its interior map first, all selected exterior maps after it, and `Muldraugh, KY` last. |
| High | Both Every Texture Optimized variants are enabled. | `ETO_B` and `ETO_P` each contribute the same 6,141 relative media paths. The runtime log records `ETO_P` overriding `ETO_B`. | Keep only `ETO_P` for maximum performance, or only `ETO_B` for better texture quality. The current effective choice is `ETO_P`; keeping `ETO_B` adds work and ambiguity without providing its full visual set. |
| High | PZK's declared order is violated. | Effective `PzkVanillaPlusCarPack` metadata declares `loadafter` for `tsarslib`, `ImmersiveVehiclePaint`, `StandardizedVehicleUpgrades3Core`, and `StandardizedVehicleUpgrades3V`; all four currently load later. | Put those four providers before PZK. Keep the PZK-specific Carzone and Simple Lightbars patches after PZK and their other bases. |
| High | PZK declares two active KI5 expansions incompatible. | Active PZK metadata lists `85chevyStepVanexpanded` and `93chevySuburbanExpanded` in `incompatible=`; both are enabled. | If PZK is retained, remove those two expansion IDs. If their content is preferred, remove PZK instead. |
| High | Better Vehicle Dynamics is not fully installed. | The hosted log repeatedly reports that Better Vehicle Dynamics is not properly installed. Its Java-side version check fails. | Disable it unless the host and all four clients deliberately install the exact matching Java component after every game update. Never put those third-party Java binaries in this repository. |
| High | Immersive Vehicle Paint calls a nonexistent function. | Its effective item script sets `OnCreate = SpecialLootSpawns.OnCreateRecipeMagazine`; that function is absent from the game and every installed Workshop Lua tree. The error occurs in the runtime log. | Order cannot fix it. Disable it or create a narrow, attributed, version-gated text patch after reproducing the intended callback. PZK's relationship to it must be retested if it is removed. |
| High | SecretZ has an active server-side Lua failure. | The runtime reaches `SZCServer.lua` and attempts to index a non-table `Commands` value while registering `DespawnDoor`. | Treat SecretZ as experimental. Update, patch narrowly, or disable it before relying on its doors/operations in a persistent world. |
| Medium-high | Vanilla Vehicles Animated lacks its author's MP sync patch. | The base mod and its SVU compatibility patch are active, but Workshop item `3685499657` is absent. | Add the linked Build 42 MP sync patch immediately after the VVA base, then keep VVA add-ons/compatibility patches after it. Test with a remote client, not only the host. |
| Medium-high | `LEGION18` declares `LG.SpawnChance` twice with incompatible types. | The effective Build 42.15 `sandbox-options.txt` repeats the option, and the runtime log reports that it cannot parse it. | Update or disable the mod, or use a version-gated one-line patch after confirming the author's intended numeric definition. Do not trust the current spawn-chance value. |
| Medium | Blackpine and 10 Years Later trade performance for overlapping overgrowth. | Both `BlackpineCounty` and `TYL_B42_STABLE_UNOFFICIAL` are active. | For the performance-focused four-player build, disable 10 Years Later on Blackpine or use its light/grass-only option. The map author explicitly warns about FPS loss from combining their vegetation. |

The RV conflict is documented on the [Arcadia RV page](https://steamcommunity.com/sharedfiles/filedetails/?id=3773972040), [RV Interior Expansion](https://steamcommunity.com/sharedfiles/filedetails/?id=3618427553), and [Expansion Part 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3622163276). Arcadia also specifies that its interior map must precede exterior maps. The relevant author documentation for the other findings is available on [Every Texture Optimized](https://steamcommunity.com/sharedfiles/filedetails/?id=3119788162), [PZK Vanilla Plus Car Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3217685049), [Immersive Vehicle Paint](https://steamcommunity.com/sharedfiles/filedetails/?id=3464606086), [Better Vehicle Dynamics](https://steamcommunity.com/sharedfiles/filedetails/?id=3728775267), [Vanilla Vehicles Animated](https://steamcommunity.com/sharedfiles/filedetails/?id=3281755175), and [Blackpine County](https://steamcommunity.com/sharedfiles/filedetails/?id=3565649631).

## Map audit

The enabled Workshop content exposes 37 `media/maps/*/map.info` folders. Only nine custom folders appear in the hosted `Map=` setting; 28 are omitted. The omitted content includes the primary folders for Grapeseed, Begonia Town, Blackpine County, Camden County, Cathaya Valley, Dawn Town, Dustwell, Fort JadeLake, HavenFall, and the SecretZ map additions.

An enabled map mod whose folder is absent from `Map=` may still provide Lua or assets, but its world cells are not part of the configured world. The latest hosted startup log also printed an empty custom map-folder scan, which is strong evidence that the current Muldraugh-first configuration did not load the intended exterior cells in that run. Confirm this in a clean startup log after rebuilding `Map=`.

Do not add all 28 omitted folders as a mechanical fix. The installed cell inventories include these overlaps:

| Pair or area | Overlap found | Consequence |
| --- | ---: | --- |
| Camden County / vanilla map | 607 cells | Camden is not a harmless additive town; enabling it requires an intentional world-layout decision. |
| Raven Creek / vanilla map | 46 cells | Raven Creek must precede vanilla so its intended cells win. |
| Blackpine / vanilla map | 40 cells | Same explicit priority decision. |
| Grapeseed / vanilla map | 24 cells | Same explicit priority decision. |
| SecretZ Louisville additions / vanilla map | 22 cells | SecretZ must be ordered as a deliberate overlay. |
| HavenFall / vanilla map | 16 cells | Same explicit priority decision. |
| Grapeseed / SecretZ additions | 5 cells across two additions | Both cannot own every overlapping cell. Pick a winner by order or omit one. |
| HavenFall / SecretZ Deerhead Lake | 2 cells | Pick a winner by order or omit one. |

SecretZ's author lists Grapeseed as a known conflict and says load order selects the preferred cells. The current SecretZ port is labelled Build 42 alpha, while [Grapeseed's Build 42 page](https://steamcommunity.com/sharedfiles/filedetails/?id=2463499011) also documents unresolved world issues. See the [SecretZ author page](https://steamcommunity.com/sharedfiles/filedetails/?id=3494374578) before committing either map to a persistent save.

### Recommended map-order skeleton

For the recommended Arcadia-only RV choice:

```text
vehicle_interior_arcadia75;
[selected custom exterior maps, highest-priority collision winner first];
[spawn-only overlays that do not own cells];
Muldraugh, KY
```

For the currently configured non-Project-RV subset, a reasonable test candidate is:

```text
vehicle_interior_arcadia75;Raven Creek B42;This Is Your Life;Spawn Selector;AZSpawn;Muldraugh, KY
```

This is a test candidate, not permission to change the live save. Before enabling the other town maps, inventory every folder name belonging to each Workshop item, generate the complete cell collision matrix, decide which map wins each overlap, and validate spawn points and travel on a new world.

If Project RV is selected instead, remove both Arcadia mod IDs and `vehicle_interior_arcadia75`, retain only the Project RV family's documented interior folders, put them before exterior maps, and still keep `Muldraugh, KY` last.

## Code-level interactions that dependency metadata misses

### Order-dependent tradeoffs

- `PzkVanillaPlusCarPack` and `tsarslib` both define the six `Base.500Tank*`/`Base.1000Tank*` items and global tanker actions. Tsar currently wins, changing PZK's nominal 500-unit tanks to Tsar's 461-unit definition and changing weights. Following PZK's declared `loadAfter` reverses that choice so PZK wins.
- `tsarslib` and `rSemiTruck` both replace `ISVehicleMechanics:doDrawItem` without delegating. The later `rSemiTruck` implementation currently removes Tsar's custom battery/fuel-tank display globally. Reordering can choose a winner, but preserving both requires a compatibility wrapper.
- Authentic Z, Gael's Gun Store, and Undead Survivor each replace `ISHotbar:getSlotForKey`. The latter two also add the same extended-hotbar keybindings without de-duplication. The final Undead implementation wins and duplicate settings entries are expected; order alone cannot repair registration.
- KillCount's Bandits compatibility checks the old ID `Bandits` while this pack enables `Bandits2`, and it requires a misspelled `BanditCharacterScren` path. The intended layout correction never activates. Current ordering preserves basic wrapping, but the character screen needs an explicit compatibility patch or KillCount should be disabled.
- Inventory Tetris replaces fundamental inventory behavior and is a save-level commitment. Its author warns that it is not freely removable and may conflict with other inventory/container UI mods. Keep Starlit Library and Alice's Weapon Sling before it if retained. See the [Inventory Tetris compatibility notes](https://steamcommunity.com/sharedfiles/filedetails/?id=3775513231).

### Known-good relative chains to preserve

Most shared hooks are cooperative wrappers rather than destructive replacements. Preserve these relative constraints during any cleanup:

```text
damnlib < all KI5 vehicles and KI5 add-ons
Bandits2 < BanditsCreator < TrueCompanions
StarlitLibrary < ZomboidForge < TLOU_Infected_42_20
GaelGunStore_B42 < GaelGunStoreCoreFixes < GaelGunStoreLootDiversification
StarlitLibrary < INVENTORY_TETRIS
alicesWeaponSling < FancyHandworkB42_19
alicesWeaponSling < INVENTORY_TETRIS
SpawnSelector < POM
twistdufflebag < twistdufflebag_authenticz
VanillaVehiclesAnimated < VVA add-ons < VanillaVehiclesAnimated_SVU
```

The duffle-bag patch order matches the [author's compatibility instructions](https://steamcommunity.com/sharedfiles/filedetails/?id=3737772445).

## Recommended minimal-delta mod order

A wholesale category sort is not recommended. It would change the winner of many Lua monkey patches without improving the 80 already-correct hard dependencies. Use this sequence of changes instead:

1. Remove `ETO_B`; retain `ETO_P` near the beginning for the performance profile. Choose the opposite only if visual quality is intentionally preferred.
2. Retain `ArcadiaRVInterior_B42_MP` and `ArcadiaRVInterior_B42_Vanilla`; remove `PROJECTRVInterior42`, `RVInteriorExpansion`, `RVInteriorExpansionPart2`, `RVmilitaryaddon`, and `rvinteriormanager`. Remove their map folders from `Map=`.
3. If keeping PZK, remove `85chevyStepVanexpanded` and `93chevySuburbanExpanded`.
4. Replace the current PZK/framework segment with this relative order:

   ```text
   tsarslib
   StandardizedVehicleUpgrades3Core
   StandardizedVehicleUpgrades3V
   SimpleLightbarsExpanded
   SimpleWheelsExpanded
   ImmersiveVehiclePaint
   PzkVanillaPlusCarPack
   rSemiTruck
   PZKCarzoneWorkshop
   SimpleLightbarsExpandedPZK
   ```

   Do not release that segment until the Immersive Vehicle Paint callback is fixed or the PZK/IVP relationship is deliberately revised. Leaving `rSemiTruck` after PZK preserves its current vehicle-menu precedence, including the documented Tsar vehicle-mechanics display tradeoff.
5. Add the VVA MP sync patch after `VanillaVehiclesAnimated`, then retain all existing VVA add-ons and `VanillaVehiclesAnimated_SVU` after it.
6. Preserve all unaffected IDs in their current relative order, especially the known-good chains above.
7. Rebuild `Map=` independently from `Mods=` using the map skeleton and collision policy above.

This recommendation intentionally does not pretend that one universal full ordering exists. The remaining choices are gameplay policy:

- `ETO_P` performance versus `ETO_B` texture quality;
- Arcadia's smaller MP-focused RV stack versus Project RV's expansion ecosystem;
- PZK's consolidated vehicle behavior versus the two incompatible KI5 expansions;
- PZK versus Tsar tanker values and UI behavior;
- SecretZ/Grapeseed/HavenFall map cells at known overlaps;
- Better Vehicle Dynamics' deeper physics versus fragile, manual Java deployment;
- Blackpine/10 Years Later overgrowth versus client FPS.

## Additional drift warnings

The effective Build 42 layer resolver selected many generic `42.0`, `42.13`, and `42.15` variants on game version `42.20.3`. Their metadata does not formally reject this game version, but the runtime log contains several signs of API drift:

- PZK tries to insert into an uninitialized West Point profession-vehicle table.
- Bandits, ZomboidForge, TLOU Infected, the PZK Simple Lightbars patch, More Maps, and the community tile pack emit missing-module warnings.
- More than 200 missing vehicle-template reports and extensive animation-bone noise appear during startup/gameplay. Some are upstream asset ordering problems; do not attribute them all to the global mod order without isolated reproduction.
- Authentic Z contains other `SpecialLootSpawns` callback references that are absent locally, although the audited log did not execute those paths.

These are candidates for controlled bisection, not justification for arbitrary reordering.

## Validation gate

Before changing the shared profile:

1. Back up the hosted save and retain the current ordered manifest revision.
2. Make the removal/order changes in a disposable profile, not the live profile.
3. Start a new world and confirm the startup log enumerates every intended map folder in the intended order.
4. Visit each map boundary and RV interior; test vehicle entry, mechanics, tankers, paint magazines, animated doors, keybindings, character UI, inventory containers, and remote-player vehicle state.
5. Run at least one four-player session on the fixed performance route described in `docs/PERFORMANCE-PLAN.md`.
6. Re-run repository validation and export the tested order only after the test profile is stable.

The active manifest and live profile remain unchanged by this audit.
