[CmdletBinding()]
param(
    [string]$LocalConfigurationPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$modRoot = Join-Path $repositoryRoot 'src\mods\GaelGunStoreCoreFixes'
$versionRoot = Join-Path $modRoot '42.20'
$lootModRoot = Join-Path $repositoryRoot 'src\mods\GaelGunStoreLootDiversification'
$lootVersionRoot = Join-Path $lootModRoot '42.20'
$visualModRoot = Join-Path $repositoryRoot 'src\mods\ItemVisualCompatibilityFixes'
$definitionsPath = Join-Path $versionRoot 'media\lua\shared\GaelGunStoreCoreFixes\Definitions.lua'
$lootDefinitionsPath = Join-Path $lootVersionRoot 'media\lua\shared\GaelGunStoreLootDiversification\Definitions.lua'
$recipesPath = Join-Path $versionRoot 'media\scripts\GaelGunStoreCoreFixes_Recipes.txt'
$itemNamesPath = Join-Path $versionRoot 'media\lua\shared\Translate\EN\ItemName.json'
$recipeNamesPath = Join-Path $versionRoot 'media\lua\shared\Translate\EN\Recipes.json'
$magazineItemsPath = Join-Path $versionRoot 'media\scripts\GaelGunStoreCoreFixes_Magazines.txt'
$visualAliasesPath = Join-Path $versionRoot 'media\scripts\GaelGunStoreCoreFixes_VisualAliases.txt'
$automaticMagazineSelectionPath = Join-Path $versionRoot 'media\lua\client\GaelGunStoreCoreFixes\AutomaticMagazineSelection.lua'
$magazineCompatibilityPath = Join-Path $versionRoot 'media\lua\client\GaelGunStoreCoreFixes\MagazineCompatibility.lua'
$lootCompatibilityPath = Join-Path $versionRoot 'media\lua\server\GaelGunStoreCoreFixes\LootCompatibility.lua'
$spawnDiversificationPath = Join-Path $lootVersionRoot 'media\lua\shared\GaelGunStoreLootDiversification\FirearmSpawnDiversification.lua'
$spawnApplicationPath = Join-Path $lootVersionRoot 'media\lua\server\GaelGunStoreLootDiversification\ApplyFirearmSpawnDiversification.lua'
$gaelLootApplicationPath = Join-Path $lootVersionRoot 'media\lua\server\GaelGunStoreLootDiversification\DiversifyGaelLoot.lua'
$spawnDiversificationTestPath = Join-Path $lootVersionRoot 'media\lua\client\GaelGunStoreLootDiversification\Tests\FirearmSpawnDiversificationTests.lua'
$lootStatePolicyPath = Join-Path $lootVersionRoot 'media\lua\shared\GaelGunStoreLootDiversification\LootStatePolicy.lua'
$lootStateApplicationPath = Join-Path $lootVersionRoot 'media\lua\server\GaelGunStoreLootDiversification\InitializeLootState.lua'
$lootStateJavaPath = Join-Path $lootVersionRoot 'media\java-src\pzmod\gaellootdiversification\GaelLootStateRuntime.java'
$visualCompatibilityPath = Join-Path $visualModRoot '42.20\media\lua\shared\ItemVisualCompatibilityFixes.lua'
$failures = [Collections.Generic.List[string]]::new()

function Get-BracedBlock {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Pattern
    )

    $match = [regex]::Match($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::Multiline)
    if (-not $match.Success) { return $null }
    $openIndex = $Text.IndexOf('{', $match.Index + $match.Length - 1)
    if ($openIndex -lt 0) { return $null }
    $depth = 0
    for ($index = $openIndex; $index -lt $Text.Length; $index++) {
        if ($Text[$index] -eq '{') { $depth++ }
        elseif ($Text[$index] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $Text.Substring($openIndex + 1, $index - $openIndex - 1)
            }
        }
    }
    return $null
}

function Get-MapperPairs {
    param(
        [Parameter(Mandatory)] [string]$RecipeBlock,
        [Parameter(Mandatory)] [string]$MapperName
    )

    $mapper = Get-BracedBlock -Text $RecipeBlock -Pattern ("itemMapper\s+{0}\s*\{{" -f [regex]::Escape($MapperName))
    if ($null -eq $mapper) { return @{} }
    $pairs = @{}
    foreach ($match in [regex]::Matches($mapper, '(?m)^\s*(Base\.[\w.]+)\s*=\s*(Base\.[\w.]+)\s*,')) {
        $pairs[$match.Groups[1].Value] = $match.Groups[2].Value
    }
    return $pairs
}

