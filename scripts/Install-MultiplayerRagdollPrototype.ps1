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
$destinationModRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) 'mods\MultiplayerRagdollPrototype'
$jarPath = Join-Path $destinationModRoot '42.20\media\java\client\MultiplayerRagdollPrototype.jar'

if (-not $PSCmdlet.ShouldProcess($destinationModRoot, 'Install Multiplayer Ragdoll Prototype source and generated JAR')) {
    return
}

& (Join-Path $PSScriptRoot 'Sync-ManagedFiles.ps1') `
    -Direction ToLocal `
    -Mod MultiplayerRagdollPrototype `
    -LocalConfigurationPath $LocalConfigurationPath

if (Test-Path -LiteralPath $jarPath -PathType Leaf) {
    $backupRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) `
        ('Backups\project-zomboid-build\ragdoll-prototype-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $backupPath = Join-Path $backupRoot 'MultiplayerRagdollPrototype.jar'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    Copy-Item -LiteralPath $jarPath -Destination $backupPath -Force
    Write-Output "Backed up the previous prototype JAR to $backupPath"
}

& (Join-Path $PSScriptRoot 'Build-MultiplayerRagdollPrototype.ps1') `
    -DestinationModRoot $destinationModRoot `
    -LocalConfigurationPath $LocalConfigurationPath

Write-Output 'Install complete. Enable ZombieBuddy and MultiplayerRagdollPrototype on the client, approve the JAR fingerprint, then restart Project Zomboid.'
