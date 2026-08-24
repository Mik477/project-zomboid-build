if _G.GGSASF_ContainerCompatibilityApplied then return end
_G.GGSASF_ContainerCompatibilityApplied = true

local Definitions = require("GaelGunStoreCoreFixes/Definitions")
local pistolMagazines = Definitions.toSet(Definitions.pistolMagazines)
local shotgunAmmo = Definitions.toSet(Definitions.shotgunAmmo)
local looseAmmo = {
    ["Base.GrenadeAmmo"] = true,
    ["Base.GrenadeAmmo_incendiary"] = true,
    ["Base.RPG7_RocketAmmo"] = true,
}

local ok, ammoProfiles = pcall(require, "GGS_AmmoProfiles")
if ok and ammoProfiles and ammoProfiles.rounds then
    for _, profile in pairs(ammoProfiles.rounds) do
        if profile.ammoFullType then
            looseAmmo[profile.ammoFullType] = true
        end
    end
end

local originalBullets = AcceptItemFunction.AmmoStrap_Bullets
local originalShells = AcceptItemFunction.AmmoStrap_Shells
local originalHolster = AcceptItemFunction.HolsterShoulder

function AcceptItemFunction.AmmoStrap_Bullets(container, item)
    if originalBullets and originalBullets(container, item) then
        return true
    end
    return looseAmmo[item:getFullType()] == true and shotgunAmmo[item:getFullType()] ~= true
end

function AcceptItemFunction.AmmoStrap_Shells(container, item)
    if originalShells and originalShells(container, item) then
        return true
    end
    return shotgunAmmo[item:getFullType()] == true
end

function AcceptItemFunction.HolsterShoulder(container, item)
    if originalHolster and originalHolster(container, item) then
        return true
    end
    return pistolMagazines[item:getFullType()] == true and container:getItems():size() < 2
end
