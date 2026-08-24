package pzmod.performance;

import java.io.BufferedWriter;
import java.io.File;
import java.io.IOException;
import java.lang.management.GarbageCollectorMXBean;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.ThreadMXBean;
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
import java.util.Arrays;
import java.util.HexFormat;
import java.util.IdentityHashMap;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

import me.zed_0xff.zombie_buddy.Accessor;
import me.zed_0xff.zombie_buddy.Utils;
import se.krka.kahlua.vm.LuaClosure;
import se.krka.kahlua.vm.Prototype;

public final class PerformanceDiagnosticsRuntime {
    static final String EXPECTED_GAME_JAR_SHA256 =
            "bda809fb49004a07dbfc560d059c0ee58d0643ab0f33b53351b13bd62f1d8227";
    static final double FRAME_SPIKE_MILLIS = 33.0;
    static final double SEVERE_FRAME_SPIKE_MILLIS = 75.0;
    static final double LUA_CALLBACK_MILLIS = 2.0;
    static final double CHUNK_MAIN_MILLIS = 3.0;
    static final double CHUNK_WORKER_MILLIS = 12.0;
    static final int LOG_LINE_LIMIT = 60_000;
    static final int LOG_QUEUE_CAPACITY = 8_192;
    static final long SUMMARY_INTERVAL_NANOS = 5_000_000_000L;
    static final long ATTEMPT_TTL_NANOS = 45_000_000_000L;

    private static final long SESSION_START_NANOS = System.nanoTime();
    private static final String SESSION_ID =
            Long.toHexString(System.currentTimeMillis())
                    + "-"
                    + Integer.toHexString(System.identityHashCode(PerformanceDiagnosticsRuntime.class));
    private static final ThreadMXBean THREADS = ManagementFactory.getThreadMXBean();
    private static final MemoryMXBean MEMORY = ManagementFactory.getMemoryMXBean();
    private static final RollingWindow UPDATE_WINDOW = new RollingWindow(512);
    private static final RollingWindow RENDER_WINDOW = new RollingWindow(512);
    private static final RollingWindow UPDATE_STUFF_WINDOW = new RollingWindow(512);
    private static final ThreadLocal<ArrayDeque<String>> LUA_EVENTS =
            ThreadLocal.withInitial(ArrayDeque::new);
    private static final IdentityHashMap<Object, Attempt> PLAYER_ATTEMPTS = new IdentityHashMap<>();
    private static final IdentityHashMap<Object, Attempt> VEHICLE_ATTEMPTS = new IdentityHashMap<>();
    private static final Map<String, Attempt> ATTEMPTS = new ConcurrentHashMap<>();
    private static final Object ATTEMPT_LOCK = new Object();
    private static final AtomicInteger FRAME_SPIKES = new AtomicInteger();
    private static final AtomicInteger LUA_SLOW_CALLBACKS = new AtomicInteger();
    private static final AtomicInteger CHUNKS_QUEUED = new AtomicInteger();
    private static final AtomicInteger CHUNK_OUTLIERS = new AtomicInteger();
    private static final AtomicInteger VEHICLE_EVENTS = new AtomicInteger();
    private static final AtomicLong FRAME_SEQUENCE = new AtomicLong();

    private static volatile boolean initialized;
    private static volatile boolean buildAccepted;
    private static volatile String state = "not initialized";
    private static volatile long lastSummaryNanos;
    private static volatile long lastRenderStartNanos;
    private static volatile long lastGcCount;
    private static volatile long lastGcMillis;
    private static volatile long lastChunkEventNanos;
    private static volatile String lastChunkEvent = "none";
    private static volatile String lastChunkCoordinates = "none";
    private static DiagnosticsLog diagnosticsLog;

    private PerformanceDiagnosticsRuntime() {}

    public static synchronized void initialize() {
        if (initialized) {
            return;
        }
        initialized = true;
        try {
            Path gameJar = locateGameJar();
            if (gameJar == null || !Files.isRegularFile(gameJar)) {
                disable("projectzomboid.jar could not be located");
                return;
            }
            String actualHash = sha256(gameJar);
            if (!EXPECTED_GAME_JAR_SHA256.equals(actualHash)) {
                disable("unsupported projectzomboid.jar SHA-256 " + actualHash);
                return;
            }
            if (THREADS.isCurrentThreadCpuTimeSupported() && !THREADS.isThreadCpuTimeEnabled()) {
                try {
                    THREADS.setThreadCpuTimeEnabled(true);
                } catch (SecurityException ignored) {
                    // CPU time is optional; wall timing remains available.
                }
            }
            diagnosticsLog = new DiagnosticsLog();
            diagnosticsLog.start();
            buildAccepted = true;
            state = "enabled for Project Zomboid 42.20.3 / Steam build 24775755";
            long[] gc = gcTotals();
            lastGcCount = gc[0];
            lastGcMillis = gc[1];
            event("session", "start",
                    "gameVersion", "42.20.3",
                    "steamBuild", "24775755",
                    "lineLimit", LOG_LINE_LIMIT,
                    "queueCapacity", LOG_QUEUE_CAPACITY,
                    "processors", Runtime.getRuntime().availableProcessors(),
                    "maxHeapBytes", Runtime.getRuntime().maxMemory(),
                    "client", isGameClient(),
                    "server", isGameServer(),
                    "logPath", diagnosticsLog.pathString());
            logGeneral(state + "; log=" + diagnosticsLog.pathString());
        } catch (Throwable throwable) {
            disable("initialization failed: " + throwable.getClass().getSimpleName()
                    + ": " + safeMessage(throwable));
        }
    }

