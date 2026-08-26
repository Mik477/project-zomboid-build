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
$observerPath = Join-Path $modRoot 'media\lua\client\PZPerformanceDiagnostics\VehicleQueueObserver.lua'
$luaEntryPath = Join-Path $modRoot 'media\lua\client\PZPerformanceDiagnostics.lua'
$modInfoPath = Join-Path $modRoot 'mod.info'
$observerTestPath = Join-Path $repositoryRoot 'tests\PZPerformanceVehicleObserver.test.lua'
$failures = [Collections.Generic.List[string]]::new()

foreach ($path in @($patchPath, $runtimePath, $apiPath, $luaPath, $observerPath, $luaEntryPath, $modInfoPath, $observerTestPath)) {
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
$observerSource = Get-Content -LiteralPath $observerPath -Raw
$luaEntrySource = Get-Content -LiteralPath $luaEntryPath -Raw
$modInfo = Get-Content -LiteralPath $modInfoPath -Raw

foreach ($expected in @(
    'id=PZPerformanceDiagnostics',
    'require=\ZombieBuddy',
    'modversion=0.2.0',
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
    'className = "zombie.vehicles.BaseVehicle", methodName = "playPartAnim"'
)
foreach ($hook in $requiredHooks) {
    if (-not $patchSource.Contains($hook)) { $failures.Add("Missing diagnostics hook: $hook") }
}
foreach ($local in @('wallStart', 'cpuStart', 'queueBefore', 'source')) {
    if (-not $patchSource.Contains('@Patch.Local("' + $local + '")')) {
        $failures.Add("Missing advice-local timer/correlation field: $local")
    }
}

foreach ($token in @(
    'EXPECTED_GAME_JAR_SHA256',
    'FRAME_SPIKE_MILLIS = 33.0',
    'LOG_LINE_LIMIT = 60_000',
    'LOG_QUEUE_CAPACITY = 8_192',
    'ACTION_EVENT_LIMIT = 10_000',
    'ACTION_DETAILS_LIMIT = 1_024',
    'ArrayBlockingQueue<String>',
    'queue.offer(line)',
    'Utils.getCachePath()',
    'resolve("PZPerformanceDiagnostics")',
    'PZ Performance Diagnostics Writer',
    'GarbageCollectorMXBean',
    'getCurrentThreadCpuTime',
    'CHUNKS_QUEUED.incrementAndGet()',
    '"chunksQueued", CHUNKS_QUEUED.get()',
    'load-or-create',
    'recordChunkPhase(',
    'base-enter',
    'nearestChunkEvent',
    'jsonEscape',
    'event("action"',
    '"actionEvents", ACTION_EVENTS.get()'
)) {
    if (-not $runtimeSource.Contains($token)) { $failures.Add("Runtime is missing required token: $token") }
}
if ($runtimeSource.Contains('event("chunk", "queued"')) {
    $failures.Add('Diagnostics must count chunk enqueue operations without writing one line per initial request.')
}
foreach ($forbiddenHook in @(
    'zombie.Lua.LuaEventManager',
    'se.krka.kahlua.vm.KahluaThread',
    'LuaCaller',
    'ReturnValues',
    'MethodArguments',
    'zombie.characters.CharacterTimedActions',
    'ISBaseTimedAction',
    'ISTimedActionQueue'
)) {
    if ($patchSource.Contains($forbiddenHook)) {
        $failures.Add("Diagnostics must not patch universal Lua/Kahlua or Java timed-action execution: $forbiddenHook")
    }
}
foreach ($forbiddenRuntimeToken in @(
    'enterLuaEvent',
    'exitLuaEvent',
    'shouldTimeLuaCallback',
    'recordLuaCallback',
    'LUA_EVENTS',
    'LUA_SLOW_CALLBACKS'
)) {
    if ($runtimeSource.Contains($forbiddenRuntimeToken)) {
        $failures.Add("Diagnostics must not retain universal Lua callback timing state: $forbiddenRuntimeToken")
    }
}
if ($luaEntrySource.Trim() -ne 'require "PZPerformanceDiagnostics/Bootstrap"') {
    $failures.Add('The direct diagnostics client entrypoint must load the observer-only bootstrap.')
}

foreach ($method in @(
    'PZPerfDiagnostics_status',
    'PZPerfDiagnostics_marker',
    'PZPerfDiagnostics_vehicleEvent',
    'PZPerfDiagnostics_actionEvent',
    'PZPerfDiagnostics_callback'
)) {
    if (-not $apiSource.Contains($method)) { $failures.Add("Lua API is missing: $method") }
}
if (-not $luaSource.Contains('require "PZPerformanceDiagnostics/VehicleQueueObserver"') -or
        -not $luaSource.Contains('PZPerformanceDiagnosticsLuaObserverOnly = true')) {
    $failures.Add('The diagnostics Lua bootstrap must load and clearly mark the observer-only queue module.')
}
foreach ($requiredObserverToken in @(
    'ISTimedActionQueue.queues',
    'isLocalPlayer',
    'goal[1] == "VehicleSeat"',
    'ISEnterVehicle',
    'ISExitVehicle',
    'Events.OnTick.Add',
    'Events.OnEnterVehicle.Add',
    'Events.OnExitVehicle.Add',
    'PZPerfDiagnostics_vehicleEvent',
    'MAX_EVENTS_PER_ATTEMPT = 32',
    'ATTEMPT_TTL_MS = 45000',
    'STALL_THRESHOLDS_MS = { 2000, 5000, 15000 }',
    'queueShape=',
    'nativeAction=',
    'started=',
    'EnterAnimationFinished',
    'ExitAnimationFinished',
    'seatState=',
    'doorOpen='
)) {
    if (-not $observerSource.Contains($requiredObserverToken)) {
        $failures.Add("Vehicle queue observer is missing required token: $requiredObserverToken")
    }
}
foreach ($assignmentPattern in @(
    '(?m)^\s*(?:ISVehicleMenu|ISTimedActionQueue|ISPathFindAction|ISOpenVehicleDoor|ISCloseVehicleDoor|ISEnterVehicle|ISExitVehicle)\s*(?<![~<>])=(?!=)',
    '(?m)\b(?:ISVehicleMenu|ISTimedActionQueue|ISPathFindAction|ISOpenVehicleDoor|ISCloseVehicleDoor|ISEnterVehicle|ISExitVehicle)\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\r\n]+\])\s*(?<![~<>])=(?!=)',
    '(?m)\b(?:action|queue|vehicle)\s*(?:\.\s*[A-Za-z_]\w*|\[[^\]\r\n]+\])\s*(?<![~<>])=(?!=)',
    '(?i)\b(?:rawset|setmetatable)\s*\(\s*(?:ISVehicleMenu|ISTimedActionQueue|ISPathFindAction|ISOpenVehicleDoor|ISCloseVehicleDoor|ISEnterVehicle|ISExitVehicle)\b'
)) {
    if ($observerSource -match $assignmentPattern) {
        $failures.Add("Vehicle queue observer must not assign to game classes, actions, queues, or vehicles: $assignmentPattern")
    }
}
foreach ($privateToken in @('getUsername', 'getAccessLevel', 'getIPAddress', 'getServerAddress')) {
    if ($observerSource.Contains($privateToken)) {
        $failures.Add("Vehicle queue observer must not collect private identity or address data: $privateToken")
    }
}
foreach ($dangerousCall in @('getJobDelta', 'begin', 'start', 'update', 'isValid', 'forceComplete', 'forceStop')) {
    $directCallPattern = '(?i)(?:\.|:)\s*' + [regex]::Escape($dangerousCall) + '\s*\('
    $indirectCallPattern = '(?i)["'']' + [regex]::Escape($dangerousCall) + '["'']'
    if ($observerSource -match $directCallPattern -or $observerSource -match $indirectCallPattern) {
        $failures.Add("Vehicle queue observer must not invoke timed-action lifecycle method: $dangerousCall")
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
        assertTrue(PerformanceDiagnosticsRuntime.boundedText("abcdef", 4).equals("abcd"), "generic action details must be bounded");

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
        System.out.println("Passed observer-only Lua syntax, bounded logging/action fields, rolling statistics, JSON, and chunk-source probe.");
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
    & $java -ea -cp "$classesRoot;$classPath" pzmod.performance.PerformanceDiagnosticsProbe $luaPath $observerPath $luaEntryPath $observerTestPath
    if ($LASTEXITCODE -ne 0) { throw "Diagnostics probe failed with exit code $LASTEXITCODE." }

    $runtimeProbePath = Join-Path $sourceRoot 'LuaRuntimeProbe.java'
    $runtimeProbeSource = @'
package pzmod.performance;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.JavaFunction;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaCallFrame;
import se.krka.kahlua.vm.LuaClosure;

public final class LuaRuntimeProbe {
    private static final class Require implements JavaFunction {
        private final Path moduleRoot;
        private final KahluaTable environment;
        private final KahluaTable preload;
        private final Map<String, Object> loaded = new HashMap<>();

        Require(Path repositoryRoot, KahluaTable environment, KahluaTable preload) {
            this.moduleRoot = repositoryRoot.resolve(
                    "src/mods/PZPerformanceDiagnostics/42.20/media/lua/client");
            this.environment = environment;
            this.preload = preload;
        }

        @Override
        public int call(LuaCallFrame frame, int argumentCount) {
            String name = String.valueOf(frame.get(0));
            try {
                Object value = loaded.get(name);
                if (value == null) {
                    Object loader = preload.rawget(name);
                    if (loader == null) {
                        Path path = moduleRoot.resolve(name + ".lua");
                        loader = LuaCompiler.loadstring(Files.readString(path), path.toString(), environment);
                    }
                    value = frame.getThread().call(loader, null, null, null);
                    if (value == null) value = Boolean.TRUE;
                    loaded.put(name, value);
                }
                return frame.push(value);
            }
            catch (Exception exception) {
                throw new RuntimeException("require failed for " + name, exception);
            }
        }
    }

    public static void main(String[] args) throws Exception {
        J2SEPlatform platform = J2SEPlatform.getInstance();
        KahluaTable environment = platform.newEnvironment();
        environment.rawset("PZPerformanceDiagnosticsRepositoryRoot", args[0]);
        KahluaTable packageTable = platform.newTable();
        KahluaTable preload = platform.newTable();
        packageTable.rawset("path", "");
        packageTable.rawset("preload", preload);
        environment.rawset("package", packageTable);
        environment.rawset("require", new Require(Path.of(args[0]), environment, preload));
        KahluaThread thread = new KahluaThread(platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        LuaClosure closure = LuaCompiler.loadstring(
                Files.readString(Path.of(args[1])), args[1], environment);
        Object[] result = thread.pcall(closure, new Object[0]);
        if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
            throw new AssertionError("Lua fixture failed: " + java.util.Arrays.toString(result));
        }
    }
}
'@
    [IO.File]::WriteAllText($runtimeProbePath, $runtimeProbeSource, [Text.UTF8Encoding]::new($false))
    & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $classesRoot $runtimeProbePath
    if ($LASTEXITCODE -ne 0) { throw "Lua runtime probe compilation failed with exit code $LASTEXITCODE." }
    Push-Location -LiteralPath $gamePath
    try {
        & $java -ea -cp "$classesRoot;$gameJar" pzmod.performance.LuaRuntimeProbe $repositoryRoot $observerTestPath
        if ($LASTEXITCODE -ne 0) { throw "Lua runtime probe failed with exit code $LASTEXITCODE." }
    }
    finally {
        Pop-Location
    }

    $syntheticLog = Join-Path $testRoot 'synthetic.jsonl'
    [IO.File]::WriteAllLines($syntheticLog, [string[]]@(
        '{"session":"test","elapsedMs":0,"category":"session","event":"start"}',
        '{"session":"test","elapsedMs":100,"category":"frame","event":"render-spike","wallMs":80,"intervalMs":90,"cpuMs":20,"gcMsDelta":5,"playerMode":"vehicle","vehicleSpeedKph":60,"playerChunk":"10,20","nearestChunkEvent":"main-integrate","nearestChunk":"11,20","chunkEventAgeMs":2}',
        '{"session":"test","elapsedMs":110,"category":"lua","event":"slow-callback","eventName":"OnTick","durationMs":12,"file":"media/lua/client/Test.lua","function":"tick","line":7}',
        '{"session":"test","elapsedMs":120,"category":"chunk","event":"load-or-create","chunk":"11,20","source":"disk","durationMs":45,"loaded":false,"blam":true,"error":"crc"}',
        '{"session":"test","elapsedMs":130,"category":"vehicle","event":"request","attempt":"vehicle-test","vehicleScript":"Base.CarNormal","seat":0,"action":"none","details":"queueDepth=0"}',
        '{"session":"test","elapsedMs":2400,"category":"vehicle","event":"timeout","attempt":"vehicle-test","vehicleScript":"Base.CarNormal","seat":0,"action":"ISEnterVehicle","details":"diagnosticOnly=true","bEnteringVehicle":"true","enterAnimationFinished":"false"}',
        '{"session":"test","elapsedMs":2450,"category":"vehicle","event":"base-enter","attempt":"unmatched","vehicleScript":"Base.ModernCarLightsMeadeSheriff","seat":0,"durationMs":0.12,"entered":true,"error":"none"}',
        '{"session":"test","elapsedMs":2475,"category":"action","event":"transfer-created","traceId":"transfer-test","actionType":"ISInventoryTransferAction","details":"source=inventory;destination=container"}',
        '{"session":"test","elapsedMs":2490,"category":"action","event":"transfer-complete","traceId":"transfer-test","actionType":"ISInventoryTransferAction","details":"result=complete"}',
        '{"session":"test","elapsedMs":2500,"category":"marker","event":"manual","label":"fast-drive","playerMode":"vehicle","playerChunk":"11,20","vehicleScript":"Base.CarNormal","vehicleSpeedKph":80}',
        '{"session":"test","elapsedMs":5000,"category":"summary","event":"window","update":"count=1","render":"count=1","updateStuff":"count=1","frameSpikes":1,"chunkOutliers":1,"vehicleEvents":3,"actionEvents":2}'
    ), [Text.UTF8Encoding]::new($false))
    $summary = & (Join-Path $PSScriptRoot 'Summarize-PZPerformanceDiagnostics.ps1') -Path $syntheticLog -Top 5 | Out-String
    foreach ($requiredSummary in @('Worst frame/update/render spikes', 'Test.lua', 'load-or-create', 'vehicle-test', 'Passive vehicle observations', 'Base.ModernCarLightsMeadeSheriff', 'Action trace timelines', 'transfer-test', 'transfer-complete', 'actionEvents', 'fast-drive')) {
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
