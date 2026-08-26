[CmdletBinding()]
param([string]$LocalConfigurationPath)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if (-not $LocalConfigurationPath) { $LocalConfigurationPath = Join-Path $repositoryRoot 'config\local.json' }
if (-not (Test-Path -LiteralPath $LocalConfigurationPath -PathType Leaf)) {
    throw 'Local configuration is missing. Run scripts/Initialize-LocalEnvironment.ps1 first.'
}

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
if ([string]$localConfiguration.projectZomboid.exactGameVersion -ne '42.20.3' -or
    [string]$localConfiguration.steam.buildId -ne '24775755') {
    throw 'Inventory Tetris diagnostics validation requires Project Zomboid 42.20.3, Steam build 24775755.'
}

$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$compilerVersion = '3.46.0'
$compilerUrl = "https://repo1.maven.org/maven2/org/eclipse/jdt/ecj/$compilerVersion/ecj-$compilerVersion.jar"
$toolRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools'
$compilerJar = Join-Path $toolRoot "ecj-$compilerVersion.jar"
$modRoot = Join-Path $repositoryRoot 'src\mods\InventoryTetrisTransferDiagnostics\42.20'
$runtimePath = Join-Path $modRoot 'media\lua\client\InventoryTetrisTransferDiagnostics\InventoryDiagnostics.lua'
$corePath = Join-Path $modRoot 'media\lua\client\InventoryTetrisTransferDiagnostics\InventoryDiagnosticsCore.lua'
$entryPath = Join-Path $modRoot 'media\lua\client\InventoryTetrisTransferDiagnostics.lua'
$modInfoPath = Join-Path $modRoot 'mod.info'
$coreTestPath = Join-Path $repositoryRoot 'tests\InventoryDiagnosticsCore.test.lua'
$runtimeTestPath = Join-Path $repositoryRoot 'tests\InventoryDiagnosticsRuntime.test.lua'
$failures = [Collections.Generic.List[string]]::new()

