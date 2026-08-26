# Architecture

The project separates content by ownership and installation target.

Use `docs/AGENT-GUIDE.md` to route a behavior or symptom to its owning module and validator. This document defines the broader source/runtime boundaries.

## Source layers

1. `config/modpack.json` is the reproducible inventory. Steam Workshop IDs are references, not bundled content.
2. `src/mods/` contains only mods authored for this project or content with explicit redistribution permission.
3. `src/game-overrides/` mirrors paths below the Project Zomboid installation directory. It is reserved for the smallest possible version-specific override.
4. `patches/` holds human-reviewable diffs when distributing a whole modified upstream file would be inappropriate.
5. `server/` holds sanitized templates. Passwords, addresses, saves, and player databases stay local.

## Local runtime boundary

Ignored `config/local.json` connects portable repository paths to the current machine's Steam library, game installation, Workshop cache, user-data directory, and selected hosted profile. `Initialize-LocalEnvironment.ps1` is the only normal way to create that bridge.

Sync is explicit and directional:

- `ToLocal` deploys group-owned source for runtime testing.
- `FromLocal` retrieves intentional edits only from already-managed custom-mod directories or already-declared game overrides.
- `Status` compares hashes without writing.

All sync modes are additive. They do not mirror-delete. Replaced files are backed up beneath the local Zomboid backup tree. Workshop content is outside this sync boundary and remains Steam-managed.

## Package layout

`Build-Package.ps1` produces an archive with this shape:

```text
Install.cmd
Install.ps1
README.txt
manifest.json
BetterVehicleDynamicsPayload.ps1
third-party/
  ZombieBuddyInstaller_v4.2.exe
  ZombieBuddy-LICENSE.txt
payload/
  user/mods/       # installed below %USERPROFILE%\Zomboid\mods
  game/            # optional, installed below an explicit game path
```

`Install.cmd` is the double-click entry point. It runs the PowerShell bootstrap, which auto-discovers Steam, delegates ZombieBuddy lifecycle changes to the pinned official installer, exact-hash installs the Workshop-owned Better Vehicle Dynamics overlay, copies repo-owned files individually, and writes the manifest's ordered client activation list. Existing destinations are copied to a timestamped backup directory before replacement. Other game overrides still require an explicit switch.

## Future dedicated-server support

Dedicated-server automation should be a separate package/profile because the server has different paths, permissions, startup flags, and secret-handling requirements. Shared manifest data can remain common.
