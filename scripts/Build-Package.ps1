[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [switch]$KeepStagingDirectory
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repositoryRoot 'config\modpack.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryRoot 'dist'
}

$packageName = '{0}-{1}' -f $manifest.package.id, $manifest.package.version
$stagingRoot = Join-Path $OutputDirectory ('.staging-{0}' -f $packageName)
$archivePath = Join-Path $OutputDirectory ('{0}.zip' -f $packageName)

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

Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $stagingRoot 'manifest.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Install-Package.ps1') -Destination (Join-Path $stagingRoot 'Install.ps1')

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
    elseif ($item.Name -in @('TrashAndCorpsesSafetyFix', 'SecretZCommandRegistrationFix')) {
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
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

$packageEntries = Get-ChildItem -LiteralPath $stagingRoot -Force | Select-Object -ExpandProperty FullName
Compress-Archive -LiteralPath $packageEntries -DestinationPath $archivePath -CompressionLevel Optimal

if (-not $KeepStagingDirectory) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

Write-Output "Created $archivePath"
