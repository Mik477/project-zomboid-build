[CmdletBinding()]
param(
    [string]$LocalConfigurationPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

function Get-RelativeFilePath {
    param(
        [Parameter(Mandatory)] [string]$BasePath,
        [Parameter(Mandatory)] [string]$Path
    )

    $baseFullPath = [IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $baseUri = [Uri]$baseFullPath
    $pathUri = [Uri][IO.Path]::GetFullPath($Path)
    return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', '\')
}

if (-not $LocalConfigurationPath) {
    $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json'
}
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
if ([string]$localConfiguration.projectZomboid.exactGameVersion -ne '42.20.3' -or
    [string]$localConfiguration.steam.buildId -ne '24909800') {
    throw 'The Kahlua pool race harness is pinned to Project Zomboid 42.20.3 / Steam build 24909800.'
}

$gameJar = Join-Path ([string]$localConfiguration.projectZomboid.gamePath) 'projectzomboid.jar'
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$expectedGameJarHash = '80E405A4BFC42F6072E75B3735F458A6514143DA011D3226007DED305A442F44'
if (-not (Test-Path -LiteralPath $gameJar -PathType Leaf)) { throw "Missing game JAR: $gameJar" }
$actualGameJarHash = (Get-FileHash -LiteralPath $gameJar -Algorithm SHA256).Hash
if ($actualGameJarHash -ne $expectedGameJarHash) {
    throw "Unsupported projectzomboid.jar SHA-256: $actualGameJarHash"
}

$gameRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$java = Join-Path $gameRoot 'jre64\bin\java.exe'
if (-not (Test-Path -LiteralPath $java -PathType Leaf)) { throw "Missing game Java runtime: $java" }
$zombieBuddyJar = Join-Path $workshopRoot '3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar'
if (-not (Test-Path -LiteralPath $zombieBuddyJar -PathType Leaf)) { throw "Missing ZombieBuddy JAR: $zombieBuddyJar" }

$compilerVersion = '3.46.0'
$compilerHash = 'D0D43F8E2D7003E5EFED612E2CBB5F01870043397D8F1BBE536FD9128F4FCBF7'
$compilerUrl = "https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/$compilerVersion/ecj-$compilerVersion.jar"
$toolRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools'
$compilerJar = Join-Path $toolRoot "ecj-$compilerVersion.jar"
New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $compilerJar -PathType Leaf)) {
    Invoke-WebRequest -UseBasicParsing -Uri $compilerUrl -OutFile $compilerJar
}
$actualCompilerHash = (Get-FileHash -LiteralPath $compilerJar -Algorithm SHA256).Hash
if ($actualCompilerHash -ne $compilerHash) {
    throw "Compiler SHA-256 mismatch for $compilerJar. Expected $compilerHash, got $actualCompilerHash."
}

$testBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests'))
$testRoot = [IO.Path]::GetFullPath((Join-Path $testBase 'KahluaObjectPoolRace'))
$resolvedTestBase = $testBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $testRoot.StartsWith($resolvedTestBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a test directory outside the external test root: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

try {
    $sourcePath = Join-Path $repositoryRoot 'tests\java\KahluaObjectPoolRaceHarness.java'
    & $java '-jar' $compilerJar '-17' '-proc:none' '-encoding' 'UTF-8' '-classpath' $gameJar '-d' $testRoot $sourcePath
    if ($LASTEXITCODE -ne 0) { throw "Harness compilation failed with exit code $LASTEXITCODE." }

    & $java '-classpath' "$testRoot;$gameJar" 'pzmod.tests.KahluaObjectPoolRaceHarness' 'unguarded'
    if ($LASTEXITCODE -ne 0) { throw 'The unguarded Kahlua pool did not reproduce the expected race.' }

    & $java '-classpath' "$testRoot;$gameJar" 'pzmod.tests.KahluaObjectPoolRaceHarness' 'guarded'
    if ($LASTEXITCODE -ne 0) { throw 'The shared-lock strategy did not eliminate Kahlua pool corruption.' }

    $patchOutput = Join-Path $testRoot 'patch-output'
    & (Join-Path $PSScriptRoot 'Build-CompatibilityPatch.ps1') `
        -PatchId 'KahluaObjectPoolConcurrencyFix' `
        -DestinationModRoot $patchOutput `
        -LocalConfigurationPath $LocalConfigurationPath
    if ($LASTEXITCODE -ne 0) { throw 'The Kahlua pool patch build failed.' }

    $patchJar = Join-Path $patchOutput '42.20\media\java\common\KahluaObjectPoolConcurrencyFix.jar'
    if (-not (Test-Path -LiteralPath $patchJar -PathType Leaf)) { throw "Missing generated Kahlua patch JAR: $patchJar" }
    $relativePatchJar = Get-RelativeFilePath -BasePath (Get-Location).Path -Path $patchJar
    $agentArgument = "-javaagent:$zombieBuddyJar=patches_jar=$relativePatchJar`:pzmod.kahluapoolconcurrency,policy=allow-all"
    & $java $agentArgument '-classpath' "$testRoot;$gameJar;$zombieBuddyJar;$patchJar" `
        'pzmod.tests.KahluaObjectPoolRaceHarness' 'patched'
    if ($LASTEXITCODE -ne 0) { throw 'The generated ZombieBuddy patch did not eliminate Kahlua pool corruption.' }

    & $java $agentArgument '-classpath' "$testRoot;$gameJar;$zombieBuddyJar;$patchJar" `
        'pzmod.tests.KahluaObjectPoolRaceHarness' 'recovery'
    if ($LASTEXITCODE -ne 0) { throw 'The generated ZombieBuddy patch did not recover pre-activation pool corruption.' }

    & $java $agentArgument '-classpath' "$testRoot;$gameJar;$zombieBuddyJar;$patchJar" `
        'pzmod.tests.KahluaObjectPoolRaceHarness' 'inflight-recovery'
    if ($LASTEXITCODE -ne 0) { throw 'The generated ZombieBuddy patch did not quarantine pre-activation in-flight pool corruption.' }
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Write-Output 'Kahlua object-pool race reproduced; isolated pooling and pre-activation ownership quarantine validated.'
