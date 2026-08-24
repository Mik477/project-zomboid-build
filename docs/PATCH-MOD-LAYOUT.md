# Patch Mod Layout

Date: 2026-08-24
Target: Project Zomboid 42.20.3, Steam build 24775755

The repo-owned patch set is organized by one upstream seam or one explicit modpack policy per mod. The retired catch-all IDs are `GaelGunStoreAmmoStorageFixes`, `ModpackCompatibilityFixes`, and `PZPerformanceFixes`.

## Enabled patches

| Mod ID | Responsibility | Required/load-order context |
|---|---|---|
| `CompactProximityInventory` | Synthetic nearby selector, occupied-row projection, crafting-marker filtering, and sticky selection | Immediately after `INVENTORY_TETRIS` |
| `GaelGunStoreInventoryTetrisCompatibility` | Stock-aware Gael firearm footprints and Inventory Tetris render/cache correction | After Compact Proximity Inventory; requires Gael and Inventory Tetris at runtime |
| `KnownAndCollectedInventoryTetrisCompatibility` | Build 42 Literature renderer containment | Immediately after `KnownAndCollected`; requires ZombieBuddy and Inventory Tetris |
| `TYLIndoorBushFix` | Prevent and remove indoor TYL bushes | Immediately after `TYL_B42_STABLE_UNOFFICIAL` |
| `PZExporterCadenceTuning` | Shared one-second PZ Map/Pulse exporter policy | Immediately after `PZ_Pulse` |
| `VASRemoteDoorSyncFix` | Remote VAS close-state correction | Immediately after `VASinked` |
| `GaelGunStoreCoreFixes` | Corrected ammo/package/magazine/firearm model, conversions, reload/storage compatibility, restored devices, and Gael-owned visuals | Immediately after `GaelGunStore_B42` |
| `GaelGunStoreLootDiversification` | Firearm retention/replacement policy, distribution rewriting, companion magazines, and Minigun suppression | Immediately after Gael core fixes |
| `ItemVisualCompatibilityFixes` | Authentic Z smoke bomb, Bandits bucket, and Headhunter visual-part mappings | After all target mods |
| `TrashAndCorpsesSafetyFix` | Dead/detached zombie clothing condition guard | Immediately after `TrashAndCorpses`; ZombieBuddy common JAR |
| `SecretZCommandRegistrationFix` | Invalid `DespawnDoor` assignment guard | Immediately after `Secretz42`; ZombieBuddy common JAR |
| `PZPerformanceDiagnostics` | Exact-build measurement instrumentation | Last enabled mod |

## Packaged but disabled

`InventoryTetrisTransferDiagnostics` is opt-in instrumentation for transfer, equip, key-ring, transaction, and recovery traces. It is packaged but intentionally absent from `config/modpack.json` for normal sessions.

`MultiplayerRagdollPrototype` remains an opt-in prototype and is not enabled in the shared manifest.

## Migration

The sync workflow is additive and cannot retire old local mod directories or moved-out files. Install the replacement package on every participant first. Then stop the game and hosted server and run:

```powershell
./scripts/Migrate-PatchModLayout.ps1 -WhatIf
./scripts/Migrate-PatchModLayout.ps1
./scripts/Apply-ModpackToLocalClient.ps1 -WhatIf
./scripts/Apply-ModpackToLocalClient.ps1 -AllowRemovals
./scripts/Apply-ModpackToLocalProfile.ps1 -WhatIf
./scripts/Apply-ModpackToLocalProfile.ps1 -AllowRemovals
```

The migration script refuses to remove anything until every replacement mod is installed. It backs up and removes only the three retired repo-owned mod directories and the known Gael-sizing/transfer-diagnostics files moved out of `CompactProximityInventory`. Do not load an old catch-all ID alongside its replacements. Apply the order change first to a cloned or disposable world, retain the previous manifest revision and backup, then fully restart every participant.

The benign MWP `Base` self-import log messages are intentionally left unpatched. The former parser hook could not prove that a matching token came from MWP, so a dedicated Java mod would have changed an engine-wide seam for cosmetic benefit.

## Validation

```powershell
./scripts/Test-GaelGunStorePatches.ps1
./scripts/Test-LuaPatchMods.ps1
./scripts/Test-CompatibilityPatches.ps1
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
```

Generated Java JARs belong only in local deployment or package staging. Every participant must approve all common-JAR fingerprints through ZombieBuddy.
