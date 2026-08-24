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
$serverProfilePath = $localConfiguration.projectZomboid.serverProfilePath
if (-not $serverProfilePath -or -not (Test-Path -LiteralPath $serverProfilePath -PathType Leaf)) {
    throw 'The selected local server profile is missing. Rerun initialization with -ServerProfilePath.'
}

# Server profiles contain secrets. Read only this explicit public allowlist.
$publicSettings = @{}
foreach ($line in Get-Content -LiteralPath $serverProfilePath) {
    if ($line -match '^\s*(WorkshopItems|Mods|Map)\s*=\s*(.*)$') {
        $publicSettings[$matches[1]] = $matches[2].Trim()
    }
}
foreach ($requiredSetting in @('WorkshopItems', 'Mods', 'Map')) {
    if (-not $publicSettings.ContainsKey($requiredSetting)) {
        throw "The selected server profile has no $requiredSetting setting."
    }
}

$workshopItemIds = @($publicSettings.WorkshopItems -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$modIds = @($publicSettings.Mods -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$maps = @($publicSettings.Map -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
foreach ($workshopItemId in $workshopItemIds) {
    if ($workshopItemId -notmatch '^\d+$') {
        throw "Invalid Workshop item ID in the selected server profile: $workshopItemId"
    }
}

$duplicates = @($workshopItemIds | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) { throw 'The selected server profile contains duplicate Workshop item IDs.' }
$duplicates = @($modIds | Group-Object | Where-Object Count -gt 1)
if ($duplicates.Count -gt 0) { throw 'The selected server profile contains duplicate mod IDs.' }

$missingWorkshopItems = @()
$workshopPath = $localConfiguration.projectZomboid.workshopPath
if (Test-Path -LiteralPath $workshopPath -PathType Container) {
    $missingWorkshopItems = @($workshopItemIds | Where-Object { -not (Test-Path -LiteralPath (Join-Path $workshopPath $_) -PathType Container) })
}
if ($missingWorkshopItems.Count -gt 0) {
    Write-Warning "$($missingWorkshopItems.Count) configured Workshop items are not installed locally."
}

$manifestPath = Join-Path $repositoryRoot 'config\modpack.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$manifest.compatibility.exactGameVersion = [string]$localConfiguration.projectZomboid.exactGameVersion
$manifest.compatibility.steamBuildId = [string]$localConfiguration.steam.buildId
$revisionInput = "WorkshopItems=$($workshopItemIds -join ';')`nMods=$($modIds -join ';')`nMap=$($maps -join ';')"
$sha256 = [Security.Cryptography.SHA256]::Create()
try {
    $revisionBytes = $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($revisionInput))
}
finally {
    $sha256.Dispose()
}
$manifest.workshop.revision = 'sha256:' + (($revisionBytes | ForEach-Object { $_.ToString('x2') }) -join '')
$manifest.workshop.itemIds = $workshopItemIds
$manifest.workshop.modIds = $modIds
$manifest.workshop.maps = $maps

if ($PSCmdlet.ShouldProcess($manifestPath, 'Export public modpack fields from the selected local server profile')) {
    ($manifest | ConvertTo-Json -Depth 10) + [Environment]::NewLine |
        Set-Content -LiteralPath $manifestPath -Encoding UTF8
}

[PSCustomObject]@{
    ExactGameVersion = $manifest.compatibility.exactGameVersion
    SteamBuildId = $manifest.compatibility.steamBuildId
    Revision = $manifest.workshop.revision
    WorkshopItems = $workshopItemIds.Count
    ModIds = $modIds.Count
    Maps = $maps.Count
    MissingInstalledWorkshopItems = $missingWorkshopItems.Count
}
