[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()

function Get-RelativeFilePath {
    param(
        [Parameter(Mandatory)] [string]$BasePath,
        [Parameter(Mandatory)] [string]$Path
    )

    $baseFullPath = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $baseUri = [Uri]$baseFullPath
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [IO.Path]::DirectorySeparatorChar)
}

$requiredPaths = @(
    'README.md',
    'AGENTS.md',
    'config\modpack.json',
    'config\modpack.schema.json',
    'config\local.example.json',
    'docs\LOCAL-WORKFLOW.md',
    'docs\PATCH-MOD-LAYOUT.md',
    'docs\JAVA-COMPATIBILITY-PATCHES.md',
    'docs\GAEL-GUN-STORE-PATCHES.md',
    'docs\PZ-PERFORMANCE-DIAGNOSTICS.md',
    'scripts\Build-Package.ps1',
    'scripts\Apply-ModpackToLocalProfile.ps1',
    'scripts\Apply-ModpackToLocalClient.ps1',
    'scripts\Install-Package.ps1',
    'scripts\Initialize-LocalEnvironment.ps1',
    'scripts\Export-LocalModpack.ps1',
    'scripts\Install-BetterVehicleDynamics.ps1',
    'scripts\Build-MultiplayerRagdollPrototype.ps1',
    'scripts\Test-MultiplayerRagdollPrototype.ps1',
    'scripts\Test-GaelGunStorePatches.ps1',
    'scripts\Install-MultiplayerRagdollPrototype.ps1',
    'scripts\Build-PZPerformanceDiagnostics.ps1',
    'scripts\Test-PZPerformanceDiagnostics.ps1',
    'scripts\Build-CompatibilityPatch.ps1',
    'scripts\Test-CompatibilityPatches.ps1',
    'scripts\Install-CompatibilityPatches.ps1',
    'scripts\Test-LuaPatchMods.ps1',
    'scripts\Migrate-PatchModLayout.ps1',
    'scripts\Install-PZPerformanceDiagnostics.ps1',
    'scripts\Summarize-PZPerformanceDiagnostics.ps1',
    'scripts\Sync-ManagedFiles.ps1',
    'src\mods',
    'src\mods\GaelGunStoreCoreFixes\42.20\mod.info',
    'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\shared\GaelGunStoreCoreFixes\Definitions.lua',
    'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\shared\GaelGunStoreCoreFixes\ScriptPatches.lua',
    'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\client\GaelGunStoreCoreFixes\AutomaticMagazineSelection.lua',
    'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\client\GaelGunStoreCoreFixes\MagazineCompatibility.lua',
    'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\server\GaelGunStoreCoreFixes\ContainerCompatibility.lua',
    'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\server\GaelGunStoreCoreFixes\LootCompatibility.lua',
    'src\mods\GaelGunStoreLootDiversification\42.20\mod.info',
    'src\mods\GaelGunStoreLootDiversification\42.20\media\lua\shared\GaelGunStoreLootDiversification\Definitions.lua',
    'src\mods\GaelGunStoreLootDiversification\42.20\media\lua\shared\GaelGunStoreLootDiversification\FirearmSpawnDiversification.lua',
    'src\mods\GaelGunStoreLootDiversification\42.20\media\lua\server\GaelGunStoreLootDiversification\ApplyFirearmSpawnDiversification.lua',
    'src\mods\ItemVisualCompatibilityFixes\42.20\mod.info',
    'src\mods\ItemVisualCompatibilityFixes\42.20\media\lua\shared\ItemVisualCompatibilityFixes.lua',
    'src\mods\CompactProximityInventory\42.20\mod.info',
    'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\CompactRows.lua',
    'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\CompactProximityInventory.lua',
    'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\SelectionGuard.lua',
    'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\SelectionPolicy.lua',
    'tests\InventoryDiagnosticsCore.test.lua',
    'tests\InventoryDiagnosticsRuntime.test.lua',
    'tests\CompactCraftContainerFilter.test.lua',
    'tests\GaelVanillaSequentialUnpack.test.lua',
    'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\NearbyContainers.lua',
    'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\Tests\NearbyContainersTests.lua',
    'src\mods\GaelGunStoreInventoryTetrisCompatibility\42.20\mod.info',
    'src\mods\GaelGunStoreInventoryTetrisCompatibility\42.20\media\lua\client\GaelGunStoreInventoryTetrisCompatibility\GaelFirearmTetrisSizes.lua',
    'src\mods\InventoryTetrisTransferDiagnostics\42.20\mod.info',
    'src\mods\InventoryTetrisTransferDiagnostics\42.20\media\lua\client\InventoryTetrisTransferDiagnostics\InventoryDiagnostics.lua',
    'src\mods\InventoryTetrisTransferDiagnostics\42.20\media\lua\client\InventoryTetrisTransferDiagnostics\InventoryDiagnosticsCore.lua',
    'src\mods\MultiplayerRagdollPrototype\42.20\mod.info',
    'src\mods\MultiplayerRagdollPrototype\42.20\media\java-src\pzmod\mpragdollprototype\MultiplayerRagdollPatches.java',
    'src\mods\PZPerformanceDiagnostics\42.20\mod.info',
    'src\mods\PZPerformanceDiagnostics\42.20\media\java-src\pzmod\performance\PerformanceDiagnosticsPatches.java',
    'src\mods\PZPerformanceDiagnostics\42.20\media\java-src\pzmod\performance\PerformanceDiagnosticsRuntime.java',
    'src\mods\PZPerformanceDiagnostics\42.20\media\lua\client\PZPerformanceDiagnostics.lua',
    'src\mods\PZPerformanceDiagnostics\42.20\media\lua\client\PZPerformanceDiagnostics\Bootstrap.lua',
    'src\mods\TrashAndCorpsesSafetyFix\42.20\mod.info',
    'src\mods\SecretZCommandRegistrationFix\42.20\mod.info',
    'src\mods\TYLIndoorBushFix\42.20\mod.info',
    'src\mods\PZExporterCadenceTuning\42.20\mod.info',
    'src\mods\KnownAndCollectedInventoryTetrisCompatibility\42.20\mod.info',
    'src\mods\VASRemoteDoorSyncFix\42.20\mod.info',
    'src\game-overrides'
)

