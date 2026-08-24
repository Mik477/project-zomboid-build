package pzmod.trashandcorpsessafety;

import java.util.concurrent.atomic.AtomicBoolean;
import zombie.characters.IsoZombie;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.Clothing;

public final class TrashAndCorpsesSafetyRuntime {
    private static final AtomicBoolean REPORTED = new AtomicBoolean();

    private TrashAndCorpsesSafetyRuntime() {}

    public static boolean shouldClampWornZombieClothing(Clothing clothing, int condition) {
        if (clothing == null || condition != 0) return false;
        ItemContainer container = clothing.getContainer();
        if (container == null || !(container.getParent() instanceof IsoZombie zombie)) return false;
        return shouldClampWornZombieClothing(
                condition,
                clothing.isWorn(),
                true,
                zombie.isDead() || zombie.getHealth() <= 0.0f,
                zombie.getSquare() == null,
                container.getSourceGrid() == null);
    }

    static boolean shouldClampWornZombieClothing(
            int condition,
            boolean worn,
            boolean zombieOwner,
            boolean dead,
            boolean zombieSquareMissing,
            boolean sourceGridMissing) {
        if (condition != 0 || !worn || !zombieOwner) return false;
        return dead || (zombieSquareMissing && sourceGridMissing);
    }

    public static void recordGuard() {
        if (REPORTED.compareAndSet(false, true)) {
            System.out.println("[TrashAndCorpsesSafetyFix] Dead-zombie clothing condition guard applied.");
        }
    }
}
