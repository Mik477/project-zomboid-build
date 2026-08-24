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

$modRoot = Join-Path $repositoryRoot 'src\mods\PZPerformanceDiagnostics\42.20'
$patchPath = Join-Path $modRoot 'media\java-src\pzmod\performance\PerformanceDiagnosticsPatches.java'
$runtimePath = Join-Path $modRoot 'media\java-src\pzmod\performance\PerformanceDiagnosticsRuntime.java'
$apiPath = Join-Path $modRoot 'media\java-src\pzmod\performance\PerformanceDiagnosticsApi.java'
$luaPath = Join-Path $modRoot 'media\lua\client\PZPerformanceDiagnostics\Bootstrap.lua'
$luaEntryPath = Join-Path $modRoot 'media\lua\client\PZPerformanceDiagnostics.lua'
$modInfoPath = Join-Path $modRoot 'mod.info'
$failures = [Collections.Generic.List[string]]::new()

foreach ($path in @($patchPath, $runtimePath, $apiPath, $luaPath, $luaEntryPath, $modInfoPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing diagnostics source path: $path")
    }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$patchSource = Get-Content -LiteralPath $patchPath -Raw
$runtimeSource = Get-Content -LiteralPath $runtimePath -Raw
$apiSource = Get-Content -LiteralPath $apiPath -Raw
$luaSource = Get-Content -LiteralPath $luaPath -Raw
$luaEntrySource = Get-Content -LiteralPath $luaEntryPath -Raw
$modInfo = Get-Content -LiteralPath $modInfoPath -Raw

foreach ($expected in @(
    'id=PZPerformanceDiagnostics',
    'require=\ZombieBuddy',
    'modversion=0.1.2',
    'versionMin=42.20.3',
    'versionMax=42.20.3',
    'javaJarFile=media/java/client/PZPerformanceDiagnostics.jar',
    'ZBVersionMin=2.3.2',
    'ZBVersionMax=2.3.2'
)) {
    if (-not $modInfo.Contains($expected)) { $failures.Add("mod.info is missing: $expected") }
}

$requiredHooks = @(
    'className = "zombie.gameStates.IngameState", methodName = "update"',
    'className = "zombie.gameStates.IngameState", methodName = "render"',
    'className = "zombie.gameStates.IngameState", methodName = "UpdateStuff"',
    'className = "zombie.iso.IsoChunkMap", methodName = "ProcessChunkPos"',
    'className = "zombie.iso.IsoChunkMap", methodName = "update"',
    'className = "zombie.iso.IsoChunk", methodName = "doLoadGridsquare"',
    'className = "zombie.iso.WorldStreamer", methodName = "addJob"',
    'className = "zombie.iso.WorldStreamer", methodName = "DoChunkAlways"',
    'className = "zombie.iso.IsoChunk", methodName = "LoadChunk"',
    'className = "zombie.iso.IsoChunk", methodName = "LoadOrCreate"',
    'className = "zombie.iso.IsoChunk", methodName = "loadInWorldStreamerThread"',
    'className = "zombie.vehicles.BaseVehicle", methodName = "enter"',
    'className = "zombie.vehicles.BaseVehicle", methodName = "playPassengerAnim"',
    'className = "zombie.vehicles.BaseVehicle", methodName = "playPartAnim"',
    'className = "zombie.Lua.LuaEventManager", methodName = "triggerEvent"',
    'className = "se.krka.kahlua.vm.KahluaThread", methodName = "pcallvoid"'
)
foreach ($hook in $requiredHooks) {
    if (-not $patchSource.Contains($hook)) { $failures.Add("Missing diagnostics hook: $hook") }
}
foreach ($local in @('wallStart', 'cpuStart', 'queueBefore', 'source', 'timed')) {
    if (-not $patchSource.Contains('@Patch.Local("' + $local + '")')) {
        $failures.Add("Missing advice-local timer/correlation field: $local")
    }
}

foreach ($token in @(
    'EXPECTED_GAME_JAR_SHA256',
    'FRAME_SPIKE_MILLIS = 33.0',
    'LUA_CALLBACK_MILLIS = 2.0',
    'LOG_LINE_LIMIT = 60_000',
    'LOG_QUEUE_CAPACITY = 8_192',
    'ArrayBlockingQueue<String>',
    'queue.offer(line)',
    'Utils.getCachePath()',
    'resolve("PZPerformanceDiagnostics")',
    'PZ Performance Diagnostics Writer',
    'GarbageCollectorMXBean',
    'getCurrentThreadCpuTime',
    'slow-callback',
    'CHUNKS_QUEUED.incrementAndGet()',
    '"chunksQueued", CHUNKS_QUEUED.get()',
    'load-or-create',
    'recordChunkPhase(',
    'base-enter',
    'nearestChunkEvent',
    'jsonEscape'
)) {
    if (-not $runtimeSource.Contains($token)) { $failures.Add("Runtime is missing required token: $token") }
}
if ($runtimeSource.Contains('event("chunk", "queued"')) {
    $failures.Add('Diagnostics must count chunk enqueue operations without writing one line per initial request.')
}
if ($luaEntrySource.Trim() -ne 'require "PZPerformanceDiagnostics/Bootstrap"') {
    $failures.Add('The direct diagnostics client entrypoint must load the passive bootstrap.')
}

foreach ($method in @(
    'PZPerfDiagnostics_status',
    'PZPerfDiagnostics_marker',
    'PZPerfDiagnostics_vehicleEvent',
    'PZPerfDiagnostics_callback'
)) {
    if (-not $apiSource.Contains($method)) { $failures.Add("Lua API is missing: $method") }
}
if (-not $luaSource.Contains('PZPerformanceDiagnosticsLuaPassive = true')) {
    $failures.Add('The diagnostics Lua bootstrap is not marked passive.')
}
foreach ($forbiddenToken in @(
    'ISVehicleMenu',
    'ISTimedActionQueue',
    'ISPathFindAction',
    'ISOpenVehicleDoor',
    'ISEnterVehicle',
    'ISCloseVehicleDoor',
    'PZPerfDiagnostics_',
    'PZPerfMark',
    'Events.',
    'pcall(',
    'forceComplete',
    'forceStop'
)) {
    if ($luaSource.Contains($forbiddenToken)) {
        $failures.Add("Passive diagnostics Lua must not intercept runtime behavior: $forbiddenToken")
    }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopPath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$zombieBuddyCandidates = @(
    (Join-Path $gamePath 'ZombieBuddy.jar'),
    (Join-Path $workshopPath '3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')
)
$zombieBuddyJar = $zombieBuddyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
$compilerJar = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools\ecj-3.46.0.jar'
$testBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests'))
$testRoot = [IO.Path]::GetFullPath((Join-Path $testBase 'PZPerformanceDiagnostics'))
$resolvedTestBase = $testBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
if (-not $testRoot.StartsWith($resolvedTestBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a test directory outside the external test root: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}

try {
    $destinationModRoot = Join-Path $testRoot 'mod\PZPerformanceDiagnostics'
    & (Join-Path $PSScriptRoot 'Build-PZPerformanceDiagnostics.ps1') `
        -DestinationModRoot $destinationModRoot `
        -LocalConfigurationPath $LocalConfigurationPath

    $diagnosticsJar = Join-Path $destinationModRoot '42.20\media\java\client\PZPerformanceDiagnostics.jar'
    if (-not (Test-Path -LiteralPath $diagnosticsJar -PathType Leaf)) {
        throw "Diagnostics build did not produce the expected JAR: $diagnosticsJar"
    }
    if (-not $zombieBuddyJar) { throw 'ZombieBuddy.jar is required for the diagnostics probe.' }
    if (-not (Test-Path -LiteralPath $compilerJar -PathType Leaf)) {
        throw "Missing compiler cache after diagnostics build: $compilerJar"
    }

    $sourceRoot = Join-Path $testRoot 'source\pzmod\performance'
    $classesRoot = Join-Path $testRoot 'classes'
    New-Item -ItemType Directory -Path $sourceRoot,$classesRoot -Force | Out-Null
    $probePath = Join-Path $sourceRoot 'PerformanceDiagnosticsProbe.java'
    $probeSource = @'
package pzmod.performance;

import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.luaj.compiler.LuaCompiler;

public final class PerformanceDiagnosticsProbe {
    private PerformanceDiagnosticsProbe() {}

    public static void main(String[] args) throws Exception {
        for (String arg : args) {
            LuaCompiler.loadstring(Files.readString(Path.of(arg)), arg, null);
        }
        assertTrue("a\\\"b\\nc".equals(PerformanceDiagnosticsRuntime.jsonEscape("a\"b\nc")), "JSON escaping must preserve line framing");
        String line = PerformanceDiagnosticsRuntime.jsonLine("probe", "event", "value", 3, "ok", true);
        assertTrue(line.contains("\"category\":\"probe\"") && line.contains("\"value\":3") && line.contains("\"ok\":true"), "JSON line fields must remain typed");

        PerformanceDiagnosticsRuntime.RollingWindow window = new PerformanceDiagnosticsRuntime.RollingWindow(4);
        window.add(1.0);
        window.add(2.0);
        window.add(3.0);
        window.add(100.0);
        String summary = window.summary();
        assertTrue(summary.contains("count=4") && summary.contains("p95Ms=100.0") && summary.contains("maxMs=100.0"), "rolling summary must retain outliers");
        window.add(4.0);
        assertTrue(window.summary().contains("maxMs=100.0"), "bounded window must rotate oldest samples first");

        PerformanceDiagnosticsRuntime.DiagnosticsLog log = new PerformanceDiagnosticsRuntime.DiagnosticsLog();
        for (int i = 0; i < PerformanceDiagnosticsRuntime.LOG_QUEUE_CAPACITY + 32; ++i) {
            log.offer("{}");
        }
        assertTrue(log.queueSize() == PerformanceDiagnosticsRuntime.LOG_QUEUE_CAPACITY, "diagnostic queue must remain bounded");
        assertTrue(log.linesDropped() == 32, "overflow must be counted rather than blocking the game thread");
        assertTrue("server".equals(PerformanceDiagnosticsRuntime.classifyChunkSource(1, 2, new Object())), "server buffers must be classified without disk access");
        System.out.println("Passed passive Lua syntax, bounded logging, rolling statistics, JSON, and chunk-source probe.");
    }

    private static void assertTrue(boolean value, String message) {
        if (!value) throw new AssertionError(message);
    }
}
'@
    [IO.File]::WriteAllText($probePath, $probeSource, [Text.UTF8Encoding]::new($false))

    $classPath = "$diagnosticsJar;$gameJar;$zombieBuddyJar"
    & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $classPath -d $classesRoot $probePath
    if ($LASTEXITCODE -ne 0) { throw "Diagnostics probe compilation failed with exit code $LASTEXITCODE." }
    & $java -ea -cp "$classesRoot;$classPath" pzmod.performance.PerformanceDiagnosticsProbe $luaPath $luaEntryPath
    if ($LASTEXITCODE -ne 0) { throw "Diagnostics probe failed with exit code $LASTEXITCODE." }

    $syntheticLog = Join-Path $testRoot 'synthetic.jsonl'
    [IO.File]::WriteAllLines($syntheticLog, [string[]]@(
        '{"session":"test","elapsedMs":0,"category":"session","event":"start"}',
        '{"session":"test","elapsedMs":100,"category":"frame","event":"render-spike","wallMs":80,"intervalMs":90,"cpuMs":20,"gcMsDelta":5,"playerMode":"vehicle","vehicleSpeedKph":60,"playerChunk":"10,20","nearestChunkEvent":"main-integrate","nearestChunk":"11,20","chunkEventAgeMs":2}',
        '{"session":"test","elapsedMs":110,"category":"lua","event":"slow-callback","eventName":"OnTick","durationMs":12,"file":"media/lua/client/Test.lua","function":"tick","line":7}',
        '{"session":"test","elapsedMs":120,"category":"chunk","event":"load-or-create","chunk":"11,20","source":"disk","durationMs":45,"loaded":false,"blam":true,"error":"crc"}',
        '{"session":"test","elapsedMs":130,"category":"vehicle","event":"request","attempt":"vehicle-test","vehicleScript":"Base.CarNormal","seat":0,"action":"none","details":"queueDepth=0"}',
        '{"session":"test","elapsedMs":2400,"category":"vehicle","event":"timeout","attempt":"vehicle-test","vehicleScript":"Base.CarNormal","seat":0,"action":"ISEnterVehicle","details":"diagnosticOnly=true","bEnteringVehicle":"true","enterAnimationFinished":"false"}',
        '{"session":"test","elapsedMs":2450,"category":"vehicle","event":"base-enter","attempt":"unmatched","vehicleScript":"Base.ModernCarLightsMeadeSheriff","seat":0,"durationMs":0.12,"entered":true,"error":"none"}',
        '{"session":"test","elapsedMs":2500,"category":"marker","event":"manual","label":"fast-drive","playerMode":"vehicle","playerChunk":"11,20","vehicleScript":"Base.CarNormal","vehicleSpeedKph":80}'
    ), [Text.UTF8Encoding]::new($false))
    $summary = & (Join-Path $PSScriptRoot 'Summarize-PZPerformanceDiagnostics.ps1') -Path $syntheticLog -Top 5 | Out-String
    foreach ($requiredSummary in @('Worst frame/update/render spikes', 'Test.lua', 'load-or-create', 'vehicle-test', 'Passive vehicle observations', 'Base.ModernCarLightsMeadeSheriff', 'fast-drive')) {
        if (-not $summary.Contains($requiredSummary)) {
            throw "Diagnostics summarizer output is missing: $requiredSummary"
        }
    }
    Write-Output 'Passed synthetic diagnostics summarizer probe.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Output 'PZ Performance Diagnostics validation passed.'
