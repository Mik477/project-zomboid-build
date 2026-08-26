[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PackageRoot,
    [string]$ZomboidUserPath,
    [string]$GamePath,
    [string]$WorkshopPath,
    [string]$ZombieBuddyInstallerPath,
    [switch]$IncludeGameOverrides,
    [switch]$SkipZombieBuddyInstaller,
    [switch]$SkipBetterVehicleDynamics
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    $installerScriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($installerScriptPath)) {
        $installerScriptPath = $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($installerScriptPath)) {
        throw 'Windows PowerShell did not provide the installer script path. Fully extract the ZIP, then run Install.cmd from the extracted folder.'
    }
    $PackageRoot = Split-Path -Parent $installerScriptPath
}
if ([string]::IsNullOrWhiteSpace($PackageRoot)) {
    throw 'The package folder could not be determined. Fully extract the ZIP, then run Install.cmd from the extracted folder.'
}
$PackageRoot = [IO.Path]::GetFullPath($PackageRoot)

if ([string]::IsNullOrWhiteSpace($ZomboidUserPath)) {
    $userProfilePath = $env:USERPROFILE
    if ([string]::IsNullOrWhiteSpace($userProfilePath)) {
        $userProfilePath = [Environment]::GetFolderPath('UserProfile')
    }
    if ([string]::IsNullOrWhiteSpace($userProfilePath)) {
        throw 'Windows did not provide a user-profile path. Set USERPROFILE or run Install.ps1 with -ZomboidUserPath.'
    }
    $ZomboidUserPath = Join-Path $userProfilePath 'Zomboid'
}

$manifestPath = Join-Path $PackageRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Package manifest not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $ZomboidUserPath ("Backups\project-zomboid-build\{0}-{1}" -f $manifest.package.version, $timestamp)
$expectedZombieBuddyInstallerHash = '2A52466AFE804FECE5E88868EEF75A70E8964D3E4E01A3629B57CF6FF19E24B3'

function Get-AcfValue {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Name
    )

    $match = [regex]::Match($Text, '(?im)^\s*"' + [regex]::Escape($Name) + '"\s+"([^"]*)"')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Resolve-ProjectZomboidInstallation {
    $steamRoots = [Collections.Generic.List[string]]::new()
    foreach ($registryPath in @(
        'HKCU:\Software\Valve\Steam',
        'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
        'HKLM:\SOFTWARE\Valve\Steam'
    )) {
        if (-not (Test-Path -LiteralPath $registryPath)) { continue }
        $properties = Get-ItemProperty -LiteralPath $registryPath
        foreach ($propertyName in @('SteamPath', 'InstallPath')) {
            if ($properties.$propertyName) {
                $steamRoots.Add([IO.Path]::GetFullPath([string]$properties.$propertyName))
            }
        }
    }

    foreach ($steamRoot in @($steamRoots | Sort-Object -Unique)) {
        $libraryRoots = [Collections.Generic.List[string]]::new()
        $libraryRoots.Add($steamRoot)
        $libraryMetadataPath = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraryMetadataPath -PathType Leaf) {
            $libraryText = Get-Content -LiteralPath $libraryMetadataPath -Raw
            foreach ($match in [regex]::Matches($libraryText, '"path"\s+"([^"]+)"')) {
                $libraryRoots.Add(($match.Groups[1].Value -replace '\\\\', '\'))
            }
        }

        foreach ($libraryRoot in @($libraryRoots | Sort-Object -Unique)) {
            if ([string]::IsNullOrWhiteSpace($libraryRoot)) { continue }
            $appManifestPath = Join-Path $libraryRoot 'steamapps\appmanifest_108600.acf'
            if (-not (Test-Path -LiteralPath $appManifestPath -PathType Leaf)) { continue }
            $appManifestText = Get-Content -LiteralPath $appManifestPath -Raw
            $installDirectory = Get-AcfValue -Text $appManifestText -Name 'installdir'
            if ([string]::IsNullOrWhiteSpace($installDirectory)) { continue }
            $steamBuildId = Get-AcfValue -Text $appManifestText -Name 'buildid'
            if ([string]::IsNullOrWhiteSpace($steamBuildId)) { continue }
            $discoveredGamePath = Join-Path $libraryRoot (Join-Path 'steamapps\common' $installDirectory)
            if (-not (Test-Path -LiteralPath $discoveredGamePath -PathType Container)) { continue }
            return [pscustomobject]@{
                GamePath = $discoveredGamePath
                WorkshopPath = Join-Path $libraryRoot 'steamapps\workshop\content\108600'
                SteamBuildId = $steamBuildId
            }
        }
    }

    throw 'Project Zomboid (Steam app 108600) was not found in any configured Steam library.'
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

function Assert-ExactFileHash {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$ExpectedHash,
        [Parameter(Mandatory)] [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description is missing: $Path"
    }
    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedHash) {
        throw "$Description changed. Expected SHA-256 $ExpectedHash, got $actualHash. Re-audit before installing this package."
    }
}

function Install-PayloadTree {
    param(
        [Parameter(Mandatory)] [string]$SourceRoot,
        [Parameter(Mandatory)] [string]$DestinationRoot,
        [Parameter(Mandatory)] [string]$BackupCategory
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        return
    }

    $sourceFiles = @(Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -Force)
    foreach ($sourceFile in $sourceFiles) {
        $relativePath = Get-RelativeFilePath -BasePath $SourceRoot -Path $sourceFile.FullName
        if ($relativePath.StartsWith('..')) {
            throw "Package entry escapes its payload root: $($sourceFile.FullName)"
        }

        $destinationPath = Join-Path $DestinationRoot $relativePath
        $destinationDirectory = Split-Path -Parent $destinationPath
        if ($PSCmdlet.ShouldProcess($destinationPath, 'Install package file')) {
            if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
                $backupPath = Join-Path (Join-Path $backupRoot $BackupCategory) $relativePath
                $backupDirectory = Split-Path -Parent $backupPath
                New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
                Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
            }

            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
            Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationPath -Force
        }
    }
}

