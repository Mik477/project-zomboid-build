[CmdletBinding()]
param(
    [string]$ArchivePath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$failures = [Collections.Generic.List[string]]::new()
$expectedInstallerHash = '2A52466AFE804FECE5E88868EEF75A70E8964D3E4E01A3629B57CF6FF19E24B3'
$sourceManifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
if (@($sourceManifest.workshop.modIds).Count -ne 207) {
    $failures.Add("Release manifest must activate exactly 207 Mod IDs; found $(@($sourceManifest.workshop.modIds).Count).")
}

function Require-Tokens {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string[]]$Tokens
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $failures.Add("Missing required package source: $Path")
        return
    }
    $content = Get-Content -LiteralPath $Path -Raw
    foreach ($token in $Tokens) {
        if (-not $content.Contains($token)) {
            $failures.Add("$Path is missing required token: $token")
        }
    }
}

Require-Tokens -Path (Join-Path $PSScriptRoot 'Build-Package.ps1') -Tokens @(
    'ZombieBuddyInstaller_v4.2.exe',
    'windows_installer_4.2',
    $expectedInstallerHash,
    'ZombieBuddy-LICENSE.txt',
    'BetterVehicleDynamicsPayload.ps1',
    '.pending-',
    'Test-FriendPackage.ps1'
)
Require-Tokens -Path (Join-Path $PSScriptRoot 'Install-Package.ps1') -Tokens @(
    'Resolve-ProjectZomboidInstallation',
    "Windows did not provide a user-profile path",
    'IsNullOrWhiteSpace($installDirectory)',
    'IsNullOrWhiteSpace($steamBuildId)',
    'Run the official ZombieBuddy installer',
    'zbNative.dll installed by the official installer',
    'reviewed Trash and Corpses source',
    'reviewed SecretZ source',
    'join the host once',
    'Write-ClientModList',
    'New-BetterVehicleDynamicsPayloadSnapshot',
    'Join the host and let Project Zomboid/Steam install the server Workshop list before playing.'
)
Require-Tokens -Path (Join-Path $repositoryRoot 'packaging\Install.cmd') -Tokens @(
    'ExecutionPolicy Bypass',
    'Install.ps1'
)
Require-Tokens -Path (Join-Path $repositoryRoot 'packaging\ZombieBuddy-LICENSE.txt') -Tokens @(
    'Copyright (c) 2025 Andrey "Zed" Zaikin',
    'Permission is hereby granted',
    'THE SOFTWARE IS PROVIDED "AS IS"'
)

if ($ArchivePath) {
    $ArchivePath = [IO.Path]::GetFullPath($ArchivePath)
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        $failures.Add("Friend package archive does not exist: $ArchivePath")
    }
    else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
        try {
            $entries = @($archive.Entries)
            $entryNames = @($entries | ForEach-Object { $_.FullName.Replace('\', '/') })
            foreach ($requiredEntry in @(
                'Install.cmd',
                'Install.ps1',
                'README.txt',
                'manifest.json',
                'BetterVehicleDynamicsPayload.ps1',
                'third-party/ZombieBuddyInstaller_v4.2.exe',
                'third-party/ZombieBuddy-LICENSE.txt'
            )) {
                if ($requiredEntry -notin $entryNames) {
                    $failures.Add("Friend package is missing $requiredEntry")
                }
            }

            if (@($entryNames | Where-Object { $_ -match '(?i)(^|/)steamapps/workshop/content/' }).Count -gt 0) {
                $failures.Add('Friend package must not redistribute Steam Workshop payloads.')
            }
            foreach ($entryName in $entryNames) {
                if ($entryName -match '(?i)^(payload/user/)?(saves?|logs?|server)(/|$)' -or
                    $entryName -match '(?i)(^|/)(console|coop-console)\.txt$' -or
                    $entryName -match '(?i)(^|/)config/local\.json$' -or
                    $entryName -match '(?i)\.(zip|7z|rar|log|dmp|db|sqlite|sqlite3)$') {
                    $failures.Add("Friend package contains a forbidden runtime/private/archive entry: $entryName")
                }
                if ($entryName -match '(?i)\.(exe|dll)$' -and $entryName -ne 'third-party/ZombieBuddyInstaller_v4.2.exe') {
                    $failures.Add("Friend package contains an unexpected native executable: $entryName")
                }
            }

            $sourceModNames = @(Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'src\mods') -Directory | Where-Object {
                Test-Path -LiteralPath (Join-Path $_.FullName '42.20\mod.info') -PathType Leaf
            } | ForEach-Object Name)
            foreach ($modName in $sourceModNames) {
                $expectedEntry = "payload/user/mods/$modName/42.20/mod.info"
                if ($expectedEntry -notin $entryNames) {
                    $failures.Add("Friend package does not contain repo-owned mod $modName")
                }
            }

            $installerEntry = $entries | Where-Object { $_.FullName.Replace('\', '/') -eq 'third-party/ZombieBuddyInstaller_v4.2.exe' } | Select-Object -First 1
            if ($installerEntry) {
                $stream = $installerEntry.Open()
                $sha256 = [Security.Cryptography.SHA256]::Create()
                try {
                    $actualHash = (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString('X2') }) -join '')
                }
                finally {
                    $sha256.Dispose()
                    $stream.Dispose()
                }
                if ($actualHash -ne $expectedInstallerHash) {
                    $failures.Add("Packaged ZombieBuddy installer hash mismatch: $actualHash")
                }
            }

            $manifestEntry = $entries | Where-Object { $_.FullName.Replace('\', '/') -eq 'manifest.json' } | Select-Object -First 1
            if ($manifestEntry) {
                $reader = [IO.StreamReader]::new($manifestEntry.Open())
                try { $packagedManifest = $reader.ReadToEnd() | ConvertFrom-Json }
                finally { $reader.Dispose() }
                if ([string]$packagedManifest.package.version -ne [string]$sourceManifest.package.version) {
                    $failures.Add('Packaged manifest version does not match config/modpack.json.')
                }
                if ((@($packagedManifest.workshop.modIds) -join "`n") -cne (@($sourceManifest.workshop.modIds) -join "`n")) {
                    $failures.Add('Packaged manifest Mod ID activation order does not match config/modpack.json.')
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
}

if ($failures.Count -gt 0) {
    $message = "Friend package validation failed:`n - " + ($failures -join "`n - ")
    throw $message
}

Write-Output 'Friend package validation passed.'
