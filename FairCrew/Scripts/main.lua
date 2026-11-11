-- FairCrew v0.2: random stranded scientists you can recruit as companions.
-- Folds the villager-companion AIs we studied into one small loop:
--   Animal Crossing (C:/re/animalcrossing/AI-MAP.md): home spot + idle wander, friendship that grows near you
--     and decays when you leave them, leaves (goes home) when friendship runs out.
--   Core Keeper villagers (C:/re/corekeeper/mod): small crew cap, follow the owner, return home when left.
-- Fair play: crew use the stock ally pawns (NarrativeNPC_BossAlly*) and their stock BT for combat;
-- no stat buffs, no teleports. FairSight caps their wall-tracking like everyone else.
local SELFTEST = os.getenv("AF_FAIRCREW_SELFTEST") == "1"   -- scripted self-test, see selftest.lua
local LOG  = (os.getenv("AF_FAIRSIGHT_TEST") == "1" or SELFTEST) and "C:/re/abioticfactor/faircrew_srv_log.txt" or "C:/re/abioticfactor/faircrew_log.txt"
local TEST = os.getenv("AF_FAIRSIGHT_TEST") == "1"   -- server test: PlayerStart stands in for a player

local CLASSES = {
  "/Game/Blueprints/Characters/NarrativeNPCs/NarrativeNPC_BossAlly",
  -- _Heavy + _Sniper dropped 11-10: spawn with no AI controller and vanish in seconds (Heavy also crashed V_Intro)
}
local WORLD_CAP     = 3      -- scientists alive in the world at once
local PER_PLAYER    = 2      -- followers per player
local RESPAWN_S     = TEST and 5 or 600   -- seconds between spawns while under the cap
local RECRUIT_UU    = 300    -- stand this close ...
local RECRUIT_S     = 4      -- ... this long to recruit
local FOLLOW_UU     = 400    -- start walking after the owner beyond this
local LEFT_UU       = 3000   -- owner this far away = "left behind"
local WANDER_UU     = 700    -- idle wander radius around home
local TICK_S        = 1.5
local SETTLE_UU     = 250    -- owner this close to a free bed ...
local SETTLE_S      = 3      -- ... this long (follower nearby) = scientist moves in
local BED_WANDER_UU = 400    -- settled scientists wander this close to their bed
local BED_CLASSES = {"Deployed_Furniture_Bed_ParentBP_C", "Deployed_Furniture_Cot_Military_C", "Deployed_VOTV_Mattress_C", "Deployed_VOTV_SleepingBag_C"}
local DIR = (debug.getinfo(1, "S").source:match("^@(.*)main%.lua$") or "")
local GIFTS = dofile(DIR .. "gifts.lua")   -- food + healing item rows (lower-case)

local function log(s) local f = io.open(LOG, "a"); if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end end
log("loaded" .. (TEST and " (server test)" or ""))

local function loc(a) return a:K2_GetActorLocation() end
local function d2(a, b) local x, y, z = a.X-b.X, a.Y-b.Y, a.Z-b.Z; return x*x+y*y+z*z end
local function valid(o) return o and o:IsValid() end
local function alive(a)   -- a destroyed actor stays IsValid until garbage collection
  if not valid(a) then return false end
  local ok, dying = pcall(function() return a:IsActorBeingDestroyed() end)
  if ok and dying then return false end
  local ok2, root = pcall(function() return a.RootComponent end)
  return ok2 and valid(root)
end

local crew = {}        -- [i] = {pawn, home={X,Y,Z}, owner, friend 0..100, near_s, wander_t, name}
local last_spawn = -RESPAWN_S
local navlogged = false
local movelog = 0
local clock = 0
local FAKE, FAKE_BEDS, AUTOSPAWN, SELF = nil, nil, true, nil   -- self-test hooks
local selftest_load
local BOT = nil   -- agent-vs-agent test: an NPC plays the owner (has a virtual gift), no player input needed