foreach ($relativePath in $requiredPaths) {
    if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot $relativePath))) {
        $failures.Add("Missing required path: $relativePath")
    }
}
$ignoredRequiredPaths = @($requiredPaths | & git -C $repositoryRoot check-ignore --no-index --stdin)
foreach ($ignoredRequiredPath in $ignoredRequiredPaths) {
    $failures.Add("Required path is ignored by Git: $ignoredRequiredPath")
}

try {
    $manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 1) { $failures.Add('Unsupported schemaVersion in config/modpack.json') }
    if ($manifest.package.version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { $failures.Add('Package version is not semantic.') }
    if ($manifest.compatibility.exactGameVersion -eq 'UNSET') { Write-Warning 'Set compatibility.exactGameVersion before the first playable release.' }
    if ($manifest.compatibility.exactGameVersion -eq 'UNKNOWN') { $failures.Add('compatibility.exactGameVersion must be known for a portable build.') }
    if ($manifest.compatibility.exactGameVersion -notmatch '^\d+\.\d+(?:\.\d+)?$') { $failures.Add('compatibility.exactGameVersion is not an exact numeric version.') }
    if ($manifest.compatibility.steamBuildId -notmatch '^\d+$') { $failures.Add('compatibility.steamBuildId must contain only digits.') }
    if ($manifest.workshop.revision -notmatch '^sha256:[0-9a-f]{64}$') { $failures.Add('workshop.revision must be a SHA-256 fingerprint.') }
    foreach ($workshopItemId in $manifest.workshop.itemIds) {
        if ($workshopItemId -notmatch '^\d+$') { $failures.Add("Invalid Workshop item ID: $workshopItemId") }
    }
    foreach ($propertyName in @('itemIds', 'modIds', 'maps')) {
        $values = @($manifest.workshop.$propertyName)
        $duplicateValues = @($values | Group-Object | Where-Object Count -gt 1)
        if ($duplicateValues.Count -gt 0) { $failures.Add("Duplicate values in workshop.$propertyName") }
    }
    foreach ($obsoleteModId in @('ModpackCompatibilityFixes', 'PZPerformanceFixes', 'GaelGunStoreAmmoStorageFixes', 'InventoryTetrisTransferDiagnostics', 'MWPSelfImportLogFix')) {
        if (@($manifest.workshop.modIds) -contains $obsoleteModId) {
            $failures.Add("Disabled or retired patch mod must not be in workshop.modIds: $obsoleteModId")
        }
    }
    if (@($manifest.workshop.itemIds) -contains '3374408921' -or @($manifest.workshop.modIds) -contains 'efficiencySkillMod2') {
        $failures.Add('Efficiency Skill Mod 2 must remain removed from the manifest.')
    }
    if (@($manifest.workshop.itemIds) -notcontains '3781486512' -or @($manifest.workshop.modIds) -notcontains 'TYL_B42_STABLE_UNOFFICIAL') {
        $failures.Add('TYL must remain enabled in the manifest.')
    }
    if (@($manifest.workshop.modIds) -notcontains 'CompactProximityInventory') {
        $failures.Add('The repo-owned CompactProximityInventory mod is missing from workshop.modIds.')
    }
    $tetrisIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'INVENTORY_TETRIS')
    $compactProximityIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'CompactProximityInventory')
    if ($tetrisIndex -lt 0 -or $compactProximityIndex -ne ($tetrisIndex + 1)) {
        $failures.Add('CompactProximityInventory must load immediately after INVENTORY_TETRIS.')
    }
    $gaelTetrisIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'GaelGunStoreInventoryTetrisCompatibility')
    if ($gaelTetrisIndex -ne ($compactProximityIndex + 1)) {
        $failures.Add('GaelGunStoreInventoryTetrisCompatibility must load immediately after CompactProximityInventory.')
    }
    $gaelIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'GaelGunStore_B42')
    $gaelCoreIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'GaelGunStoreCoreFixes')
    $gaelLootIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'GaelGunStoreLootDiversification')
    if ($gaelIndex -lt 0 -or $gaelCoreIndex -ne ($gaelIndex + 1) -or $gaelLootIndex -ne ($gaelCoreIndex + 1)) {
        $failures.Add('GaelGunStoreCoreFixes and GaelGunStoreLootDiversification must load immediately after GaelGunStore_B42, in that order.')
    }
    if (@($manifest.workshop.itemIds) -contains '3669616334') {
        $failures.Add('The removed third-party GaelGunStore patch must not be enabled alongside the repo-owned patch.')
    }
    $diagnosticsIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), 'PZPerformanceDiagnostics')
    if ($diagnosticsIndex -ne (@($manifest.workshop.modIds).Count - 1)) {
        $failures.Add('PZPerformanceDiagnostics must load last so it observes the final vehicle and timed-action wrappers.')
    }
    foreach ($pair in @(
        @{ Target = 'Secretz42'; Patch = 'SecretZCommandRegistrationFix' },
        @{ Target = 'PZ_Pulse'; Patch = 'PZExporterCadenceTuning' },
        @{ Target = 'TrashAndCorpses'; Patch = 'TrashAndCorpsesSafetyFix' },
        @{ Target = 'TYL_B42_STABLE_UNOFFICIAL'; Patch = 'TYLIndoorBushFix' },
        @{ Target = 'VASinked'; Patch = 'VASRemoteDoorSyncFix' },
        @{ Target = 'KnownAndCollected'; Patch = 'KnownAndCollectedInventoryTetrisCompatibility' },
        @{ Target = 'HNDLBR_Preppers'; Patch = 'ItemVisualCompatibilityFixes' }
    )) {
        $targetIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), $pair.Target)
        $patchIndex = [Array]::IndexOf([object[]]@($manifest.workshop.modIds), $pair.Patch)
        if ($targetIndex -lt 0 -or $patchIndex -ne ($targetIndex + 1)) {
            $failures.Add("$($pair.Patch) must load immediately after $($pair.Target).")
        }
    }
    if (@($manifest.workshop.modIds) -contains 'ETO_B' -or @($manifest.workshop.modIds) -notcontains 'ETO_P') {
        $failures.Add('The performance profile must retain only ETO_P, not the redundant ETO_B variant.')
    }
    foreach ($requiredItem in @('3077900375','2881764317','3252451158','2896041179','2366717227')) {
        if (@($manifest.workshop.itemIds) -notcontains $requiredItem) { $failures.Add("Missing reconciled Workshop dependency: $requiredItem") }
    }
    foreach ($requiredMod in @('ChuckleberryFinnAlertSystem','KnownAndCollected','HNDLBR_Preppers','errorMagnifier','SwapIt')) {
        if (@($manifest.workshop.modIds) -notcontains $requiredMod) { $failures.Add("Missing reconciled mod dependency: $requiredMod") }
    }
    $revisionInput = "WorkshopItems=$(@($manifest.workshop.itemIds) -join ';')`nMods=$(@($manifest.workshop.modIds) -join ';')`nMap=$(@($manifest.workshop.maps) -join ';')"
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $revisionBytes = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($revisionInput))
    }
    finally {
        $sha256.Dispose()
    }
    $expectedRevision = 'sha256:' + (($revisionBytes | ForEach-Object { $_.ToString('x2') }) -join '')
    if ($manifest.workshop.revision -ne $expectedRevision) { $failures.Add('workshop.revision does not match the ordered item IDs, mod IDs, and maps.') }
}
catch {
    $failures.Add("Invalid config/modpack.json: $($_.Exception.Message)")
}

