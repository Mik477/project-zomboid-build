package pzmod.performance;

import se.krka.kahlua.integration.annotations.LuaMethod;

public final class PerformanceDiagnosticsApi {
    private PerformanceDiagnosticsApi() {}

    @LuaMethod(name = "PZPerfDiagnostics_status", global = true)
    public static String status() {
        return PerformanceDiagnosticsRuntime.status();
    }

    @LuaMethod(name = "PZPerfDiagnostics_marker", global = true)
    public static void marker(String label) {
        PerformanceDiagnosticsRuntime.manualMarker(label);
    }

    @LuaMethod(name = "PZPerfDiagnostics_vehicleEvent", global = true)
    public static void vehicleEvent(
            String attemptId,
            String stage,
            Object character,
            Object vehicle,
            Double seat,
            String action,
            String details) {
        PerformanceDiagnosticsRuntime.vehicleEvent(
                attemptId,
                stage,
                character,
                vehicle,
                seat == null ? -1 : seat.intValue(),
                action,
                details);
    }

    @LuaMethod(name = "PZPerfDiagnostics_actionEvent", global = true)
    public static void actionEvent(
            String traceId, String stage, String actionType, String details) {
        PerformanceDiagnosticsRuntime.actionEvent(traceId, stage, actionType, details);
    }

    @LuaMethod(name = "PZPerfDiagnostics_callback", global = true)
    public static void callback(String eventName, String filename, String functionName, Double line) {
        PerformanceDiagnosticsRuntime.callbackInventory(
                eventName,
                filename,
                functionName,
                line == null ? -1 : line.intValue());
    }
}