    public static String status() {
        initialize();
        DiagnosticsLog log = diagnosticsLog;
        return "PZPerformanceDiagnostics " + state
                + "; session=" + SESSION_ID
                + "; log=" + (log == null ? "none" : log.pathString())
                + "; queued=" + (log == null ? 0 : log.queueSize())
                + "; lines=" + (log == null ? 0 : log.linesWritten())
                + "; dropped=" + (log == null ? 0 : log.linesDropped())
                + "; frameSpikes=" + FRAME_SPIKES.get()
                + "; slowLua=" + LUA_SLOW_CALLBACKS.get()
                + "; chunksQueued=" + CHUNKS_QUEUED.get()
                + "; chunkOutliers=" + CHUNK_OUTLIERS.get()
                + "; vehicleEvents=" + VEHICLE_EVENTS.get();
    }

    public static long currentThreadCpuTime() {
        if (!buildAccepted || !THREADS.isCurrentThreadCpuTimeSupported()
                || !THREADS.isThreadCpuTimeEnabled()) {
            return -1L;
        }
        return THREADS.getCurrentThreadCpuTime();
    }

    public static void recordGamePhase(
            String phase, long wallStart, long cpuStart, Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        long now = System.nanoTime();
        double wallMillis = millis(now - wallStart);
        long cpuEnd = currentThreadCpuTime();
        double cpuMillis = cpuStart >= 0L && cpuEnd >= cpuStart ? millis(cpuEnd - cpuStart) : -1.0;
        RollingWindow window = "render".equals(phase) ? RENDER_WINDOW : UPDATE_WINDOW;
        window.add(wallMillis);
        long frame = FRAME_SEQUENCE.incrementAndGet();
        double intervalMillis = -1.0;
        if ("render".equals(phase)) {
            long previous = lastRenderStartNanos;
            lastRenderStartNanos = wallStart;
            if (previous != 0L && wallStart >= previous) {
                intervalMillis = millis(wallStart - previous);
            }
        }
        long[] gc = gcTotals();
        long gcCountDelta = Math.max(0L, gc[0] - lastGcCount);
        long gcMillisDelta = Math.max(0L, gc[1] - lastGcMillis);
        lastGcCount = gc[0];
        lastGcMillis = gc[1];

        boolean spike = wallMillis >= FRAME_SPIKE_MILLIS
                || intervalMillis >= FRAME_SPIKE_MILLIS
                || thrown != null;
        if (spike) {
            FRAME_SPIKES.incrementAndGet();
            PlayerContext player = capturePlayerContext();
            long chunkAgeMillis = lastChunkEventNanos == 0L
                    ? -1L
                    : Math.max(0L, TimeUnit.NANOSECONDS.toMillis(now - lastChunkEventNanos));
            MemoryUsage heap = MEMORY.getHeapMemoryUsage();
            event("frame", phase + "-spike",
                    "frame", frame,
                    "wallMs", round(wallMillis),
                    "cpuMs", round(cpuMillis),
                    "intervalMs", round(intervalMillis),
                    "severity", wallMillis >= SEVERE_FRAME_SPIKE_MILLIS ? "severe" : "slow",
                    "gcCountDelta", gcCountDelta,
                    "gcMsDelta", gcMillisDelta,
                    "heapUsedBytes", heap.getUsed(),
                    "heapCommittedBytes", heap.getCommitted(),
                    "playerMode", player.mode,
                    "playerX", player.x,
                    "playerY", player.y,
                    "playerZ", player.z,
                    "playerChunk", player.chunk,
                    "vehicleId", player.vehicleId,
                    "vehicleScript", player.vehicleScript,
                    "vehicleSpeedKph", player.vehicleSpeed,
                    "nearestChunkEvent", lastChunkEvent,
                    "nearestChunk", lastChunkCoordinates,
                    "chunkEventAgeMs", chunkAgeMillis,
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
        if (now - lastSummaryNanos >= SUMMARY_INTERVAL_NANOS) {
            lastSummaryNanos = now;
            emitSummary(now);
        }
    }

    public static void recordSubsystem(
            String phase, Object owner, long wallStart, Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        if ("update-stuff".equals(phase)) {
            UPDATE_STUFF_WINDOW.add(elapsed);
        }
        double threshold = phase.startsWith("streamer") ? CHUNK_MAIN_MILLIS : 8.0;
        if (elapsed >= threshold || thrown != null) {
            event("subsystem", phase,
                    "durationMs", round(elapsed),
                    "thread", Thread.currentThread().getName(),
                    "queueSize", owner == null ? -1 : streamerQueueSize(owner),
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
    }

    public static void beforeProcessChunkPosition(Object chunkMap, Object character) {
        if (!enabled()) {
            return;
        }
        pruneAttempts(System.nanoTime());
    }

    public static void afterProcessChunkPosition(
            Object chunkMap, Object character, long wallStart, Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        if (elapsed >= CHUNK_MAIN_MILLIS || thrown != null) {
            CHUNK_OUTLIERS.incrementAndGet();
            String coordinates = chunkMapCoordinates(chunkMap);
            noteChunkEvent("process-position", coordinates);
            event("chunk", "process-position",
                    "durationMs", round(elapsed),
                    "chunkMap", coordinates,
                    "character", safeClassName(character),
                    "characterX", callDouble(character, "getX", -1.0),
                    "characterY", callDouble(character, "getY", -1.0),
                    "queueSize", chunkIntegrationQueueSize(),
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
    }

    public static int chunkIntegrationQueueSize() {
        try {
            Class<?> chunkClass = Class.forName("zombie.iso.IsoChunk");
            Field field = chunkClass.getField("loadGridSquare");
            return collectionSize(field.get(null));
        } catch (Throwable ignored) {
            return -1;
        }
    }

    public static void recordChunkMapUpdate(
            Object chunkMap, long wallStart, int queueBefore, Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        int queueAfter = chunkIntegrationQueueSize();
        if (elapsed >= CHUNK_MAIN_MILLIS || queueBefore > 0 || thrown != null) {
            if (elapsed >= CHUNK_MAIN_MILLIS || thrown != null) {
                CHUNK_OUTLIERS.incrementAndGet();
            }
            String coordinates = chunkMapCoordinates(chunkMap);
            noteChunkEvent("chunk-map-update", coordinates);
            event("chunk", "chunk-map-update",
                    "durationMs", round(elapsed),
                    "chunkMap", coordinates,
                    "queueBefore", queueBefore,
                    "queueAfter", queueAfter,
                    "integratedEstimate", queueBefore >= 0 && queueAfter >= 0
                            ? Math.max(0, queueBefore - queueAfter) : -1,
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
    }

    public static void chunkQueued(
            Object streamer, Object chunk, int wx, int wy, boolean serverRequest) {
        if (!enabled()) {
            return;
        }
        CHUNKS_QUEUED.incrementAndGet();
    }

    public static void recordChunkPhase(
            String phase, Object chunk, String source, long wallStart, Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        double threshold = phase.startsWith("main") ? CHUNK_MAIN_MILLIS : CHUNK_WORKER_MILLIS;
        if (elapsed >= threshold || thrown != null) {
            CHUNK_OUTLIERS.incrementAndGet();
            String coordinates = chunkCoordinates(chunk);
            noteChunkEvent(phase, coordinates);
            event("chunk", phase,
                    "chunk", coordinates,
                    "durationMs", round(elapsed),
                    "source", source == null ? "unknown" : source,
                    "thread", Thread.currentThread().getName(),
                    "loaded", readBoolean(chunk, "loaded", false),
                    "blam", readBoolean(chunk, "blam", false),
                    "jobType", safeValue(Accessor.tryGet(chunk, "jobType", null)),
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
    }

    public static void recordChunkLoad(
            Object chunk,
            int wx,
            int wy,
            Object fromServer,
            long wallStart,
            Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        if (elapsed >= CHUNK_WORKER_MILLIS || thrown != null || readBoolean(chunk, "blam", false)) {
            CHUNK_OUTLIERS.incrementAndGet();
            String coordinates = wx + "," + wy;
            noteChunkEvent("load-chunk", coordinates);
            event("chunk", "load-chunk",
                    "chunk", coordinates,
                    "durationMs", round(elapsed),
                    "source", fromServer == null ? "disk-or-new" : "server",
                    "thread", Thread.currentThread().getName(),
                    "loaded", readBoolean(chunk, "loaded", false),
                    "blam", readBoolean(chunk, "blam", false),
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
    }

    public static String classifyChunkSource(int wx, int wy, Object fromServer) {
        if (fromServer != null) {
            return "server";
        }
        try {
            Class<?> filenamesClass = Class.forName("zombie.ChunkMapFilenames");
            Object instance = filenamesClass.getField("instance").get(null);
            Object file = filenamesClass.getMethod("getFilename", int.class, int.class)
                    .invoke(instance, wx, wy);
            if (file instanceof File path && path.exists()) {
                return "disk";
            }
        } catch (Throwable ignored) {
            return "disk-or-new";
        }
        return "brand-new";
    }

    public static void recordChunkLoadOrCreate(
            Object chunk,
            int wx,
            int wy,
            String source,
            boolean loaded,
            long wallStart,
            Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        boolean blam = readBoolean(chunk, "blam", false);
        if (elapsed >= CHUNK_WORKER_MILLIS || !loaded || blam || thrown != null) {
            CHUNK_OUTLIERS.incrementAndGet();
            String coordinates = wx + "," + wy;
            noteChunkEvent("load-or-create", coordinates);
            event("chunk", "load-or-create",
                    "chunk", coordinates,
                    "durationMs", round(elapsed),
                    "source", source == null ? "unknown" : source,
                    "loaded", loaded,
                    "blam", blam,
                    "thread", Thread.currentThread().getName(),
                    "error", thrown == null ? "none" : throwableDescription(thrown));
        }
    }

    public static void enterLuaEvent(String eventName) {
        if (!enabled()) {
            return;
        }
        LUA_EVENTS.get().push(eventName == null ? "unknown" : eventName);
    }

    public static void exitLuaEvent(String eventName, Throwable thrown) {
        if (!enabled()) {
            return;
        }
        ArrayDeque<String> events = LUA_EVENTS.get();
        if (!events.isEmpty()) {
            events.pop();
        }
        if (thrown != null) {
            event("lua", "event-error",
                    "eventName", eventName,
                    "error", throwableDescription(thrown));
        }
    }

    public static boolean shouldTimeLuaCallback(Object function) {
        if (!enabled() || !(function instanceof LuaClosure)) {
            return false;
        }
        return !LUA_EVENTS.get().isEmpty();
    }

    public static void recordLuaCallback(Object function, long wallStart, Throwable thrown) {
        if (!enabled() || wallStart == 0L || !(function instanceof LuaClosure closure)) {
            return;
        }
        double elapsed = millis(System.nanoTime() - wallStart);
        if (elapsed < LUA_CALLBACK_MILLIS && thrown == null) {
            return;
        }
        LUA_SLOW_CALLBACKS.incrementAndGet();
        ArrayDeque<String> events = LUA_EVENTS.get();
        String eventName = events.isEmpty() ? "unknown" : events.peek();
        Prototype prototype = closure.prototype;
        String filename = prototype == null ? "unknown" : safeValue(prototype.filename);
        String name = prototype == null ? "unknown" : safeValue(prototype.name);
        int line = prototype == null || prototype.lines == null || prototype.lines.length == 0
                ? -1 : prototype.lines[0];
        event("lua", "slow-callback",
                "eventName", eventName,
                "durationMs", round(elapsed),
                "file", filename,
                "function", name,
                "line", line,
                "error", thrown == null ? "none" : throwableDescription(thrown));
    }

    public static void callbackInventory(
            String eventName, String filename, String functionName, int line) {
        if (!enabled()) {
            return;
        }
        event("lua", "callback-registered",
                "eventName", eventName,
                "file", filename,
                "function", functionName,
                "line", line);
    }

    public static void vehicleEvent(
            String attemptId,
            String stage,
            Object character,
            Object vehicle,
            int seat,
            String action,
            String details) {
        if (!enabled()) {
            return;
        }
        long now = System.nanoTime();
        Attempt attempt;
        synchronized (ATTEMPT_LOCK) {
            pruneAttemptsLocked(now);
            attempt = ATTEMPTS.computeIfAbsent(
                    safeValue(attemptId), id -> new Attempt(id, now));
            attempt.lastNanos = now;
            if (character != null) {
                attempt.character = character;
                PLAYER_ATTEMPTS.put(character, attempt);
            }
            if (vehicle != null) {
                attempt.vehicle = vehicle;
                VEHICLE_ATTEMPTS.put(vehicle, attempt);
            }
            if (seat >= 0) {
                attempt.seat = seat;
            }
        }
        VEHICLE_EVENTS.incrementAndGet();
        event("vehicle", stage,
                "attempt", attempt.id,
                "elapsedMs", round(millis(now - attempt.startedNanos)),
                "action", action,
                "details", details,
                "seat", attempt.seat,
                "vehicleId", vehicleId(vehicle),
                "vehicleScript", vehicleScript(vehicle),
                "vehicleSpeedKph", round(callDouble(vehicle, "getCurrentSpeedKmHour", -1.0)),
                "characterVehicle", callNoArg(character, "getVehicle") != null,
                "bEnteringVehicle", callString(character, "GetVariable", "bEnteringVehicle"),
                "enterAnimationFinished", callString(character, "GetVariable", "EnterAnimationFinished"));
    }

    public static void baseVehicleEnter(
            Object vehicle,
            Object character,
            int seat,
            boolean entered,
            long wallStart,
            Throwable thrown) {
        if (!enabled() || wallStart == 0L) {
            return;
        }
        Attempt attempt = findAttempt(character, vehicle);
        event("vehicle", "base-enter",
                "attempt", attempt == null ? "unmatched" : attempt.id,
                "durationMs", round(millis(System.nanoTime() - wallStart)),
                "entered", entered,
                "seat", seat,
                "vehicleId", vehicleId(vehicle),
                "vehicleScript", vehicleScript(vehicle),
                "error", thrown == null ? "none" : throwableDescription(thrown));
    }

    public static void vehicleAnimation(
            String eventName,
            Object vehicle,
            Object part,
            int seat,
            String animation) {
        if (!enabled()) {
            return;
        }
        Attempt attempt = findAttempt(null, vehicle);
        if (attempt == null) {
            return;
        }
        event("vehicle", eventName,
                "attempt", attempt.id,
                "elapsedMs", round(millis(System.nanoTime() - attempt.startedNanos)),
                "vehicleId", vehicleId(vehicle),
                "vehicleScript", vehicleScript(vehicle),
                "part", safePartId(part),
                "seat", seat,
                "animation", animation);
    }

    public static void manualMarker(String label) {
        if (!enabled()) {
            return;
        }
        PlayerContext player = capturePlayerContext();
        event("marker", "manual",
                "label", label,
                "playerMode", player.mode,
                "playerX", player.x,
                "playerY", player.y,
                "playerZ", player.z,
                "playerChunk", player.chunk,
                "vehicleId", player.vehicleId,
                "vehicleScript", player.vehicleScript,
                "vehicleSpeedKph", player.vehicleSpeed);
    }

    private static boolean enabled() {
        if (!initialized) {
            initialize();
        }
        return buildAccepted && isGameClient() && !isGameServer();
    }

    private static void emitSummary(long now) {
        PlayerContext player = capturePlayerContext();
        MemoryUsage heap = MEMORY.getHeapMemoryUsage();
        event("summary", "window",
                "update", UPDATE_WINDOW.summary(),
                "render", RENDER_WINDOW.summary(),
                "updateStuff", UPDATE_STUFF_WINDOW.summary(),
                "heapUsedBytes", heap.getUsed(),
                "heapCommittedBytes", heap.getCommitted(),
                "integrationQueue", chunkIntegrationQueueSize(),
                "playerMode", player.mode,
                "playerChunk", player.chunk,
                "vehicleSpeedKph", player.vehicleSpeed,
                "frameSpikes", FRAME_SPIKES.get(),
                "slowLua", LUA_SLOW_CALLBACKS.get(),
                "chunksQueued", CHUNKS_QUEUED.get(),
                "chunkOutliers", CHUNK_OUTLIERS.get(),
                "vehicleEvents", VEHICLE_EVENTS.get());
    }

    private static void noteChunkEvent(String eventName, String coordinates) {
        lastChunkEventNanos = System.nanoTime();
        lastChunkEvent = eventName;
        lastChunkCoordinates = coordinates;
    }

    private static Attempt findAttempt(Object character, Object vehicle) {
        synchronized (ATTEMPT_LOCK) {
            pruneAttemptsLocked(System.nanoTime());
            Attempt attempt = character == null ? null : PLAYER_ATTEMPTS.get(character);
            if (attempt == null && vehicle != null) {
                attempt = VEHICLE_ATTEMPTS.get(vehicle);
            }
            return attempt;
        }
    }

    private static void pruneAttempts(long now) {
        synchronized (ATTEMPT_LOCK) {
            pruneAttemptsLocked(now);
        }
    }

    private static void pruneAttemptsLocked(long now) {
        ATTEMPTS.values().removeIf(attempt -> {
            boolean expired = now - attempt.lastNanos > ATTEMPT_TTL_NANOS;
            if (expired) {
                if (attempt.character != null && PLAYER_ATTEMPTS.get(attempt.character) == attempt) {
                    PLAYER_ATTEMPTS.remove(attempt.character);
                }
                if (attempt.vehicle != null && VEHICLE_ATTEMPTS.get(attempt.vehicle) == attempt) {
                    VEHICLE_ATTEMPTS.remove(attempt.vehicle);
                }
            }
            return expired;
        });
    }

    private static PlayerContext capturePlayerContext() {
        try {
            Class<?> playerClass = Class.forName("zombie.characters.IsoPlayer");
            Object player = playerClass.getMethod("getInstance").invoke(null);
            if (player == null) {
                return PlayerContext.NONE;
            }
            double x = callDouble(player, "getX", -1.0);
            double y = callDouble(player, "getY", -1.0);
            double z = callDouble(player, "getZ", -1.0);
            Object vehicle = callNoArg(player, "getVehicle");
            String mode = vehicle == null ? movementMode(player) : "vehicle";
            return new PlayerContext(
                    mode,
                    round(x),
                    round(y),
                    round(z),
                    ((int)Math.floor(x / 8.0)) + "," + ((int)Math.floor(y / 8.0)),
                    vehicleId(vehicle),
                    vehicleScript(vehicle),
                    round(callDouble(vehicle, "getCurrentSpeedKmHour", 0.0)));
        } catch (Throwable ignored) {
            return PlayerContext.NONE;
        }
    }

    private static String movementMode(Object player) {
        if (callBoolean(player, "isSprinting", false)) {
            return "sprinting";
        }
        if (callBoolean(player, "isRunning", false)) {
            return "running";
        }
        if (callBoolean(player, "isWalking", false)) {
            return "walking";
        }
        return "stationary";
    }

    private static int streamerQueueSize(Object streamer) {
        int total = 0;
        boolean found = false;
        for (String name : new String[]{
                "jobQueue", "jobList", "chunkRequests0", "chunkRequests1",
                "mainThreadRequestQueue", "sentRequests", "pendingRequests", "pendingRequests1"}) {
            Object value = Accessor.tryGet(streamer, name, null);
            int size = collectionSize(value);
            if (size >= 0) {
                total += size;
                found = true;
            }
        }
        return found ? total : -1;
    }

    private static int collectionSize(Object value) {
        if (value == null) {
            return -1;
        }
        try {
            Object result = value.getClass().getMethod("size").invoke(value);
            return result instanceof Number number ? number.intValue() : -1;
        } catch (Throwable ignored) {
            return -1;
        }
    }

    private static String chunkCoordinates(Object chunk) {
        if (chunk == null) {
            return "none";
        }
        return readInt(chunk, "wx", -1) + "," + readInt(chunk, "wy", -1);
    }

    private static String chunkMapCoordinates(Object chunkMap) {
        if (chunkMap == null) {
            return "none";
        }
        return readInt(chunkMap, "worldX", -1) + "," + readInt(chunkMap, "worldY", -1);
    }

    private static int vehicleId(Object vehicle) {
        return vehicle == null ? -1 : (int)callDouble(vehicle, "getId", -1.0);
    }

    private static String vehicleScript(Object vehicle) {
        Object script = callNoArg(vehicle, "getScript");
        if (script == null) {
            return "none";
        }
        Object fullName = callNoArg(script, "getFullName");
        if (fullName == null) {
            fullName = callNoArg(script, "getName");
        }
        return safeValue(fullName);
    }

    private static String safePartId(Object part) {
        Object id = callNoArg(part, "getId");
        return id == null ? "none" : safeValue(id);
    }

    private static long[] gcTotals() {
        long count = 0L;
        long millis = 0L;
        for (GarbageCollectorMXBean bean : ManagementFactory.getGarbageCollectorMXBeans()) {
            if (bean.getCollectionCount() >= 0L) {
                count += bean.getCollectionCount();
            }
            if (bean.getCollectionTime() >= 0L) {
                millis += bean.getCollectionTime();
            }
        }
        return new long[]{count, millis};
    }

    private static void event(String category, String eventName, Object... fields) {
        DiagnosticsLog log = diagnosticsLog;
        if (!buildAccepted || log == null) {
            return;
        }
        log.offer(jsonLine(category, eventName, fields));
    }

    static String jsonLine(String category, String eventName, Object... fields) {
        StringBuilder line = new StringBuilder(256);
        line.append('{');
        appendJsonField(line, "session", SESSION_ID, false);
        appendJsonField(line, "elapsedMs", round(millis(System.nanoTime() - SESSION_START_NANOS)), true);
        appendJsonField(line, "category", category, true);
        appendJsonField(line, "event", eventName, true);
        appendJsonField(line, "thread", Thread.currentThread().getName(), true);
        for (int i = 0; i + 1 < fields.length; i += 2) {
            appendJsonField(line, safeValue(fields[i]), fields[i + 1], true);
        }
        line.append('}');
        return line.toString();
    }

    private static void appendJsonField(
            StringBuilder target, String key, Object value, boolean comma) {
        if (comma) {
            target.append(',');
        }
        target.append('"').append(jsonEscape(key)).append("\":");
        if (value == null) {
            target.append("null");
        } else if (value instanceof Number || value instanceof Boolean) {
            target.append(value);
        } else {
            target.append('"').append(jsonEscape(safeValue(value))).append('"');
        }
    }

    static String jsonEscape(String value) {
        StringBuilder escaped = new StringBuilder(value.length() + 16);
        for (int i = 0; i < value.length(); ++i) {
            char ch = value.charAt(i);
            switch (ch) {
                case '\\' -> escaped.append("\\\\");
                case '"' -> escaped.append("\\\"");
                case '\n' -> escaped.append("\\n");
                case '\r' -> escaped.append("\\r");
                case '\t' -> escaped.append("\\t");
                default -> {
                    if (ch < 0x20) {
                        escaped.append(String.format("\\u%04x", (int)ch));
                    } else {
                        escaped.append(ch);
                    }
                }
            }
        }
        return escaped.toString();
    }

    private static Object callNoArg(Object target, String methodName) {
        if (target == null) {
            return null;
        }
        try {
            return target.getClass().getMethod(methodName).invoke(target);
        } catch (Throwable ignored) {
            return null;
        }
    }

    private static boolean callBoolean(Object target, String methodName, boolean fallback) {
        Object value = callNoArg(target, methodName);
        return value instanceof Boolean bool ? bool : fallback;
    }

    private static double callDouble(Object target, String methodName, double fallback) {
        Object value = callNoArg(target, methodName);
        return value instanceof Number number ? number.doubleValue() : fallback;
    }

    private static String callString(Object target, String methodName, String argument) {
        if (target == null) {
            return "none";
        }
        try {
            Object value = target.getClass().getMethod(methodName, String.class).invoke(target, argument);
            return safeValue(value);
        } catch (Throwable ignored) {
            return "unavailable";
        }
    }

    private static int readInt(Object target, String fieldName, int fallback) {
        Object value = Accessor.tryGet(target, fieldName, null);
        return value instanceof Number number ? number.intValue() : fallback;
    }

    private static boolean readBoolean(Object target, String fieldName, boolean fallback) {
        Object value = Accessor.tryGet(target, fieldName, null);
        return value instanceof Boolean bool ? bool : fallback;
    }

    private static String safeClassName(Object value) {
        return value == null ? "none" : value.getClass().getName();
    }

    private static String safeValue(Object value) {
        if (value == null) {
            return "none";
        }
        try {
            return String.valueOf(value);
        } catch (Throwable ignored) {
            return value.getClass().getName();
        }
    }

    private static String throwableDescription(Throwable throwable) {
        return throwable.getClass().getName() + ":" + safeMessage(throwable);
    }

    private static String safeMessage(Throwable throwable) {
        String message = throwable.getMessage();
        return message == null ? "no-message" : message;
    }

    private static double millis(long nanos) {
        return nanos / 1_000_000.0;
    }

    private static double round(double value) {
        if (!Double.isFinite(value)) {
            return -1.0;
        }
        return Math.round(value * 1000.0) / 1000.0;
    }

    private static void disable(String reason) {
        buildAccepted = false;
        state = "disabled: " + reason;
        logGeneral(state);
    }

    private static void logGeneral(String message) {
        String line = "[PZPerformanceDiagnostics] " + message;
        try {
            Class<?> debugType = Class.forName(
                    "zombie.debug.DebugType",
                    false,
                    PerformanceDiagnosticsRuntime.class.getClassLoader());
            Object general = debugType.getField("General").get(null);
            general.getClass().getMethod("println", String.class).invoke(general, line);
            return;
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            // Fall back to stdout when the exact debug logger API is unavailable.
        }
        System.out.println(line);
    }

    private static boolean isGameClient() {
        return readStaticBoolean("zombie.network.GameClient", "client");
    }

    private static boolean isGameServer() {
        return readStaticBoolean("zombie.network.GameServer", "server");
    }

    private static boolean readStaticBoolean(String className, String fieldName) {
        try {
            return Class.forName(className).getField(fieldName).getBoolean(null);
        } catch (Throwable ignored) {
            return false;
        }
    }

    private static Path locateGameJar() {
        try {
            URL location = Class.forName("zombie.GameWindow")
                    .getProtectionDomain().getCodeSource().getLocation();
            if (location != null) {
                URI uri = location.toURI();
                Path path = Paths.get(uri);
                if (Files.isRegularFile(path) && path.getFileName().toString().equalsIgnoreCase("projectzomboid.jar")) {
                    return path;
                }
                Path sibling = path.resolve("projectzomboid.jar");
                if (Files.isRegularFile(sibling)) {
                    return sibling;
                }
            }
        } catch (Throwable ignored) {
            // Fall through to the working-directory check used by the normal launcher.
        }
        Path workingDirectoryJar = Paths.get(System.getProperty("user.dir", "."), "projectzomboid.jar");
        return Files.isRegularFile(workingDirectoryJar) ? workingDirectoryJar : null;
    }

    private static String sha256(Path path) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (var input = Files.newInputStream(path)) {
            byte[] buffer = new byte[64 * 1024];
            int read;
            while ((read = input.read(buffer)) >= 0) {
                if (read > 0) {
                    digest.update(buffer, 0, read);
                }
            }
        }
        return HexFormat.of().formatHex(digest.digest());
    }

    static final class RollingWindow {
        private final double[] values;
        private int count;
        private int next;

        RollingWindow(int capacity) {
            values = new double[capacity];
        }

        synchronized void add(double value) {
            values[next] = value;
            next = (next + 1) % values.length;
            if (count < values.length) {
                ++count;
            }
        }

        synchronized String summary() {
            if (count == 0) {
                return "count=0";
            }
            double[] snapshot = new double[count];
            double total = 0.0;
            double maximum = 0.0;
            for (int i = 0; i < count; ++i) {
                snapshot[i] = values[i];
                total += snapshot[i];
                maximum = Math.max(maximum, snapshot[i]);
            }
            Arrays.sort(snapshot);
            return "count=" + count
                    + ",avgMs=" + round(total / count)
                    + ",p95Ms=" + round(percentile(snapshot, 0.95))
                    + ",p99Ms=" + round(percentile(snapshot, 0.99))
                    + ",maxMs=" + round(maximum);
        }

        private static double percentile(double[] sorted, double percentile) {
            int index = (int)Math.ceil(percentile * sorted.length) - 1;
            return sorted[Math.max(0, Math.min(sorted.length - 1, index))];
        }
    }

    static final class DiagnosticsLog {
        private static final String POISON = new String("PZPERF-POISON");
        private final ArrayBlockingQueue<String> queue =
                new ArrayBlockingQueue<>(LOG_QUEUE_CAPACITY);
        private final AtomicInteger accepted = new AtomicInteger();
        private final AtomicInteger written = new AtomicInteger();
        private final AtomicInteger dropped = new AtomicInteger();
        private volatile String failure = "none";
        private Path path;
        private Thread thread;

        void start() throws IOException {
            Path cachePath = Utils.getCachePath();
            if (cachePath == null) {
                String userHome = System.getProperty("user.home");
                if (userHome == null || userHome.isEmpty()) {
                    throw new IOException("cache path unavailable");
                }
                cachePath = Paths.get(userHome).resolve("Zomboid");
            }
            Path root = cachePath.resolve("Logs").resolve("PZPerformanceDiagnostics");
            Files.createDirectories(root);
            path = root.resolve("perf-" + SESSION_ID + ".jsonl");
            thread = new Thread(this::writerLoop, "PZ Performance Diagnostics Writer");
            thread.setDaemon(true);
            thread.start();
            Runtime.getRuntime().addShutdownHook(new Thread(this::close, "PZ Performance Diagnostics Shutdown"));
        }

        void offer(String line) {
            int current = accepted.incrementAndGet();
            if (current > LOG_LINE_LIMIT || !queue.offer(line)) {
                dropped.incrementAndGet();
            }
        }

        int queueSize() {
            return queue.size();
        }

        int linesWritten() {
            return written.get();
        }

        int linesDropped() {
            return dropped.get();
        }

        String pathString() {
            return path == null ? "none" : path.toString();
        }

        private void writerLoop() {
            try (BufferedWriter writer = Files.newBufferedWriter(
                    path,
                    StandardCharsets.UTF_8,
                    StandardOpenOption.CREATE_NEW,
                    StandardOpenOption.WRITE)) {
                int sinceFlush = 0;
                long lastFlush = System.nanoTime();
                while (true) {
                    String line = queue.poll(500L, TimeUnit.MILLISECONDS);
                    if (line == POISON) {
                        break;
                    }
                    if (line != null) {
                        writer.write(line);
                        writer.newLine();
                        written.incrementAndGet();
                        ++sinceFlush;
                    }
                    long now = System.nanoTime();
                    if (sinceFlush >= 32 || now - lastFlush >= 1_000_000_000L) {
                        writer.flush();
                        sinceFlush = 0;
                        lastFlush = now;
                    }
                }
                String line;
                while ((line = queue.poll()) != null) {
                    writer.write(line);
                    writer.newLine();
                    written.incrementAndGet();
                }
                writer.flush();
            } catch (Throwable throwable) {
                failure = throwableDescription(throwable);
                System.err.println("[PZPerformanceDiagnostics] writer failed: " + failure);
            }
        }

        void close() {
            Thread current = thread;
            if (current == null || !current.isAlive()) {
                return;
            }
            queue.offer(POISON);
            try {
                current.join(2_000L);
            } catch (InterruptedException interrupted) {
                Thread.currentThread().interrupt();
            }
        }
    }

    private static final class Attempt {
        final String id;
        final long startedNanos;
        long lastNanos;
        Object character;
        Object vehicle;
        int seat = -1;

        Attempt(String id, long now) {
            this.id = id;
            this.startedNanos = now;
            this.lastNanos = now;
        }
    }

    private record PlayerContext(
            String mode,
            double x,
            double y,
            double z,
            String chunk,
            int vehicleId,
            String vehicleScript,
            double vehicleSpeed) {
        static final PlayerContext NONE =
                new PlayerContext("none", -1.0, -1.0, -1.0, "none", -1, "none", 0.0);
    }
}