$localConfigurationPath = Join-Path $repositoryRoot 'config\local.json'
if (Test-Path -LiteralPath $localConfigurationPath -PathType Leaf) {
    & git -C $repositoryRoot check-ignore --quiet -- 'config/local.json'
    if ($LASTEXITCODE -ne 0) {
        $failures.Add('config/local.json exists but is not ignored by Git.')
    }
}

$trackedPaths = @(& git -C $repositoryRoot ls-files)
foreach ($forbiddenTrackedPath in @('config/local.json', 'server/private/')) {
    if (@($trackedPaths | Where-Object { $_ -eq $forbiddenTrackedPath -or $_.StartsWith($forbiddenTrackedPath) }).Count -gt 0) {
        $failures.Add("Forbidden local/private path is tracked: $forbiddenTrackedPath")
    }
}

$scriptFiles = Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'scripts') -Filter '*.ps1' -File
foreach ($scriptFile in $scriptFiles) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($scriptFile.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($parseError in $parseErrors) {
        $failures.Add("PowerShell syntax error in $($scriptFile.Name): $($parseError.Message)")
    }
}

try {
    & (Join-Path $PSScriptRoot 'Test-GaelGunStorePatches.ps1')
}
catch {
    $failures.Add("Gael ammo patch validation failed: $($_.Exception.Message)")
}

