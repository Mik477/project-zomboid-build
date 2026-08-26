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
$userModsRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) 'mods'
$patchIds = @(
    'TrashAndCorpsesSafetyFix',
    'SecretZCommandRegistrationFix',
    'KahluaObjectPoolConcurrencyFix',
    'GaelGunStoreLootDiversification'
)

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
    throw 'Project Zomboid or its hosted server is running. Stop it before installing compatibility patches.'
}

if (-not $PSCmdlet.ShouldProcess($userModsRoot, 'Install split compatibility patch sources and generated common JARs')) {
    return
}

$backupRoot = Join-Path ([string]$localConfiguration.projectZomboid.userPath) `
    ('Backups\project-zomboid-build\compatibility-patches-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($patchId in $patchIds) {
    $destinationModRoot = Join-Path $userModsRoot $patchId
    $jarPath = Join-Path $destinationModRoot ("42.20\media\java\common\{0}.jar" -f $patchId)
    if (Test-Path -LiteralPath $jarPath -PathType Leaf) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        Copy-Item -LiteralPath $jarPath -Destination (Join-Path $backupRoot ("{0}.jar" -f $patchId)) -Force
    }

    & (Join-Path $PSScriptRoot 'Sync-ManagedFiles.ps1') `
        -Direction ToLocal `
        -Mod $patchId `
        -LocalConfigurationPath $LocalConfigurationPath
    & (Join-Path $PSScriptRoot 'Build-CompatibilityPatch.ps1') `
        -PatchId $patchId `
        -DestinationModRoot $destinationModRoot `
        -LocalConfigurationPath $LocalConfigurationPath

    $jarHash = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash
    Write-Output "$patchId common JAR SHA-256: $jarHash"
}

Write-Output 'Install complete. Every participant must approve all common-JAR fingerprints and fully restart Project Zomboid.'
