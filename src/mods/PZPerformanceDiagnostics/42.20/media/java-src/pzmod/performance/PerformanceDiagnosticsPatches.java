package pzmod.performance;

import me.zed_0xff.zombie_buddy.Patch;

public final class PerformanceDiagnosticsPatches {
    private PerformanceDiagnosticsPatches() {}

    @Patch(className = "zombie.gameStates.IngameState", methodName = "update", strictMatch = true)
    public static final class IngameUpdate {
        @Patch.OnEnter
        public static void enter(
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("cpuStart") long cpuStart) {
            wallStart = System.nanoTime();
            cpuStart = PerformanceDiagnosticsRuntime.currentThreadCpuTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("cpuStart") long cpuStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordGamePhase("update", wallStart, cpuStart, thrown);
        }
    }

    @Patch(className = "zombie.gameStates.IngameState", methodName = "render", strictMatch = true)
    public static final class IngameRender {
        @Patch.OnEnter
        public static void enter(
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("cpuStart") long cpuStart) {
            wallStart = System.nanoTime();
            cpuStart = PerformanceDiagnosticsRuntime.currentThreadCpuTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("cpuStart") long cpuStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordGamePhase("render", wallStart, cpuStart, thrown);
        }
    }

    @Patch(className = "zombie.gameStates.IngameState", methodName = "UpdateStuff", strictMatch = true)
    public static final class IngameUpdateStuff {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordSubsystem("update-stuff", null, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.IsoChunkMap", methodName = "ProcessChunkPos")
    public static final class ProcessChunkPos {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object chunkMap,
                @Patch.Argument(0) Object character,
                @Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
            PerformanceDiagnosticsRuntime.beforeProcessChunkPosition(chunkMap, character);
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object chunkMap,
                @Patch.Argument(0) Object character,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.afterProcessChunkPosition(
                    chunkMap, character, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.IsoChunkMap", methodName = "update", strictMatch = true)
    public static final class ChunkMapUpdate {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object chunkMap,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("queueBefore") int queueBefore) {
            wallStart = System.nanoTime();
            queueBefore = PerformanceDiagnosticsRuntime.chunkIntegrationQueueSize();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object chunkMap,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("queueBefore") int queueBefore,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordChunkMapUpdate(
                    chunkMap, wallStart, queueBefore, thrown);
        }
    }

    @Patch(className = "zombie.iso.IsoChunk", methodName = "doLoadGridsquare", strictMatch = true)
    public static final class ChunkGridSquareIntegration {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object chunk,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordChunkPhase(
                    "main-integrate", chunk, null, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.WorldStreamer", methodName = "addJob")
    public static final class WorldStreamerAddJob {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object streamer,
                @Patch.Argument(0) Object chunk,
                @Patch.Argument(1) int wx,
                @Patch.Argument(2) int wy,
                @Patch.Argument(3) boolean serverRequest) {
            PerformanceDiagnosticsRuntime.chunkQueued(streamer, chunk, wx, wy, serverRequest);
        }
    }

    @Patch(className = "zombie.iso.WorldStreamer", methodName = "updateMain", strictMatch = true)
    public static final class WorldStreamerUpdateMain {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object streamer,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordSubsystem(
                    "streamer-main", streamer, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.WorldStreamer", methodName = "DoChunkAlways")
    public static final class WorldStreamerDoChunk {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.Argument(0) Object chunk,
                @Patch.Argument(1) Object fromServer,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordChunkPhase(
                    "worker-total", chunk, fromServer == null ? "disk-or-new" : "server", wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.IsoChunk", methodName = "LoadChunk")
    public static final class ChunkLoad {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object chunk,
                @Patch.Argument(0) int wx,
                @Patch.Argument(1) int wy,
                @Patch.Argument(2) Object fromServer,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordChunkLoad(
                    chunk, wx, wy, fromServer, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.IsoChunk", methodName = "LoadOrCreate")
    public static final class ChunkLoadOrCreate {
        @Patch.OnEnter
        public static void enter(
                @Patch.Argument(0) int wx,
                @Patch.Argument(1) int wy,
                @Patch.Argument(2) Object fromServer,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("source") String source) {
            wallStart = System.nanoTime();
            source = PerformanceDiagnosticsRuntime.classifyChunkSource(wx, wy, fromServer);
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object chunk,
                @Patch.Argument(0) int wx,
                @Patch.Argument(1) int wy,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Local("source") String source,
                @Patch.Return boolean loaded,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordChunkLoadOrCreate(
                    chunk, wx, wy, source, loaded, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.iso.IsoChunk", methodName = "loadInWorldStreamerThread", strictMatch = true)
    public static final class ChunkWorkerPostprocess {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object chunk,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.recordChunkPhase(
                    "worker-postprocess", chunk, null, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.vehicles.BaseVehicle", methodName = "enter")
    public static final class BaseVehicleEnter {
        @Patch.OnEnter
        public static void enter(@Patch.Local("wallStart") long wallStart) {
            wallStart = System.nanoTime();
        }

        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This Object vehicle,
                @Patch.Argument(0) int seat,
                @Patch.Argument(1) Object character,
                @Patch.Local("wallStart") long wallStart,
                @Patch.Return boolean entered,
                @Patch.Thrown Throwable thrown) {
            PerformanceDiagnosticsRuntime.baseVehicleEnter(
                    vehicle, character, seat, entered, wallStart, thrown);
        }
    }

    @Patch(className = "zombie.vehicles.BaseVehicle", methodName = "playPassengerAnim")
    public static final class PassengerAnimation {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object vehicle,
                @Patch.Argument(0) int seat,
                @Patch.Argument(1) String animation) {
            PerformanceDiagnosticsRuntime.vehicleAnimation(
                    "passenger-animation", vehicle, null, seat, animation);
        }
    }

    @Patch(className = "zombie.vehicles.BaseVehicle", methodName = "playPartAnim")
    public static final class PartAnimation {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Object vehicle,
                @Patch.Argument(0) Object part,
                @Patch.Argument(1) String animation) {
            PerformanceDiagnosticsRuntime.vehicleAnimation(
                    "part-animation", vehicle, part, -1, animation);
        }
    }

}
