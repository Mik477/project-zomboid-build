[CmdletBinding(SupportsShouldProcess)]
param([string]$LocalConfigurationPath)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $LocalConfigurationPath) { $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json' }
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$gameRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$userPath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.userPath)
$modsRoot = Join-Path $userPath 'mods'
$obsoleteModDirectories = @(
    'GaelGunStoreAmmoStorageFixes',
    'ModpackCompatibilityFixes',
    'PZPerformanceFixes'
)
$obsoleteCompactFiles = @(
    'CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\GaelFirearmTetrisSizes.lua',
    'CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\InventoryDiagnostics.lua',
    'CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\InventoryDiagnosticsCore.lua',
    'CompactProximityInventory\42.20\media\lua\client\CompactProximityInventory\Tests\GaelFirearmTetrisSizesTests.lua'
)
$replacementModDirectories = @(
    'CompactProximityInventory',
    'GaelGunStoreInventoryTetrisCompatibility',
    'InventoryTetrisTransferDiagnostics',
    'TYLIndoorBushFix',
    'PZExporterCadenceTuning',
    'KnownAndCollectedInventoryTetrisCompatibility',
    'VASRemoteDoorSyncFix',
    'GaelGunStoreCoreFixes',
    'GaelGunStoreLootDiversification',
    'ItemVisualCompatibilityFixes',
    'TrashAndCorpsesSafetyFix',
    'SecretZCommandRegistrationFix'
)
$expectedGeneratedJarHashes = @{
    TrashAndCorpsesSafetyFix = '84B174AB483834A265EEC26A714AEEF3F9E08436F2076E7F72409F3350E5599F'
    SecretZCommandRegistrationFix = '7FDD6A647033894DBE75F0077862B71BFD080FF82FF1552F8E1E132C2AD0D265'
}

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

$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    if ($_.ProcessName -like 'ProjectZomboid*') { return $true }
    try {
        return $_.Path -and [IO.Path]::GetFullPath($_.Path).StartsWith(
            $gameRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)
    }
    catch { return $false }
})
if ($runningProcesses.Count -gt 0) {
    throw 'Project Zomboid or its hosted server is running. Stop it before migrating patch mods.'
}

$existingDirectories = @($obsoleteModDirectories | Where-Object {
    Test-Path -LiteralPath (Join-Path $modsRoot $_) -PathType Container
})
$existingCompactFiles = @($obsoleteCompactFiles | Where-Object {
    Test-Path -LiteralPath (Join-Path $modsRoot $_) -PathType Leaf
})
if ($existingDirectories.Count -eq 0 -and $existingCompactFiles.Count -eq 0) {
    Write-Output 'No obsolete patch-mod directories or files are installed.'
    return
}

$replacementProblems = [Collections.Generic.List[string]]::new()
foreach ($modDirectory in $replacementModDirectories) {
    $sourceModRoot = Join-Path $repositoryRoot ("src\mods\{0}" -f $modDirectory)
    $installedModRoot = Join-Path $modsRoot $modDirectory
    foreach ($sourceFile in Get-ChildItem -LiteralPath $sourceModRoot -Recurse -File) {
        $relativePath = Get-RelativeFilePath -BasePath $sourceModRoot -Path $sourceFile.FullName
        $installedPath = Join-Path $installedModRoot $relativePath
        if (-not (Test-Path -LiteralPath $installedPath -PathType Leaf)) {
            $replacementProblems.Add("$modDirectory missing $relativePath")
            break
        }
        $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
        $installedHash = (Get-FileHash -LiteralPath $installedPath -Algorithm SHA256).Hash
        if ($installedHash -ne $sourceHash) {
            $replacementProblems.Add("$modDirectory differs at $relativePath")
            break
        }
    }
}
foreach ($patchId in $expectedGeneratedJarHashes.Keys) {
    $jarPath = Join-Path $modsRoot ("{0}\42.20\media\java\common\{0}.jar" -f $patchId)
    if (-not (Test-Path -LiteralPath $jarPath -PathType Leaf)) {
        $replacementProblems.Add("$patchId is missing its generated common JAR")
        continue
    }
    $jarHash = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash
    if ($jarHash -ne $expectedGeneratedJarHashes[$patchId]) {
        $replacementProblems.Add("$patchId common JAR has unexpected SHA-256 $jarHash")
    }
}
if ($replacementProblems.Count -gt 0) {
    throw "Install the exact replacement package before retiring old patches: $($replacementProblems -join '; ')"
}

$backupRoot = Join-Path $userPath ('Backups\project-zomboid-build\patch-layout-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($modDirectory in $existingDirectories) {
    $source = Join-Path $modsRoot $modDirectory
    if (-not $PSCmdlet.ShouldProcess($source, 'Back up and remove obsolete patch-mod directory')) { continue }
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination (Join-Path $backupRoot $modDirectory) -Recurse -Force
    Remove-Item -LiteralPath $source -Recurse -Force
    Write-Output "Backed up and removed obsolete mod directory: $modDirectory"
}
foreach ($relativePath in $existingCompactFiles) {
    $source = Join-Path $modsRoot $relativePath
    if (-not $PSCmdlet.ShouldProcess($source, 'Back up and remove obsolete Compact Proximity Inventory file')) { continue }
    $backupPath = Join-Path $backupRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $backupPath -Force
    Remove-Item -LiteralPath $source -Force
    Write-Output "Backed up and removed obsolete Compact file: $relativePath"
}

Write-Output "Patch-layout backup: $backupRoot"
Write-Output 'Apply the new manifest and fully restart every client and host before loading a shared world.'