try {
    & (Join-Path $PSScriptRoot 'Test-CompatibilityPatches.ps1')
}
catch {
    $failures.Add("Modpack compatibility validation failed: $($_.Exception.Message)")
}

try {
    & (Join-Path $PSScriptRoot 'Test-PZPerformanceDiagnostics.ps1')
}
catch {
    $failures.Add("PZ performance diagnostics validation failed: $($_.Exception.Message)")
}

try {
    & (Join-Path $PSScriptRoot 'Test-LuaPatchMods.ps1')
}
catch {
    $failures.Add("PZ performance fixes validation failed: $($_.Exception.Message)")
}

$inventoryDiagnosticsPath = Join-Path $repositoryRoot 'src\mods\InventoryTetrisTransferDiagnostics\42.20\media\lua\client\InventoryTetrisTransferDiagnostics\InventoryDiagnostics.lua'
if (Test-Path -LiteralPath $inventoryDiagnosticsPath -PathType Leaf) {
    $inventoryDiagnosticsSource = Get-Content -LiteralPath $inventoryDiagnosticsPath -Raw
    if (-not $inventoryDiagnosticsSource.Contains('version = "0.1.0"')) {
        $failures.Add('Inventory Tetris Transfer Diagnostics must report the current mod version 0.1.0.')
    }
}

