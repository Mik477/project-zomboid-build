# Agent Guide

Use this file as the routing index for repository work. It identifies the source of truth, the module that owns each behavior, and the focused validation path. Follow links to feature documents only after the owner is known.

## Start here

1. Classify the change with the routing table below. Completion: one owning source path and one focused test path are identified.
2. Read the owner's `42.20/mod.info`, entry point, tests, and owner document below before editing. Completion: dependencies, runtime side, and load-order requirements are known.
3. Edit the repository source, not the deployed game, user-mod, or Workshop tree. Completion: every durable change is below a tracked source path.
4. Run the focused validator. Deploy Lua/data changes with targeted `Sync-ManagedFiles.ps1`; deploy Java changes with the owning build/install script because managed sync excludes JARs. Test the behavior in the smallest suitable local session. Completion: the changed seam and deployed artifact are exercised in the runtime that loads them.
5. Run the readiness gate at the end of this file. Completion: source, local deployment, manifest, tests, package, and evidence agree.

## Sources of truth

| Concern | Authoritative source | Runtime or generated copy |
| --- | --- | --- |
| Enabled Workshop items, mod IDs, map order, game version, Steam build, package version | `config/modpack.json` | Client `mods/default.txt` and the selected hosted profile |
| Machine paths and selected hosted profile | Ignored `config/local.json`, created by `scripts/Initialize-LocalEnvironment.ps1` | Local machine only |
| Repo-owned mod behavior | `src/mods/<directory>/` | Zomboid user-mod directory |
| Optional base-game replacement | `src/game-overrides/` | Project Zomboid installation |
| Non-redistributable upstream change | `patches/` | Applied temporary/runtime tree |
| Mod ownership and edit routing | This file | None |
| Runtime dependencies and generated Java package | Each mod's `42.20/mod.info` | Loaded mod metadata |
| Load-order and migration rationale | `docs/PATCH-MOD-LAYOUT.md` | Ordered `Mods=` list and deployed directories |
| Local discovery, sync, deploy, and release workflow | `docs/LOCAL-WORKFLOW.md` | PowerShell scripts under `scripts/` |

Steam Workshop content is read-only evidence. Generated JARs and `dist/` archives are build outputs. Local profiles, saves, logs, databases, and backups are runtime data.

## Change routing

