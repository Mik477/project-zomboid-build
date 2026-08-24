local prefix = "[MPRagdollPrototype] "

local function printStatus()
    if type(MPRagdollPrototype_status) ~= "function" then
        print(prefix .. "Java API unavailable. Approve the JAR in ZombieBuddy and restart the game.")
        return
    end

    local ok, status = pcall(MPRagdollPrototype_status)
    if ok then
        print(prefix .. tostring(status))
    else
        print(prefix .. "Unable to read Java status: " .. tostring(status))
    end
end

Events.OnGameStart.Add(printStatus)