function Require-WorkshopItem {
    param(
        [Parameter(Mandatory)] [string]$ItemId,
        [Parameter(Mandatory)] [string]$Name
    )

    $itemPath = Join-Path $WorkshopPath $ItemId
    if (Test-Path -LiteralPath $itemPath -PathType Container) {
        return $itemPath
    }

    if ($WhatIfPreference) {
        Write-Output "Would require Steam Workshop item $ItemId ($Name)."
        return $itemPath
    }
    throw "Steam Workshop item $ItemId ($Name) is missing. Start Project Zomboid, join the host once, let the server Workshop download finish, close the game, then run Install.cmd again."
}

function Write-ClientModList {
    $modListPath = Join-Path $ZomboidUserPath 'mods\default.txt'
    $desiredMods = @($manifest.workshop.modIds)
    $newLines = [Collections.Generic.List[string]]::new()
    $newLines.Add('VERSION = 1,')
    $newLines.Add('')
    $newLines.Add('mods')
    $newLines.Add('{')
    foreach ($modId in $desiredMods) {
        $newLines.Add("    mod = $modId,")
    }
    $newLines.Add('}')

    $newContent = $newLines -join [Environment]::NewLine
    $currentContent = if (Test-Path -LiteralPath $modListPath -PathType Leaf) {
        (Get-Content -LiteralPath $modListPath -Raw).TrimEnd("`r", "`n")
    }
    else {
        $null
    }
    if ($currentContent -ceq $newContent) {
        Write-Output "Client activation list already matches all $($desiredMods.Count) manifest Mod IDs."
        return
    }

    if ($PSCmdlet.ShouldProcess($modListPath, "Activate all $($desiredMods.Count) manifest Mod IDs")) {
        if (Test-Path -LiteralPath $modListPath -PathType Leaf) {
            $backupPath = Join-Path $backupRoot 'client-mods\default.txt.bak'
            New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
            Copy-Item -LiteralPath $modListPath -Destination $backupPath -Force
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $modListPath) -Force | Out-Null
        Set-Content -LiteralPath $modListPath -Value $newLines -Encoding utf8
        Write-Output "Activated all $($desiredMods.Count) manifest Mod IDs in $modListPath."
    }
}

