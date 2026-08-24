package pzmod.trashandcorpsessafety;

import me.zed_0xff.zombie_buddy.Patch;
import zombie.inventory.types.Clothing;

public final class TrashAndCorpsesSafetyPatches {
    private TrashAndCorpsesSafetyPatches() {}

    @Patch(className = "zombie.inventory.types.Clothing", methodName = "setCondition", strictMatch = true)
    public static final class ClothingCondition {
        @Patch.OnEnter
        public static void enter(
                @Patch.This Clothing clothing,
                @Patch.Argument(value = 0, readOnly = false) int condition) {
            if (TrashAndCorpsesSafetyRuntime.shouldClampWornZombieClothing(clothing, condition)) {
                condition = 1;
                TrashAndCorpsesSafetyRuntime.recordGuard();
            }
        }
    }
}
