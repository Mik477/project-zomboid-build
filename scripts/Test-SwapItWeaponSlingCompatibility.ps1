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
    throw 'Swap It weapon-sling validation requires Project Zomboid 42.20.3, Steam build 24775755.'
}

$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopRoot = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$gameJar = Join-Path $gamePath 'projectzomboid.jar'
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$compilerJar = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools\ecj-3.46.0.jar'
$modRoot = Join-Path $repositoryRoot 'src\mods\SwapItWeaponSlingCompatibility\42.20'
$runtimePath = Join-Path $modRoot 'media\lua\client\SwapItWeaponSlingCompatibility.lua'
$modInfoPath = Join-Path $modRoot 'mod.info'
$fixturePath = Join-Path $repositoryRoot 'tests\SwapItWeaponSlingCompatibility.test.lua'
$failures = [Collections.Generic.List[string]]::new()

$reviewedFiles = @(
    @{ Name='Swap It hotbar replacement'; Path=(Join-Path $workshopRoot '2366717227\mods\SwapIt\42.0\media\lua\client\SwapIt Main.lua'); Hash='C86B25098F37F0600878A96FAEAB5FBA3363F600CE121263A01EA7B94F6F47BA'; Tokens=@('function ISHotbar:equipItem(item)', 'self:removeItem(item, false)', 'self:attachItem(primary,') },
    @{ Name='Alice sling handoff'; Path=(Join-Path $workshopRoot '3775549570\mods\alicesWeaponSling\42\media\lua\client\AliceWeaponSling_ISHotbar.lua'); Hash='C8E8236BC2FE307F09F4CB88E2E3250C98D4A30974F6249ECD03417F15E857CE'; Tokens=@('AliceWeaponSling_PendingSwapItAttach', 'function AliceWeaponSling.repairHotbarItem', 'if result ~= false then') },
    @{ Name='Fancy Handwork completion'; Path=(Join-Path $workshopRoot '3771638611\mods\FancyHandwork\42.19\media\lua\client\TimedActions\FHEquipWeaponAction.lua'); Hash='C3C734A19D01CA5AFB8E11E6701B125D908D3EEDAB46F69091931B6295B03284'; Tokens=@('function ISEquipWeaponAction:complete()', 'self.character:setSecondaryHandItem(self.hgun)', 'sendEquip(self.character)') },
    @{ Name='Vanilla equip completion'; Path=(Join-Path $gamePath 'media\lua\shared\TimedActions\ISEquipWeaponAction.lua'); Hash='30B756C8D6B79FF8278DB5A7E15CCD55F21CC908E2A37838A999FF9C5940B5D1'; Tokens=@('function ISEquipWeaponAction:complete()', 'self:isAlreadyEquipped(self.item)', 'return false') },
    @{ Name='Vanilla hotbar state'; Path=(Join-Path $gamePath 'media\lua\client\Hotbar\ISHotbar.lua'); Hash='C50A52CA3FC81E4E5BCCC4FB290A36ED6CD572AF44DD3E735DC7AA219BE1D6DB'; Tokens=@('function ISHotbar:isInHotbar(item)', 'function ISHotbar:reloadIcons()', 'self.attachedItems[item:getAttachedSlot()] = item') }
    @{ Name='Clean Hot Bar render'; Path=(Join-Path $workshopRoot '3461263912\mods\CleanHotBar\common\media\lua\client\hotbar\cleanhotbar.lua'); Hash='6273BA3D4C95BD0B759EF2842CAB8ED13516BF65CD2DD4EF6BD2BADC63CA5FD8'; Tokens=@('ISHotbar.render = function(self)', 'CleanHotbarWeaponState.renderWeaponState', 'ISHotbar.setSizeAndPosition = function(self)') }
)

foreach ($path in @($gameJar, $java, $compilerJar, $runtimePath, $modInfoPath, $fixturePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing Swap It validation path: $path") }
}

if (Test-Path -LiteralPath $modInfoPath -PathType Leaf) {
    $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
    foreach ($token in @('id=SwapItWeaponSlingCompatibility', 'require=SwapIt,alicesWeaponSling,FancyHandworkB42_19,CleanHotBar', 'modversion=0.3.0', 'versionMin=42.20.3', 'versionMax=42.20.3')) {
        if (-not $modInfo.Contains($token)) { $failures.Add("Swap It weapon-sling mod.info is missing: $token") }
    }
}
if (Test-Path -LiteralPath $runtimePath -PathType Leaf) {
    $runtime = Get-Content -LiteralPath $runtimePath -Raw
    foreach ($token in @('AliceWeaponSling_PendingSwapItAttach', 'AliceWeaponSling.repairHotbarItem', 'selectedItemIsEquipped', 'sendEquip(action.character)', 'commitPendingHandoff', 'hotbar:attachItem(', 'ISEquipWeaponAction.complete', 'ISEquipWeaponAction.stop', 'CleanHotbarWeaponState.renderWeaponState', 'ISHotbar:setSizeAndPosition', 'ISHotbar:render', 'Events.OnGameStart.Add(Fix.install)')) {
        if (-not $runtime.Contains($token)) { $failures.Add("Swap It weapon-sling runtime is missing: $token") }
    }
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

if ($failures.Count -eq 0) {
    $testRoot = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests\SwapItWeaponSlingCompatibility'
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
    try {
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        $probePath = Join-Path $testRoot 'SwapItWeaponSlingProbe.java'
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

public final class SwapItWeaponSlingProbe {
    private static final class Require implements JavaFunction {
        private final Path moduleRoot;
        private final KahluaTable environment;
        private final KahluaTable preload;
        private final Map<String, Object> loaded = new HashMap<>();

        Require(Path repositoryRoot, KahluaTable environment, KahluaTable preload) {
            this.moduleRoot = repositoryRoot.resolve(
                    "src/mods/SwapItWeaponSlingCompatibility/42.20/media/lua/client");
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
        environment.rawset("SwapItWeaponSlingCompatibilityRepositoryRoot", args[0]);
        environment.rawset("require", new Require(Path.of(args[0]), environment, preload));
        KahluaThread thread = new KahluaThread(platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        LuaClosure fixture = LuaCompiler.loadstring(Files.readString(Path.of(args[1])), args[1], environment);
        Object[] result = thread.pcall(fixture, new Object[0]);
        if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
            throw new AssertionError("Swap It weapon-sling fixture failed: " + java.util.Arrays.toString(result));
        }
    }
}
'@
        [IO.File]::WriteAllText($probePath, $probe, [Text.UTF8Encoding]::new($false))
        & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $gameJar -d $testRoot $probePath
        if ($LASTEXITCODE -ne 0) { throw "Swap It weapon-sling probe compilation failed: $LASTEXITCODE" }
        Push-Location -LiteralPath $gamePath
        try {
            & $java -cp "$testRoot;$gameJar" SwapItWeaponSlingProbe $repositoryRoot $fixturePath
            if ($LASTEXITCODE -ne 0) { throw "Swap It weapon-sling fixture failed: $LASTEXITCODE" }
        }
        finally { Pop-Location }
    }
    catch { $failures.Add("Executable Swap It weapon-sling probe failed: $($_.Exception.Message)") }
    finally { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } }
}

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Error $_ }; exit 1 }
Write-Output 'Swap It weapon-sling compatibility validation passed.'