| Change or symptom | Owner | Edit here | Focused verification |
| --- | --- | --- | --- |
| Add, remove, enable, disable, or reorder a Workshop item, mod ID, or map | Modpack manifest | `config/modpack.json` | `scripts/Test-Project.ps1`; preview both apply scripts |
| Change package version or release description | Package metadata | `config/modpack.json`, `docs/CHANGELOG.md` | `scripts/Test-Project.ps1`, `scripts/Build-Package.ps1` |
| Compact nearby selector, occupied-row projection, crafting marker, or sticky selection | `CompactProximityInventory` | `src/mods/CompactProximityInventory/` | `scripts/Test-Project.ps1` static gate; standalone `tests/CompactProximitySelectionPolicy.test.lua`; in-game `CompactRowsTests.lua` and `NearbyContainersTests.lua` |
| Gael firearm Inventory Tetris footprint, render size, cache correction, or stock-state reflow | `GaelGunStoreInventoryTetrisCompatibility` | `src/mods/GaelGunStoreInventoryTetrisCompatibility/` | `scripts/Test-Project.ps1` static gate; in-game `GaelFirearmTetrisSizesTests.lua` |
| Inventory Tetris overflow hover, click, drag-source, or outside-release interaction | `InventoryTetrisOverflowInteractionFix` | `src/mods/InventoryTetrisOverflowInteractionFix/` | `scripts/Test-InventoryTetrisOverflowInteractionFix.ps1` |
| Swap It exchange between an equipped item and Alice Weapon Sling Back, including Fancy Handwork completion order | `SwapItWeaponSlingCompatibility` | `src/mods/SwapItWeaponSlingCompatibility/` | `scripts/Test-SwapItWeaponSlingCompatibility.ps1` |
| Inventory Tetris transfer, equip, key-ring, transaction, or recovery logging | `InventoryTetrisTransferDiagnostics` | `src/mods/InventoryTetrisTransferDiagnostics/` | `scripts/Test-InventoryTetrisTransferDiagnostics.ps1`; standalone pure-Lua fixtures under `tests/` |
| Repeated Wear, insert/eject/swap requests, or no-space held-item displacement during equip | `InventoryActionIntentFix` | `src/mods/InventoryActionIntentFix/`; optional Gael adapter in `GaelGunStoreCoreFixes/AutomaticMagazineSelection.lua` | `scripts/Test-InventoryActionIntentFix.ps1` |
| Gael ammo, package, recipe, magazine map, reload, storage, restored feed device, or Gael-owned visual correctness | `GaelGunStoreCoreFixes` | `src/mods/GaelGunStoreCoreFixes/` | `scripts/Test-GaelGunStorePatches.ps1`; in-game `DefinitionsTests.lua`, `MagazineCompatibilityTests.lua`, `AutomaticMagazineSelectionTests.lua` |
| Gael firearm spawn rates, vanilla retention, replacement pools, generated condition/magazine fill, zombie gun loot, case companions, or Minigun suppression | `GaelGunStoreLootDiversification` | `src/mods/GaelGunStoreLootDiversification/` | `scripts/Test-GaelGunStorePatches.ps1`, `scripts/Test-CompatibilityPatches.ps1`; in-game `FirearmSpawnDiversificationTests.lua` |
| Authentic Z smoke bomb, Bandits bucket, or Headhunter item-part visuals | `ItemVisualCompatibilityFixes` | `src/mods/ItemVisualCompatibilityFixes/` | `scripts/Test-GaelGunStorePatches.ps1` |
| Known and Collected Literature rendering under Inventory Tetris | `KnownAndCollectedInventoryTetrisCompatibility` | Its single client Lua file | `scripts/Test-LuaPatchMods.ps1` |
| Indoor This Is Your Life bushes | `TYLIndoorBushFix` | Its single server Lua file | `scripts/Test-LuaPatchMods.ps1` |
| PZ Map and PZ Pulse exporter cadence | `PZExporterCadenceTuning` | Its single client Lua file | `scripts/Test-LuaPatchMods.ps1` |
| Remote VAS vehicle-door close state | `VASRemoteDoorSyncFix` | Its single client Lua file | `scripts/Test-LuaPatchMods.ps1` |
| Trash and Corpses dead-zombie clothing failure | `TrashAndCorpsesSafetyFix` | Its Java source package | `scripts/Test-CompatibilityPatches.ps1` |
| SecretZ invalid `DespawnDoor` registration | `SecretZCommandRegistrationFix` | Its Java source package | `scripts/Test-CompatibilityPatches.ps1` |
| Kahlua `ReturnValues.put`/`MethodArguments` pool corruption or timed-action begin failures | `KahluaObjectPoolConcurrencyFix` | Its Java source package and race harness | `scripts/Test-KahluaObjectPoolRace.ps1`, `scripts/Test-CompatibilityPatches.ps1` |
| Frame, chunk, GC, action, or vehicle-entry measurement | `PZPerformanceDiagnostics` | `src/mods/PZPerformanceDiagnostics/` | `scripts/Test-PZPerformanceDiagnostics.ps1` |
| Multiplayer client-local death ragdoll experiment | `MultiplayerRagdollPrototype` | `src/mods/MultiplayerRagdollPrototype/` | `scripts/Test-MultiplayerRagdollPrototype.ps1` |
| Better Vehicle Dynamics manual Java payload | Deployment tooling only | `scripts/BetterVehicleDynamicsPayload.ps1`, `scripts/Install-BetterVehicleDynamics.ps1` | `scripts/Test-BetterVehicleDynamicsPayload.ps1`; installer exact local checks |
| New incompatibility not listed above | A new focused patch mod | New directory below `src/mods/` | Add a focused validator or extend the validator for that seam |

`InventoryTetrisOverflowInteractionFix` loads after the compact and Gael Inventory Tetris adapters. `InventoryActionIntentFix` is enabled immediately before `InventoryTetrisTransferDiagnostics`, which remains immediately before the last-loaded `PZPerformanceDiagnostics` mod. The latter two are observer-only. `MultiplayerRagdollPrototype` remains packaged but disabled in the shared manifest.

The `media/lua/.../Tests` modules register only when debug mode and Mod ID `\TEST_FRAMEWORK` are active. `Test-Project.ps1` performs repository/static assertions for these modules; it does not execute the in-game Test Framework suite. The root `tests/*.test.lua` files are standalone pure-Lua regressions, but this repository does not bundle a Lua interpreter or invoke them from `Test-Project.ps1`.

## Owner documents

