[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PackageRoot = $PSScriptRoot,
    [string]$ZomboidUserPath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Zomboid'),
    [string]$GamePath,
    [string]$WorkshopPath,
    [switch]$IncludeGameOverrides
)

$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PackageRoot 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Package manifest not found: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $ZomboidUserPath ("Backups\project-zomboid-build\{0}-{1}" -f $manifest.package.version, $timestamp)

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

$userPayload = Join-Path $PackageRoot 'payload\user'
$generatedJavaPayloads = @()
if (Test-Path -LiteralPath $userPayload -PathType Container) {
    $generatedJavaPayloads = @(Get-ChildItem -LiteralPath $userPayload -Recurse -File -Filter '*.jar')
}
if ($generatedJavaPayloads.Count -gt 0) {
    if (-not $GamePath -or -not $WorkshopPath) {
        throw '-GamePath and -WorkshopPath are required when a package contains generated Java patches.'
    }
    $GamePath = [IO.Path]::GetFullPath($GamePath)
    $WorkshopPath = [IO.Path]::GetFullPath($WorkshopPath)
    if ([string]$manifest.compatibility.exactGameVersion -ne '42.20.3' -or
        [string]$manifest.compatibility.steamBuildId -ne '24775755') {
        throw 'Package compatibility metadata does not match the exact Java patch target.'
    }

    Assert-ExactFileHash `
        -Path (Join-Path $GamePath 'projectzomboid.jar') `
        -ExpectedHash 'BDA809FB49004A07DBFC560D059C0EE58D0643AB0F33B53351B13BD62F1D8227' `
        -Description 'projectzomboid.jar'
    $zombieBuddyCandidates = @(
        (Join-Path $GamePath 'ZombieBuddy.jar'),
        (Join-Path $WorkshopPath '3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')
    )
    $zombieBuddyJar = $zombieBuddyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    if (-not $zombieBuddyJar) { throw 'ZombieBuddy.jar was not found in the game directory or Workshop item 3619862853.' }
    Assert-ExactFileHash `
        -Path $zombieBuddyJar `
        -ExpectedHash '6DD95CEDCE60F03BF8B8CEFD0D19EB156230E0D54BFFA07DE9DA5212A06C7BE6' `
        -Description 'ZombieBuddy.jar'

    if (Test-Path -LiteralPath (Join-Path $userPayload 'mods\TrashAndCorpsesSafetyFix') -PathType Container) {
        Assert-ExactFileHash `
            -Path (Join-Path $WorkshopPath '3662273535\mods\Trash and Corpses\42\media\lua\shared\ScatteredTrashes.lua') `
            -ExpectedHash '556A46A87DCC9CF704FB65F991C5CD44396CCCEC0016442DD66776578AE8B6DB' `
            -Description 'reviewed Trash and Corpses source'
    }
    if (Test-Path -LiteralPath (Join-Path $userPayload 'mods\SecretZCommandRegistrationFix') -PathType Container) {
        Assert-ExactFileHash `
            -Path (Join-Path $WorkshopPath '3494374578\mods\Secretz42\42.20\media\lua\server\SZDoors\SZCServer.lua') `
            -ExpectedHash '8CDC2C1DC0DFB191D1E4A46B0C4E76DEC4816198E27A3E560E3C053485FB4838' `
            -Description 'reviewed SecretZ source'
    }
}

$resolvedGameRoot = if ($GamePath) { [IO.Path]::GetFullPath($GamePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar } else { $null }
$runningProcesses = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    if ($_.ProcessName -like 'ProjectZomboid*') { return $true }
    try {
        return $resolvedGameRoot -and $_.Path -and
            [IO.Path]::GetFullPath($_.Path).StartsWith($resolvedGameRoot, [StringComparison]::OrdinalIgnoreCase)
    }
    catch { return $false }
})
if ($runningProcesses.Count -gt 0) {
    throw 'Project Zomboid or its hosted server is running. Stop it before installing the package.'
}

Install-PayloadTree -SourceRoot $userPayload -DestinationRoot $ZomboidUserPath -BackupCategory 'user'

if ($IncludeGameOverrides) {
    if (-not $GamePath) {
        throw '-GamePath is required when -IncludeGameOverrides is used.'
    }
    if (-not (Test-Path -LiteralPath $GamePath -PathType Container)) {
        throw "Project Zomboid game directory does not exist: $GamePath"
    }

    $gamePayload = Join-Path $PackageRoot 'payload\game'
    Install-PayloadTree -SourceRoot $gamePayload -DestinationRoot $GamePath -BackupCategory 'game'
}

Write-Output ("Installed {0} {1}. Backups, when needed, are under {2}" -f $manifest.package.name, $manifest.package.version, $backupRoot)
