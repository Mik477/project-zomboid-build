[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Status', 'ToLocal', 'FromLocal')]
    [string]$Direction = 'Status',
    [string[]]$Mod,
    [switch]$IncludeGameOverrides,
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
$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
$backupRoot = Join-Path $localConfiguration.projectZomboid.userPath ('Backups\project-zomboid-build\sync-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$results = [Collections.Generic.List[object]]::new()

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

function Assert-ChildPath {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Path
    )

    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $resolvedPath = [IO.Path]::GetFullPath($Path)
    if (-not $resolvedPath.StartsWith($resolvedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path escapes its managed root: $resolvedPath"
    }
}

function Test-ExcludedFile {
    param([Parameter(Mandatory)] [string]$RelativePath)

    $segments = $RelativePath -split '[\\/]'
    if ([IO.Path]::GetFileName($RelativePath) -eq '.gitkeep') { return $true }
    if ($segments -contains '.git' -or $segments -contains 'Logs' -or $segments -contains 'Saves' -or $segments -contains 'db') { return $true }
    $extension = [IO.Path]::GetExtension($RelativePath).ToLowerInvariant()
    return $extension -in @('.db', '.sqlite', '.sqlite3', '.log', '.dmp', '.zip', '.7z', '.rar', '.exe', '.dll', '.jar', '.class')
}

function Get-FileMap {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [AllowEmptyCollection()] [string[]]$OnlyRelativePaths
    )

    $map = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return $map }
    if ($PSBoundParameters.ContainsKey('OnlyRelativePaths')) {
        foreach ($relativePath in $OnlyRelativePaths) {
            $path = Join-Path $Root $relativePath
            Assert-ChildPath -Root $Root -Path $path
            if (Test-Path -LiteralPath $path -PathType Leaf) { $map[$relativePath] = $path }
        }
        return $map
    }
    foreach ($file in Get-ChildItem -LiteralPath $Root -File -Recurse -Force) {
        $relativePath = Get-RelativeFilePath -BasePath $Root -Path $file.FullName
        if (-not (Test-ExcludedFile -RelativePath $relativePath)) { $map[$relativePath] = $file.FullName }
    }
    return $map
}

function Get-FileState {
    param([string]$RepositoryPath, [string]$LocalPath)

    if (-not $RepositoryPath) { return 'LocalOnly' }
    if (-not $LocalPath) { return 'RepositoryOnly' }
    $repositoryHash = (Get-FileHash -LiteralPath $RepositoryPath -Algorithm SHA256).Hash
    $localHash = (Get-FileHash -LiteralPath $LocalPath -Algorithm SHA256).Hash
    if ($repositoryHash -eq $localHash) { return 'Same' }
    return 'Different'
}

function Copy-ManagedFile {
    param(
        [Parameter(Mandatory)] [string]$SourcePath,
        [Parameter(Mandatory)] [string]$DestinationPath,
        [Parameter(Mandatory)] [string]$RelativePath,
        [Parameter(Mandatory)] [string]$BackupCategory
    )

    if (-not $PSCmdlet.ShouldProcess($DestinationPath, "Copy managed file from $Direction")) { return }
    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        $backupPath = Join-Path (Join-Path $backupRoot $BackupCategory) $RelativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
        Copy-Item -LiteralPath $DestinationPath -Destination $backupPath -Force
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $DestinationPath) -Force | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
}

function Sync-Tree {
    param(
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [string]$RepositoryTreeRoot,
        [Parameter(Mandatory)] [string]$LocalRoot,
        [switch]$RepositoryDefinesScope
    )

    Assert-ChildPath -Root $repositoryRoot -Path $RepositoryTreeRoot
    $repositoryFiles = Get-FileMap -Root $RepositoryTreeRoot
    $localFiles = if ($RepositoryDefinesScope) {
        Get-FileMap -Root $LocalRoot -OnlyRelativePaths @($repositoryFiles.Keys)
    }
    else {
        Get-FileMap -Root $LocalRoot
    }
    $relativePaths = @($repositoryFiles.Keys) + @($localFiles.Keys) | Sort-Object -Unique
    foreach ($relativePath in $relativePaths) {
        $repositoryPath = $repositoryFiles[$relativePath]
        $localPath = $localFiles[$relativePath]
        $state = Get-FileState -RepositoryPath $repositoryPath -LocalPath $localPath
        if ($state -ne 'Same') {
            $results.Add([PSCustomObject]@{Target=$Name; State=$state; Path=$relativePath})
        }
        if ($Direction -eq 'ToLocal' -and $repositoryPath -and $state -ne 'Same') {
            $destinationPath = Join-Path $LocalRoot $relativePath
            Assert-ChildPath -Root $LocalRoot -Path $destinationPath
            Copy-ManagedFile -SourcePath $repositoryPath -DestinationPath $destinationPath -RelativePath (Join-Path $Name $relativePath) -BackupCategory 'local'
        }
        elseif ($Direction -eq 'FromLocal' -and $localPath -and $state -ne 'Same') {
            $destinationPath = Join-Path $RepositoryTreeRoot $relativePath
            Assert-ChildPath -Root $RepositoryTreeRoot -Path $destinationPath
            Copy-ManagedFile -SourcePath $localPath -DestinationPath $destinationPath -RelativePath (Join-Path $Name $relativePath) -BackupCategory 'repository'
        }
    }
}

$modSourceRoot = Join-Path $repositoryRoot 'src\mods'
$availableMods = @(Get-ChildItem -LiteralPath $modSourceRoot -Directory -Force | Where-Object Name -ne '.git')
if ($Mod) {
    foreach ($modName in $Mod) {
        if ($modName -match '[\\/]' -or $modName -in @('.', '..')) { throw "Invalid managed mod directory name: $modName" }
    }
    $availableMods = @($availableMods | Where-Object Name -in $Mod)
    $missingMods = @($Mod | Where-Object { $_ -notin $availableMods.Name })
    if ($missingMods.Count -gt 0) { throw "These mods do not exist under src/mods: $($missingMods -join ', ')" }
}
foreach ($managedMod in $availableMods) {
    $localModRoot = Join-Path (Join-Path $localConfiguration.projectZomboid.userPath 'mods') $managedMod.Name
    Sync-Tree -Name (Join-Path 'mods' $managedMod.Name) -RepositoryTreeRoot $managedMod.FullName -LocalRoot $localModRoot
}

if ($IncludeGameOverrides) {
    if ([string]$localConfiguration.steam.buildId -ne [string]$manifest.compatibility.steamBuildId) {
        throw "Game override sync is version-gated. Local Steam build $($localConfiguration.steam.buildId) does not match manifest build $($manifest.compatibility.steamBuildId)."
    }
    Sync-Tree -Name 'game-overrides' -RepositoryTreeRoot (Join-Path $repositoryRoot 'src\game-overrides') -LocalRoot $localConfiguration.projectZomboid.gamePath -RepositoryDefinesScope
}

if ($results.Count -eq 0) {
    Write-Output 'Managed files are in sync.'
}
else {
    $results | Sort-Object Target, Path | Format-Table -AutoSize
}
if ($Direction -ne 'Status') {
    Write-Output 'Sync is additive: files absent from the source were not deleted.'
    Write-Output "Replaced files were backed up under $backupRoot when changes were applied."
}