$requiredPaths = @(
    'LICENSE.txt',
    'README.md',
    'CHANGELOG.md',
    '42.20\mod.info',
    '42.20\media\lua\shared\GaelGunStoreCoreFixes\Definitions.lua',
    '42.20\media\lua\shared\GaelGunStoreCoreFixes\ScriptPatches.lua',
    '42.20\media\lua\server\GaelGunStoreCoreFixes\ContainerCompatibility.lua',
    '42.20\media\lua\server\GaelGunStoreCoreFixes\LootCompatibility.lua',
    '42.20\media\lua\client\GaelGunStoreCoreFixes\AutomaticMagazineSelection.lua',
    '42.20\media\lua\client\GaelGunStoreCoreFixes\MagazineCompatibility.lua',
    '42.20\media\lua\client\GaelGunStoreCoreFixes\SafeAmmoUnpack.lua',
    '42.20\media\lua\client\GaelGunStoreCoreFixes\Tests\AutomaticMagazineSelectionTests.lua',
    '42.20\media\lua\client\GaelGunStoreCoreFixes\Tests\DefinitionsTests.lua',
    '42.20\media\lua\client\GaelGunStoreCoreFixes\Tests\MagazineCompatibilityTests.lua',
    '42.20\media\lua\shared\Translate\EN\ItemName.json',
    '42.20\media\lua\shared\Translate\EN\Recipes.json',
    '42.20\media\scripts\GaelGunStoreCoreFixes_Magazines.txt',
    '42.20\media\scripts\GaelGunStoreCoreFixes_Recipes.txt',
    '42.20\media\scripts\GaelGunStoreCoreFixes_VisualAliases.txt'
)
foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $modRoot $relativePath) -PathType Leaf)) {
        $failures.Add("Missing Gael patch path: $relativePath")
    }
}
foreach ($path in @(
    $lootDefinitionsPath,
    $spawnDiversificationPath,
    $spawnApplicationPath,
    $gaelLootApplicationPath,
    $spawnDiversificationTestPath,
    $lootStatePolicyPath,
    $lootStateApplicationPath,
    $lootStateJavaPath,
    $visualCompatibilityPath
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing split Gael patch path: $path")
    }
}
$lootModInfo = Get-Content -LiteralPath (Join-Path $lootVersionRoot 'mod.info') -Raw
foreach ($expected in @(
    'id=GaelGunStoreLootDiversification',
    'require=\ZombieBuddy,GaelGunStore_B42',
    'modversion=0.2.0',
    'javaJarFile=media/java/common/GaelGunStoreLootDiversification.jar',
    'javaPkgName=pzmod.gaellootdiversification'
)) {
    if (-not $lootModInfo.Contains($expected)) { $failures.Add("Loot diversification mod.info is missing: $expected") }
}
$lootStatePolicy = Get-Content -LiteralPath $lootStatePolicyPath -Raw
$lootStateApplication = Get-Content -LiteralPath $lootStateApplicationPath -Raw
$lootStateJava = Get-Content -LiteralPath $lootStateJavaPath -Raw
foreach ($expected in @(
    'secure = {',
    'condition = { 70, 100 }',
    'magazine = { 50, 100 }',
    'zombie = {',
    'condition = { 20, 60 }',
    'magazine = { 10, 60 }',
    'GGS_LootState_0_2_Firearm',
    'GGS_LootState_0_2_Magazine'
)) {
    if (-not $lootStatePolicy.Contains($expected)) { $failures.Add("Loot state policy is missing: $expected") }
}
foreach ($expected in @(
    'Events.OnFillContainer.Add(initializeContainer)',
    'or instanceof(item, "HandWeapon")',
    'item:getMaxAmmo() <= 0',
    'not gunTypes:isEmpty()',
    'instanceof(item, "InventoryContainer")'
)) {
    if (-not $lootStateApplication.Contains($expected)) { $failures.Add("Loot state application is missing: $expected") }
}
foreach ($expected in @(
    'GameClient.client',
    'zombie.isReanimatedPlayer()',
    'zombie.wasFakeDead()',
    'item instanceof HandWeapon weapon && weapon.isRanged()',
    'gunTypes != null && !gunTypes.isEmpty()'
)) {
    if (-not $lootStateJava.Contains($expected)) { $failures.Add("Zombie loot state runtime is missing: $expected") }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$modInfo = Get-Content -LiteralPath (Join-Path $versionRoot 'mod.info') -Raw
foreach ($expected in @(
    'id=GaelGunStoreCoreFixes',
    'require=\GaelGunStore_B42',
    'modversion=1.0.2',
    'versionMin=42.20.3',
    'versionMax=42.20.3'
)) {
    if (-not $modInfo.Contains($expected)) { $failures.Add("mod.info is missing: $expected") }
}
$visualModInfo = Get-Content -LiteralPath (Join-Path $visualModRoot '42.20\mod.info') -Raw
if (-not $visualModInfo.Contains('require=Authentic Z - Current,Bandits2,HNDLBR_Preppers')) {
    $failures.Add('ItemVisualCompatibilityFixes must require only its three visual targets.')
}
if ($visualModInfo.Contains('GaelGunStore_B42')) {
    $failures.Add('ItemVisualCompatibilityFixes must not require unrelated GaelGunStore_B42.')
}

try { $itemNames = Get-Content -LiteralPath $itemNamesPath -Raw | ConvertFrom-Json }
catch { $failures.Add("Invalid ItemName.json: $($_.Exception.Message)") }
try { $recipeNames = Get-Content -LiteralPath $recipeNamesPath -Raw | ConvertFrom-Json }
catch { $failures.Add("Invalid Recipes.json: $($_.Exception.Message)") }

$definitions = Get-Content -LiteralPath $definitionsPath -Raw
$lootDefinitions = Get-Content -LiteralPath $lootDefinitionsPath -Raw
$recipes = Get-Content -LiteralPath $recipesPath -Raw
$packageMatches = [regex]::Matches($definitions, '\{\s*item\s*=\s*"(Base\.[^"]+)",\s*recipe\s*=\s*"([^"]+)",\s*rounds\s*=\s*(\d+)\s*\}')
$packageItems = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$packageRecipes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$packageRoundCounts = @{}
$packageRecipeByItem = @{}
foreach ($match in $packageMatches) {
    $item = $match.Groups[1].Value
    $recipe = $match.Groups[2].Value
    $rounds = [int]$match.Groups[3].Value
    if (-not $packageItems.Add($item)) { $failures.Add("Duplicate package definition: $item") }
    $null = $packageRecipes.Add($recipe)
    $packageRoundCounts[$item] = $rounds
    $packageRecipeByItem[$item] = $recipe
    if ($rounds -le 0) { $failures.Add("Non-positive package count: $item") }
}
if ($packageItems.Count -ne 67) { $failures.Add("Expected 67 box/projectile package definitions; found $($packageItems.Count).") }

$cartonTable = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.cartons\s*=\s*\{'
$cartons = @([regex]::Matches([string]$cartonTable, '"(Base\.[^"]+Carton)"') | ForEach-Object { $_.Groups[1].Value })
if ($cartons.Count -ne 20 -or @($cartons | Sort-Object -Unique).Count -ne 20) {
    $failures.Add("Expected 20 unique carton definitions; found $($cartons | Sort-Object -Unique).Count.")
}
if ($cartons -notcontains 'Base.3030Carton') { $failures.Add('The carton list is missing Base.3030Carton.') }

$pistolTable = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.pistolMagazines\s*=\s*\{'
$pistolMagazines = @([regex]::Matches([string]$pistolTable, '"(Base\.[^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($pistolMagazines.Count -ne 10 -or @($pistolMagazines | Sort-Object -Unique).Count -ne 10) {
    $failures.Add("Expected 10 unique chest-holster magazine types; found $($pistolMagazines | Sort-Object -Unique).Count.")
}
if (@($pistolMagazines | Where-Object { $_ -match 'Drum' }).Count -gt 0) {
    $failures.Add('Chest-holster compatibility must not include drum magazines.')
}
$shotgunTable = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.shotgunAmmo\s*=\s*\{'
$shotgunAmmo = @([regex]::Matches([string]$shotgunTable, '"(Base\.[^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($shotgunAmmo.Count -ne 3 -or @($shotgunAmmo | Sort-Object -Unique).Count -ne 3) {
    $failures.Add("Expected three unique shotgun-ammo compatibility types; found $($shotgunAmmo | Sort-Object -Unique).Count.")
}

$feedDeviceTable = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.feedDevices\s*=\s*\{'
$feedDeviceMatches = [regex]::Matches([string]$feedDeviceTable, '\{\s*item\s*=\s*"(Base\.[^"]+)",\s*rounds\s*=\s*(\d+)\s*\}')
$feedDevices = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$feedDeviceRoundCounts = @{}
foreach ($match in $feedDeviceMatches) {
    $item = $match.Groups[1].Value
    $rounds = [int]$match.Groups[2].Value
    if (-not $feedDevices.Add($item)) { $failures.Add("Duplicate feed-device definition: $item") }
    if ($rounds -le 0) { $failures.Add("Non-positive feed-device capacity: $item") }
    $feedDeviceRoundCounts[$item] = $rounds
}
if ($feedDevices.Count -ne 66) { $failures.Add("Expected 66 unique feed devices; found $($feedDevices.Count).") }
foreach ($expected in @{
    'Base.22LRClip' = 25
    'Base.303Drum50' = 40
    'Base.308Clip30' = 30
    'Base.Bullets50Clip' = 30
    'Base.762x39Drum73' = 73
    'Base.792x57Clip40' = 40
}.GetEnumerator()) {
    if ($feedDeviceRoundCounts[$expected.Key] -ne $expected.Value) {
        $failures.Add("Unexpected feed-device capacity for $($expected.Key): $($feedDeviceRoundCounts[$expected.Key])")
    }
}

$itemNameKeys = @($itemNames.PSObject.Properties.Name)
if (@($itemNameKeys | Where-Object { $_ -like 'ItemName_*' }).Count -gt 0) {
    $failures.Add('Build 42 ItemName.json must not contain legacy ItemName_* keys.')
}
foreach ($item in @($packageItems) + $cartons + @($feedDevices)) {
    if ($itemNameKeys -notcontains $item) { $failures.Add("Missing English item name: $item") }
}
foreach ($item in $packageItems) {
    if ($itemNameKeys -contains $item) {
        $translatedName = [string]$itemNames.PSObject.Properties[$item].Value
        if ($translatedName -notmatch ('\({0}\s' -f $packageRoundCounts[$item])) {
            $failures.Add("Package name does not state its configured count $($packageRoundCounts[$item]): $item")
        }
    }
}
foreach ($item in $feedDevices) {
    if ($itemNameKeys -contains $item) {
        $translatedName = [string]$itemNames.PSObject.Properties[$item].Value
        if ($translatedName -notmatch ('\({0}\s' -f $feedDeviceRoundCounts[$item])) {
            $failures.Add("Feed-device name does not state its configured capacity $($feedDeviceRoundCounts[$item]): $item")
        }
        if ($translatedName -notmatch '^(?:\.\d|\d)') {
            $failures.Add("Feed-device name must begin with its caliber rather than a weapon name: $item ($translatedName)")
        }
    }
}
foreach ($canonicalName in @{
    'Base.45Clip' = '.45 ACP Magazine (12 Rounds)'
    'Base.9mmClip' = '9mm Magazine (15 Rounds)'
    'Base.M14Clip' = '.308 Winchester (7.62x51mm) Magazine (20 Rounds)'
}.GetEnumerator()) {
    if ([string]$itemNames.PSObject.Properties[$canonicalName.Key].Value -cne $canonicalName.Value) {
        $failures.Add("Canonical shared-magazine name changed: $($canonicalName.Key)")
    }
}
$allItemNameValues = @($itemNames.PSObject.Properties | ForEach-Object { [string]$_.Value })
foreach ($legacyName in @('M1911 Auto Magazine', 'M9 Magazine', 'M1A Magazine')) {
    if (@($allItemNameValues | Where-Object { $_ -ceq $legacyName }).Count -gt 0) {
        $failures.Add("Legacy weapon-specific magazine name remains: $legacyName")
    }
}
foreach ($item in @(
    'Base.308Box', 'Base.308Bullets', 'Base.308BulletsAP', 'Base.308BulletsTracer',
    'Base.308Carton', 'Base.308BulletsAPBox', 'Base.308BulletsTracerBox', 'Base.308Box150',
    'Base.308Clip', 'Base.M14Clip', 'Base.308Clip30', 'Base.308Clip40', 'Base.308Drum60', 'Base.308Drum100'
)) {
    $translatedName = [string]$itemNames.PSObject.Properties[$item].Value
    if ($translatedName -notmatch '\.308 Winchester' -or $translatedName -notmatch '7\.62x51mm') {
        $failures.Add(".308 item name must include both caliber names: $item")
    }
}
foreach ($item in @('Base.303Bullets', 'Base.303Box', 'Base.303Clip20', 'Base.303Drum50')) {
    $translatedName = [string]$itemNames.PSObject.Properties[$item].Value
    if ($translatedName -notmatch '\.303 British|303 British' -or $translatedName -match '7\.62x51mm') {
        $failures.Add(".303 British item name is ambiguous or incorrect: $item")
    }
}
$recipeNameKeys = @($recipeNames.PSObject.Properties.Name)
foreach ($recipe in $packageRecipes) {
    if ($recipeNameKeys -notcontains $recipe) { $failures.Add("Missing English recipe name: $recipe") }
}

$customRecipeNames = @([regex]::Matches($recipes, '(?m)^\s*craftRecipe\s+(\S+)') | ForEach-Object { $_.Groups[1].Value })
if ($customRecipeNames.Count -ne @($customRecipeNames | Sort-Object -Unique).Count) {
    $failures.Add('The custom recipe script contains duplicate recipe names.')
}
$customRecipeTable = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.customRecipes\s*=\s*\{'
$declaredCustomRecipes = @([regex]::Matches([string]$customRecipeTable, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
if ($declaredCustomRecipes.Count -ne 14 -or @($declaredCustomRecipes | Sort-Object -Unique).Count -ne 14) {
    $failures.Add("Expected 14 unique custom recipe declarations; found $($declaredCustomRecipes | Sort-Object -Unique).Count.")
}
if (Compare-Object @($customRecipeNames | Sort-Object) @($declaredCustomRecipes | Sort-Object)) {
    $failures.Add('Definitions.customRecipes does not exactly match the custom recipe script.')
}
foreach ($recipe in $customRecipeNames) {
    if ($recipeNameKeys -notcontains $recipe) { $failures.Add("Missing English custom recipe name: $recipe") }
}

$openCarton = Get-BracedBlock -Text $recipes -Pattern 'craftRecipe\s+GGSASF_OpenAmmoCarton\s*\{'
$packCarton = Get-BracedBlock -Text $recipes -Pattern 'craftRecipe\s+GGSASF_PackAmmoCarton\s*\{'
if ($null -eq $openCarton -or $null -eq $packCarton) {
    $failures.Add('The reciprocal carton recipes are missing.')
}
else {
    if ($openCarton -notmatch 'item\s+12\s+mapper:boxType') { $failures.Add('Carton unpack must output exactly 12 boxes.') }
    if ($packCarton -notmatch 'item\s+12\s+\[') { $failures.Add('Carton packing must consume exactly 12 boxes.') }
    $openPairs = Get-MapperPairs -RecipeBlock $openCarton -MapperName 'boxType'
    $packPairs = Get-MapperPairs -RecipeBlock $packCarton -MapperName 'cartonType'
    if ($openPairs.Count -ne 20 -or $packPairs.Count -ne 20) {
        $failures.Add("Expected 20 mappings in each carton recipe; found $($openPairs.Count) and $($packPairs.Count).")
    }
    foreach ($box in $openPairs.Keys) {
        $carton = $openPairs[$box]
        if ($packPairs[$carton] -ne $box) {
            $failures.Add("Carton mapping is not reciprocal: $carton <-> $box")
        }
    }
}

$magazineItems = Get-Content -LiteralPath $magazineItemsPath -Raw
foreach ($expectedItem in @{
    '308Clip30' = @{ MaxAmmo = 30; AmmoType = 'base:bullets_308' }
    'Bullets50Clip' = @{ MaxAmmo = 30; AmmoType = 'ggs:bullets_50' }
    '792x57Clip40' = @{ MaxAmmo = 40; AmmoType = 'ggs:792x57_bullets' }
}.GetEnumerator()) {
    $block = Get-BracedBlock -Text $magazineItems -Pattern ("item\s+{0}\s*\{{" -f [regex]::Escape($expectedItem.Key))
    if ($null -eq $block) {
        $failures.Add("Missing restored magazine item: Base.$($expectedItem.Key)")
        continue
    }
    if ($block -notmatch ("(?m)^\s*MaxAmmo\s*=\s*{0}\s*," -f $expectedItem.Value.MaxAmmo)) {
        $failures.Add("Restored magazine has the wrong capacity: Base.$($expectedItem.Key)")
    }
    if ($block -notmatch ("(?m)^\s*AmmoType\s*=\s*{0}\s*," -f [regex]::Escape($expectedItem.Value.AmmoType))) {
        $failures.Add("Restored magazine has the wrong ammo type: Base.$($expectedItem.Key)")
    }
}
foreach ($visualPart in @('Clip_308Clip20', 'Clip_Bullets50Clip', 'Clip_792x57Clip40')) {
    if ($null -eq (Get-BracedBlock -Text $magazineItems -Pattern ("item\s+{0}\s*\{{" -f [regex]::Escape($visualPart)))) {
        $failures.Add("Missing restored visual magazine part: Base.$visualPart")
    }
}
$visualAliases = Get-Content -LiteralPath $visualAliasesPath -Raw
foreach ($visualPart in @('Clip_M14Clip', 'Clip_303Clip20', 'Clip_303Drum50', 'Clip_9mmClip70old')) {
    if ($null -eq (Get-BracedBlock -Text $visualAliases -Pattern ("item\s+{0}\s*\{{" -f [regex]::Escape($visualPart)))) {
        $failures.Add("Missing visual-alias item: Base.$visualPart")
    }
}
foreach ($visualModel in @('Clip_M14Clip', 'Clip_303Clip20', 'Clip_303Drum50', 'Clip_9mmClip70old', 'Clip_Bullets50Clip', 'Clip_792x57Clip40')) {
    $modelBlock = Get-BracedBlock -Text $visualAliases -Pattern ("model\s+{0}\s*\{{" -f [regex]::Escape($visualModel))
    if ($null -eq $modelBlock) {
        $failures.Add("Missing visual-alias model: Base.$visualModel")
    }
    elseif ($modelBlock -notmatch '(?m)^\s*mesh\s*=\s*\S+\s*,' -or $modelBlock -notmatch '(?m)^\s*texture\s*=\s*\S+\s*,') {
        $failures.Add("Visual-alias model is missing mesh/texture references: Base.$visualModel")
    }
}
foreach ($requiredDefinition in @(
    '{ item = "Base.BenelliM3", parameters = { Icon = "BenelliM4" } }',
    '{ item = "Base.G36", parameters = { Icon = "G36C" } }',
    '{ item = "Base.M9A3", parameters = { Icon = "M9" } }',
    '{ item = "Base.PKM", parameters = { Icon = "PKP" } }',
    '{ item = "Base.Rhino60DS", parameters = { Icon = "Rhino20DS" } }',
    '{ item = "Base.303Clip20", parameters = { Icon = "792x57Clip" } }',
    '{ item = "Base.303Drum50", parameters = { Icon = "308Drum60" } }',
    '{ item = "Base.BizonClip64", parameters = { Icon = "22LRDrum100" } }',
    '{ item = "Base.30_06Clip", parameters = { Icon = "792x57Clip" } }',
    '{ item = "Base.30_06Clip40", parameters = { Icon = "308Clip40" } }',
    '{ item = "Base.Bullets50Clip", parameters = { Icon = "308Box150" } }',
    '{ item = "Base.9mmClip70old", parameters = { WorldStaticModel = "Clip_9mmClip70old" } }',
    '{ item = "Base.9mmClip100old", parameters = { WorldStaticModel = "Clip_9mmClip100old" } }',
    'item = "Base.Grizzly50AE"',
    'ammoType = "ggs:bullets_50magnum"',
    'item = "Base.M39", ammoType = "base:bullets_308"',
    'item = "Base.Enfield"',
    'ammoType = "ggs:303_bullets"',
    'ammoBox = "Base.303Box"',
    'item = "Base.MG131"',
    '{ from = "P38", to = "Walther_P38" }',
    '{ from = "Pistol_shotgun", to = "pistol_shotgun" }',
    '{ from = "SVDk", to = "SVDK" }',
    'HeadhunterRifle = { "308Clip", "M14Clip", "308Clip30", "308Clip40" }',
    'DeadlyHeadhunterRifle = { "308Clip", "M14Clip", "308Clip30", "308Clip40" }',
    'TrapperCarbine = { "45Clip", "45Clip25", "45Drum50" }',
    'magazines = { "308Clip", "M14Clip", "308Clip30", "308Clip40" }',
    'M14Clip = "Base.Clip_M14Clip"',
    '["303Clip20"] = "Base.Clip_303Clip20"',
    '["303Drum50"] = "Base.Clip_303Drum50"',
    '["9mmClip70old"] = "Base.Clip_9mmClip70old"',
    'M9A3 = { "9mmClip", "9mmClip30", "9mmDrum50" }',
    'UMP9 = { "9mmClip", "9mmClip30", "9mmDrum50", "9mmDrum75", "9mmDrum100" }',
    'G36 = { "556Clip", "556Drum_60rnd", "556Drum_100rnd" }',
    'MAT49 = { "9mmClip", "9mmClip30old", "9mmClip100old" }',
    'PPSH41 = { "9mmClip30old", "9mmClip", "9mmClip30", "9mmDrum50", "9mmDrum75", "9mmDrum100" }'
)) {
    if (-not $definitions.Contains($requiredDefinition)) {
        $failures.Add("Definitions.lua is missing the targeted compatibility declaration: $requiredDefinition")
    }
}

$visualCompatibility = Get-Content -LiteralPath $visualCompatibilityPath -Raw
foreach ($requiredVisualPatch in @(
    'item = "AuthenticZClothing.AuthenticSmokeBomb"',
    '{ item = "Bandits.Bucket", parameters = { StaticModel = "Bucket" } }',
    'item = "Base.HeadhunterRifle"',
    '"Base.x8Scope Base.x8Scope scope scope"'
)) {
    if (-not $visualCompatibility.Contains($requiredVisualPatch)) {
        $failures.Add("Item visual compatibility source is missing: $requiredVisualPatch")
    }
}
foreach ($requiredLootPolicy in @('Definitions.firearmSpawnPools', '["Base.Minigun"] = true', 'Pistol = { retain = 0.025', 'Shotgun = { retain = 0.025')) {
    if (-not $lootDefinitions.Contains($requiredLootPolicy)) {
        $failures.Add("Loot diversification definitions are missing: $requiredLootPolicy")
    }
}

$allTextFiles = @($modRoot, $lootModRoot, $visualModRoot) | ForEach-Object {
    Get-ChildItem -LiteralPath $_ -File -Recurse
} | Where-Object Extension -in @('.lua', '.txt', '.md', '.info', '.json')
foreach ($file in $allTextFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match '(?i)[A-Z]:\\Users\\|steamapps\\workshop\\content') {
        $failures.Add("Local or Workshop payload path leaked into $($file.Name).")
    }
}

$scriptPatches = Get-Content -LiteralPath (Join-Path $versionRoot 'media\lua\shared\GaelGunStoreCoreFixes\ScriptPatches.lua') -Raw
foreach ($requiredExpression in @(
    'setDoubleClickRecipe',
    'Definitions.firearmScriptPatches',
    'Definitions.itemVisualPatches',
    'item:DoParam',
    'ModelWeaponPart = ',
    'AmmoType = definition.ammoType',
    'AmmoBox = definition.ammoBox',
    'MagazineType = definition.magazineType',
    'MaxAmmo = definition.maxAmmo',
    'ClipSize = definition.clipSize',
    'ItemTag.AMMO',
    'ItemTag.SHOTGUN_SHELL',
    'ItemTag.PISTOL_MAGAZINE'
)) {
    if (-not $scriptPatches.Contains($requiredExpression)) { $failures.Add("Script patch is missing $requiredExpression") }
}
$containerCompatibility = Get-Content -LiteralPath (Join-Path $versionRoot 'media\lua\server\GaelGunStoreCoreFixes\ContainerCompatibility.lua') -Raw
foreach ($requiredExpression in @('originalBullets', 'originalShells', 'originalHolster', 'container:getItems():size() < 2')) {
    if (-not $containerCompatibility.Contains($requiredExpression)) { $failures.Add("Container compatibility is missing $requiredExpression") }
}
$safeUnpack = Get-Content -LiteralPath (Join-Path $versionRoot 'media\lua\client\GaelGunStoreCoreFixes\SafeAmmoUnpack.lua') -Raw
foreach ($requiredExpression in @('GGSASF_VanillaSequentialAmmoUnpack', 'additive deployments', 'Vanilla queues package transfers before crafting')) {
    if (-not $safeUnpack.Contains($requiredExpression)) { $failures.Add("Vanilla sequential unpack compatibility file is missing: $requiredExpression") }
}
foreach ($forbiddenExpression in @('ISInventoryPaneContextMenu.OnNewCraft =', 'newInventoryTransferAction', 'setOnComplete', 'continueAfterTransfer', 'originalOnNewCraft')) {
    if ($safeUnpack.Contains($forbiddenExpression)) { $failures.Add("Obsolete unpack continuation is still present: $forbiddenExpression") }
}

foreach ($testPath in @(
    (Join-Path $versionRoot 'media\lua\client\GaelGunStoreCoreFixes\Tests\AutomaticMagazineSelectionTests.lua'),
    (Join-Path $versionRoot 'media\lua\client\GaelGunStoreCoreFixes\Tests\DefinitionsTests.lua'),
    (Join-Path $versionRoot 'media\lua\client\GaelGunStoreCoreFixes\Tests\MagazineCompatibilityTests.lua'),
    (Join-Path $lootVersionRoot 'media\lua\client\GaelGunStoreLootDiversification\Tests\FirearmSpawnDiversificationTests.lua')
)) {
    $testSource = Get-Content -LiteralPath $testPath -Raw
    if (-not $testSource.Contains('contains("\\TEST_FRAMEWORK")')) {
        $failures.Add("Debug test uses the wrong TEST_FRAMEWORK activation ID: $testPath")
    }
}

$magazineCompatibility = Get-Content -LiteralPath $magazineCompatibilityPath -Raw
foreach ($requiredExpression in @(
    'Definitions.magazineMapAliases',
    'Definitions.magazineMapRemovals',
    'Definitions.magazineMapUnions',
    'Definitions.magazinePartPatches',
    'GGSASF_ApplyMagazineCompatibility',
    'GGS_MagMapping._reverseMap = nil',
    'Events.OnGameStart.Add'
)) {
    if (-not $magazineCompatibility.Contains($requiredExpression)) {
        $failures.Add("Magazine compatibility patch is missing: $requiredExpression")
    }
}
$automaticMagazineSelection = Get-Content -LiteralPath $automaticMagazineSelectionPath -Raw
foreach ($requiredExpression in @(
    'findCompatibleMagazines',
    'findBestCompatibleMagazine',
    'queueCompatibleMagazine',
    'BeginAutomaticReload',
    'ReloadBestMagazine',
    'doReloadMenuForMagazine',
    'doReloadMenuForWeapon',
    '_G.ChangeMagazine',
    'Events.OnGameStart.Add',
    'return Module'
)) {
    if (-not $automaticMagazineSelection.Contains($requiredExpression)) {
        $failures.Add("Automatic magazine selection is missing: $requiredExpression")
    }
}

$lootCompatibility = Get-Content -LiteralPath $lootCompatibilityPath -Raw
foreach ($requiredExpression in @(
    'Definitions.lootClones',
    'Definitions.obsoleteLootItems',
    'require, "item/loot"',
    'GGSASF_ApplyLootCompatibility',
    'table.remove'
)) {
    if (-not $lootCompatibility.Contains($requiredExpression)) {
        $failures.Add("Loot compatibility patch is missing: $requiredExpression")
    }
}
$gaelLootApplication = Get-Content -LiteralPath $gaelLootApplicationPath -Raw
foreach ($requiredExpression in @('Definitions.suppressedLootItems', 'Diversification.transformRecords', 'require, "item/loot"', 'table.remove')) {
    if (-not $gaelLootApplication.Contains($requiredExpression)) {
        $failures.Add("Gael loot diversification is missing: $requiredExpression")
    }
}
$spawnDiversification = Get-Content -LiteralPath $spawnDiversificationPath -Raw
foreach ($requiredExpression in @(
    'transformWeightedItems',
    'transformRoots',
    'transformRecords',
    'transformedArrays',
    'availableReplacements',
    'replacementType'
)) {
    if (-not $spawnDiversification.Contains($requiredExpression)) {
        $failures.Add("Firearm spawn transformer is missing: $requiredExpression")
    }
}
$spawnApplication = Get-Content -LiteralPath $spawnApplicationPath -Raw
foreach ($requiredExpression in @(
    'Items/ProceduralDistributions',
    'Items/Distributions',
    'Items/Distribution_BagsAndContainers',
    'Vehicles/VehicleDistributions',
    'BagsAndContainers.RifleCase1',
    'Diversification.transformRoots',
    'ItemPickerJava.Parse'
)) {
    if (-not $spawnApplication.Contains($requiredExpression)) {
        $failures.Add("Firearm spawn application is missing: $requiredExpression")
    }
}

if (-not $LocalConfigurationPath) { $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json' }
if (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf) {
    try {
        $localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
        $workshopRoot = [string]$localConfiguration.projectZomboid.workshopPath
        $gameRoot = [string]$localConfiguration.projectZomboid.gamePath
        $gaelScripts = Join-Path $workshopRoot '3616176188\mods\GaelGunStore\42\media\scripts'
        $gameScripts = Join-Path $gameRoot 'media\scripts'
        if (Test-Path -LiteralPath $gaelScripts -PathType Container) {
            $gaelText = (@(Get-ChildItem -LiteralPath $gaelScripts -Filter '*.txt' -File -Recurse) |
                ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
            $gameText = (@(Get-ChildItem -LiteralPath $gameScripts -Filter '*.txt' -File -Recurse) |
                ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
            $upstreamText = $gaelText + "`n" + $gameText
            $effectiveItemText = $visualAliases + "`n" + $magazineItems + "`n" + $gaelText + "`n" + $gameText
            $upstreamItems = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($match in [regex]::Matches($effectiveItemText, '(?m)^\s*item\s+([\w.-]+)\s*\{')) { $null = $upstreamItems.Add('Base.' + $match.Groups[1].Value) }
            $upstreamRecipes = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($match in [regex]::Matches($upstreamText, '(?m)^\s*craftRecipe\s+(\S+)')) { $null = $upstreamRecipes.Add($match.Groups[1].Value) }

            $gaelMediaRoot = Join-Path $workshopRoot '3616176188\mods\GaelGunStore\42\media'
            foreach ($iconAlias in @('BenelliM4', 'G36C', 'M9', 'PKP', 'Rhino20DS', '792x57Clip', '308Drum60', '22LRDrum100', '308Clip40', '308Box150')) {
                if (-not (Test-Path -LiteralPath (Join-Path $gaelMediaRoot "textures\Item_$iconAlias.png") -PathType Leaf) -and
                    -not (Test-Path -LiteralPath (Join-Path $gaelMediaRoot "textures\item_$iconAlias.png") -PathType Leaf)) {
                    $failures.Add("Visual icon alias asset is missing: Item_$iconAlias.png")
                }
            }
            foreach ($attachment in @('Base.x8Scope', 'Base.Sling', 'Base.bipod_harris', 'Base.NST_Silencer', 'Base.Scrap_Silencer')) {
                if (-not $upstreamItems.Contains($attachment)) { $failures.Add("Headhunter visual replacement item is missing: $attachment") }
                $shortType = $attachment.Substring($attachment.IndexOf('.') + 1)
                if ($gaelText -notmatch ("(?m)^\s*model\s+{0}\s*\{{" -f [regex]::Escape($shortType))) {
                    $failures.Add("Headhunter visual replacement model is missing: Base.$shortType")
                }
            }
            foreach ($item in @($packageItems) + $cartons + @($feedDevices)) {
                if (-not $upstreamItems.Contains($item)) { $failures.Add("Effective script set is missing item: $item") }
            }
            foreach ($item in $feedDevices) {
                $shortType = $item.Substring($item.IndexOf('.') + 1)
                $itemBlock = Get-BracedBlock -Text $effectiveItemText -Pattern ("item\s+{0}\s*\{{" -f [regex]::Escape($shortType))
                if ($null -eq $itemBlock) { continue }
                $maxAmmo = [regex]::Match($itemBlock, '(?m)^\s*MaxAmmo\s*=\s*(\d+)\s*,')
                if (-not $maxAmmo.Success -or [int]$maxAmmo.Groups[1].Value -ne $feedDeviceRoundCounts[$item]) {
                    $failures.Add("Effective feed-device capacity does not match Definitions.feedDevices for $item.")
                }
            }

            $spawnPoolBlock = Get-BracedBlock -Text $lootDefinitions -Pattern 'Definitions\.firearmSpawnPools\s*=\s*\{'
            $spawnPools = @{}
            foreach ($match in [regex]::Matches([string]$spawnPoolBlock, '(?ms)^\s*([A-Za-z0-9_]+)\s*=\s*\{\s*retain\s*=\s*([0-9.]+),\s*ammoType\s*=\s*"([^"]+)",\s*replacements\s*=\s*\{([^}]*)\}')) {
                $sourceType = $match.Groups[1].Value
                $replacements = @([regex]::Matches($match.Groups[4].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
                $spawnPools[$sourceType] = [pscustomobject]@{
                    Retain = [double]$match.Groups[2].Value
                    AmmoType = $match.Groups[3].Value
                    Replacements = $replacements
                }
            }
            if ($spawnPools.Count -ne 19) { $failures.Add("Expected 19 firearm spawn pools; found $($spawnPools.Count).") }
            if ($spawnPools.ContainsKey('L94_Rifle')) { $failures.Add('L94_Rifle must remain unmodified because no same-ammo replacement exists.') }
            foreach ($sourceType in $spawnPools.Keys) {
                $pool = $spawnPools[$sourceType]
                if ($pool.Retain -le 0 -or $pool.Retain -ge 1) { $failures.Add("Invalid firearm retention rate for $sourceType.") }
                if ($pool.Replacements.Count -eq 0) { $failures.Add("Firearm spawn pool has no replacements: $sourceType") }
                if (@($pool.Replacements | Sort-Object -Unique).Count -ne $pool.Replacements.Count) { $failures.Add("Duplicate firearm replacement in pool: $sourceType") }
                foreach ($replacement in $pool.Replacements) {
                    if (-not $upstreamItems.Contains('Base.' + $replacement)) {
                        $failures.Add("Firearm replacement item is missing: Base.$replacement")
                        continue
                    }
                    $replacementBlock = Get-BracedBlock -Text $effectiveItemText -Pattern ("item\s+{0}\s*\{{" -f [regex]::Escape($replacement))
                    $ammoType = if ($replacementBlock) { [regex]::Match($replacementBlock, '(?m)^\s*AmmoType\s*=\s*([^,\s]+)\s*,') } else { $null }
                    if (-not $ammoType -or -not $ammoType.Success -or $ammoType.Groups[1].Value -ine $pool.AmmoType) {
                        $failures.Add("Firearm replacement has the wrong ammo family: Base.$replacement (expected $($pool.AmmoType))")
                    }
                }
            }
            if ($spawnPools.Pistol.Retain -ne 0.025 -or $spawnPools.Shotgun.Retain -ne 0.025) {
                $failures.Add('M9 and JS-2000 retention must remain at 2.5%.')
            }
            if ($spawnPools.VarmintRifle.AmmoType -ne 'base:bullets_556' -or
                $spawnPools.VarmintRifle.Replacements.Count -ne 1 -or
                $spawnPools.VarmintRifle.Replacements[0] -ne 'Scout_elite') {
                $failures.Add('VarmintRifle replacements must preserve the vanilla 5.56 RifleCase1 ammo family.')
            }

            $gameRoot = [string]$localConfiguration.projectZomboid.gamePath
            $distributionSources = @{
                Procedural = @(Join-Path $gameRoot 'media\lua\server\Items\ProceduralDistributions.lua')
                Legacy = @(Join-Path $gameRoot 'media\lua\server\Items\Distributions.lua')
                Bags = @(Join-Path $gameRoot 'media\lua\server\Items\Distribution_BagsAndContainers.lua')
                Vehicles = @(Get-ChildItem -LiteralPath (Join-Path $gameRoot 'media\lua\server\Vehicles') -Filter 'VehicleDistribution*.lua' -File | Select-Object -ExpandProperty FullName)
            }
            $sourcePattern = '"(?:Base\.)?(' + (($spawnPools.Keys | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')"\s*,\s*([0-9.]+)'
            $distributionHitCounts = @{}
            foreach ($sourceName in $distributionSources.Keys) {
                $sourceText = ($distributionSources[$sourceName] | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { Get-Content -LiteralPath $_ -Raw }) -join "`n"
                $hits = [regex]::Matches($sourceText, $sourcePattern)
                $distributionHitCounts[$sourceName] = $hits.Count
                foreach ($hit in $hits) {
                    $pool = $spawnPools[$hit.Groups[1].Value]
                    $weight = [double]$hit.Groups[2].Value
                    $retained = $weight * $pool.Retain
                    $replacementTotal = ($weight - $retained) / $pool.Replacements.Count * $pool.Replacements.Count
                    if ([math]::Abs(($retained + $replacementTotal) - $weight) -gt 0.000001) {
                        $failures.Add("Firearm spawn weight is not conserved for $($hit.Groups[1].Value) in $sourceName.")
                    }
                }
            }
            foreach ($sourceName in @('Procedural', 'Legacy', 'Bags', 'Vehicles')) {
                if ($distributionHitCounts[$sourceName] -le 0) { $failures.Add("No configured firearm sources found in $sourceName distributions.") }
            }
            if ($distributionHitCounts.Bags -ne 22) {
                $failures.Add("Expected all 22 vanilla firearm entries in nested bag/case tables to be covered; found $($distributionHitCounts.Bags).")
            }
            if ($distributionHitCounts.Vehicles -lt 134) {
                $failures.Add("Expected at least 134 direct vehicle firearm entries to be covered; found $($distributionHitCounts.Vehicles).")
            }

            $generatedMapPath = Join-Path $workshopRoot '3616176188\mods\GaelGunStore\42\media\lua\client\GGS_ControllerGenerated_Attachments.lua'
            $codesPath = Join-Path $workshopRoot '3616176188\mods\GaelGunStore\42\media\lua\client\GGS_Codes.lua'
            if ((Test-Path -LiteralPath $generatedMapPath -PathType Leaf) -and (Test-Path -LiteralPath $codesPath -PathType Leaf)) {
                $generatedMap = Get-Content -LiteralPath $generatedMapPath -Raw
                $codes = Get-Content -LiteralPath $codesPath -Raw
                $weaponMagazineMap = @{}
                foreach ($match in [regex]::Matches($generatedMap, 'AWCWF_WeaponMagazineType\["([^"]+)"\]\s*=\s*\{([^}]*)\}')) {
                    $magazines = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    foreach ($value in [regex]::Matches($match.Groups[2].Value, '"([^"]+)"')) {
                        $null = $magazines.Add($value.Groups[1].Value)
                    }
                    $weaponMagazineMap[$match.Groups[1].Value] = $magazines
                }

                $aliasBlock = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.magazineMapAliases\s*=\s*\{'
                foreach ($match in [regex]::Matches([string]$aliasBlock, '\{\s*from\s*=\s*"([^"]+)",\s*to\s*=\s*"([^"]+)"\s*\}')) {
                    $source = $match.Groups[1].Value
                    $target = $match.Groups[2].Value
                    if (-not $weaponMagazineMap.ContainsKey($target)) {
                        $weaponMagazineMap[$target] = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    }
                    if ($weaponMagazineMap.ContainsKey($source)) {
                        foreach ($magazine in $weaponMagazineMap[$source]) { $null = $weaponMagazineMap[$target].Add($magazine) }
                        $weaponMagazineMap.Remove($source)
                    }
                }

                $removalBlock = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.magazineMapRemovals\s*=\s*\{'
                foreach ($match in [regex]::Matches([string]$removalBlock, '"([^"]+)"')) {
                    $weaponMagazineMap.Remove($match.Groups[1].Value)
                }

                $unionBlock = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.magazineMapUnions\s*=\s*\{'
                foreach ($match in [regex]::Matches([string]$unionBlock, '(?m)^\s*(?:\["([^"]+)"\]|([\w.-]+))\s*=\s*\{([^}]*)\}')) {
                    $weaponType = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                    if (-not $weaponMagazineMap.ContainsKey($weaponType)) {
                        $weaponMagazineMap[$weaponType] = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    }
                    foreach ($value in [regex]::Matches($match.Groups[3].Value, '"([^"]+)"')) {
                        $null = $weaponMagazineMap[$weaponType].Add($value.Groups[1].Value)
                    }
                }

                $familyBlock = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.magazineFamilyExpansions\s*=\s*\{'
                foreach ($family in [regex]::Matches([string]$familyBlock, '(?ms)\{\s*markers\s*=\s*\{([^}]*)\},\s*magazines\s*=\s*\{([^}]*)\}')) {
                    $markers = @([regex]::Matches($family.Groups[1].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
                    $familyMagazines = @([regex]::Matches($family.Groups[2].Value, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
                    foreach ($weaponType in @($weaponMagazineMap.Keys)) {
                        $matchesFamily = @($markers | Where-Object { $weaponMagazineMap[$weaponType].Contains($_) }).Count -gt 0
                        if ($matchesFamily) {
                            foreach ($magazineType in $familyMagazines) { $null = $weaponMagazineMap[$weaponType].Add($magazineType) }
                        }
                    }
                }

                foreach ($expectation in @{
                    AssaultRifle = @('556Clip', '556Drum_60rnd', '556Drum_100rnd')
                    CZ805 = @('556Clip', '556Drum_60rnd', '556Drum_100rnd')
                    MP5 = @('9mmClip', '9mmClip30', '9mmDrum50', '9mmDrum75', '9mmDrum100')
                    MP5K = @('9mmClip', '9mmClip30', '9mmDrum50', '9mmDrum75', '9mmDrum100')
                    MP5SD = @('9mmClip', '9mmClip30', '9mmDrum50', '9mmDrum75', '9mmDrum100')
                }.GetEnumerator()) {
                    if (-not $weaponMagazineMap.ContainsKey($expectation.Key)) {
                        $failures.Add("Expected weapon magazine map is missing: Base.$($expectation.Key)")
                        continue
                    }
                    foreach ($magazineType in $expectation.Value) {
                        if (-not $weaponMagazineMap[$expectation.Key].Contains($magazineType)) {
                            $failures.Add("Expected compatible magazine is missing: Base.$($expectation.Key) -> Base.$magazineType")
                        }
                    }
                }

                $magazinePartMap = @{}
                foreach ($match in [regex]::Matches($codes, 'AWCWF_MagazineTypeToPart\["([^"]+)"\]\s*=\s*"([^"]+)"')) {
                    $magazinePartMap[$match.Groups[1].Value] = $match.Groups[2].Value
                }
                $partPatchBlock = Get-BracedBlock -Text $definitions -Pattern 'Definitions\.magazinePartPatches\s*=\s*\{'
                foreach ($match in [regex]::Matches([string]$partPatchBlock, '(?m)^\s*(?:\["([^"]+)"\]|([\w.-]+))\s*=\s*"([^"]+)"\s*,')) {
                    $magazineType = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
                    $magazinePartMap[$magazineType] = $match.Groups[3].Value
                }
                $magazinesByPart = @{}
                foreach ($magazineType in $magazinePartMap.Keys) {
                    $fullType = 'Base.' + $magazineType
                    if (-not $feedDevices.Contains($fullType)) { continue }
                    $partType = $magazinePartMap[$magazineType]
                    if (-not $magazinesByPart.ContainsKey($partType)) {
                        $magazinesByPart[$partType] = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    }
                    $null = $magazinesByPart[$partType].Add($magazineType)
                }

                foreach ($weaponType in $weaponMagazineMap.Keys) {
                    $weaponBlock = Get-BracedBlock -Text $effectiveItemText -Pattern ("item\s+{0}\s*\{{" -f [regex]::Escape($weaponType))
                    if ($null -eq $weaponBlock) { continue }
                    $allowed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                    foreach ($magazineType in $weaponMagazineMap[$weaponType]) { $null = $allowed.Add($magazineType) }
                    $staticMagazine = [regex]::Match($weaponBlock, '(?m)^\s*MagazineType\s*=\s*(?:Base\.)?([\w.-]+)\s*,')
                    if ($staticMagazine.Success) { $null = $allowed.Add($staticMagazine.Groups[1].Value) }

                    foreach ($visual in [regex]::Matches($weaponBlock, '(?m)^\s*ModelWeaponPart\s*=\s*(\S+)\s+\S+\s+Clip\s+Clip\s*,')) {
                        $partType = $visual.Groups[1].Value
                        if (-not $partType.Contains('.')) { $partType = 'Base.' + $partType }
                        if (-not $magazinesByPart.ContainsKey($partType)) { continue }
                        foreach ($magazineType in $magazinesByPart[$partType]) {
                            if (-not $allowed.Contains($magazineType)) {
                                $failures.Add("Magazine visual is not represented in the effective allow-list: Base.$weaponType -> Base.$magazineType")
                            }
                        }
                    }
                }
            }
            else { Write-Warning 'Gael magazine-map sources were not found; skipped visual-to-functional compatibility checks.' }

            foreach ($recipe in $packageRecipes) {
                if (-not $recipe.StartsWith('GGSASF_') -and -not $upstreamRecipes.Contains($recipe)) {
                    $failures.Add("Installed upstream is missing recipe: $recipe")
                }
            }
            foreach ($item in $packageItems) {
                $recipe = $packageRecipeByItem[$item]
                $recipeSource = if ($recipe.StartsWith('GGSASF_')) { $recipes } else { $upstreamText }
                $recipeBlock = Get-BracedBlock -Text $recipeSource -Pattern ("craftRecipe\s+{0}\s*\{{" -f [regex]::Escape($recipe))
                if ($null -ne $recipeBlock) {
                    $output = [regex]::Match($recipeBlock, 'outputs\s*\{\s*item\s+(\d+)\s+', [Text.RegularExpressions.RegexOptions]::Singleline)
                    if (-not $output.Success -or [int]$output.Groups[1].Value -ne $packageRoundCounts[$item]) {
                        $failures.Add("Recipe output does not match configured package count for $item ($recipe).")
                    }
                }
            }
        }
        else { Write-Warning 'GaelGunStore Workshop payload was not found; skipped installed-upstream checks.' }
    }
    catch { $failures.Add("Installed-upstream validation failed: $($_.Exception.Message) at $($_.ScriptStackTrace)") }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Gael ammo patch validation passed ($($packageItems.Count) packages, $($feedDevices.Count) feed devices, $($cartons.Count) cartons, $($customRecipeNames.Count) custom recipes)."
