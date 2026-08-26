# Java Compatibility Patches

Date: 2026-08-25
Target: Project Zomboid 42.20.3, Steam build 24775755, ZombieBuddy 2.3.2

Four repo-owned mods currently generate common Java JARs: two focused replacements for the former `ModpackCompatibilityFixes` catch-all, one Kahlua concurrency guard, and the zombie-inventory half of the firearm-loot policy. They do not replace or redistribute Workshop files. JARs are generated during installation or package staging and must not be committed under `src`.

## KahluaObjectPoolConcurrencyFix

Build 42.20.3 stores `ReturnValues` and each `MethodArguments` size class in process-wide unsynchronized `ArrayList` pools. Concurrent Lua-to-Java calls can observe a non-empty pool and then remove a null/already-claimed slot, matching the timed-action failure at `ReturnValues.get`'s `callFrame` assignment.

The four strict ZombieBuddy advices replace the legacy static `get`/`put` bodies with isolated patch-owned pools guarded by one reentrant lock. Every advice declares the exact target arguments; without those declarations ZombieBuddy inferred zero-argument targets and transformed the classes without advising the real overloads. The replacement pools accept returns only for objects they issued, so objects held by multiple callers before retransformation can never enter or mutate the replacement pool. Weak active-owner records allow abandoned exceptional invocations to be collected.

`Test-KahluaObjectPoolRace.ps1` drives millions of operations through the exact game classes: unguarded access must reproduce null, duplicate, or exception failures, direct locking must establish the concurrency baseline, and the generated JAR loaded through the actual ZombieBuddy agent must report zero. Separate agent processes cover duplicates still in a legacy pool and the more dangerous in-flight case where a stale pre-activation owner returns an object after a patched caller has begun; both execute the full `LuaJavaInvoker` lifecycle and require zero invoker failures.

## TrashAndCorpsesSafetyFix

The reviewed `ScatteredTrashes.lua` can calculate condition zero for a dead zombie's worn clothing. `Clothing.setCondition(0)` then calls `Unwear`, which can attempt a network container removal after the zombie or container has lost its square.

The advice changes zero to one only when the item is worn, the owning container belongs to an `IsoZombie`, and that zombie is dead or fully detached. Positive condition, living-character clothing, unworn items, and non-zombie owners pass through unchanged.

## SecretZCommandRegistrationFix

The reviewed `SZDoors/SZCServer.lua:401` assigns `Commands["DespawnDoor"]` even though `Commands` is not a table in this runtime. The exception aborts the file before later `OnClientCommand` and `OnTick` registrations.

The advice skips only that invalid Kahlua `tableSet`: source `SZCServer.lua`, line 401, exact `DespawnDoor` key, non-table target, and Lua closure value. The remainder of the file can load normally.

## GaelGunStoreLootDiversification

The Lua half initializes newly filled world containers. The common-JAR half advises the exact private `IsoZombie.DoZombieInventory(boolean)` completion seam so newly assembled zombie death inventories receive the lower-condition firearm and magazine-fill policy before they are exposed. It is inert on multiplayer clients, skips reanimated/fake-dead zombies, recurses only through that newly generated inventory, and uses per-item markers rather than scanning persisted items.

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

The installer synchronizes each source mod, backs up an existing generated JAR, and builds one deterministic `media/java/common/<ModId>.jar` per guard. Every participant must receive the same package, approve all common-JAR fingerprints through ZombieBuddy, and fully restart.

After all replacement mods and both generated JARs are installed, run `Migrate-PatchModLayout.ps1` once to back up and remove the obsolete `ModpackCompatibilityFixes` directory. Apply the authoritative client and hosted-profile manifest with `-AllowRemovals` only after reviewing each `-WhatIf` result.

## Runtime acceptance

1. Confirm ZombieBuddy loads all enabled common-JAR mods on host and clients and logs the Kahlua pool guard once.
2. Repeat the prior key/key-ring/fanny-pack timed-action route and confirm no `ReturnValues.put`/`callFrame` failure occurs.
3. Kill enough zombies to exercise Trash and Corpses worn-item degradation and generated firearm loot state.
4. Let SecretZ initialize beyond line 401 and confirm its timer/client-command registrations run.
5. Confirm logs contain no Kahlua pool exception, SecretZ line-401 exception, or Trash and Corpses `Clothing.Unwear` null-square chain.

Each guard reports at most one concise application message. Raw logs, player identifiers, server values, credentials, saves, and databases remain local and must not be committed.

MWP's benign `Base` self-import messages remain unpatched. A parser advice could not identify MWP at runtime and was not justified for cosmetic log cleanup.
