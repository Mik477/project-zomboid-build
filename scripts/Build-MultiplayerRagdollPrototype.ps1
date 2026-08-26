[CmdletBinding()]
param(
    [string]$DestinationModRoot,
    [string]$LocalConfigurationPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceModRoot = Join-Path $repositoryRoot 'src\mods\MultiplayerRagdollPrototype'
$sourceVersionRoot = Join-Path $sourceModRoot '42.20'
$sourceJavaRoot = Join-Path $sourceVersionRoot 'media\java-src'
$expectedGameJarHash = 'BDA809FB49004A07DBFC560D059C0EE58D0643AB0F33B53351B13BD62F1D8227'
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

if (-not $LocalConfigurationPath) {
    $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json'
}
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'config\modpack.json') -Raw | ConvertFrom-Json
if ([string]$localConfiguration.projectZomboid.exactGameVersion -ne '42.20.3') {
    throw "Prototype requires Project Zomboid 42.20.3; local configuration reports $($localConfiguration.projectZomboid.exactGameVersion)."
}
if ([string]$localConfiguration.steam.buildId -ne '24775755') {
    throw "Prototype requires Steam build 24775755; local configuration reports $($localConfiguration.steam.buildId)."
}
if ([string]$manifest.compatibility.exactGameVersion -ne '42.20.3' -or
    [string]$manifest.compatibility.steamBuildId -ne '24775755') {
    throw 'Repository compatibility metadata no longer matches the prototype target.'
}

$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
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
    (Join-Path ([string]$localConfiguration.projectZomboid.workshopPath) '3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')
)
$zombieBuddyJar = $zombieBuddyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $zombieBuddyJar) {
    throw 'ZombieBuddy.jar was not found in the game directory or Workshop item 3619862853.'
}
$actualZombieBuddyHash = (Get-FileHash -LiteralPath $zombieBuddyJar -Algorithm SHA256).Hash
if ($actualZombieBuddyHash -ne $expectedZombieBuddyHash) {
    throw "Unsupported ZombieBuddy.jar SHA-256: $actualZombieBuddyHash"
}

$toolRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools'
$buildRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\build\MultiplayerRagdollPrototype'
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
    $DestinationModRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\prototype-output\MultiplayerRagdollPrototype'
}
$DestinationModRoot = [IO.Path]::GetFullPath($DestinationModRoot)
$resolvedSourceRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'src')).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if ($DestinationModRoot.StartsWith($resolvedSourceRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to write a generated JAR below repository source: $DestinationModRoot"
}

New-Item -ItemType Directory -Path $DestinationModRoot -Force | Out-Null
Copy-Item -LiteralPath $sourceVersionRoot -Destination $DestinationModRoot -Recurse -Force
$jarDirectory = Join-Path $DestinationModRoot '42.20\media\java\client'
$jarPath = Join-Path $jarDirectory 'MultiplayerRagdollPrototype.jar'
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
