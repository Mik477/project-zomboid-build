local Definitions = {}

Definitions.boxes = {
    { item = "Base.Bullets22LRBox", recipe = "GGS_OpenBoxofBullets22LR", rounds = 60 },
    { item = "Base.Bullets32Box", recipe = "GGS_OpenBoxofBullets32", rounds = 50 },
    { item = "Base.Bullets38Box", recipe = "GGS_OpenBoxofBullets38", rounds = 50 },
    { item = "Base.Bullets357Box", recipe = "GGS_OpenBoxofBullets357", rounds = 30 },
    { item = "Base.Bullets44Box", recipe = "GGS_OpenBoxofBullets44", rounds = 50 },
    { item = "Base.Bullets45Box", recipe = "GGS_OpenBoxofBullets45", rounds = 50 },
    { item = "Base.Bullets50MagnumBox", recipe = "GGS_OpenBoxofBullets50Magnum", rounds = 30 },
    { item = "Base.Bullets9mmBox", recipe = "GGS_OpenBoxofBullets9mm", rounds = 50 },
    { item = "Base.3030Box", recipe = "OpenBoxOfBullets20", rounds = 20 },
    { item = "Base.303Box", recipe = "GGS_OpenBoxof303Bullets", rounds = 20 },
    { item = "Base.308Box", recipe = "GGS_OpenBoxof308Bullets", rounds = 20 },
    { item = "Base.30_06Box", recipe = "GGS_OpenBoxof30_06Bullets", rounds = 20 },
    { item = "Base.Bullets50Box", recipe = "GGS_OpenBoxofBullets50", rounds = 20 },
    { item = "Base.545x39Box", recipe = "GGS_OpenBoxof545x39Bullets", rounds = 30 },
    { item = "Base.556Box", recipe = "GGS_OpenBoxof556Bullets", rounds = 60 },
    { item = "Base.762x39Box", recipe = "GGS_OpenBoxof762x39Bullets", rounds = 30 },
    { item = "Base.762x54rBox", recipe = "GGS_OpenBoxof762x54rBullets", rounds = 20 },
    { item = "Base.792x57Box", recipe = "GGS_OpenBoxof792x57Bullets", rounds = 20 },
    { item = "Base.9x39Box", recipe = "GGS_OpenBoxof9x39Bullets", rounds = 30 },
    { item = "Base.ShotgunShellsBox", recipe = "OpenBoxOfShotgunShells", rounds = 25 },

    { item = "Base.Bullets22LRAPBox", recipe = "GGS_OpenBoxof22LRAPBullets", rounds = 60 },
    { item = "Base.Bullets22LRTracerBox", recipe = "GGS_OpenBoxof22LRTracerBullets", rounds = 60 },
    { item = "Base.Bullets32APBox", recipe = "GGS_OpenBoxof32APBullets", rounds = 50 },
    { item = "Base.Bullets32TracerBox", recipe = "GGS_OpenBoxof32TracerBullets", rounds = 50 },
    { item = "Base.Bullets38APBox", recipe = "GGS_OpenBoxof38APBullets", rounds = 50 },
    { item = "Base.Bullets38TracerBox", recipe = "GGS_OpenBoxof38TracerBullets", rounds = 50 },
    { item = "Base.Bullets357APBox", recipe = "GGS_OpenBoxof357APBullets", rounds = 30 },
    { item = "Base.Bullets357TracerBox", recipe = "GGS_OpenBoxof357TracerBullets", rounds = 30 },
    { item = "Base.Bullets44APBox", recipe = "GGS_OpenBoxof44APBullets", rounds = 50 },
    { item = "Base.Bullets44TracerBox", recipe = "GGS_OpenBoxof44TracerBullets", rounds = 50 },
    { item = "Base.Bullets45APBox", recipe = "GGS_OpenBoxof45APBullets", rounds = 50 },
    { item = "Base.Bullets45TracerBox", recipe = "GGS_OpenBoxof45TracerBullets", rounds = 50 },
    { item = "Base.Bullets50MagnumAPBox", recipe = "GGS_OpenBoxof50MagnumAPBullets", rounds = 30 },
    { item = "Base.Bullets50MagnumTracerBox", recipe = "GGS_OpenBoxof50MagnumTracerBullets", rounds = 30 },
    { item = "Base.Bullets9mmAPBox", recipe = "GGS_OpenBoxof9mmAPBullets", rounds = 50 },
    { item = "Base.Bullets9mmTracerBox", recipe = "GGS_OpenBoxof9mmTracerBullets", rounds = 50 },
    { item = "Base.303BulletsAPBox", recipe = "GGS_OpenBoxof303APBullets", rounds = 20 },
    { item = "Base.303BulletsTracerBox", recipe = "GGS_OpenBoxof303TracerBullets", rounds = 20 },
    { item = "Base.308BulletsAPBox", recipe = "GGS_OpenBoxof308APBullets", rounds = 20 },
    { item = "Base.308BulletsTracerBox", recipe = "GGS_OpenBoxof308TracerBullets", rounds = 20 },
    { item = "Base.30_06BulletsAPBox", recipe = "GGS_OpenBoxof30_06APBullets", rounds = 20 },
    { item = "Base.30_06BulletsTracerBox", recipe = "GGS_OpenBoxof30_06TracerBullets", rounds = 20 },
    { item = "Base.Bullets50APBox", recipe = "GGS_OpenBoxof50APBullets", rounds = 20 },
    { item = "Base.Bullets50TracerBox", recipe = "GGS_OpenBoxof50TracerBullets", rounds = 20 },
    { item = "Base.545x39BulletsAPBox", recipe = "GGS_OpenBoxof545x39APBullets", rounds = 30 },
    { item = "Base.545x39BulletsTracerBox", recipe = "GGS_OpenBoxof545x39TracerBullets", rounds = 30 },
    { item = "Base.556BulletsAPBox", recipe = "GGS_OpenBoxof556APBullets", rounds = 60 },
    { item = "Base.556BulletsTracerBox", recipe = "GGS_OpenBoxof556TracerBullets", rounds = 60 },
    { item = "Base.762x39BulletsAPBox", recipe = "GGS_OpenBoxof762x39APBullets", rounds = 30 },
    { item = "Base.762x39BulletsTracerBox", recipe = "GGS_OpenBoxof762x39TracerBullets", rounds = 30 },
    { item = "Base.762x54rBulletsAPBox", recipe = "GGS_OpenBoxof762x54rAPBullets", rounds = 20 },
    { item = "Base.762x54rBulletsTracerBox", recipe = "GGS_OpenBoxof762x54rTracerBullets", rounds = 20 },
    { item = "Base.792x57BulletsAPBox", recipe = "GGS_OpenBoxof792x57APBullets", rounds = 20 },
    { item = "Base.792x57BulletsTracerBox", recipe = "GGS_OpenBoxof792x57TracerBullets", rounds = 20 },
    { item = "Base.9x39BulletsAPBox", recipe = "GGS_OpenBoxof9x39APBullets", rounds = 30 },
    { item = "Base.9x39BulletsTracerBox", recipe = "GGS_OpenBoxof9x39TracerBullets", rounds = 30 },
    { item = "Base.ShotgunSlugBox", recipe = "GGS_OpenBoxofShotgunSlugs", rounds = 24 },
    { item = "Base.DragonBreathShellBox", recipe = "GGS_OpenBoxofDragonBreathShells", rounds = 24 },

    { item = "Base.GrenadeAmmoBox", recipe = "OpenBoxofGrenadeAmmo", rounds = 6 },
    { item = "Base.GrenadeAmmoBox_incendiary", recipe = "OpenBoxofIncendiaryGrenadeAmmo", rounds = 6 },
    { item = "Base.RocketAmmoBox", recipe = "GGSASF_OpenRocketAmmoBox", rounds = 3 },
}

