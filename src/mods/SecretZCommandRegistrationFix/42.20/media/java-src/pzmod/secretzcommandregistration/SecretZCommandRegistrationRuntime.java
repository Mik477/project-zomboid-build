package pzmod.secretzcommandregistration;

import java.util.concurrent.atomic.AtomicBoolean;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;

public final class SecretZCommandRegistrationRuntime {
    private static final String TARGET_FILE = "SZCServer.lua";
    private static final int TARGET_LINE = 401;
    private static final String TARGET_KEY = "DespawnDoor";
    private static final AtomicBoolean REPORTED = new AtomicBoolean();

    private SecretZCommandRegistrationRuntime() {}

    public static boolean shouldSkipAssignment(KahluaThread thread, Object table, Object key, Object value) {
        if (thread == null) return false;
        return shouldSkipAssignment(
                thread.currentfile,
                thread.currentLine,
                table instanceof KahluaTable,
                TARGET_KEY.equals(key),
                value instanceof LuaClosure);
    }

    static boolean shouldSkipAssignment(
            String currentFile,
            int currentLine,
            boolean tableIsKahluaTable,
            boolean keyMatches,
            boolean valueIsLuaClosure) {
        if (currentFile == null) return false;
        String normalizedFile = currentFile.replace('\\', '/');
        return (normalizedFile.equals(TARGET_FILE) || normalizedFile.endsWith("/" + TARGET_FILE))
                && currentLine == TARGET_LINE
                && !tableIsKahluaTable
                && keyMatches
                && valueIsLuaClosure;
    }

    public static void recordGuard() {
        if (REPORTED.compareAndSet(false, true)) {
            System.out.println("[SecretZCommandRegistrationFix] Invalid DespawnDoor registration skipped.");
        }
    }
}
