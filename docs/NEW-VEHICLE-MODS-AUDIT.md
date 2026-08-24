# New Vehicle Mods and Multiplayer Animation Patch Audit

Audit date: 2026-08-20
Game target: Project Zomboid 42.20.3, Steam build 24775755
Baseline examined: revision `sha256:a2f956...` of [`config/modpack.json`](../config/modpack.json)
Applied state: revision `sha256:43fdbb301194d431a1bb8d872c5c1a60af50ac5b00cbc71f97e13b26e4ed9d06`

## Outcome

The reviewed result has now been applied to both the tracked manifest and selected hosted-server profile. They match at **140 Workshop items, 161 Mod IDs, and 6 maps**. The net change from the audited 138/162/10 baseline is deliberately small because the additions were paired with the requested removal of the complete PZK-branded active family, the Project RV family, and `ETO_B` while retaining `ETO_P`.

Nine reviewed additions are active: eight ordinary KI5 base vehicles plus the S10 Rust texture replacement. `VASinked`, M911, and all four optional E-150 modules remain downloaded but inactive. The later eight Workshop downloads described below are also inactive and were not admitted as part of this vehicle pass.

| State | Workshop items | Mod IDs | Maps | Revision |
|---|---:|---:|---:|---|
| Audited baseline | 138 | 162 | 10 | `sha256:a2f956...` |
| Applied state | 140 | 161 | 6 | `sha256:43fdbb301194d431a1bb8d872c5c1a60af50ac5b00cbc71f97e13b26e4ed9d06` |

This research pass did not modify Workshop or game files. The reviewed manifest/profile changes were applied separately through the repository workflow.

## Exact local delta

These eleven items formed the initial vehicle-related download cohort. Nine were admitted and two were held. In the table below, Stagea, Taurus, Type 2, Buick, Range Rover, BMW, the E-150 base, S10, and S10 Rust are now active. `VASinked` and M911 remain inactive. For E-150, only `86fordE150` is active; `86fordE150dnd`, `86fordE150mm`, `86fordE150pd`, and `86fordE150expanded` remain inactive.