local function players()
  if FAKE then return FAKE end
  if BOT then return valid(BOT) and {BOT} or {} end
  local out = {}
  for _, p in ipairs(FindAllOf("Abiotic_PlayerCharacter_C") or {}) do if valid(p) then out[#out+1] = p end end
  if TEST and #out == 0 then local ps = FindFirstOf("PlayerStart"); if valid(ps) then out[1] = ps end end
  return out
end

local function move_to(pawn, dest, accept)
  local c = pawn.Controller
  if not valid(c) then return end
  -- EPathFollowingRequestResult: 0 Failed, 1 AlreadyAtGoal, 2 RequestSuccessful
  local ok, r = pcall(function() return c:MoveToLocation(dest, accept, true, true, true, false, nil, true) end)
  local direct = false
  if not ok or r == 0 then   -- no path (no navmesh here): walk straight instead of standing still
    direct = true
    ok, r = pcall(function() return c:MoveToLocation(dest, accept, true, false, false, false, nil, true) end)
  end
  if SELFTEST and movelog < 6 then movelog = movelog + 1; log("move ok=" .. tostring(ok) .. " r=" .. tostring(r) .. " direct=" .. tostring(direct)) end
  return ok, r, direct
end

local function spawn_one(pl, at, as_bot)
  local world = FindFirstOf("World"); if not valid(world) then return end
  local spots = {}
  for _, sp in ipairs(FindAllOf("Abiotic_NPCSpawn_ParentBP_C") or {}) do
    if valid(sp) then
      local l = loc(sp); local ok = true
      for _, p in ipairs(pl) do
        local dd = d2(l, loc(p))
        if TEST then ok = dd < 4000*4000 else ok = ok and dd > 2500*2500 end   -- never pop in in front of a player
      end
      if ok then spots[#spots+1] = l end
    end
  end
  local l = (#spots > 0) and spots[math.random(#spots)] or nil
  if not l then
    -- no spawner far enough: random reachable navmesh point 3000-4500 uu from a random player
    local nav = StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1")
    local o = loc(pl[math.random(#pl)])
    for _ = 1, 6 do
      local out = {}
      local ok, hit = pcall(function() return nav:K2_GetRandomReachablePointInRadius(world, o, out, 4500.0, nil, nil) end)
      if TEST and not navlogged then navlogged = true; log("nav ok=" .. tostring(ok) .. " hit=" .. tostring(hit) .. " out=" .. tostring(out.X) .. "," .. tostring(out.Y)) end
      if ok and hit and out.X and d2(out, o) > 3000*3000 then l = {X=out.X, Y=out.Y, Z=out.Z}; break end
    end
  end
  if TEST and #crew == 0 then local s0 = loc(pl[1]); l = {X=s0.X+150, Y=s0.Y, Z=s0.Z} end   -- test: first one spawns next to the fake player
  if at then l = at end
  if not l then log("spawn: no spot (spawners " .. #spots .. ")"); return end
  local path = CLASSES[math.random(#CLASSES)]
  local name = path:match("([^/]+)$")
  LoadAsset(path .. "." .. name)
  local cls = StaticFindObject(path .. "." .. name .. "_C")
  if not valid(cls) then log("spawn: no class " .. name); return end
  local a = world:SpawnActor(cls, {X=l.X, Y=l.Y, Z=l.Z+100}, {Pitch=0, Yaw=math.random(0, 359), Roll=0})
  if not valid(a) then log("spawn: failed " .. name); return end
  if not valid(a.Controller) then pcall(function() a:SpawnDefaultController() end) end   -- placed-by-script pawns can come up without AI
  if as_bot then BOT = a; AUTOSPAWN = false; log(string.format("bot owner %s at %.0f %.0f", name, l.X, l.Y)); return a end
  crew[#crew+1] = {pawn=a, home={X=l.X, Y=l.Y, Z=l.Z}, owner=nil, friend=0, near_s=0, wander_t=0, name=name}
  log(string.format("spawn %s at %.0f %.0f %.0f ctrl=%s", name, l.X, l.Y, l.Z, tostring(valid(a.Controller) and a.Controller:GetClass():GetFName():ToString())))
end

local function followers(p) local n = 0; for _, m in ipairs(crew) do if m.owner == p then n = n + 1 end end; return n end

-- held food/healing item of a player, or nil
local function held_gift(p)
  if p == BOT then return "Bandage" end
  local ok, row = pcall(function() return p.CurrentItemRow:ToString() end)
  if ok and row and GIFTS[row:lower()] then return row end
end
-- take one of the held item (the gift); true if the game confirmed it
local function take_gift(p, row)
  if p == BOT then return true end
  -- 11-10: GetCurrentHeldItem(o,slot,{},{}) crashed the client (FField::AddCppProperty) 4 s after the
  -- recruit started; now the row handle is built here (the Lua side takes exactly 2 args)
  local ok, e = pcall(function()
    local h = {DataTable = StaticFindObject("/Game/Blueprints/Items/ItemTable_Global.ItemTable_Global"), RowName = FName(row)}
    p:ConsumeItemOfSpecificCount(h, 1)
  end)
  if not ok then log("take_gift error " .. tostring(e)) end
  return ok
end

local beds, beds_t, claimed = {}, -100, {}   -- claimed[bed full name] = member
local function refresh_beds()
  -- every tick (was 10 s): a cached bed actor can go stale when its area streams out/in (crash 4, 11-10)
  if clock - beds_t < TICK_S * 0.5 then return end
  beds_t = clock; beds = {}
  local seen = {}   -- parent + child bed classes both list the same actor
  for _, cn in ipairs(BED_CLASSES) do for _, b in ipairs(FindAllOf(cn) or {}) do if valid(b) then local k = b:GetFullName(); if not seen[k] then seen[k] = true; beds[#beds+1] = b end end end end
  for _, b in ipairs(FAKE_BEDS or {}) do beds[#beds+1] = b end
end
local function free_bed_near(pos, r)
  for _, b in ipairs(beds) do
    if FAKE_BEDS or alive(b) then
      local k = b:GetFullName()
      if not (claimed[k] and valid(claimed[k].pawn)) and d2(loc(b), pos) < r*r then return b, k end
    end
  end
end

local function tick()
  clock = clock + TICK_S
  for i = #crew, 1, -1 do if not alive(crew[i].pawn) then log("lost " .. crew[i].name); if crew[i].bedkey then claimed[crew[i].bedkey] = nil end; table.remove(crew, i) end end
  for _, m in ipairs(crew) do   -- a spawned NPC can start in MOVE_None (0) or with its movement tick off, and then never walks
    pcall(function() local cm = m.pawn.CharacterMovement; if not cm:IsComponentTickEnabled() then cm:SetComponentTickEnabled(true) end; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0) end end)
  end
  local pl = players()
  if #pl == 0 then return end
  if AUTOSPAWN and #crew < WORLD_CAP and clock - last_spawn >= RESPAWN_S then last_spawn = clock; spawn_one(pl) end

  refresh_beds()
  for _, m in ipairs(crew) do
    local here = loc(m.pawn)
    if m.owner and not valid(m.owner) then m.owner = nil end
    if not m.owner then
      -- idle: AC-style wander around home; recruit when a player lingers close
      local best, bd
      for _, p in ipairs(pl) do local dd = d2(here, loc(p)); if not bd or dd < bd then best, bd = p, dd end end
      local gift = best and held_gift(best)
      if bd and bd < RECRUIT_UU*RECRUIT_UU and gift and followers(best) < PER_PLAYER and clock >= (m.recruit_cd or 0) then
        m.near_s = m.near_s + TICK_S
        if m.near_s >= RECRUIT_S then
          local took = take_gift(best, gift)
          m.owner = best; m.settled = false; m.friend = math.max(m.friend, 50) + 10; m.near_s = 0
          log("recruited " .. m.name .. " with " .. gift .. " took=" .. tostring(took) .. " friend=" .. m.friend)
        end
      else
        m.near_s = 0
        if clock >= m.wander_t then
          m.wander_t = clock + math.random(10, 20)
          local a = math.random() * 2 * math.pi; local r = math.random(m.bed and 100 or 200, m.bed and BED_WANDER_UU or WANDER_UU)
          move_to(m.pawn, {X=m.home.X + r*math.cos(a), Y=m.home.Y + r*math.sin(a), Z=m.home.Z}, 50.0)
        end
      end
    else
      -- following: walk after the owner; friendship grows near, decays when left behind
      local o = loc(m.owner); local dd = d2(here, o)
      if dd > FOLLOW_UU*FOLLOW_UU then move_to(m.pawn, o, FOLLOW_UU*0.5) end
      if dd < 1500*1500 then m.friend = math.min(100, m.friend + TICK_S/10)
      elseif dd > LEFT_UU*LEFT_UU then m.friend = m.friend - TICK_S/2 end
      if m.friend <= 0 then
        m.owner = nil; m.friend = 0; m.wander_t = 0
        if m.bed then claimed[m.bedkey] = nil; m.bed, m.bedkey = nil, nil end
        log("went home " .. m.name)
      else
        -- move in: owner stands at a free bed with this follower close by
        local b, k = free_bed_near(o, SETTLE_UU)
        if b and dd < 800*800 then
          m.settle_s = (m.settle_s or 0) + TICK_S
          if m.settle_s >= SETTLE_S then
            if m.bedkey then claimed[m.bedkey] = nil end
            claimed[k] = m; m.bed, m.bedkey = b, k
            local bl = loc(b); m.home = {X=bl.X, Y=bl.Y, Z=bl.Z}
            m.owner = nil; m.wander_t = 0; m.settle_s = 0
            m.recruit_cd = clock + 30   -- 11-10 run: owner still holding the gift re-recruited it 6 s after move-in (ate a 2nd Bandage)
            log("moved in " .. m.name .. " bed=" .. k:match("[^%.:]+$"))
          end
        else m.settle_s = 0 end
      end
    end
  end
end

local ticks = 0
LoopAsync(math.floor(TICK_S*1000), function()
  ExecuteInGameThread(function()
    local ok, err = pcall(tick); if not ok then log("tick error " .. tostring(err)) end
    if SELFTEST and not SELF then selftest_load() end
    if SELF then local ok2, err2 = pcall(SELF, clock); if not ok2 then log("selftest error " .. tostring(err2)) end end
    ticks = ticks + 1
    if ticks % 20 == 0 then
      local parts = {}
      for _, m in ipairs(crew) do local l = loc(m.pawn); parts[#parts+1] = string.format("%s[%s f=%.0f %.0f,%.0f]", m.name:gsub("NarrativeNPC_", ""), m.owner and "follow" or (m.bed and "home" or "idle"), m.friend, l.X, l.Y) end
      log("crew " .. #crew .. " " .. table.concat(parts, " "))
    end
  end)
  return false
end)

-- test keys (v0.2 test build): F9 = spawn a scientist 3 m in front of you, F10 = log crew + your held item
local function me()
  local pc = FindFirstOf("PlayerController"); if pc and valid(pc) and pc.Pawn and valid(pc.Pawn) then return pc.Pawn end
  if TEST then local ps = FindFirstOf("PlayerStart"); if valid(ps) then return ps end end   -- server gym: no player, anchor on PlayerStart
end
local function t_spawn(dist)
  local p = me(); if not p then log("F9: no pawn"); return end
  local l = loc(p); local f = p:GetActorForwardVector()
  spawn_one({p}, {X=l.X + f.X*dist, Y=l.Y + f.Y*dist, Z=l.Z})
  log("F9 spawn near player d=" .. dist)
end
local function t_status()
  local p = me(); local row = p and (pcall(function() return p.CurrentItemRow:ToString() end) and p.CurrentItemRow:ToString()) or "?"
  local parts = {}
  for _, m in ipairs(crew) do local l = loc(m.pawn); parts[#parts+1] = string.format("%s[%s f=%.0f %.0f,%.0f]", m.name:gsub("NarrativeNPC_", ""), m.owner and "follow" or (m.bed and "home" or "idle"), m.friend, l.X, l.Y) end
  local pl = p and loc(p) or {X=0, Y=0}
  local bl = {}; for _, b in ipairs(beds) do local q = loc(b); bl[#bl+1] = string.format("%.0f,%.0f,%.0f", q.X, q.Y, q.Z) end
  log(string.format("F10 me=%.0f,%.0f held=%s gift=%s beds=%d crew %d %s", pl.X, pl.Y, tostring(row), tostring(GIFTS[tostring(row):lower()] or false), #beds, #crew, table.concat(parts, " ") .. " beds@" .. table.concat(bl, ";") .. (valid(BOT) and string.format(" bot=%.0f,%.0f", loc(BOT).X, loc(BOT).Y) or "")))
end
function t_bot(dist)
  local p = me(); if not p then log("bot: no pawn"); return end
  local l = loc(p); local f = p:GetActorForwardVector()
  local b = spawn_one({p}, {X=l.X + f.X*dist, Y=l.Y + f.Y*dist, Z=l.Z}, true); if not valid(b) then return end
  local bl = loc(b); spawn_one({b}, {X=bl.X + 150, Y=bl.Y, Z=bl.Z - 100})
end
-- 11-11 bot walker: runs 1-4 the bot owner got r=2 from MoveToLocation and stood still. Stop its behaviour tree, re-issue the move every
-- second, and if it still has not moved 50 uu in 2 s, glide it (K2_SetActorLocation, 600 uu/s straight line; test-only, bot owner only).
local BG = nil   -- {dest, accept, t, last={X,Y}, stuck, glide}
local function bot_goal(dest, accept)
  if not valid(BOT) then return end
  pcall(function() local bc = BOT.Controller.BrainComponent; if valid(bc) and bc:IsRunning() then bc:StopLogic("FairCrew bot owner"); log("bot BT stopped") end end)
  pcall(function() local cm = BOT.CharacterMovement; if not cm:IsComponentTickEnabled() then cm:SetComponentTickEnabled(true) end; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0) end end)
  local l = loc(BOT); BG = {dest = dest, accept = accept or 50, t = 0, last = {X = l.X, Y = l.Y}, stuck = 0, glide = false}
  return move_to(BOT, dest, BG.accept)
end
LoopAsync(100, function()
  ExecuteInGameThread(function() pcall(function()
    if not BG then return end
    if not valid(BOT) then BG = nil; return end
    local l = loc(BOT); local dx, dy = BG.dest.X - l.X, BG.dest.Y - l.Y; local d = math.sqrt(dx*dx + dy*dy)
    if d <= BG.accept + 30 then log(string.format("bot arrived %.0f,%.0f glide=%s", l.X, l.Y, tostring(BG.glide))); BG = nil; return end
    BG.t = BG.t + 1
    if BG.glide then
      local st = math.min(60, d); BOT:K2_SetActorLocation({X = l.X + dx/d*st, Y = l.Y + dy/d*st, Z = l.Z + (BG.dest.Z + 90 - l.Z) * st/d}, false, {}, true)
    elseif BG.t % 10 == 0 then
      local mv = math.sqrt((l.X-BG.last.X)^2 + (l.Y-BG.last.Y)^2); BG.last = {X = l.X, Y = l.Y}
      if mv < 50 then BG.stuck = BG.stuck + 1 else BG.stuck = 0 end
      if BG.stuck >= 2 then BG.glide = true; log(string.format("bot stuck at %.0f,%.0f (%.0f uu to go): glide", l.X, l.Y, d)) else move_to(BOT, BG.dest, BG.accept) end
    end
  end) end)
  return false
end)
function t_botgo(dx, dy)
  if not valid(BOT) then log("botgo: no bot"); return end
  -- 11-10 run 1: bot stood still (not in crew, so the MOVE_None fix in tick() never touched it)
  pcall(function() local cm = BOT.CharacterMovement; if not cm:IsComponentTickEnabled() then cm:SetComponentTickEnabled(true) end; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0) end end)
  local l = loc(BOT); local ok, r, direct = bot_goal({X=l.X+dx, Y=l.Y+dy, Z=l.Z-90}, 50.0)
  log(string.format("botgo %.0f %.0f from %.0f,%.0f ok=%s r=%s direct=%s ctrl=%s", dx, dy, l.X, l.Y, tostring(ok), tostring(r), tostring(direct), tostring(valid(BOT.Controller))))
end
-- 11-10 run 2: botgo offsets had no navmesh path (direct walk stopped after ~90 uu); pick reachable points instead
function t_botfar(dist)
  if not valid(BOT) then log("botfar: no bot"); return end
  local nav = StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1"); local world = FindFirstOf("World")
  local o = loc(BOT); local best, bd = nil, 0
  for _ = 1, 12 do
    local out = {}
    local ok, hit = pcall(function() return nav:K2_GetRandomReachablePointInRadius(world, o, out, dist * 1.3, nil, nil) end)
    if ok and hit and out.X then local dd = d2(out, o); if dd > bd then best, bd = {X=out.X, Y=out.Y, Z=out.Z}, dd end end
  end
  if not best then   -- 11-11 server gym: PlayerStart area has no navmesh -> glide straight along +X instead of giving up
    bot_goal({X=o.X+dist, Y=o.Y, Z=o.Z-90}, 50.0); if BG then BG.glide = true end
    log(string.format("botfar %.0f: no reachable point, glide +X", dist)); return
  end
  pcall(function() local cm = BOT.CharacterMovement; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0) end end)
  local ok, r, direct = bot_goal(best, 50.0)
  log(string.format("botfar %.0f -> %.0f,%.0f (%.0f uu) r=%s direct=%s", dist, best.X, best.Y, math.sqrt(bd), tostring(r), tostring(direct)))
end
function t_botback()
  if not valid(BOT) then return end
  for _, m in ipairs(crew) do if m.bed and alive(m.bed) then local b = loc(m.bed); local ok, r = bot_goal({X=b.X+100, Y=b.Y, Z=b.Z}, 50.0); log("botback r=" .. tostring(r)); return end end
  log("botback: no crew bed")
end
function t_botbed(dx)
  if not valid(BOT) then log("botbed: no bot"); return end
  local cp = "/Game/Blueprints/DeployedObjects/Furniture/Deployed_Furniture_Cot_Military"
  LoadAsset(cp .. ".Deployed_Furniture_Cot_Military"); local cot = StaticFindObject(cp .. ".Deployed_Furniture_Cot_Military_C")
  local l = loc(BOT); local b = FindFirstOf("World"):SpawnActor(cot, {X=l.X+dx, Y=l.Y, Z=l.Z-90}, {Pitch=0, Yaw=0, Roll=0})
  beds_t = -100; log("botbed " .. tostring(valid(b) and b:GetFName():ToString()))
end
RegisterKeyBind(Key.F9, function() ExecuteInGameThread(function() pcall(t_spawn, 300) end) end)
RegisterKeyBind(Key.F10, function() ExecuteInGameThread(function() pcall(t_status) end) end)
-- test command file (no focus needed): lines "spawn <uu>" | "status"
local TCMD = "C:/re/abioticfactor/faircrew_cmd.txt"
LoopAsync(500, function()
  local f = io.open(TCMD, "r"); if not f then return false end
  local lines = {}; for l in f:lines() do if #l > 0 then lines[#lines+1] = l end end
  f:close(); os.remove(TCMD)
  ExecuteInGameThread(function()
    for _, l in ipairs(lines) do
      local op, n, n2 = l:match("^(%S+)%s*(%S*)%s*(%S*)")
      local ok, e = pcall(function()
        if op == "spawn" then t_spawn(tonumber(n) or 300) elseif op == "status" then t_status()
        elseif op == "bot" then t_bot(tonumber(n) or 400)                         -- bot owner in front of the player + a crew NPC next to it
        elseif op == "botgo" then t_botgo(tonumber(n) or 0, tonumber(n2) or 0)     -- walk the bot owner by an offset (AI pathing)
        elseif op == "botfar" then t_botfar(tonumber(n) or 1500)                  -- walk the bot to a navmesh-reachable point ~n uu away
        elseif op == "botback" then t_botback()                                     -- walk the bot back to its crew member's bed
        elseif op == "botbed" then t_botbed(tonumber(n) or 150) end               -- cot next to the bot owner
      end)
      if not ok then log("cmd error " .. l .. " " .. tostring(e)) end
    end
  end)
  return false
end)

selftest_load = function()   -- once the world is up
  local ps = FindFirstOf("PlayerStart"); if not valid(ps) then return end
  local ok, r = pcall(function()
    return dofile(DIR .. "selftest.lua")({crew=crew, claimed=claimed, gifts=GIFTS, spawn_one=spawn_one, log=log, loc=loc,
      set_fake=function(t) FAKE = t end, set_fake_beds=function(t) FAKE_BEDS = t end,
      set_autospawn=function(b) AUTOSPAWN = b end, beds_reset=function() beds_t = -100 end})
  end)
  if ok then SELF = r else log("selftest load error " .. tostring(r)); SELFTEST = false end
end