Definitions.projectilePacks = {
    { item = "Base.arrow_wood_pack", recipe = "GGS_OpenBoxofArrowsWood", rounds = 8 },
    { item = "Base.arrow_metal_pack", recipe = "GGS_OpenBoxofArrowsMetal", rounds = 8 },
    { item = "Base.arrow_carbon_pack", recipe = "GGS_OpenBoxofArrowsCarbon", rounds = 8 },
    { item = "Base.bolt_wood_pack", recipe = "GGS_OpenBoxofBoltsWood", rounds = 8 },
    { item = "Base.bolt_metal_pack", recipe = "GGS_OpenBoxofBoltsMetal", rounds = 8 },
    { item = "Base.bolt_carbon_pack", recipe = "GGS_OpenBoxofBoltsCarbon", rounds = 8 },
}

Definitions.feedDevices = {
    { item = "Base.22LRClip", rounds = 25 },
    { item = "Base.22LRClip50", rounds = 50 },
    { item = "Base.22LRDrum100", rounds = 100 },
    { item = "Base.BizonClip64", rounds = 64 },

    { item = "Base.303Clip20", rounds = 20 },
    { item = "Base.303Drum50", rounds = 40 },

    { item = "Base.308Clip", rounds = 10 },
    { item = "Base.M14Clip", rounds = 20 },
    { item = "Base.308Clip30", rounds = 30 },
    { item = "Base.308Clip40", rounds = 40 },
    { item = "Base.308Drum60", rounds = 60 },
    { item = "Base.308Drum100", rounds = 100 },
    { item = "Base.308Box150", rounds = 150 },

    { item = "Base.30_06Clip", rounds = 10 },
    { item = "Base.30_06Clip40", rounds = 40 },

    { item = "Base.357Clip", rounds = 10 },
    { item = "Base.357Drum45", rounds = 45 },

    { item = "Base.44Clip", rounds = 8 },
    { item = "Base.44Clip20", rounds = 20 },
    { item = "Base.44Drum50", rounds = 50 },

    { item = "Base.45Clip", rounds = 12 },
    { item = "Base.45Clip25", rounds = 25 },
    { item = "Base.45Clip30old", rounds = 30 },
    { item = "Base.45Drum50", rounds = 50 },
    { item = "Base.45Drum60old", rounds = 60 },
    { item = "Base.45Drum100", rounds = 100 },

    { item = "Base.50Clip", rounds = 10 },
    { item = "Base.50Clip18", rounds = 18 },
    { item = "Base.Bullets50Clip", rounds = 30 },

    { item = "Base.50MagnumClip", rounds = 8 },
    { item = "Base.50MagnumClip18", rounds = 18 },
    { item = "Base.50MagnumDrum40", rounds = 40 },

    { item = "Base.545x39Clip30", rounds = 30 },
    { item = "Base.545x39Clip60", rounds = 60 },
    { item = "Base.545x39Drum100", rounds = 100 },

    { item = "Base.JS14_Clip", rounds = 20 },
    { item = "Base.556Clip", rounds = 30 },
    { item = "Base.556Drum_60rnd", rounds = 60 },
    { item = "Base.556Drum_100rnd", rounds = 100 },
    { item = "Base.556Box150", rounds = 150 },

    { item = "Base.762x39Clip", rounds = 30 },
    { item = "Base.762x39Clip45", rounds = 45 },
    { item = "Base.762x39Drum73", rounds = 73 },
    { item = "Base.762x39Drum100", rounds = 100 },

    { item = "Base.762x54rClip", rounds = 20 },
    { item = "Base.762x54rClip40", rounds = 40 },
    { item = "Base.762x54rBox150", rounds = 150 },

    { item = "Base.792x57Clip", rounds = 10 },
    { item = "Base.792x57Clip40", rounds = 40 },
    { item = "Base.792x57Box75", rounds = 75 },
    { item = "Base.792x57Box97", rounds = 97 },

    { item = "Base.9mmClip", rounds = 15 },
    { item = "Base.9mmClip30", rounds = 30 },
    { item = "Base.9mmClip30old", rounds = 30 },
    { item = "Base.9mmDrum50", rounds = 50 },
    { item = "Base.P90Clip", rounds = 50 },
    { item = "Base.9mmClip70old", rounds = 70 },
    { item = "Base.9mmDrum75", rounds = 75 },
    { item = "Base.9mmClip100old", rounds = 100 },
    { item = "Base.9mmDrum100", rounds = 100 },

    { item = "Base.9x39Clip", rounds = 20 },
    { item = "Base.9x39Clip40", rounds = 40 },
    { item = "Base.9x39Drum60", rounds = 60 },

    { item = "Base.12GClip", rounds = 8 },
    { item = "Base.12GClip14", rounds = 14 },
    { item = "Base.12GDrum24", rounds = 24 },
}