$discoveredInstallation = Resolve-ProjectZomboidInstallation
if (-not $GamePath) { $GamePath = $discoveredInstallation.GamePath }
if (-not $WorkshopPath) { $WorkshopPath = $discoveredInstallation.WorkshopPath }
$GamePath = [IO.Path]::GetFullPath($GamePath)
$WorkshopPath = [IO.Path]::GetFullPath($WorkshopPath)
$ZomboidUserPath = [IO.Path]::GetFullPath($ZomboidUserPath)

if (-not (Test-Path -LiteralPath $GamePath -PathType Container)) {
    throw "Project Zomboid game directory does not exist: $GamePath"
}
if (-not (Test-Path -LiteralPath $WorkshopPath -PathType Container)) {
    throw "Project Zomboid Workshop directory does not exist: $WorkshopPath"
}
if ([string]$discoveredInstallation.SteamBuildId -ne [string]$manifest.compatibility.steamBuildId) {
    throw "Installed Steam build $($discoveredInstallation.SteamBuildId) does not match package build $($manifest.compatibility.steamBuildId)."
}

$resolvedGameRoot = $GamePath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    if ($_.ProcessName -like 'ProjectZomboid*') { return $true }
    try {
        return $_.Path -and [IO.Path]::GetFullPath($_.Path).StartsWith($resolvedGameRoot, [StringComparison]::OrdinalIgnoreCase)
    }
    catch { return $false }
})
if ($runningProcesses.Count -gt 0) {
    throw 'Project Zomboid or its hosted server is running. Stop it before installing the package.'
}

$zombieBuddyWorkshopRoot = Require-WorkshopItem -ItemId '3619862853' -Name 'ZombieBuddy'
$secretZWorkshopRoot = Require-WorkshopItem -ItemId '3494374578' -Name 'SecretZ'
$trashAndCorpsesWorkshopRoot = Require-WorkshopItem -ItemId '3662273535' -Name 'Trash and Corpses'
$betterVehicleDynamicsWorkshopRoot = $null
if (-not $SkipBetterVehicleDynamics) {
    $betterVehicleDynamicsWorkshopRoot = Require-WorkshopItem -ItemId '3728775267' -Name 'Better Vehicle Dynamics'
}

if (-not $ZombieBuddyInstallerPath) {
    $ZombieBuddyInstallerPath = Join-Path $PackageRoot 'third-party\ZombieBuddyInstaller_v4.2.exe'
}
Assert-ExactFileHash `
    -Path $ZombieBuddyInstallerPath `
    -ExpectedHash $expectedZombieBuddyInstallerHash `
    -Description 'official ZombieBuddy v4.2 installer'

if (-not $SkipZombieBuddyInstaller -and $PSCmdlet.ShouldProcess($ZombieBuddyInstallerPath, 'Run the official ZombieBuddy installer')) {
    $installerProcess = Start-Process -FilePath $ZombieBuddyInstallerPath -Wait -PassThru
    if ($installerProcess.ExitCode -ne 0) {
        throw "The official ZombieBuddy installer exited with code $($installerProcess.ExitCode)."
    }
}

if ([string]$manifest.compatibility.exactGameVersion -ne '42.20.3' -or
    [string]$manifest.compatibility.steamBuildId -ne '24909800') {
    throw 'Package compatibility metadata does not match the exact Java patch target.'
}
Assert-ExactFileHash `
    -Path (Join-Path $GamePath 'projectzomboid.jar') `
    -ExpectedHash '80E405A4BFC42F6072E75B3735F458A6514143DA011D3226007DED305A442F44' `
    -Description 'projectzomboid.jar'

