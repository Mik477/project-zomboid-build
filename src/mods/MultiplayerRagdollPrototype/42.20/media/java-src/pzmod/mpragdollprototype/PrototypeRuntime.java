package pzmod.mpragdollprototype;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Field;
import java.net.URI;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.util.ArrayDeque;
import java.util.HexFormat;
import java.util.IdentityHashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.locks.ReentrantLock;

import me.zed_0xff.zombie_buddy.Accessor;
import me.zed_0xff.zombie_buddy.Utils;

public final class PrototypeRuntime {
    static final int MAX_ACTIVE_RAGDOLLS = 5;

    private static final String EXPECTED_GAME_JAR_SHA256 =
            "bda809fb49004a07dbfc560d059c0ee58d0643ab0f33b53351b13bd62f1d8227";
    private static final int TRACE_LINE_LIMIT = 12000;
    private static final String RAGDOLL_ACTION_STATE = "staggerback-knockeddown-ragdoll";
    private static final String FAST_RAGDOLL_ACTION_STATE = "falldown-ragdoll";
    private static final String KNIFE_RAGDOLL_ACTION_STATE = "falldown-knifedeath-ragdoll";
    private static final String SPEAR_RAGDOLL_ACTION_STATE = "falldown-speardeath1-ragdoll";
    private static final int QUALITY_LEGACY = 0;
    private static final int QUALITY_STABILIZED = 1;
    private static final int QUALITY_ASSISTED = 2;
    private static final int QUALITY_RESTRAINED = 3;
    private static final int PELVIS_BODY_PART = 0;
    private static final int SPINE_BODY_PART = 1;
    private static final int HEAD_BODY_PART = 2;
    private static final float MOVEMENT_VELOCITY_TO_IMPULSE_SCALE = 1.0f;
    private static final float MAX_MOVEMENT_IMPULSE = 3.25f;
    private static final float[] RAGDOLL_BODY_MASSES = {
        0.1481f,
        0.3111f,
        0.0823f,
        0.11125f,
        0.0643f,
        0.11125f,
        0.0643f,
        0.03075f,
        0.02295f,
        0.03075f,
        0.02295f
    };
    private static final float[] RESTRAINED_RAGDOLL_BODY_MASSES = {
        0.1481f,
        0.3111f,
        0.0823f,
        0.11125f,
        0.0643f,
        0.11125f,
        0.0643f,
        0.040f,
        0.035f,
        0.040f,
        0.035f
    };
    private static final float[] FORWARD_FALL_PITCH_MULTIPLIERS = {
        0.95f,
        1.06f,
        1.10f,
        0.84f,
        0.78f,
        0.84f,
        0.78f,
        1.06f,
        1.06f,
        1.06f,
        1.06f
    };
    private static final int[] FOLLOWER_BODY_PARTS = {3, 4, 5, 6};
    private static final float[] FOLLOWER_FRAME_IMPULSE_LIMITS = {
        0.0f, 0.0f, 0.0f, 0.035f, 0.03f, 0.035f, 0.03f, 0.0f, 0.0f, 0.0f, 0.0f
    };
    private static final float[] FOLLOWER_TOTAL_IMPULSE_LIMITS = {
        0.0f, 0.0f, 0.0f, 0.14f, 0.12f, 0.14f, 0.12f, 0.0f, 0.0f, 0.0f, 0.0f
    };
    private static final String TRACE_SESSION_ID =
            Long.toHexString(System.currentTimeMillis())
                    + "-"
                    + Integer.toHexString(System.identityHashCode(PrototypeRuntime.class));
    private static final long ARM_WINDOW_NANOS = 10_000_000_000L;
    private static final long RAGDOLL_START_TIMEOUT_NANOS = 1_500_000_000L;
    private static final long TORSO_ASSIST_DURATION_NANOS = 150_000_000L;
    private static final float TORSO_ASSIST_TOTAL_IMPULSE = 1.2f;
    private static final float FORWARD_FALL_MIN_SPEED = 0.75f;
    private static final float FORWARD_FALL_APPROACH_DOT_LIMIT = -0.60f;
    private static final float TIMING_EPSILON_SECONDS = 0.0001f;
    private static final float MOMENTUM_CORRECTION_START_SECONDS = 0.08f;
    private static final float MOMENTUM_CORRECTION_END_SECONDS = 0.18f;
    private static final float MOMENTUM_TARGET_RATIO = 0.75f;
    private static final float MOMENTUM_CORRECTION_IMPULSE_LIMIT = 0.30f;
    private static final float FOLLOWER_START_SECONDS = 0.0f;
    private static final float FOLLOWER_LEG_START_SECONDS = 0.12f;
    private static final float FOLLOWER_END_SECONDS = 0.28f;
    private static final float FOLLOWER_RELATIVE_SPEED_DEADZONE = 1.25f;
    private static final float FOLLOWER_CORRECTION_GAIN = 0.65f;
    private static final int RAGDOLL_BODY_PART_INFO_STRIDE = 10;
    private static final float RESTRAINED_ARM_RADIUS_SCALE = 0.85f;
    private static final float RESTRAINED_UPPER_ARM_LINEAR_DAMPING = 0.12f;
    private static final float RESTRAINED_LOWER_ARM_LINEAR_DAMPING = 0.18f;
    private static final float RESTRAINED_UPPER_ARM_FRICTION = 0.35f;
    private static final float RESTRAINED_LOWER_ARM_FRICTION = 0.20f;
    private static final float RESTRAINED_ARM_ROLLING_FRICTION = 0.0f;
    private static final long MOVEMENT_SAMPLE_INTERVAL_NANOS = 40_000_000L;
    private static final long MOVEMENT_HISTORY_MAX_AGE_NANOS = 180_000_000L;
    private static final long MOVEMENT_HISTORY_ENTRY_TTL_NANOS = 2_000_000_000L;
    private static final long MOVEMENT_HISTORY_PRUNE_INTERVAL_NANOS = 1_000_000_000L;
    private static final int MOVEMENT_HISTORY_MAX_ENTRIES = 2048;
    private static final float MOVEMENT_HISTORY_MIN_DISTANCE = 0.002f;
    private static final float MAX_CAPTURED_MOVEMENT_SPEED = 2.5f;
    private static final float MOVEMENT_HISTORY_SMOOTHING = 0.5f;
    private static final Object MARKER_LOCK = new Object();
    private static final Object MOVEMENT_HISTORY_LOCK = new Object();
    private static final Object TELEMETRY_LOG_LOCK = new Object();
    private static final Object RIGID_BODY_BUFFER_FIELD_LOCK = new Object();
    private static final ReentrantLock RAGDOLL_TEMPLATE_LOCK = new ReentrantLock();
    private static final ThreadLocal<TemplateSwap> RAGDOLL_TEMPLATE_SWAP = new ThreadLocal<>();
    private static final IdentityHashMap<Object, ArmedZombie> ARMED_ZOMBIES =
            new IdentityHashMap<>();
    private static final IdentityHashMap<Object, MovementHistory> MOVEMENT_HISTORY =
            new IdentityHashMap<>();
    private static long lastMovementHistoryPruneNanos;
    private static final ThreadLocal<ArrayDeque<PendingHitConsequences>> HIT_CONSEQUENCES =
            ThreadLocal.withInitial(ArrayDeque::new);
    private static final ThreadLocal<ArrayDeque<DeathPacketContext>> DEATH_PACKETS =
            ThreadLocal.withInitial(ArrayDeque::new);

    private static final AtomicInteger ARMED_COUNT = new AtomicInteger();
    private static final AtomicInteger GATE_GRANT_COUNT = new AtomicInteger();
    private static final AtomicInteger POSE_GRANT_COUNT = new AtomicInteger();
    private static final AtomicInteger DEATH_PACKET_COUNT = new AtomicInteger();
    private static final AtomicInteger ACTIVE_AT_DEATH_COUNT = new AtomicInteger();
    private static final AtomicInteger MELEE_DEATH_COUNT = new AtomicInteger();
    private static final AtomicInteger FIREARM_DEATH_COUNT = new AtomicInteger();
    private static final AtomicInteger TRANSITION_FAILURE_COUNT = new AtomicInteger();
    private static final AtomicInteger FORCED_ACTION_STATE_COUNT = new AtomicInteger();
    private static final AtomicInteger RAGDOLL_START_COUNT = new AtomicInteger();
    private static final AtomicInteger STARTUP_DEFERRAL_COUNT = new AtomicInteger();
    private static final AtomicInteger STARTUP_TIMEOUT_COUNT = new AtomicInteger();
    private static final AtomicInteger DEATH_TIMEOUT_DEFERRAL_COUNT = new AtomicInteger();
    private static final AtomicInteger INITIAL_VELOCITY_SUPPRESSION_COUNT = new AtomicInteger();
    private static final AtomicInteger CUSTOM_IMPULSE_COUNT = new AtomicInteger();
    private static final AtomicInteger DYNAMICS_TUNING_COUNT = new AtomicInteger();
    private static final AtomicInteger RESTRAINED_MOMENTUM_COUNT = new AtomicInteger();
    private static final AtomicInteger MOMENTUM_CORRECTION_COUNT = new AtomicInteger();
    private static final AtomicInteger LIMB_FOLLOWER_COUNT = new AtomicInteger();
    private static final AtomicInteger FORWARD_FALL_REQUEST_COUNT = new AtomicInteger();
    private static final AtomicInteger ARM_PROFILE_APPLY_COUNT = new AtomicInteger();
    private static final AtomicInteger ARM_PROFILE_RESTORE_COUNT = new AtomicInteger();
    private static final AtomicInteger ARM_PROFILE_FAILURE_COUNT = new AtomicInteger();
    private static final AtomicInteger LOCALIZED_REACTION_COUNT = new AtomicInteger();
    private static final AtomicInteger TORSO_ASSIST_COUNT = new AtomicInteger();
    private static final AtomicInteger TORSO_ASSIST_TICK_COUNT = new AtomicInteger();
    private static final AtomicInteger HIT_CONTEXT_COUNT = new AtomicInteger();
    private static final AtomicInteger LETHAL_PREPARATION_COUNT = new AtomicInteger();
    private static final AtomicInteger PREPARED_SURVIVAL_COUNT = new AtomicInteger();
    private static final AtomicInteger HIT_SEQUENCE = new AtomicInteger();
    private static final AtomicInteger ZOMBIE_HIT_ENTRY_COUNT = new AtomicInteger();
    private static final AtomicInteger REJECTED_HIT_COUNT = new AtomicInteger();
    private static final AtomicInteger APPLY_DAMAGE_COUNT = new AtomicInteger();
    private static final AtomicInteger UNMATCHED_ZOMBIE_DAMAGE_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_FRAME_CALLBACK_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_VALID_FRAME_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_SNAPSHOT_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_SUMMARY_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_INVALID_FRAME_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_FALLBACK_CAPTURE_COUNT = new AtomicInteger();
    private static final AtomicInteger RIGID_FALLBACK_UNAVAILABLE_COUNT = new AtomicInteger();
    private static final AtomicInteger TRACE_LINE_COUNT = new AtomicInteger();
    private static final AtomicInteger TRACE_DROPPED_COUNT = new AtomicInteger();

    private static BufferedWriter telemetryWriter;
    private static boolean telemetryWriterFailed;
    private static String telemetryWriterFailure = "none";
    private static String telemetryWriterFilename = "none";
    private static int telemetryLinesSinceFlush;
    private static volatile Class<?> rigidBodyBufferOwner;
    private static volatile Field rigidBodyBufferField;
    private static volatile boolean rigidBodyBufferLookupComplete;
    private static volatile String rigidBodyBufferFailure = "not-resolved";
    private static volatile float[] vanillaBodyPartInfoTemplate;
    private static volatile float[] restrainedBodyPartInfoTemplate;

    private static volatile boolean initialized;
    private static volatile boolean buildAccepted;
    private static volatile boolean hasArmedZombies;
    private static volatile int qualityMode = QUALITY_RESTRAINED;
    private static volatile String state = "not initialized";

    private PrototypeRuntime() {}

    public static synchronized void initialize() {
        if (initialized) {
            return;
        }
        initialized = true;

        try {
            Path gameJar = locateGameJar();
            if (gameJar == null || !Files.isRegularFile(gameJar)) {
                disable("disabled: projectzomboid.jar could not be located");
                return;
            }

            String actualHash = sha256(gameJar);
            if (!EXPECTED_GAME_JAR_SHA256.equals(actualHash)) {
                disable("disabled: unsupported projectzomboid.jar SHA-256 " + actualHash);
                return;
            }

            buildAccepted = true;
            initializeTelemetryWriter();
            state = "enabled for Project Zomboid 42.20.3 / Steam build 24775755"
                    + "; restrained lethal melee/firearm ragdolls; cap=" + MAX_ACTIVE_RAGDOLLS;
            log(state);
            log("diagnostic tracing enabled; session=" + TRACE_SESSION_ID
                    + "; lineLimit=" + TRACE_LINE_LIMIT
                    + "; gameClient=" + isGameClient()
                    + "; gameServer=" + isGameServer()
                    + "; zombieBuddyClient=" + Utils.isClient()
                    + "; zombieBuddyServer=" + Utils.isServer());
        } catch (Throwable throwable) {
            disable("disabled: exact-build validation failed: " + throwable.getClass().getSimpleName());
        }
    }

    public static boolean isEnabledClient() {
        initialize();
        return buildAccepted && isGameClient() && !isGameServer();
    }

    public static void enterHitConsequences(
            Object target,
            Object weapon,
            Object wielder,
            boolean ignoreDamage,
            float declaredDamage,
            boolean remote) {
        initialize();
        int hitId = HIT_SEQUENCE.incrementAndGet();
        boolean ranged = callBooleanOrDefault(weapon, "isRanged", false);
        String hitReaction = safeStateName(callNoArgOrNull(target, "getHitReaction"));
        String weaponDescriptor = describeWeapon(weapon);
        float[] hitDirection = calculateHitDirection(target, wielder);
        MovementSnapshot movement = captureMovementSnapshot(target);
        String rejection = getHitEligibilityRejection(target, weapon, ignoreDamage);
        boolean eligible = rejection == null;
        PendingHitConsequences pending = new PendingHitConsequences(
                hitId,
                target,
                weapon,
                eligible,
                ranged,
                rejection == null ? "none" : rejection,
                weaponDescriptor,
                safeClassName(wielder),
                hitReaction,
                hitDirection[0],
                hitDirection[1],
                movement.directionX,
                movement.directionY,
                movement.speed,
                movement.source);
        HIT_CONSEQUENCES.get().push(pending);
        if (isZombie(target)) {
            ZOMBIE_HIT_ENTRY_COUNT.incrementAndGet();
            if (eligible) {
                HIT_CONTEXT_COUNT.incrementAndGet();
            } else {
                REJECTED_HIT_COUNT.incrementAndGet();
            }
            traceHit(
                    pending,
                    "hit-enter",
                    "eligible=" + eligible
                            + " reason=" + pending.eligibilityReason
                            + " weapon=" + pending.weaponType
                            + " hitReaction=" + pending.hitReaction
                            + " hitDirection=" + pending.directionX + ',' + pending.directionY
                            + " movementDirection=" + pending.movementDirectionX + ',' + pending.movementDirectionY
                            + " movementSpeed=" + pending.movementSpeed
                            + " movementSource=" + pending.movementSource
                            + " movementFrameSeconds=" + movement.frameSeconds
                            + " movementFrameDisplacement=" + movement.frameDisplacement
                            + " movementReportedDisplacement=" + movement.reportedDisplacement
                            + " movementHistoryAgeMs=" + movement.historyAgeMillis
                            + " wielder=" + pending.wielderType
                            + " melee=" + formatNullableBoolean(callBooleanOrNull(weapon, "isMelee"))
                            + " ranged=" + formatNullableBoolean(callBooleanOrNull(weapon, "isRanged"))
                            + " explosive=" + formatNullableBoolean(callBooleanOrNull(weapon, "isExplosive"))
                            + " ignoreDamage=" + ignoreDamage
                            + " remote=" + remote
                            + " declaredDamage=" + declaredDamage);
        }
    }

