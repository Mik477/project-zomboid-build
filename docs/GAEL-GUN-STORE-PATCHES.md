# Gael Gun Store Patches

## Scope and compatibility

The Gael work is split across `GaelGunStoreCoreFixes`, `GaelGunStoreLootDiversification`, `GaelGunStoreInventoryTetrisCompatibility`, and the cross-mod `ItemVisualCompatibilityFixes` module. Together they provide the behavior documented below for:

- Project Zomboid `42.20.3` / Steam build `24775755`
- GaelGunStore Workshop item [`3616176188`](https://steamcommunity.com/sharedfiles/filedetails/?id=3616176188)
- Gael Mod ID `GaelGunStore_B42`

`GaelGunStoreCoreFixes` and `GaelGunStoreLootDiversification` load immediately after Gael, in that order. The Inventory Tetris compatibility module loads after `CompactProximityInventory`; item-visual fixes load after all target mods.

## Local firearm selection

Gael is effectively the firearm system for this pack. Its installed script layer currently contains **364 ammo-using weapon definitions**. These are script definitions rather than a promise of 364 independently spawning models—Gael also defines variants and compatibility forms—but they show the scale of its ownership:

| Family/source file group | Ammo-using definitions |
| --- | ---: |
| Pistols | 47 |
| Revolvers | 32 |
| Shotguns (all action types) | 46 |
| SMGs | 45 |
| Rifles and carbines | 150 |
| LMGs | 23 |
| Launchers/explosives | 8 |
| Bows/crossbows | 13 |

The most frequently referenced ammunition families are 9mm (58 definitions), 5.56x45mm (49, including one case-variant definition), 12 gauge (47), .308 (44, including malformed/case-variant references), .45 ACP (25), 7.62x39mm (19), 7.62x54mmR (14), .357 Magnum (14), and .22 LR (12). `MWPWeaponsB42` is primarily a melee-weapon pack despite its name, while the enabled `Explosives` mod supplements thrown explosives rather than competing as a broad firearm pack.

This patch intentionally fixes the shared ammo foundation first. Later gun-selection pruning or spawn balancing can therefore be done against one working package/conversion system rather than editing hundreds of Gael definitions.

## Magazine naming and compatibility

Version `0.2.0` inventories **65 effective detachable feed devices**: 63 pre-existing vanilla/Gael magazines, drums, clips, pans, or belt boxes plus two restored definitions that Gael referenced but did not provide. Version `0.2.1` makes every valid Build 42 English key caliber-first using `<caliber> <device kind> (<capacity>)`; a proprietary weapon qualifier appears only after the capacity. Shared magazines therefore display `.45 ACP`, `9mm`, or `.308 Winchester` instead of inherited M1911, M9, or M1A labels. Internal item IDs remain unchanged for save and cross-mod compatibility, including misleading legacy IDs such as `303Drum50`, whose real capacity and visible name are 40 rounds.

The restored devices are:

- `Base.Bullets50Clip`: a 30-round .50 BMG MG 131 magazine matching the weapon's existing intended map and capacity.
- `Base.792x57Clip40`: the 40-round G43 extended magazine already present in Gael's compatibility map.

Both use narrow original script definitions and visual-part aliases that reference Gael's existing icon/model IDs; the patch redistributes no Workshop assets. Their loot entries are cloned from the matching base magazines before Gael applies its normal sandbox and ammo-probability multipliers.

Targeted compatibility corrections also:

- move stale `P38`, `Pistol_shotgun`, and `SVDk` map entries to `Walther_P38`, `pistol_shotgun`, and `SVDK`;
- remove dead `FR-F2`, `M98`, and duplicate `Ruger10_22LR` keys;
- preserve both the static and alternate magazine families for MAT-49 and PPSh-41;
- enable the M9A3's modeled 30-round magazine/50-round drum, the UMP9's complete modeled modern 9mm family, and the G36's modeled 60/100-round 5.56 devices;
- correct Grizzly50AE from 9mm to .50 AE, M39's malformed `.308Bulets` ammo type, and MG 131 clip metadata;
- stop future loot generation for `Base.30_06Clip` and `Base.30_06Clip40` while retaining the definitions so saved copies can still be unloaded. Enfield1917 and Springfield1903 remain intentional loose-round `Rifles_bolt_nomag` weapons.

Gael has many weapon-side `MaxAmmo` values that differ from the selected magazine. The patch does not blanket-rebalance them: Gael's existing swap code reads `MaxAmmo` from the inserted magazine and makes that device the runtime capacity source of truth. Only the three demonstrably malformed firearm definitions are changed.

Version `0.3.0` also adds a 30-round `.308 Winchester Magazine` and treats 10/20/30/40-round box magazines as one gameplay-oriented core family across suitable .308 rifles. Headhunter variants receive that family, and Trapper Carbine receives the standard/extended/50-round .45 family. High-capacity drums remain role-limited, while belt boxes, vintage magazines, P90/Bizon/JS-14 devices, and the MG 131 feed device remain separate.

### Automatic allowed-magazine insertion

Gael's allow-list and vanilla's reload selector use different state. `AWCWF_WeaponMagazineType` may allow several magazine families, but `HandWeapon:getBestMagazine()` and vanilla context menus only search the weapon instance's current `MagazineType`. Before version `0.5.0`, a valid drum therefore remained unavailable until the player manually selected that family through Gael's radial menu.

The client patch now recursively discovers all allowed magazines in main inventory and nested bags. It preserves the current family when one is available; otherwise reload-key handling selects the best allowed alternative by loaded rounds, capacity, then condition. Right-clicking either a gun or compatible magazine adds explicit insertion options for every allowed family present. Different-family insertion delegates to Gael's existing `ChangeMagazine(...)` flow so ejection, capacity, visual part, preferred type, timed actions, transfer, and multiplayer commands remain synchronized.

Examples now available without radial preselection:

- M16 and CZ805/BREN: standard, 60-round, and 100-round 5.56 devices;
- MP5, MP5K, and MP5SD: standard/30-round magazines and 50/75/100-round 9mm drums.

The final allow-list still controls selection, so vintage, proprietary, and belt-fed devices do not become universally interchangeable.

### Lee-Enfield and `.308` naming

`Base.Enfield` incorrectly used `base:bullets_308` despite being represented and distributed as a `.303 British` Lee-Enfield. Version `0.5.0` restores `ggs:303_bullets`, `Base.303Box`, its existing ten-round internal capacity, and no detachable magazine. It is also removed from `.308` replacement pools so `.308` cases cannot generate a rifle with incompatible companion ammunition.

All `.308` names now state `.308 Winchester (7.62x51mm)`, including loose standard/AP/tracer rounds, 20-round boxes, cartons, the 150-round feed box, and magazines/drums. Internal `base:bullets_308` IDs remain unchanged. `.303 British` rounds, boxes, cartons, and magazines retain distinct names.

## Firearm spawn diversification

Vanilla firearm entries were individually much heavier than Gael alternatives. For example, `Base.Pistol` appears in 28 procedural entries with a diagnostic raw-weight sum of 198.42, while `Base.Shotgun` appears in 33 with 275.16. Police storage assigned either one roughly 30.8 effective weight versus about 0.8 for one typical Gael counterpart. Gael then injected the vanilla IDs again.

The patch now transforms every configured vanilla occurrence without changing its total weight:

```text
retained vanilla weight = original weight × retention
replacement weight each = original weight × (1 − retention) / available replacements
```

Retention policy in version `0.6.0`:

- 2.5%: M9 (`Base.Pistol`) and JS-2000 (`Base.Shotgun`);
- 10%: broad pistol, revolver, rifle, and sawed-off replacement pools;
- 20%: newer JS-14, JS-3T, and MSR7T weapons;
- 25%: double barrels, L92, Trapper Carbine, and MSR700/Varmint Rifle pools with only one or two close alternatives;
- 100%: L94 Rifle because Gael has no same-ammo `.30-30` replacement; cap guns are also untouched.

The transformer rebuilds each weighted array with replacements immediately after the source gun. This is essential for small firearm cases, whose upstream definition explicitly requires guns before magazines/ammunition because later items may not fit. Previously the retained vanilla gun stayed first while Gael replacements were appended behind accessories, causing cases to remain effectively vanilla despite correct total weights.

Replacement pools preserve the vanilla weapon's original caliber rather than Gael's malformed effective overrides. This notably keeps RevolverCase2 on `.357` replacements and RifleCase1 on 5.56 via `Scout_elite`.

The recursive transformer covers:

- `ProceduralDistributions.list`;
- legacy `Distributions` / `SuburbsDistributions` room tables;
- `VehicleDistributions`, including trunk and glovebox tables;
- Gael's generated `item/loot` records before injection;
- all `BagsAndContainers` weighted arrays, including Pistol/Revolver/Rifle/Shotgun cases, police bags, survivor/bandit bags, and shared arrays referenced by bags nested inside other containers.

It transforms only arrays that already contain a configured firearm. Ordinary bags that never spawned guns remain unchanged. Existing items, player-owned bags, explored containers, and saved vehicle inventories are not rewritten; only newly generated loot uses the diversified pools. RifleCase1 gains the same two generic 5.56 magazine weights used by RifleCase4 so its magazine-fed Scout Elite replacement has a matching magazine.

### Generated firearm condition and magazine fill

Version `0.2.0` applies context-aware state only when new loot is generated. The server/SP `OnFillContainer` handler runs after Gael's context-free condition handler, while an exact Build 42.20.3 ZombieBuddy patch runs after `IsoZombie.DoZombieInventory(boolean)` finishes. Both paths recurse into newly generated nested bags and write unique per-item markers; they never scan an explored world, a player inventory, or persisted items.

| Source context | Firearm condition | Detachable magazine fill |
| --- | ---: | ---: |
| Gun/police/military/security/locker storage | 70-100% | 50-100% |
| Other generated world containers | 45-90% | 25-90% |
| Zombie death inventory | 20-60% | 10-60% |

All ranges vary per item and clamp to the item's own capacity/condition maximum. A magazine must be a non-weapon item with positive `MaxAmmo` and a non-empty `GunType` list; this avoids Build 42's unusable `ItemTag.MAGAZINE` path and keeps generated police-locker magazines non-empty. The Java path is multiplayer-client inert and ignores reanimated players and fake-dead zombies.

## Weapon visual compatibility

Version `0.4.0` reuses close installed icons for six spawnable Gael weapons whose configured icon names did not exist in individual textures or active texture packs:

- Benelli M3 → Benelli M4 icon;
- G36 → G36C icon;
- M9A3 → M9 icon;
- PKM → PKP icon;
- Walther P38 → existing P38 icon;
- Rhino 60DS → Rhino 20DS icon.

Their dedicated 3D meshes/textures remain unchanged. The patch references installed icon names through `ScriptManager` and copies no Workshop assets. Minigun has no reasonable close icon and is removed from future normal Gael loot instead; existing saved Miniguns remain valid because the upstream item definition is not deleted.

Cross-mod corrections also split Authentic Z Smoke Bomb's malformed combined `Icon`/`Weight` parameter, point Bandits Bucket at vanilla `Bucket`, and append valid installed x8-scope/sling/Harris-bipod/NST-suppressor/scrap-suppressor visuals to Headhunter Rifle.

Missing magazine attachment visuals are restored as local script aliases that reuse existing Gael mesh/texture IDs:

- M14/.308 20-round magazine → existing `.308` box-mag silhouette (30 affected rifles);
- `.303` 20-round magazine and 40-round drum → existing `.308` box/drum silhouettes (five rifles);
- vintage 70-round 9mm magazine → existing vintage 100-round stick silhouette (four SMGs);
- MG 131 feed device → existing ammunition-box silhouette;
- G43 40-round magazine → existing 7.92x57mm magazine silhouette.

Version `1.0.1` also audits all 66 effective feed devices and replaces unresolved inventory icons without copying assets. `.303` box/drum, Bizon, saved obsolete `.30-06`, and MG 131 devices reuse the closest installed Gael box, drum, or feed-box art. The vintage 70/100-round 9mm devices retain their inventory art but point their ground representation at existing valid model names.

Intentional invisible helpers (`TempNilItem`, `AttachmentPlaceholder`, `Rocket_explosion`, and `HE_explosion`) remain untouched. MWP `IconsForTexture`, vanilla UI-pack icons, optional world models, and Explosives GLB meshes are valid and were excluded from fixes.

## Diagnosed failures

### Package actions

Gael defines recipes such as `GGS_OpenBoxofBullets9mm` and `GGS_OpenAmmoCarton12`, but its package items point to `OpenBoxofBullets9mm` and `OpenAmmoCarton12`. `ISInventoryPane` checks the latter names, receives no recipe, and silently stops. This explains the double-click action that appears to do nothing.

Gael's English `ItemName.json` also uses legacy keys such as `ItemName_Base.Bullets9mmBox`. Build 42 JSON translation files expect `Base.Bullets9mmBox`, so many packages fall back to internal or inconsistent display names. Cartons generally have no useful script-level `DisplayName` fallback at all.

### Multiplayer handcraft start

The initial client log and the post-patch `2026-08-21_20-49_DebugLog.txt` repeatedly record:

```text
ActionManager.sendAction > IllegalStateException: Unable to resolve container location
... ISInventoryPaneContextMenu.OnNewCraft
... Neat_Crafting.startHandcraft
```

The corrected package action transfers the selected box successfully—which explains why it visibly moves to another inventory slot—but the following networked handcraft action still fails before consumption/output. The actual unresolvable object is `CompactProximityInventory`'s display-only `Nearby (Compact)` marker. Build 42 serializes every visible container returned by `ISInventoryPaneContextMenu.getContainers`; the marker intentionally has no world/player parent, so `ContainerID.set` rejects it. Neat Crafting obtains its container list through the same function.

`CompactProximityInventory` now preserves the marker and the complete stacked looting view, but filters only that marker from crafting lists. Every real nearby container and Inventory Tetris key-ring container remains available as a recipe source.

An initial Gael workaround intercepted `OnNewCraft`, queued only the package transfer, and attempted to re-enter crafting from the transfer callback. After the marker fix this wrapper became both unnecessary and responsible for packages stopping in Pockets until a second click. Version `0.1.1` retires it. Build 42's native `OnNewCraft` now owns the full one-click sequence: queue transfer, refresh inputs, then queue the server-authoritative unpack action. Neither compatibility mod spawns or deletes ammunition in client Lua.

Nearby errors involving `Trash and Corpses`, `SpecialLootSpawns.OnCreateRecipeMagazine`, `ReceiveModData`, and fluid/object synchronization are unrelated and are not hidden or changed by this patch.

## Conversion coverage

The mod retains Gael's current normal/AP/tracer per-caliber recipes, fixes every package link, and supplies missing reversible paths:

- 20 existing normal-ammo cartons ↔ 12 matching boxes, including `.30-30` and shotgun shells.
- Normal, AP, and tracer boxes ↔ their exact current loose-round quantities.
- `.30-30`, buckshot, 40 mm HE/incendiary grenades, and RPG-7 rockets ↔ boxes.
- Wooden, metal, and carbon arrows/bolts ↔ eight-projectile packs.

The translations state exact box quantities. In particular, current Gael recipes yield **60**, not 50, rounds from `.22 LR` and 5.56x45mm boxes. Shotgun variant boxes contain 24 shells while the buckshot box contains 25.

## Storage behavior

- All loose Gael ballistic and launcher ammunition receives the vanilla ammo tag.
- Buckshot, slugs, and Dragon's Breath receive the shotgun-shell tag and use shell bandoliers; other rounds use bullet bandoliers.
- The chest/shoulder holster accepts Gael's standard/non-drum handgun magazines while preserving vanilla's two-magazine limit.
- Drums and long SMG/LMG magazines remain excluded.
- Server accept-function wrappers preserve vanilla behavior and also recognize saved Gael items created before the script tags were corrected.

## Verification

Run before packaging:

```powershell
./scripts/Test-GaelGunStorePatches.ps1
./scripts/Test-Project.ps1
./scripts/Build-Package.ps1
```

For runtime testing, deploy both managed compatibility mods:

```powershell
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod GaelGunStoreCoreFixes
./scripts/Install-CompatibilityPatches.ps1 -WhatIf
./scripts/Install-CompatibilityPatches.ps1
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod GaelGunStoreInventoryTetrisCompatibility
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod ItemVisualCompatibilityFixes
./scripts/Sync-ManagedFiles.ps1 -Direction ToLocal -Mod CompactProximityInventory
```

Use a disposable hosted world and test:

1. Keep `Nearby (Compact)` selected and invoke unpack exactly once from main inventory, a carried bag, and a real nearby container. When movement is required, verify transfer into Pockets is immediately followed by unpacking without another click.
2. Repeat through Neat Crafting; confirm the compact stacked looting view stays selected and all real nearby ingredients remain usable.
3. Test representative 20/25/30/50/60-round boxes plus AP/tracer, `.30-30`, 40 mm, rockets, arrows, and bolts in both directions.
4. Round-trip a carton with exactly 12 boxes and no count loss.
5. Verify bullet versus shell bandoliers and two compatible pistol magazines in the chest/shoulder holster; drums must remain rejected.
6. Load, fire, eject, and swap magazines on MG 131, G43, Grizzly50AE, M39, Walther P38, pistol-grip shotgun, SVDK, MAT-49, PPSh-41, M9A3, UMP9, and G36; confirm every mapped device uses its intended capacity and visual part.
7. Generate untouched gun/ammo containers under representative Gael loot settings; confirm restored devices can appear and obsolete `.30-06` magazines no longer do. Existing saved `.30-06` magazines should remain unloadable.
8. Inspect newly generated police/army/gun-store loot, direct vehicle trunks and gloveboxes, Pistol/Revolver/Rifle/Shotgun cases, police bags, survivor/bandit bags, and a gun-bearing bag nested in another container. Confirm Gael replacements appear, M9/JS-2000 remain occasional rather than dominant, companion ammo fits, and ordinary non-gun bags remain unchanged.
9. In a disposable fresh area, compare secure gun/police lockers, ordinary static storage, and newly killed zombies. Confirm firearm condition follows the documented bands, magazines vary without being empty, nested new bags are initialized, and moving/reopening items does not reroll them.
10. Put 5.56 drums and 9mm drums in main inventory and nested bags, then test reload-key, gun-context, and magazine-context insertion on M16, CZ805/BREN, MP5, MP5K, and MP5SD without first using the radial selector. Confirm Lee-Enfield loads only `.303 British`, keeps ten internal rounds, and never offers `.308 Winchester (7.62x51mm)` ammunition.
11. Inspect Benelli M3, G36, M9A3, PKM, Walther P38, and Rhino 60DS inventory art; `.303` box/drum, Bizon, saved `.30-06`, MG 131, and vintage 9mm feed devices; Authentic Smoke Bomb and Bandits Bucket; restored magazine attachments; and Headhunter scope/sling/bipod/suppressor combinations. Generate fresh Gael loot and confirm Minigun no longer appears while existing saved copies remain loadable.
12. Check client/server logs for firearm-diversification, loot-state, visual-patch, and magazine-selection errors, then confirm no missing-item/map warnings, duplicate reload actions, red-question-mark icons, invisible parts, or new `ActionManager.sendAction`, `ContainerID.set`, or `Unable to resolve container location` errors.

## Workshop patch assessment

Workshop item [`3669616334`](https://steamcommunity.com/sharedfiles/filedetails/?id=3669616334) identified three useful goals: ammo conversion, bandolier storage, and chest-holster magazine support. It is currently marked removed/incompatible and publishes no source license. Its installed payload overwrites complete older Gael ammo files, omits current AP/tracer and legacy-mag content, maps some quantities incorrectly (including a 60-round `.22 LR` box through a 50-round output), and has incomplete mapper entries.

For those reasons this project implements the behavior independently through narrow script mutations, new recipes, and translations. No source file, model, texture, logo, or poster from that Workshop item is redistributed.

## Publishing checklist

The source under `src/mods/GaelGunStoreCoreFixes` is MIT licensed and contains original artwork. The split policy and compatibility mods are distributed with this private package rather than prepared as one combined Workshop item.

Any future Workshop publication must preserve these module boundaries, declare the appropriate upstream requirements, credit Pen-Pen Pirulin, and be tested as clean subscriptions before the manifest gains Workshop item IDs. Publishing remains an explicit external action and is not performed by this workflow.
