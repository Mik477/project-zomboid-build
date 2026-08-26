[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('TrashAndCorpsesSafetyFix', 'SecretZCommandRegistrationFix', 'KahluaObjectPoolConcurrencyFix', 'GaelGunStoreLootDiversification')]
    [string]$PatchId,
    [string]$DestinationModRoot,
    [string]$LocalConfigurationPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceModRoot = Join-Path (Join-Path $repositoryRoot 'src\mods') $PatchId
$sourceVersionRoot = Join-Path $sourceModRoot '42.20'
$sourceJavaRoot = Join-Path $sourceVersionRoot 'media\java-src'
$expectedGameJarHash = '80E405A4BFC42F6072E75B3735F458A6514143DA011D3226007DED305A442F44'
$expectedZombieBuddyHash = '6DD95CEDCE60F03BF8B8CEFD0D19EB156230E0D54BFFA07DE9DA5212A06C7BE6'
$compilerVersion = '3.46.0'
$compilerHash = 'D0D43F8E2D7003E5EFED612E2CBB5F01870043397D8F1BBE536FD9128F4FCBF7'
$compilerUrl = "https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/$compilerVersion/ecj-$compilerVersion.jar"

function Get-RelativeFilePath {
    param(
        [Parameter(Mandatory)] [string]$BasePath,
        [Parameter(Mandatory)] [string]$Path
    )

    $baseFullPath = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $baseUri = [Uri]$baseFullPath
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString())
}

function Assert-ReviewedWorkshopSource {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$ExpectedHash,
        [Parameter(Mandatory)] [string[]]$RequiredTokens
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required reviewed Workshop source is missing: $Path"
    }
    $actualHash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actualHash -ne $ExpectedHash) {
        throw "Reviewed Workshop source changed: $Path. Expected SHA-256 $ExpectedHash, got $actualHash. Re-audit before updating the guard."
    }
    $source = Get-Content -LiteralPath $Path -Raw
    foreach ($token in $RequiredTokens) {
        if (-not $source.Contains($token)) {
            throw "Reviewed Workshop source is missing expected token '$token': $Path"
        }
    }
}

if (-not $LocalConfigurationPath) {
    $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json'
}
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
if ([string]$localConfiguration.projectZomboid.exactGameVersion -ne '42.20.3') {
    throw "$PatchId requires Project Zomboid 42.20.3; local configuration reports $($localConfiguration.projectZomboid.exactGameVersion)."
}
if ([string]$localConfiguration.steam.buildId -ne '24909800') {
    throw "$PatchId requires Steam build 24909800; local configuration reports $($localConfiguration.steam.buildId)."
}
if ([string]$manifest.compatibility.exactGameVersion -ne '42.20.3' -or
    [string]$manifest.compatibility.steamBuildId -ne '24909800') {
    throw 'Repository compatibility metadata no longer matches the compatibility-fix target.'
}

$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopPath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
if (-not (Test-Path -LiteralPath $gameJar -PathType Leaf)) { throw "Missing game JAR: $gameJar" }
if (-not (Test-Path -LiteralPath $java -PathType Leaf)) { throw "Missing game Java runtime: $java" }

$actualGameJarHash = (Get-FileHash -LiteralPath $gameJar -Algorithm SHA256).Hash
if ($actualGameJarHash -ne $expectedGameJarHash) {
    throw "Unsupported projectzomboid.jar SHA-256: $actualGameJarHash"
}

$zombieBuddyCandidates = @(
    (Join-Path $gamePath 'ZombieBuddy.jar'),
    (Join-Path $workshopPath '3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')
)
$zombieBuddyJar = $zombieBuddyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $zombieBuddyJar) {
    throw 'ZombieBuddy.jar was not found in the game directory or Workshop item 3619862853.'
}
$actualZombieBuddyHash = (Get-FileHash -LiteralPath $zombieBuddyJar -Algorithm SHA256).Hash
if ($actualZombieBuddyHash -ne $expectedZombieBuddyHash) {
    throw "Unsupported ZombieBuddy.jar SHA-256: $actualZombieBuddyHash"
}

switch ($PatchId) {
    'TrashAndCorpsesSafetyFix' {
        Assert-ReviewedWorkshopSource `
            -Path (Join-Path $workshopPath '3662273535\mods\Trash and Corpses\42\media\lua\shared\ScatteredTrashes.lua') `
            -ExpectedHash '556A46A87DCC9CF704FB65F991C5CD44396CCCEC0016442DD66776578AE8B6DB' `
            -RequiredTokens @('local function degradeWornItems', 'degradeWornItems(zombie, 5, 45)', 'item:setCondition(math.max(0, math.floor(max * pct / 100)))')
    }
    'SecretZCommandRegistrationFix' {
        Assert-ReviewedWorkshopSource `
            -Path (Join-Path $workshopPath '3494374578\mods\Secretz42\42.20\media\lua\server\SZDoors\SZCServer.lua') `
            -ExpectedHash '8CDC2C1DC0DFB191D1E4A46B0C4E76DEC4816198E27A3E560E3C053485FB4838' `
            -RequiredTokens @('Commands["DespawnDoor"] = handleDespawnDoorCommand', 'Events.OnClientCommand.Add(onClientCommand)', 'Events.OnTick.Add(updateTimers)')
    }
}

$toolRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools'
$buildRoot = Join-Path $env:LOCALAPPDATA ("project-zomboid-build\build\{0}" -f $PatchId)
$compilerJar = Join-Path $toolRoot "ecj-$compilerVersion.jar"
$classesRoot = Join-Path $buildRoot 'classes'
New-Item -ItemType Directory -Path $toolRoot,$buildRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath $compilerJar -PathType Leaf)) {
    Write-Output "Downloading Eclipse compiler $compilerVersion to the external tool cache."
    Invoke-WebRequest -UseBasicParsing -Uri $compilerUrl -OutFile $compilerJar
}
$actualCompilerHash = (Get-FileHash -LiteralPath $compilerJar -Algorithm SHA256).Hash
if ($actualCompilerHash -ne $compilerHash) {
    throw "Compiler SHA-256 mismatch for $compilerJar. Expected $compilerHash, got $actualCompilerHash."
}

$resolvedBuildRoot = [IO.Path]::GetFullPath($buildRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$resolvedClassesRoot = [IO.Path]::GetFullPath($classesRoot)
if (-not $resolvedClassesRoot.StartsWith($resolvedBuildRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to clean classes outside the external build root: $resolvedClassesRoot"
}
if (Test-Path -LiteralPath $classesRoot) {
    Remove-Item -LiteralPath $classesRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $classesRoot -Force | Out-Null

$javaSources = @(Get-ChildItem -LiteralPath $sourceJavaRoot -Recurse -File -Filter '*.java' | Sort-Object FullName)
if ($javaSources.Count -eq 0) {
    throw "No Java sources found under $sourceJavaRoot"
}

$classPath = "$gameJar;$zombieBuddyJar"
$compilerArguments = @(
    '-jar', $compilerJar,
    '-17',
    '-proc:none',
    '-encoding', 'UTF-8',
    '-classpath', $classPath,
    '-d', $classesRoot
) + $javaSources.FullName

& $java @compilerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Java compilation failed with exit code $LASTEXITCODE."
}

$manifestDirectory = Join-Path $classesRoot 'META-INF'
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
[IO.File]::WriteAllText(
    (Join-Path $manifestDirectory 'MANIFEST.MF'),
    "Manifest-Version: 1.0`r`nCreated-By: project-zomboid-build`r`n`r`n",
    [Text.Encoding]::ASCII)

if (-not $DestinationModRoot) {
    $DestinationModRoot = Join-Path $env:LOCALAPPDATA ("project-zomboid-build\prototype-output\{0}" -f $PatchId)
}
$DestinationModRoot = [IO.Path]::GetFullPath($DestinationModRoot)
$resolvedSourceRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'src')).TrimEnd('\', '/')
$resolvedSourcePrefix = $resolvedSourceRoot + [IO.Path]::DirectorySeparatorChar
if ($DestinationModRoot.Equals($resolvedSourceRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $DestinationModRoot.StartsWith($resolvedSourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write a generated JAR below repository source: $DestinationModRoot"
}

New-Item -ItemType Directory -Path $DestinationModRoot -Force | Out-Null
Copy-Item -LiteralPath $sourceVersionRoot -Destination $DestinationModRoot -Recurse -Force
$jarDirectory = Join-Path $DestinationModRoot '42.20\media\java\common'
$jarPath = Join-Path $jarDirectory ("{0}.jar" -f $PatchId)
New-Item -ItemType Directory -Path $jarDirectory -Force | Out-Null
if (Test-Path -LiteralPath $jarPath) {
    Remove-Item -LiteralPath $jarPath -Force
}

Add-Type -AssemblyName System.IO.Compression
$jarStream = [IO.File]::Open($jarPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $archive = [IO.Compression.ZipArchive]::new($jarStream, [IO.Compression.ZipArchiveMode]::Create, $false)
    try {
        $fixedTimestamp = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        foreach ($file in Get-ChildItem -LiteralPath $classesRoot -Recurse -File | Sort-Object FullName) {
            $relativePath = Get-RelativeFilePath -BasePath $classesRoot -Path $file.FullName
            $entry = $archive.CreateEntry($relativePath, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = $fixedTimestamp
            $input = [IO.File]::OpenRead($file.FullName)
            $output = $entry.Open()
            try {
                $input.CopyTo($output)
            }
            finally {
                $output.Dispose()
                $input.Dispose()
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    $jarStream.Dispose()
}

$jarHash = (Get-FileHash -LiteralPath $jarPath -Algorithm SHA256).Hash
Write-Output "Built $jarPath"
Write-Output "JAR SHA-256: $jarHash"
