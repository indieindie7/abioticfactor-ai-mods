-- FairFps v0.1: FPS readout + frame-time graph (engine stat fps + stat unitgraph), F8 toggle, frame-time log.
local LOG = "C:/re/abioticfactor/fairfps_log.txt"
local on = true
local function log(s) local f = io.open(LOG, "a"); if f then f:write(os.date("%H:%M:%S "), s, "\n"); f:close() end end
local function cmd(c)
    local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local pc = FindFirstOf("PlayerController")
    if ksl and ksl:IsValid() and pc and pc:IsValid() then ksl:ExecuteConsoleCommand(FindFirstOf("World"), c, pc); return true end
    return false
end
local function apply()
    ExecuteInGameThread(function() pcall(function()
        local ok = cmd("stat fps") and cmd("stat unitgraph")
        log("toggle " .. tostring(on) .. " ok=" .. tostring(ok))
    end) end)
end
RegisterKeyBind(Key.F8, function() on = not on; apply() end)
-- frame-time log: sample delta once a second, write min/avg/max every 10 s
local n, sum, mx, mn = 0, 0, 0, 1e9
local gs = nil
LoopAsync(1000, function()
    ExecuteInGameThread(function() pcall(function()
        gs = gs or StaticFindObject("/Script/Engine.Default__GameplayStatics")
        local w = FindFirstOf("World")
        if not (gs and w and w:IsValid()) then return end
        local dt = gs:GetWorldDeltaSeconds(w) * 1000
        if dt <= 0 then return end
        n = n + 1; sum = sum + dt; if dt > mx then mx = dt end; if dt < mn then mn = dt end
        if n >= 10 then
            log(string.format("frame ms avg=%.1f min=%.1f max=%.1f fps~%.0f", sum / n, mn, mx, 1000 * n / sum))
            n, sum, mx, mn = 0, 0, 0, 1e9
        end
    end) end)
    return false
end)
-- stats start off in engine; turn them on once a player controller exists
local tries = 0
LoopAsync(2000, function()
    tries = tries + 1
    if FindFirstOf("PlayerController") then apply(); return true end
    return tries > 300
end)
log("FairFps loaded (F8 toggles)")
