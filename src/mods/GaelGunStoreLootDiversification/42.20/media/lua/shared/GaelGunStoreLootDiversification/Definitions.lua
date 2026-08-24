local Definitions = {}

Definitions.suppressedLootItems = {
    ["Base.Minigun"] = true,
}

Definitions.firearmSpawnPools = {
    AssaultRifle = { retain = 0.10, ammoType = "base:bullets_556", replacements = { "M4", "AR15", "HK416", "M16A2", "ACR", "G36", "ScarL", "CZ805" } },
    AssaultRifle2 = { retain = 0.10, ammoType = "base:bullets_308", replacements = { "AR10", "FAL", "G3A3", "SA58", "ScarH", "ACE53", "HKG28" } },
    DoubleBarrelShotgun = { retain = 0.25, ammoType = "base:shotgun_shells", replacements = { "DB_Condor" } },
    DoubleBarrelShotgunSawnoff = { retain = 0.25, ammoType = "base:shotgun_shells", replacements = { "DB_Condor_sawn" } },
    HuntingRifle = { retain = 0.10, ammoType = "base:bullets_308", replacements = { "M24", "M40", "MAS36", "CS5", "L96" } },
    JS14_Rifle = { retain = 0.20, ammoType = "base:bullets_556", replacements = { "M16A2", "Mini_14", "ValmetM82", "Scout_elite" } },
    JS3T_Shotgun = { retain = 0.20, ammoType = "base:shotgun_shells", replacements = { "Mossber590", "Remington870", "KSG", "SWMP_12", "BenelliM4" } },
    L92_Carbine = { retain = 0.25, ammoType = "base:bullets_357", replacements = { "SWM1854", "SWM1894" } },
    MSR7T_Rifle = { retain = 0.20, ammoType = "base:bullets_308", replacements = { "M24", "M40", "L96", "JNG90", "L115A" } },
    Pistol = { retain = 0.025, ammoType = "base:bullets_9mm", replacements = { "Beretta_PX4", "M9A3", "BrowningHP", "CZ75", "G17", "P228", "P99", "XD" } },
    Pistol2 = { retain = 0.10, ammoType = "base:bullets_45", replacements = { "Kimber1911", "FNX45", "USP45", "HKMK23", "P220_Elite", "Glock_tactical" } },
    Pistol3 = { retain = 0.10, ammoType = "base:bullets_44", replacements = { "Automag44", "Wildey" } },
    Revolver = { retain = 0.10, ammoType = "base:bullets_357", replacements = { "Rhino20DS", "Python357", "SWM327", "Taurus606" } },
    Revolver_Long = { retain = 0.10, ammoType = "base:bullets_44", replacements = { "Anaconda", "SW629", "SWM629_Deluxe", "Schofield1875" } },
    Revolver_Short = { retain = 0.10, ammoType = "base:bullets_38", replacements = { "Revolver38", "Taurus_RT85", "SW1905", "Webley_MK_snub" } },
    Shotgun = { retain = 0.025, ammoType = "base:shotgun_shells", replacements = { "Mossber500", "Mossber590", "M620", "Remington870", "Winchester1897" } },
    ShotgunSawnoff = { retain = 0.10, ammoType = "base:shotgun_shells", replacements = { "Remington870_Short", "Shorty", "M1887_Short", "Becker_Shotgun_Short", "Beretta_A400_Short" } },
    TrapperCarbine = { retain = 0.25, ammoType = "base:bullets_45", replacements = { "DeLisle" } },
    VarmintRifle = { retain = 0.25, ammoType = "base:bullets_556", replacements = { "Scout_elite" } },
}

return Definitions
