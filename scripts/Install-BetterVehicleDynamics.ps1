[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$LocalConfigurationPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $LocalConfigurationPath) {
    $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json'
}
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$modpack = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
$localVersion = [string]$localConfiguration.projectZomboid.exactGameVersion
$manifestVersion = [string]$modpack.compatibility.exactGameVersion
$localBuildId = [string]$localConfiguration.steam.buildId
$manifestBuildId = [string]$modpack.compatibility.steamBuildId

if ($localVersion -ne $manifestVersion -or $localBuildId -ne $manifestBuildId) {
    throw "BVD installation is version-gated. Local version/build $localVersion/$localBuildId does not match manifest $manifestVersion/$manifestBuildId."
}
if ($localVersion -notmatch '^42\.20(?:\.|$)') {
    throw "The installed BVD overlay is for Project Zomboid 42.20, not $localVersion."
}

$gameRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$sourceRoot = Join-Path $workshopRoot '3728775267\mods\BetterVehicleDynamics\B42.20_Manual_Install\zombie'
$targetRoot = Join-Path $gameRoot 'zombie'

if (-not (Test-Path -LiteralPath $gameRoot -PathType Container)) {
    throw 'The discovered Project Zomboid game directory does not exist.'
}
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw 'The Better Vehicle Dynamics B42.20 manual-install payload is missing. Let Steam finish downloading Workshop item 3728775267.'
}

$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    if ($_.ProcessName -like 'ProjectZomboid*') { return $true }
    try {
        return $_.Path -and [IO.Path]::GetFullPath($_.Path).StartsWith($gameRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
})
if ($runningProcesses.Count -gt 0) {
    throw 'Project Zomboid or its hosted server is running. Stop it before installing the BVD Java overlay.'
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

function Assert-ChildPath {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Path
    )

    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its intended root: $resolvedPath"
    }
}

$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -File -Recurse -Force)
if ($sourceFiles.Count -eq 0) {
    throw 'The BVD manual-install payload contains no files.'
}
$unexpectedFiles = @($sourceFiles | Where-Object Extension -ne '.class')
if ($unexpectedFiles.Count -gt 0) {
    throw 'The BVD manual-install payload contains an unexpected non-class file; review the Workshop update before installing it.'
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) "Backups\project-zomboid-build\bvd-$timestamp"
$records = [Collections.Generic.List[object]]::new()
$copyCount = 0
$replaceCount = 0

foreach ($sourceFile in $sourceFiles) {
    $relativePath = Get-RelativeFilePath -BasePath $sourceRoot -Path $sourceFile.FullName
    $destinationPath = Join-Path $targetRoot $relativePath
    Assert-ChildPath -Root $targetRoot -Path $destinationPath
    $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    $destinationExisted = Test-Path -LiteralPath $destinationPath -PathType Leaf
    $destinationHash = if ($destinationExisted) {
        (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    else {
        $null
    }
    $needsCopy = $sourceHash -ne $destinationHash
    $backupRelativePath = $null

    if ($needsCopy -and $PSCmdlet.ShouldProcess($destinationPath, 'Install Better Vehicle Dynamics Java class')) {
        if ($destinationExisted) {
            $backupRelativePath = Join-Path 'replaced' $relativePath
            $backupPath = Join-Path $backupRoot $backupRelativePath
            Assert-ChildPath -Root $backupRoot -Path $backupPath
            New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
            Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
            $replaceCount++
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationPath -Force
        $installedHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($installedHash -ne $sourceHash) {
            throw "BVD verification failed after copying $relativePath."
        }
        $copyCount++
    }

    $records.Add([pscustomobject]@{
        path = $relativePath.Replace('\', '/')
        sourceSha256 = $sourceHash
        existedBefore = $destinationExisted
        previousSha256 = $destinationHash
        backupPath = if ($backupRelativePath) { $backupRelativePath.Replace('\', '/') } else { $null }
        changed = $needsCopy
    })
}

if ($copyCount -gt 0) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    [pscustomobject]@{
        schemaVersion = 1
        installedAt = (Get-Date).ToString('o')
        workshopItemId = '3728775267'
        gameVersion = $localVersion
        steamBuildId = $localBuildId
        destination = 'ProjectZomboid/zombie'
        files = @($records)
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupRoot 'install-manifest.json') -Encoding utf8
}

[pscustomobject]@{
    SourceFiles = $sourceFiles.Count
    InstalledOrUpdated = $copyCount
    ReplacedAndBackedUp = $replaceCount
    AlreadyCurrent = $sourceFiles.Count - @($records | Where-Object changed).Count
    BackupManifest = if ($copyCount -gt 0) { Join-Path $backupRoot 'install-manifest.json' } else { $null }
}
