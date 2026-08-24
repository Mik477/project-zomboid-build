# Gael Gun Store Core Fixes

An original compatibility mod for **GaelGunStore** on Project Zomboid **42.20.3**.

## Features

- Correct names and round counts for Gael ammo cartons, boxes, special-ammo boxes, launcher packages, projectile packs, ammunition-component boxes, and all effective detachable feed devices.
- Caliber-first `<caliber> <device> (<capacity>)` magazine names instead of M1911/M9/M1A labels; proprietary magazines add their weapon qualifier only after the capacity.
- Restored MG 131 and G43 magazines plus corrected Grizzly .50 AE, M39, Walther P38, pistol-grip shotgun, SVDK, MAT-49, and PPSh-41 compatibility.
- Enables every magazine already modeled for the M9A3, UMP9, and G36, including their appropriate extended and drum options.
- Adds a 30-round .308 Winchester magazine and shares the 10/20/30/40-round core family across suitable .308 rifles while retaining separate drums, belts, and proprietary systems.
- Converts overrepresented vanilla firearm weight into adjacent, case-safe Gael alternatives without changing total gun abundance; M9 and JS-2000 retain only 2.5%.
- Covers procedural/legacy containers, direct vehicle loot, and every gun-bearing bag or case even when nested inside trunks or other containers.
- Reuses close existing inventory art for six guns with missing icons and restores missing .308/.303/vintage-9mm/MG131/G43 magazine visuals without redistributing Workshop assets.
- Repairs Authentic Z Smoke Bomb, Bandits Bucket, and Headhunter Rifle visual mappings; suppresses Minigun from new normal loot while preserving saved copies.
- Automatically offers any allowed magazine found in main inventory or nested bags on reload and both context menus, including M16/BREN 5.56 drums and MP5-family 9mm drums.
- Corrects Lee-Enfield to `.303 British` and labels `.308 Winchester` items with the `7.62x51mm` synonym used by unpacked rounds.
- Working double-click and clearly named right-click unpack actions.
- Reversible carton → 12 boxes → loose rounds conversion, including `.30-30`.
- Missing pack recipes for `.30-30`, shotgun shells, 40 mm grenades, rockets, arrows, and bolts.
- Gael rounds in the appropriate bullet/shell bandolier and compatible non-drum pistol magazines in the chest/shoulder holster.
- Vanilla sequential transfer → unpack behavior for packages in backpacks or nearby containers; the modpack's Compact Proximity Inventory filter keeps its display marker out of networked crafting without changing the compact loot view.

## Requirements and order

- Project Zomboid `42.20.3`
- GaelGunStore (`Workshop 3616176188`, Mod ID `GaelGunStore_B42`)
- Load this mod immediately after `GaelGunStore_B42` on every client and the server.

Do not enable the removed Workshop patch `3669616334` at the same time. This mod uses the distinct Mod ID `GaelGunStoreCoreFixes` and does not redistribute files from either Workshop item.

## Compatibility policy

The patch mutates only named Gael script items, adds original recipes/translations and missing feed-device definitions, repairs Gael's client magazine maps, adjusts its generated loot before injection, recursively diversifies vanilla weighted distribution arrays, and wraps vanilla container checks. It changes distribution definitions only—not live inventories—so existing items and explored containers remain untouched. Restored devices reference existing Gael icon/model IDs; no Workshop meshes or textures are redistributed. Missing upstream entries are logged and skipped rather than crashing startup. Re-test after every GaelGunStore or Project Zomboid update.

The obsolete `Base.30_06Clip` and `Base.30_06Clip40` definitions are retained so saved copies remain unloadable, but new copies are removed from generated loot. The two active .30-06 rifles deliberately use loose-round bolt-action reloads and are not converted to detachable magazines.

## License and attribution

The compatibility code and original artwork in this directory are MIT licensed; see `LICENSE.txt`. GaelGunStore and its assets remain the property of its author, Pen-Pen Pirulin. The feature list of DPK's removed `GaelGunStore-Patch` (`3669616334`) informed the compatibility goals, but no code or assets were copied from it.