| Owner family | Deep behavior and runtime acceptance |
| --- | --- |
| Compact nearby inventory | [Compact Proximity Inventory](COMPACT-PROXIMITY-INVENTORY.md) |
| Gael core, loot, Tetris sizing, and cross-mod visuals | [Gael Gun Store Patches](GAEL-GUN-STORE-PATCHES.md) |
| Focused patch activation and migration | [Patch Mod Layout](PATCH-MOD-LAYOUT.md) |
| Common Java compatibility guards | [Java Compatibility Patches](JAVA-COMPATIBILITY-PATCHES.md) |
| Performance instrumentation | [PZ Performance Diagnostics](PZ-PERFORMANCE-DIAGNOSTICS.md) |
| Inventory action intent compatibility | [Inventory Action Intent Fix](INVENTORY-ACTION-INTENT-FIX.md) |
| Inventory Tetris overflow interaction | [Inventory Tetris Overflow Interaction](INVENTORY-TETRIS-OVERFLOW-INTERACTION.md) |
| Swap It and Alice Weapon Sling exchange | [Swap It Weapon Sling Compatibility](SWAP-IT-WEAPON-SLING-COMPATIBILITY.md) |
| Ragdoll experiment | [Multiplayer Ragdoll Prototype](MULTIPLAYER-RAGDOLL-PROTOTYPE.md) |
| Manifest risk and established-world order | [Mod Compatibility Audit](MOD-COMPATIBILITY-AUDIT.md) |

## Multi-file module ownership

### Compact Proximity Inventory

| File | Responsibility |
| --- | --- |
| `CompactProximityInventory.lua` | Runtime installation and Inventory Tetris/UI wrappers |
| `NearbyContainers.lua` | Synthetic marker, nearby aggregation, ordering, and crafting-container filtering |
| `CompactRows.lua` | Occupied-row projection and source/display coordinate conversion |
| `SelectionGuard.lua` | Runtime interception that preserves explicit compact selection |
| `SelectionPolicy.lua` | Pure selection decision seam used by root tests |

Gael sizing and transfer diagnostics do not belong in this module.

### Gael Gun Store core

| File or directory | Responsibility |
| --- | --- |
| `media/lua/shared/GaelGunStoreCoreFixes/Definitions.lua` | Correctness catalog: package quantities, feed devices, firearm fields, maps, recipes, storage sets, and core visual aliases |
| `ScriptPatches.lua` | Applies shared script-item, package, firearm, tag, and visual mutations |
| `MagazineCompatibility.lua` | Repairs Gael runtime magazine maps and weapon-part mappings |
| `AutomaticMagazineSelection.lua` | Finds and inserts allowed magazine families from inventory and nested bags |
| `SafeAmmoUnpack.lua` | Additive-deployment tombstone that overwrites the retired client crafting hook; keep it even though it intentionally performs no interception |
| `ContainerCompatibility.lua` | Server-side bandolier and shoulder-holster acceptance |
| `LootCompatibility.lua` | Restored-device loot clones and obsolete `.30-06` device suppression |
| `media/scripts/` | New magazine definitions, reversible recipes, and model aliases |
| `media/lua/shared/Translate/` | User-visible item and recipe names |

Spawn balance and cross-mod visual repairs do not belong in core.

### Gael loot diversification

| File | Responsibility |
| --- | --- |
| `Definitions.lua` | Explicit retention/replacement policy and companion-item rules |
| `FirearmSpawnDiversification.lua` | Pure weighted-array transformation and conservation logic |
| `ApplyFirearmSpawnDiversification.lua` | Applies policy to procedural, legacy, vehicle, and bag distributions |
| `DiversifyGaelLoot.lua` | Applies the same policy to Gael-generated loot records |
| `LootStatePolicy.lua` | Pure condition and magazine-fill ranges plus secure-container classification |
| `InitializeLootState.lua` | Server/SP `OnFillContainer` initialization for newly generated world and nested-bag loot |
| `media/java-src/pzmod/gaellootdiversification/` | Strict zombie-inventory completion advice and server-authoritative recursive initialization |

### Java mods

Tracked Java source lives under `media/java-src`. `mod.info` declares the generated JAR path and ZombieBuddy package. `scripts/Build-CompatibilityPatch.ps1`, `scripts/Build-PZPerformanceDiagnostics.ps1`, and `scripts/Build-MultiplayerRagdollPrototype.ps1` compile outside repository source and exact-hash the game/upstream seams. Generated `media/java` JARs belong only in local deployment or package staging.

## Tool ownership

