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

$localConfiguration = Get-Content -LiteralPath $LocalConfigurationPath -Raw | ConvertFrom-Json
$gamePath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.gamePath)
$workshopPath = [IO.Path]::GetFullPath([string]$localConfiguration.projectZomboid.workshopPath)
$java = Join-Path $gamePath 'jre64\bin\java.exe'
$zombieBuddyCandidates = @(
    (Join-Path $gamePath 'ZombieBuddy.jar'),
    (Join-Path $workshopPath '3619862853\mods\ZombieBuddy\libs\ZombieBuddy.jar')
)
$zombieBuddyJar = $zombieBuddyCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
$compilerJar = Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tools\ecj-3.46.0.jar'
$testBase = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'project-zomboid-build\tests'))
$testRoot = [IO.Path]::GetFullPath((Join-Path $testBase 'MultiplayerRagdollPrototype-visibility'))
$patchSourcePath = Join-Path $repositoryRoot 'src\mods\MultiplayerRagdollPrototype\42.20\media\java-src\pzmod\mpragdollprototype\MultiplayerRagdollPatches.java'
$runtimeSourcePath = Join-Path $repositoryRoot 'src\mods\MultiplayerRagdollPrototype\42.20\media\java-src\pzmod\mpragdollprototype\PrototypeRuntime.java'
$telemetrySourcePath = Join-Path $repositoryRoot 'src\mods\MultiplayerRagdollPrototype\42.20\media\java-src\pzmod\mpragdollprototype\RigidBodyTelemetry.java'
$resolvedTestBase = $testBase.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar

if (-not $testRoot.StartsWith($resolvedTestBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to use a test directory outside the external test root: $testRoot"
}
if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}