$expectedGameJarHash = 'BDA809FB49004A07DBFC560D059C0EE58D0643AB0F33B53351B13BD62F1D8227'
$expectedCompilerHash = 'D0D43F8E2D7003E5EFED612E2CBB5F01870043397D8F1BBE536FD9128F4FCBF7'
$reviewedFiles = @(
    @{ Name='Vanilla timed-action queue'; Path=(Join-Path $gamePath 'media\lua\client\TimedActions\ISTimedActionQueue.lua'); Hash='23C98152728172B44CCB41BC8DDC97798FEE7A91B57B20620FB11D5F41E7792C'; Tokens=@('ISTimedActionQueue.queues = {}', 'self.current = action;', 'action:begin();') },
    @{ Name='Vanilla inventory transfer'; Path=(Join-Path $gamePath 'media\lua\client\TimedActions\ISInventoryTransferAction.lua'); Hash='96EE554609F9AE029809643D50E4F31DBC5A7D21A558934BE0804FD909C345B4'; Tokens=@('o.started = false;', 'o.transactionId = 0;', 'o.maxTime  = -1') },
    @{ Name='Vanilla weapon equip'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISEquipWeaponAction.lua'); Hash='30B756C8D6B79FF8278DB5A7E15CCD55F21CC908E2A37838A999FF9C5940B5D1'; Tokens=@('function ISEquipWeaponAction:complete()', 'o.maxTime = maxTimeInit') },
    @{ Name='Vanilla load magazine'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISLoadBulletsInMagazine.lua'); Hash='A9FAABA4FF3650DE790D6C258D2214C0507ADE8C3AC2461AE22DD8924EA444A9'; Tokens=@('ISLoadBulletsInMagazine = ISBaseTimedAction:derive("ISLoadBulletsInMagazine")', 'self:setOverrideHandModels(nil, "GunMagazine")') },
    @{ Name='Inventory Tetris item-container grid'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\Model\ItemContainerGrid.lua'); Hash='0F509DBB37604FED2398403EC3D1CDB67AFD11DC39F987BB2CAE12776A32996A'; Tokens=@('ItemContainerGrid._unpositionedItemSetsByPlayer = {}', 'sourceContainer = sourceContainer', 'detectedAt = getTimestampMs()') },
    @{ Name='Inventory Tetris key-ring support'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\KeyRingSupport.lua'); Hash='26FC7D591C410CA74B6F138B79DF6EA2DCD60DFD6D446421A69CD0FD9BA6593A'; Tokens=@('function KeyRingSupport.isContainer(container)', 'container:getType() == "KeyRing"') },
    @{ Name='Inventory Tetris auto-drop'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\System\GridAutoDropSystem.lua'); Hash='FC7C3244890D122D787BAF7040BC7F9C73FD9B65F6F6FD7041AA7A202B485C90'; Tokens=@('for playerNum, itemMap in pairs(ItemContainerGrid._unpositionedItemSetsByPlayer)', 'Events.OnTick.Add(GridAutoDropSystem._processQueues)') },
    @{ Name='Inventory Tetris transfer patch'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\Patches\TimedActions\InventoryTetris_InventoryTransferAction.lua'); Hash='ECDA0A1CE4064BB0205CC00EC47D70470A5F812EEF86AD842BE841DAD596974F'; Tokens=@('function ISInventoryTransferAction:start()', 'function ISInventoryTransferAction:isValid()', 'KeyRingSupport.isContainer(self.destContainer)') },
    @{ Name='Gael magazine change'; Path=(Join-Path $workshopRoot '3616176188\mods\GaelGunStore\42\media\lua\client\WeaponAbility\ChangeMagazineType.lua'); Hash='DD461E09FDAACCC45AEBCE7FFCB0221541EC5F0BEB3A0B9C0B37B34E7A31E773'; Tokens=@('ISBaseTimedAction:derive("SetMagTypeAction")', 'ISBaseTimedAction:derive("PostSwapAction")', 'o.gun = gun', 'o.magType = magType') }
)

foreach ($path in @($gameJar, $java, $runtimePath, $corePath, $entryPath, $modInfoPath, $coreTestPath, $runtimeTestPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing diagnostics validation path: $path") }
}
if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $compilerJar -PathType Leaf)) {
    Write-Output "Downloading Eclipse compiler $compilerVersion to the external tool cache."
    Invoke-WebRequest -UseBasicParsing -Uri $compilerUrl -OutFile $compilerJar
}
if (Test-Path -LiteralPath $gameJar -PathType Leaf) {
    $actualGameJarHash = (Get-FileHash -LiteralPath $gameJar -Algorithm SHA256).Hash
    if ($actualGameJarHash -ne $expectedGameJarHash) { $failures.Add("Unsupported projectzomboid.jar SHA-256: $actualGameJarHash") }
}
if (Test-Path -LiteralPath $compilerJar -PathType Leaf) {
    $actualCompilerHash = (Get-FileHash -LiteralPath $compilerJar -Algorithm SHA256).Hash
    if ($actualCompilerHash -ne $expectedCompilerHash) { $failures.Add("Unsupported ECJ compiler SHA-256: $actualCompilerHash") }
}
foreach ($reviewed in $reviewedFiles) {
    if (-not (Test-Path -LiteralPath $reviewed.Path -PathType Leaf)) {
        $failures.Add("Missing reviewed seam: $($reviewed.Name)")
        continue
    }
    $actualHash = (Get-FileHash -LiteralPath $reviewed.Path -Algorithm SHA256).Hash
    if ($actualHash -ne $reviewed.Hash) {
        $failures.Add("Reviewed seam changed for $($reviewed.Name): $actualHash")
        continue
    }
    $reviewedSource = Get-Content -LiteralPath $reviewed.Path -Raw
    foreach ($token in $reviewed.Tokens) {
        if (-not $reviewedSource.Contains($token)) { $failures.Add("$($reviewed.Name) seam is missing: $token") }
    }
}

if (Test-Path -LiteralPath $modInfoPath -PathType Leaf) {
    $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
    foreach ($token in @(
        'id=InventoryTetrisTransferDiagnostics',
        'require=INVENTORY_TETRIS',
        'modversion=0.3.1',
        'versionMin=42.20.3',
        'versionMax=42.20.3',
        'observer-only'
    )) {
        if (-not $modInfo.Contains($token)) { $failures.Add("mod.info is missing: $token") }
    }
}

if (Test-Path -LiteralPath $runtimePath -PathType Leaf) {
    $runtimeSource = Get-Content -LiteralPath $runtimePath -Raw
    $allDiagnosticSource = @($entryPath, $runtimePath, $corePath) |
        ForEach-Object { Get-Content -LiteralPath $_ -Raw } |
        Out-String
    foreach ($token in @(
        'MAX_LINES = 2500',
        'MAX_LIVE_TRACES = 64',
        'MAX_QUEUE_TYPES = 12',
        'TRACE_TTL_MS = 45000',
        'ISTimedActionQueue.queues',
        'ItemContainerGrid._unpositionedItemSetsByPlayer',
        'KeyRingSupport.isContainer',
        'missing-native-action-stall',
        'PZPerfDiagnostics_actionEvent',
        'ISWearClothing',
        'ISInsertMagazine',
        'ISEjectMagazine',
        'ISLoadBulletsInMagazine',
        'worn-state-changed',
        'magazine-state-changed',
        'inventory-capacity-state-changed',
        'everStarted',
        'buildQueueContext',
        'Events.OnTick.Add(onTick)'
    )) {
        if (-not $runtimeSource.Contains($token)) { $failures.Add("Observer runtime is missing: $token") }
    }

    $protectedNames = 'ISInventoryTransferAction|ISEquipWeaponAction|ISTimedActionQueue|ISInventoryPane|ISInventoryPaneContextMenu|GridAutoDropSystem'
    foreach ($pattern in @(
        "(?m)^\s*function\s+(?:$protectedNames)[\.:]",
        "(?m)^\s*(?:$protectedNames)(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]]+\])?\s*="
    )) {
        if ($allDiagnosticSource -match $pattern) { $failures.Add("Observer runtime replaces or assigns a protected runtime method/table: $($Matches[0].Trim())") }
    }

    $dangerousCalls = @(
        'getJobDelta', 'begin', 'start', 'update', 'isValid', 'isValidStart',
        'validateTetrisRules', 'validateTetrisSquishable', 'isAlreadyTransferred',
        'isItemAllowed', 'isRemoveItemAllowed', 'hasRoomFor', 'canAddItem',
        'doesItemFit', 'doesItemFitAnywhere', 'doesItemFitSpecificGrid',
        'forceComplete', 'forceStop', 'forceCancel', 'transferItem', 'perform', 'complete', 'stop',
        '_handleDropItem', '_attemptToForcePositionItem', '_attemptToForceEquipItem', '_processItems', '_processQueues',
        'autoPositionItem', 'attemptToInsertItem', 'insertItem', 'removeItem'
    )
    foreach ($call in $dangerousCalls) {
        if ($allDiagnosticSource -match ("(?:[:\.]|\b)" + [regex]::Escape($call) + "\s*\(")) {
            $failures.Add("Observer runtime invokes forbidden method: $call")
        }
    }
    foreach ($globalCall in @(
        'isItemTransactionConsistent', 'isItemTransactionDone', 'isItemTransactionRejected',
        'createItemTransaction', 'removeItemTransaction', 'sendAddItemToContainer',
        'sendRemoveItemFromContainer', 'sendEquip', 'syncItemActivated', 'save', 'Save'
    )) {
        if ($allDiagnosticSource -match ("\b" + [regex]::Escape($globalCall) + "\s*\(")) {
            $failures.Add("Observer runtime invokes forbidden validation, save, or network API: $globalCall")
        }
    }
    foreach ($queueCall in @(
        'getTimedActionQueue', 'addToQueue', 'add', 'clear', 'clearQueue',
        'resetQueue', 'cancelQueue', 'onCompleted', 'tick'
    )) {
        if ($allDiagnosticSource -match ("ISTimedActionQueue\s*[\.:]\s*" + [regex]::Escape($queueCall) + "\s*\(")) {
            $failures.Add("Observer runtime invokes forbidden queue method: $queueCall")
        }
    }
}

$luaPaths = @($entryPath, $runtimePath, $corePath, $coreTestPath, $runtimeTestPath)
if ($failures.Count -eq 0) {
    $testBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests'))
    $testRoot = [IO.Path]::GetFullPath((Join-Path $testBase 'InventoryTetrisTransferDiagnostics'))
    $resolvedTestBase = $testBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $testRoot.StartsWith($resolvedTestBase, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to use a test directory outside the external test root: $testRoot"
    }
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
        System.out.println("Inventory diagnostics Lua syntax passed.");
    }
}
'@
        [IO.File]::WriteAllText($syntaxPath, $syntax, [Text.UTF8Encoding]::new($false))
        & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $testRoot $syntaxPath
        if ($LASTEXITCODE -ne 0) { throw "Lua syntax probe compilation failed: $LASTEXITCODE" }
        & $java -cp "$testRoot;$gameJar" LuaSyntaxProbe @luaPaths
        if ($LASTEXITCODE -ne 0) { throw "Lua syntax probe failed: $LASTEXITCODE" }

        $runtimeProbePath = Join-Path $testRoot 'LuaRuntimeProbe.java'
        $runtimeProbe = @'
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
                    "src/mods/InventoryTetrisTransferDiagnostics/42.20/media/lua/client");
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
        for (int index = 1; index < args.length; ++index) {
            String arg = args[index];
            J2SEPlatform platform = J2SEPlatform.getInstance();
            KahluaTable environment = platform.newEnvironment();
            environment.rawset("InventoryDiagnosticsRepositoryRoot", args[0]);
            KahluaTable packageTable = platform.newTable();
            KahluaTable preload = platform.newTable();
            packageTable.rawset("path", "");
            packageTable.rawset("preload", preload);
            environment.rawset("package", packageTable);
            environment.rawset("require", new Require(Path.of(args[0]), environment, preload));
            KahluaThread thread = new KahluaThread(platform, environment);
            thread.debugOwnerThread = Thread.currentThread();
            LuaClosure closure = LuaCompiler.loadstring(Files.readString(Path.of(arg)), arg, environment);
            Object[] result = thread.pcall(closure, new Object[0]);
            if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
                throw new AssertionError("Lua fixture failed: " + arg + " " + java.util.Arrays.toString(result));
            }
        }
        System.out.println("Inventory diagnostics Lua runtime fixtures passed.");
    }
}
'@
        [IO.File]::WriteAllText($runtimeProbePath, $runtimeProbe, [Text.UTF8Encoding]::new($false))
        & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $testRoot $runtimeProbePath
        if ($LASTEXITCODE -ne 0) { throw "Lua runtime probe compilation failed: $LASTEXITCODE" }
        Push-Location -LiteralPath $gamePath
        try {
            & $java -cp "$testRoot;$gameJar" LuaRuntimeProbe $repositoryRoot $coreTestPath $runtimeTestPath
            if ($LASTEXITCODE -ne 0) { throw "Lua runtime probe failed: $LASTEXITCODE" }
        }
        finally {
            Pop-Location
        }
    }
    catch { $failures.Add("Executable Lua syntax probe failed: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } }
}

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output 'Inventory Tetris Transfer Diagnostics validation passed.'
