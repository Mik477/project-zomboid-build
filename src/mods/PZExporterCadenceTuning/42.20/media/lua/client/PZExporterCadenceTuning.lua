PZExporterCadenceTuning = PZExporterCadenceTuning or {
    mapApplied = false,
    pulseApplied = false,
}

local Tuning = PZExporterCadenceTuning
local MINIMUM_INTERVAL_MS = 1000

local function enforceMinimumInterval(exporter, name)
    if not exporter or type(exporter.updateMs) ~= "function" then return false end
    if exporter._PZExporterCadenceTuningApplied then return true end

    local originalUpdateMs = exporter.updateMs
    exporter.updateMs = function(...)
        local ok, value = pcall(originalUpdateMs, ...)
        value = ok and tonumber(value) or MINIMUM_INTERVAL_MS
        return math.max(MINIMUM_INTERVAL_MS, value or MINIMUM_INTERVAL_MS)
    end
    exporter.cachedMs = math.max(MINIMUM_INTERVAL_MS, tonumber(exporter.cachedMs) or 0)
    exporter._PZExporterCadenceTuningApplied = true
    print("[PZExporterCadenceTuning] enforced " .. name .. " minimum interval=" .. MINIMUM_INTERVAL_MS .. "ms")
    return true
end

function Tuning.install()
    if not isClient() then return false end
    Tuning.mapApplied = enforceMinimumInterval(PZ_Map, "PZ_Map") or Tuning.mapApplied
    Tuning.pulseApplied = enforceMinimumInterval(PZ_Pulse, "PZ_Pulse") or Tuning.pulseApplied
    return Tuning.mapApplied and Tuning.pulseApplied
end

if Events.OnConnected then Events.OnConnected.Add(Tuning.install) end
if Events.OnGameStart then Events.OnGameStart.Add(Tuning.install) end
Tuning.install()

PZExporterCadenceTuning_status = function()
    return "mapApplied=" .. tostring(Tuning.mapApplied) .. ";pulseApplied=" .. tostring(Tuning.pulseApplied)
end
