[CmdletBinding()]
param([string]$LocalConfigurationPath)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $LocalConfigurationPath) { $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json' }
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$compilerJar = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools\ecj-3.46.0.jar'
$expectedGameJarHash = 'BDA809FB49004A07DBFC560D059C0EE58D0643AB0F33B53351B13BD62F1D8227'
$expectedCompilerHash = 'D0D43F8E2D7003E5EFED612E2CBB5F01870043397D8F1BBE536FD9128F4FCBF7'
if ([string]$localConfiguration.projectZomboid.exactGameVersion -ne '42.20.3' -or
    [string]$localConfiguration.steam.buildId -ne '24775755') {
    throw 'Focused Lua patch validation requires Project Zomboid 42.20.3, Steam build 24775755.'
}
foreach ($toolPath in @($gameJar, $java, $compilerJar)) {
    if (-not (Test-Path -LiteralPath $toolPath -PathType Leaf)) { throw "Missing Lua validation tool: $toolPath" }
}
$actualGameJarHash = (Get-FileHash -LiteralPath $gameJar -Algorithm SHA256).Hash
if ($actualGameJarHash -ne $expectedGameJarHash) { throw "Unsupported projectzomboid.jar SHA-256: $actualGameJarHash" }
$actualCompilerHash = (Get-FileHash -LiteralPath $compilerJar -Algorithm SHA256).Hash
if ($actualCompilerHash -ne $expectedCompilerHash) { throw "Unsupported ECJ compiler SHA-256: $actualCompilerHash" }
$mods = @(
    @{ Id='TYLIndoorBushFix'; RelativeSource='media\lua\server\TYLIndoorBushFix.lua'; Tokens=@('Fix.guardSpawnBush', 'modData.TYLBush == true', 'square:RemoveTileObject(object)') },
    @{ Id='PZExporterCadenceTuning'; RelativeSource='media\lua\client\PZExporterCadenceTuning.lua'; Tokens=@('MINIMUM_INTERVAL_MS = 1000', 'PZ_Map', 'PZ_Pulse') },
    @{ Id='KnownAndCollectedInventoryTetrisCompatibility'; RelativeSource='media\lua\client\KnownAndCollectedInventoryTetrisCompatibility.lua'; Tokens=@('HANDLER_SOURCE = "knownandcollectedrenderhandler.lua"', 'TetrisEvents.OnPostRenderGrid._eventHandlers', 'instanceof(item, "Literature")', 'instruction[9] = true', 'instruction[9] = false') },
    @{ Id='VASRemoteDoorSyncFix'; RelativeSource='media\lua\client\VASRemoteDoorSyncFix.lua'; Tokens=@('module ~= "VAS_Sync"', 'command ~= "doorStatus"', 'door:setOpen(false)') }
)
$failures = [Collections.Generic.List[string]]::new()
$luaPaths = @()

foreach ($mod in $mods) {
    $versionRoot = Join-Path $repositoryRoot ("src\mods\{0}\42.20" -f $mod.Id)
    $modInfoPath = Join-Path $versionRoot 'mod.info'
    $sourcePath = Join-Path $versionRoot $mod.RelativeSource
    foreach ($path in @($modInfoPath, $sourcePath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing focused Lua patch path: $path") }
    }
    if (-not (Test-Path -LiteralPath $modInfoPath -PathType Leaf) -or -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { continue }
    $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
    foreach ($expected in @("id=$($mod.Id)", 'modversion=0.1.0', 'versionMin=42.20.3', 'versionMax=42.20.3')) {
        if (-not $modInfo.Contains($expected)) { $failures.Add("$($mod.Id) mod.info is missing: $expected") }
    }
    if ($modInfo.Contains('javaJarFile=') -or $modInfo.Contains('javaPkgName=')) {
        $failures.Add("$($mod.Id) must remain Lua-only.")
    }
    $source = Get-Content -LiteralPath $sourcePath -Raw
    foreach ($token in $mod.Tokens) {
        if (-not $source.Contains($token)) { $failures.Add("$($mod.Id) source is missing: $token") }
    }
    $luaPaths += $sourcePath
}

$upstream = @(
    @{ Name='TYL'; Path=(Join-Path $workshopRoot '3781486512\mods\UNOFFICIAL_42_STABLE_TYL\42\media\lua\server\TYL_TREEGENERATOR\TYL_TREEGENERATOR_SERVER.lua'); Hash='C25939E74390E9659353BDCC12C2EDB91E7096F26A91E45289363A3229F7F9E2'; Tokens=@('Events.OnPlayerUpdate.Add(TYL_ProcessPlayerRadius)','Events.LoadGridsquare.Add(LoadGridsquare)','TYL_SpawnBush = function(square)') },
    @{ Name='PZ Map'; Path=(Join-Path $workshopRoot '3770149036\mods\PZ_Map\42\media\lua\client\PZ_Map.lua'); Hash='B14098A80CF33BB70E0DDA7471155B9AAE06CD24EA25F289AFD5C3079FFCB2AB'; Tokens=@('function PM.updateMs()') },
    @{ Name='PZ Pulse'; Path=(Join-Path $workshopRoot '3753700423\mods\PZ_Pulse\42\media\lua\client\PZ_Pulse.lua'); Hash='CB63C111662F1779BE5D98C3FC7A03BD0AEFD8904876A5578B946BA908E3EAAF'; Tokens=@('function PC.updateMs()') },
    @{ Name='VAS'; Path=(Join-Path $workshopRoot '3685499657\mods\VASinked\42\media\lua\client\VAS_CCommands.lua'); Hash='018202DF853BE6D34111EB4798EBAF24F94559C1DD750164494668E466854EAE'; Tokens=@('vehicle:playPartAnim(part, "Close")','part:getDoor():setOpen(true)') },
    @{ Name='Inventory Tetris KnownAndCollected'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\EventHandlers\KnownAndCollectedRenderHandler.lua'); Hash='DE62E438B99D5C5999249AFBCED16C552C159F0E64CC7A95A28D025B3FC77DD2'; Tokens=@('local recipes = item:getTeachedRecipes()','TetrisEvents.OnPostRenderGrid:add(KnownAndCollectedRenderer)') }
)
foreach ($item in $upstream) {
    if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) { $failures.Add("Missing reviewed upstream: $($item.Name)"); continue }
    $actual = (Get-FileHash -LiteralPath $item.Path -Algorithm SHA256).Hash
    if ($actual -ne $item.Hash) { $failures.Add("Reviewed upstream changed for $($item.Name): $actual"); continue }
    $text = Get-Content -LiteralPath $item.Path -Raw
    foreach ($token in $item.Tokens) { if (-not $text.Contains($token)) { $failures.Add("$($item.Name) seam changed: $token") } }
}

$testRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests\FocusedLuaPatches'
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
try {
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $syntaxPath = Join-Path $testRoot 'LuaSyntaxProbe.java'
    $syntax = @'
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
public final class LuaSyntaxProbe {
    public static void main(String[] args) throws Exception {
        for (String arg : args) LuaCompiler.loadstring(Files.readString(Path.of(arg)), arg, null);
        System.out.println("Lua syntax passed.");
    }
}
'@
    [IO.File]::WriteAllText($syntaxPath, $syntax, [Text.UTF8Encoding]::new($false))
    & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $testRoot $syntaxPath
    if ($LASTEXITCODE -ne 0) { throw "Lua syntax probe compilation failed: $LASTEXITCODE" }
    & $java -cp "$testRoot;$gameJar" LuaSyntaxProbe @luaPaths
    if ($LASTEXITCODE -ne 0) { throw "Lua syntax probe failed: $LASTEXITCODE" }
}
catch { $failures.Add("Executable Lua patch probe failed: $($_.Exception.Message)") }
finally { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } }

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output 'Focused Lua patch validation passed.'
