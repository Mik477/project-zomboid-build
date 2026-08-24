[CmdletBinding()]
param(
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

$buildPath = Join-Path $PSScriptRoot 'Build-CompatibilityPatch.ps1'
$installPath = Join-Path $PSScriptRoot 'Install-CompatibilityPatches.ps1'
$patches = @(
    @{
        Id = 'TrashAndCorpsesSafetyFix'
        Package = 'pzmod.trashandcorpsessafety'
        Classes = @('TrashAndCorpsesSafetyPatches', 'TrashAndCorpsesSafetyRuntime')
        Tokens = @('condition != 0 || !worn || !zombieOwner', 'dead || (zombieSquareMissing && sourceGridMissing)', 'AtomicBoolean')
    },
    @{
        Id = 'SecretZCommandRegistrationFix'
        Package = 'pzmod.secretzcommandregistration'
        Classes = @('SecretZCommandRegistrationPatches', 'SecretZCommandRegistrationRuntime')
        Tokens = @('TARGET_LINE = 401', 'TARGET_KEY = "DespawnDoor"', 'table instanceof KahluaTable', 'value instanceof LuaClosure')
    }
)
$failures = [Collections.Generic.List[string]]::new()

foreach ($requiredPath in @($buildPath, $installPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        $failures.Add("Missing compatibility tooling: $requiredPath")
    }
}
foreach ($patch in $patches) {
    $versionRoot = Join-Path $repositoryRoot ("src\mods\{0}\42.20" -f $patch.Id)
    $modInfoPath = Join-Path $versionRoot 'mod.info'
    if (-not (Test-Path -LiteralPath $modInfoPath -PathType Leaf)) {
        $failures.Add("Missing mod.info for $($patch.Id)")
        continue
    }
    $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
    foreach ($expected in @(
        "id=$($patch.Id)",
        'require=\ZombieBuddy',
        'modversion=0.1.0',
        'versionMin=42.20.3',
        'versionMax=42.20.3',
        "javaJarFile=media/java/common/$($patch.Id).jar",
        "javaPkgName=$($patch.Package)",
        'ZBVersionMin=2.3.2',
        'ZBVersionMax=2.3.2'
    )) {
        if (-not $modInfo.Contains($expected)) { $failures.Add("$($patch.Id) mod.info is missing: $expected") }
    }

    $javaRoot = Join-Path $versionRoot 'media\java-src'
    $javaSource = (@(Get-ChildItem -LiteralPath $javaRoot -Recurse -File -Filter '*.java') |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    foreach ($token in $patch.Tokens) {
        if (-not $javaSource.Contains($token)) { $failures.Add("$($patch.Id) source is missing: $token") }
    }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$testBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests'))
$testRoot = [IO.Path]::GetFullPath((Join-Path $testBase 'CompatibilityPatches'))
$resolvedTestBase = $testBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $testRoot.StartsWith($resolvedTestBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a test directory outside the external test root: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($patch in $patches) {
        $destinationA = Join-Path $testRoot ("build-a\{0}" -f $patch.Id)
        $destinationB = Join-Path $testRoot ("build-b\{0}" -f $patch.Id)
        & $buildPath -PatchId $patch.Id -DestinationModRoot $destinationA -LocalConfigurationPath $LocalConfigurationPath
        & $buildPath -PatchId $patch.Id -DestinationModRoot $destinationB -LocalConfigurationPath $LocalConfigurationPath

        $relativeJar = "42.20\media\java\common\{0}.jar" -f $patch.Id
        $jarA = Join-Path $destinationA $relativeJar
        $jarB = Join-Path $destinationB $relativeJar
        if (-not (Test-Path -LiteralPath $jarA -PathType Leaf) -or -not (Test-Path -LiteralPath $jarB -PathType Leaf)) {
            throw "$($patch.Id) build did not produce both expected common JARs."
        }
        $hashA = (Get-FileHash -LiteralPath $jarA -Algorithm SHA256).Hash
        $hashB = (Get-FileHash -LiteralPath $jarB -Algorithm SHA256).Hash
        if ($hashA -ne $hashB) { throw "$($patch.Id) JAR is not deterministic: $hashA differs from $hashB" }

        $archive = [IO.Compression.ZipFile]::OpenRead($jarA)
        try {
            $entryNames = @($archive.Entries | ForEach-Object FullName)
            $packagePath = $patch.Package.Replace('.', '/')
            foreach ($className in $patch.Classes) {
                $entry = "$packagePath/$className.class"
                if ($entryNames -notcontains $entry) { throw "$($patch.Id) JAR is missing entry: $entry" }
            }
            if ($entryNames -notcontains 'META-INF/MANIFEST.MF') {
                throw "$($patch.Id) JAR is missing META-INF/MANIFEST.MF"
            }
        }
        finally { $archive.Dispose() }
        Write-Output "$($patch.Id) deterministic JAR SHA-256: $hashA"
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}

Write-Output 'Split compatibility patch validation passed.'
