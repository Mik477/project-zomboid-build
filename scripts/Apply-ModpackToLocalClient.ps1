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
$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
$userRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.userPath)
$gameRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$clientModListPath = Join-Path $userRoot 'mods\default.txt'
if (-not (Test-Path -LiteralPath $clientModListPath -PathType Leaf)) {
    throw "The local client mod list does not exist: $clientModListPath"
}

$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    if ($_.ProcessName -like 'ProjectZomboid*') { return $true }
    try {
        return $_.Path -and [IO.Path]::GetFullPath($_.Path).StartsWith(
            $gameRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase)
    }
    catch {
        return $false
    }
})
if ($runningProcesses.Count -gt 0) {
    throw 'Project Zomboid or its hosted server is running. Stop it before changing the client mod list.'
}

$currentMods = [Collections.Generic.List[string]]::new()
foreach ($line in Get-Content -LiteralPath $clientModListPath) {
    if ($line -match '^\s*mod\s*=\s*(.*),\s*$') {
        $currentMods.Add($matches[1])
    }
}
if ($currentMods.Count -eq 0) {
    throw 'The local client mod list contains no recognized mod entries.'
}
if (@($currentMods | Sort-Object -Unique).Count -ne $currentMods.Count) {
    throw 'The local client mod list contains duplicate mod IDs.'
}

$desiredMods = @($manifest.workshop.modIds)
if (@($desiredMods | Sort-Object -Unique).Count -ne $desiredMods.Count) {
    throw 'config/modpack.json contains duplicate mod IDs.'
}
$removedMods = @($currentMods | Where-Object { $_ -notin $desiredMods })
$addedMods = @($desiredMods | Where-Object { $_ -notin $currentMods })
if ($removedMods.Count -gt 0) {
    Write-Warning "Manifest would remove $($removedMods.Count) local client mod entries: $($removedMods -join ', ')"
    if (-not $AllowRemovals -and -not $WhatIfPreference) {
        throw 'Refusing to remove established client mod entries. Review with -WhatIf, then rerun with -AllowRemovals.'
    }
}

$currentOrdered = @($currentMods) -join "`n"
$desiredOrdered = $desiredMods -join "`n"
if ($currentOrdered -ceq $desiredOrdered) {
    Write-Output 'The local client mod list already matches config/modpack.json.'
    return
}

$newLines = [Collections.Generic.List[string]]::new()
$newLines.Add('VERSION = 1,')
$newLines.Add('')
$newLines.Add('mods')
$newLines.Add('{')
foreach ($modId in $desiredMods) {
    $newLines.Add("    mod = $modId,")
}
$newLines.Add('}')

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $userRoot "Backups\project-zomboid-build\client-mods-$timestamp"
$backupPath = Join-Path $backupRoot 'default.txt.bak'
if ($PSCmdlet.ShouldProcess($clientModListPath, 'Replace the local client mod list from config/modpack.json')) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $clientModListPath -Destination $backupPath
    Set-Content -LiteralPath $clientModListPath -Value $newLines -Encoding utf8
    Write-Output "Updated the local client mod list and backed up its previous state under $backupRoot"
}

[pscustomobject]@{
    ModIds = $desiredMods.Count
    Added = $addedMods
    Removed = $removedMods
}
