package pzmod.tests;

import pzmod.gaellootdiversification.GaelLootStateRuntime;

public final class GaelLootStatePolicyHarness {
    private GaelLootStatePolicyHarness() {}

    public static void main(String[] args) {
        assertEquals(2, GaelLootStateRuntime.conditionForContext("zombie", 10, 0));
        assertEquals(6, GaelLootStateRuntime.conditionForContext("zombie", 10, 9999));
        assertEquals(7, GaelLootStateRuntime.conditionForContext("secure", 10, 0));
        assertEquals(10, GaelLootStateRuntime.conditionForContext("secure", 10, 9999));
        assertEquals(5, GaelLootStateRuntime.conditionForContext("world", 10, 0));
        assertEquals(9, GaelLootStateRuntime.conditionForContext("world", 10, 9999));

        assertEquals(3, GaelLootStateRuntime.magazineAmmoForContext("zombie", 30, 0));
        assertEquals(18, GaelLootStateRuntime.magazineAmmoForContext("zombie", 30, 9999));
        assertEquals(15, GaelLootStateRuntime.magazineAmmoForContext("secure", 30, 0));
        assertEquals(30, GaelLootStateRuntime.magazineAmmoForContext("secure", 30, 9999));
        assertEquals(1, GaelLootStateRuntime.magazineAmmoForContext("world", 1, 0));
        assertEquals(0, GaelLootStateRuntime.magazineAmmoForContext("world", 0, 9999));

        System.out.println("Gael loot-state Java policy validation passed.");
    }

    private static void assertEquals(int expected, int actual) {
        if (actual != expected) {
            throw new AssertionError("Expected " + expected + ", got " + actual);
        }
    }
}