try {
    $patchSource = Get-Content -LiteralPath $patchSourcePath -Raw
    $runtimeSource = Get-Content -LiteralPath $runtimeSourcePath -Raw
    $telemetrySource = Get-Content -LiteralPath $telemetrySourcePath -Raw
    if ($patchSource -notmatch '@Patch\(className = "zombie\.characters\.IsoGameCharacter", methodName = "hitConsequences"\)') {
        throw 'Missing IsoGameCharacter.hitConsequences advice required to snapshot off-ground state before damage.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.characters\.IsoGameCharacter", methodName = "applyDamage"\)') {
        throw 'Missing IsoGameCharacter.applyDamage advice required to recognize lethality before health is reduced.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.characters\.IsoZombie", methodName = "update"\)') {
        throw 'Missing IsoZombie.update advice required to retain locomotion across zero-displacement lethal frames.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.ai\.states\.ZombieFallDownState", methodName = "execute"\)') {
        throw 'Missing ZombieFallDownState.execute startup deferral required to let ragdoll physics initialize.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.characters\.NetworkCharacterAI", methodName = "isDeadBodyTimeout"\)') {
        throw 'Missing NetworkCharacterAI.isDeadBodyTimeout guard required to preserve active ragdolls.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.core\.physics\.RagdollController", methodName = "simulateHitReaction"\)') {
        throw 'Missing RagdollController.simulateHitReaction replacement required for reliable melee and firearm impulses.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.core\.physics\.RagdollController", methodName = "addToWorld"\)') {
        throw 'Missing RagdollController.addToWorld hook required for per-ragdoll arm templates.'
    }
    if ($patchSource -notmatch 'methodName = "uploadAnimationBonePreviousTransformsToRagdoll"') {
        throw 'Missing RagdollController initial-velocity suppression hook required to prevent animation-derived limb launches.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.core\.physics\.RagdollController", methodName = "postUpdate"\)') {
        throw 'Missing RagdollController.postUpdate hook required for stabilization and bounded torso assistance.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.core\.physics\.RagdollController", methodName = "simulateRagdoll"\)') {
        throw 'Missing RagdollController.simulateRagdoll hook required for native rigid-body telemetry.'
    }
    if ($patchSource -notmatch '@Patch\.Argument\(5\) float\[\] rigidBodyBuffer') {
        throw 'Ragdoll telemetry must capture argument five, the 77-float native rigid-body output buffer.'
    }
    if ($patchSource -notmatch '@Patch\(className = "zombie\.core\.physics\.RagdollController", methodName = "update"\)') {
        throw 'Missing RagdollController.update hook required to associate simulation delta time with rigid-body frames.'
    }
    if ($patchSource -notmatch '@Patch\.OnEnter\(skipOn = true\)') {
        throw 'ZombieFallDownState.execute advice must be able to skip premature vanilla corpse conversion.'
    }
    foreach ($methodName in @('enterHitConsequences', 'beforeApplyDamage', 'exitHitConsequences', 'shouldDeferFallDownExecution', 'shouldDeferDeadBodyTimeout', 'replaceHitReaction', 'shouldSuppressInitialVelocities', 'beforeAddRagdollToWorld', 'afterAddRagdollToWorld', 'prepareRagdollFrame', 'captureRagdollFrame', 'finishRagdollFrame', 'updateRagdollController')) {
        if ($runtimeSource -notmatch "public static void $methodName\(") {
            if ($runtimeSource -notmatch "public static boolean $methodName\(") {
                throw "Missing public advice-facing runtime method: $methodName"
            }
        }
    }
    foreach ($requiredTelemetryToken in @('BUFFER_LENGTH = BODY_COUNT * BODY_STRIDE', 'CAPTURE_DEFERRED_FIRST_FRAME', 'maxRelativeAngular', 'maxAirborneRelativeAngularSpeed', 'armFrameDetails', 'armSummaryDetails', 'maxAngleDelta', 'latest[bodyOffset] - latest[0]')) {
        if ($telemetrySource -notmatch [regex]::Escape($requiredTelemetryToken)) {
            throw "Rigid-body telemetry source is missing required token: $requiredTelemetryToken"
        }
    }
    foreach ($traceEvent in @(
        'hit-enter',
        'damage-unmatched',
        'damage-eval',
        'gate-rejected',
        'gate-granted',
        'transition-prepared',
        'transition-failed',
        'fall-state-deferred',
        'ragdoll-started',
        'ragdoll-start-timeout',
        'death-timeout-deferred',
        'initial-velocities-suppressed',
        'arm-profile-applied',
        'arm-profile-restored',
        'arm-profile-failed',
        'forward-fall-requested',
        'coherent-momentum-applied',
        'custom-impulse-queued',
        'custom-impulse-applied',
        'dynamics-tuned',
        'motion-sample',
        'rigid-frame-deferred',
        'rigid-fallback-capture',
        'rigid-fallback-unavailable',
        'rigid-baseline',
        'rigid-frame',
        'rigid-joints',
        'rigid-arm-snapshot',
        'rigid-core-snapshot',
        'rigid-summary',
        'rigid-body-summary',
        'rigid-arm-summary',
        'rigid-joint-summary',
        'momentum-window-correction-applied',
        'limb-follower-correction',
        'torso-assist-started',
        'torso-assist-finished',
        'hit-exit',
        'death-packet-armed',
        'death-packet-unarmed'
    )) {
        if ($runtimeSource -notmatch [regex]::Escape('"' + $traceEvent + '"')) {
            throw "Missing required diagnostic trace event: $traceEvent"
        }
    }
    if ($runtimeSource -notmatch 'TRACE_LINE_LIMIT = 12000') {
        throw 'Diagnostic tracing must remain bounded to avoid runaway console logging.'
    }
    if ($runtimeSource -notmatch [regex]::Escape('"zombie.debug.DebugType"')) {
        throw 'Prototype diagnostics must route through the native Project Zomboid debug log when available.'
    }
    foreach ($durableTelemetryToken in @('Utils.getCachePath()', 'StandardOpenOption.TRUNCATE_EXISTING', 'dedicated telemetry ready', 'rigid-arm-snapshot', 'telemetryLinesSinceFlush >= 8')) {
        if ($runtimeSource -notmatch [regex]::Escape($durableTelemetryToken)) {
            throw "Durable telemetry source is missing required token: $durableTelemetryToken"
        }
    }
    foreach ($deferredInitializationToken in @('FORWARD_FALL_MIN_SPEED', 'initialImpulseQueued', 'initialImpulseValidFrame', 'momentumCorrectionAttempted')) {
        if ($runtimeSource -notmatch [regex]::Escape($deferredInitializationToken)) {
            throw "Deferred restrained initialization source is missing required token: $deferredInitializationToken"
        }
    }
    if ($runtimeSource -notmatch 'qualityMode = QUALITY_RESTRAINED') {
        throw 'Restrained whole-body momentum must remain the default quality mode.'
    }
    foreach ($requiredRestrainedSymbol in @('captureMovementSnapshot', 'sampleZombieMovement', 'getRealworldSecondsSinceLastUpdate', 'applyMassWeightedMovementImpulse', 'FORWARD_FALL_PITCH_MULTIPLIERS', 'FOLLOWER_LEG_START_SECONDS', 'MAX_CAPTURED_MOVEMENT_SPEED', 'RAGDOLL_BODY_MASSES', 'selectLocalizedReactionBodyPart')) {
        if ($runtimeSource -notmatch [regex]::Escape($requiredRestrainedSymbol)) {
            throw "Missing restrained ragdoll implementation symbol: $requiredRestrainedSymbol"
        }
    }
    if ($runtimeSource -notmatch [regex]::Escape('return buildAccepted && isGameClient() && !isGameServer();')) {
        throw 'Client enablement must use the exact-build GameClient/GameServer flags, not ZombieBuddy Utils.isClient().'
    }
    foreach ($networkClass in @('zombie.network.GameClient', 'zombie.network.GameServer')) {
        if ($runtimeSource -notmatch [regex]::Escape('"' + $networkClass + '"')) {
            throw "Missing direct multiplayer mode probe for $networkClass"
        }
    }

    $destinationModRoot = Join-Path $testRoot 'mod\MultiplayerRagdollPrototype'
    & (Join-Path $PSScriptRoot 'Build-MultiplayerRagdollPrototype.ps1') -DestinationModRoot $destinationModRoot -LocalConfigurationPath $LocalConfigurationPath

    $prototypeJar = Join-Path $destinationModRoot '42.20\media\java\client\MultiplayerRagdollPrototype.jar'
    if (-not (Test-Path -LiteralPath $prototypeJar -PathType Leaf)) {
        throw "Prototype build did not produce the expected JAR: $prototypeJar"
    }
    if (-not (Test-Path -LiteralPath $java -PathType Leaf)) {
        throw "Missing game Java runtime: $java"
    }
    if (-not (Test-Path -LiteralPath $compilerJar -PathType Leaf)) {
        throw "Missing compiler cache after prototype build: $compilerJar"
    }
    if (-not $zombieBuddyJar) {
        throw 'ZombieBuddy.jar is required to execute the lethal-hit regression probe.'
    }

    $sourceRoot = Join-Path $testRoot 'source'
    $sourceDirectory = Join-Path $sourceRoot 'zombie\characters'
    $gameTimeSourceDirectory = Join-Path $sourceRoot 'zombie'
    $actionSourceDirectory = Join-Path $sourceRoot 'zombie\characters\action'
    $advancedAnimationSourceDirectory = Join-Path $sourceRoot 'zombie\core\skinnedmodel\advancedanimation'
    $animationSourceDirectory = Join-Path $sourceRoot 'zombie\core\skinnedmodel\animation'
    $physicsSourceDirectory = Join-Path $sourceRoot 'zombie\core\physics'
    $classesDirectory = Join-Path $testRoot 'classes'
    New-Item -ItemType Directory -Path $sourceDirectory,$gameTimeSourceDirectory,$actionSourceDirectory,$advancedAnimationSourceDirectory,$animationSourceDirectory,$physicsSourceDirectory,$classesDirectory -Force | Out-Null
    $probePath = Join-Path $sourceDirectory 'MultiplayerRagdollVisibilityProbe.java'
    $zombieStubPath = Join-Path $sourceDirectory 'IsoZombie.java'
    $gameTimeStubPath = Join-Path $gameTimeSourceDirectory 'GameTime.java'
    $networkCharacterAIStubPath = Join-Path $sourceDirectory 'NetworkCharacterAI.java'
    $actionStateStubPath = Join-Path $actionSourceDirectory 'ActionState.java'
    $actionGroupStubPath = Join-Path $actionSourceDirectory 'ActionGroup.java'
    $actionContextStubPath = Join-Path $actionSourceDirectory 'ActionContext.java'
    $animationMultiTrackStubPath = Join-Path $animationSourceDirectory 'AnimationMultiTrack.java'
    $animationPlayerStubPath = Join-Path $animationSourceDirectory 'AnimationPlayer.java'
    $advancedAnimatorStubPath = Join-Path $advancedAnimationSourceDirectory 'AdvancedAnimator.java'
    $bulletStubPath = Join-Path $physicsSourceDirectory 'Bullet.java'
    $ragdollControllerStubPath = Join-Path $physicsSourceDirectory 'RagdollController.java'
    $probeSource = @(
        'package zombie.characters;',
        '',
        'import java.lang.reflect.Field;',
        'import java.lang.reflect.Method;',
        'import pzmod.mpragdollprototype.PrototypeRuntime;',
        'import pzmod.mpragdollprototype.RigidBodyTelemetry;',
        'import zombie.GameTime;',
        'import zombie.core.physics.Bullet;',
        'import zombie.core.physics.RagdollController;',
        '',
        'public final class MultiplayerRagdollVisibilityProbe {',
        '    private MultiplayerRagdollVisibilityProbe() {}',
        '',
        '    public static String compileOnly(',
        '            Object packet,',
        '            Object character,',
        '            Object weapon,',
        '            Throwable thrown) {',
        '        PrototypeRuntime.initialize();',
        '        boolean enabled = PrototypeRuntime.isEnabledClient();',
        '        PrototypeRuntime.enterHitConsequences(character, weapon, null, false, 1.0f, false);',
        '        PrototypeRuntime.beforeApplyDamage(character, 1.0f);',
        '        PrototypeRuntime.exitHitConsequences(character, thrown);',
        '        PrototypeRuntime.enterDeathPacket(packet);',
        '        PrototypeRuntime.exitDeathPacket(packet);',
        '        boolean deferFall = PrototypeRuntime.shouldDeferFallDownExecution(character);',
        '        boolean deferTimeout = PrototypeRuntime.shouldDeferDeadBodyTimeout(character);',
        '        boolean replaceImpulse = PrototypeRuntime.replaceHitReaction(character);',
        '        boolean suppressInitialVelocities = PrototypeRuntime.shouldSuppressInitialVelocities(character);',
        '        PrototypeRuntime.updateRagdollController(character, 0.016f);',
        '        PrototypeRuntime.prepareRagdollFrame(character, 0.016f);',
        '        PrototypeRuntime.captureRagdollFrame(character, new float[77]);',
        '        boolean ragdoll = PrototypeRuntime.canRagdoll(character);',
        '        boolean pose = PrototypeRuntime.canCaptureCorpsePose(character);',
        '        return enabled + ":" + deferFall + ":" + deferTimeout + ":" + replaceImpulse + ":" + suppressInitialVelocities + ":" + ragdoll + ":" + pose + ":" + PrototypeRuntime.status();',
        '    }',
        '',
        '    public static void main(String[] args) throws Exception {',
        '        IsoZombie zombie = new IsoZombie();',
        '        assertTrue(invokeBoolean("isEligibleOffGroundZombie", zombie), "standing zombie should qualify");',
        '        zombie.onFloor = true;',
        '        assertFalse(invokeBoolean("isEligibleOffGroundZombie", zombie), "grounded zombie must not qualify");',
        '        zombie.gettingUp = true;',
        '        assertTrue(invokeBoolean("isEligibleOffGroundZombie", zombie), "getting-up zombie should qualify");',
        '        zombie.gettingUp = false;',
        '        zombie.onFloor = false;',
        '',
        '        assertTrue(invokeBoolean("isSupportedKillingWeapon", new FakeWeapon(true, false, false)), "melee should qualify");',
        '        assertTrue(invokeBoolean("isSupportedKillingWeapon", new FakeWeapon(false, true, false)), "firearm should qualify");',
        '        assertFalse(invokeBoolean("isSupportedKillingWeapon", new FakeWeapon(false, true, true)), "explosive should not qualify");',
        '        assertFalse(invokeBoolean("isSupportedKillingWeapon", new FakeWeapon(false, false, false)), "nonweapon should not qualify");',
        '        zombie.health = 0.75f;',
        '        assertTrue(invokeDamageCheck(zombie, 0.75f), "equal final damage should be lethal");',
        '        assertFalse(invokeDamageCheck(zombie, 0.74f), "sublethal final damage must not prepare ragdoll");',
        '        assertTrue(invokeIntString("selectImpulseBodyPart", "ShotHeadFwd02") == 0, "stabilized head reactions must retain pelvis redirection");',
        '        assertTrue(invokeIntString("selectLocalizedReactionBodyPart", "ShotHeadFwd02") == 2, "restrained head reactions must target only the head");',
        '        assertTrue(invokeIntString("selectLocalizedReactionBodyPart", "ShotShoulderR") == 1, "restrained shoulder reactions must redirect to the spine");',
        '        assertTrue(invokeIntString("selectLocalizedReactionBodyPart", "Step_L") == 1, "restrained limb reactions must redirect to the spine");',
        '        assertTrue(invokeImpulseMagnitude(true, "Base.Shotgun:shotgun_shells:Rifle", 2.0f) == 16.0f, "shotgun impulse must remain below the previous launch force");',
        '        assertTrue(invokeImpulseMagnitude(true, "Base.Revolver38:Handgun", 2.0f) == 10.0f, "handgun impulse must remain torso-scale");',
        '        assertTrue(invokeImpulseMagnitude(false, "Base.BaseballBat:Bat", 1.1f) < 8.0f, "melee impulse must remain a shove rather than a launch");',
        '        assertTrue(invokeUpwardImpulse(true, "Base.Shotgun:shotgun_shells:Rifle") == 1.0f, "shotgun lift must be tightly bounded");',
        '        assertTrue(invokeUpwardImpulse(false, "Base.BaseballBat:Bat") == 0.25f, "melee lift must be nearly zero");',
        '        assertNear(0.0263f, invokeLocalizedReactionMagnitude(true, "Base.Jackhammer:base:shotgun_shells:Rifle", 2.0f, 2), 0.002f, "shotgun head reactions must be a slight velocity change rather than a neck launch");',
        '        assertNear(0.0996f, invokeLocalizedReactionMagnitude(true, "Base.Jackhammer:base:shotgun_shells:Rifle", 2.0f, 1), 0.003f, "shotgun spine reactions must remain below one tenth impulse");',
        '        assertNear(0.0560f, invokeLocalizedReactionMagnitude(true, "Base.Sten_MK5:base:bullets_9mm:Rifle", 2.0f, 1), 0.003f, "9mm SMGs must use a small mass-scaled spine reaction");',
        '        assertNear(0.0230f, invokeLocalizedReactionMagnitude(true, "Base.HuntingRifle:base:bullets_308:Rifle", 2.0f, 2), 0.003f, "rifle head reactions must remain mass-scaled");',
        '        assertNear(2.4f, invokeMovementImpulse(2.4f), 0.0001f, "movement velocity must transfer one-for-one into whole-body momentum");',
        '        assertNear(3.25f, invokeMovementImpulse(10.0f), 0.0001f, "network corrections must not create excessive momentum");',
        '        zombie.x = 10.04f;',
        '        zombie.y = 20.0f;',
        '        zombie.lastX = 10.0f;',
        '        zombie.lastY = 20.0f;',
        '        GameTime.getInstance().frameSeconds = 0.02f;',
        '        assertNear(1.0f, invokeMovementSnapshotFloat(zombie, "directionX"), 0.0001f, "movement direction must follow actual displacement");',
        '        assertNear(2.0f, invokeMovementSnapshotFloat(zombie, "speed"), 0.0001f, "movement velocity must be normalized by real frame time");',
        '        assertTrue("displacement".equals(invokeMovementSnapshotString(zombie, "source")), "movement traces must identify displacement capture");',
        '        IsoZombie fastZombie = new IsoZombie();',
        '        fastZombie.x = 50.08f;',
        '        fastZombie.lastX = 50.0f;',
        '        assertNear(2.5f, invokeMovementSnapshotFloat(fastZombie, "speed"), 0.0001f, "implausible direct displacement spikes must be clamped before momentum targeting");',
        '        IsoZombie historyZombie = new IsoZombie();',
        '        historyZombie.x = 30.0f;',
        '        historyZombie.y = 40.0f;',
        '        historyZombie.lastX = 30.0f;',
        '        historyZombie.lastY = 40.0f;',
        '        invokeMovementSample(historyZombie, 1_000_000_000L);',
        '        historyZombie.x = 30.08f;',
        '        invokeMovementSample(historyZombie, 1_050_000_000L);',
        '        historyZombie.lastX = historyZombie.x;',
        '        assertNear(1.0f, invokeMovementSnapshotFloatAt(historyZombie, "directionX", 1_100_000_000L), 0.0001f, "recent movement history must retain locomotion direction across a zero-displacement lethal frame");',
        '        assertNear(1.6f, invokeMovementSnapshotFloatAt(historyZombie, "speed", 1_100_000_000L), 0.001f, "recent movement history must retain locomotion speed across a zero-displacement lethal frame");',
        '        assertTrue("history".equals(invokeMovementSnapshotStringAt(historyZombie, "source", 1_100_000_000L)), "movement traces must identify history fallback");',
        '        assertNear(50.0f, invokeMovementSnapshotFloatAt(historyZombie, "historyAgeMillis", 1_100_000_000L), 0.001f, "history fallback must expose sample age for diagnostics");',
        '        historyZombie.x = 30.28f;',
        '        invokeMovementSample(historyZombie, 1_100_000_000L);',
        '        historyZombie.lastX = historyZombie.x;',
        '        assertNear(2.05f, invokeMovementSnapshotFloatAt(historyZombie, "speed", 1_120_000_000L), 0.01f, "movement history must smooth a clamped root-motion spike with the previous sample");',
        '        historyZombie.x = 30.10f;',
        '        historyZombie.lastX = 30.08f;',
        '        assertTrue("displacement".equals(invokeMovementSnapshotStringAt(historyZombie, "source", 1_130_000_000L)), "current displacement must override recent history");',
        '        historyZombie.lastX = historyZombie.x;',
        '        assertTrue("stationary".equals(invokeMovementSnapshotStringAt(historyZombie, "source", 1_300_000_000L)), "stale movement history must be rejected");',
        '        assertTrue("restrained".equals(PrototypeRuntime.setQualityMode("restrained")), "restrained mode must be selectable");',
        '        assertTrue("falldown-ragdoll".equals(invokeStateSelection(true, "Base.Pistol")), "firearms must use the fast fall animation seed");',
        '        assertTrue("falldown-ragdoll".equals(invokeStateSelection(false, "Base.Axe")), "restrained melee must avoid a staged backward fall");',
        '        assertTrue(invokeForwardFallSelection(true, 1.2f, -1.0f, 0.0f, 1.0f, 0.0f), "an approaching firearm target must request a face-first fall");',
        '        assertFalse(invokeForwardFallSelection(true, 0.5f, -1.0f, 0.0f, 1.0f, 0.0f), "slow firearm deaths must retain native fall selection");',
        '        assertFalse(invokeForwardFallSelection(false, 1.2f, -1.0f, 0.0f, 1.0f, 0.0f), "melee deaths must retain their hit-driven fall selection");',
        '        assertFalse(invokeForwardFallSelection(true, 1.2f, 1.0f, 0.0f, 1.0f, 0.0f), "targets moving away from the shooter must not be forced face-first");',
        '        assertTrue("stabilized".equals(PrototypeRuntime.setQualityMode("stabilized")), "stabilized mode must remain selectable");',
        '        assertTrue("falldown-speardeath1-ragdoll".equals(invokeStateSelection(false, "Base.Spear")), "spears must use the spear death animation seed");',
        '        assertTrue("falldown-knifedeath-ragdoll".equals(invokeStateSelection(false, "Base.HuntingKnife")), "knives must use the knife death animation seed");',
        '        assertTrue("staggerback-knockeddown-ragdoll".equals(invokeStateSelection(false, "Base.Axe")), "other melee weapons must use the generic stagger seed");',
        '',
        '        zombie.hitFromBehind = true;',
        '        assertTrue(invokeBoolean("forceRagdollDeath", zombie), "ragdoll transition should succeed");',
        '        assertTrue(zombie.usePhysicHitReaction, "physics hit reaction must be enabled");',
        '        assertTrue(zombie.ragdollFall, "ragdoll fall must be enabled");',
        '        assertFalse(zombie.onFloor, "standing transition must begin off-floor");',
        '        assertTrue(zombie.knockedDown, "zombie must be knocked down");',
        '        assertTrue(zombie.staggerBack, "zombie must enter stagger-back flow");',
        '        assertTrue("".equals(zombie.hitReaction), "normal death hit reaction must be cleared");',
        '        assertTrue("BEHIND".equals(zombie.playerAttackPosition), "rear hits must select the BEHIND ragdoll node");',
        '        assertTrue(zombie.hitForce == 1.0f, "ragdoll transition must receive full hit force");',
        '        assertTrue("wasHit".equals(zombie.reportedEvent), "animation graph must be notified");',
        '        assertTrue("staggerback-knockeddown-ragdoll".equals(zombie.getActionStateName()), "action state must be forced directly");',
        '        assertTrue("staggerback-knockeddown-ragdoll".equals(zombie.getAnimationStateName()), "animation state must be forced directly");',
        '        assertTrue(zombie.animationPlayer.getMultiTrack().containsAnyRagdollTracks(), "forced state must create a ragdoll track");',
        '',
        '        IsoZombie forwardFallZombie = new IsoZombie();',
        '        assertTrue(invokeForceRagdollDeath(forwardFallZombie, true, 1.2f, -1.0f, 0.0f, 1.0f, 0.0f), "approaching ranged transition must succeed");',
        '        assertTrue(forwardFallZombie.fallOnFront, "an approaching ranged lethal hit must set the native fall-on-front flag before ragdoll startup");',
        '',
        '        zombie.dead = true;',
        '        invokeArm(zombie, 77);',
        '        assertTrue(PrototypeRuntime.shouldDeferFallDownExecution(zombie), "corpse conversion must wait for ragdoll startup");',
        '        zombie.animationPlayer.setRagdollSimulationActive(true);',
        '        zombie.onFloor = false;',
        '        Bullet.reset();',
        '        RagdollController controller = new RagdollController(zombie, 101);',
        '        assertTrue("legacy".equals(PrototypeRuntime.setQualityMode("legacy")), "legacy mode must be selectable");',
        '        assertFalse(PrototypeRuntime.shouldSuppressInitialVelocities(controller), "legacy mode must preserve vanilla animation-derived velocities");',
        '        assertFalse(PrototypeRuntime.replaceHitReaction(controller), "legacy mode must leave the vanilla controller untouched");',
        '        PrototypeRuntime.updateRagdollController(controller, 0.016f);',
        '        assertTrue(Bullet.impulseCalls == 0, "legacy mode must not add custom impulses");',
        '        assertTrue(Bullet.dynamicsCalls == 0, "legacy mode must not tune body dynamics");',
        '        assertTrue("stabilized".equals(PrototypeRuntime.setQualityMode("stabilized")), "stabilized mode must be selectable");',
        '        assertTrue(PrototypeRuntime.shouldSuppressInitialVelocities(controller), "stabilized lethal ragdolls must reject animation-derived bone velocities");',
        '        assertTrue(PrototypeRuntime.shouldSuppressInitialVelocities(controller), "velocity suppression must remain active throughout ragdoll reinitialization");',
        '        assertTrue(PrototypeRuntime.replaceHitReaction(controller), "armed ragdoll must replace the disabled vanilla hit impulse");',
        '        assertTrue(Bullet.impulseCalls == 1, "initial custom impulse must be applied exactly once");',
        '        assertTrue(Bullet.lastBodyPart == 0, "initial custom impulse must target only the pelvis");',
        '        assertFalse(PrototypeRuntime.replaceHitReaction(controller), "initial impulse must not be duplicated");',
        '        PrototypeRuntime.updateRagdollController(controller, 0.016f);',
        '        assertTrue(Bullet.dynamicsCalls == 11, "every ragdoll rigid body must receive stabilized dynamics");',
        '        assertTrue(Bullet.dynamics[7][2] == 0.995f && Bullet.dynamics[9][2] == 0.995f, "upper arms must retain stronger-than-vanilla shoulder damping");',
        '        assertTrue(Bullet.dynamics[8][2] == 0.97f && Bullet.dynamics[10][2] == 0.97f, "lower arms must settle without becoming rigid");',
        '        assertTrue(Bullet.dynamics[0][4] >= 1.6f && Bullet.dynamics[0][5] >= 2.5f, "sleep thresholds must not be lower than vanilla");',
        '        assertTrue(Bullet.dynamics[7][6] == 1.5f && Bullet.dynamics[7][7] == 0.5f, "limb contact friction must remain at vanilla values");',
        '        assertTrue(Bullet.impulseCalls == 1, "stabilized mode must not add torso assistance");',
        '        assertTrue("assisted".equals(PrototypeRuntime.setQualityMode("assisted")), "assisted mode must be selectable");',
        '        PrototypeRuntime.updateRagdollController(controller, 0.016f);',
        '        assertTrue(Bullet.impulseCalls == 2, "assisted mode must add only one bounded pelvis impulse per update");',
        '        assertTrue(Bullet.lastBodyPart == 0, "assistance must never target the spine or limbs");',
        '',
        '        IsoZombie restrainedZombie = new IsoZombie();',
        '        restrainedZombie.dead = true;',
        '        restrainedZombie.onFloor = false;',
        '        restrainedZombie.animationPlayer.setRagdollSimulationActive(true);',
        '        assertTrue("restrained".equals(PrototypeRuntime.setQualityMode("restrained")), "restrained mode must be selected before arming the death");',
        '        invokeArm(restrainedZombie, 78);',
        '        Bullet.reset();',
        '        RagdollController restrainedController = new RagdollController(restrainedZombie, 102);',
        '        seedRagdollTemplates();',
        '        int profileAppliesBefore = statusMetric("armProfileApplies");',
        '        int profileRestoresBefore = statusMetric("armProfileRestores");',
        '        PrototypeRuntime.beforeAddRagdollToWorld(restrainedController);',
        '        assertTrue(Bullet.defineBodyPartInfoCalls == 1 && Bullet.defineConstraintCalls == 0, "restrained creation must leave native constraints untouched");',
        '        assertNear(0.040f, Bullet.lastBodyPartInfo[7 * 10 + 6], 0.0001f, "upper-arm mass must be moderately increased during creation");',
        '        assertNear(0.035f, Bullet.lastBodyPartInfo[8 * 10 + 6], 0.0001f, "lower-arm mass must be moderately increased during creation");',
        '        assertNear(0.068f, Bullet.lastBodyPartInfo[7 * 10 + 2], 0.0001f, "upper-arm collision radius must be reduced during creation");',
        '        assertNear(0.068f, Bullet.lastBodyPartInfo[8 * 10 + 2], 0.0001f, "lower-arm collision radius must be reduced during creation");',
        '        PrototypeRuntime.afterAddRagdollToWorld(restrainedController, null);',
        '        assertTrue(Bullet.defineBodyPartInfoCalls == 2 && Bullet.defineConstraintCalls == 0, "vanilla body template must be restored without redefining constraints");',
        '        assertNear(0.03075f, Bullet.lastBodyPartInfo[7 * 10 + 6], 0.0001f, "template restoration must restore vanilla upper-arm mass");',
        '        assertNear(0.080f, Bullet.lastBodyPartInfo[7 * 10 + 2], 0.0001f, "template restoration must restore vanilla arm radius");',
        '        assertTrue(statusMetric("armProfileApplies") == profileAppliesBefore + 1, "arm profile application must be counted");',
        '        assertTrue(statusMetric("armProfileRestores") == profileRestoresBefore + 1, "arm profile restoration must be counted");',
        '        Bullet.reset();',
        '        assertTrue(PrototypeRuntime.shouldSuppressInitialVelocities(restrainedController), "restrained ragdolls must suppress independent bone velocities");',
        '        assertTrue(PrototypeRuntime.replaceHitReaction(restrainedController), "restrained ragdolls must suppress vanilla hit reaction while preserving coherent root momentum");',
        '        assertTrue(Bullet.impulseCalls == 11, "captured locomotion must be applied coherently before the first physics step");',
        '        float[] masses = new float[] {0.1481f, 0.3111f, 0.0823f, 0.11125f, 0.0643f, 0.11125f, 0.0643f, 0.040f, 0.035f, 0.040f, 0.035f};',
        '        for (int bodyPart = 0; bodyPart < 11; bodyPart++) {',
        '            assertTrue(Bullet.callBodyParts[bodyPart] == bodyPart, "pre-step locomotion must visit every rigid body in order");',
        '            assertNear(2.0f * masses[bodyPart], Bullet.callImpulses[bodyPart][0], 0.0001f, "pre-step locomotion must give every body the same velocity change");',
        '        }',
        '        assertTrue(PrototypeRuntime.replaceHitReaction(restrainedController), "queued restrained initialization must continue suppressing vanilla hit reaction without duplicating work");',
        '        assertTrue(Bullet.impulseCalls == 11, "repeated hit-reaction callbacks must not duplicate pre-step locomotion");',
        '        PrototypeRuntime.updateRagdollController(restrainedController, 0.016f);',
        '        assertTrue(Bullet.dynamicsCalls == 11, "restrained mode must tune every rigid body once");',
        '        assertNear(0.05f, Bullet.dynamics[0][1], 0.0001f, "torso linear damping must remain light");',
        '        assertNear(0.12f, Bullet.dynamics[7][1], 0.0001f, "upper arms must receive moderate linear damping");',
        '        assertNear(0.18f, Bullet.dynamics[8][1], 0.0001f, "lower arms must receive stronger linear damping");',
        '        assertTrue(Bullet.dynamics[7][2] >= 0.9995f && Bullet.dynamics[8][2] >= 0.9995f, "arms must suppress independent angular motion without erasing torso-following velocity");',
        '        assertNear(0.35f, Bullet.dynamics[7][6], 0.0001f, "upper-arm contact friction must be reduced");',
        '        assertNear(0.20f, Bullet.dynamics[8][6], 0.0001f, "lower-arm contact friction must be reduced further");',
        '        assertNear(0.0f, Bullet.dynamics[7][7], 0.0001f, "arm rolling friction must be disabled");',
        '        assertTrue(Bullet.dynamics[3][2] >= 0.995f && Bullet.dynamics[4][2] >= 0.995f, "legs must remain angularly restrained while preserving forward motion");',
        '        assertTrue(Bullet.dynamics[0][2] < Bullet.dynamics[7][2] && Bullet.dynamics[1][2] < Bullet.dynamics[7][2], "pelvis and spine must stay freer than the arms while sharing their linear velocity");',
        '        assertTrue(Bullet.dynamics[7][3] >= 0.4f && Bullet.dynamics[7][4] <= 1.9f && Bullet.dynamics[7][5] <= 3.0f, "arms must not freeze early under oversized sleep thresholds");',
        '        assertTrue(Bullet.dynamics[3][3] >= 0.45f && Bullet.dynamics[3][4] <= 1.9f && Bullet.dynamics[3][5] <= 3.0f, "legs must remain simulated until genuinely settled");',
        '        assertTrue(Bullet.impulseCalls == 11, "dynamics setup must not add another momentum pass");',
        '        restrainedController.firstFrame = false;',
        '        float[] restrainedOpening = createRigidFrame(25.0f, 40.0f, 15.0f);',
        '        captureRigidFrame(restrainedController, restrainedOpening);',
        '        assertTrue(Bullet.impulseCalls == 11, "telemetry baselines must not modify the ragdoll");',
        '        float[] slowForwardFrame = restrainedOpening.clone();',
        '        moveAllBodies(slowForwardFrame, 0.01f, 0.0f, 0.0f);',
        '        slowForwardFrame[4 * 7 + 1] += 0.20f;',
        '        slowForwardFrame[8 * 7 + 1] += 0.20f;',
        '        captureRigidFrame(restrainedController, slowForwardFrame);',
        '        PrototypeRuntime.updateRagdollController(restrainedController, 0.02f);',
        '        assertTrue(Bullet.impulseCalls == 12, "first measured melee frame must add only the localized reaction and never kick an arm directly");',
        '        assertTrue(Bullet.callBodyParts[11] == 2, "localized reaction must remain last and target only the selected body");',
        '        float[] postInitializationSlowFrame = slowForwardFrame.clone();',
        '        moveAllBodies(postInitializationSlowFrame, 0.01f, 0.0f, 0.0f);',
        '        captureRigidFrame(restrainedController, postInitializationSlowFrame);',
        '        PrototypeRuntime.updateRagdollController(restrainedController, 0.02f);',
        '        assertTrue(Bullet.impulseCalls == 12, "windowed momentum correction must wait for a stable displacement sample");',
        '        float[] coherentFollowerFrame = postInitializationSlowFrame.clone();',
        '        for (int frame = 0; frame < 2; frame++) {',
        '            moveAllBodies(coherentFollowerFrame, 0.04f, 0.0f, 0.0f);',
        '            captureRigidFrame(restrainedController, coherentFollowerFrame);',
        '            PrototypeRuntime.updateRagdollController(restrainedController, 0.02f);',
        '        }',
        '        assertTrue(Bullet.impulseCalls == 23, "one displacement-window correction must apply coherently after eighty milliseconds");',
        '        for (int bodyPart = 0; bodyPart < 11; bodyPart++) {',
        '            assertTrue(Bullet.callBodyParts[12 + bodyPart] == bodyPart, "windowed momentum correction must visit every rigid body in order");',
        '            assertTrue(Bullet.callImpulses[12 + bodyPart][0] > 0.0f, "windowed correction must follow captured locomotion");',
        '        }',
        '        float[] restrainedArmFling = coherentFollowerFrame.clone();',
        '        moveAllBodies(restrainedArmFling, 0.04f, 0.0f, 0.0f);',
        '        restrainedArmFling[8 * 7 + 1] += 0.20f;',
        '        captureRigidFrame(restrainedController, restrainedArmFling);',
        '        PrototypeRuntime.updateRagdollController(restrainedController, 0.02f);',
        '        assertTrue(Bullet.impulseCalls == 23, "later arm motion must not be pumped by continuous follower impulses");',
        '        float[] restrainedLegFling = restrainedArmFling.clone();',
        '        moveAllBodies(restrainedLegFling, 0.04f, 0.0f, 0.0f);',
        '        restrainedLegFling[4 * 7 + 1] += 0.20f;',
        '        captureRigidFrame(restrainedController, restrainedLegFling);',
        '        PrototypeRuntime.updateRagdollController(restrainedController, 0.02f);',
        '        assertTrue(Bullet.impulseCalls == 24, "leg correction may begin after the protected opening window");',
        '        assertTrue(Bullet.lastBodyPart == 4, "late follower correction must target only the measured lower-leg outlier");',
        '        restrainedZombie.onFloor = true;',
        '        float[] groundedFling = restrainedLegFling.clone();',
        '        groundedFling[8 * 7 + 1] += 0.20f;',
        '        captureRigidFrame(restrainedController, groundedFling);',
        '        PrototypeRuntime.updateRagdollController(restrainedController, 0.02f);',
        '        assertTrue(Bullet.impulseCalls == 24, "follower corrections must stop when the corpse reaches the floor");',
        '        restrainedZombie.onFloor = false;',
        '        IsoZombie rangedZombie = new IsoZombie();',
        '        rangedZombie.dead = true;',
        '        rangedZombie.onFloor = false;',
        '        rangedZombie.animationPlayer.setRagdollSimulationActive(true);',
        '        invokeArm(rangedZombie, 79, true);',
        '        Bullet.reset();',
        '        RagdollController rangedController = new RagdollController(rangedZombie, 103);',
        '        assertTrue(PrototypeRuntime.replaceHitReaction(rangedController), "moving firearm deaths must preserve coherent locomotion and queue only a gentle pitch profile");',
        '        assertTrue(Bullet.impulseCalls == 11, "ranged locomotion must be present before Bullet selects the opening fall");',
        '        for (int bodyPart = 0; bodyPart < masses.length; bodyPart++) {',
        '            assertNear(2.0f * masses[bodyPart], Bullet.callImpulses[bodyPart][0], 0.0001f, "ranged pre-step locomotion must remain coherent");',
        '        }',
        '        rangedController.firstFrame = false;',
        '        float[] rangedOpening = createRigidFrame(80.0f, 20.0f, 10.0f);',
        '        captureRigidFrame(rangedController, rangedOpening);',
        '        assertTrue(Bullet.impulseCalls == 11, "ranged baseline capture must not add another locomotion pass");',
        '        float[] rangedSlowFrame = rangedOpening.clone();',
        '        moveAllBodies(rangedSlowFrame, 0.01f, 0.0f, 0.0f);',
        '        captureRigidFrame(rangedController, rangedSlowFrame);',
        '        assertTrue(Bullet.impulseCalls == 23, "first measured ranged frame must apply eleven gentle pitch adjustments plus one localized reaction");',
        '        float totalPitchImpulse = 0.0f;',
        '        for (int bodyPart = 0; bodyPart < masses.length; bodyPart++) {',
        '            assertTrue(Bullet.callBodyParts[11 + bodyPart] == bodyPart, "forward pitch must visit every rigid body in order");',
        '            totalPitchImpulse += Bullet.callImpulses[11 + bodyPart][0];',
        '        }',
        '        assertNear(0.0f, totalPitchImpulse, 0.0002f, "the pitch adjustment must not add or remove whole-body momentum");',
        '        float spinePitchVelocity = Bullet.callImpulses[12][0] / masses[1];',
        '        float upperArmPitchVelocity = Bullet.callImpulses[18][0] / masses[7];',
        '        float lowerArmPitchVelocity = Bullet.callImpulses[19][0] / masses[8];',
        '        float lowerLegPitchVelocity = Bullet.callImpulses[15][0] / masses[4];',
        '        assertNear(spinePitchVelocity, upperArmPitchVelocity, 0.0001f, "upper arms must receive their parent spine velocity adjustment");',
        '        assertNear(upperArmPitchVelocity, lowerArmPitchVelocity, 0.0001f, "lower arms must follow upper arms without a velocity split");',
        '        assertTrue(spinePitchVelocity > 0.0f && lowerLegPitchVelocity < 0.0f, "gentle pitch must advance the torso while only slightly retaining the feet");',
        '        assertTrue(Math.abs(spinePitchVelocity / lowerLegPitchVelocity) < 1.0f, "pitch bias must remain far below the previous tenfold torso-to-feet split");',
        '        assertTrue(Bullet.callBodyParts[22] == 2, "firearm reaction must remain localized after forward pitch");',
        '        PrototypeRuntime.updateRagdollController(rangedController, 0.02f);',
        '        assertTrue(Bullet.impulseCalls == 23, "ranged correction must wait for the displacement window");',
        '        float[] rangedMaintenanceFrame = rangedSlowFrame.clone();',
        '        for (int frame = 0; frame < 3; frame++) {',
        '            moveAllBodies(rangedMaintenanceFrame, 0.01f, 0.0f, 0.0f);',
        '            captureRigidFrame(rangedController, rangedMaintenanceFrame);',
        '            PrototypeRuntime.updateRagdollController(rangedController, 0.02f);',
        '        }',
        '        assertTrue(Bullet.impulseCalls == 34, "ranged momentum must receive at most one coherent windowed correction");',
        '        for (int bodyPart = 0; bodyPart < masses.length; bodyPart++) {',
        '            assertNear(Bullet.callImpulses[23][0] / masses[0], Bullet.callImpulses[23 + bodyPart][0] / masses[bodyPart], 0.0001f, "windowed correction must preserve one coherent velocity across the body");',
        '        }',
        '        assertFalse(PrototypeRuntime.shouldDeferFallDownExecution(zombie), "active simulation is handled by vanilla fall state");',
        '        assertTrue(PrototypeRuntime.shouldDeferDeadBodyTimeout(new NetworkCharacterAI(zombie)), "active ragdoll must suppress the network corpse timeout");',
        '        zombie.animationPlayer.setRagdollSimulationActive(false);',
        '        assertFalse(PrototypeRuntime.shouldDeferFallDownExecution(zombie), "settled ragdoll must allow corpse creation");',
        '        assertFalse(PrototypeRuntime.shouldDeferDeadBodyTimeout(new NetworkCharacterAI(zombie)), "settled ragdoll must release the network corpse timeout");',
        '',
        '        IsoZombie fallbackZombie = new IsoZombie();',
        '        fallbackZombie.dead = true;',
        '        fallbackZombie.animationPlayer.setRagdollSimulationActive(true);',
        '        invokeArm(fallbackZombie, 79);',
        '        RagdollController fallbackController = new RagdollController(fallbackZombie, 103);',
        '        fallbackController.firstFrame = false;',
        '        float[] fallbackOpening = createRigidFrame(60.0f, 30.0f, 10.0f);',
        '        fallbackController.setRigidBodyBuffer(fallbackOpening);',
        '        int fallbackCallbacksBefore = statusMetric("rigidCallbacks");',
        '        int fallbackValidBefore = statusMetric("rigidValidFrames");',
        '        int fallbackCapturesBefore = statusMetric("rigidFallbackCaptures");',
        '        PrototypeRuntime.prepareRagdollFrame(fallbackController, 0.02f);',
        '        PrototypeRuntime.finishRagdollFrame(fallbackController);',
        '        PrototypeRuntime.updateRagdollController(fallbackController, 0.02f);',
        '        assertTrue(statusMetric("rigidCallbacks") == fallbackCallbacksBefore + 1, "post-update fallback must capture a frame when simulateRagdoll advice is absent");',
        '        assertTrue(statusMetric("rigidValidFrames") == fallbackValidBefore + 1, "post-update fallback must establish one valid rigid-body baseline");',
        '        assertTrue(statusMetric("rigidFallbackCaptures") == fallbackCapturesBefore + 1, "update-exit and post-update fallbacks must capture only once per update");',
        '        float[] directFrame = fallbackOpening.clone();',
        '        moveAllBodies(directFrame, 0.02f, 0.0f, 0.0f);',
        '        fallbackController.setRigidBodyBuffer(directFrame);',
        '        PrototypeRuntime.prepareRagdollFrame(fallbackController, 0.02f);',
        '        PrototypeRuntime.captureRagdollFrame(fallbackController, directFrame);',
        '        PrototypeRuntime.finishRagdollFrame(fallbackController);',
        '        PrototypeRuntime.updateRagdollController(fallbackController, 0.02f);',
        '        assertTrue(statusMetric("rigidCallbacks") == fallbackCallbacksBefore + 2, "fallback must not duplicate a frame already captured by direct advice");',
        '        assertTrue(statusMetric("rigidValidFrames") == fallbackValidBefore + 2, "direct capture plus fallback must produce exactly one valid frame per update");',
        '        assertTrue(statusMetric("rigidFallbackCaptures") == fallbackCapturesBefore + 1, "a working direct hook must bypass both fallback layers");',
        '',
        '        RigidBodyTelemetry telemetry = new RigidBodyTelemetry(1.0f, 0.0f);',
        '        assertTrue(telemetry.capture(new float[77], 0.02f, 900_000_000L, false) == RigidBodyTelemetry.CAPTURE_INVALID_VALUES, "zeroed native buffers must not become a world-origin baseline");',
        '        float[] openingFrame = createRigidFrame(100.0f, 50.0f, 25.0f);',
        '        assertTrue(telemetry.capture(openingFrame, 0.02f, 1_000_000_000L, true) == RigidBodyTelemetry.CAPTURE_DEFERRED_FIRST_FRAME, "controller first frames must be copied but deferred");',
        '        assertFalse(telemetry.hasBaseline(), "deferred first frames must not establish the telemetry baseline");',
        '        assertTrue(telemetry.capture(openingFrame, 0.02f, 1_020_000_000L, false) == RigidBodyTelemetry.CAPTURE_BASELINE, "first valid physics frame must establish the baseline");',
        '        float[] coherentFrame = openingFrame.clone();',
        '        moveAllBodies(coherentFrame, 0.04f, 0.0f, 0.0f);',
        '        assertTrue(telemetry.capture(coherentFrame, 0.02f, 1_040_000_000L, false) == RigidBodyTelemetry.CAPTURE_UPDATED, "coherent whole-body motion must be processed");',
        '        assertNear(0.04f, telemetry.getComDisplacementX(), 0.0001f, "center-of-mass displacement must retain forward motion");',
        '        assertNear(0.0f, telemetry.getCurrentVelocityCoherenceRms(), 0.001f, "identical body velocities must report coherent motion");',
        '        assertNear(0.0f, telemetry.getMaxOpeningDisplacement(8), 0.0001f, "coherent translation must not look like lower-arm flinging");',
        '        float[] armFlingFrame = coherentFrame.clone();',
        '        moveAllBodies(armFlingFrame, 0.04f, 0.0f, 0.0f);',
        '        armFlingFrame[8 * 7 + 1] += 0.20f;',
        '        setBodyRotation(armFlingFrame, 8, 0.0f, 0.0f, 0.70710677f, 0.70710677f);',
        '        telemetry.capture(armFlingFrame, 0.02f, 1_060_000_000L, false);',
        '        assertTrue(telemetry.getMaxOpeningDisplacement(8) > 0.19f, "lower-arm displacement must be isolated from whole-body translation");',
        '        assertTrue(telemetry.getMaxRelativeAngularSpeed(8) > 70.0f, "rapid lower-arm spin must be visible in angular telemetry");',
        '        assertTrue(telemetry.getMaxJointStretch(7) > 0.04f, "left-elbow stretch must be measured against its opening distance");',
        '        assertTrue(telemetry.getMaxJointAngularDeviation(7) > 1.5f, "left-elbow rotation must be measured against its opening pose");',
        '        telemetry.observeState(false, false, false, true);',
        '        assertFalse(telemetry.frameDetails().contains("100.0"), "telemetry must never log absolute world coordinates");',
        '        assertTrue(telemetry.bodySummaryDetails().contains("leftLowerArm"), "native body eight must be labeled as the left lower arm");',
        '        assertTrue(telemetry.armFrameDetails().contains("phase=airborne"), "arm snapshots must identify pre-floor motion");',
        '        assertTrue(telemetry.armFrameDetails().contains("maxRelativeAngular=78") && telemetry.armFrameDetails().contains("@3"), "arm peak timing must identify the measured frame");',
        '        assertTrue(telemetry.coreFrameDetails().contains("spine{linear="), "core snapshots must expose torso and leg motion");',
        '        assertTrue(telemetry.armSummaryDetails().contains("maxRelativeAngular="), "arm summaries must retain peak angular motion");',
        '        assertTrue(telemetry.armSummaryDetails().contains("airAngular="), "arm summaries must separate airborne peaks from floor contact");',
        '        assertTrue(RigidBodyTelemetry.shouldLogSnapshot(256), "long falls must retain a bounded late snapshot");',
        '        assertFalse(RigidBodyTelemetry.shouldLogSnapshot(257), "unscheduled frames must remain in-memory only");',
        '        System.out.println("Passed forced-state, corpse-lifecycle, and rigid-body telemetry probe.");',
        '    }',
        '',
        '    private static float[] createRigidFrame(float worldX, float worldY, float worldZ) {',
        '        float[] frame = new float[77];',
        '        setBody(frame, 0, worldX, worldY + 1.0f, worldZ);',
        '        setBody(frame, 1, worldX, worldY + 1.5f, worldZ);',
        '        setBody(frame, 2, worldX, worldY + 2.0f, worldZ);',
        '        setBody(frame, 3, worldX + 0.2f, worldY + 0.8f, worldZ);',
        '        setBody(frame, 4, worldX + 0.2f, worldY + 0.3f, worldZ);',
        '        setBody(frame, 5, worldX - 0.2f, worldY + 0.8f, worldZ);',
        '        setBody(frame, 6, worldX - 0.2f, worldY + 0.3f, worldZ);',
        '        setBody(frame, 7, worldX + 0.45f, worldY + 1.5f, worldZ);',
        '        setBody(frame, 8, worldX + 0.90f, worldY + 1.5f, worldZ);',
        '        setBody(frame, 9, worldX - 0.45f, worldY + 1.5f, worldZ);',
        '        setBody(frame, 10, worldX - 0.90f, worldY + 1.5f, worldZ);',
        '        return frame;',
        '    }',
        '',
        '    private static void setBody(float[] frame, int bodyPart, float x, float y, float z) {',
        '        int offset = bodyPart * 7;',
        '        frame[offset] = x;',
        '        frame[offset + 1] = y;',
        '        frame[offset + 2] = z;',
        '        frame[offset + 6] = 1.0f;',
        '    }',
        '',
        '    private static void setBodyRotation(float[] frame, int bodyPart, float x, float y, float z, float w) {',
        '        int offset = bodyPart * 7 + 3;',
        '        frame[offset] = x;',
        '        frame[offset + 1] = y;',
        '        frame[offset + 2] = z;',
        '        frame[offset + 3] = w;',
        '    }',
        '',
        '    private static void moveAllBodies(float[] frame, float x, float y, float z) {',
        '        for (int bodyPart = 0; bodyPart < 11; bodyPart++) {',
        '            int offset = bodyPart * 7;',
        '            frame[offset] += x;',
        '            frame[offset + 1] += y;',
        '            frame[offset + 2] += z;',
        '        }',
        '    }',
        '',
        '    private static boolean invokeBoolean(String methodName, Object argument) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod(methodName, Object.class);',
        '        method.setAccessible(true);',
        '        return Boolean.TRUE.equals(method.invoke(null, argument));',
        '    }',
        '',
        '    private static boolean invokeDamageCheck(Object target, float damage) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("wouldBeKilledByDamage", Object.class, Float.TYPE);',
        '        method.setAccessible(true);',
        '        return Boolean.TRUE.equals(method.invoke(null, target, Float.valueOf(damage)));',
        '    }',
        '',
        '    private static int invokeIntString(String methodName, String argument) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod(methodName, String.class);',
        '        method.setAccessible(true);',
        '        return ((Number) method.invoke(null, argument)).intValue();',
        '    }',
        '',
        '    private static String invokeStateSelection(boolean ranged, String weaponType) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("selectRagdollState", Boolean.TYPE, String.class);',
        '        method.setAccessible(true);',
        '        return String.valueOf(method.invoke(null, Boolean.valueOf(ranged), weaponType));',
        '    }',
        '',
        '    private static float invokeImpulseMagnitude(boolean ranged, String weaponType, float weaponDamage) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("calculateImpulseMagnitude", Boolean.TYPE, String.class, Float.TYPE);',
        '        method.setAccessible(true);',
        '        return ((Number) method.invoke(null, Boolean.valueOf(ranged), weaponType, Float.valueOf(weaponDamage))).floatValue();',
        '    }',
        '',
        '    private static float invokeUpwardImpulse(boolean ranged, String weaponType) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("calculateUpwardImpulse", Boolean.TYPE, String.class);',
        '        method.setAccessible(true);',
        '        return ((Number) method.invoke(null, Boolean.valueOf(ranged), weaponType)).floatValue();',
        '    }',
        '',
        '    private static float invokeLocalizedReactionMagnitude(boolean ranged, String weaponType, float weaponDamage, int bodyPart) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("calculateLocalizedReactionMagnitude", Boolean.TYPE, String.class, Float.TYPE, Integer.TYPE);',
        '        method.setAccessible(true);',
        '        return ((Number) method.invoke(null, Boolean.valueOf(ranged), weaponType, Float.valueOf(weaponDamage), Integer.valueOf(bodyPart))).floatValue();',
        '    }',
        '',
        '    private static float invokeMovementImpulse(float movementSpeed) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("calculateMovementImpulse", Float.TYPE);',
        '        method.setAccessible(true);',
        '        return ((Number) method.invoke(null, Float.valueOf(movementSpeed))).floatValue();',
        '    }',
        '',
        '    private static boolean invokeForwardFallSelection(boolean ranged, float movementSpeed, float movementX, float movementY, float hitX, float hitY) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("shouldForceFallOnFront", Boolean.TYPE, Float.TYPE, Float.TYPE, Float.TYPE, Float.TYPE, Float.TYPE);',
        '        method.setAccessible(true);',
        '        return Boolean.TRUE.equals(method.invoke(null, Boolean.valueOf(ranged), Float.valueOf(movementSpeed), Float.valueOf(movementX), Float.valueOf(movementY), Float.valueOf(hitX), Float.valueOf(hitY)));',
        '    }',
        '',
        '    private static boolean invokeForceRagdollDeath(Object target, boolean ranged, float movementSpeed, float movementX, float movementY, float hitX, float hitY) throws Exception {',
        '        Class<?> pendingClass = Class.forName("pzmod.mpragdollprototype.PrototypeRuntime$PendingHitConsequences");',
        '        java.lang.reflect.Constructor<?> constructor = pendingClass.getDeclaredConstructor(Integer.TYPE, Object.class, Object.class, Boolean.TYPE, Boolean.TYPE, String.class, String.class, String.class, String.class, Float.TYPE, Float.TYPE, Float.TYPE, Float.TYPE, Float.TYPE, String.class);',
        '        constructor.setAccessible(true);',
        '        Object pending = constructor.newInstance(Integer.valueOf(500), target, null, Boolean.TRUE, Boolean.valueOf(ranged), "none", "Base.Test", "test", "ShotHeadFwd", Float.valueOf(hitX), Float.valueOf(hitY), Float.valueOf(movementX), Float.valueOf(movementY), Float.valueOf(movementSpeed), "test");',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("forceRagdollDeath", Object.class, pendingClass);',
        '        method.setAccessible(true);',
        '        return Boolean.TRUE.equals(method.invoke(null, target, pending));',
        '    }',
        '',
        '    private static float invokeMovementSnapshotFloat(Object target, String fieldName) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("captureMovementSnapshot", Object.class);',
        '        method.setAccessible(true);',
        '        Object snapshot = method.invoke(null, target);',
        '        java.lang.reflect.Field field = snapshot.getClass().getDeclaredField(fieldName);',
        '        field.setAccessible(true);',
        '        return ((Number) field.get(snapshot)).floatValue();',
        '    }',
        '',
        '    private static String invokeMovementSnapshotString(Object target, String fieldName) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("captureMovementSnapshot", Object.class);',
        '        method.setAccessible(true);',
        '        Object snapshot = method.invoke(null, target);',
        '        java.lang.reflect.Field field = snapshot.getClass().getDeclaredField(fieldName);',
        '        field.setAccessible(true);',
        '        return String.valueOf(field.get(snapshot));',
        '    }',
        '',
        '    private static void invokeMovementSample(Object target, long nowNanos) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("sampleZombieMovement", Object.class, Long.TYPE);',
        '        method.setAccessible(true);',
        '        method.invoke(null, target, Long.valueOf(nowNanos));',
        '    }',
        '',
        '    private static float invokeMovementSnapshotFloatAt(Object target, String fieldName, long nowNanos) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("captureMovementSnapshot", Object.class, Long.TYPE);',
        '        method.setAccessible(true);',
        '        Object snapshot = method.invoke(null, target, Long.valueOf(nowNanos));',
        '        java.lang.reflect.Field field = snapshot.getClass().getDeclaredField(fieldName);',
        '        field.setAccessible(true);',
        '        return ((Number) field.get(snapshot)).floatValue();',
        '    }',
        '',
        '    private static String invokeMovementSnapshotStringAt(Object target, String fieldName, long nowNanos) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("captureMovementSnapshot", Object.class, Long.TYPE);',
        '        method.setAccessible(true);',
        '        Object snapshot = method.invoke(null, target, Long.valueOf(nowNanos));',
        '        java.lang.reflect.Field field = snapshot.getClass().getDeclaredField(fieldName);',
        '        field.setAccessible(true);',
        '        return String.valueOf(field.get(snapshot));',
        '    }',
        '',
        '    private static void invokeArm(Object target, int hitId) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("arm", Object.class, Integer.TYPE);',
        '        method.setAccessible(true);',
        '        method.invoke(null, target, Integer.valueOf(hitId));',
        '    }',
        '',
        '    private static void invokeArm(Object target, int hitId, boolean ranged) throws Exception {',
        '        Method method = PrototypeRuntime.class.getDeclaredMethod("arm", Object.class, Integer.TYPE, Boolean.TYPE);',
        '        method.setAccessible(true);',
        '        method.invoke(null, target, Integer.valueOf(hitId), Boolean.valueOf(ranged));',
        '    }',
        '',
        '    private static void seedRagdollTemplates() throws Exception {',
        '        float[] vanillaBodyInfo = new float[11 * 10];',
        '        float[] vanillaMasses = new float[] {0.1481f, 0.3111f, 0.0823f, 0.11125f, 0.0643f, 0.11125f, 0.0643f, 0.03075f, 0.02295f, 0.03075f, 0.02295f};',
        '        float[] restrainedMasses = new float[] {0.1481f, 0.3111f, 0.0823f, 0.11125f, 0.0643f, 0.11125f, 0.0643f, 0.040f, 0.035f, 0.040f, 0.035f};',
        '        for (int body = 0; body < 11; body++) {',
        '            vanillaBodyInfo[body * 10] = body;',
        '            vanillaBodyInfo[body * 10 + 2] = 0.080f;',
        '            vanillaBodyInfo[body * 10 + 6] = vanillaMasses[body];',
        '        }',
        '        float[] restrainedBodyInfo = vanillaBodyInfo.clone();',
        '        for (int body = 0; body < 11; body++) {',
        '            restrainedBodyInfo[body * 10 + 6] = restrainedMasses[body];',
        '            if (body >= 7) restrainedBodyInfo[body * 10 + 2] *= 0.85f;',
        '        }',
        '        setRuntimeArray("vanillaBodyPartInfoTemplate", vanillaBodyInfo);',
        '        setRuntimeArray("restrainedBodyPartInfoTemplate", restrainedBodyInfo);',
        '    }',
        '',
        '    private static void setRuntimeArray(String fieldName, float[] value) throws Exception {',
        '        Field field = PrototypeRuntime.class.getDeclaredField(fieldName);',
        '        field.setAccessible(true);',
        '        field.set(null, value);',
        '    }',
        '',
        '    private static void captureRigidFrame(RagdollController controller, float[] frame) {',
        '        PrototypeRuntime.prepareRagdollFrame(controller, 0.02f);',
        '        PrototypeRuntime.captureRagdollFrame(controller, frame);',
        '    }',
        '',
        '    private static int statusMetric(String name) {',
        '        String prefix = name + "=";',
        '        for (String token : PrototypeRuntime.status().split("; ")) {',
        '            if (token.startsWith(prefix)) {',
        '                return Integer.parseInt(token.substring(prefix.length()));',
        '            }',
        '        }',
        '        throw new AssertionError("missing status metric: " + name);',
        '    }',
        '',
        '    private static void assertTrue(boolean value, String message) {',
        '        if (!value) {',
        '            throw new AssertionError(message);',
        '        }',
        '    }',
        '',
        '    private static void assertFalse(boolean value, String message) {',
        '        assertTrue(!value, message);',
        '    }',
        '',
        '    private static void assertNear(float expected, float actual, float tolerance, String message) {',
        '        assertTrue(Math.abs(expected - actual) <= tolerance, message + ": expected=" + expected + " actual=" + actual);',
        '    }',
        '',
        '    public static final class FakeWeapon {',
        '        private final boolean melee;',
        '        private final boolean ranged;',
        '        private final boolean explosive;',
        '',
        '        FakeWeapon(boolean melee, boolean ranged, boolean explosive) {',
        '            this.melee = melee;',
        '            this.ranged = ranged;',
        '            this.explosive = explosive;',
        '        }',
        '',
        '        public boolean isMelee() { return melee; }',
        '        public boolean isRanged() { return ranged; }',
        '        public boolean isExplosive() { return explosive; }',
        '    }',
        '}'
    ) -join [Environment]::NewLine
    $zombieStubSource = @(
        'package zombie.characters;',
        '',
        'import zombie.characters.action.ActionContext;',
        'import zombie.characters.action.ActionGroup;',
        'import zombie.core.skinnedmodel.advancedanimation.AdvancedAnimator;',
        'import zombie.core.skinnedmodel.animation.AnimationPlayer;',
        '',
        'public final class IsoZombie {',
        '    private final ActionContext actionContext = new ActionContext(new ActionGroup());',
        '    public final AnimationPlayer animationPlayer = new AnimationPlayer();',
        '    private final AdvancedAnimator advancedAnimator = new AdvancedAnimator(animationPlayer);',
        '    public boolean dead;',
        '    public boolean onFloor;',
        '    public boolean knockedDown;',
        '    public boolean crawling;',
        '    public boolean prone;',
        '    public boolean gettingUp;',
        '    public boolean sitOnGround;',
        '    public boolean hitFromBehind;',
        '    public boolean fallOnFront;',
        '    public float health = 1.0f;',
        '    public boolean usePhysicHitReaction;',
        '    public boolean ragdollFall;',
        '    public boolean staggerBack;',
        '    public String hitReaction;',
        '    public String playerAttackPosition;',
        '    public float hitForce;',
        '    public String reportedEvent;',
        '    public float x;',
        '    public float y;',
        '    public float lastX;',
        '    public float lastY;',
        '    public float forwardDirectionX = 1.0f;',
        '    public float forwardDirectionY;',
        '',
        '    public ActionContext getActionContext() { return actionContext; }',
        '    public AdvancedAnimator getAdvancedAnimator() { return advancedAnimator; }',
        '    public AnimationPlayer getAnimationPlayer() { return animationPlayer; }',
        '    public String getActionStateName() { return actionContext.getCurrentStateName(); }',
        '    public String getAnimationStateName() { return advancedAnimator.getCurrentStateName(); }',
        '    public Object getRagdollController() { return animationPlayer.getRagdollController(); }',
        '    public Object getCurrentState() { return actionContext.getCurrentState(); }',
        '    public boolean hasAnimationPlayer() { return true; }',
        '    public boolean isDead() { return dead; }',
        '    public boolean isOnFloor() { return onFloor; }',
        '    public boolean isKnockedDown() { return knockedDown; }',
        '    public boolean isCrawling() { return crawling; }',
        '    public boolean isProne() { return prone || onFloor || crawling; }',
        '    public boolean isGettingUp() { return gettingUp; }',
        '    public boolean isSitOnGround() { return sitOnGround; }',
        '    public boolean isHitFromBehind() { return hitFromBehind; }',
        '    public boolean isFallOnFront() { return fallOnFront; }',
        '    public boolean isStaggerBack() { return staggerBack; }',
        '    public float getHealth() { return health; }',
        '    public float getX() { return x; }',
        '    public float getY() { return y; }',
        '    public float getLastX() { return lastX; }',
        '    public float getLastY() { return lastY; }',
        '    public float getForwardDirectionX() { return forwardDirectionX; }',
        '    public float getForwardDirectionY() { return forwardDirectionY; }',
        '    public float getMovementSpeed() {',
        '        float deltaX = x - lastX;',
        '        float deltaY = y - lastY;',
        '        return (float) Math.sqrt(deltaX * deltaX + deltaY * deltaY);',
        '    }',
        '    public void setUsePhysicHitReaction(boolean value) { usePhysicHitReaction = value; }',
        '    public void setRagdollFall(boolean value) { ragdollFall = value; }',
        '    public void setFallOnFront(boolean value) { fallOnFront = value; }',
        '    public void setOnFloor(boolean value) { onFloor = value; }',
        '    public void setKnockedDown(boolean value) { knockedDown = value; }',
        '    public void setStaggerBack(boolean value) { staggerBack = value; }',
        '    public void setHitReaction(String value) { hitReaction = value; }',
        '    public void setPlayerAttackPosition(String value) { playerAttackPosition = value; }',
        '    public void setHitForce(float value) { hitForce = value; }',
        '    public void reportEvent(String value) { reportedEvent = value; }',
        '}'
    ) -join [Environment]::NewLine
    $gameTimeStubSource = @(
        'package zombie;',
        '',
        'public final class GameTime {',
        '    private static final GameTime instance = new GameTime();',
        '    public float frameSeconds = 1.0f / 60.0f;',
        '',
        '    private GameTime() {}',
        '    public static GameTime getInstance() { return instance; }',
        '    public float getRealworldSecondsSinceLastUpdate() { return frameSeconds; }',
        '}'
    ) -join [Environment]::NewLine
    $networkCharacterAIStubSource = @(
        'package zombie.characters;',
        '',
        'public final class NetworkCharacterAI {',
        '    public final Object character;',
        '',
        '    public NetworkCharacterAI(Object character) {',
        '        this.character = character;',
        '    }',
        '}'
    ) -join [Environment]::NewLine
    $actionStateStubSource = @(
        'package zombie.characters.action;',
        '',
        'public final class ActionState {',
        '    private final String name;',
        '',
        '    public ActionState(String name) { this.name = name; }',
        '    public String getName() { return name; }',
        '    public String toString() { return name; }',
        '}'
    ) -join [Environment]::NewLine
    $actionGroupStubSource = @(
        'package zombie.characters.action;',
        '',
        'public final class ActionGroup {',
        '    private final ActionState walkToward = new ActionState("walktoward");',
        '    private final ActionState ragdoll = new ActionState("staggerback-knockeddown-ragdoll");',
        '',
        '    public ActionState findState(String name) {',
        '        if (ragdoll.getName().equalsIgnoreCase(name)) { return ragdoll; }',
        '        if (walkToward.getName().equalsIgnoreCase(name)) { return walkToward; }',
        '        return null;',
        '    }',
        '}'
    ) -join [Environment]::NewLine
    $actionContextStubSource = @(
        'package zombie.characters.action;',
        '',
        'public final class ActionContext {',
        '    private final ActionGroup group;',
        '    private ActionState currentState;',
        '',
        '    public ActionContext(ActionGroup group) {',
        '        this.group = group;',
        '        this.currentState = group.findState("walktoward");',
        '    }',
        '    public ActionGroup getGroup() { return group; }',
        '    public void setCurrentState(ActionState state) { currentState = state; }',
        '    public ActionState getCurrentState() { return currentState; }',
        '    public String getCurrentStateName() { return currentState == null ? "" : currentState.getName(); }',
        '}'
    ) -join [Environment]::NewLine
    $animationMultiTrackStubSource = @(
        'package zombie.core.skinnedmodel.animation;',
        '',
        'public final class AnimationMultiTrack {',
        '    private boolean ragdollTrack;',
        '',
        '    public boolean containsAnyRagdollTracks() { return ragdollTrack; }',
        '    public void setContainsRagdollTrack(boolean value) { ragdollTrack = value; }',
        '}'
    ) -join [Environment]::NewLine
    $animationPlayerStubSource = @(
        'package zombie.core.skinnedmodel.animation;',
        '',
        'public final class AnimationPlayer {',
        '    private final AnimationMultiTrack multiTrack = new AnimationMultiTrack();',
        '    private boolean ragdollSimulationActive;',
        '    private Object ragdollController;',
        '',
        '    public AnimationMultiTrack getMultiTrack() { return multiTrack; }',
        '    public boolean isRagdollSimulationActive() { return ragdollSimulationActive; }',
        '    public void setRagdollSimulationActive(boolean value) {',
        '        ragdollSimulationActive = value;',
        '        ragdollController = value ? new Object() : null;',
        '    }',
        '    public Object getRagdollController() { return ragdollController; }',
        '    public boolean isBoneTransformsNeedFirstFrame() { return false; }',
        '}'
    ) -join [Environment]::NewLine
    $advancedAnimatorStubSource = @(
        'package zombie.core.skinnedmodel.advancedanimation;',
        '',
        'import zombie.core.skinnedmodel.animation.AnimationPlayer;',
        '',
        'public final class AdvancedAnimator {',
        '    private final AnimationPlayer animationPlayer;',
        '    private String currentStateName = "walktoward";',
        '',
        '    public AdvancedAnimator(AnimationPlayer animationPlayer) { this.animationPlayer = animationPlayer; }',
        '    public void setState(String stateName) {',
        '        currentStateName = stateName;',
        '        animationPlayer.getMultiTrack().setContainsRagdollTrack(',
        '                "staggerback-knockeddown-ragdoll".equalsIgnoreCase(stateName));',
        '    }',
        '    public String getCurrentStateName() { return currentStateName; }',
        '}'
    ) -join [Environment]::NewLine
    $bulletStubSource = @(
        'package zombie.core.physics;',
        '',
        'import java.util.Arrays;',
        '',
        'public final class Bullet {',
        '    public static int impulseCalls;',
        '    public static int dynamicsCalls;',
        '    public static int lastBodyPart = -1;',
        '    public static float[] lastImpulse;',
        '    public static int[] callBodyParts = new int[64];',
        '    public static float[][] callImpulses = new float[64][];',
        '    public static float[][] dynamics = new float[11][];',
        '    public static int defineConstraintCalls;',
        '    public static int defineBodyPartInfoCalls;',
        '    public static float[] lastConstraints;',
        '    public static float[] lastBodyPartInfo;',
        '',
        '    private Bullet() {}',
        '    public static void reset() {',
        '        impulseCalls = 0;',
        '        dynamicsCalls = 0;',
        '        defineConstraintCalls = 0;',
        '        defineBodyPartInfoCalls = 0;',
        '        lastConstraints = null;',
        '        lastBodyPartInfo = null;',
        '        lastBodyPart = -1;',
        '        lastImpulse = null;',
        '        Arrays.fill(callBodyParts, -1);',
        '        callImpulses = new float[64][];',
        '        dynamics = new float[11][];',
        '    }',
        '    public static void applyImpulse(int ragdollId, int bodyPart, float[] impulse) {',
        '        callBodyParts[impulseCalls] = bodyPart;',
        '        callImpulses[impulseCalls] = Arrays.copyOf(impulse, impulse.length);',
        '        impulseCalls++;',
        '        lastBodyPart = bodyPart;',
        '        lastImpulse = impulse;',
        '    }',
        '    public static boolean defineRagdollConstraints(float[] parameters, boolean liveUpdate) {',
        '        defineConstraintCalls++;',
        '        lastConstraints = Arrays.copyOf(parameters, parameters.length);',
        '        return true;',
        '    }',
        '    public static boolean defineRagdollBodyPartInfo(float[] parameters, boolean liveUpdate) {',
        '        defineBodyPartInfoCalls++;',
        '        lastBodyPartInfo = Arrays.copyOf(parameters, parameters.length);',
        '        return true;',
        '    }',
        '    public static boolean setRagdollBodyDynamics(int ragdollId, float[] parameters) {',
        '        dynamicsCalls++;',
        '        if (parameters == null || parameters.length != 8) { return false; }',
        '        int bodyPart = (int) parameters[0];',
        '        if (bodyPart < 0 || bodyPart >= dynamics.length) { return false; }',
        '        dynamics[bodyPart] = Arrays.copyOf(parameters, parameters.length);',
        '        return true;',
        '    }',
        '}'
    ) -join [Environment]::NewLine
    $ragdollControllerStubSource = @(
        'package zombie.core.physics;',
        '',
        'import zombie.characters.IsoZombie;',
        '',
        'public final class RagdollController {',
        '    private final IsoZombie character;',
        '    private final int id;',
        '    private static final float[] rigidBodyBuffer = new float[77];',
        '    public boolean firstFrame = true;',
        '',
        '    public RagdollController(IsoZombie character, int id) {',
        '        this.character = character;',
        '        this.id = id;',
        '    }',
        '    public IsoZombie getGameCharacterObject() { return character; }',
        '    public int getID() { return id; }',
        '    public boolean isSimulationActive() { return character.animationPlayer.isRagdollSimulationActive(); }',
        '    public boolean isFirstFrame() { return firstFrame; }',
        '    public boolean isSimulationSleeping() { return false; }',
        '    public boolean isUpright() { return !character.onFloor; }',
        '    public boolean isOnBack() { return false; }',
        '    public void setRigidBodyBuffer(float[] value) {',
        '        System.arraycopy(value, 0, rigidBodyBuffer, 0, Math.min(value.length, rigidBodyBuffer.length));',
        '    }',
        '}'
    ) -join [Environment]::NewLine
    [IO.File]::WriteAllText($probePath, $probeSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($zombieStubPath, $zombieStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($gameTimeStubPath, $gameTimeStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($networkCharacterAIStubPath, $networkCharacterAIStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($actionStateStubPath, $actionStateStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($actionGroupStubPath, $actionGroupStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($actionContextStubPath, $actionContextStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($animationMultiTrackStubPath, $animationMultiTrackStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($animationPlayerStubPath, $animationPlayerStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($advancedAnimatorStubPath, $advancedAnimatorStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($bulletStubPath, $bulletStubSource, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($ragdollControllerStubPath, $ragdollControllerStubSource, [Text.UTF8Encoding]::new($false))

    $stubPaths = @(
        $zombieStubPath,
        $gameTimeStubPath,
        $networkCharacterAIStubPath,
        $actionStateStubPath,
        $actionGroupStubPath,
        $actionContextStubPath,
        $animationMultiTrackStubPath,
        $animationPlayerStubPath,
        $advancedAnimatorStubPath,
        $bulletStubPath,
        $ragdollControllerStubPath
    )
    & $java -jar $compilerJar -17 -proc:none -encoding UTF-8 -classpath $prototypeJar -d $classesDirectory $probePath @stubPaths
    if ($LASTEXITCODE -ne 0) {
        throw "Cross-package visibility compilation failed with exit code $LASTEXITCODE. Advice-called runtime APIs must remain public."
    }

    & $java -cp "$classesDirectory;$prototypeJar;$zombieBuddyJar" zombie.characters.MultiplayerRagdollVisibilityProbe
    if ($LASTEXITCODE -ne 0) {
        throw "Standing lethal-hit regression probe failed with exit code $LASTEXITCODE."
    }

    Write-Output 'Passed cross-package ZombieBuddy advice visibility preflight.'
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
