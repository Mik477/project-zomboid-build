if _G.ItemVisualCompatibilityFixesApplied then return end
_G.ItemVisualCompatibilityFixesApplied = true

local patches = {
    {
        item = "AuthenticZClothing.AuthenticSmokeBomb",
        parameters = { Icon = "SmokeGrenadeIcon", Weight = 1.5 },
    },
    { item = "Bandits.Bucket", parameters = { StaticModel = "Bucket" } },
    {
        item = "Base.HeadhunterRifle",
        modelWeaponParts = {
            "Base.x8Scope Base.x8Scope scope scope",
            "Base.Sling Base.Sling sling sling",
            "Base.bipod_harris Base.bipod_harris bipod bipod",
            "Base.NST_Silencer Base.NST_Silencer silencer silencer",
            "Base.Scrap_Silencer Base.Scrap_Silencer silencer silencer",
        },
    },
}

local scriptManager = getScriptManager()
local patched = 0
local missing = {}
for _, definition in ipairs(patches) do
    local item = scriptManager:getItem(definition.item)
    if item then
        for name, value in pairs(definition.parameters or {}) do
            item:DoParam(name .. " = " .. tostring(value))
        end
        for _, modelWeaponPart in ipairs(definition.modelWeaponParts or {}) do
            item:DoParam("ModelWeaponPart = " .. modelWeaponPart)
        end
        patched = patched + 1
    else
        missing[#missing + 1] = definition.item
    end
end

print(string.format(
    "[ItemVisualCompatibilityFixes] Patched %d visual definitions (%d missing targets).",
    patched,
    #missing
))
if #missing > 0 then
    table.sort(missing)
    print("[ItemVisualCompatibilityFixes] Missing items: " .. table.concat(missing, ", "))
end