Definitions.firearmScriptPatches = {
    {
        item = "Base.Grizzly50AE",
        ammoType = "ggs:bullets_50magnum",
        ammoBox = "Base.Bullets50MagnumBox",
        magazineType = "Base.50MagnumClip",
        maxAmmo = 8,
        clipSize = 8,
    },
    { item = "Base.M39", ammoType = "base:bullets_308" },
    {
        item = "Base.Enfield",
        ammoType = "ggs:303_bullets",
        ammoBox = "Base.303Box",
        maxAmmo = 10,
    },
    {
        item = "Base.MG131",
        magazineType = "Base.Bullets50Clip",
        maxAmmo = 30,
        clipSize = 30,
    },
}

Definitions.itemVisualPatches = {
    { item = "Base.BenelliM3", parameters = { Icon = "BenelliM4" } },
    { item = "Base.G36", parameters = { Icon = "G36C" } },
    { item = "Base.M9A3", parameters = { Icon = "M9" } },
    { item = "Base.PKM", parameters = { Icon = "PKP" } },
    { item = "Base.Rhino60DS", parameters = { Icon = "Rhino20DS" } },
    { item = "Base.303Clip20", parameters = { Icon = "792x57Clip" } },
    { item = "Base.303Drum50", parameters = { Icon = "308Drum60" } },
    { item = "Base.BizonClip64", parameters = { Icon = "22LRDrum100" } },
    { item = "Base.30_06Clip", parameters = { Icon = "792x57Clip" } },
    { item = "Base.30_06Clip40", parameters = { Icon = "308Clip40" } },
    { item = "Base.Bullets50Clip", parameters = { Icon = "308Box150" } },
    { item = "Base.9mmClip70old", parameters = { WorldStaticModel = "Clip_9mmClip70old" } },
    { item = "Base.9mmClip100old", parameters = { WorldStaticModel = "Clip_9mmClip100old" } },
}

