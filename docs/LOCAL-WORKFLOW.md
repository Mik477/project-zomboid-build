# Local Project Zomboid workflow

This repository is the reviewable source of truth for group-owned changes. The local Project Zomboid installation is the runtime and test environment. Steam Workshop is the distributor for third-party mods.

## Observed installation

The local inspection on 2026-08-20 found:

| Layer | Observation |
| --- | --- |
| Game | Project Zomboid `42.20.3` |
| Steam build | `24775755` |
| Steam branch | No beta key recorded in the app manifest |
| Installed Workshop items | 175; Steam subscriptions were still changing during the audit |
| Workshop metadata | 471 `mod.info` files and 227 unique mod IDs |
| Hosted profile | 140 Workshop items, 162 enabled mod IDs (including the repo-owned compact proximity patch), and 6 maps |
| Hosted-profile readiness | All 140 configured Workshop items are installed |
| Installed but not in hosted profile | 35 Workshop items, including deliberately held or unreviewed downloads |
| Exported hosted selection | 162 mod IDs |
| User mods | Only the shipped `examplemod` was found outside Workshop |

“Installed” is not the same as “enabled.” The hosted profile is authoritative for the group modpack; extra subscriptions stay local unless deliberately added to that profile and exported.

## Ownership boundaries

| Local content | Repository representation | Rule |
| --- | --- | --- |
| Steam Workshop item | IDs in `config/modpack.json`; optional text patch in `patches/` | Do not copy or commit downloaded content. Do not use the Workshop directory as durable source. |
| Group-owned custom mod | `src/mods/<mod-directory>/` | This is editable and distributable source. Keep its `mod.info`, attribution, and license with it. |
| Base-game change | Minimal mirror below `src/game-overrides/` or a text patch below `patches/` | Version-gate it, back it up, and prefer a mod or patch over a whole upstream file. |
| Hosted-server profile | Public allowlist fields in `config/modpack.json`; sanitized templates in `server/` | Export only `WorkshopItems`, `Mods`, and `Map`. Never copy the live profile. |
| Saves, databases, logs, presets, credentials | No tracked representation | Keep local. Use sanitized measurements or summaries in `docs/`. |
| Machine paths and selected profile | Ignored `config/local.json` | Generate locally; never commit it. |

## One-time discovery

Close Project Zomboid and its hosted server before a write sync. Then run:

```powershell
./scripts/Initialize-LocalEnvironment.ps1
```

The script discovers Steam through its registry/library metadata, locates app `108600`, detects the current version from local logs, selects the only or most recently modified hosted profile, and writes ignored `config/local.json`. If several profiles exist, select one explicitly:

```powershell
./scripts/Initialize-LocalEnvironment.ps1 -ServerProfilePath $profilePath
```

Never pass or record the profile path in commits, issue text, test fixtures, or release notes.

## Sync the enabled modpack metadata

Preview the public export first, then apply it:

```powershell
./scripts/Export-LocalModpack.ps1 -WhatIf
./scripts/Export-LocalModpack.ps1
git diff -- config/modpack.json
```

The exporter reads only the three public modpack keys. It preserves their server order, rejects duplicate IDs, reports configured Workshop items missing from the local installation, and derives a SHA-256 revision fingerprint from the ordered values.

When an ordered change has first been reviewed in `config/modpack.json`, preview and apply only those three public fields back to the selected hosted profile:

```powershell
./scripts/Apply-ModpackToLocalProfile.ps1 -WhatIf
./scripts/Apply-ModpackToLocalProfile.ps1 -Confirm:$false
```

This direction also requires the game and server to be stopped. It backs up the complete local profile, but replaces only `WorkshopItems`, `Mods`, and `Map`; private settings never enter the repository or command output. If the manifest would remove any established entry, `-WhatIf` lists the removals and a real write refuses unless `-AllowRemovals` is supplied after an existing-world compatibility review. Export again afterward to confirm an identical revision.

## Work on a group-owned mod

Create or adopt a directory below `src/mods/` only when the group owns the code or its license permits redistribution. Use the repository copy as the normal editing location.

Preview and deploy one mod to the local user-mod directory:

```powershell
./scripts/Sync-ManagedFiles.ps1 -Direction Status -Mod ExampleGroupMod
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod ExampleGroupMod -WhatIf
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod ExampleGroupMod
```

If an edit was intentionally made in the deployed local copy, pull back only that already-managed mod:

```powershell
./scripts/Sync-ManagedFiles.ps1 -Direction FromLocal -Mod ExampleGroupMod -WhatIf
./scripts/Sync-ManagedFiles.ps1 -Direction FromLocal -Mod ExampleGroupMod
git status --short
git diff -- src/mods/ExampleGroupMod
```

The sync is additive and never deletes destination-only files. Changed destination files are copied to the local Zomboid backup tree before replacement. Executables, archives, databases, logs, and other unsafe runtime files are excluded from local-to-repository mod sync.

## Work on a base-game override

Add only the intended relative file to `src/game-overrides/`, document why a mod or text patch is insufficient, and record the exact compatible game/Steam build. Preview before deployment:

```powershell
./scripts/Sync-ManagedFiles.ps1 -Direction Status -IncludeGameOverrides
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -IncludeGameOverrides -WhatIf
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -IncludeGameOverrides
```

Game-override sync stops on a Steam build mismatch. It considers only files already represented in the overlay; it never scans or imports the whole game. Steam verification or an update can replace deployed overrides, so the repository copy and generated backup are the recovery sources.

## Workshop experiments

Do not make durable edits inside Steam Workshop content. For a temporary diagnosis:

1. Record the Workshop item ID, mod ID, installed update time, and exact game version.
2. Copy only the relevant text file into an ignored working area.
3. Make the experiment reproducible as a text patch under `patches/` or as original compatibility code under `src/mods/`.
4. Preserve attribution and license information.
5. Restore or re-verify the Workshop item after the experiment.

Never sync a Workshop item into `src/mods/` merely because it is installed locally.

## Better Vehicle Dynamics Java overlay

Better Vehicle Dynamics Workshop item `3728775267` contains Lua content plus a Build 42.20 Java overlay that Steam cannot install into the game directory. The overlay is a local deployment, never repository content. Close the game and hosted server, preview the exact copy, and then install it:

```powershell
./scripts/Install-BetterVehicleDynamics.ps1 -WhatIf
./scripts/Install-BetterVehicleDynamics.ps1
```

The installer discovers both trees through ignored `config/local.json`, accepts only the item's `B42.20_Manual_Install` class payload, checks the exact game version and Steam build against `config/modpack.json`, refuses to run while Project Zomboid is active, backs up every replaced class, and verifies copied SHA-256 hashes. Its local rollback manifest is written below the user's Zomboid backup tree.

Run it again after every Project Zomboid update, but only after the repository manifest has been reviewed and updated for the new exact build. Every connecting player must perform the same installation. A future dedicated server needs the corresponding overlay in its own Java class tree; that deployment is deliberately separate from this hosted-client workflow.

## Multiplayer ragdoll prototype

The experimental ragdoll mod contains reviewable Java source but no tracked JAR. Build and install it with the dedicated exact-version script:

```powershell
./scripts/Test-MultiplayerRagdollPrototype.ps1
./scripts/Install-MultiplayerRagdollPrototype.ps1 -WhatIf
./scripts/Install-MultiplayerRagdollPrototype.ps1
```

The preflight builds the JAR and compiles a caller from an external game package to catch ZombieBuddy advice-access regressions. The compiler cache and class output stay below `%LOCALAPPDATA%\project-zomboid-build`. The generated JAR is written only into the local user mod or package staging directory. Follow `docs/MULTIPLAYER-RAGDOLL-PROTOTYPE.md` and use a disposable hosted world.

## Focused patches and diagnostics

The Lua compatibility behavior is split into `KnownAndCollectedInventoryTetrisCompatibility`, `TYLIndoorBushFix`, `PZExporterCadenceTuning`, and `VASRemoteDoorSyncFix`. Java guards and Gael work are likewise split by upstream seam. `PZPerformanceDiagnostics` remains the exact-build ZombieBuddy client probe used for before/after evidence. Follow `docs/PATCH-MOD-LAYOUT.md` and test/deploy with:

```powershell
./scripts/Test-LuaPatchMods.ps1
./scripts/Test-CompatibilityPatches.ps1
./scripts/Test-GaelGunStorePatches.ps1
./scripts/Test-PZPerformanceDiagnostics.ps1
./scripts/Install-CompatibilityPatches.ps1 -WhatIf
./scripts/Install-CompatibilityPatches.ps1
./scripts/Install-PZPerformanceDiagnostics.ps1 -WhatIf
./scripts/Install-PZPerformanceDiagnostics.ps1
./scripts/Migrate-PatchModLayout.ps1 -WhatIf
./scripts/Migrate-PatchModLayout.ps1
./scripts/Summarize-PZPerformanceDiagnostics.ps1
```

Install or synchronize all replacement patch mods before running the migration; it refuses to retire old directories or moved-out Compact files while replacements are missing. The generated diagnostics JAR stays outside repository source. Raw JSONL logs remain below the local Project Zomboid cache and must not be committed. Follow `docs/PZ-PERFORMANCE-DIAGNOSTICS.md` for the short vehicle-entry/fast-travel A/B route and acceptance criteria.

## Ready, commit, and push

A change is ready only after the local runtime test and repository review agree:

```powershell
./scripts/Sync-ManagedFiles.ps1 -Direction Status
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
git status --short
git diff
```

For gameplay or performance work, also add reproduction steps and before/after evidence under `docs/`. Update `docs/CHANGELOG.md` and the package version when producing a release candidate.

Commit one coherent, reviewed change at a time. Before staging, confirm no local config, live server file, save, database, log, Workshop payload, game binary, password, IP address, or absolute local path is present. Inspect the staged diff again before committing. Commit and push only on explicit request; pushing is a publication step, not part of syncing files from the game.
