package pzmod.gaellootdiversification;

import java.util.ArrayList;
import se.krka.kahlua.vm.KahluaTable;
import zombie.characters.IsoZombie;
import zombie.core.random.Rand;
import zombie.inventory.InventoryItem;
import zombie.inventory.ItemContainer;
import zombie.inventory.types.HandWeapon;
import zombie.inventory.types.InventoryContainer;
import zombie.network.GameClient;

public final class GaelLootStateRuntime {
    public static final String FIREARM_MARKER = "GGS_LootState_0_2_Firearm";
    public static final String MAGAZINE_MARKER = "GGS_LootState_0_2_Magazine";

    private GaelLootStateRuntime() {}

    public static void initializeZombieInventory(IsoZombie zombie) {
        if (GameClient.client || zombie == null || zombie.isReanimatedPlayer() || zombie.wasFakeDead()) {
            return;
        }
        initializeContainer(zombie.getInventory());
    }

    public static int conditionForContext(String context, int maximum, int roll) {
        if ("secure".equals(context)) return amountFor(maximum, 70, 100, roll);
        if ("zombie".equals(context)) return amountFor(maximum, 20, 60, roll);
        return amountFor(maximum, 45, 90, roll);
    }

    public static int magazineAmmoForContext(String context, int maximum, int roll) {
        if ("secure".equals(context)) return amountFor(maximum, 50, 100, roll);
        if ("zombie".equals(context)) return amountFor(maximum, 10, 60, roll);
        return amountFor(maximum, 25, 90, roll);
    }

    private static int amountFor(int maximum, int minimumPercent, int maximumPercent, int roll) {
        if (maximum <= 0) return 0;
        int normalizedRoll = Math.floorMod(roll, 10000);
        int percentage = minimumPercent
                + (maximumPercent - minimumPercent + 1) * normalizedRoll / 10000;
        return Math.max(1, Math.min(maximum, (maximum * percentage + 99) / 100));
    }

    private static void initializeContainer(ItemContainer container) {
        if (container == null) return;
        ArrayList<InventoryItem> items = container.getItems();
        for (int index = 0; index < items.size(); index++) {
            initializeItem(items.get(index));
        }
    }

    private static void initializeItem(InventoryItem item) {
        if (isFirearm(item)) {
            KahluaTable modData = item.getModData();
            if (modData.rawget(FIREARM_MARKER) == null) {
                item.setCondition(conditionForContext("zombie", item.getConditionMax(), Rand.Next(10000)));
                modData.rawset(FIREARM_MARKER, Boolean.TRUE);
            }
        } else if (isMagazine(item)) {
            KahluaTable modData = item.getModData();
            if (modData.rawget(MAGAZINE_MARKER) == null) {
                item.setCurrentAmmoCount(
                        magazineAmmoForContext("zombie", item.getMaxAmmo(), Rand.Next(10000)));
                modData.rawset(MAGAZINE_MARKER, Boolean.TRUE);
            }
        }

        if (item instanceof InventoryContainer nested) {
            initializeContainer(nested.getInventory());
        }
    }

    private static boolean isFirearm(InventoryItem item) {
        return item instanceof HandWeapon weapon && weapon.isRanged() && weapon.getMaxAmmo() > 0;
    }

    private static boolean isMagazine(InventoryItem item) {
        if (item == null || item instanceof HandWeapon || item.getMaxAmmo() <= 0) return false;
        ArrayList<String> gunTypes = item.getGunType();
        return gunTypes != null && !gunTypes.isEmpty();
    }
}