    public static void beforeApplyDamage(Object target, float damage) {
        ArrayDeque<PendingHitConsequences> stack = HIT_CONSEQUENCES.get();
        if (stack.isEmpty()) {
            if (isZombie(target)) {
                UNMATCHED_ZOMBIE_DAMAGE_COUNT.incrementAndGet();
                trace(
                        0,
                        "damage-unmatched",
                        target,
                        "finalDamage=" + damage + " reason=no-hitConsequences-context");
            }
            return;
        }

        PendingHitConsequences pending = stack.peek();
        if (pending.target != target) {
            if (isZombie(target)) {
                UNMATCHED_ZOMBIE_DAMAGE_COUNT.incrementAndGet();
                trace(
                        pending.hitId,
                        "damage-unmatched",
                        target,
                        "finalDamage=" + damage + " reason=context-target-mismatch");
            }
            return;
        }

        APPLY_DAMAGE_COUNT.incrementAndGet();
        boolean lethal = wouldBeKilledByDamage(target, damage);
        traceHit(
                pending,
                "damage-eval",
                "eligible=" + pending.eligible
                        + " reason=" + pending.eligibilityReason
                        + " finalDamage=" + damage
                        + " lethal=" + lethal);
        if (!pending.eligible || pending.lethalPrepared || !lethal) {
            return;
        }

        pending.lethalPrepared = true;
        pending.ragdollState = selectRagdollState(pending);
        pending.impulseBodyPart = selectImpulseBodyPart(pending.hitReaction);
        pending.impulseMagnitude = calculateImpulseMagnitude(pending);
        pending.upwardImpulse = calculateUpwardImpulse(pending);
        pending.reactionBodyPart = selectLocalizedReactionBodyPart(pending.hitReaction);
        pending.reactionImpulse = calculateLocalizedReactionMagnitude(pending);
        pending.movementImpulse = calculateMovementImpulse(pending.movementSpeed);
        arm(target, pending);
        String gateRejection = getRagdollGateRejection(target);
        if (gateRejection != null) {
            traceHit(pending, "gate-rejected", "reason=" + gateRejection);
            pending.lethalPrepared = false;
            clear(target);
            return;
        }

        GATE_GRANT_COUNT.incrementAndGet();
        traceHit(pending, "gate-granted", "source=pre-damage");
        if (!forceRagdollDeath(target, pending)) {
            pending.lethalPrepared = false;
            clear(target);
            return;
        }

        pending.transitionPrepared = true;
        if (LETHAL_PREPARATION_COUNT.incrementAndGet() == 1) {
            log("prepared first lethal ragdoll before health subtraction");
        }
    }

    public static void exitHitConsequences(Object target, Throwable thrown) {
        ArrayDeque<PendingHitConsequences> stack = HIT_CONSEQUENCES.get();
        if (stack.isEmpty()) {
            return;
        }

        PendingHitConsequences pending = stack.pop();
        if (stack.isEmpty()) {
            HIT_CONSEQUENCES.remove();
        }
        if (pending.target != target) {
            return;
        }
        boolean dead = callBooleanOrDefault(target, "isDead", false);
        traceHit(
                pending,
                "hit-exit",
                "dead=" + dead
                        + " transitionPrepared=" + pending.transitionPrepared
                        + " thrown=" + safeClassName(thrown));
        if (!pending.transitionPrepared) {
            return;
        }
        if (thrown != null || !dead) {
            restorePreparedState(target, pending);
            clear(target);
            PREPARED_SURVIVAL_COUNT.incrementAndGet();
            traceHit(pending, "transition-reset", "reason=target-survived-or-threw");
            return;
        }

        if (pending.ranged) {
            FIREARM_DEATH_COUNT.incrementAndGet();
        } else {
            MELEE_DEATH_COUNT.incrementAndGet();
        }
    }

    public static void enterDeathPacket(Object packet) {
        Object character = getDeathPacketCharacter(packet);
        ArmedZombie marker = getArmedMarker(character);
        boolean armed = marker != null;
        boolean active = armed && isAnimationRagdollActive(character);
        int hitId = marker == null ? 0 : marker.hitId;
        DEATH_PACKETS.get().push(new DeathPacketContext(packet, character, armed, hitId));
        if (armed) {
            DEATH_PACKET_COUNT.incrementAndGet();
            if (active) {
                ACTIVE_AT_DEATH_COUNT.incrementAndGet();
            }
        }
        if (isZombie(character)) {
            trace(
                    hitId,
                    armed ? "death-packet-armed" : "death-packet-unarmed",
                    character,
                    "ragdollActive=" + active);
        }
    }

    public static void exitDeathPacket(Object packet) {
        ArrayDeque<DeathPacketContext> stack = DEATH_PACKETS.get();
        if (stack.isEmpty()) {
            return;
        }

        DeathPacketContext context = stack.pop();
        if (stack.isEmpty()) {
            DEATH_PACKETS.remove();
        }
        if (context.packet == packet && context.armed) {
            trace(
                    context.hitId,
                    "death-packet-exit",
                    context.character,
                    "clearingMarker=true");
            clear(context.character, "death-packet-exit");
        }
    }

    public static boolean canRagdoll(Object character) {
        String rejection = getRagdollGateRejection(character);
        ArmedZombie marker = getArmedMarker(character);
        if (marker != null) {
            traceRagdollStateIfChanged(
                    character,
                    marker,
                    rejection == null ? "gate-query-granted" : "gate-query-rejected",
                    "reason=" + (rejection == null ? "none" : rejection));
        }
        if (rejection != null) {
            return false;
        }
        GATE_GRANT_COUNT.incrementAndGet();
        return true;
    }

    public static boolean shouldDeferFallDownExecution(Object character) {
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null || !callBooleanOrDefault(character, "isDead", false)) {
            return false;
        }

