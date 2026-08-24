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
$gameRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$destinationModRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) 'mods\PZPerformanceDiagnostics'
$jarPath = Join-Path $destinationModRoot '42.20\media\java\client\PZPerformanceDiagnostics.jar'

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
    throw 'Project Zomboid or its hosted server is running. Stop it before installing diagnostics.'
}

if (-not $PSCmdlet.ShouldProcess($destinationModRoot, 'Install PZ Performance Diagnostics source and generated JAR')) {
    return
}

& (Join-Path $PSScriptRoot 'Sync-ManagedFiles.ps1') `
    -Direction ToLocal `
    -Mod PZPerformanceDiagnostics `
    -LocalConfigurationPath $LocalConfigurationPath

if (Test-Path -LiteralPath $jarPath -PathType Leaf) {
    $backupRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) `
        ('Backups\project-zomboid-build\performance-diagnostics-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $backupPath = Join-Path $backupRoot 'PZPerformanceDiagnostics.jar'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $jarPath -Destination $backupPath -Force
    Write-Output "Backed up the previous diagnostics JAR to $backupPath"
}

& (Join-Path $PSScriptRoot 'Build-PZPerformanceDiagnostics.ps1') `
    -DestinationModRoot $destinationModRoot `
    -LocalConfigurationPath $LocalConfigurationPath

Write-Output 'Install complete. Enable ZombieBuddy and PZPerformanceDiagnostics, approve the JAR fingerprint, then restart Project Zomboid.'
