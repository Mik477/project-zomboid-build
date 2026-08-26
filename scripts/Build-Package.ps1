[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$KeepStagingDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot 'config\modpack.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$zombieBuddyInstallerName = 'ZombieBuddyInstaller_v4.2.exe'
$zombieBuddyInstallerUrl = 'https://github.com/zed-0xff/ZombieBuddy/releases/download/windows_installer_4.2/ZombieBuddyInstaller_v4.2.exe'
$zombieBuddyInstallerHash = '2A52466AFE804FECE5E88868EEF75A70E8964D3E4E01A3629B57CF6FF19E24B3'

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot 'dist'
}

$packageName = '{0}-{1}' -f $manifest.package.id, $manifest.package.version
$stagingRoot = Join-Path $OutputDirectory ('.staging-{0}' -f $packageName)
$archivePath = Join-Path $OutputDirectory ('{0}.zip' -f $packageName)
$pendingArchivePath = Join-Path $OutputDirectory ('.pending-{0}-{1}.zip' -f $packageName, $PID)

if (Test-Path -LiteralPath $stagingRoot) {
    $resolvedOutput = [IO.Path]::GetFullPath($OutputDirectory)
    $resolvedStaging = [IO.Path]::GetFullPath($stagingRoot)
    if (-not $resolvedStaging.StartsWith($resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove staging path outside the output directory: $resolvedStaging"
    }
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'payload\user\mods') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'payload\game') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $stagingRoot 'third-party') -Force | Out-Null

Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingRoot 'manifest.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install-Package.ps1') -Destination (Join-Path $stagingRoot 'Install.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'BetterVehicleDynamicsPayload.ps1') -Destination (Join-Path $stagingRoot 'BetterVehicleDynamicsPayload.ps1')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'packaging\Install.cmd') -Destination (Join-Path $stagingRoot 'Install.cmd')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'packaging\README.txt') -Destination (Join-Path $stagingRoot 'README.txt')
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'packaging\ZombieBuddy-LICENSE.txt') -Destination (Join-Path $stagingRoot 'third-party\ZombieBuddy-LICENSE.txt')

$thirdPartyCache = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\third-party'
$cachedZombieBuddyInstaller = Join-Path $thirdPartyCache $zombieBuddyInstallerName
$cachedInstallerIsCurrent = (Test-Path -LiteralPath $cachedZombieBuddyInstaller -PathType Leaf) -and
    ((Get-FileHash -LiteralPath $cachedZombieBuddyInstaller -Algorithm SHA256).Hash -eq $zombieBuddyInstallerHash)
if (-not $cachedInstallerIsCurrent) {
    New-Item -ItemType Directory -Path $thirdPartyCache -Force | Out-Null
    $downloadPath = "$cachedZombieBuddyInstaller.download-$PID"
    try {
        Invoke-WebRequest -Uri $zombieBuddyInstallerUrl -OutFile $downloadPath -UseBasicParsing
        $downloadHash = (Get-FileHash -LiteralPath $downloadPath -Algorithm SHA256).Hash
        if ($downloadHash -ne $zombieBuddyInstallerHash) {
            throw "Official ZombieBuddy installer changed. Expected SHA-256 $zombieBuddyInstallerHash, got $downloadHash."
        }
        Move-Item -LiteralPath $downloadPath -Destination $cachedZombieBuddyInstaller -Force
    }
    finally {
        if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
            Remove-Item -LiteralPath $downloadPath -Force
        }
    }
}
Copy-Item -LiteralPath $cachedZombieBuddyInstaller -Destination (Join-Path $stagingRoot "third-party\$zombieBuddyInstallerName")

$modSource = Join-Path $repositoryRoot 'src\mods'
$modItems = @(Get-ChildItem -LiteralPath $modSource -Directory -Force | Where-Object {
    Test-Path -LiteralPath (Join-Path $_.FullName '42.20\mod.info') -PathType Leaf
})
foreach ($item in $modItems) {
    $destinationModRoot = Join-Path (Join-Path $stagingRoot 'payload\user\mods') $item.Name
    if ($item.Name -eq 'MultiplayerRagdollPrototype') {
        & (Join-Path $PSScriptRoot 'Build-MultiplayerRagdollPrototype.ps1') -DestinationModRoot $destinationModRoot
    }
    elseif ($item.Name -eq 'PZPerformanceDiagnostics') {
        & (Join-Path $PSScriptRoot 'Build-PZPerformanceDiagnostics.ps1') -DestinationModRoot $destinationModRoot
    }
    elseif ($item.Name -in @(
        'TrashAndCorpsesSafetyFix',
        'SecretZCommandRegistrationFix',
        'KahluaObjectPoolConcurrencyFix',
        'GaelGunStoreLootDiversification'
    )) {
        & (Join-Path $PSScriptRoot 'Build-CompatibilityPatch.ps1') `
            -PatchId $item.Name `
            -DestinationModRoot $destinationModRoot
    }
    else {
        Copy-Item -LiteralPath $item.FullName -Destination $destinationModRoot -Recurse -Force
    }
}

$overrideSource = Join-Path $repositoryRoot 'src\game-overrides'
$overrideItems = @(Get-ChildItem -LiteralPath $overrideSource -Force | Where-Object Name -ne '.gitkeep')
foreach ($item in $overrideItems) {
    Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $stagingRoot 'payload\game') -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $pendingArchivePath) {
    Remove-Item -LiteralPath $pendingArchivePath -Force
}

$packageEntries = Get-ChildItem -LiteralPath $stagingRoot -Force | Select-Object -ExpandProperty FullName
try {
    Compress-Archive -LiteralPath $packageEntries -DestinationPath $pendingArchivePath -CompressionLevel Optimal
    & (Join-Path $PSScriptRoot 'Test-FriendPackage.ps1') -ArchivePath $pendingArchivePath
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        Remove-Item -LiteralPath $archivePath -Force
    }
    Move-Item -LiteralPath $pendingArchivePath -Destination $archivePath
}
finally {
    if (Test-Path -LiteralPath $pendingArchivePath -PathType Leaf) {
        Remove-Item -LiteralPath $pendingArchivePath -Force
    }
}

if (-not $KeepStagingDirectory) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

Write-Output "Created $archivePath"