Definitions.magazineMapAliases = {
    { from = "P38", to = "Walther_P38" },
    { from = "Pistol_shotgun", to = "pistol_shotgun" },
    { from = "SVDk", to = "SVDK" },
}

Definitions.magazineMapRemovals = {
    "FR-F2",
    "M98",
    "Ruger10_22LR",
}

Definitions.magazineMapUnions = {
    HeadhunterRifle = { "308Clip", "M14Clip", "308Clip30", "308Clip40" },
    DeadlyHeadhunterRifle = { "308Clip", "M14Clip", "308Clip30", "308Clip40" },
    TrapperCarbine = { "45Clip", "45Clip25", "45Drum50" },
    M9A3 = { "9mmClip", "9mmClip30", "9mmDrum50" },
    UMP9 = { "9mmClip", "9mmClip30", "9mmDrum50", "9mmDrum75", "9mmDrum100" },
    G36 = { "556Clip", "556Drum_60rnd", "556Drum_100rnd" },
    MAT49 = { "9mmClip", "9mmClip30old", "9mmClip100old" },
    PPSH41 = { "9mmClip30old", "9mmClip", "9mmClip30", "9mmDrum50", "9mmDrum75", "9mmDrum100" },
    Grizzly50AE = { "50MagnumClip", "50MagnumClip18", "50MagnumDrum40" },
    MG131 = { "Bullets50Clip" },
    G43 = { "792x57Clip", "792x57Clip40" },
}

