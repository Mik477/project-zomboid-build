# Repository Instructions

This repository contains a private, portable Project Zomboid multiplayer build for a four-player group.

- Routing: before changing mod behavior, manifest order, Java patches, sync/deployment tooling, or release docs, read `docs/AGENT-GUIDE.md` to identify the owning source path and focused validator.

- Never commit Steam credentials, server passwords, IP addresses, player databases, saves, logs, crash dumps, or local absolute paths.
- Never commit Project Zomboid game binaries, decompiled game source, downloaded Workshop content, or third-party mod archives.
- Keep original custom mods in `src/mods/`, minimal game-file overlays in `src/game-overrides/`, and text patches in `patches/`.
- Treat Workshop item IDs and public collection URLs as metadata; let Steam distribute Workshop content.
- Preserve upstream mod attribution and licenses. Do not redistribute a mod unless its license explicitly permits it.
- Make direct game-file changes optional, version-gated, and reversible. Back up every replaced file.
- Record the exact Project Zomboid version and mod-list revision for every release.
- Optimize from measurements. Keep before/after results and reproduction steps in `docs/`.
- Keep hosted-server and future dedicated-server settings separate from client payloads.
- Treat `config/modpack.json` as the public, reviewable record of the enabled server modpack. Treat ignored `config/local.json` as the machine-specific path bridge.
- Discover local paths with `./scripts/Initialize-LocalEnvironment.ps1`; never hard-code a Steam library, Windows user profile, server-profile name, or another local absolute path in tracked content.
- Treat Steam's game directory and `steamapps/workshop/content/108600` as deployed/runtime trees, not source trees. Workshop content is read-only for durable work because Steam may replace it.
- Edit repo-owned mods in `src/mods/`. A local edit may be brought back only through `./scripts/Sync-ManagedFiles.ps1 -Direction FromLocal -Mod <repo-owned-directory>` and only after reviewing its status/diff.
- Sync game overrides only for files already represented below `src/game-overrides/`. Require the recorded Steam build ID to match, stop the game/server first, and keep the generated backup.
- Export only `WorkshopItems`, `Mods`, and `Map` from a local server profile with `./scripts/Export-LocalModpack.ps1`. Never copy a whole server profile into the repository.
- Sync operations must be targeted, additive, previewable with `-WhatIf`, and non-deleting. Review `git status`, `git diff`, and newly added files after every local-to-repo sync.
- Before calling a change ready, run managed-file status, `./scripts/Test-Project.ps1`, and `./scripts/Build-Package.ps1`. Record game version, Steam build ID, mod-list revision, and material test evidence.
- Run `./scripts/Test-Project.ps1` and `./scripts/Build-Package.ps1` after workflow changes.
- Do not commit, push, publish releases, or change repository visibility unless explicitly requested.
