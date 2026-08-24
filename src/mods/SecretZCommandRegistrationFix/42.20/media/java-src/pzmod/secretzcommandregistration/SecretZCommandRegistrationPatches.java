package pzmod.secretzcommandregistration;

import me.zed_0xff.zombie_buddy.Patch;
import se.krka.kahlua.vm.KahluaThread;

public final class SecretZCommandRegistrationPatches {
    private SecretZCommandRegistrationPatches() {}

    @Patch(className = "se.krka.kahlua.vm.KahluaThread", methodName = "tableSet", strictMatch = true)
    public static final class InvalidCommandRegistration {
        @Patch.OnEnter(skipOn = true)
        public static boolean enter(
                @Patch.This KahluaThread thread,
                @Patch.Argument(0) Object table,
                @Patch.Argument(1) Object key,
                @Patch.Argument(2) Object value) {
            boolean skip = SecretZCommandRegistrationRuntime.shouldSkipAssignment(thread, table, key, value);
            if (skip) SecretZCommandRegistrationRuntime.recordGuard();
            return skip;
        }
    }
}