Definitions.magazineFamilyExpansions = {
    {
        markers = { "308Clip", "M14Clip", "308Clip40" },
        magazines = { "308Clip", "M14Clip", "308Clip30", "308Clip40" },
    },
}

Definitions.magazinePartPatches = {
    M14Clip = "Base.Clip_M14Clip",
    ["303Clip20"] = "Base.Clip_303Clip20",
    ["303Drum50"] = "Base.Clip_303Drum50",
    ["308Clip30"] = "Base.Clip_308Clip40",
    ["9mmClip70old"] = "Base.Clip_9mmClip70old",
    Bullets50Clip = "Base.Clip_Bullets50Clip",
    ["792x57Clip40"] = "Base.Clip_792x57Clip40",
}

Definitions.lootClones = {
    { source = "Base.308Clip40", item = "Base.308Clip30" },
    { source = "Base.50Clip", item = "Base.Bullets50Clip" },
    { source = "Base.792x57Clip", item = "Base.792x57Clip40" },
}

Definitions.obsoleteLootItems = {
    "Base.30_06Clip",
    "Base.30_06Clip40",
}

Definitions.customRecipes = {
    "GGSASF_OpenAmmoCarton",
    "GGSASF_PackAmmoCarton",
    "GGSASF_Pack3030Rounds",
    "GGSASF_PackShotgunShells",
    "GGSASF_PackGrenadeAmmo",
    "GGSASF_PackIncendiaryGrenadeAmmo",
    "GGSASF_OpenRocketAmmoBox",
    "GGSASF_PackRockets",
    "GGSASF_PackWoodArrows",
    "GGSASF_PackMetalArrows",
    "GGSASF_PackCarbonArrows",
    "GGSASF_PackWoodBolts",
    "GGSASF_PackMetalBolts",
    "GGSASF_PackCarbonBolts",
}

Definitions.cartons = {
    "Base.Bullets9mmCarton",
    "Base.Bullets9x39Carton",
    "Base.Bullets22Carton",
    "Base.Bullets32Carton",
    "Base.Bullets38Carton",
    "Base.Bullets44Carton",
    "Base.Bullets45Carton",
    "Base.Bullets50CalCarton",
    "Base.Bullets50MagnumCarton",
    "Base.308Carton",
    "Base.Bullets357Carton",
    "Base.545x39Carton",
    "Base.556Carton",
    "Base.762x39Carton",
    "Base.762x54rCarton",
    "Base.30_06Carton",
    "Base.303Carton",
    "Base.3030Carton",
    "Base.792x57Carton",
    "Base.ShotgunShellsCarton",
}

Definitions.pistolMagazines = {
    "Base.9mmClip",
    "Base.22LRClip",
    "Base.22LRClip50",
    "Base.357Clip",
    "Base.44Clip",
    "Base.44Clip20",
    "Base.45Clip",
    "Base.45Clip25",
    "Base.50MagnumClip",
    "Base.50MagnumClip18",
}

Definitions.shotgunAmmo = {
    "Base.ShotgunShells",
    "Base.ShotgunSlug",
    "Base.DragonBreathShell",
}

Definitions.cartonRecipe = "GGSASF_OpenAmmoCarton"

function Definitions.toSet(values, field)
    local result = {}
    for _, value in ipairs(values) do
        result[field and value[field] or value] = true
    end
    return result
end

function Definitions.getUnpackRecipeSet()
    local result = Definitions.toSet(Definitions.boxes, "recipe")
    for recipe in pairs(Definitions.toSet(Definitions.projectilePacks, "recipe")) do
        result[recipe] = true
    end
    result[Definitions.cartonRecipe] = true
    return result
end

return Definitions
