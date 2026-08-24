[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [string]$LocalConfigurationPath,
    [switch]$AllowRemovals
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
$profilePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.serverProfilePath)
$gameRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)

if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
    throw 'The discovered hosted-server profile does not exist.'
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
    throw 'Project Zomboid or its hosted server is running. Stop it before changing the hosted profile.'
}

$publicValues = [ordered]@{
    WorkshopItems = @($modpack.workshop.itemIds) -join ';'
    Mods = @($modpack.workshop.modIds) -join ';'
    Map = @($modpack.workshop.maps) -join ';'
}
foreach ($entry in $publicValues.GetEnumerator()) {
    $values = @($entry.Value -split ';')
    if ($values.Count -ne @($values | Sort-Object -Unique).Count) {
        throw "config/modpack.json contains duplicate values for $($entry.Key)."
    }
}

$profileLines = [Collections.Generic.List[string]]::new()
$profileLines.AddRange([string[]](Get-Content -LiteralPath $profilePath))
$changedKeys = [Collections.Generic.List[string]]::new()
$removedByKey = [ordered]@{}
foreach ($entry in $publicValues.GetEnumerator()) {
    $matchingIndexes = @(for ($index = 0; $index -lt $profileLines.Count; $index++) {
        if ($profileLines[$index] -match ('^{0}=' -f [regex]::Escape($entry.Key))) { $index }
    })
    if ($matchingIndexes.Count -ne 1) {
        throw "Expected exactly one $($entry.Key)= line in the hosted profile; found $($matchingIndexes.Count)."
    }
    $currentValue = $profileLines[$matchingIndexes[0]] -replace ('^{0}=' -f [regex]::Escape($entry.Key)), ''
    $currentValues = @($currentValue -split ';' | Where-Object { $_ })
    $newValues = @($entry.Value -split ';' | Where-Object { $_ })
    $removedValues = @($currentValues | Where-Object { $_ -notin $newValues })
    if ($removedValues.Count -gt 0) {
        $removedByKey[$entry.Key] = $removedValues
    }
    $newLine = "$($entry.Key)=$($entry.Value)"
    if ($profileLines[$matchingIndexes[0]] -ne $newLine) {
        $profileLines[$matchingIndexes[0]] = $newLine
        $changedKeys.Add($entry.Key)
    }
}

if ($removedByKey.Count -gt 0) {
    foreach ($entry in $removedByKey.GetEnumerator()) {
        Write-Warning ("Manifest would remove {0} {1} entries: {2}" -f $entry.Value.Count, $entry.Key, ($entry.Value -join ', '))
    }
    if (-not $AllowRemovals -and -not $WhatIfPreference) {
        throw 'Refusing to remove established hosted-profile entries. Review with -WhatIf, then rerun with -AllowRemovals only after verifying existing-world compatibility.'
    }
}

if ($changedKeys.Count -eq 0) {
    Write-Output 'The hosted profile already matches config/modpack.json.'
    return
}

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) "Backups\project-zomboid-build\profile-$timestamp"
$backupPath = Join-Path $backupRoot ([IO.Path]::GetFileName($profilePath) + '.bak')

if ($PSCmdlet.ShouldProcess($profilePath, "Replace only $($changedKeys -join ', ') from config/modpack.json")) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $profilePath -Destination $backupPath
    Set-Content -LiteralPath $profilePath -Value $profileLines -Encoding utf8
    Write-Output "Updated public modpack fields: $($changedKeys -join ', ')"
    Write-Output "The complete previous profile was backed up locally under $backupRoot"
}

[pscustomobject]@{
    WorkshopItems = @($modpack.workshop.itemIds).Count
    ModIds = @($modpack.workshop.modIds).Count
    Maps = @($modpack.workshop.maps).Count
    ChangedFields = @($changedKeys)
}