        RagdollStateSnapshot snapshot = observeRagdollState(character, marker);
        traceRagdollStateIfChanged(character, marker, "fall-state", "source=execute");
        if (snapshot.simulationActive || marker.simulationObserved) {
            return false;
        }
        if (System.nanoTime() >= marker.startDeadlineNanos) {
            if (!marker.startupTimeoutLogged) {
                marker.startupTimeoutLogged = true;
                STARTUP_TIMEOUT_COUNT.incrementAndGet();
                trace(marker.hitId, "ragdoll-start-timeout", character, "fallback=vanilla-death");
            }
            return false;
        }
        if (!marker.startupDeferralLogged) {
            marker.startupDeferralLogged = true;
            STARTUP_DEFERRAL_COUNT.incrementAndGet();
            trace(marker.hitId, "fall-state-deferred", character, "waitingFor=ragdoll-simulation");
        }
        return true;
    }

    public static boolean shouldDeferDeadBodyTimeout(Object networkCharacterAI) {
        Object character = Accessor.tryGet(networkCharacterAI, "character", null);
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null) {
            return false;
        }

        RagdollStateSnapshot snapshot = observeRagdollState(character, marker);
        boolean defer = snapshot.simulationActive
                || (!marker.simulationObserved && System.nanoTime() < marker.startDeadlineNanos);
        if (defer && !marker.deathTimeoutDeferralLogged) {
            marker.deathTimeoutDeferralLogged = true;
            DEATH_TIMEOUT_DEFERRAL_COUNT.incrementAndGet();
            trace(marker.hitId, "death-timeout-deferred", character, "source=network-ai");
        }
        return defer;
    }

    public static boolean replaceHitReaction(Object ragdollController) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null || qualityMode == QUALITY_LEGACY || marker.initialImpulseApplied) {
            return false;
        }

        int ragdollId = readInt(callNoArgOrNull(ragdollController, "getID"), -1);
        if (ragdollId < 0) {
            return false;
        }
        if (qualityMode == QUALITY_RESTRAINED) {
            if (!marker.preSimulationMovementApplied) {
                boolean movementApplied = marker.movementImpulse <= 0.0f
                        || applyMassWeightedMovementImpulse(
                                ragdollId,
                                marker.movementDirectionX,
                                marker.movementDirectionY,
                                marker.movementImpulse,
                                marker.bodyMasses);
                if (!movementApplied) {
                    trace(
                            marker.hitId,
                            "custom-impulse-failed",
                            character,
                            "ragdollId=" + ragdollId + " phase=pre-simulation-momentum");
                    return false;
                }
                marker.preSimulationMovementApplied = true;
                if (marker.movementImpulse > 0.0f) {
                    RESTRAINED_MOMENTUM_COUNT.incrementAndGet();
                    trace(
                            marker.hitId,
                            "coherent-momentum-applied",
                            character,
                            "ragdollId=" + ragdollId
                                    + " phase=pre-simulation"
                                    + " movementDirection=" + marker.movementDirectionX + ','
                                    + marker.movementDirectionY
                                    + " movementSpeed=" + marker.movementSpeed
                                    + " movementImpulse=" + marker.movementImpulse
                                    + " movementParts=" + RAGDOLL_BODY_MASSES.length);
                }
            }
            if (!marker.initialImpulseQueued) {
                marker.initialImpulseQueued = true;
                trace(
                        marker.hitId,
                        "custom-impulse-queued",
                        character,
                        "ragdollId=" + ragdollId
                                + " waitingFor=first-measured-rigid-frame-pitch-and-reaction"
                                + " movementSpeed=" + marker.movementSpeed
                                + " movementSource=" + marker.movementSource);
            }
            callOneArgQuietly(character, "setHitReaction", String.class, "");
            return true;
        }

        boolean applied = applyDirectedImpulse(
                ragdollId,
                marker.impulseBodyPart,
                marker.directionX,
                marker.directionY,
                marker.impulseMagnitude,
                marker.upwardImpulse);
        if (!applied) {
            trace(marker.hitId, "custom-impulse-failed", character, "ragdollId=" + ragdollId);
            return false;
        }

        marker.initialImpulseApplied = true;
        marker.assistDeadlineNanos = System.nanoTime() + TORSO_ASSIST_DURATION_NANOS;
        CUSTOM_IMPULSE_COUNT.incrementAndGet();
        traceCustomImpulseApplied(marker, character, ragdollId, "simulate-hit-reaction");
        callOneArgQuietly(character, "setHitReaction", String.class, "");
        return true;
    }

    private static void traceCustomImpulseApplied(
            ArmedZombie marker,
            Object character,
            int ragdollId,
            String phase) {
        trace(
                marker.hitId,
                "custom-impulse-applied",
                character,
                "ragdollId=" + ragdollId
                        + " phase=" + phase
                        + " initialValidFrame=" + marker.initialImpulseValidFrame
                        + " preSimulationMovement=" + marker.preSimulationMovementApplied
                        + " mode=" + qualityModeName()
                        + " ranged=" + marker.ranged
                        + " bodyPart=" + marker.impulseBodyPart
                        + " direction=" + marker.directionX + ',' + marker.directionY
                        + " impulse=" + marker.impulseMagnitude
                        + " upward=" + marker.upwardImpulse
                        + " movementDirection=" + marker.movementDirectionX + ',' + marker.movementDirectionY
                        + " movementSpeed=" + marker.movementSpeed
                        + " movementImpulse=" + marker.movementImpulse
                        + " movementProfile=" + (marker.ranged
                                ? "coherent-prestep+gentle-forward-pitch"
                                : "coherent-prestep")
                        + " movementSource=" + marker.movementSource
                        + " movementParts=" + (marker.restrainedArmProfile && marker.movementImpulse > 0.0f
                                ? marker.bodyMasses.length
                                : 0)
                        + " reactionBodyPart=" + marker.reactionBodyPart
                        + " reactionImpulse=" + marker.reactionImpulse
                        + " reactionVelocityDelta=" + calculateReactionVelocityDelta(
                                marker.bodyMasses,
                                marker.reactionBodyPart,
                                marker.reactionImpulse));
    }

    public static boolean shouldSuppressInitialVelocities(Object ragdollController) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null || qualityMode == QUALITY_LEGACY) {
            return false;
        }

        if (!marker.initialVelocitiesSuppressedLogged) {
            marker.initialVelocitiesSuppressedLogged = true;
            INITIAL_VELOCITY_SUPPRESSION_COUNT.incrementAndGet();
            int ragdollId = readInt(callNoArgOrNull(ragdollController, "getID"), -1);
            trace(
                    marker.hitId,
                    "initial-velocities-suppressed",
                    character,
                    "ragdollId=" + ragdollId);
        }
        return true;
    }

    public static void beforeAddRagdollToWorld(Object ragdollController) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null || !marker.restrainedArmProfile) {
            return;
        }
        if (RAGDOLL_TEMPLATE_SWAP.get() != null) {
            ARM_PROFILE_FAILURE_COUNT.incrementAndGet();
            trace(marker.hitId, "arm-profile-failed", character, "stage=reentrant-add-to-world");
            return;
        }

        RAGDOLL_TEMPLATE_LOCK.lock();
        boolean applied = false;
        try {
            ensureRagdollTemplates();
            if (!defineRagdollBodyPartInfo(restrainedBodyPartInfoTemplate)) {
                throw new ReflectiveOperationException("native template update rejected");
            }
            RAGDOLL_TEMPLATE_SWAP.set(new TemplateSwap(ragdollController, character, marker));
            ARM_PROFILE_APPLY_COUNT.incrementAndGet();
            applied = true;
            trace(
                    marker.hitId,
                    "arm-profile-applied",
                    character,
                    "upperArmMass=" + RESTRAINED_RAGDOLL_BODY_MASSES[7]
                            + " lowerArmMass=" + RESTRAINED_RAGDOLL_BODY_MASSES[8]
                            + " armRadiusScale=" + RESTRAINED_ARM_RADIUS_SCALE
                            + " constraints=vanilla");
        } catch (ReflectiveOperationException | RuntimeException exception) {
            ARM_PROFILE_FAILURE_COUNT.incrementAndGet();
            restoreRagdollBodyPartInfoQuietly();
            trace(
                    marker.hitId,
                    "arm-profile-failed",
                    character,
                    "stage=apply error=" + exception.getClass().getSimpleName());
        } finally {
            if (!applied) {
                RAGDOLL_TEMPLATE_LOCK.unlock();
            }
        }
    }

    public static void afterAddRagdollToWorld(Object ragdollController, Throwable thrown) {
        TemplateSwap swap = RAGDOLL_TEMPLATE_SWAP.get();
        if (swap == null) {
            return;
        }
        try {
            boolean controllerMatched = swap.ragdollController == ragdollController;
            boolean restored = restoreRagdollBodyPartInfoQuietly();
            if (controllerMatched && restored) {
                ARM_PROFILE_RESTORE_COUNT.incrementAndGet();
                trace(
                        swap.marker.hitId,
                        "arm-profile-restored",
                        swap.character,
                        "addThrew=" + (thrown != null));
            } else {
                ARM_PROFILE_FAILURE_COUNT.incrementAndGet();
                trace(
                        swap.marker.hitId,
                        "arm-profile-failed",
                        swap.character,
                        "stage=restore controllerMatched=" + controllerMatched
                                + " restored=" + restored
                                + " addThrew=" + (thrown != null));
            }
        } finally {
            RAGDOLL_TEMPLATE_SWAP.remove();
            RAGDOLL_TEMPLATE_LOCK.unlock();
        }
    }

    public static void prepareRagdollFrame(Object ragdollController, float deltaT) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker != null) {
            marker.rigidUpdateSequence++;
            if (isFinite(deltaT) && deltaT > 0.0f) {
                marker.pendingRigidFrameDeltaT = deltaT;
            }
        }
    }

    public static void captureRagdollFrame(Object ragdollController, float[] rigidBodyBuffer) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null) {
            return;
        }

        captureRagdollFrame(ragdollController, rigidBodyBuffer, character, marker);
    }

    public static void finishRagdollFrame(Object ragdollController) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker != null) {
            capturePendingRagdollFrame(ragdollController, character, marker, "update-exit");
        }
    }

    private static void captureRagdollFrame(
            Object ragdollController,
            float[] rigidBodyBuffer,
            Object character,
            ArmedZombie marker) {
        int updateSequence = marker.rigidUpdateSequence;
        if (updateSequence > 0 && marker.rigidCapturedUpdateSequence == updateSequence) {
            return;
        }
        if (updateSequence > 0) {
            marker.rigidCapturedUpdateSequence = updateSequence;
        }

        boolean sleeping = callBooleanOrDefault(ragdollController, "isSimulationSleeping", false);
        boolean onFloor = callBooleanOrDefault(character, "isOnFloor", false);
        boolean upright = callBooleanOrDefault(ragdollController, "isUpright", true);
        boolean onBack = callBooleanOrDefault(ragdollController, "isOnBack", false);
        marker.rigidTelemetry.observeState(sleeping, onFloor, upright, onBack);
        boolean firstFrame = callBooleanOrDefault(ragdollController, "isFirstFrame", true);
        int captureResult = marker.rigidTelemetry.capture(
                rigidBodyBuffer,
                marker.pendingRigidFrameDeltaT,
                System.nanoTime(),
                firstFrame);
        RIGID_FRAME_CALLBACK_COUNT.incrementAndGet();
        if (captureResult == RigidBodyTelemetry.CAPTURE_DEFERRED_FIRST_FRAME) {
            if (!marker.rigidFirstFrameDeferralLogged) {
                marker.rigidFirstFrameDeferralLogged = true;
                trace(
                        marker.hitId,
                        "rigid-frame-deferred",
                        character,
                        "reason=controller-first-frame callbacks="
                                + marker.rigidTelemetry.getCallbackCount());
            }
            return;
        }
        if (captureResult == RigidBodyTelemetry.CAPTURE_INVALID_LENGTH
                || captureResult == RigidBodyTelemetry.CAPTURE_INVALID_VALUES) {
            RIGID_INVALID_FRAME_COUNT.incrementAndGet();
            if (marker.rigidInvalidFrameLogs < 3) {
                marker.rigidInvalidFrameLogs++;
                trace(
                        marker.hitId,
                        "rigid-frame-invalid",
                        character,
                        "reason=" + (captureResult == RigidBodyTelemetry.CAPTURE_INVALID_LENGTH
                                ? "buffer-length"
                                : "non-finite-or-invalid-quaternion")
                                + " bufferLength=" + (rigidBodyBuffer == null ? -1 : rigidBodyBuffer.length)
                                + " invalidCount=" + marker.rigidTelemetry.getInvalidFrameCount());
            }
            return;
        }

        RIGID_VALID_FRAME_COUNT.incrementAndGet();
        marker.rigidTelemetry.observeState(sleeping, onFloor, upright, onBack);
        if (captureResult == RigidBodyTelemetry.CAPTURE_BASELINE) {
            trace(
                    marker.hitId,
                    "rigid-baseline",
                    character,
                    "callbacks=" + marker.rigidTelemetry.getCallbackCount()
                            + " deferredFirstFrames="
                            + marker.rigidTelemetry.getDeferredFirstFrameCount()
                            + " coordinateSpace=pelvis-relative positions=bullet-x-up-y-z");
        }
        int validFrame = marker.rigidTelemetry.getValidFrameCount();
        if (RigidBodyTelemetry.shouldLogSnapshot(validFrame)) {
            trace(
                    marker.hitId,
                    "rigid-frame",
                    character,
                    marker.rigidTelemetry.frameDetails());
            trace(
                    marker.hitId,
                    "rigid-joints",
                    character,
                    marker.rigidTelemetry.jointFrameDetails());
            trace(
                    marker.hitId,
                    "rigid-arm-snapshot",
                    character,
                    marker.rigidTelemetry.armFrameDetails());
            trace(
                    marker.hitId,
                    "rigid-core-snapshot",
                    character,
                    marker.rigidTelemetry.coreFrameDetails());
            RIGID_SNAPSHOT_COUNT.incrementAndGet();
        }
        if (captureResult == RigidBodyTelemetry.CAPTURE_UPDATED) {
            applyQueuedRestrainedInitialization(ragdollController, character, marker);
        }
    }

    private static void applyQueuedRestrainedInitialization(
            Object ragdollController,
            Object character,
            ArmedZombie marker) {
        if (qualityMode != QUALITY_RESTRAINED
                || !marker.initialImpulseQueued
                || marker.initialImpulseApplied) {
            return;
        }

        int ragdollId = readInt(callNoArgOrNull(ragdollController, "getID"), -1);
        if (ragdollId < 0) {
            return;
        }
        boolean pitchApplied = !marker.ranged
                || marker.movementImpulse <= 0.0f
                || applyForwardPitchAdjustment(
                        ragdollId,
                        marker.movementDirectionX,
                        marker.movementDirectionY,
                        marker.movementImpulse,
                        marker.bodyMasses);
        boolean reactionApplied = marker.reactionImpulse <= 0.0f
                || applyDirectedImpulse(
                        ragdollId,
                        marker.reactionBodyPart,
                        marker.directionX,
                        marker.directionY,
                        marker.reactionImpulse,
                        0.0f);
        if (!pitchApplied || !reactionApplied) {
            marker.initialImpulseQueued = false;
            trace(
                    marker.hitId,
                    "custom-impulse-failed",
                    character,
                    "ragdollId=" + ragdollId + " phase=first-measured-rigid-frame");
            return;
        }

        marker.initialImpulseApplied = true;
        marker.initialImpulseValidFrame = marker.rigidTelemetry.getValidFrameCount();
        marker.assistDeadlineNanos = System.nanoTime() + TORSO_ASSIST_DURATION_NANOS;
        if (marker.reactionImpulse > 0.0f) {
            LOCALIZED_REACTION_COUNT.incrementAndGet();
        }
        CUSTOM_IMPULSE_COUNT.incrementAndGet();
        traceCustomImpulseApplied(
                marker,
                character,
                ragdollId,
                "first-measured-rigid-frame");
    }

    public static void updateRagdollController(Object ragdollController, float deltaT) {
        Object character = callNoArgOrNull(ragdollController, "getGameCharacterObject");
        ArmedZombie marker = getArmedMarker(character);
        if (marker == null) {
            return;
        }
        capturePendingRagdollFrame(ragdollController, character, marker, "post-update");
        if (qualityMode == QUALITY_LEGACY) {
            return;
        }
        if (!callBooleanOrDefault(ragdollController, "isSimulationActive", false)) {
            if (marker.assistStarted && !marker.assistFinished) {
                marker.assistFinished = true;
                trace(marker.hitId, "torso-assist-finished", character, "reason=simulation-inactive");
            }
            return;
        }

        int ragdollId = readInt(callNoArgOrNull(ragdollController, "getID"), -1);
        if (ragdollId < 0) {
            return;
        }
        if (!marker.dynamicsApplied) {
            marker.dynamicsApplied = tuneRagdollDynamics(
                    ragdollId,
                    marker.restrainedArmProfile);
            if (marker.dynamicsApplied) {
                DYNAMICS_TUNING_COUNT.incrementAndGet();
                trace(
                        marker.hitId,
                        "dynamics-tuned",
                        character,
                        "ragdollId=" + ragdollId
                                + " torsoLinearDamping=0.05"
                                + " upperArmLinearDamping=" + RESTRAINED_UPPER_ARM_LINEAR_DAMPING
                                + " lowerArmLinearDamping=" + RESTRAINED_LOWER_ARM_LINEAR_DAMPING
                                + " armAngularDamping=0.9997"
                                + " upperArmFriction=" + RESTRAINED_UPPER_ARM_FRICTION
                                + " lowerArmFriction=" + RESTRAINED_LOWER_ARM_FRICTION
                                + " armRollingFriction=" + RESTRAINED_ARM_ROLLING_FRICTION
                                + " legAngularDamping=0.997");
            } else {
                trace(marker.hitId, "dynamics-tuning-failed", character, "ragdollId=" + ragdollId);
            }
        }

        traceMotionSample(marker, ragdollController, character, deltaT);

        boolean sleeping = callBooleanOrDefault(ragdollController, "isSimulationSleeping", false);
        boolean onFloor = callBooleanOrDefault(character, "isOnFloor", false);
        if (qualityMode == QUALITY_RESTRAINED && marker.initialImpulseApplied) {
            applyRestrainedMotionControl(marker, character, ragdollId, sleeping, onFloor);
        }

        if (qualityMode != QUALITY_ASSISTED || !marker.initialImpulseApplied) {
            return;
        }
        if (onFloor) {
            finishAssist(marker, character, "on-floor");
            return;
        }
        long now = System.nanoTime();
        if (marker.assistDeadlineNanos <= 0L || now >= marker.assistDeadlineNanos) {
            finishAssist(marker, character, "deadline");
            return;
        }

        float boundedDeltaT = Math.max(0.0f, Math.min(deltaT, 0.05f));
        if (!(boundedDeltaT > 0.0f)) {
            return;
        }
        float impulse = TORSO_ASSIST_TOTAL_IMPULSE
                * boundedDeltaT
                / (TORSO_ASSIST_DURATION_NANOS / 1_000_000_000.0f);
        boolean pelvisApplied = applyDirectedImpulse(
                ragdollId,
                PELVIS_BODY_PART,
                marker.directionX,
                marker.directionY,
                impulse,
                impulse * 0.03f);
        if (!pelvisApplied) {
            return;
        }
        if (!marker.assistStarted) {
            marker.assistStarted = true;
            TORSO_ASSIST_COUNT.incrementAndGet();
            trace(
                    marker.hitId,
                    "torso-assist-started",
                    character,
                    "durationMs=150 bodyPart=" + PELVIS_BODY_PART);
        }
        TORSO_ASSIST_TICK_COUNT.incrementAndGet();
    }

    private static void applyRestrainedMotionControl(
            ArmedZombie marker,
            Object character,
            int ragdollId,
            boolean sleeping,
            boolean onFloor) {
        if (sleeping || onFloor || marker.rigidTelemetry.getValidFrameCount() <= 0) {
            return;
        }
        if (marker.rigidTelemetry.getValidFrameCount() <= marker.initialImpulseValidFrame) {
            return;
        }

        float elapsedSeconds = marker.rigidTelemetry.getElapsedSeconds();
        if (!marker.momentumCorrectionAttempted
                && elapsedSeconds + TIMING_EPSILON_SECONDS >= MOMENTUM_CORRECTION_START_SECONDS) {
            marker.momentumCorrectionAttempted = true;
            if (elapsedSeconds <= MOMENTUM_CORRECTION_END_SECONDS
                    && marker.movementSpeed > 0.25f) {
                float forwardDisplacement = marker.rigidTelemetry.getCurrentForwardDisplacement();
                float averageForwardVelocity = forwardDisplacement / elapsedSeconds;
                float targetForwardVelocity = marker.movementSpeed * MOMENTUM_TARGET_RATIO;
                float velocityDeficit = targetForwardVelocity - averageForwardVelocity;
                if (isFinite(velocityDeficit) && velocityDeficit + 0.001f >= 0.25f) {
                    float totalImpulse = Math.min(
                            velocityDeficit * 0.25f,
                            MOMENTUM_CORRECTION_IMPULSE_LIMIT);
                    if (applyMassWeightedMovementImpulse(
                            ragdollId,
                            marker.movementDirectionX,
                            marker.movementDirectionY,
                            totalImpulse,
                            marker.bodyMasses)) {
                        MOMENTUM_CORRECTION_COUNT.incrementAndGet();
                        trace(
                                marker.hitId,
                                "momentum-window-correction-applied",
                                character,
                                "elapsed=" + elapsedSeconds
                                        + " forwardDisplacement=" + forwardDisplacement
                                        + " averageForward=" + averageForwardVelocity
                                        + " targetForward=" + targetForwardVelocity
                                        + " impulse=" + totalImpulse);
                    }
                }
            }
        }

        if (elapsedSeconds < FOLLOWER_START_SECONDS || elapsedSeconds > FOLLOWER_END_SECONDS) {
            return;
        }
        for (int bodyPart : FOLLOWER_BODY_PARTS) {
            if (elapsedSeconds + TIMING_EPSILON_SECONDS < FOLLOWER_LEG_START_SECONDS) {
                continue;
            }
            float remainingBudget = FOLLOWER_TOTAL_IMPULSE_LIMITS[bodyPart]
                    - marker.followerImpulseByBody[bodyPart];
            if (!(remainingBudget > 0.0001f)) {
                continue;
            }
            float relativeSpeed = marker.rigidTelemetry.getParentVelocityCorrection(
                    bodyPart,
                    marker.followerCorrection);
            if (!isFinite(relativeSpeed) || relativeSpeed <= FOLLOWER_RELATIVE_SPEED_DEADZONE) {
                continue;
            }
            float excessRatio = (relativeSpeed - FOLLOWER_RELATIVE_SPEED_DEADZONE)
                    / relativeSpeed;
            float impulseScale = marker.bodyMasses[bodyPart]
                    * FOLLOWER_CORRECTION_GAIN
                    * excessRatio;
            float impulseX = marker.followerCorrection[0] * impulseScale;
            float impulseY = marker.followerCorrection[1] * impulseScale;
            float impulseZ = marker.followerCorrection[2] * impulseScale;
            float impulseMagnitude = vectorLength(impulseX, impulseY, impulseZ);
            float frameImpulseLimit = FOLLOWER_FRAME_IMPULSE_LIMITS[bodyPart];
            float impulseLimit = Math.min(frameImpulseLimit, remainingBudget);
            if (impulseMagnitude > impulseLimit) {
                float clampScale = impulseLimit / impulseMagnitude;
                impulseX *= clampScale;
                impulseY *= clampScale;
                impulseZ *= clampScale;
                impulseMagnitude = impulseLimit;
            }
            if (!(impulseMagnitude > 0.0001f)
                    || !applyBodyImpulse(ragdollId, bodyPart, impulseX, impulseY, impulseZ)) {
                continue;
            }
            marker.followerImpulseByBody[bodyPart] += impulseMagnitude;
            LIMB_FOLLOWER_COUNT.incrementAndGet();
            trace(
                    marker.hitId,
                    "limb-follower-correction",
                    character,
                    "elapsed=" + elapsedSeconds
                            + " bodyPart=" + bodyPart
                            + " body=" + RigidBodyTelemetry.bodyName(bodyPart)
                            + " phase=leg-follow"
                            + " relativeSpeed=" + relativeSpeed
                            + " impulse=" + impulseX + ',' + impulseY + ',' + impulseZ
                            + " magnitude=" + impulseMagnitude
                            + " total=" + marker.followerImpulseByBody[bodyPart]);
        }
    }

    private static void finishAssist(ArmedZombie marker, Object character, String reason) {
        if (marker.assistStarted && !marker.assistFinished) {
            marker.assistFinished = true;
            trace(marker.hitId, "torso-assist-finished", character, "reason=" + reason);
        }
    }

    public static String setQualityMode(String mode) {
        String normalized = mode == null ? "" : mode.trim().toLowerCase();
        switch (normalized) {
            case "legacy":
                qualityMode = QUALITY_LEGACY;
                break;
            case "stabilized":
                qualityMode = QUALITY_STABILIZED;
                break;
            case "assisted":
                qualityMode = QUALITY_ASSISTED;
                break;
            case "restrained":
                qualityMode = QUALITY_RESTRAINED;
                break;
            default:
                return "invalid quality mode; expected legacy, stabilized, assisted, or restrained";
        }
        log("quality mode changed to " + qualityModeName());
        return qualityModeName();
    }

    public static boolean canCaptureCorpsePose(Object character) {
        initialize();
        ArmedZombie marker = getArmedMarker(character);
        if (!buildAccepted
                || marker == null
                || !isZombie(character)
                || !isGameClient()
                || isGameServer()) {
            return false;
        }

        try {
            if (callBoolean(character, "isSceneCulled")) {
                trace(marker.hitId, "pose-rejected", character, "reason=scene-culled");
                return false;
            }
            if (!callBoolean(character, "hasActiveModel")) {
                trace(marker.hitId, "pose-rejected", character, "reason=no-active-model");
                return false;
            }
            Object animationPlayer = Accessor.callNoArg(character, "getAnimationPlayer");
            if (animationPlayer == null) {
                trace(marker.hitId, "pose-rejected", character, "reason=no-animation-player");
                return false;
            }
            if (!isAnimationRagdollActive(character)
                    && callBoolean(animationPlayer, "isBoneTransformsNeedFirstFrame")) {
                trace(marker.hitId, "pose-rejected", character, "reason=bone-transforms-not-ready");
                return false;
            }

            POSE_GRANT_COUNT.incrementAndGet();
            trace(marker.hitId, "pose-granted", character, "reason=none");
            return true;
        } catch (ReflectiveOperationException exception) {
            trace(
                    marker.hitId,
                    "pose-rejected",
                    character,
                    "reason=reflection-" + exception.getClass().getSimpleName());
            return false;
        }
    }

    public static String status() {
        initialize();
        int armedNow;
        synchronized (MARKER_LOCK) {
            pruneExpired(System.nanoTime());
            armedNow = ARMED_ZOMBIES.size();
        }
        return state
                + "; qualityMode=" + qualityModeName()
                + "; armed=" + ARMED_COUNT.get()
                + "; pending=" + armedNow
                + "; gateGrants=" + GATE_GRANT_COUNT.get()
                + "; poseCaptures=" + POSE_GRANT_COUNT.get()
                + "; matchedDeathPackets=" + DEATH_PACKET_COUNT.get()
                + "; activeAtDeathPacket=" + ACTIVE_AT_DEATH_COUNT.get()
                + "; meleeDeaths=" + MELEE_DEATH_COUNT.get()
                + "; firearmDeaths=" + FIREARM_DEATH_COUNT.get()
                + "; transitionFailures=" + TRANSITION_FAILURE_COUNT.get()
                + "; forcedActionStates=" + FORCED_ACTION_STATE_COUNT.get()
                + "; ragdollStarts=" + RAGDOLL_START_COUNT.get()
                + "; startupDeferrals=" + STARTUP_DEFERRAL_COUNT.get()
                + "; startupTimeouts=" + STARTUP_TIMEOUT_COUNT.get()
                + "; deathTimeoutDeferrals=" + DEATH_TIMEOUT_DEFERRAL_COUNT.get()
                + "; initialVelocitySuppressions=" + INITIAL_VELOCITY_SUPPRESSION_COUNT.get()
                + "; customImpulses=" + CUSTOM_IMPULSE_COUNT.get()
                + "; dynamicsTunings=" + DYNAMICS_TUNING_COUNT.get()
                + "; restrainedMomentum=" + RESTRAINED_MOMENTUM_COUNT.get()
                + "; momentumCorrections=" + MOMENTUM_CORRECTION_COUNT.get()
                + "; limbFollowerCorrections=" + LIMB_FOLLOWER_COUNT.get()
                + "; forwardFallRequests=" + FORWARD_FALL_REQUEST_COUNT.get()
                + "; armProfileApplies=" + ARM_PROFILE_APPLY_COUNT.get()
                + "; armProfileRestores=" + ARM_PROFILE_RESTORE_COUNT.get()
                + "; armProfileFailures=" + ARM_PROFILE_FAILURE_COUNT.get()
                + "; localizedReactions=" + LOCALIZED_REACTION_COUNT.get()
                + "; torsoAssists=" + TORSO_ASSIST_COUNT.get()
                + "; torsoAssistTicks=" + TORSO_ASSIST_TICK_COUNT.get()
                + "; hitContexts=" + HIT_CONTEXT_COUNT.get()
                + "; lethalPreparations=" + LETHAL_PREPARATION_COUNT.get()
                + "; preparedSurvivals=" + PREPARED_SURVIVAL_COUNT.get()
                + "; zombieHitEntries=" + ZOMBIE_HIT_ENTRY_COUNT.get()
                + "; rejectedHits=" + REJECTED_HIT_COUNT.get()
                + "; applyDamageCalls=" + APPLY_DAMAGE_COUNT.get()
                + "; unmatchedZombieDamage=" + UNMATCHED_ZOMBIE_DAMAGE_COUNT.get()
                + "; rigidCallbacks=" + RIGID_FRAME_CALLBACK_COUNT.get()
                + "; rigidValidFrames=" + RIGID_VALID_FRAME_COUNT.get()
                + "; rigidSnapshots=" + RIGID_SNAPSHOT_COUNT.get()
                + "; rigidSummaries=" + RIGID_SUMMARY_COUNT.get()
                + "; rigidInvalidFrames=" + RIGID_INVALID_FRAME_COUNT.get()
                + "; rigidFallbackCaptures=" + RIGID_FALLBACK_CAPTURE_COUNT.get()
                + "; rigidFallbackUnavailable=" + RIGID_FALLBACK_UNAVAILABLE_COUNT.get()
                + "; dedicatedTelemetry=" + (telemetryWriter != null
                        ? "ready:" + telemetryWriterFilename
                        : telemetryWriterFailed ? "failed:" + telemetryWriterFailure : "not-open")
                + "; traceSession=" + TRACE_SESSION_ID
                + "; traceLines=" + Math.min(TRACE_LINE_COUNT.get(), TRACE_LINE_LIMIT)
                + "; traceDropped=" + TRACE_DROPPED_COUNT.get();
    }

    private static void arm(Object zombie, int hitId) {
        arm(zombie, hitId, false);
    }

    private static void arm(Object zombie, int hitId, boolean ranged) {
        long now = System.nanoTime();
        arm(
                zombie,
                new ArmedZombie(
                        now + ARM_WINDOW_NANOS,
                        now + RAGDOLL_START_TIMEOUT_NANOS,
                        hitId,
                        ranged,
                        PELVIS_BODY_PART,
                        8.0f,
                        0.25f,
                        1.0f,
                        0.0f,
                        HEAD_BODY_PART,
                        0.15f,
                        1.0f,
                        0.0f,
                        2.0f,
                        2.0f / MOVEMENT_VELOCITY_TO_IMPULSE_SCALE,
                        "test"));
    }

    private static void arm(Object zombie, PendingHitConsequences pending) {
        long now = System.nanoTime();
        arm(
                zombie,
                new ArmedZombie(
                        now + ARM_WINDOW_NANOS,
                        now + RAGDOLL_START_TIMEOUT_NANOS,
                        pending.hitId,
                        pending.ranged,
                        pending.impulseBodyPart,
                        pending.impulseMagnitude,
                        pending.upwardImpulse,
                        pending.directionX,
                        pending.directionY,
                        pending.reactionBodyPart,
                        pending.reactionImpulse,
                        pending.movementDirectionX,
                        pending.movementDirectionY,
                        pending.movementImpulse,
                        pending.movementSpeed,
                        pending.movementSource));
    }

    private static void arm(Object zombie, ArmedZombie marker) {
        long now = System.nanoTime();
        boolean newlyArmed;
        synchronized (MARKER_LOCK) {
            pruneExpired(now);
            newlyArmed = !ARMED_ZOMBIES.containsKey(zombie);
            ARMED_ZOMBIES.put(zombie, marker);
            hasArmedZombies = true;
        }
        if (newlyArmed) {
            ARMED_COUNT.incrementAndGet();
        }
    }

    private static boolean forceRagdollDeath(Object zombie) {
        return forceRagdollDeath(zombie, null);
    }

    private static boolean forceRagdollDeath(
            Object zombie,
            PendingHitConsequences pending) {
        String stage = "isHitFromBehind";
        try {
            boolean hitFromBehind = callBoolean(zombie, "isHitFromBehind");
            if (pending != null) {
                pending.previousActionState = safeStateName(callNoArgOrNull(zombie, "getActionStateName"));
                pending.previousAnimationState = safeStateName(callNoArgOrNull(zombie, "getAnimationStateName"));
                pending.previousFallOnFront = callBooleanOrDefault(zombie, "isFallOnFront", false);
            }
            stage = "setUsePhysicHitReaction";
            callOneArg(zombie, "setUsePhysicHitReaction", Boolean.TYPE, Boolean.TRUE);
            stage = "setRagdollFall";
            callOneArg(zombie, "setRagdollFall", Boolean.TYPE, Boolean.TRUE);
            if (pending != null && pending.forceFallOnFront) {
                stage = "setFallOnFront";
                callOneArg(zombie, "setFallOnFront", Boolean.TYPE, Boolean.TRUE);
                FORWARD_FALL_REQUEST_COUNT.incrementAndGet();
                trace(
                        pending.hitId,
                        "forward-fall-requested",
                        zombie,
                        "movementSpeed=" + pending.movementSpeed
                                + " movementDirection=" + pending.movementDirectionX + ','
                                + pending.movementDirectionY
                                + " hitDirection=" + pending.directionX + ',' + pending.directionY);
            }
            stage = "setOnFloor";
            callOneArg(zombie, "setOnFloor", Boolean.TYPE, Boolean.FALSE);
            stage = "setKnockedDown";
            callOneArg(zombie, "setKnockedDown", Boolean.TYPE, Boolean.TRUE);
            stage = "setStaggerBack";
            callOneArg(zombie, "setStaggerBack", Boolean.TYPE, Boolean.TRUE);
            stage = "setHitReaction";
            callOneArg(zombie, "setHitReaction", String.class, "");
            stage = "setPlayerAttackPosition";
            callOneArg(
                    zombie,
                    "setPlayerAttackPosition",
                    String.class,
                    hitFromBehind ? "BEHIND" : "FRONT");
            stage = "setHitForce";
            callOneArg(zombie, "setHitForce", Float.TYPE, Float.valueOf(1.0f));
            stage = "reportEvent";
            callOneArg(zombie, "reportEvent", String.class, "wasHit");
            stage = "forceActionState";
            String ragdollState = pending == null || pending.ragdollState == null
                    ? RAGDOLL_ACTION_STATE
                    : pending.ragdollState;
            forceActionAndAnimationState(zombie, ragdollState);
            FORCED_ACTION_STATE_COUNT.incrementAndGet();
            trace(
                    pending == null ? 0 : pending.hitId,
                    "transition-prepared",
                    zombie,
                    "direction=" + (hitFromBehind ? "BEHIND" : "FRONT")
                            + " fallOnFrontRequested=" + (pending != null && pending.forceFallOnFront)
                            + " forcedState=" + ragdollState
                            + " hitReaction=" + (pending == null ? "unknown" : pending.hitReaction)
                            + " impulseBodyPart=" + (pending == null ? 1 : pending.impulseBodyPart)
                            + " impulse=" + (pending == null ? 0.0f : pending.impulseMagnitude)
                            + " movementDirection=" + (pending == null
                                    ? "unknown"
                                    : pending.movementDirectionX + "," + pending.movementDirectionY)
                            + " movementSpeed=" + (pending == null ? 0.0f : pending.movementSpeed)
                            + " movementImpulse=" + (pending == null ? 0.0f : pending.movementImpulse)
                            + " movementSource=" + (pending == null ? "unknown" : pending.movementSource)
                            + " reactionBodyPart=" + (pending == null ? SPINE_BODY_PART : pending.reactionBodyPart)
                            + " reactionImpulse=" + (pending == null ? 0.0f : pending.reactionImpulse)
                            + " finalStage=" + stage);
            return true;
        } catch (ReflectiveOperationException | RuntimeException exception) {
            TRANSITION_FAILURE_COUNT.incrementAndGet();
            restorePreparedState(zombie, pending);
            trace(
                    pending == null ? 0 : pending.hitId,
                    "transition-failed",
                    zombie,
                    "stage=" + stage + " error=" + exception.getClass().getSimpleName());
            log("lethal-hit ragdoll transition failed at " + stage
                    + ": " + exception.getClass().getSimpleName());
            return false;
        }
    }

    private static void resetPreparedRagdoll(Object zombie) {
        callOneArgQuietly(zombie, "setUsePhysicHitReaction", Boolean.TYPE, Boolean.FALSE);
        callOneArgQuietly(zombie, "setRagdollFall", Boolean.TYPE, Boolean.FALSE);
    }

    private static void restorePreparedState(Object zombie, PendingHitConsequences pending) {
        resetPreparedRagdoll(zombie);
        if (pending == null) {
            return;
        }
        restoreActionAndAnimationState(
                zombie,
                pending.previousActionState,
                pending.previousAnimationState);
        callOneArgQuietly(
                zombie,
                "setFallOnFront",
                Boolean.TYPE,
                Boolean.valueOf(pending.previousFallOnFront));
    }

    private static boolean isLethalPreparationActive(Object zombie) {
        ArrayDeque<PendingHitConsequences> stack = HIT_CONSEQUENCES.get();
        if (stack.isEmpty()) {
            return false;
        }
        for (PendingHitConsequences pending : stack) {
            if (pending.target == zombie && pending.lethalPrepared) {
                return true;
            }
        }
        return false;
    }

    private static ArmedZombie getArmedMarker(Object zombie) {
        if (zombie == null) {
            return null;
        }
        long now = System.nanoTime();
        synchronized (MARKER_LOCK) {
            pruneExpired(now);
            ArmedZombie marker = ARMED_ZOMBIES.get(zombie);
            return marker != null && marker.expiresAt > now ? marker : null;
        }
    }

    private static boolean isArmed(Object zombie) {
        return getArmedMarker(zombie) != null;
    }

    private static void clear(Object zombie) {
        clear(zombie, "marker-cleared");
    }

    private static void clear(Object zombie, String reason) {
        ArmedZombie removed;
        synchronized (MARKER_LOCK) {
            removed = ARMED_ZOMBIES.remove(zombie);
            hasArmedZombies = !ARMED_ZOMBIES.isEmpty();
        }
        emitRigidSummary(zombie, removed, reason);
    }

    private static void pruneExpired(long now) {
        Iterator<Map.Entry<Object, ArmedZombie>> iterator = ARMED_ZOMBIES.entrySet().iterator();
        while (iterator.hasNext()) {
            Map.Entry<Object, ArmedZombie> entry = iterator.next();
            if (entry.getValue().expiresAt <= now) {
                emitRigidSummary(entry.getKey(), entry.getValue(), "marker-expired");
                iterator.remove();
            }
        }
        hasArmedZombies = !ARMED_ZOMBIES.isEmpty();
    }

    private static void emitRigidSummary(Object character, ArmedZombie marker, String reason) {
        if (marker == null || marker.rigidSummaryLogged) {
            return;
        }
        marker.rigidSummaryLogged = true;
        trace(marker.hitId, "rigid-summary", character, marker.rigidTelemetry.summaryDetails(reason));
        trace(marker.hitId, "rigid-body-summary", character, marker.rigidTelemetry.bodySummaryDetails());
        trace(marker.hitId, "rigid-arm-summary", character, marker.rigidTelemetry.armSummaryDetails());
        trace(marker.hitId, "rigid-joint-summary", character, marker.rigidTelemetry.jointSummaryDetails());
        RIGID_SUMMARY_COUNT.incrementAndGet();
    }

    private static Object getDeathPacketCharacter(Object packet) {
        Object characterId = Accessor.tryGet(packet, "characterId", null);
        return callNoArgOrNull(characterId, "getCharacter");
    }

    private static boolean isZombie(Object character) {
        return character != null && "zombie.characters.IsoZombie".equals(character.getClass().getName());
    }

    private static boolean isGameClient() {
        return readStaticBoolean("zombie.network.GameClient", "client");
    }

    private static boolean isGameServer() {
        return readStaticBoolean("zombie.network.GameServer", "server");
    }

    private static boolean readStaticBoolean(String className, String fieldName) {
        try {
            Class<?> targetClass = Class.forName(className, false, PrototypeRuntime.class.getClassLoader());
            return Accessor.tryGet(targetClass, fieldName, Boolean.FALSE);
        } catch (ClassNotFoundException | LinkageError | RuntimeException ignored) {
            return false;
        }
    }

    private static String getHitEligibilityRejection(
            Object target,
            Object weapon,
            boolean ignoreDamage) {
        if (!buildAccepted) {
            return "build-not-accepted";
        }
        if (!isGameClient()) {
            return "not-client";
        }
        if (isGameServer()) {
            return "server-process";
        }
        if (ignoreDamage) {
            return "ignore-damage";
        }
        if (!isZombie(target)) {
            return "target-not-zombie";
        }
        if (callBooleanOrDefault(target, "isDead", true)) {
            return "target-already-dead";
        }
        if (callBooleanOrDefault(target, "isOnFloor", true)
                && !callBooleanOrDefault(target, "isGettingUp", false)) {
            return "target-grounded";
        }
        if (weapon == null) {
            return "weapon-null";
        }
        if (callBooleanOrDefault(weapon, "isExplosive", true)) {
            return "weapon-explosive-or-unknown";
        }
        if (!isSupportedKillingWeapon(weapon)) {
            return "weapon-not-melee-or-ranged";
        }
        return null;
    }

    private static boolean isSupportedKillingWeapon(Object weapon) {
        if (weapon == null || callBooleanOrDefault(weapon, "isExplosive", true)) {
            return false;
        }
        return callBooleanOrDefault(weapon, "isMelee", false)
                || callBooleanOrDefault(weapon, "isRanged", false);
    }

    private static String selectRagdollState(PendingHitConsequences pending) {
        return selectRagdollState(pending.ranged, pending.weaponType);
    }

    private static String selectRagdollState(boolean ranged, String weaponType) {
        if (qualityMode == QUALITY_LEGACY) {
            return RAGDOLL_ACTION_STATE;
        }
        if (qualityMode == QUALITY_RESTRAINED || ranged) {
            return FAST_RAGDOLL_ACTION_STATE;
        }
        String weapon = weaponType == null ? "" : weaponType.toLowerCase();
        if (weapon.contains("spear")) {
            return SPEAR_RAGDOLL_ACTION_STATE;
        }
        if (weapon.contains("knife") || weapon.contains("smallblade") || weapon.contains("shortblade")) {
            return KNIFE_RAGDOLL_ACTION_STATE;
        }
        return RAGDOLL_ACTION_STATE;
    }

    private static int selectImpulseBodyPart(String hitReaction) {
        return PELVIS_BODY_PART;
    }

    private static int selectLocalizedReactionBodyPart(String hitReaction) {
        String reaction = hitReaction == null ? "" : hitReaction.toLowerCase();
        return reaction.contains("head") ? HEAD_BODY_PART : SPINE_BODY_PART;
    }

    private static float calculateImpulseMagnitude(PendingHitConsequences pending) {
        float weaponDamage = readFloat(callNoArgOrNull(pending.weapon, "getMaxDamage"), 2.0f);
        return calculateImpulseMagnitude(pending.ranged, pending.weaponType, weaponDamage);
    }

    private static float calculateImpulseMagnitude(
            boolean ranged,
            String weaponType,
            float weaponDamage) {
        if (ranged) {
            String weapon = weaponType == null ? "" : weaponType.toLowerCase();
            if (weapon.contains("shotgun")) {
                return 16.0f;
            }
            if (weapon.contains("308") || weapon.contains("556") || weapon.contains("rifle")) {
                return 13.0f;
            }
            if (weapon.contains("44") || weapon.contains("45") || weapon.contains("magnum")) {
                return 12.0f;
            }
            return 10.0f;
        }
        return Math.max(6.0f, Math.min(10.0f, 6.0f + weaponDamage * 1.3f));
    }

    private static float calculateUpwardImpulse(PendingHitConsequences pending) {
        return calculateUpwardImpulse(pending.ranged, pending.weaponType);
    }

    private static float calculateUpwardImpulse(boolean ranged, String weaponType) {
        if (!ranged) {
            return 0.25f;
        }
        String weapon = weaponType == null ? "" : weaponType.toLowerCase();
        if (weapon.contains("shotgun")) {
            return 1.0f;
        }
        if (weapon.contains("rifle") || weapon.contains("308") || weapon.contains("556")) {
            return 0.75f;
        }
        return 0.5f;
    }

    private static float calculateLocalizedReactionMagnitude(PendingHitConsequences pending) {
        float weaponDamage = readFloat(callNoArgOrNull(pending.weapon, "getMaxDamage"), 2.0f);
        float magnitude = calculateLocalizedReactionMagnitude(
                pending.ranged,
                pending.weaponType,
                weaponDamage,
                pending.reactionBodyPart);
        return magnitude;
    }

    private static float calculateLocalizedReactionMagnitude(
            boolean ranged,
            String weaponType,
            float weaponDamage,
            int bodyPart) {
        if (!ranged) {
            float magnitude = Math.max(0.18f, Math.min(0.35f, 0.16f + weaponDamage * 0.04f));
            return bodyPart == HEAD_BODY_PART ? magnitude * 0.6f : magnitude;
        }
        float targetVelocity;
        String weapon = weaponType == null ? "" : weaponType.toLowerCase();
        if (weapon.contains("shotgun_shell") || weapon.contains("shotgun")) {
            targetVelocity = 0.32f;
        } else if (weapon.contains("bullets_308") || weapon.contains("308")) {
            targetVelocity = 0.28f;
        } else if (weapon.contains("bullets_556") || weapon.contains("556")) {
            targetVelocity = 0.25f;
        } else if (weapon.contains("bullets_44")
                || weapon.contains("bullets_45")
                || weapon.contains("magnum")) {
            targetVelocity = 0.24f;
        } else if (weapon.contains("bullets_9mm")
                || weapon.contains("bullets_38")
                || weapon.contains("bullets_22")
                || weapon.contains("sten")
                || weapon.contains("smg")) {
            targetVelocity = 0.18f;
        } else if (weapon.contains("rifle")) {
            targetVelocity = 0.24f;
        } else {
            targetVelocity = 0.2f;
        }
        int safeBodyPart = bodyPart >= 0 && bodyPart < RAGDOLL_BODY_MASSES.length
                ? bodyPart
                : SPINE_BODY_PART;
        return targetVelocity * RAGDOLL_BODY_MASSES[safeBodyPart];
    }

    private static float calculateMovementImpulse(float movementSpeed) {
        if (!isFinite(movementSpeed) || !(movementSpeed > 0.001f)) {
            return 0.0f;
        }
        return Math.min(MAX_MOVEMENT_IMPULSE, movementSpeed * MOVEMENT_VELOCITY_TO_IMPULSE_SCALE);
    }

    private static boolean shouldForceFallOnFront(
            boolean ranged,
            float movementSpeed,
            float movementDirectionX,
            float movementDirectionY,
            float hitDirectionX,
            float hitDirectionY) {
        if (!ranged || !isFinite(movementSpeed) || movementSpeed < FORWARD_FALL_MIN_SPEED) {
            return false;
        }
        float movementLength = vectorLength(movementDirectionX, movementDirectionY, 0.0f);
        float hitLength = vectorLength(hitDirectionX, hitDirectionY, 0.0f);
        if (!(movementLength > 0.001f) || !(hitLength > 0.001f)) {
            return false;
        }
        float approachDot = (movementDirectionX * hitDirectionX
                + movementDirectionY * hitDirectionY) / (movementLength * hitLength);
        return approachDot <= FORWARD_FALL_APPROACH_DOT_LIMIT;
    }

    private static float calculateReactionVelocityDelta(
            float[] bodyMasses,
            int bodyPart,
            float impulse) {
        if (!(impulse > 0.0f)
                || bodyPart < 0
                || bodyPart >= bodyMasses.length) {
            return 0.0f;
        }
        return impulse / bodyMasses[bodyPart];
    }

    private static String describeWeapon(Object weapon) {
        if (weapon == null) {
            return "null";
        }
        StringBuilder builder = new StringBuilder(safeClassName(weapon));
        appendDescriptor(builder, callNoArgOrNull(weapon, "getFullType"));
        appendDescriptor(builder, callNoArgOrNull(weapon, "getAmmoType"));
        appendDescriptor(builder, callNoArgOrNull(weapon, "getCategories"));
        appendDescriptor(builder, callNoArgOrNull(weapon, "getSwingAnim"));
        return safeToken(builder.toString());
    }

    private static void appendDescriptor(StringBuilder builder, Object value) {
        if (value == null) {
            return;
        }
        String text = value.toString();
        if (!text.isEmpty()) {
            builder.append(':').append(text);
        }
    }

    private static float[] calculateHitDirection(Object target, Object wielder) {
        float targetX = readFloat(callNoArgOrNull(target, "getX"), Float.NaN);
        float targetY = readFloat(callNoArgOrNull(target, "getY"), Float.NaN);
        float wielderX = readFloat(callNoArgOrNull(wielder, "getX"), Float.NaN);
        float wielderY = readFloat(callNoArgOrNull(wielder, "getY"), Float.NaN);
        if (Float.isNaN(targetX) || Float.isNaN(targetY)
                || Float.isNaN(wielderX) || Float.isNaN(wielderY)) {
            return new float[] {1.0f, 0.0f};
        }
        float directionX = targetX - wielderX;
        float directionY = targetY - wielderY;
        float length = (float) Math.sqrt(directionX * directionX + directionY * directionY);
        if (!(length > 0.001f)) {
            return new float[] {1.0f, 0.0f};
        }
        return new float[] {directionX / length, directionY / length};
    }

    public static void sampleZombieMovement(Object target) {
        initialize();
        if (!buildAccepted) {
            return;
        }
        sampleZombieMovement(target, System.nanoTime());
    }

    private static void sampleZombieMovement(Object target, long nowNanos) {
        if (target == null) {
            return;
        }

        synchronized (MOVEMENT_HISTORY_LOCK) {
            pruneMovementHistory(nowNanos);
            MovementHistory existing = MOVEMENT_HISTORY.get(target);
            if (existing != null) {
                existing.lastObservedNanos = nowNanos;
                if (nowNanos - existing.positionSampleNanos < MOVEMENT_SAMPLE_INTERVAL_NANOS) {
                    return;
                }
            }
        }

        if (callBooleanOrDefault(target, "isDead", false)
                || callBooleanOrDefault(target, "isOnFloor", false)) {
            synchronized (MOVEMENT_HISTORY_LOCK) {
                MOVEMENT_HISTORY.remove(target);
            }
            return;
        }

        float x = readFloat(callNoArgOrNull(target, "getX"), Float.NaN);
        float y = readFloat(callNoArgOrNull(target, "getY"), Float.NaN);
        if (!isFinite(x) || !isFinite(y)) {
            return;
        }

        synchronized (MOVEMENT_HISTORY_LOCK) {
            MovementHistory history = MOVEMENT_HISTORY.get(target);
            if (history == null) {
                if (MOVEMENT_HISTORY.size() >= MOVEMENT_HISTORY_MAX_ENTRIES) {
                    return;
                }
                MOVEMENT_HISTORY.put(target, new MovementHistory(x, y, nowNanos));
                return;
            }

            long elapsedNanos = nowNanos - history.positionSampleNanos;
            if (elapsedNanos <= 0L) {
                history.positionX = x;
                history.positionY = y;
                history.positionSampleNanos = nowNanos;
                history.lastObservedNanos = nowNanos;
                return;
            }

            float movementX = x - history.positionX;
            float movementY = y - history.positionY;
            float distance = (float) Math.sqrt(movementX * movementX + movementY * movementY);
            history.positionX = x;
            history.positionY = y;
            history.positionSampleNanos = nowNanos;
            history.lastObservedNanos = nowNanos;
            if (distance < MOVEMENT_HISTORY_MIN_DISTANCE) {
                return;
            }

            float elapsedSeconds = elapsedNanos / 1_000_000_000.0f;
            float sampleDirectionX = movementX / distance;
            float sampleDirectionY = movementY / distance;
            float sampleSpeed = clampCapturedMovementSpeed(distance / elapsedSeconds);
            if (history.movementSampleNanos > 0L) {
                float retainedWeight = 1.0f - MOVEMENT_HISTORY_SMOOTHING;
                float smoothedVelocityX = history.directionX * history.speed * retainedWeight
                        + sampleDirectionX * sampleSpeed * MOVEMENT_HISTORY_SMOOTHING;
                float smoothedVelocityY = history.directionY * history.speed * retainedWeight
                        + sampleDirectionY * sampleSpeed * MOVEMENT_HISTORY_SMOOTHING;
                float smoothedSpeed = (float) Math.sqrt(
                        smoothedVelocityX * smoothedVelocityX
                                + smoothedVelocityY * smoothedVelocityY);
                if (smoothedSpeed > 0.001f) {
                    history.directionX = smoothedVelocityX / smoothedSpeed;
                    history.directionY = smoothedVelocityY / smoothedSpeed;
                    history.speed = clampCapturedMovementSpeed(smoothedSpeed);
                } else {
                    history.directionX = sampleDirectionX;
                    history.directionY = sampleDirectionY;
                    history.speed = sampleSpeed;
                }
            } else {
                history.directionX = sampleDirectionX;
                history.directionY = sampleDirectionY;
                history.speed = sampleSpeed;
            }
            history.movementSampleNanos = nowNanos;
        }
    }

    private static void pruneMovementHistory(long nowNanos) {
        if (nowNanos - lastMovementHistoryPruneNanos < MOVEMENT_HISTORY_PRUNE_INTERVAL_NANOS
                && MOVEMENT_HISTORY.size() < MOVEMENT_HISTORY_MAX_ENTRIES) {
            return;
        }
        Iterator<Map.Entry<Object, MovementHistory>> iterator =
                MOVEMENT_HISTORY.entrySet().iterator();
        while (iterator.hasNext()) {
            MovementHistory history = iterator.next().getValue();
            if (nowNanos - history.lastObservedNanos > MOVEMENT_HISTORY_ENTRY_TTL_NANOS) {
                iterator.remove();
            }
        }
        lastMovementHistoryPruneNanos = nowNanos;
    }

    private static MovementSnapshot captureMovementSnapshot(Object target) {
        return captureMovementSnapshot(target, System.nanoTime());
    }

    private static MovementSnapshot captureMovementSnapshot(Object target, long nowNanos) {
        float x = readFloat(callNoArgOrNull(target, "getX"), Float.NaN);
        float y = readFloat(callNoArgOrNull(target, "getY"), Float.NaN);
        float lastX = readFloat(callNoArgOrNull(target, "getLastX"), Float.NaN);
        float lastY = readFloat(callNoArgOrNull(target, "getLastY"), Float.NaN);
        float movementSpeed = readFloat(callNoArgOrNull(target, "getMovementSpeed"), Float.NaN);
        float frameSeconds = getRealworldFrameSeconds();
        float movementVelocity = isFinite(movementSpeed) && frameSeconds > 0.0f
                ? clampCapturedMovementSpeed(movementSpeed / frameSeconds)
                : Float.NaN;
        if (isFinite(x) && isFinite(y) && isFinite(lastX) && isFinite(lastY)) {
            float movementX = x - lastX;
            float movementY = y - lastY;
            float length = (float) Math.sqrt(movementX * movementX + movementY * movementY);
            if (length > 0.001f) {
                float capturedSpeed = isFinite(movementVelocity) && movementVelocity > 0.0f
                        ? movementVelocity
                        : clampCapturedMovementSpeed(length / frameSeconds);
                return new MovementSnapshot(
                        movementX / length,
                        movementY / length,
                        capturedSpeed,
                        "displacement",
                        frameSeconds,
                        length,
                        movementSpeed,
                        -1.0f);
            }
        }
        synchronized (MOVEMENT_HISTORY_LOCK) {
            MovementHistory history = MOVEMENT_HISTORY.get(target);
            if (history != null && history.movementSampleNanos > 0L) {
                long ageNanos = nowNanos - history.movementSampleNanos;
                if (ageNanos >= 0L && ageNanos <= MOVEMENT_HISTORY_MAX_AGE_NANOS) {
                    return new MovementSnapshot(
                            history.directionX,
                            history.directionY,
                            history.speed,
                            "history",
                            frameSeconds,
                            0.0f,
                            movementSpeed,
                            ageNanos / 1_000_000.0f);
                }
            }
        }
        if (isFinite(movementVelocity) && movementVelocity > 0.001f) {
            float forwardX = readFloat(callNoArgOrNull(target, "getForwardDirectionX"), 0.0f);
            float forwardY = readFloat(callNoArgOrNull(target, "getForwardDirectionY"), 0.0f);
            float length = (float) Math.sqrt(forwardX * forwardX + forwardY * forwardY);
            if (length > 0.001f) {
                return new MovementSnapshot(
                        forwardX / length,
                        forwardY / length,
                        movementVelocity,
                        "forward-fallback",
                        frameSeconds,
                        0.0f,
                        movementSpeed,
                        -1.0f);
            }
        }
        return new MovementSnapshot(
                0.0f,
                0.0f,
                0.0f,
                "stationary",
                frameSeconds,
                0.0f,
                movementSpeed,
                -1.0f);
    }

    private static float clampCapturedMovementSpeed(float movementSpeed) {
        if (!isFinite(movementSpeed) || !(movementSpeed > 0.0f)) {
            return 0.0f;
        }
        return Math.min(MAX_CAPTURED_MOVEMENT_SPEED, movementSpeed);
    }

    private static void traceMotionSample(
            ArmedZombie marker,
            Object ragdollController,
            Object character,
            float deltaT) {
        if (callBooleanOrDefault(ragdollController, "isFirstFrame", true)) {
            return;
        }

        float pelvisX = readFloat(callNoArgOrNull(ragdollController, "getPelvisPositionX"), Float.NaN);
        float pelvisY = readFloat(callNoArgOrNull(ragdollController, "getPelvisPositionY"), Float.NaN);
        float desiredX = readFloat(
                callNoArgOrNull(ragdollController, "getDesiredCharacterPositionX"),
                Float.NaN);
        float desiredY = readFloat(
                callNoArgOrNull(ragdollController, "getDesiredCharacterPositionY"),
                Float.NaN);
        float characterX = readFloat(callNoArgOrNull(character, "getX"), Float.NaN);
        float characterY = readFloat(callNoArgOrNull(character, "getY"), Float.NaN);
        if (!isFinite(pelvisX) || !isFinite(pelvisY)
                || !isFinite(desiredX) || !isFinite(desiredY)
                || !isFinite(characterX) || !isFinite(characterY)) {
            return;
        }
        int sample = ++marker.motionSampleCount;
        if (!marker.motionBaselineCaptured) {
            marker.motionBaselineCaptured = true;
            marker.motionBaselinePelvisX = pelvisX;
            marker.motionBaselinePelvisY = pelvisY;
            marker.motionBaselineDesiredX = desiredX;
            marker.motionBaselineDesiredY = desiredY;
            marker.motionBaselineCharacterX = characterX;
            marker.motionBaselineCharacterY = characterY;
        }
        if (sample != 1 && sample != 2 && sample != 4
                && sample != 8 && sample != 16 && sample != 32) {
            return;
        }

        float pelvisDeltaX = relativeDelta(pelvisX, marker.motionBaselinePelvisX);
        float pelvisDeltaY = relativeDelta(pelvisY, marker.motionBaselinePelvisY);
        float projectedPelvisDelta = pelvisDeltaX * marker.movementDirectionX
                + pelvisDeltaY * marker.movementDirectionY;
        trace(
                marker.hitId,
                "motion-sample",
                character,
                "sample=" + sample
                        + " deltaT=" + deltaT
                        + " pelvisDelta=" + pelvisDeltaX + ',' + pelvisDeltaY
                        + " pelvisForward=" + projectedPelvisDelta
                        + " desiredDelta="
                        + relativeDelta(desiredX, marker.motionBaselineDesiredX) + ','
                        + relativeDelta(desiredY, marker.motionBaselineDesiredY)
                        + " characterDelta="
                        + relativeDelta(characterX, marker.motionBaselineCharacterX) + ','
                        + relativeDelta(characterY, marker.motionBaselineCharacterY)
                        + " sleeping="
                        + callBooleanOrDefault(ragdollController, "isSimulationSleeping", false));
    }

    private static float relativeDelta(float value, float baseline) {
        return isFinite(value) && isFinite(baseline) ? value - baseline : Float.NaN;
    }

    private static void capturePendingRagdollFrame(
            Object ragdollController,
            Object character,
            ArmedZombie marker,
            String source) {
        int updateSequence = marker.rigidUpdateSequence;
        if (updateSequence <= 0 || marker.rigidCapturedUpdateSequence == updateSequence) {
            return;
        }
        if (marker.rigidFallbackAttemptedUpdateSequence == updateSequence) {
            return;
        }
        marker.rigidFallbackAttemptedUpdateSequence = updateSequence;

        float[] rigidBodyBuffer = readRigidBodyBuffer(ragdollController);
        if (rigidBodyBuffer == null) {
            RIGID_FALLBACK_UNAVAILABLE_COUNT.incrementAndGet();
            if (marker.rigidFallbackUnavailableLogs < 3) {
                marker.rigidFallbackUnavailableLogs++;
                trace(
                        marker.hitId,
                        "rigid-fallback-unavailable",
                        character,
                        "updateSequence=" + updateSequence
                                + " reason=" + safeToken(rigidBodyBufferFailure));
            }
            return;
        }

        RIGID_FALLBACK_CAPTURE_COUNT.incrementAndGet();
        if (!marker.rigidFallbackLogged) {
            marker.rigidFallbackLogged = true;
            trace(
                    marker.hitId,
                    "rigid-fallback-capture",
                    character,
                    "updateSequence=" + updateSequence
                            + " bufferLength=" + rigidBodyBuffer.length
                            + " source=" + source
                            + " reason=simulate-advice-missed");
        }
        captureRagdollFrame(ragdollController, rigidBodyBuffer, character, marker);
    }

    private static float[] readRigidBodyBuffer(Object ragdollController) {
        if (ragdollController == null) {
            rigidBodyBufferFailure = "null-controller";
            return null;
        }

        Class<?> controllerClass = ragdollController.getClass();
        Field field = rigidBodyBufferField;
        if (!rigidBodyBufferLookupComplete || rigidBodyBufferOwner != controllerClass) {
            synchronized (RIGID_BODY_BUFFER_FIELD_LOCK) {
                field = rigidBodyBufferField;
                if (!rigidBodyBufferLookupComplete || rigidBodyBufferOwner != controllerClass) {
                    rigidBodyBufferOwner = controllerClass;
                    rigidBodyBufferField = null;
                    rigidBodyBufferLookupComplete = false;
                    try {
                        field = controllerClass.getDeclaredField("rigidBodyBuffer");
                        field.setAccessible(true);
                        rigidBodyBufferField = field;
                        rigidBodyBufferFailure = "none";
                    } catch (ReflectiveOperationException | SecurityException exception) {
                        rigidBodyBufferFailure = exception.getClass().getSimpleName();
                    } finally {
                        rigidBodyBufferLookupComplete = true;
                    }
                }
            }
        }
        field = rigidBodyBufferField;
        if (field == null) {
            return null;
        }

        try {
            Object value = field.get(null);
            if (value instanceof float[]) {
                return (float[]) value;
            }
            rigidBodyBufferFailure = value == null
                    ? "null-buffer"
                    : "unexpected-" + value.getClass().getSimpleName();
        } catch (IllegalAccessException | IllegalArgumentException exception) {
            rigidBodyBufferFailure = exception.getClass().getSimpleName();
        }
        return null;
    }

    private static float vectorLength(float valueX, float valueY, float valueZ) {
        return (float) Math.sqrt(valueX * valueX + valueY * valueY + valueZ * valueZ);
    }

    private static float getRealworldFrameSeconds() {
        try {
            Object gameTime = Accessor.callByName("zombie.GameTime", "getInstance");
            float frameSeconds = readFloat(
                    callNoArgOrNull(gameTime, "getRealworldSecondsSinceLastUpdate"),
                    1.0f / 60.0f);
            return Math.max(1.0f / 240.0f, Math.min(frameSeconds, 0.1f));
        } catch (ReflectiveOperationException | RuntimeException exception) {
            return 1.0f / 60.0f;
        }
    }

    private static boolean applyMassWeightedMovementImpulse(
            int ragdollId,
            float directionX,
            float directionY,
            float totalImpulse,
            float[] bodyMasses) {
        if (!(totalImpulse > 0.0f)) {
            return true;
        }
        for (int bodyPart = 0; bodyPart < bodyMasses.length; bodyPart++) {
            if (!applyDirectedImpulse(
                    ragdollId,
                    bodyPart,
                    directionX,
                    directionY,
                    totalImpulse * bodyMasses[bodyPart],
                    0.0f)) {
                return false;
            }
        }
        return true;
    }

    private static void ensureRagdollTemplates() throws ReflectiveOperationException {
        if (vanillaBodyPartInfoTemplate != null && restrainedBodyPartInfoTemplate != null) {
            return;
        }
        Object bodyParts = Accessor.callByName(
                "zombie.scripting.objects.RagdollScript", "getRagdollBodyPartInfoList");
        if (!(bodyParts instanceof List)) {
            throw new ReflectiveOperationException("ragdoll body-part script list unavailable");
        }
        vanillaBodyPartInfoTemplate = serializeRagdollBodyPartInfo((List<?>) bodyParts);
        restrainedBodyPartInfoTemplate = vanillaBodyPartInfoTemplate.clone();
        applyRestrainedBodyPartInfoProfile(restrainedBodyPartInfoTemplate);
    }

    private static float[] serializeRagdollBodyPartInfo(List<?> bodyPartInfo)
            throws ReflectiveOperationException {
        if (bodyPartInfo.isEmpty()) {
            throw new ReflectiveOperationException("ragdoll body-part list empty");
        }
        float[] result = new float[bodyPartInfo.size() * RAGDOLL_BODY_PART_INFO_STRIDE];
        int offset = 0;
        for (Object info : bodyPartInfo) {
            result[offset++] = readPublicInt(info, "part");
            result[offset++] = readPublicBoolean(info, "calculateLength") ? 1.0f : 0.0f;
            result[offset++] = readPublicFloat(info, "radius");
            result[offset++] = readPublicFloat(info, "height");
            result[offset++] = readPublicFloat(info, "gap");
            result[offset++] = readPublicInt(info, "shape");
            result[offset++] = readPublicFloat(info, "mass");
            offset = appendPublicVector(result, offset, info, "offset");
        }
        return result;
    }

    private static void applyRestrainedBodyPartInfoProfile(float[] bodyPartInfo)
            throws ReflectiveOperationException {
        boolean[] seen = new boolean[RigidBodyTelemetry.BODY_COUNT];
        for (int offset = 0; offset < bodyPartInfo.length; offset += RAGDOLL_BODY_PART_INFO_STRIDE) {
            int bodyPart = Math.round(bodyPartInfo[offset]);
            if (bodyPart < 0 || bodyPart >= RESTRAINED_RAGDOLL_BODY_MASSES.length) {
                throw new ReflectiveOperationException("unexpected ragdoll body part " + bodyPart);
            }
            bodyPartInfo[offset + 6] = RESTRAINED_RAGDOLL_BODY_MASSES[bodyPart];
            if (bodyPart >= 7 && bodyPart <= 10) {
                bodyPartInfo[offset + 2] *= RESTRAINED_ARM_RADIUS_SCALE;
            }
            seen[bodyPart] = true;
        }
        for (int bodyPart = 0; bodyPart < seen.length; bodyPart++) {
            if (!seen[bodyPart]) {
                throw new ReflectiveOperationException("ragdoll body part missing " + bodyPart);
            }
        }
    }

    private static boolean defineRagdollBodyPartInfo(float[] bodyPartInfo) {
        return defineRagdollTemplate("defineRagdollBodyPartInfo", bodyPartInfo);
    }

    private static boolean defineRagdollTemplate(String methodName, float[] values) {
        if (values == null || values.length == 0) {
            return false;
        }
        try {
            Object result = callStaticByName(
                    "zombie.core.physics.Bullet", methodName, values, Boolean.FALSE);
            return Boolean.TRUE.equals(result);
        } catch (ReflectiveOperationException | RuntimeException exception) {
            return false;
        }
    }

    private static boolean restoreRagdollBodyPartInfoQuietly() {
        if (defineRagdollBodyPartInfo(vanillaBodyPartInfoTemplate)) {
            return true;
        }
        try {
            callStaticVoidByName(
                    "zombie.scripting.objects.RagdollScript",
                    "uploadBodyPartInfo",
                    Boolean.FALSE);
            return true;
        } catch (ReflectiveOperationException | RuntimeException exception) {
            return false;
        }
    }

    private static int appendPublicVector(
            float[] output,
            int offset,
            Object owner,
            String fieldName) throws ReflectiveOperationException {
        Object vector = readPublicField(owner, fieldName);
        output[offset++] = readPublicFloat(vector, "x");
        output[offset++] = readPublicFloat(vector, "y");
        output[offset++] = readPublicFloat(vector, "z");
        return offset;
    }

    private static Object readPublicField(Object owner, String fieldName)
            throws ReflectiveOperationException {
        if (owner == null) {
            throw new ReflectiveOperationException("null owner for field " + fieldName);
        }
        return owner.getClass().getField(fieldName).get(owner);
    }

    private static int readPublicInt(Object owner, String fieldName)
            throws ReflectiveOperationException {
        Object value = readPublicField(owner, fieldName);
        if (!(value instanceof Number)) {
            throw new ReflectiveOperationException("non-numeric field " + fieldName);
        }
        return ((Number) value).intValue();
    }

    private static float readPublicFloat(Object owner, String fieldName)
            throws ReflectiveOperationException {
        Object value = readPublicField(owner, fieldName);
        if (!(value instanceof Number)) {
            throw new ReflectiveOperationException("non-numeric field " + fieldName);
        }
        float result = ((Number) value).floatValue();
        if (!isFinite(result)) {
            throw new ReflectiveOperationException("non-finite field " + fieldName);
        }
        return result;
    }

    private static boolean readPublicBoolean(Object owner, String fieldName)
            throws ReflectiveOperationException {
        Object value = readPublicField(owner, fieldName);
        if (!(value instanceof Boolean)) {
            throw new ReflectiveOperationException("non-boolean field " + fieldName);
        }
        return ((Boolean) value).booleanValue();
    }

    private static boolean applyForwardPitchAdjustment(
            int ragdollId,
            float directionX,
            float directionY,
            float movementImpulse,
            float[] bodyMasses) {
        float weightedMass = 0.0f;
        for (int bodyPart = 0; bodyPart < bodyMasses.length; bodyPart++) {
            weightedMass += bodyMasses[bodyPart]
                    * FORWARD_FALL_PITCH_MULTIPLIERS[bodyPart];
        }
        if (!(weightedMass > 0.0f)) {
            return false;
        }
        float totalMass = 0.0f;
        for (float bodyMass : bodyMasses) {
            totalMass += bodyMass;
        }

        for (int bodyPart = 0; bodyPart < bodyMasses.length; bodyPart++) {
            float velocityAdjustment = movementImpulse
                    * (FORWARD_FALL_PITCH_MULTIPLIERS[bodyPart]
                            * totalMass / weightedMass - 1.0f);
            float bodyImpulse = bodyMasses[bodyPart]
                    * velocityAdjustment;
            if (!applyDirectedImpulse(
                    ragdollId,
                    bodyPart,
                    directionX,
                    directionY,
                    bodyImpulse,
                    0.0f)) {
                return false;
            }
        }
        return true;
    }

    private static boolean applyDirectedImpulse(
            int ragdollId,
            int bodyPart,
            float directionX,
            float directionY,
            float impulse,
            float upwardImpulse) {
        return applyBodyImpulse(
                ragdollId,
                bodyPart,
                directionX * impulse,
                upwardImpulse,
                directionY * impulse);
    }

    private static boolean applyBodyImpulse(
            int ragdollId,
            int bodyPart,
            float impulseX,
            float impulseY,
            float impulseZ) {
        try {
            float[] parameters = new float[] {
                impulseX,
                impulseY,
                impulseZ,
                0.0f,
                0.0f,
                0.0f
            };
            callStaticByName(
                    "zombie.core.physics.Bullet",
                    "applyImpulse",
                    Integer.valueOf(ragdollId),
                    Integer.valueOf(bodyPart),
                    parameters);
            return true;
        } catch (ReflectiveOperationException | RuntimeException exception) {
            return false;
        }
    }

    private static boolean tuneRagdollDynamics(
            int ragdollId,
            boolean restrainedArmProfile) {
        boolean success = true;
        for (int bodyPart = 0; bodyPart <= 10; bodyPart++) {
            float linearDamping = 0.05f;
            float angularDamping;
            float deactivationTime = 0.55f;
            float linearSleepingThreshold = 1.9f;
            float angularSleepingThreshold = 3.0f;
            float friction = 1.5f;
            float rollingFriction = 0.5f;
            if (restrainedArmProfile) {
                if (bodyPart == 7 || bodyPart == 8 || bodyPart == 9 || bodyPart == 10) {
                    boolean upperArm = bodyPart == 7 || bodyPart == 9;
                    linearDamping = upperArm
                            ? RESTRAINED_UPPER_ARM_LINEAR_DAMPING
                            : RESTRAINED_LOWER_ARM_LINEAR_DAMPING;
                    angularDamping = 0.9997f;
                    deactivationTime = 0.45f;
                    linearSleepingThreshold = 1.8f;
                    angularSleepingThreshold = 2.8f;
                    friction = upperArm
                            ? RESTRAINED_UPPER_ARM_FRICTION
                            : RESTRAINED_LOWER_ARM_FRICTION;
                    rollingFriction = RESTRAINED_ARM_ROLLING_FRICTION;
                } else if (bodyPart == 3 || bodyPart == 4 || bodyPart == 5 || bodyPart == 6) {
                    angularDamping = 0.997f;
                    deactivationTime = 0.50f;
                    linearSleepingThreshold = 1.8f;
                    angularSleepingThreshold = 2.8f;
                } else if (bodyPart == HEAD_BODY_PART) {
                    angularDamping = 0.985f;
                } else if (bodyPart == SPINE_BODY_PART) {
                    angularDamping = 0.94f;
                } else {
                    angularDamping = 0.92f;
                }
            } else if (bodyPart == 7 || bodyPart == 9) {
                angularDamping = 0.995f;
            } else if (bodyPart == 8 || bodyPart == 10) {
                angularDamping = 0.97f;
            } else if (bodyPart >= 3) {
                angularDamping = 0.96f;
            } else if (bodyPart == 2) {
                angularDamping = 0.94f;
            } else {
                angularDamping = 0.92f;
            }
            float[] parameters = new float[] {
                bodyPart,
                linearDamping,
                angularDamping,
                deactivationTime,
                linearSleepingThreshold,
                angularSleepingThreshold,
                friction,
                rollingFriction
            };
            try {
                Object result = callStaticByName(
                        "zombie.core.physics.Bullet",
                        "setRagdollBodyDynamics",
                        Integer.valueOf(ragdollId),
                        parameters);
                success &= Boolean.TRUE.equals(result);
            } catch (ReflectiveOperationException | RuntimeException exception) {
                return false;
            }
        }
        return success;
    }

    private static Object callStaticByName(
            String className,
            String methodName,
            Object... arguments) throws ReflectiveOperationException {
        Object result = Accessor.klass(className).call(methodName, arguments).orElse(null);
        if (result == null && !"applyImpulse".equals(methodName)) {
            throw new ReflectiveOperationException("static call returned no result: " + methodName);
        }
        return result;
    }

    private static void callStaticVoidByName(
            String className,
            String methodName,
            Object... arguments) throws ReflectiveOperationException {
        Accessor.klass(className).call(methodName, arguments);
    }

    private static int readInt(Object value, int defaultValue) {
        return value instanceof Number ? ((Number) value).intValue() : defaultValue;
    }

    private static float readFloat(Object value, float defaultValue) {
        return value instanceof Number ? ((Number) value).floatValue() : defaultValue;
    }

    private static String qualityModeName() {
        switch (qualityMode) {
            case QUALITY_LEGACY:
                return "legacy";
            case QUALITY_STABILIZED:
                return "stabilized";
            case QUALITY_ASSISTED:
                return "assisted";
            default:
                return "restrained";
        }
    }

    private static boolean isFinite(float value) {
        return !Float.isNaN(value) && !Float.isInfinite(value);
    }

    private static String getRagdollGateRejection(Object character) {
        initialize();
        if (!buildAccepted) {
            return "build-not-accepted";
        }
        if (!hasArmedZombies || !isArmed(character)) {
            return "target-not-armed";
        }
        if (!isZombie(character)) {
            return "target-not-zombie";
        }
        if (!isGameClient()) {
            return "not-client";
        }
        if (isGameServer()) {
            return "server-process";
        }

        try {
            if (!callBoolean(character, "isDead")
                    && !isLethalPreparationActive(character)) {
                return "alive-outside-lethal-preparation";
            }
            if (callBoolean(character, "isSceneCulled")) {
                return "scene-culled";
            }
            if (!callBoolean(character, "hasAnimationPlayer")) {
                return "no-animation-player";
            }
            if (isRagdollDebugDisabled()) {
                return "ragdolls-debug-disabled";
            }
            if (!Accessor.tryGet(character, "wornClothingCanRagdoll", Boolean.FALSE)) {
                return "clothing-cannot-ragdoll";
            }

            Object controller = callNoArgOrNull(character, "getRagdollController");
            if (controller == null) {
                int activeRagdolls = getActiveRagdollCount();
                if (activeRagdolls >= MAX_ACTIVE_RAGDOLLS) {
                    return "active-ragdoll-cap-" + activeRagdolls;
                }
            }
            return null;
        } catch (ReflectiveOperationException exception) {
            return "reflection-" + exception.getClass().getSimpleName();
        } catch (RuntimeException exception) {
            return "runtime-" + exception.getClass().getSimpleName();
        }
    }

    private static boolean isEligibleOffGroundZombie(Object zombie) {
        return isZombie(zombie)
                && !callBooleanOrDefault(zombie, "isDead", true)
                && (!callBooleanOrDefault(zombie, "isOnFloor", true)
                        || callBooleanOrDefault(zombie, "isGettingUp", false));
    }

    private static boolean wouldBeKilledByDamage(Object zombie, float damage) {
        if (zombie == null || !(damage > 0.0f) || Float.isNaN(damage)) {
            return false;
        }
        Object health = callNoArgOrNull(zombie, "getHealth");
        return health instanceof Number && ((Number) health).floatValue() <= damage;
    }

    private static void forceActionAndAnimationState(Object zombie, String stateName)
            throws ReflectiveOperationException {
        Object actionContext = Accessor.callNoArg(zombie, "getActionContext");
        if (actionContext == null) {
            throw new ReflectiveOperationException("action context unavailable");
        }
        Object actionGroup = Accessor.callNoArg(actionContext, "getGroup");
        if (actionGroup == null) {
            throw new ReflectiveOperationException("action group unavailable");
        }
        Object actionState = Accessor.callExact(
                actionGroup,
                "findState",
                new Class<?>[] {String.class},
                stateName);
        if (actionState == null) {
            throw new ReflectiveOperationException("action state unavailable: " + stateName);
        }
        Class<?> actionStateClass = Class.forName(
                "zombie.characters.action.ActionState",
                false,
                PrototypeRuntime.class.getClassLoader());
        Accessor.callExact(
                actionContext,
                "setCurrentState",
                new Class<?>[] {actionStateClass},
                actionState);

        Object advancedAnimator = Accessor.callNoArg(zombie, "getAdvancedAnimator");
        if (advancedAnimator == null) {
            throw new ReflectiveOperationException("advanced animator unavailable");
        }
        callOneArg(advancedAnimator, "setState", String.class, stateName);

        String actionStateName = safeStateName(callNoArgOrNull(actionContext, "getCurrentStateName"));
        String animationStateName = safeStateName(callNoArgOrNull(advancedAnimator, "getCurrentStateName"));
        if (!stateName.equalsIgnoreCase(actionStateName)) {
            throw new ReflectiveOperationException("action state force did not stick");
        }
        if (!stateName.equalsIgnoreCase(animationStateName)) {
            throw new ReflectiveOperationException("animation state force did not stick");
        }
    }

    private static void restoreActionAndAnimationState(
            Object zombie,
            String actionStateName,
            String animationStateName) {
        try {
            if (actionStateName != null && !actionStateName.isEmpty()) {
                Object actionContext = Accessor.callNoArg(zombie, "getActionContext");
                Object actionGroup = Accessor.callNoArg(actionContext, "getGroup");
                Object actionState = Accessor.callExact(
                        actionGroup,
                        "findState",
                        new Class<?>[] {String.class},
                        actionStateName);
                if (actionState != null) {
                    Class<?> actionStateClass = Class.forName(
                            "zombie.characters.action.ActionState",
                            false,
                            PrototypeRuntime.class.getClassLoader());
                    Accessor.callExact(
                            actionContext,
                            "setCurrentState",
                            new Class<?>[] {actionStateClass},
                            actionState);
                }
            }
            if (animationStateName != null && !animationStateName.isEmpty()) {
                Object advancedAnimator = Accessor.callNoArg(zombie, "getAdvancedAnimator");
                callOneArg(advancedAnimator, "setState", String.class, animationStateName);
            }
        } catch (ReflectiveOperationException | RuntimeException ignored) {
        }
    }

    private static RagdollStateSnapshot observeRagdollState(
            Object character,
            ArmedZombie marker) {
        RagdollStateSnapshot snapshot = new RagdollStateSnapshot(
                safeStateName(callNoArgOrNull(character, "getActionStateName")),
                safeStateName(callNoArgOrNull(character, "getAnimationStateName")),
                hasRagdollAnimationTrack(character),
                callNoArgOrNull(character, "getRagdollController") != null,
                isAnimationRagdollActive(character));
        if (snapshot.simulationActive && !marker.simulationObserved) {
            marker.simulationObserved = true;
            RAGDOLL_START_COUNT.incrementAndGet();
            trace(marker.hitId, "ragdoll-started", character, snapshot.details());
        }
        return snapshot;
    }

    private static void traceRagdollStateIfChanged(
            Object character,
            ArmedZombie marker,
            String event,
            String details) {
        RagdollStateSnapshot snapshot = observeRagdollState(character, marker);
        String signature = event + '|' + snapshot.signature() + '|' + details;
        if (signature.equals(marker.lastTraceSignature)) {
            return;
        }
        marker.lastTraceSignature = signature;
        trace(marker.hitId, event, character, details + ' ' + snapshot.details());
    }

    private static boolean isAnimationRagdollActive(Object character) {
        Object animationPlayer = callNoArgOrNull(character, "getAnimationPlayer");
        return callBooleanOrDefault(animationPlayer, "isRagdollSimulationActive", false);
    }

    private static boolean hasRagdollAnimationTrack(Object character) {
        Object animationPlayer = callNoArgOrNull(character, "getAnimationPlayer");
        Object multiTrack = callNoArgOrNull(animationPlayer, "getMultiTrack");
        return callBooleanOrDefault(multiTrack, "containsAnyRagdollTracks", false);
    }

    private static String safeStateName(Object value) {
        return value == null ? "" : safeToken(value.toString());
    }

    private static boolean isRagdollDebugDisabled() throws ReflectiveOperationException {
        Class<?> debugOptionsClass = Class.forName("zombie.debug.DebugOptions");
        Object debugOptions = Accessor.tryGet(debugOptionsClass, "instance", null);
        Object animation = Accessor.tryGet(debugOptions, "animation", null);
        Object disableRagdolls = Accessor.tryGet(animation, "disableRagdolls", null);
        if (disableRagdolls == null) {
            throw new NoSuchFieldException("DebugOptions.animation.disableRagdolls");
        }
        return callBoolean(disableRagdolls, "getValue");
    }

    private static int getActiveRagdollCount() throws ReflectiveOperationException {
        Object count = Accessor.callByName(
                "zombie.core.physics.RagdollController",
                "getNumberOfActiveSimulations");
        if (!(count instanceof Number)) {
            throw new ReflectiveOperationException("active ragdoll count unavailable");
        }
        return ((Number) count).intValue();
    }

    private static boolean callBoolean(Object target, String methodName)
            throws ReflectiveOperationException {
        return Boolean.TRUE.equals(Accessor.callNoArg(target, methodName));
    }

    private static boolean callBooleanOrDefault(Object target, String methodName, boolean defaultValue) {
        try {
            return callBoolean(target, methodName);
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            return defaultValue;
        }
    }

    private static Boolean callBooleanOrNull(Object target, String methodName) {
        try {
            return Boolean.valueOf(callBoolean(target, methodName));
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            return null;
        }
    }

    private static Object callNoArgOrNull(Object target, String methodName) {
        if (target == null) {
            return null;
        }
        try {
            return Accessor.callNoArg(target, methodName);
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            return null;
        }
    }

    private static void callOneArgQuietly(
            Object target,
            String methodName,
            Class<?> parameterType,
            Object value) {
        try {
            callOneArg(target, methodName, parameterType, value);
        } catch (ReflectiveOperationException | RuntimeException ignored) {
        }
    }

    private static void callOneArg(
            Object target,
            String methodName,
            Class<?> parameterType,
            Object value) throws ReflectiveOperationException {
        Accessor.callExact(target, methodName, new Class<?>[] {parameterType}, value);
    }

    private static Path locateGameJar() throws Exception {
        Class<?> gameClass = Class.forName(
                "zombie.characters.IsoGameCharacter",
                false,
                PrototypeRuntime.class.getClassLoader());
        URL location = gameClass.getProtectionDomain().getCodeSource().getLocation();
        if (location != null) {
            URI uri = location.toURI();
            Path codeSource = Paths.get(uri);
            if (Files.isRegularFile(codeSource)) {
                return codeSource;
            }
            Path adjacentJar = codeSource.resolve("projectzomboid.jar");
            if (Files.isRegularFile(adjacentJar)) {
                return adjacentJar;
            }
        }

        String[] classPathEntries = System.getProperty("java.class.path", "").split(
                java.io.File.pathSeparator);
        for (String entry : classPathEntries) {
            Path path = Paths.get(entry);
            if (path.getFileName() != null
                    && "projectzomboid.jar".equalsIgnoreCase(path.getFileName().toString())
                    && Files.isRegularFile(path)) {
                return path;
            }
        }
        return null;
    }

    private static String sha256(Path path) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        byte[] buffer = new byte[1024 * 1024];
        try (InputStream input = Files.newInputStream(path)) {
            int read;
            while ((read = input.read(buffer)) >= 0) {
                if (read > 0) {
                    digest.update(buffer, 0, read);
                }
            }
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    private static void disable(String reason) {
        buildAccepted = false;
        state = reason;
        log(reason);
    }

    private static void log(String message) {
        String line = "[MPRagdollPrototype] " + message;
        writeTelemetryFile(line);
        writeGameLog(line);
    }

    private static void traceHit(
            PendingHitConsequences pending,
            String event,
            String details) {
        trace(pending.hitId, event, pending.target, details);
    }

    private static void trace(int hitId, String event, Object target, String details) {
        int lineNumber = TRACE_LINE_COUNT.incrementAndGet();
        if (lineNumber > TRACE_LINE_LIMIT) {
            int dropped = TRACE_DROPPED_COUNT.incrementAndGet();
            if (dropped == 1) {
                log("diagnostic trace limit reached for session=" + TRACE_SESSION_ID
                        + "; further trace lines will be counted but suppressed");
            }
            return;
        }

        StringBuilder builder = new StringBuilder(384);
        builder.append("[MPRagdollPrototype][TRACE]")
                .append(" session=").append(TRACE_SESSION_ID)
                .append(" event=").append(event)
                .append(" hit=").append(hitId)
                .append(" thread=").append(safeToken(Thread.currentThread().getName()))
                .append(" target=").append(objectId(target));
        if (target != null) {
            builder.append(' ').append(characterSnapshot(target));
        }
        if (details != null && !details.isEmpty()) {
            builder.append(' ').append(details);
        }
        String line = builder.toString();
        writeTelemetryFile(line);
        if (!isHighVolumeTelemetryEvent(event)) {
            writeGameLog(line);
        }
    }

    private static boolean isHighVolumeTelemetryEvent(String event) {
        return "rigid-frame".equals(event)
                || "rigid-joints".equals(event)
                || "limb-follower-correction".equals(event);
    }

    private static void initializeTelemetryWriter() {
        synchronized (TELEMETRY_LOG_LOCK) {
            if (telemetryWriter != null || telemetryWriterFailed) {
                return;
            }
            try {
                Path cachePath = Utils.getCachePath();
                if (cachePath == null) {
                    String userHome = System.getProperty("user.home");
                    if (userHome == null || userHome.isEmpty()) {
                        throw new IOException("cache path unavailable");
                    }
                    cachePath = Paths.get(userHome).resolve("Zomboid");
                }
                Path directory = cachePath.resolve("Logs").resolve("MultiplayerRagdollPrototype");
                Files.createDirectories(directory);
                telemetryWriterFilename = "ragdoll-" + TRACE_SESSION_ID + ".log";
                Path telemetryPath = directory.resolve(telemetryWriterFilename);
                String header = "[MPRagdollPrototype] dedicated telemetry session="
                        + TRACE_SESSION_ID + " format=trace-v4 flush=critical-or-8-lines"
                        + System.lineSeparator();
                Files.writeString(
                        telemetryPath,
                        header,
                        StandardCharsets.UTF_8,
                        StandardOpenOption.CREATE,
                        StandardOpenOption.TRUNCATE_EXISTING,
                        StandardOpenOption.WRITE);
                telemetryWriter = Files.newBufferedWriter(
                        telemetryPath,
                        StandardCharsets.UTF_8,
                        StandardOpenOption.APPEND,
                        StandardOpenOption.WRITE);
                telemetryWriterFailure = "none";
                writeGameLog("[MPRagdollPrototype] dedicated telemetry ready: "
                        + telemetryWriterFilename);
                Runtime.getRuntime().addShutdownHook(new Thread(
                        PrototypeRuntime::closeTelemetryWriter,
                        "mpragdoll-telemetry-close"));
            } catch (IOException | RuntimeException exception) {
                telemetryWriterFailed = true;
                telemetryWriterFailure = exception.getClass().getSimpleName();
                telemetryWriter = null;
                writeGameLog("[MPRagdollPrototype] dedicated telemetry unavailable: "
                        + exception.getClass().getSimpleName());
            }
        }
    }

    private static void writeTelemetryFile(String message) {
        synchronized (TELEMETRY_LOG_LOCK) {
            if (telemetryWriter == null) {
                return;
            }
            try {
                telemetryWriter.write(message);
                telemetryWriter.newLine();
                telemetryLinesSinceFlush++;
                if (telemetryLinesSinceFlush >= 8
                        || message.contains("rigid-summary")
                        || message.contains("rigid-arm-snapshot")
                        || message.contains("rigid-arm-summary")
                        || message.contains("arm-profile-")) {
                    telemetryWriter.flush();
                    telemetryLinesSinceFlush = 0;
                }
            } catch (IOException exception) {
                telemetryWriterFailed = true;
                telemetryWriterFailure = exception.getClass().getSimpleName();
                closeTelemetryWriterLocked();
                writeGameLog("[MPRagdollPrototype] dedicated telemetry write failed: "
                        + telemetryWriterFailure);
            }
        }
    }

    private static void closeTelemetryWriter() {
        synchronized (TELEMETRY_LOG_LOCK) {
            closeTelemetryWriterLocked();
        }
    }

    private static void closeTelemetryWriterLocked() {
        if (telemetryWriter == null) {
            return;
        }
        try {
            telemetryWriter.flush();
            telemetryWriter.close();
        } catch (IOException ignored) {
        } finally {
            telemetryWriter = null;
            telemetryLinesSinceFlush = 0;
        }
    }

    private static void writeGameLog(String message) {
        try {
            Class<?> debugTypeClass = Class.forName(
                    "zombie.debug.DebugType",
                    false,
                    PrototypeRuntime.class.getClassLoader());
            Object general = debugTypeClass.getField("General").get(null);
            general.getClass().getMethod("println", String.class).invoke(general, message);
            return;
        } catch (ReflectiveOperationException | RuntimeException ignored) {
        }
        System.out.println(message);
    }

    private static String characterSnapshot(Object character) {
        Object health = callNoArgOrNull(character, "getHealth");
        Object currentState = callNoArgOrNull(character, "getCurrentState");
        return "health=" + (health instanceof Number ? health.toString() : "unknown")
                + " dead=" + formatNullableBoolean(callBooleanOrNull(character, "isDead"))
                + " onFloor=" + formatNullableBoolean(callBooleanOrNull(character, "isOnFloor"))
                + " gettingUp=" + formatNullableBoolean(callBooleanOrNull(character, "isGettingUp"))
                + " knockedDown=" + formatNullableBoolean(callBooleanOrNull(character, "isKnockedDown"))
                + " staggerBack=" + formatNullableBoolean(callBooleanOrNull(character, "isStaggerBack"))
                + " ragdollTrack=" + hasRagdollAnimationTrack(character)
                + " ragdollController=" + (callNoArgOrNull(character, "getRagdollController") != null)
                + " ragdollActive=" + isAnimationRagdollActive(character)
                + " actionState=" + safeStateName(callNoArgOrNull(character, "getActionStateName"))
                + " animationState=" + safeStateName(callNoArgOrNull(character, "getAnimationStateName"))
                + " state=" + safeClassName(currentState);
    }

    private static String objectId(Object value) {
        return value == null
                ? "null"
                : safeClassName(value) + "@" + Integer.toHexString(System.identityHashCode(value));
    }

    private static String safeClassName(Object value) {
        if (value == null) {
            return "null";
        }
        String name = value instanceof Throwable
                ? value.getClass().getSimpleName()
                : value.getClass().getName();
        return safeToken(name);
    }

    private static String safeToken(String value) {
        if (value == null || value.isEmpty()) {
            return "unknown";
        }
        return value.replace(' ', '_').replace('=', '_');
    }

    private static String formatNullableBoolean(Boolean value) {
        return value == null ? "unknown" : value.toString();
    }

    private static final class PendingHitConsequences {
        private final int hitId;
        private final Object target;
        private final Object weapon;
        private final boolean eligible;
        private final boolean ranged;
        private final String eligibilityReason;
        private final String weaponType;
        private final String wielderType;
        private final String hitReaction;
        private final float directionX;
        private final float directionY;
        private final float movementDirectionX;
        private final float movementDirectionY;
        private final float movementSpeed;
        private final String movementSource;
        private final boolean forceFallOnFront;
        private boolean lethalPrepared;
        private boolean transitionPrepared;
        private String previousActionState;
        private String previousAnimationState;
        private boolean previousFallOnFront;
        private String ragdollState;
        private int impulseBodyPart;
        private float impulseMagnitude;
        private float upwardImpulse;
        private int reactionBodyPart;
        private float reactionImpulse;
        private float movementImpulse;

        private PendingHitConsequences(
                int hitId,
                Object target,
                Object weapon,
                boolean eligible,
                boolean ranged,
                String eligibilityReason,
                String weaponType,
                String wielderType,
                String hitReaction,
                float directionX,
                float directionY,
                float movementDirectionX,
                float movementDirectionY,
                float movementSpeed,
                String movementSource) {
            this.hitId = hitId;
            this.target = target;
            this.weapon = weapon;
            this.eligible = eligible;
            this.ranged = ranged;
            this.eligibilityReason = eligibilityReason;
            this.weaponType = weaponType;
            this.wielderType = wielderType;
            this.hitReaction = hitReaction;
            this.directionX = directionX;
            this.directionY = directionY;
            this.movementDirectionX = movementDirectionX;
            this.movementDirectionY = movementDirectionY;
            this.movementSpeed = movementSpeed;
            this.movementSource = movementSource;
            this.forceFallOnFront = shouldForceFallOnFront(
                    ranged,
                    movementSpeed,
                    movementDirectionX,
                    movementDirectionY,
                    directionX,
                    directionY);
        }
    }

    private static final class ArmedZombie {
        private final long expiresAt;
        private final long startDeadlineNanos;
        private final int hitId;
        private final boolean ranged;
        private final int impulseBodyPart;
        private final float impulseMagnitude;
        private final float upwardImpulse;
        private final float directionX;
        private final float directionY;
        private final int reactionBodyPart;
        private final float reactionImpulse;
        private final float movementDirectionX;
        private final float movementDirectionY;
        private final float movementImpulse;
        private final float movementSpeed;
        private final String movementSource;
        private final boolean restrainedArmProfile;
        private final float[] bodyMasses;
        private final RigidBodyTelemetry rigidTelemetry;
        private volatile boolean simulationObserved;
        private volatile boolean startupDeferralLogged;
        private volatile boolean startupTimeoutLogged;
        private volatile boolean deathTimeoutDeferralLogged;
        private volatile boolean initialVelocitiesSuppressedLogged;
        private volatile boolean preSimulationMovementApplied;
        private volatile boolean initialImpulseQueued;
        private volatile boolean initialImpulseApplied;
        private volatile int initialImpulseValidFrame = -1;
        private volatile boolean dynamicsApplied;
        private volatile boolean assistStarted;
        private volatile boolean assistFinished;
        private volatile long assistDeadlineNanos;
        private volatile float pendingRigidFrameDeltaT = Float.NaN;
        private volatile int rigidUpdateSequence;
        private volatile int rigidCapturedUpdateSequence = -1;
        private volatile int rigidFallbackAttemptedUpdateSequence = -1;
        private volatile boolean rigidFallbackLogged;
        private volatile int rigidFallbackUnavailableLogs;
        private volatile boolean rigidFirstFrameDeferralLogged;
        private volatile int rigidInvalidFrameLogs;
        private volatile boolean rigidSummaryLogged;
        private volatile boolean momentumCorrectionAttempted;
        private final float[] followerImpulseByBody = new float[RigidBodyTelemetry.BODY_COUNT];
        private final float[] followerCorrection = new float[3];
        private volatile int motionSampleCount;
        private volatile boolean motionBaselineCaptured;
        private volatile float motionBaselinePelvisX = Float.NaN;
        private volatile float motionBaselinePelvisY = Float.NaN;
        private volatile float motionBaselineDesiredX = Float.NaN;
        private volatile float motionBaselineDesiredY = Float.NaN;
        private volatile float motionBaselineCharacterX = Float.NaN;
        private volatile float motionBaselineCharacterY = Float.NaN;
        private volatile String lastTraceSignature = "";

        private ArmedZombie(
                long expiresAt,
                long startDeadlineNanos,
                int hitId,
                boolean ranged,
                int impulseBodyPart,
                float impulseMagnitude,
                float upwardImpulse,
                float directionX,
                float directionY,
                int reactionBodyPart,
                float reactionImpulse,
                float movementDirectionX,
                float movementDirectionY,
                float movementImpulse,
                float movementSpeed,
                String movementSource) {
            this.expiresAt = expiresAt;
            this.startDeadlineNanos = startDeadlineNanos;
            this.hitId = hitId;
            this.ranged = ranged;
            this.impulseBodyPart = impulseBodyPart;
            this.impulseMagnitude = impulseMagnitude;
            this.upwardImpulse = upwardImpulse;
            this.directionX = directionX;
            this.directionY = directionY;
            this.reactionBodyPart = reactionBodyPart;
            this.reactionImpulse = reactionImpulse;
            this.movementDirectionX = movementDirectionX;
            this.movementDirectionY = movementDirectionY;
            this.movementImpulse = movementImpulse;
            this.movementSpeed = movementSpeed;
            this.movementSource = movementSource;
            this.restrainedArmProfile = qualityMode == QUALITY_RESTRAINED;
            this.bodyMasses = restrainedArmProfile
                    ? RESTRAINED_RAGDOLL_BODY_MASSES
                    : RAGDOLL_BODY_MASSES;
            this.rigidTelemetry = new RigidBodyTelemetry(
                    movementDirectionX,
                    movementDirectionY,
                    bodyMasses);
        }
    }

    private static final class TemplateSwap {
        private final Object ragdollController;
        private final Object character;
        private final ArmedZombie marker;

        private TemplateSwap(Object ragdollController, Object character, ArmedZombie marker) {
            this.ragdollController = ragdollController;
            this.character = character;
            this.marker = marker;
        }
    }

    private static final class MovementSnapshot {
        private final float directionX;
        private final float directionY;
        private final float speed;
        private final String source;
        private final float frameSeconds;
        private final float frameDisplacement;
        private final float reportedDisplacement;
        private final float historyAgeMillis;

        private MovementSnapshot(
                float directionX,
                float directionY,
                float speed,
                String source,
                float frameSeconds,
                float frameDisplacement,
                float reportedDisplacement,
                float historyAgeMillis) {
            this.directionX = directionX;
            this.directionY = directionY;
            this.speed = speed;
            this.source = source;
            this.frameSeconds = frameSeconds;
            this.frameDisplacement = frameDisplacement;
            this.reportedDisplacement = reportedDisplacement;
            this.historyAgeMillis = historyAgeMillis;
        }
    }

    private static final class MovementHistory {
        private float positionX;
        private float positionY;
        private long positionSampleNanos;
        private long lastObservedNanos;
        private float directionX;
        private float directionY;
        private float speed;
        private long movementSampleNanos;

        private MovementHistory(float positionX, float positionY, long nowNanos) {
            this.positionX = positionX;
            this.positionY = positionY;
            this.positionSampleNanos = nowNanos;
            this.lastObservedNanos = nowNanos;
        }
    }

    private static final class RagdollStateSnapshot {
        private final String actionState;
        private final String animationState;
        private final boolean ragdollTrack;
        private final boolean controllerPresent;
        private final boolean simulationActive;

        private RagdollStateSnapshot(
                String actionState,
                String animationState,
                boolean ragdollTrack,
                boolean controllerPresent,
                boolean simulationActive) {
            this.actionState = actionState;
            this.animationState = animationState;
            this.ragdollTrack = ragdollTrack;
            this.controllerPresent = controllerPresent;
            this.simulationActive = simulationActive;
        }

        private String signature() {
            return actionState + '|' + animationState + '|' + ragdollTrack + '|'
                    + controllerPresent + '|' + simulationActive;
        }

        private String details() {
            return "actionState=" + actionState
                    + " animationState=" + animationState
                    + " ragdollTrack=" + ragdollTrack
                    + " ragdollController=" + controllerPresent
                    + " ragdollActive=" + simulationActive;
        }
    }

    private static final class DeathPacketContext {
        private final Object packet;
        private final Object character;
        private final boolean armed;
        private final int hitId;

        private DeathPacketContext(Object packet, Object character, boolean armed, int hitId) {
            this.packet = packet;
            this.character = character;
            this.armed = armed;
            this.hitId = hitId;
        }
    }
}
