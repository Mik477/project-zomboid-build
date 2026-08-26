# Project Zomboid Build

A private, reproducible Project Zomboid setup for a four-player group using a large mod list. The project is intended to improve client and server performance, carry small custom features, and produce a low-friction installer for friends.

## Current status

The repository contains no redistributed Workshop mods or game files. The current manifest organizes repo-owned behavior into focused patch mods for compact inventory, Gael correctness and loot policy, item visuals, Lua compatibility, Java safety guards, and observer-only diagnostics. The multiplayer ragdoll prototype remains packaged but disabled by default.

The current local reference environment is Project Zomboid `42.20.3` (Steam build `24909800`). See [the local workflow](docs/LOCAL-WORKFLOW.md) for the discovered mod inventory and guarded edit/sync process, and the [activated-mod compatibility audit](docs/MOD-COMPATIBILITY-AUDIT.md) before changing the shared order.

Agents should start with the [Agent Guide](docs/AGENT-GUIDE.md) to locate the owning module, edit path, focused validator, and deployment workflow for a change.

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

`docs/AGENT-GUIDE.md` is the responsibility and edit-routing index. `docs/ARCHITECTURE.md` defines ownership boundaries, while `docs/LOCAL-WORKFLOW.md` contains operational commands.

Downloaded Workshop content, game binaries, saves, player databases, and secrets do not belong in this repository or its release archives.

Machine-specific Steam, game, Workshop, user-data, and hosted-profile paths are discovered into ignored `config/local.json`; they are never written into the portable manifest.

## Build a friend package

From PowerShell:

```powershell
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
```

The build writes a versioned ZIP to `dist/`. A friend extracts the complete ZIP, closes Project Zomboid, and double-clicks:

```text
Install.cmd
```

Before running the bootstrap, the friend joins the host once and lets Project Zomboid download the complete server Workshop list; that first connection may stop on the still-missing custom mods. The bootstrap then auto-discovers Steam and Project Zomboid, runs the pinned official ZombieBuddy installer, exact-hash checks the game and Java agent, installs every group-owned mod beneath `%USERPROFILE%\Zomboid`, applies the reviewed Better Vehicle Dynamics overlay from Steam's Workshop copy, and activates the exact ordered manifest in `mods/default.txt`. It backs up replaced files. Third-party Workshop items are never redistributed in the ZIP.

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
