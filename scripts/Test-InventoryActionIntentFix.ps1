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
    throw 'Inventory action intent validation requires Project Zomboid 42.20.3, Steam build 24775755.'
}

$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$compilerJar = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools\ecj-3.46.0.jar'
$modRoot = Join-Path $repositoryRoot 'src\mods\InventoryActionIntentFix\42.20'
$entryPath = Join-Path $modRoot 'media\lua\client\InventoryActionIntentFix.lua'
$runtimePath = Join-Path $modRoot 'media\lua\client\InventoryActionIntentFix\InventoryActionIntentFix.lua'
$policyPath = Join-Path $modRoot 'media\lua\client\InventoryActionIntentFix\IntentPolicy.lua'
$modInfoPath = Join-Path $modRoot 'mod.info'
$fixturePath = Join-Path $repositoryRoot 'tests\InventoryActionIntentFix.test.lua'
$gaelAdapterPath = Join-Path $repositoryRoot 'src\mods\GaelGunStoreCoreFixes\42.20\media\lua\client\GaelGunStoreCoreFixes\AutomaticMagazineSelection.lua'
$failures = [Collections.Generic.List[string]]::new()

foreach ($path in @($gameJar, $java, $compilerJar, $entryPath, $runtimePath, $policyPath, $modInfoPath, $fixturePath, $gaelAdapterPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing inventory action intent path: $path") }
}

foreach ($reviewed in @(
    @{ Name='Vanilla inventory context menu'; Path=(Join-Path $gamePath 'media\lua\client\ISUI\ISInventoryPaneContextMenu.lua'); Hash='D448542EC2D93CACD80C0FE6A5AEDF41D16521F4E227A1382FFC9431F0C3E1A9'; Tokens=@('ISInventoryPaneContextMenu.wearItem = function(item, player)', 'ISInventoryPaneContextMenu.onInsertMagazine = function(playerObj, weapon, magazine)', 'ISInventoryPaneContextMenu.onEjectMagazine = function(playerObj, weapon)') },
    @{ Name='Vanilla timed-action queue'; Path=(Join-Path $gamePath 'media\lua\client\TimedActions\ISTimedActionQueue.lua'); Hash='23C98152728172B44CCB41BC8DDC97798FEE7A91B57B20620FB11D5F41E7792C'; Tokens=@('ISTimedActionQueue.queues = {}', 'queue:addToQueue(action)') },
    @{ Name='Vanilla Wear action'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISWearClothing.lua'); Hash='146C66743D8593581BAE58E7E1D954886F73A1E6B8BC51720FD2271AFBB50524'; Tokens=@('ISWearClothing = ISBaseTimedAction:derive("ISWearClothing")') },
    @{ Name='Vanilla insert-magazine action'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISInsertMagazine.lua'); Hash='51D607D1B33B6A6FF90DEAA01944CEBEDBE563FEB34A14A972139BA4C7D6A7E2'; Tokens=@('ISInsertMagazine = ISBaseTimedAction:derive("ISInsertMagazine")') },
    @{ Name='Vanilla eject-magazine action'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISEjectMagazine.lua'); Hash='00AF120A7C231380F82075B3EC7A198A315D50EE4D6D44A806A888A067FBB31A'; Tokens=@('ISEjectMagazine = ISBaseTimedAction:derive("ISEjectMagazine")') },
    @{ Name='Vanilla equip action'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISEquipWeaponAction.lua'); Hash='30B756C8D6B79FF8278DB5A7E15CCD55F21CC908E2A37838A999FF9C5940B5D1'; Tokens=@('function ISEquipWeaponAction:complete()', 'forceDropHeavyItems(self.character)') },
    @{ Name='Vanilla floor transfer'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISTransferAction.lua'); Hash='97744891C667D8DE0CD18C789AB0A6C0E4ADD0C7CC114D904C359703D0A66C43'; Tokens=@('function ISTransferAction:getNotFullFloorSquare(character, item, destContainer)', 'function ISTransferAction:removeItemOnCharacter(character, item)') },
    @{ Name='Inventory Tetris container grid'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\Model\ItemContainerGrid.lua'); Hash='0F509DBB37604FED2398403EC3D1CDB67AFD11DC39F987BB2CAE12776A32996A'; Tokens=@('function ItemContainerGrid:canAddItem(item)', 'ItemContainerGrid._playerMainGrids = {}') },
    @{ Name='Inventory Tetris auto-drop'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\System\GridAutoDropSystem.lua'); Hash='FC7C3244890D122D787BAF7040BC7F9C73FD9B65F6F6FD7041AA7A202B485C90'; Tokens=@('GridAutoDropSystem._isActionQueueIdle(playerObj)', 'GridAutoDropSystem._processItems(playerNum, readyItems)') },
    @{ Name='Gael magazine change'; Path=(Join-Path $workshopRoot '3616176188\mods\GaelGunStore\42\media\lua\client\WeaponAbility\ChangeMagazineType.lua'); Hash='DD461E09FDAACCC45AEBCE7FFCB0221541EC5F0BEB3A0B9C0B37B34E7A31E773'; Tokens=@('ISBaseTimedAction:derive("SetMagTypeAction")', 'ISBaseTimedAction:derive("PostSwapAction")') }
)) {
    if (-not (Test-Path -LiteralPath $reviewed.Path -PathType Leaf)) { $failures.Add("Missing reviewed seam: $($reviewed.Name)"); continue }
    $actualHash = (Get-FileHash -LiteralPath $reviewed.Path -Algorithm SHA256).Hash
    if ($actualHash -ne $reviewed.Hash) { $failures.Add("Reviewed seam changed for $($reviewed.Name): $actualHash"); continue }
    $source = Get-Content -LiteralPath $reviewed.Path -Raw
    foreach ($token in $reviewed.Tokens) {
        if (-not $source.Contains($token)) { $failures.Add("$($reviewed.Name) seam is missing: $token") }
    }
}

if (Test-Path -LiteralPath $modInfoPath -PathType Leaf) {
    $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
    foreach ($token in @('id=InventoryActionIntentFix', 'require=INVENTORY_TETRIS', 'modversion=0.2.0', 'versionMin=42.20.3', 'versionMax=42.20.3')) {
        if (-not $modInfo.Contains($token)) { $failures.Add("InventoryActionIntentFix mod.info is missing: $token") }
    }
    if ($modInfo.Contains('javaJarFile=') -or $modInfo.Contains('javaPkgName=')) {
        $failures.Add('InventoryActionIntentFix must remain Lua-only.')
    }
}

if (Test-Path -LiteralPath $runtimePath -PathType Leaf) {
    $runtimeSource = Get-Content -LiteralPath $runtimePath -Raw
    foreach ($token in @('function Module.isPending', 'function Module.install', 'ISInventoryPaneContextMenu.wearItem = wrapper', 'ISInventoryPaneContextMenu.onInsertMagazine = wrapper', 'ISInventoryPaneContextMenu.onEjectMagazine = wrapper', 'ISInventoryPaneContextMenu.equipWeapon = wrapper', 'grid.findStackByItem', 'hasPendingFloorTransfer', 'GridAutoDropSystem._handleDropItem(displacedItem, playerNum)', 'InventoryActionIntentFix_isPending')) {
        if (-not $runtimeSource.Contains($token)) { $failures.Add("Inventory action intent runtime is missing: $token") }
    }
    foreach ($forbidden in @('ISTimedActionQueue.add =', 'ISTimedActionQueue.addToQueue =', 'GridAutoDropSystem._processItems =', 'GridAutoDropSystem._processQueues =', 'ISInventoryTransferAction.', ':AddWorldInventoryItem(', ':DoRemoveItem(', ':Remove(')) {
        if ($runtimeSource.Contains($forbidden)) { $failures.Add("Inventory action intent runtime changes a forbidden broad seam: $forbidden") }
    }
}

if (Test-Path -LiteralPath $gaelAdapterPath -PathType Leaf) {
    $gaelSource = Get-Content -LiteralPath $gaelAdapterPath -Raw
    if (-not $gaelSource.Contains('InventoryActionIntentFix_isPending')) {
        $failures.Add('Gael automatic magazine selection does not consult the shared intent guard.')
    }
}

if ($failures.Count -eq 0) {
    $testRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests\InventoryActionIntentFix'
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    try {
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        $probePath = Join-Path $testRoot 'InventoryActionIntentLuaProbe.java'
        $probe = @'
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
public final class InventoryActionIntentLuaProbe {
    private static final class Require implements JavaFunction {
        private final Path repositoryRoot;
        private final KahluaTable environment;
        private final KahluaTable preload;
        private final Map<String, Object> loaded = new HashMap<>();
        Require(Path repositoryRoot, KahluaTable environment, KahluaTable preload) {
            this.repositoryRoot = repositoryRoot;
            this.environment = environment;
            this.preload = preload;
        }
        @Override public int call(LuaCallFrame frame, int argumentCount) {
            String name = String.valueOf(frame.get(0));
            try {
                Object value = loaded.get(name);
                if (value == null) {
                    Object loader = preload.rawget(name);
                    if (loader == null) {
                        Path moduleRoot = name.startsWith("GaelGunStoreCoreFixes/")
                                ? repositoryRoot.resolve("src/mods/GaelGunStoreCoreFixes/42.20/media/lua/client")
                                : repositoryRoot.resolve("src/mods/InventoryActionIntentFix/42.20/media/lua/client");
                        Path path = moduleRoot.resolve(name + ".lua");
                        loader = LuaCompiler.loadstring(Files.readString(path), path.toString(), environment);
                    }
                    value = frame.getThread().call(loader, null, null, null);
                    if (value == null) value = Boolean.TRUE;
                    loaded.put(name, value);
                }
                return frame.push(value);
            } catch (Exception exception) { throw new RuntimeException("require failed for " + name, exception); }
        }
    }
    public static void main(String[] args) throws Exception {
        J2SEPlatform platform = J2SEPlatform.getInstance();
        KahluaTable environment = platform.newEnvironment();
        KahluaTable packageTable = platform.newTable();
        KahluaTable preload = platform.newTable();
        packageTable.rawset("path", "");
        packageTable.rawset("preload", preload);
        environment.rawset("package", packageTable);
        environment.rawset("InventoryActionIntentFixRepositoryRoot", args[0]);
        environment.rawset("require", new Require(Path.of(args[0]), environment, preload));
        KahluaThread thread = new KahluaThread(platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        for (int index = 1; index < args.length - 1; ++index) {
            Path path = Path.of(args[index]);
            LuaCompiler.loadstring(Files.readString(path), path.toString(), environment);
        }
        Path fixture = Path.of(args[args.length - 1]);
        LuaClosure closure = LuaCompiler.loadstring(Files.readString(fixture), fixture.toString(), environment);
        Object[] result = thread.pcall(closure, new Object[0]);
        if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
            throw new AssertionError("Lua probe failed: " + fixture + " " + java.util.Arrays.toString(result));
        }
        System.out.println("Inventory action intent Lua fixtures passed.");
    }
}
'@
        [IO.File]::WriteAllText($probePath, $probe, [Text.UTF8Encoding]::new($false))
        & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $testRoot $probePath
        if ($LASTEXITCODE -ne 0) { throw "Lua probe compilation failed: $LASTEXITCODE" }
        Push-Location -LiteralPath $gamePath
        try {
            & $java -cp "$testRoot;$gameJar" InventoryActionIntentLuaProbe $repositoryRoot $policyPath $runtimePath $entryPath $fixturePath
            if ($LASTEXITCODE -ne 0) { throw "Lua probe failed: $LASTEXITCODE" }
        }
        finally { Pop-Location }
    }
    catch { $failures.Add("Executable inventory action intent probe failed: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } }
}

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output 'Inventory action intent validation passed.'
