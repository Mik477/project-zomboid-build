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
    [string]$localConfiguration.steam.buildId -ne '24909800') {
    throw 'Overflow interaction validation requires Project Zomboid 42.20.3, Steam build 24909800.'
}

$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$compilerJar = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools\ecj-3.46.0.jar'
$modRoot = Join-Path $repositoryRoot 'src\mods\InventoryTetrisOverflowInteractionFix\42.20'
$entryPath = Join-Path $modRoot 'media\lua\client\InventoryTetrisOverflowInteractionFix.lua'
$runtimePath = Join-Path $modRoot 'media\lua\client\InventoryTetrisOverflowInteractionFix\OverflowInteraction.lua'
$modInfoPath = Join-Path $modRoot 'mod.info'
$fixturePath = Join-Path $repositoryRoot 'tests\InventoryTetrisOverflowInteractionFix.test.lua'
$failures = [Collections.Generic.List[string]]::new()

$reviewedFiles = @(
    @{ Name='Inventory Tetris overflow renderer'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\UI\Container\GridOverflowRenderer.lua'); Hash='5A6C25FD2656BBE1D968B283699B2C4F16527D2F692F4B4362B4794ECF824FA5'; Tokens=@('function GridOverflowRenderer:findStackDataUnderMouse(x, y)', 'return self.gridUi:onMouseDown(x, y, stack)', 'function GridOverflowRenderer:onMouseDoubleClick(x, y)') },
    @{ Name='Inventory Tetris container UI'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\UI\Container\ItemGridContainerUI.lua'); Hash='BC80E341C30185EE0CEDB15C5F56DF42D1F4ED59ACD5E8DFB2F0792775C88D54'; Tokens=@('function ItemGridContainerUI:findGridStackUnderMouse()', 'self.overflowRenderer = overflowRenderer') },
    @{ Name='Inventory Tetris grid events'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\UI\Grid\ItemGridUI_events.lua'); Hash='6AEC5D24363B54A2898B74C48D18F4071C2C299B47A4BEC4DACEA96CD4FFEB1A'; Tokens=@('function ItemGridUI:onMouseMove(dx, dy)', 'function ItemGridUI:onMouseMoveOutside(dx, dy)', 'function ItemGridUI:onMouseUpOutside(x, y)') },
    @{ Name='Inventory Tetris tooltip patch'; Path=(Join-Path $workshopRoot '3775513231\mods\InventoryTetris\42.20\media\lua\client\InventoryTetris\Patches\Core\InventoryTetris_InventoryPane.lua'); Hash='FB562B59DEFB79842AFA39D9013CD5D1455928396B26737F0C97886C0608BE9E'; Tokens=@('local stack = containerGridUi:findGridStackUnderMouse()', 'self:doTooltipForItem(item)') }
)

foreach ($path in @($gameJar, $java, $compilerJar, $entryPath, $runtimePath, $modInfoPath, $fixturePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing overflow interaction validation path: $path") }
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
    $source = Get-Content -LiteralPath $reviewed.Path -Raw
    foreach ($token in $reviewed.Tokens) {
        if (-not $source.Contains($token)) { $failures.Add("$($reviewed.Name) seam is missing: $token") }
    }
}

if (Test-Path -LiteralPath $modInfoPath -PathType Leaf) {
    $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
    foreach ($token in @('id=InventoryTetrisOverflowInteractionFix', 'require=INVENTORY_TETRIS', 'modversion=0.1.1', 'versionMin=42.20.3', 'versionMax=42.20.3')) {
        if (-not $modInfo.Contains($token)) { $failures.Add("mod.info is missing: $token") }
    }
}
if (Test-Path -LiteralPath $runtimePath -PathType Leaf) {
    $runtime = Get-Content -LiteralPath $runtimePath -Raw
    foreach ($token in @('ItemGridContainerUI.findGridStackUnderMouse', 'GridOverflowRenderer.findStackDataUnderMouse', 'GridOverflowRenderer.onMouseMove', 'GridOverflowRenderer.onMouseMoveOutside', 'GridOverflowRenderer.onMouseUpOutside', 'ItemStack.getFrontItem')) {
        if (-not $runtime.Contains($token)) { $failures.Add("Overflow interaction runtime is missing: $token") }
    }
}

if ($failures.Count -eq 0) {
    $testRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests\InventoryTetrisOverflowInteractionFix'
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    try {
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        $probePath = Join-Path $testRoot 'OverflowInteractionProbe.java'
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

public final class OverflowInteractionProbe {
    private static final class Require implements JavaFunction {
        private final Path moduleRoot;
        private final KahluaTable environment;
        private final KahluaTable preload;
        private final Map<String, Object> loaded = new HashMap<>();

        Require(Path repositoryRoot, KahluaTable environment, KahluaTable preload) {
            this.moduleRoot = repositoryRoot.resolve(
                    "src/mods/InventoryTetrisOverflowInteractionFix/42.20/media/lua/client");
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
        KahluaTable packageTable = platform.newTable();
        KahluaTable preload = platform.newTable();
        packageTable.rawset("path", "");
        packageTable.rawset("preload", preload);
        environment.rawset("package", packageTable);
        environment.rawset("InventoryTetrisOverflowInteractionFixRepositoryRoot", args[0]);
        environment.rawset("require", new Require(Path.of(args[0]), environment, preload));
        KahluaThread thread = new KahluaThread(platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        LuaClosure fixture = LuaCompiler.loadstring(Files.readString(Path.of(args[1])), args[1], environment);
        Object[] result = thread.pcall(fixture, new Object[0]);
        if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
            throw new AssertionError("Overflow interaction fixture failed: " + java.util.Arrays.toString(result));
        }
    }
}
'@
        [IO.File]::WriteAllText($probePath, $probe, [Text.UTF8Encoding]::new($false))
        & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $testRoot $probePath
        if ($LASTEXITCODE -ne 0) { throw "Overflow interaction probe compilation failed: $LASTEXITCODE" }
        Push-Location -LiteralPath $gamePath
        try {
            & $java -cp "$testRoot;$gameJar" OverflowInteractionProbe $repositoryRoot $fixturePath
            if ($LASTEXITCODE -ne 0) { throw "Overflow interaction fixture failed: $LASTEXITCODE" }
        }
        finally {
            Pop-Location
        }
    }
    catch { $failures.Add("Executable overflow interaction probe failed: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } }
}

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output 'Inventory Tetris overflow interaction validation passed.'
