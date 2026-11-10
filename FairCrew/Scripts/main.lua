-- FairCrew v0.2: random stranded scientists you can recruit as companions.
-- Folds the villager-companion AIs we studied into one small loop:
--   Animal Crossing (C:/re/animalcrossing/AI-MAP.md): home spot + idle wander, friendship that grows near you
--     and decays when you leave them, leaves (goes home) when friendship runs out.
--   Core Keeper villagers (C:/re/corekeeper/mod): small crew cap, follow the owner, return home when left.
-- Fair play: crew use the stock ally pawns (NarrativeNPC_BossAlly*) and their stock BT for combat;
-- no stat buffs, no teleports. FairSight caps their wall-tracking like everyone else.
local LOG  = (os.getenv("AF_FAIRSIGHT_TEST") == "1") and "C:/re/abioticfactor/faircrew_srv_log.txt" or "C:/re/abioticfactor/faircrew_log.txt"
local TEST = os.getenv("AF_FAIRSIGHT_TEST") == "1"   -- server test: PlayerStart stands in for a player

local CLASSES = {
  "/Game/Blueprints/Characters/NarrativeNPCs/NarrativeNPC_BossAlly",
  "/Game/Blueprints/Characters/NarrativeNPCs/NarrativeNPC_BossAlly_Heavy",
  "/Game/Blueprints/Characters/NarrativeNPCs/NarrativeNPC_BossAlly_Sniper",
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

local crew = {}        -- [i] = {pawn, home={X,Y,Z}, owner, friend 0..100, near_s, wander_t, name}
local last_spawn = -RESPAWN_S
local navlogged = false
local clock = 0

local function players()
  local out = {}
  for _, p in ipairs(FindAllOf("Abiotic_PlayerCharacter_C") or {}) do if valid(p) then out[#out+1] = p end end
  if TEST and #out == 0 then local ps = FindFirstOf("PlayerStart"); if valid(ps) then out[1] = ps end end
  return out
end

local function move_to(pawn, dest, accept)
  local c = pawn.Controller
  if not valid(c) then return end
  pcall(function() c:MoveToLocation(dest, accept, true, true, true, false, nil, true) end)
end

local function spawn_one(pl)
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
  if not l then log("spawn: no spot (spawners " .. #spots .. ")"); return end
  local path = CLASSES[math.random(#CLASSES)]
  local name = path:match("([^/]+)$")
  LoadAsset(path .. "." .. name)
  local cls = StaticFindObject(path .. "." .. name .. "_C")
  if not valid(cls) then log("spawn: no class " .. name); return end
  local a = world:SpawnActor(cls, {X=l.X, Y=l.Y, Z=l.Z+100}, {Pitch=0, Yaw=math.random(0, 359), Roll=0})
  if not valid(a) then log("spawn: failed " .. name); return end
  crew[#crew+1] = {pawn=a, home={X=l.X, Y=l.Y, Z=l.Z}, owner=nil, friend=0, near_s=0, wander_t=0, name=name}
  log(string.format("spawn %s at %.0f %.0f %.0f ctrl=%s", name, l.X, l.Y, l.Z, tostring(valid(a.Controller) and a.Controller:GetClass():GetFName():ToString())))
end

local function followers(p) local n = 0; for _, m in ipairs(crew) do if m.owner == p then n = n + 1 end end; return n end

-- held food/healing item of a player, or nil
local function held_gift(p)
  local ok, row = pcall(function() return p.CurrentItemRow:ToString() end)
  if ok and row and GIFTS[row:lower()] then return row end
end
-- take one of the held item (the gift); true if the game confirmed it
local function take_gift(p, row)
  local ok = pcall(function()
    local okh, slot = false, {}
    pcall(function() local o = {}; p:GetCurrentHeldItem(o, slot, {}, {}) ; okh = o.Success end)
    local h = slot and slot.ItemDataTable
    if not h then h = {DataTable = StaticFindObject("/Game/Blueprints/Items/ItemTable_Global.ItemTable_Global"), RowName = FName(row)} end
    p:ConsumeItemOfSpecificCount(h, 1)
  end)
  return ok
end

local beds, beds_t, claimed = {}, -100, {}   -- claimed[bed full name] = member
local function refresh_beds()
  if clock - beds_t < 10 then return end
  beds_t = clock; beds = {}
  for _, cn in ipairs(BED_CLASSES) do for _, b in ipairs(FindAllOf(cn) or {}) do if valid(b) then beds[#beds+1] = b end end end
end
local function free_bed_near(pos, r)
  for _, b in ipairs(beds) do
    local k = b:GetFullName()
    if not (claimed[k] and valid(claimed[k].pawn)) and d2(loc(b), pos) < r*r then return b, k end
  end
end

local function tick()
  clock = clock + TICK_S
  for i = #crew, 1, -1 do if not valid(crew[i].pawn) then log("lost " .. crew[i].name); if crew[i].bedkey then claimed[crew[i].bedkey] = nil end; table.remove(crew, i) end end
  local pl = players()
  if #pl == 0 then return end
  if #crew < WORLD_CAP and clock - last_spawn >= RESPAWN_S then last_spawn = clock; spawn_one(pl) end

  refresh_beds()
  for _, m in ipairs(crew) do
    local here = loc(m.pawn)
    if m.owner and not valid(m.owner) then m.owner = nil end
    if not m.owner then
      -- idle: AC-style wander around home; recruit when a player lingers close
      local best, bd
      for _, p in ipairs(pl) do local dd = d2(here, loc(p)); if not bd or dd < bd then best, bd = p, dd end end
      local gift = best and held_gift(best)
      if bd and bd < RECRUIT_UU*RECRUIT_UU and gift and followers(best) < PER_PLAYER then
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
    ticks = ticks + 1
    if ticks % 20 == 0 then
      local parts = {}
      for _, m in ipairs(crew) do local l = loc(m.pawn); parts[#parts+1] = string.format("%s[%s f=%.0f %.0f,%.0f]", m.name:gsub("NarrativeNPC_", ""), m.owner and "follow" or (m.bed and "home" or "idle"), m.friend, l.X, l.Y) end
      log("crew " .. #crew .. " " .. table.concat(parts, " "))
    end
  end)
  return false
end)