$gaelTetrisSizesPath = Join-Path $repositoryRoot 'src\mods\GaelGunStoreInventoryTetrisCompatibility\42.20\media\lua\client\GaelGunStoreInventoryTetrisCompatibility\GaelFirearmTetrisSizes.lua'
$gaelTetrisModInfoPath = Join-Path $repositoryRoot 'src\mods\GaelGunStoreInventoryTetrisCompatibility\42.20\mod.info'
if (Test-Path -LiteralPath $gaelTetrisModInfoPath -PathType Leaf) {
    $gaelTetrisModInfo = Get-Content -LiteralPath $gaelTetrisModInfoPath -Raw
    if (-not $gaelTetrisModInfo.Contains('require=INVENTORY_TETRIS,GaelGunStore_B42')) {
        $failures.Add('Gael Gun Store Inventory Tetris compatibility must require both target mods.')
    }
}
if (Test-Path -LiteralPath $gaelTetrisSizesPath -PathType Leaf) {
    $gaelTetrisSizesSource = Get-Content -LiteralPath $gaelTetrisSizesPath -Raw
    foreach ($requiredExpression in @(
        'function Module.getUnrotatedSize',
        'function Module.applySizePolicy',
        'function Module.buildRenderDataOverlay',
        'function Module.correctRenderInstructions',
        'TetrisItemData._getItemData = wrapper',
        'ItemGridUI.renderStackLoop = wrapper',
        'ItemGridUI._bulkRenderGridStacks = wrapper',
        'ammoType:find("arrow", 1, true)',
        'ammoType:find("bolt", 1, true)',
        'pistol", 2, 1',
        'large", 4, 2',
        'compact", 2, 2',
        'standard", 3, 2',
        'getWeaponPart", nil, "Stock"',
        'stocklessPartTokens',
        'extendedStockTokens',
        'pendingPolicyReflowByItem',
        'reflowExpandedWeapon',
        'ItemContainerGrid.GetOrCreate',
        'ISUpgradeWeapon.complete',
        'ISRemoveWeaponUpgrade.complete',
        'refreshItemGrids(true)',
        '[GaelFirearmTetris] session='
    )) {
        if (-not $gaelTetrisSizesSource.Contains($requiredExpression)) {
            $failures.Add("Gael firearm Tetris sizing is missing: $requiredExpression")
        }
    }
}

$gaelTetrisTestsPath = Join-Path $repositoryRoot 'src\mods\GaelGunStoreInventoryTetrisCompatibility\42.20\media\lua\client\GaelGunStoreInventoryTetrisCompatibility\Tests\GaelFirearmTetrisSizesTests.lua'
if (Test-Path -LiteralPath $gaelTetrisTestsPath -PathType Leaf) {
    $gaelTetrisTestsSource = Get-Content -LiteralPath $gaelTetrisTestsPath -Raw
    foreach ($requiredExpression in @(
        'test_render_instructions_override_stale_weight_sizes',
        'test_render_instruction_rotation_and_instance_stock_state',
        'test_stock_slot_grips_do_not_extend_compact_weapons',
        'test_render_overlay_prevents_stale_dimension_culling',
        'test_non_firearm_render_instruction_is_untouched',
        'test_install_is_idempotent'
    )) {
        if (-not $gaelTetrisTestsSource.Contains($requiredExpression)) {
            $failures.Add("Gael firearm Tetris regression is missing: $requiredExpression")
        }
    }
}

$nearbyContainersPath = Join-Path $repositoryRoot 'src\mods\CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\NearbyContainers.lua'
if (Test-Path -LiteralPath $nearbyContainersPath -PathType Leaf) {
    $nearbyContainersSource = Get-Content -LiteralPath $nearbyContainersPath -Raw
    foreach ($requiredExpression in @(
        'NearbyContainers.filterCraftContainers',
        'not NearbyContainers.isMarker(container)',
        'ISInventoryPaneContextMenu.getContainers = function(character)',
        'CompactProximityInventoryCraftContainerFilterApplied'
    )) {
        if (-not $nearbyContainersSource.Contains($requiredExpression)) {
            $failures.Add("Compact crafting-container filter is missing: $requiredExpression")
        }
    }
}

$forbiddenExtensions = @('.class', '.dll', '.exe', '.jar', '.pdb', '.sqlite', '.sqlite3')
$forbiddenFiles = Get-ChildItem -LiteralPath $repositoryRoot -File -Recurse -Force |
    Where-Object {
        $_.FullName -notlike "$(Join-Path $repositoryRoot '.git')*" -and
        $_.FullName -notlike "$(Join-Path $repositoryRoot 'dist')*" -and
        $forbiddenExtensions -contains $_.Extension.ToLowerInvariant()
    }
foreach ($forbiddenFile in $forbiddenFiles) {
    $relativeForbiddenPath = Get-RelativeFilePath -BasePath $repositoryRoot -Path $forbiddenFile.FullName
    $failures.Add("Forbidden binary/database file: $relativeForbiddenPath")
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'Project validation passed.'
