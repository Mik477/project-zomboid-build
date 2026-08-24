package pzmod.mpragdollprototype;

import se.krka.kahlua.integration.annotations.LuaMethod;

public final class PrototypeStatus {
    private PrototypeStatus() {}

    @LuaMethod(name = "MPRagdollPrototype_status", global = true)
    public static String status() {
        return PrototypeRuntime.status();
    }

    @LuaMethod(name = "MPRagdollPrototype_setQualityMode", global = true)
    public static String setQualityMode(String mode) {
        return PrototypeRuntime.setQualityMode(mode);
    }
}
