local originalOnNewCraft = function() return "vanilla-sequence" end
ISInventoryPaneContextMenu = { OnNewCraft = originalOnNewCraft }
_G.GGSASF_VanillaSequentialAmmoUnpack = nil

local chunk = assert(loadfile(
    "src/mods/GaelGunStoreCoreFixes/42.20/media/lua/client/GaelGunStoreCoreFixes/SafeAmmoUnpack.lua"
))
chunk()

assert(
    ISInventoryPaneContextMenu.OnNewCraft == originalOnNewCraft,
    "Gael compatibility file must leave vanilla OnNewCraft unchanged"
)
assert(
    _G.GGSASF_VanillaSequentialAmmoUnpack == true,
    "Gael compatibility marker must confirm vanilla sequencing is active"
)

print("Gael vanilla sequential unpack compatibility passed.")