$installedZombieBuddyJar = Join-Path $GamePath 'ZombieBuddy.jar'
$installedZombieBuddyNative = Join-Path $GamePath 'zbNative.dll'
$zombieBuddyCoreMissing = -not (Test-Path -LiteralPath $installedZombieBuddyJar -PathType Leaf) -or
    -not (Test-Path -LiteralPath $installedZombieBuddyNative -PathType Leaf)
if ($zombieBuddyCoreMissing -and $WhatIfPreference) {
    Write-Warning 'ZombieBuddy core files are not installed yet; the real run will verify them after the official installer finishes.'
}
else {
    Assert-ExactFileHash `
        -Path $installedZombieBuddyJar `
        -ExpectedHash '6DD95CEDCE60F03BF8B8CEFD0D19EB156230E0D54BFFA07DE9DA5212A06C7BE6' `
        -Description 'ZombieBuddy.jar installed by the official installer'
    Assert-ExactFileHash `
        -Path $installedZombieBuddyNative `
        -ExpectedHash 'C2AE9335E717EE24B2F4A40D1A3BF77F1519762A72A0459E766A2BBAFC077F6C' `
        -Description 'zbNative.dll installed by the official installer'
}

$normalLauncherPath = Join-Path $GamePath 'ProjectZomboid64.json'
$alternateLauncherPath = Join-Path $GamePath 'ProjectZomboid64.bat'
$normalLauncherPatched = (Test-Path -LiteralPath $normalLauncherPath -PathType Leaf) -and
    (Get-Content -LiteralPath $normalLauncherPath -Raw).Contains('-agentlib:zbNative')
$alternateLauncherPatched = (Test-Path -LiteralPath $alternateLauncherPath -PathType Leaf) -and
    (Get-Content -LiteralPath $alternateLauncherPath -Raw).Contains('-agentlib:zbNative')
if (-not $normalLauncherPatched -or -not $alternateLauncherPatched) {
    if ($WhatIfPreference) {
        Write-Warning 'No Project Zomboid launcher is patched yet; the real run will verify the official installer result.'
    }
    else {
        throw 'ZombieBuddy core files exist, but both ProjectZomboid64.json and ProjectZomboid64.bat must load zbNative. Run the official installer again and patch Both launch modes.'
    }
}

Assert-ExactFileHash `
    -Path (Join-Path $trashAndCorpsesWorkshopRoot 'mods\Trash and Corpses\42\media\lua\shared\ScatteredTrashes.lua') `
    -ExpectedHash '556A46A87DCC9CF704FB65F991C5CD44396CCCEC0016442DD66776578AE8B6DB' `
    -Description 'reviewed Trash and Corpses source'
Assert-ExactFileHash `
    -Path (Join-Path $secretZWorkshopRoot 'mods\Secretz42\42.20\media\lua\server\SZDoors\SZCServer.lua') `
    -ExpectedHash '8CDC2C1DC0DFB191D1E4A46B0C4E76DEC4816198E27A3E560E3C053485FB4838' `
    -Description 'reviewed SecretZ source'

$userPayload = Join-Path $PackageRoot 'payload\user'
Install-PayloadTree -SourceRoot $userPayload -DestinationRoot $ZomboidUserPath -BackupCategory 'user'

