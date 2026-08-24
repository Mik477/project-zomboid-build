# Change Log

## 0.6.0 — 2026-08-24

- Fixed small firearm cases continuing to favor vanilla guns by inserting each Gael replacement immediately after its source entry instead of after magazines, ammunition, and accessories.
- Reduced M9/JS-2000 retention to 2.5%, broad vanilla weapon families to 10%, newer B42 guns to 20%, and one/two-equivalent families to 25% while preserving exact total firearm weight.
- Kept unique .30-30/cap guns unchanged and preserved unavailable-replacement/idempotence safeguards.

## 0.5.0 — 2026-08-22

- Added automatic compatible-magazine discovery for reload actions and both inventory context-menu directions, including magazines stored in nested bags.
- M16/BREN-family rifles can now select their configured 60/100-round 5.56 devices, and MP5/MP5K/MP5SD can select configured 50/75/100-round 9mm drums without manual radial preselection.
- Reused Gael's synchronized `ChangeMagazine` timed-action flow for ejection, capacity, visual-part, preferred-type, and multiplayer state changes.
- Corrected Lee-Enfield from .308 Winchester to `.303 British`, retained its ten-round internal magazine, and removed it from `.308` firearm replacement pools.
- Renamed standard/AP/tracer `.308` rounds, boxes, cartons, feed boxes, magazines, and drums as `.308 Winchester (7.62x51mm)` so packed and unpacked items use the same recognizable caliber terminology.
- Added explicit `.303 British` loose-round names and regressions preventing `.303`/`7.62x51mm` ambiguity.

## 0.4.0 — 2026-08-22

- Reused existing close-match Gael icons for Benelli M3, G36, M9A3, PKM, Walther P38, and Rhino 60DS, eliminating red-question-mark inventory art without copying assets.
- Removed Minigun from all future normal Gael loot while retaining the item definition for existing saves and debug/admin recovery.
- Corrected Authentic Z Smoke Bomb's malformed combined Icon/Weight line and Bandits Bucket's nonexistent `BucketEmpty` static model.
- Restored missing visual-part items/models for M14/.308, .303 box/drum, vintage 70-round 9mm, MG 131, and G43 magazines by referencing existing Gael meshes and textures.
- Added valid Headhunter Rifle mappings for the installed x8 scope, sling, Harris bipod, rifle suppressor, and scrap suppressor models.
- Added installed-source checks for icon aliases, model aliases, magazine visual mappings, Headhunter replacement assets, and Minigun suppression.

## 0.3.0 — 2026-08-22

- Rebalanced 19 overrepresented vanilla firearm spawn IDs into curated same-role/original-caliber Gael pools while preserving total distribution weight and retaining a minority of each vanilla gun.
- Reduced M9 and JS-2000 retention to 10%; retained broader or unique vanilla weapons at 25–50%, and left the unmatched .30-30 L94 untouched.
- Applied diversification recursively to procedural loot, legacy room tables, direct vehicle/trunk/glovebox loot, Gael's injected records, and all gun-bearing bags/cases—including bags spawned inside other containers.
- Preserved gun-case ammo families and added 5.56 magazine support to RifleCase1 for its Scout Elite replacement.
- Added a 30-round .308 Winchester magazine, restored the missing 20-round .308 visual part, and made the 10/20/30/40-round core .308 family interchangeable across suitable rifles.
- Expanded Headhunter rifle and Trapper Carbine magazine families while keeping vintage, proprietary, and belt-fed systems separate.
- Added deterministic and in-game regressions for weight conservation, namespace handling, idempotence, unavailable-item fallback, nested bag coverage, vehicle coverage, and magazine-family expansion.

## 0.2.2 — 2026-08-22

- Enabled M9A3 use of the existing 30-round 9mm magazine and 50-round 9mm drum already declared by its weapon model.
- Enabled UMP9 use of the complete modern 9mm family: 15/30-round magazines and 50/75/100-round drums.
- Enabled G36 use of the existing 60- and 100-round 5.56x45mm devices already declared by its weapon model.
- Added a general installed-source regression that rejects any magazine visual not represented in the effective functional allow-list.

## 0.2.1 — 2026-08-22

- Made every feed-device name caliber-first so shared magazines no longer inherit M1911, M9, M1A, or other weapon-centric labels.
- Moved the PP-19 Bizon, MG 131, JS-14, and P90 qualifiers behind caliber, device type, and capacity because those magazines remain proprietary despite sharing an ammunition family.
- Added static and in-game regressions for the canonical `.45 ACP`, `9mm`, and `.308 Winchester` shared-magazine names.

## 0.2.0 — 2026-08-22

- Added valid Build 42 English names and exact capacities for all 65 effective magazines, drums, clips, pans, and ammunition feed boxes.
- Restored the missing 30-round MG 131 magazine and 40-round G43 magazine with visual-part aliases that reuse GaelGunStore assets.
- Corrected the Grizzly .50 AE caliber fields, the M39 `.308Bulets` typo, and MG 131 clip metadata.
- Repaired stale and case-mismatched magazine-map keys for the Walther P38, pistol-grip shotgun, and SVDK; preserved the union of MAT-49 and PPSh-41 magazine choices.
- Cloned Gael's scaled loot entries for the restored devices and stopped future spawning of two obsolete, unusable .30-06 magazines without deleting saved copies.
- Added static installed-source validation and in-game definition/map regressions for the complete compatibility layer.

## 0.1.1 — 2026-08-21

- Retired the custom transfer-completion callback after the compact crafting-marker fix made vanilla's transfer-then-craft queue safe again.
- Backpack and nearby-container package actions now move their inputs and continue unpacking automatically from the same click.
- Kept the old client file as a compatibility no-op so additive deployments overwrite the previously installed hook.

## 0.1.0 — 2026-08-21

- Corrected package names and double-click recipe links for current GaelGunStore ammo.
- Completed carton, box, launcher-ammo, shotgun, arrow, and bolt pack/unpack paths.
- Added bandolier and chest-holster compatibility without replacing upstream item files.
- Added a transfer-first workaround for Build 42 multiplayer unpacking from nested containers.
