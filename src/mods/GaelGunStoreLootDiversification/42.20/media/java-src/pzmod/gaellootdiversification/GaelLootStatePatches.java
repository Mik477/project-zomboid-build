package pzmod.gaellootdiversification;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.characters.IsoZombie;

public final class GaelLootStatePatches {
    private GaelLootStatePatches() {}

    @Patch(
            className = "zombie.characters.IsoZombie",
            methodName = "DoZombieInventory",
            strictMatch = true)
    public static final class ZombieInventoryCompletion {
        @Patch.OnExit(onThrowable = Throwable.class)
        public static void exit(
                @Patch.This IsoZombie zombie,
                @Patch.Argument(0) boolean corpseInventory,
                @Patch.Thrown Throwable thrown) {
            if (thrown == null) {
                GaelLootStateRuntime.initializeZombieInventory(zombie);
            }
        }
    }
}