if (-not $SkipBetterVehicleDynamics) {
    $bvdFunctionsPath = Join-Path $PackageRoot 'BetterVehicleDynamicsPayload.ps1'
    if (-not (Test-Path -LiteralPath $bvdFunctionsPath -PathType Leaf)) {
        throw "Better Vehicle Dynamics package helper is missing: $bvdFunctionsPath"
    }
    . $bvdFunctionsPath
    $bvdSourceRoot = Join-Path $betterVehicleDynamicsWorkshopRoot 'mods\BetterVehicleDynamics\B42.20_Manual_Install\zombie'
    if (-not (Test-Path -LiteralPath $bvdSourceRoot -PathType Container)) {
        throw 'The Better Vehicle Dynamics B42.20 manual-install payload is missing. Let Steam finish downloading Workshop item 3728775267.'
    }

    $bvdExpectedHashes = Get-BetterVehicleDynamicsExpectedPayloadHashes
    $bvdSnapshotRoot = Join-Path $env:TEMP "project-zomboid-build-bvd-$PID-$([Guid]::NewGuid().ToString('N'))"
    $bvdDestinationRoot = Join-Path $GamePath 'zombie'
    $bvdRecords = [Collections.Generic.List[object]]::new()
    $bvdChangedCount = 0
    try {
        $null = @(New-BetterVehicleDynamicsPayloadSnapshot `
            -SourceRoot $bvdSourceRoot `
            -SnapshotRoot $bvdSnapshotRoot `
            -ExpectedPayloadHashes $bvdExpectedHashes)

        foreach ($relativePath in $bvdExpectedHashes.Keys) {
            $sourcePath = Join-Path $bvdSnapshotRoot $relativePath
            $destinationPath = Join-Path $bvdDestinationRoot $relativePath
            $destinationExisted = Test-Path -LiteralPath $destinationPath -PathType Leaf
            $previousHash = if ($destinationExisted) {
                (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
            }
            else {
                $null
            }
            $needsCopy = $previousHash -ne $bvdExpectedHashes[$relativePath]
            $backupRelativePath = $null

            if ($needsCopy -and $PSCmdlet.ShouldProcess($destinationPath, 'Install Better Vehicle Dynamics Java class')) {
                if ($destinationExisted) {
                    $backupRelativePath = Join-Path 'replaced' $relativePath
                    $backupPath = Join-Path (Join-Path $backupRoot 'better-vehicle-dynamics') $backupRelativePath
                    New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                    Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
                }
                New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force | Out-Null
                Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
                Assert-ExactFileHash `
                    -Path $destinationPath `
                    -ExpectedHash $bvdExpectedHashes[$relativePath] `
                    -Description "installed Better Vehicle Dynamics class $relativePath"
                $bvdChangedCount++
            }

            $bvdRecords.Add([pscustomobject]@{
                path = $relativePath.Replace('\', '/')
                sourceSha256 = $bvdExpectedHashes[$relativePath].ToLowerInvariant()
                existedBefore = $destinationExisted
                previousSha256 = if ($previousHash) { $previousHash.ToLowerInvariant() } else { $null }
                backupPath = if ($backupRelativePath) { $backupRelativePath.Replace('\', '/') } else { $null }
                changed = $needsCopy
            })
        }

        if ($bvdChangedCount -gt 0 -and -not $WhatIfPreference) {
            $bvdBackupRoot = Join-Path $backupRoot 'better-vehicle-dynamics'
            New-Item -ItemType Directory -Path $bvdBackupRoot -Force | Out-Null
            [pscustomobject]@{
                schemaVersion = 1
                installedAt = (Get-Date).ToString('o')
                workshopItemId = '3728775267'
                gameVersion = [string]$manifest.compatibility.exactGameVersion
                steamBuildId = [string]$manifest.compatibility.steamBuildId
                destination = 'ProjectZomboid/zombie'
                files = @($bvdRecords)
            } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $bvdBackupRoot 'install-manifest.json') -Encoding utf8
        }
    }
    finally {
        if (Test-Path -LiteralPath $bvdSnapshotRoot -PathType Container) {
            Remove-Item -LiteralPath $bvdSnapshotRoot -Recurse -Force -WhatIf:$false
        }
    }
}

if ($IncludeGameOverrides) {
    Install-PayloadTree `
        -SourceRoot (Join-Path $PackageRoot 'payload\game') `
        -DestinationRoot $GamePath `
        -BackupCategory 'game'
}

Write-ClientModList

$missingWorkshopItems = @($manifest.workshop.itemIds | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $WorkshopPath $_) -PathType Container)
})
if ($missingWorkshopItems.Count -gt 0) {
    Write-Warning "$($missingWorkshopItems.Count) Steam Workshop items are not downloaded yet. Join the host and let Project Zomboid/Steam install the server Workshop list before playing."
}

Write-Output ("Installed {0} {1}. Backups, when needed, are under {2}" -f $manifest.package.name, $manifest.package.version, $backupRoot)
