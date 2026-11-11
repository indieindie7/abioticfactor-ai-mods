-- FairFps v0.2: FPS readout + scrolling frame-time bar graph drawn on the HUD (port of AdventMod ModFpsGraph),
-- F8 toggle, frame-time log. v0.1 used `stat unitgraph`, which draws nothing in the shipping build.
-- Graph: top = 50 ms, green line 60 fps (16.7 ms), yellow line 30 fps (33.3 ms); bars green/yellow/red.
local LOG = "C:/re/abioticfactor/fairfps_log.txt"
local SAMPLES, W, H, X0, Y0 = 120, 360, 90, 12, 12
local on = true
local times, head, count = {}, 0, 0
local line, shown, clock = "", -1, 0
local gs, font = nil, nil
local function log(s) local f = io.open(LOG, "a"); if f then f:write(os.date("%H:%M:%S "), s, "\n"); f:close() end end
local function col(r, g, b, a) return {R = r / 255, G = g / 255, B = b / 255, A = a / 255} end
local BG, L60, L30 = col(0, 0, 0, 150), col(60, 200, 60, 200), col(220, 200, 40, 200)
local GOOD, MID, BAD, WHITE = col(80, 220, 80, 220), col(230, 200, 50, 220), col(230, 60, 50, 230), col(255, 255, 255, 255)

-- 10 s log over every drawn frame
local ln, lsum, lmx, lmn, lt = 0, 0, 0, 1e9, 0
local function sample(dt)
    head = head % SAMPLES + 1; times[head] = dt; if count < SAMPLES then count = count + 1 end
    clock = clock + dt
    ln = ln + 1; lsum = lsum + dt; if dt > lmx then lmx = dt end; if dt < lmn then lmn = dt end
    if clock - lt >= 10 then
        log(string.format("frame ms avg=%.1f min=%.1f max=%.1f fps~%.0f frames=%d", lsum / ln * 1000, lmn * 1000, lmx * 1000, ln / lsum, ln))
        ln, lsum, lmx, lmn, lt = 0, 0, 0, 1e9, clock
    end
end

local function draw(hud)
    gs = gs or StaticFindObject("/Script/Engine.Default__GameplayStatics")
    local dt = gs:GetWorldDeltaSeconds(hud)
    if not dt or dt <= 0 then return end
    sample(dt)
    if not on then return end
    local bw = W / SAMPLES
    hud:DrawRect(BG, X0 - 4, Y0 - 4, W + 8, H + 26)
    hud:DrawRect(L60, X0, Y0 + H - H * 16.7 / 50, W, 1)
    hud:DrawRect(L30, X0, Y0 + H - H * 33.3 / 50, W, 1)
    local sum, worst = 0, 0
    for i = 1, count do
        local t = times[(head - count + i - 1) % SAMPLES + 1]
        sum = sum + t; if t > worst then worst = t end
        local ms = math.min(t * 1000, 50)
        local c = ms <= 17.5 and GOOD or (ms <= 34 and MID or BAD)
        local bh = H * ms / 50
        hud:DrawRect(c, X0 + (SAMPLES - count + i - 1) * bw, Y0 + H - bh, math.max(bw, 1), bh)
    end
    if clock - shown > 0.25 or line == "" then
        shown = clock
        line = string.format("fps %d   avg %d   worst %d (%d ms)", math.floor(1 / math.max(times[head], 1e-4)),
            math.floor(count / math.max(sum, 1e-4)), math.floor(1 / math.max(worst, 1e-4)), math.floor(worst * 1000))
    end
    if font == nil then
        font = StaticFindObject("/Engine/EngineFonts/Roboto.Roboto")
        if not (font and font:IsValid()) then font = false; log("no Roboto font: text off, bars only") end
    end
    if font then hud:DrawText(line, WHITE, X0, Y0 + H + 4, font, 1.0, false) end
end

local hooked, errs = false, 0
local function try_hook()
    if hooked then return true end
    local ok, e = pcall(RegisterHook, "/Game/Blueprints/Meta/BP_HUD.BP_HUD_C:ReceiveDrawHUD", function(ctx)
        local ok2, e2 = pcall(draw, ctx:get())
        if not ok2 and errs < 5 then errs = errs + 1; log("draw error " .. tostring(e2)) end
    end)
    if ok then hooked = true; log("graph hooked on BP_HUD:ReceiveDrawHUD") end
    return hooked
end
RegisterKeyBind(Key.F8, function() on = not on; log("toggle " .. tostring(on)) end)
-- BP_HUD loads with the first level; retry the hook until it exists
local tries = 0
LoopAsync(2000, function()
    tries = tries + 1
    local done = false
    ExecuteInGameThread(function() done = try_hook() end)
    return hooked or tries > 600
end)
log("FairFps v0.2 loaded (F8 toggles graph)")
