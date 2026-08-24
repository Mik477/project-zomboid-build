# Project Zomboid Build

A private, reproducible Project Zomboid setup for a four-player group using a large mod list. The project is intended to improve client and server performance, carry small custom features, and produce a low-friction installer for friends.

## Current status

The repository contains no redistributed Workshop mods or game files. Version `0.9.5` makes the opt-in multiplayer ragdolls more conservative and realistic: all impacts are redirected to the pelvis, weapon force and lift are reduced, vanilla shoulder restriction is reinforced, and bodies settle sooner without sustained assistance by default. It retains the `0.9.4` hybrid animation/physics controller, `0.9.3` Gael one-click unpack fix, `0.9.1` compact-marker crafting fix, package format, safety checks, installer, and measurement plan.

The current local reference environment is Project Zomboid `42.20.3` (Steam build `24775755`). See [the local workflow](docs/LOCAL-WORKFLOW.md) for the discovered mod inventory and guarded edit/sync process, and the [activated-mod compatibility audit](docs/MOD-COMPATIBILITY-AUDIT.md) before changing the shared order.

The custom compact looting mode is documented in [Compact Proximity Inventory](docs/COMPACT-PROXIMITY-INVENTORY.md).

The focused repo-owned patch selection and migration procedure are documented in [Patch Mod Layout](docs/PATCH-MOD-LAYOUT.md). The Gael-specific implementation is documented in [Gael Gun Store Patches](docs/GAEL-GUN-STORE-PATCHES.md).

The opt-in Java experiment is documented in [Multiplayer Ragdoll Prototype](docs/MULTIPLAYER-RAGDOLL-PROTOTYPE.md). It requires ZombieBuddy, builds outside repository source, and keeps authoritative corpses at their normal server positions.

## Goals

- Establish a repeatable performance baseline before changing files.
- Identify expensive or conflicting mods in the roughly 150-mod setup.
- Prefer original compatibility/performance mods over invasive base-game edits.
- Keep any unavoidable game-file overrides minimal, version-specific, optional, and reversible.
- Package group-owned changes and sanitized configuration into one friend-friendly archive.
- Support the current hosted server first and a dedicated server later.

## Repository layout

| Path | Purpose |
| --- | --- |
| `config/modpack.json` | Package metadata and ordered Workshop identifiers |
| `src/mods/` | Original mods maintained by this project |
| `src/game-overrides/` | Minimal files installed relative to the game directory |
| `patches/` | Reviewable text patches and patch notes for game/mod changes |
| `server/` | Sanitized server configuration templates |
| `scripts/` | Validation, packaging, and installation tooling |
| `docs/` | Performance evidence, compatibility notes, and decisions |

Downloaded Workshop content, game binaries, saves, player databases, and secrets do not belong in this repository or its release archives.

Machine-specific Steam, game, Workshop, user-data, and hosted-profile paths are discovered into ignored `config/local.json`; they are never written into the portable manifest.

## Build a friend package

From PowerShell:

```powershell
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
```

The build writes a versioned ZIP to `dist/`. A friend extracts that ZIP and runs:

```powershell
$gamePath = Read-Host 'Project Zomboid game directory'
$workshopPath = Read-Host 'Workshop content directory for app 108600'
./Install.ps1 -GamePath $gamePath -WorkshopPath $workshopPath
```

This exact-hash checks the game, ZombieBuddy, and the Workshop seams used by generated Java patches; installs group-owned user content beneath `%USERPROFILE%\Zomboid`; and backs up replaced files. Optional game-directory overrides are not installed unless the user also supplies `-IncludeGameOverrides`.

## First data to add

1. Review the exported hosted server Workshop item IDs, mod IDs, and maps, preserving load order.
2. Record operating system, hardware, resolution, and representative save/scenario for performance tests.
3. Capture a no-change baseline using the template in `docs/PERFORMANCE-PLAN.md`.
4. Add only original code/configuration or licensed content to `src/`.
5. Document each mod or base-game edit in `docs/CHANGELOG.md` with its measured effect.

## Compatibility rule

Every release must name an exact Project Zomboid version. "Latest" is not a reproducible target and can silently break patches or Lua behavior after an update.

## Local workflow

```powershell
./scripts/Initialize-LocalEnvironment.ps1
./scripts/Export-LocalModpack.ps1 -WhatIf
./scripts/Sync-ManagedFiles.ps1 -Direction Status
```

Use targeted `ToLocal` syncs to test repo-owned files and targeted `FromLocal` syncs only when an intentional local edit must be brought back. Workshop payloads and live server profiles are never imported wholesale.
