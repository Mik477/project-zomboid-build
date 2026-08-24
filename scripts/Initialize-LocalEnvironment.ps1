[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$OutputPath,
    [string]$ServerProfilePath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $repositoryRoot 'config\local.json'
}

function Get-AcfValue {
    param(
        [Parameter(Mandatory)] [string]$Text,
        [Parameter(Mandatory)] [string]$Name
    )

    $match = [regex]::Match($Text, '(?im)^\s*"' + [regex]::Escape($Name) + '"\s+"([^"]*)"')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

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
            $steamRoots.Add([IO.Path]::GetFullPath($properties.$propertyName))
        }
    }
}

$steamRoots = @($steamRoots | Sort-Object -Unique)
if ($steamRoots.Count -eq 0) {
    throw 'Steam was not found in the current user or machine registry.'
}

$installation = $null
foreach ($steamRoot in $steamRoots) {
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
        $appManifestPath = Join-Path $libraryRoot 'steamapps\appmanifest_108600.acf'
        if (-not (Test-Path -LiteralPath $appManifestPath -PathType Leaf)) { continue }
        $manifestText = Get-Content -LiteralPath $appManifestPath -Raw
        $installDirectory = Get-AcfValue -Text $manifestText -Name 'installdir'
        $gamePath = Join-Path $libraryRoot (Join-Path 'steamapps\common' $installDirectory)
        if (-not (Test-Path -LiteralPath $gamePath -PathType Container)) { continue }
        $installation = [PSCustomObject]@{
            SteamRoot = $steamRoot
            AppManifestPath = $appManifestPath
            BuildId = Get-AcfValue -Text $manifestText -Name 'buildid'
            GamePath = $gamePath
            WorkshopPath = Join-Path $libraryRoot 'steamapps\workshop\content\108600'
        }
        break
    }
    if ($installation) { break }
}

if (-not $installation) {
    throw 'Project Zomboid (Steam app 108600) was not found in any configured Steam library.'
}

$zomboidUserPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Zomboid'
if (-not (Test-Path -LiteralPath $zomboidUserPath -PathType Container)) {
    throw 'The current user does not have a Project Zomboid user-data directory.'
}

$logCandidates = [Collections.Generic.List[IO.FileInfo]]::new()
foreach ($logName in @('console.txt', 'coop-console.txt')) {
    $logPath = Join-Path $zomboidUserPath $logName
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        $logCandidates.Add((Get-Item -LiteralPath $logPath))
    }
}
foreach ($logFile in Get-ChildItem -LiteralPath (Join-Path $zomboidUserPath 'Logs') -File -Recurse -ErrorAction SilentlyContinue) {
    $logCandidates.Add($logFile)
}
$exactGameVersionText = $null
foreach ($logFile in ($logCandidates | Sort-Object LastWriteTime -Descending)) {
    $fileVersionCandidates = [Collections.Generic.List[version]]::new()
    foreach ($line in Get-Content -LiteralPath $logFile.FullName -ErrorAction SilentlyContinue) {
        $match = [regex]::Match($line, '(?i)\bversion=(42\.\d+(?:\.\d+)?)\b')
        if ($match.Success) {
            $fileVersionCandidates.Add([version]$match.Groups[1].Value)
        }
    }
    if ($fileVersionCandidates.Count -gt 0) {
        $exactGameVersionText = ($fileVersionCandidates | Sort-Object -Descending | Select-Object -First 1).ToString()
        break
    }
}
if (-not $exactGameVersionText) {
    Write-Warning 'The exact game version could not be recovered from local logs. Start the game once, then rerun this script.'
    $exactGameVersionText = 'UNKNOWN'
}

if ($ServerProfilePath) {
    $ServerProfilePath = [IO.Path]::GetFullPath($ServerProfilePath)
    if (-not (Test-Path -LiteralPath $ServerProfilePath -PathType Leaf)) {
        throw "Server profile does not exist: $ServerProfilePath"
    }
}
else {
    $profiles = @(Get-ChildItem -LiteralPath (Join-Path $zomboidUserPath 'Server') -Filter '*.ini' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($profiles.Count -gt 0) {
        $ServerProfilePath = $profiles[0].FullName
        if ($profiles.Count -gt 1) {
            Write-Warning 'Multiple server profiles were found; the most recently modified profile was selected. Rerun with -ServerProfilePath to choose explicitly.'
        }
    }
}

$localConfiguration = [ordered]@{
    schemaVersion = 1
    steam = [ordered]@{
        root = $installation.SteamRoot
        appManifestPath = $installation.AppManifestPath
        buildId = $installation.BuildId
    }
    projectZomboid = [ordered]@{
        gamePath = $installation.GamePath
        userPath = $zomboidUserPath
        workshopPath = $installation.WorkshopPath
        exactGameVersion = $exactGameVersionText
        serverProfilePath = $ServerProfilePath
    }
}

if ($PSCmdlet.ShouldProcess($OutputPath, 'Write ignored local Project Zomboid configuration')) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputPath) -Force | Out-Null
    $localConfiguration | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
}

$workshopItemCount = 0
if (Test-Path -LiteralPath $installation.WorkshopPath -PathType Container) {
    $workshopItemCount = @(Get-ChildItem -LiteralPath $installation.WorkshopPath -Directory).Count
}

[PSCustomObject]@{
    GameVersion = $exactGameVersionText
    SteamBuildId = $installation.BuildId
    InstalledWorkshopItems = $workshopItemCount
    ServerProfileSelected = [bool]$ServerProfilePath
    LocalConfiguration = $OutputPath
}