| Task | Script | Writes |
| --- | --- | --- |
| Discover Steam, game, Workshop, user, version, build, and hosted profile paths | `Initialize-LocalEnvironment.ps1` | Ignored `config/local.json` |
| Compare or copy repo-owned mods and declared overlays | `Sync-ManagedFiles.ps1` | Target selected by `-Direction`; additive and backup-first |
| Import public hosted-profile selection | `Export-LocalModpack.ps1` | `config/modpack.json` only |
| Apply ordered manifest to local client | `Apply-ModpackToLocalClient.ps1` | Client `mods/default.txt`, with backup |
| Apply ordered manifest to hosted server | `Apply-ModpackToLocalProfile.ps1` | Only `WorkshopItems`, `Mods`, and `Map`, with full profile backup |
| Build portable friend package | `Build-Package.ps1`; focused archive gate `Test-FriendPackage.ps1` | Ignored `dist/`, external third-party cache, and temporary staging |
| Install portable package | `Install-Package.ps1` | User mods and optional game overlay, with exact gates and backups |
| Retire old patch layout | `Migrate-PatchModLayout.ps1` | Removes only enumerated obsolete paths after replacement hash checks |
| Build/install common Kahlua, zombie-loot, Trash and Corpses, or SecretZ JARs | `Build-CompatibilityPatch.ps1`, `Install-CompatibilityPatches.ps1` | External build tree and local common JARs |
| Build/install performance diagnostics | `Build-PZPerformanceDiagnostics.ps1`, `Install-PZPerformanceDiagnostics.ps1` | External build tree and local client JAR |
| Build/install ragdoll prototype | `Build-MultiplayerRagdollPrototype.ps1`, `Install-MultiplayerRagdollPrototype.ps1` | External build tree and local client JAR |
| Validate all repository invariants | `Test-Project.ps1` | External temporary test/build directories only |

Focused Java build, test, install, and diagnostics summarizer scripts are named after the module they own. Keep a module-specific invariant in its focused validator; keep repository-wide path, manifest, safety, and orchestration invariants in `Test-Project.ps1`.

## Cross-cutting changes

### Add or rename a repo-owned mod

1. Create `src/mods/<directory>/42.20/mod.info` and keep the directory name stable for sync/package targeting.
2. Put behavior only in that focused module and declare real runtime requirements in `mod.info`.
3. Add the Mod ID to `config/modpack.json` only when it should be enabled; preserve dependency order and refresh `workshop.revision`.
4. Add required paths and order assertions to `scripts/Test-Project.ps1`.
5. Add or extend a focused validator and update this routing map plus `docs/PATCH-MOD-LAYOUT.md`.
6. If an old ID or moved file is already deployed, extend the backup-first migration because ordinary sync never deletes.

### Change the manifest

1. Preserve the order of all unaffected IDs and maps.
2. Refresh `workshop.revision`; it hashes the ordered `WorkshopItems`, `Mods`, and `Map` values.
3. Run `Test-Project.ps1` before applying anything locally.
4. Preview client and profile changes with `-WhatIf`; inspect every removal before using `-AllowRemovals`.
5. Test order changes against a cloned or disposable world before an established shared save.

### Change a Java patch

1. Edit `media/java-src` and keep `src/` free of generated JARs.
2. Re-audit and update exact hashes when the game, ZombieBuddy, or the reviewed Workshop seam changes.
3. Run the module's deterministic build/test script.
4. Install common guards with `Install-CompatibilityPatches.ps1`, diagnostics with `Install-PZPerformanceDiagnostics.ps1`, or ragdolls with `Install-MultiplayerRagdollPrototype.ps1`; a freshly built package is the distribution path.
5. Record the new fingerprint and require every participant to approve common/client JARs through ZombieBuddy.

### Update Project Zomboid or Steam build

Treat a version change as a compatibility audit, not a metadata-only edit. Update manifest compatibility, every affected `mod.info` version gate, builders, validators, installer hashes, docs, and runtime evidence together. A hash mismatch is a stop condition until the seam is re-audited.

## Runtime boundaries

- Use `src/mods/` as the normal edit location. A deployed user-mod copy is a test target.
- Use Workshop files only to inspect an exact upstream seam. Durable work becomes original compatibility code or a text patch.
- Use `config/modpack.json` for public server selection. A live profile is not repository source.
- Use `src/game-overrides/` only for an already-declared, version-gated minimal replacement.
- Keep raw diagnostics, saves, databases, credentials, addresses, local paths, generated binaries, and packages outside Git.

## Ready gate

A change is ready when all applicable conditions are true:

1. The owning module and its focused validator agree with the intended behavior.
2. Runtime testing used the exact game version and Steam build recorded in `config/modpack.json`.
3. `scripts/Sync-ManagedFiles.ps1 -Direction Status` reports the intended local/source state; add `-IncludeGameOverrides` when `src/game-overrides/` changed.
4. `scripts/Test-Project.ps1` passes.
5. `scripts/Build-Package.ps1` succeeds and contains no retired or generated-source artifacts.
6. Gameplay, compatibility, or performance changes have reproduction steps and material evidence in `docs/`.
7. `git status`, diff, staged paths, and ignored files contain no runtime/private data.

See `docs/LOCAL-WORKFLOW.md` for command detail and `docs/PATCH-MOD-LAYOUT.md` for current activation/load-order policy.
