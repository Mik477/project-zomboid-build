if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end

local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")

local function contains(values, expected)
    if type(values) ~= "table" then
        return false
    end
    for _, value in ipairs(values) do
        if value == expected then
            return true
        end
    end
    return false
end

local function hasDuplicates(values)
    local seen = {}
    for _, value in ipairs(values or {}) do
        if seen[value] then
            return true
        end
        seen[value] = true
    end
    return false
end

local function containsText(value, expected)
    return string.find(tostring(value), expected, 1, true) ~= nil
end

TestFramework.registerTestModule("Gael Gun Store Ammo & Storage Fixes", "Magazine compatibility", function()
    local Tests = TestUtils.newTestModule("client/GaelGunStoreCoreFixes/Tests/MagazineCompatibilityTests.lua")

    function Tests.test_restored_magazines_and_visual_parts_loaded()
        local scriptManager = getScriptManager()
        local magazine308 = instanceItem("Base.308Clip30")
        local mg131Magazine = instanceItem("Base.Bullets50Clip")
        local g43Magazine = instanceItem("Base.792x57Clip40")
        TestUtils.assert(magazine308 ~= nil)
        TestUtils.assert(mg131Magazine ~= nil)
        TestUtils.assert(g43Magazine ~= nil)
        TestUtils.assert(magazine308:getMaxAmmo() == 30)
        TestUtils.assert(mg131Magazine:getMaxAmmo() == 30)
        TestUtils.assert(g43Magazine:getMaxAmmo() == 40)
        TestUtils.assert(tostring(magazine308:getAmmoType()) == "base:bullets_308")
        TestUtils.assert(tostring(mg131Magazine:getAmmoType()) == "ggs:bullets_50")
        TestUtils.assert(tostring(g43Magazine:getAmmoType()) == "ggs:792x57_bullets")
        TestUtils.assert(scriptManager:getItem("Base.Clip_308Clip20") ~= nil)
        TestUtils.assert(scriptManager:getItem("Base.Clip_M14Clip") ~= nil)
        TestUtils.assert(scriptManager:getItem("Base.Clip_303Clip20") ~= nil)
        TestUtils.assert(scriptManager:getItem("Base.Clip_303Drum50") ~= nil)
        TestUtils.assert(scriptManager:getItem("Base.Clip_9mmClip70old") ~= nil)
        TestUtils.assert(scriptManager:getItem("Base.Clip_Bullets50Clip") ~= nil)
        TestUtils.assert(scriptManager:getItem("Base.Clip_792x57Clip40") ~= nil)
    end

    function Tests.test_targeted_firearm_script_fields_are_corrected()
        local grizzly = instanceItem("Base.Grizzly50AE")
        local enfield = instanceItem("Base.Enfield")
        local m39 = instanceItem("Base.M39")
        local mg131 = instanceItem("Base.MG131")
        TestUtils.assert(grizzly ~= nil and enfield ~= nil and m39 ~= nil and mg131 ~= nil)
        TestUtils.assert(tostring(grizzly:getAmmoType()) == "ggs:bullets_50magnum")
        TestUtils.assert(tostring(grizzly:getAmmoBox()) == "Base.Bullets50MagnumBox")
        TestUtils.assert(tostring(grizzly:getMagazineType()) == "Base.50MagnumClip")
        TestUtils.assert(grizzly:getMaxAmmo() == 8)
        TestUtils.assert(grizzly:getClipSize() == 8)
        TestUtils.assert(tostring(enfield:getAmmoType()) == "ggs:303_bullets")
        TestUtils.assert(tostring(enfield:getAmmoBox()) == "Base.303Box")
        TestUtils.assert(enfield:getMagazineType() == nil)
        TestUtils.assert(enfield:getMaxAmmo() == 10)
        TestUtils.assert(tostring(m39:getAmmoType()) == "base:bullets_308")
        TestUtils.assert(tostring(mg131:getMagazineType()) == "Base.Bullets50Clip")
        TestUtils.assert(mg131:getMaxAmmo() == 30)
        TestUtils.assert(mg131:getClipSize() == 30)
    end

    function Tests.test_shared_magazine_names_are_ammo_based_at_runtime()
        local magazine45 = instanceItem("Base.45Clip")
        local magazine9mm = instanceItem("Base.9mmClip")
        local magazine308 = instanceItem("Base.M14Clip")
        TestUtils.assert(magazine45 ~= nil and magazine9mm ~= nil and magazine308 ~= nil)

        local name45 = magazine45:getDisplayName()
        local name9mm = magazine9mm:getDisplayName()
        local name308 = magazine308:getDisplayName()
        TestUtils.assert(containsText(name45, ".45 ACP Magazine"))
        TestUtils.assert(not containsText(name45, "M1911"))
        TestUtils.assert(containsText(name9mm, "9mm Magazine"))
        TestUtils.assert(not containsText(name9mm, "M9 Magazine"))
        TestUtils.assert(containsText(name308, ".308 Winchester (7.62x51mm) Magazine"))
        TestUtils.assert(not containsText(name308, "M1A Magazine"))
    end

    function Tests.test_dynamic_map_corrections_are_complete_and_idempotent()
        TestUtils.assert(type(_G.GGSASF_ApplyMagazineCompatibility) == "function")
        TestUtils.assert(_G.GGSASF_ApplyMagazineCompatibility())
        TestUtils.assert(_G.GGSASF_ApplyMagazineCompatibility())

        local weaponMap = _G.AWCWF_WeaponMagazineType
        local partMap = _G.AWCWF_MagazineTypeToPart
        TestUtils.assert(type(weaponMap) == "table" and type(partMap) == "table")
        for _, deadKey in ipairs({ "FR-F2", "M98", "P38", "Pistol_shotgun", "Ruger10_22LR", "SVDk" }) do
            TestUtils.assert(weaponMap[deadKey] == nil)
        end

        TestUtils.assert(contains(weaponMap.Walther_P38, "9mmClip30"))
        TestUtils.assert(contains(weaponMap.pistol_shotgun, "12GClip14"))
        TestUtils.assert(contains(weaponMap.SVDK, "762x54rClip40"))
        TestUtils.assert(contains(weaponMap.MAT49, "9mmClip"))
        TestUtils.assert(contains(weaponMap.PPSH41, "9mmClip30old"))
        TestUtils.assert(contains(weaponMap.Grizzly50AE, "50MagnumClip"))
        TestUtils.assert(contains(weaponMap.MG131, "Bullets50Clip"))
        TestUtils.assert(contains(weaponMap.G43, "792x57Clip40"))
        TestUtils.assert(contains(weaponMap.M9A3, "9mmClip30"))
        TestUtils.assert(contains(weaponMap.M9A3, "9mmDrum50"))
        TestUtils.assert(contains(weaponMap.UMP9, "9mmClip30"))
        TestUtils.assert(contains(weaponMap.UMP9, "9mmDrum50"))
        TestUtils.assert(contains(weaponMap.UMP9, "9mmDrum75"))
        TestUtils.assert(contains(weaponMap.UMP9, "9mmDrum100"))
        TestUtils.assert(contains(weaponMap.G36, "556Drum_60rnd"))
        TestUtils.assert(contains(weaponMap.G36, "556Drum_100rnd"))
        TestUtils.assert(contains(weaponMap.HeadhunterRifle, "308Clip30"))
        TestUtils.assert(contains(weaponMap.DeadlyHeadhunterRifle, "308Clip30"))
        TestUtils.assert(contains(weaponMap.TrapperCarbine, "45Clip25"))
        TestUtils.assert(contains(weaponMap.TrapperCarbine, "45Drum50"))

        for _, magazines in pairs(weaponMap) do
            if contains(magazines, "308Clip") or contains(magazines, "M14Clip") or contains(magazines, "308Clip40") then
                TestUtils.assert(contains(magazines, "308Clip30"))
            end
        end

        for _, weaponType in ipairs({
            "Walther_P38", "pistol_shotgun", "SVDK", "MAT49", "PPSH41", "M9A3", "UMP9", "G36",
            "HeadhunterRifle", "DeadlyHeadhunterRifle", "TrapperCarbine"
        }) do
            TestUtils.assert(not hasDuplicates(weaponMap[weaponType]))
        end
        TestUtils.assert(partMap.M14Clip == "Base.Clip_M14Clip")
        TestUtils.assert(partMap["303Clip20"] == "Base.Clip_303Clip20")
        TestUtils.assert(partMap["303Drum50"] == "Base.Clip_303Drum50")
        TestUtils.assert(partMap["308Clip30"] == "Base.Clip_308Clip40")
        TestUtils.assert(partMap["9mmClip70old"] == "Base.Clip_9mmClip70old")
        TestUtils.assert(partMap.Bullets50Clip == "Base.Clip_Bullets50Clip")
        TestUtils.assert(partMap["792x57Clip40"] == "Base.Clip_792x57Clip40")
    end

    return Tests
end)
