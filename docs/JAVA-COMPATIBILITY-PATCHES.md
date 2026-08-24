# Java Compatibility Patches

Date: 2026-08-24
Target: Project Zomboid 42.20.3, Steam build 24775755, ZombieBuddy 2.3.2

Two repo-owned common Java mods replace the behavior-changing guards from the former `ModpackCompatibilityFixes` catch-all. They do not replace or redistribute Workshop files. JARs are generated during installation or package staging and must not be committed under `src`.

## TrashAndCorpsesSafetyFix

The reviewed `ScatteredTrashes.lua` can calculate condition zero for a dead zombie's worn clothing. `Clothing.setCondition(0)` then calls `Unwear`, which can attempt a network container removal after the zombie or container has lost its square.

The advice changes zero to one only when the item is worn, the owning container belongs to an `IsoZombie`, and that zombie is dead or fully detached. Positive condition, living-character clothing, unworn items, and non-zombie owners pass through unchanged.

## SecretZCommandRegistrationFix

The reviewed `SZDoors/SZCServer.lua:401` assigns `Commands["DespawnDoor"]` even though `Commands` is not a table in this runtime. The exception aborts the file before later `OnClientCommand` and `OnTick` registrations.

The advice skips only that invalid Kahlua `tableSet`: source `SZCServer.lua`, line 401, exact `DespawnDoor` key, non-table target, and Lua closure value. The remainder of the file can load normally.

## Exact upstream gates

`Build-CompatibilityPatch.ps1` compiles one selected mod and validates only its relevant Workshop seam. Every build also validates the exact game and ZombieBuddy JARs.

| Source | SHA-256 |
|---|---|
| `projectzomboid.jar` | `BDA809FB49004A07DBFC560D059C0EE58D0643AB0F33B53351B13BD62F1D8227` |
| `ZombieBuddy.jar` | `6DD95CEDCE60F03BF8B8CEFD0D19EB156230E0D54BFFA07DE9DA5212A06C7BE6` |
| Trash and Corpses `ScatteredTrashes.lua` | `556A46A87DCC9CF704FB65F991C5CD44396CCCEC0016442DD66776578AE8B6DB` |
| SecretZ `SZCServer.lua` | `8CDC2C1DC0DFB191D1E4A46B0C4E76DEC4816198E27A3E560E3C053485FB4838` |

A mismatch requires a fresh upstream audit; do not weaken the gate.

## Build and install

```powershell
./scripts/Test-CompatibilityPatches.ps1
./scripts/Install-CompatibilityPatches.ps1 -WhatIf
./scripts/Install-CompatibilityPatches.ps1
```

The installer synchronizes each source mod, backs up an existing generated JAR, and builds one deterministic `media/java/common/<ModId>.jar` per guard. Every participant must receive the same package, approve both common-JAR fingerprints through ZombieBuddy, and fully restart.

After all replacement mods and both generated JARs are installed, run `Migrate-PatchModLayout.ps1` once to back up and remove the obsolete `ModpackCompatibilityFixes` directory. Apply the authoritative client and hosted-profile manifest with `-AllowRemovals` only after reviewing each `-WhatIf` result.

## Runtime acceptance

1. Confirm ZombieBuddy loads both enabled guard mods on host and clients.
2. Kill enough zombies to exercise Trash and Corpses worn-item degradation.
3. Let SecretZ initialize beyond line 401 and confirm its timer/client-command registrations run.
4. Confirm logs contain no SecretZ line-401 exception or Trash and Corpses `Clothing.Unwear` null-square chain.

Each guard reports at most one concise application message. Raw logs, player identifiers, server values, credentials, saves, and databases remain local and must not be committed.

MWP's benign `Base` self-import messages remain unpatched. A parser advice could not identify MWP at runtime and was not justified for cosmetic log cleanup.