| Workshop item | Mod ID(s) | Effective B42 payload on 42.20.3 | Hard dependency | Initial verdict |
|---|---|---|---|---|
| [`3685499657` — Vehicle Animations Sinked](https://steamcommunity.com/sharedfiles/filedetails/?id=3685499657) | `VASinked` | `42` | None declared | Do not activate on 42.20.3 |
| [`2618213077` — '82 Oshkosh M911](https://steamcommunity.com/sharedfiles/filedetails/?id=2618213077) | `82oshkoshM911` | `42.20` | `damnlib` | Hold while `rSemiTruck` is enabled |
| [`3315443103` — '98 Nissan Stagea](https://steamcommunity.com/sharedfiles/filedetails/?id=3315443103) | `98stagea` | `42.13` | `damnlib` | Admit with BVD balance caveat |
| [`3088951320` — '93 Ford Taurus](https://steamcommunity.com/sharedfiles/filedetails/?id=3088951320) | `93fordTaurus` | `42.13` | `damnlib` | Admit |
| [`3041122351` — '63 Volkswagen Type 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3041122351) | `63Type2Van` | `42.13` | `damnlib` | Admit; Arcadia-supported |
| [`3418252689` — '85 Buick LeSabre](https://steamcommunity.com/sharedfiles/filedetails/?id=3418252689) | `85buickLeSabre` | `42.13` | `damnlib` | Admit |
| [`2409333430` — '91 Range Rover Classic](https://steamcommunity.com/sharedfiles/filedetails/?id=2409333430) | `91range` | `42.13` | `damnlib` | Admit; Arcadia-supported |
| [`3110913021` — '90 BMW E30](https://steamcommunity.com/sharedfiles/filedetails/?id=3110913021) | `90bmwE30` | `42.13` | `damnlib` | Admit |
| [`2870394916` — '86 Ford Econoline E-150](https://steamcommunity.com/sharedfiles/filedetails/?id=2870394916) | `86fordE150`; optional `86fordE150dnd`, `86fordE150mm`, `86fordE150pd`, `86fordE150expanded` | Base: `42.13`; optional submods: `42.0` | Base requires `damnlib`; submods require `86fordE150` | Admit base first; stage options |
| [`2886832936` — '88 Chevrolet S10](https://steamcommunity.com/sharedfiles/filedetails/?id=2886832936) | `88chevyS10` | `42.13` | `damnlib` | Admit |
| [`3658499522` — S10 Rust Edition](https://steamcommunity.com/sharedfiles/filedetails/?id=3658499522) | `88chevyS10Rusty` | `common` + `42.13` | `damnlib`, `88chevyS10` | Optional; load after base S10 |

The locally installed [`that DAMN Library`](https://steamcommunity.com/workshop/filedetails/?id=3171167894) is already enabled as Workshop item `3171167894`, Mod ID `damnlib`. The eight admitted KI5 bases and inactive M911 declare it in their effective `mod.info`; their author pages identify the current B42.13+ editions as multiplayer-supported.

### Later downloads: inactive and out of scope

Eight more items arrived after the vehicle cohort was already under review. They are not in the applied manifest or live profile and were not considered for admission in this pass:

| Workshop item | Identified content | Applied status |
|---|---|---|
| [`3374408921` — Efficiency Skill Mod 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3374408921) | Skill/timed-action overhaul; `efficiencySkillMod2` and legacy `efficiencySkillModLegacy` | **Removed after later review; unsafe timed-action wrapper** |
| [`3461415167` — Bicycle!](https://steamcommunity.com/sharedfiles/filedetails/?id=3461415167) | Bicycle vehicle/gameplay mod; `BicycleMod` | **Inactive; separate review required** |
| [`2447729538` — Fluffy Hair](https://steamcommunity.com/sharedfiles/filedetails/?id=2447729538) | Cosmetic hair/hat compatibility mod; `FH` | **Inactive; separate review required** |
| [`2847184718` — Proximity Inventory](https://steamcommunity.com/sharedfiles/filedetails/?id=2847184718) | Inventory UI/nearby-container aggregation; `ProximityInventory` | **Inactive; separate review required** |
| [`3490188370` — Project Cook](https://steamcommunity.com/sharedfiles/filedetails/?id=3490188370) | Cooking UI/content; `Project_Cook` plus an optional icon pack; requires `NeatUI_Framework` | **Inactive; separate review required** |
| [`3502080466` — Neat Crafting](https://steamcommunity.com/sharedfiles/filedetails/?id=3502080466) | Crafting UI replacement; `Neat_Crafting`; requires `NeatUI_Framework` | **Inactive; separate review required** |
| [`3536052310` — Neat Building](https://steamcommunity.com/sharedfiles/filedetails/?id=3536052310) | Building UI with several mutually exclusive variants; requires `NeatUI_Framework` for the main/UI-only choices | **Inactive; separate review required** |
| [`3508537032` — NeatUI Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3508537032) | Shared UI dependency; `NeatUI_Framework` | **Inactive; separate review required** |

## Findings by risk

### Critical: the downloaded VVA sync patch should not be admitted

The already-enabled [Vanilla Vehicles Animated](https://steamcommunity.com/sharedfiles/filedetails/?id=3281755175) page still links Workshop item `3685499657` for Build 42 multiplayer state synchronization. That link is now stale operational guidance:

- The patch is titled for B42.15, while this pack targets B42.20.3.
- The patch author now says it likely does not work in 42.20 and has no plan to maintain it.
- The VVA author now acknowledges in the current comments that the linked patch is unmaintained and does not know of a replacement; native synchronization may be added to VVA later.
- The patch author explicitly says KI5 vehicles already perform their own synchronization. `VASinked` would be for VVA/other animated vehicles, not the newly downloaded KI5 cars.

The local patch code confirms two additional risks:

1. `VAS_CCommands.lua` handles the remote close-door branch by playing `Close` but deliberately leaves `part:getDoor():setOpen(true)` at animation start. The stock 42.20 `ISCloseVehicleDoor.complete()` later sets the state to false and transmits the part-door update. This is therefore not conclusively a permanent-state bug by itself; it is a two-message convergence design that depends on the later native update arriving and winning. A missed or reordered completion update can leave a remote client visually closed but logically open.
2. `VAS_AnimationInterception.lua` wraps the same `ISOpenVehicleDoor.start` and `ISCloseVehicleDoor.start` methods already wrapped by `damnlib`'s `VanillaDoorAnimationSync.lua`. When both apply to a KI5-managed vehicle, the chained wrappers emit two different synchronization command paths for the same door action.

No load-order placement updates the B42.15-era protocol for 42.20 or eliminates the duplicate KI5 synchronization path. The code uses unique file paths, so the risk is semantic rather than a simple file overwrite.

Recommendation: leave Workshop item `3685499657` downloaded but exclude both its Workshop ID and `VASinked` from the server manifest. Re-evaluate when VVA ships internal B42.20 synchronization or another maintained patch explicitly supports the target game version.

### High: M911 and the current W900 semi ecosystem conflict

The [M911 author page](https://steamcommunity.com/sharedfiles/filedetails/?id=2618213077) states: “M911 is not compatible with other semi mods, they use different connection method.” The tracked pack currently enables [W900 Semi-Truck](https://steamcommunity.com/sharedfiles/filedetails/?id=3409472393), Workshop item `3409472393`, Mod ID `rSemiTruck`.

The effective source supports that warning:

- M911 registers its tractors through `DAMN.SemiAttachmentHelper`.
- `rSemiTruck` uses its own `trailertruck` attachment handling, explicit allow-lists, client hooks, server commands, and trailer-physics state.
- Their media paths and script IDs do not directly overwrite one another, so both may initialize. That does not make their trailers interoperable or the combination supported.

This is a design-level incompatibility, not an ordering problem. At minimum, players can encounter visually similar tractors and trailers that cannot be cross-attached. More importantly, the M911 author does not support the combination.

Recommendation: keep `rSemiTruck` and omit M911 for the first cleaned modpack. If M911 is preferred, test it as a replacement semi ecosystem rather than adding it to the existing one.

The M911 fuel-tanker feature also needs `tsarslib`. Its Workshop page points to the old B41 item, but this pack already has the correct B42 item `3402491515` with the same Mod ID. Do not subscribe to the legacy B41 library just to satisfy that feature.

### Medium: Better Vehicle Dynamics has one currently dormant coverage gap

The installed B42.20 Better Vehicle Dynamics payload includes a first-party `BVD_Pack_KI5.lua` reference pack. Comparing every newly downloaded vehicle script to that registry gives:

- Curated BVD reference entries exist for the Taurus, Type 2, Buick, Range Rover, BMW, S10, all twelve base E-150 variants, all 53 E-150 Expanded variants, the two usable M911 tractors, and all five M911 trailers.
- No curated entries exist for `Base.98stagea260RS` or `Base.98stagea260RSlhd`.
- The burnt M911 wreck also lacks an entry, which is much less important because it is not a normal drivable variant.

BVD still classifies unknown year-prefixed vehicles into its default `Car` bucket, so the Stagea is not ignored completely. It does not receive the authoritative real-world HP/mass rebasing that the other KI5 additions receive. The current server sandbox sets `BetterVehicleDynamics.RealismHPWeight = false`, so that coverage difference does not presently rewrite the Stagea's HP or mass. It becomes material if the realism option is enabled later. Since the [Stagea author describes it](https://steamcommunity.com/sharedfiles/filedetails/?id=3315443103) as a fast performance vehicle and it is outside the game's 1993 setting, it remains the addition most worth comparing against the pack's other sports cars.

There is also an M911-specific reason to test before ever enabling BVD's realism option: the bundled KI5 reference pack assigns `17,500 kg` not only to both M911 tractors but also to each of its five trailers. That may be intentional gross-system balancing, but it is far heavier than ordinary trailer entries and should be validated under towing physics rather than accepted unseen.

Recommendation: admit the Stagea only with an explicit handling/acceleration comparison against existing sports cars. If it is materially outside the chosen BVD profile, add a repo-owned registration through the author's [BVD Public Lua API](https://branched-almanac-460.notion.site/Better-Vehicle-Dynamics-Public-Lua-API-36542ef13d238106a7afda59a82181f6) later rather than editing Workshop content.

### Medium: E-150 optional modules multiply scope

The E-150 Workshop item contains one base Mod ID and four optional spawn/content modules:

```text
damnlib
86fordE150
86fordE150dnd
86fordE150mm
86fordE150pd
86fordE150expanded
```

The base supplies 12 vehicle definitions. The Expanded module adds 53 more branded/service variants and many new entries to business and special-purpose vehicle zones. The three pop-culture modules primarily enable special variants already defined by the base.

Tradeoffs:

- Enabling Expanded increases variety but heavily weights the pack toward one van family and changes the composition of business/special vehicle zones.
- The optional modules expose only `42.0` version layers, whereas the base has a `42.13` multiplayer layer. This is additional version drift on 42.20.3.
- In the pre-cleanup tracked manifest, PZK explicitly marks `86fordE150expanded` incompatible. The user's requested PZK removal eliminates that declared conflict; it would return if PZK were reintroduced.
- Arcadia's current source already contains detailed E-150 support, including the base, special variants, Expanded fleet variants, and distinct standard/long-wheelbase interior pools.

Recommendation: enable `86fordE150` first. Add the three named novelty toggles only if the group wants those rare vehicles. Keep `86fordE150expanded` out of the first test pass, then measure spawn variety and startup/log impact before admitting its 53 definitions.

### Medium: S10 Rust is a replacement, not an additional vehicle

The [S10 Rust Edition author](https://steamcommunity.com/sharedfiles/filedetails/?id=3658499522) states that it replaces the textures of all S10 variants and does not add a separate car. The local payload confirms it replaces 14 S10 shell/interior texture paths through common assets plus a small B42.13 metadata layer.

This fits the enabled Project Seasons/10 Years Later aesthetic, but the tradeoff is global: normal-looking S10 paint is replaced rather than mixed with rusty variants. It also cannot be evaluated as a spawn-frequency addition.

Recommendation: if the all-rust treatment is desired, load `88chevyS10Rusty` immediately after `88chevyS10`. Otherwise enable only the base S10.

### Low: no unique media-path overwrite was found among the safe base cars

The effective 42.13/42.20 media paths for all nine KI5 base items and the S10 Rust add-on were compared with the current active-content inventory. After excluding standard per-mod metadata, generic translation filenames, and sandbox metadata, no relative media path collided with an enabled mod.

The KI5 items extend shared runtime tables such as `VehicleZoneDistribution`, `VehicleDistributions`, and mechanics-overlay registries. Their entries use vehicle-specific names. This does not prove runtime perfection, but it rules out the most direct silent overwrite class that affected ETO and other parts of the original pack.

## Arcadia RV integration

The target cleanup keeps Arcadia and removes the Project RV family. The latest local Arcadia source already recognizes three of the new vehicle families:

- `63Type2Van` and its Hippie, Apocalypse, and Military variants.
- `86fordE150`, the special variants, both long-wheelbase variants, and all E-150 Expanded fleet variants.
- `91range` and `91range2` through the current KI5 catalog support list.

No Arcadia entries were found for the ordinary sedans/coupe/pickup, which is appropriate. The M911 is also not assigned an Arcadia interior.

Arcadia registers these relationships by full vehicle-script name and does not declare a `loadAfter` requirement on the vehicle Mod IDs. The meaningful order requirement remains Arcadia's map-folder rule, not a newly discovered `Mods=` dependency.

## Applied relative order and constraints

The applied manifest preserves the existing `damnlib`-before-KI5 relationship and places the admitted bases in the existing year-oriented KI5 block. The inactive alternatives are shown only as constraints:

```text
damnlib

63beetle
63Type2Van
...
82porsche911
# 82oshkoshM911 only if rSemiTruck is removed
...
85buickLeSabre
...
86fordE150
# optional, after the base:
# 86fordE150dnd
# 86fordE150mm
# 86fordE150pd
# 86fordE150expanded
...
88chevyS10
# optional texture replacement:
88chevyS10Rusty
...
90bmwE30
...
91range
...
93fordTaurus
...
95impreza
98stagea
```

Required ordering constraints, independent of the cosmetic year grouping:

```text
damnlib < every new KI5 base vehicle
86fordE150 < every E-150 optional submod
88chevyS10 < 88chevyS10Rusty
tsarslib must be present for M911 tanker fuel functionality
```

There is no evidence-backed `VASinked` placement that makes the current B42.15 code safe on B42.20.3. It should be excluded, not merely moved later.

## Content and performance tradeoffs

The nine base KI5 items define 41 vehicle scripts in total, including five M911 trailers and a burnt M911 variant. Excluding M911 still adds 33 drivable/special vehicle definitions. Enabling E-150 Expanded raises the new-definition count by another 53.

Expected effects to measure rather than assume:

- Longer script/asset initialization and more vehicle models/textures resident as they are encountered.
- Changed relative spawn composition in vehicle zones; more definitions do not necessarily mean a higher total number of spawned vehicles.
- More mechanics recipes, armor parts, and loot-distribution entries competing in already large lists.
- Greater vehicle variety versus reduced likelihood of finding a particular vanilla or previously installed car.

The Stagea also creates a deliberate setting tradeoff: its author acknowledges the 1998 model is later than the game's 1993 setting. That is a content choice, not a technical incompatibility.

## Verification test for the applied set

Use a clone or disposable copy of the current 140/161/6 server world.

1. Confirm the live profile still exactly matches revision `sha256:43fdbb...` before launching.
2. Start the host plus one remote client and inspect startup errors, vehicle scripts, recipes, doors/windows, enter/exit actions, towing, mechanics UI, and BVD version/status output.
3. Spawn and drive each admitted base family. Compare Stagea acceleration, braking, rollover behavior, off-road grip, and collision response against an existing BVD-covered sports car.
4. Validate Arcadia entry/exit and MP teleport behavior for Type 2, E-150, and Range Rover.
5. Confirm that all S10 variants intentionally receive the Rust replacement textures on host and remote client.
6. If E-150 options are reconsidered, admit them one at a time with Expanded last.
7. Test M911 only in a separate `rSemiTruck`-free pass if the group wants to compare the two semi ecosystems. Keep `VASinked` excluded.

Record log deltas, startup time, reproduction steps, and the exact mod-list revision before calling the additions ready.

## Sources inspected

Primary sources were the effective local `mod.info`, Lua, script, and texture payloads for the Workshop IDs above, the locally installed BVD and Arcadia source, the tracked manifest, the selected server profile, Steam's local Workshop manifest, and these author-owned pages:

- [Vanilla Vehicles Animated](https://steamcommunity.com/sharedfiles/filedetails/?id=3281755175)
- [Vehicle Animations Sinked](https://steamcommunity.com/sharedfiles/filedetails/?id=3685499657)
- [that DAMN Library](https://steamcommunity.com/workshop/filedetails/?id=3171167894)
- ['82 Oshkosh M911](https://steamcommunity.com/sharedfiles/filedetails/?id=2618213077)
- ['98 Nissan Stagea](https://steamcommunity.com/sharedfiles/filedetails/?id=3315443103)
- ['93 Ford Taurus](https://steamcommunity.com/sharedfiles/filedetails/?id=3088951320)
- ['63 Volkswagen Type 2 Van](https://steamcommunity.com/sharedfiles/filedetails/?id=3041122351)
- ['85 Buick LeSabre](https://steamcommunity.com/sharedfiles/filedetails/?id=3418252689)
- ['91 Range Rover Classic](https://steamcommunity.com/sharedfiles/filedetails/?id=2409333430)
- ['90 BMW E30](https://steamcommunity.com/sharedfiles/filedetails/?id=3110913021)
- ['86 Ford Econoline E-150](https://steamcommunity.com/sharedfiles/filedetails/?id=2870394916)
- ['88 Chevrolet S10](https://steamcommunity.com/sharedfiles/filedetails/?id=2886832936)
- ['88 Chevrolet S10 Rust Edition](https://steamcommunity.com/sharedfiles/filedetails/?id=3658499522)
- [W900 Semi-Truck](https://steamcommunity.com/sharedfiles/filedetails/?id=3409472393)
- [B42 Tsar's Common Library](https://steamcommunity.com/sharedfiles/filedetails/?id=3402491515)
- [PZK Vanilla Plus Car Pack](https://steamcommunity.com/sharedfiles/filedetails/?id=3217685049)
- [Efficiency Skill Mod 2](https://steamcommunity.com/sharedfiles/filedetails/?id=3374408921)
- [Bicycle!](https://steamcommunity.com/sharedfiles/filedetails/?id=3461415167)
- [Fluffy Hair](https://steamcommunity.com/sharedfiles/filedetails/?id=2447729538)
- [Proximity Inventory](https://steamcommunity.com/sharedfiles/filedetails/?id=2847184718)
- [Project Cook](https://steamcommunity.com/sharedfiles/filedetails/?id=3490188370)
- [Neat Crafting](https://steamcommunity.com/sharedfiles/filedetails/?id=3502080466)
- [Neat Building](https://steamcommunity.com/sharedfiles/filedetails/?id=3536052310)
- [NeatUI Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3508537032)
