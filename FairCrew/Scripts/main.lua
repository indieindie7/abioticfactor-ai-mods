-- FairCrew v0.2: random stranded scientists you can recruit as companions.
-- Folds the villager-companion AIs we studied into one small loop:
--   Animal Crossing villagers: home spot + idle wander, friendship that grows near you
--     and decays when you leave them, leaves (goes home) when friendship runs out.
--   Core Keeper villagers: small crew cap, follow the owner, return home when left.
-- Fair play: crew are player-pipeline bodies (Abiotic_PlayerCharacter_C + the stock AI controller, random look), no player-only powers;
-- no stat buffs. A crew body's position is set directly in two places only: the ladder rise (small steps) and once at spawn
-- when the body comes up more than 500 uu from its spot (test commands aside). FairSight caps their wall-tracking like everyone else.
local SELFTEST = os.getenv("AF_FAIRCREW_SELFTEST") == "1"   -- scripted self-test, see selftest.lua
local LOG  = (os.getenv("AF_FAIRSIGHT_TEST") == "1" or SELFTEST) and "C:/re/abioticfactor/faircrew_srv_log.txt" or "C:/re/abioticfactor/faircrew_log.txt"
local TEST = os.getenv("AF_FAIRSIGHT_TEST") == "1"   -- server test: PlayerStart stands in for a player

-- crew body: made with the player character pipeline so it can move freely like a player
local BODY_CLASS = "/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C"
local LOOK_PARTS = {"Head","HairStyle","HairColor","HeadAccessory","UpperBody","LowerBody","ShirtColor","Shoes","Tie"}
local OURS = {}          -- address -> true for bodies we spawned: they are not players
local crew_seq = 0
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
-- needs: the crew decide whether to join or keep following by how well rested and fed they are
local REST_UP_S     = 6      -- seconds per +1 rest while at home near the own bed (0 -> 100 in 10 min)
local REST_DOWN_S   = 18     -- seconds per -1 rest while following (100 -> 0 in 30 min)
local FED_DOWN_S    = 30     -- seconds per -1 fed, always (100 -> 0 in 50 min)
local GIFT_FED      = 40     -- a gift item adds this much fed (gifts.lua does not split food from healing yet)
local JOIN_REST     = 60     -- settled crew joins the owner only when rest >= this ...
local JOIN_FED      = 40     -- ... and fed >= this (a gift is eaten first when hungry)
local QUIT_NEED     = 15     -- a follower with a bed walks home when rest or fed drops below this
-- jobs: porter and guard, kept small (docs/crew_jobs_plan.md sections 9 + 10)
local JOB_DRAIN     = {porter = 1.5, guard = 1.2}   -- rest drain multiplier while working
local BAG_CAP       = 12     -- items a porter carries
local BASE_UU       = 800    -- owner this close to the porter's bed = "back at base", porter unloads
local BOX_UU        = 1500   -- storage box this close to the porter's bed is used
local GUARD_UU      = 1500   -- guard reacts to an enemy this close to its bed
local GUARD_STEP    = 400    -- guard stands at most this far out from the bed, on the line bed -> enemy
local BED_WANDER_UU = 400    -- settled scientists wander this close to their bed
local BED_CLASSES = {"Deployed_Furniture_Bed_ParentBP_C", "Deployed_Furniture_Cot_Military_C", "Deployed_VOTV_Mattress_C", "Deployed_VOTV_SleepingBag_C"}
local DIR = (debug.getinfo(1, "S").source:match("^@(.*)main%.lua$") or "")
local GIFTS = dofile(DIR .. "gifts.lua")   -- food + healing item rows (lower-case)

local function log(s) local f = io.open(LOG, "a"); if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end end
log("loaded" .. (TEST and " (server test)" or ""))

-- crash breadcrumb: last step reached, read after a client crash (C:/re/abioticfactor/faircrew_crumb.txt)
local CRUMBS = false     -- true while hunting a client crash
local function crumb(c) if not CRUMBS then return end; local f = io.open("C:/re/abioticfactor/faircrew_crumb.txt", "w"); if f then f:write(os.date("%H:%M:%S ") .. c); f:close() end end
local function loc(a) return a:K2_GetActorLocation() end
local function d2(a, b) local x, y, z = a.X-b.X, a.Y-b.Y, a.Z-b.Z; return x*x+y*y+z*z end
local function valid(o) return o and o:IsValid() end
local function alive(a)   -- a destroyed actor stays IsValid until garbage collection
  if not valid(a) then return false end
  crumb("alive dying"); local ok, dying = pcall(function() return a:IsActorBeingDestroyed() end)
  if ok and dying then return false end
  crumb("alive root"); local ok2, root = pcall(function() return a.RootComponent end)
  return ok2 and valid(root)
end

local crew = {}        -- [i] = {pawn, home={X,Y,Z}, owner, friend 0..100, near_s, wander_t, name}
local last_spawn = -RESPAWN_S
local navlogged = false
local movelog = 0
local clock = 0
local FAKE, FAKE_BEDS, AUTOSPAWN, SELF = nil, nil, true, nil   -- self-test hooks
local selftest_load
local BOTGIFT = true   -- test: bot owner holds a virtual gift (command "botgift 0|1")
local BODY = nil
local ROWS = nil
local BOT = nil   -- agent-vs-agent test: an NPC plays the owner (has a virtual gift), no player input needed

local function players()
  if FAKE then return FAKE end
  if BOT then return valid(BOT) and {BOT} or {} end
  local out = {}
  for _, p in ipairs(FindAllOf("Abiotic_PlayerCharacter_C") or {}) do if valid(p) and not OURS[string.format("%x", p:GetAddress())] then out[#out+1] = p end end
  if TEST and #out == 0 then local ps = FindFirstOf("PlayerStart"); if valid(ps) then out[1] = ps end end
  return out
end

local function move_to(pawn, dest, accept, straight)
  crumb("move_to controller"); local c = pawn.Controller
  if not valid(c) then return end
  crumb("move_to MoveToLocation path")
  -- EPathFollowingRequestResult: 0 Failed, 1 AlreadyAtGoal, 2 RequestSuccessful
  local ok, r = false, 0
  if not straight then ok, r = pcall(function() return c:MoveToLocation(dest, accept, true, true, true, false, nil, true) end) end
  local direct = false
  if not ok or r == 0 then   -- no path (no navmesh here): walk straight instead of standing still
    direct = true; crumb("move_to MoveToLocation direct")
    ok, r = pcall(function() return c:MoveToLocation(dest, accept, true, false, false, false, nil, true) end)
  end
  if SELFTEST and movelog < 6 then movelog = movelog + 1; log("move ok=" .. tostring(ok) .. " r=" .. tostring(r) .. " direct=" .. tostring(direct)) end
  crumb("move_to done"); return ok, r, direct
end

local function load_rows()   -- row names of the customization tables, once
  if ROWS then return ROWS end
  local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary"); local R = {}
  for _, t in ipairs(LOOK_PARTS) do
    local dt = StaticFindObject("/Game/Blueprints/DataTables/Customization/DT_Customization_" .. t .. ".DT_Customization_" .. t); local names = {}
    if valid(dt) then local out = {}; crumb("rows " .. t)
      local ok, e = pcall(function() lib:GetDataTableRowNames(dt, out) end); if not ok then log("rows " .. t .. " ERR " .. tostring(e):sub(-80)) end
      local et, cnt = "none", 0
      for _, v in pairs(out) do local nm; et = type(v); cnt = cnt + 1
        if et == "string" then nm = v else pcall(function() nm = v:ToString() end); if not nm then pcall(function() nm = v:get():ToString() end) end end
        if nm then names[#names+1] = nm end end
      log(string.format("rows %s ok=%s out=%d elem=%s names=%d", t, tostring(ok), cnt, et, #names))
    else log("rows: no table " .. t) end
    R[t] = {dt = dt, names = names}
  end
  ROWS = R; return R
end
-- random look: write a row on the body's HumanCustomizationComponent, then call that part's own OnRep (never Server_ApplyAllCustomizationData: hangs the pump)
local function random_look(a)
  local comp = a.HumanCustomizationComponent; if not valid(comp) then return "no component" end
  local rows, said = load_rows(), {}
  for _, t in ipairs(LOOK_PARTS) do
    local r = rows[t]
    if r and #r.names > 0 then local pick = r.names[math.random(#r.names)]; crumb("look " .. t)
      local ok, e = pcall(function() comp["Customization_" .. t].RowName = FName(pick); comp["OnRep_Customization_" .. t](comp) end)
      said[#said+1] = ok and (t .. "=" .. pick) or (t .. " ERR " .. tostring(e):sub(-60))
    end
  end
  crumb("look done"); return table.concat(said, " ")
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
  crew_seq = crew_seq + 1
  local name = as_bot and "BotOwner" or ("Crew" .. crew_seq)
  local cls = StaticFindObject(BODY_CLASS)
  if not valid(cls) then log("spawn: no class " .. name); return end
  local a = world:SpawnActor(cls, {X=l.X, Y=l.Y, Z=l.Z+100}, {Pitch=0, Yaw=math.random(0, 359), Roll=0})
  if not valid(a) then log("spawn: failed " .. name); return end
  -- 11-11 client: first scripted spawn came up at 0,0,0 (crew then spawned at "150 0 -100" and was lost): put it where it was asked
  pcall(function() local al = loc(a); if d2(al, {X=l.X, Y=l.Y, Z=l.Z+100}) > 500*500 then a:K2_SetActorLocation({X=l.X, Y=l.Y, Z=l.Z+100}, false, {}, true); log(string.format("spawn fixup from %.0f,%.0f,%.0f", al.X, al.Y, al.Z)) end end)
  OURS[string.format("%x", a:GetAddress())] = true
  if not valid(a.Controller) then pcall(function() a:SpawnDefaultController() end) end   -- a scripted player body has no controller: gives Abiotic_AI_Controller_ParentBP_C
  log("look " .. name .. " " .. random_look(a))
  -- 11-11: the game builds navmesh only around navigation invokers (bGenerateNavigationOnlyAroundNavigationInvokers = true, RuntimeGeneration Dynamic).
  -- TEST/bot mode only: make spawned NPCs invokers so they can path away from any player (gym, dedicated server).
  if as_bot or BOT or TEST then
    local okr, er = pcall(function() StaticFindObject("/Script/NavigationSystem.Default__NavigationSystemV1"):RegisterNavigationInvoker(a, 3000.0, 5000.0) end)
    log("nav invoker " .. tostring(okr) .. (okr and "" or (" " .. tostring(er))))
  end
  if as_bot then BOT = a; AUTOSPAWN = false; log(string.format("bot owner %s at %.0f %.0f", name, l.X, l.Y)); return a end
  crew[#crew+1] = {pawn=a, home={X=l.X, Y=l.Y, Z=l.Z}, owner=nil, friend=0, near_s=0, wander_t=0, name=name, rest=50, fed=50, bag={}, bagn=0}
  log(string.format("spawn %s at %.0f %.0f %.0f ctrl=%s", name, l.X, l.Y, l.Z, tostring(valid(a.Controller) and a.Controller:GetClass():GetFName():ToString())))
end

local function followers(p) local n = 0; for _, m in ipairs(crew) do if m.owner == p then n = n + 1 end end; return n end

-- held food/healing item of a player, or nil
local function held_gift(p)
  if p == BOT then return BOTGIFT and "Bandage" or nil end
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
-- 11-12: b:GetFullName() on a bed from FindAllOf crashed the client inside UE4SS (access violation, stress run 3,
-- crumb "beds GetFullName"); the key is now the object address, which touches no engine data
local function bed_key(b) return string.format("%x", b:GetAddress()) end
local function refresh_beds()
  -- every tick (was 10 s): a cached bed actor can go stale when its area streams out/in (crash 4, 11-10)
  if clock - beds_t < TICK_S * 0.5 then return end
  beds_t = clock; beds = {}
  local seen = {}   -- parent + child bed classes both list the same actor
  for _, cn in ipairs(BED_CLASSES) do crumb("beds FindAllOf " .. cn); for _, b in ipairs(FindAllOf(cn) or {}) do if alive(b) then crumb("beds key"); local k = bed_key(b); if not seen[k] then seen[k] = true; beds[#beds+1] = b end end end end
  for _, b in ipairs(FAKE_BEDS or {}) do beds[#beds+1] = b end
end
local function free_bed_near(pos, r)
  for _, b in ipairs(beds) do
    crumb("fb alive"); if FAKE_BEDS or alive(b) then
      crumb("fb name"); local k = bed_key(b)
      crumb("fb loc")
      if not (claimed[k] and valid(claimed[k].pawn)) and d2(loc(b), pos) < r*r then return b, k end
    end
  end
end

-- ---- jobs ----
-- Porter v1: the bag is a mod-side list (row -> count). Only the bot owner can hand items over (virtual held item,
-- command "bothold"): taking real items from a player is OFF until a tested call exists that puts them into a box.
-- The box is a ledger too (BOXES); what is tested is the behaviour: carry, walk to the box at base, unload.
-- 11-13 real items: engine inventory calls (each probed alone first; pattern = AfPilot give).
local ITEMTABLE = "/Game/Blueprints/Items/ItemTable_Global.ItemTable_Global"
local function item_row(name) return {DataTable = StaticFindObject(ITEMTABLE), RowName = FName(name)} end
local function inv_weight(inv) return valid(inv) and inv.CurrentTotalInventoryWeight or -1 end
local function inv_put(inv, name, n)      -- place n of a row, slot by slot ('Try Place Item in Inventory' refuses from Lua); returns all placed, remaining
  local slots = inv.CurrentInventory:GetArrayNum()
  for i = 0, slots - 1 do
    local r1, r2 = {}, {}
    crumb("inv_put " .. name .. " x" .. n .. " slot " .. i)
    inv:TryPlaceIteminInventorySlot(item_row(name), {CurrentStack = n, CurrentItemDurability = 100, MaxItemDurability = 100}, i, false, false, r1, r2, {})
    crumb("inv_put done")
    if r2.Success then n = r1.Remaining or 0; if n <= 0 then return true, 0 end end
  end
  return false, n
end
local function inv_slots(inv)             -- "row x stack" per used slot (read of the replicated array)
  local t = {}
  for i = 1, inv.CurrentInventory:GetArrayNum() do
    local okr, txt = pcall(function() local e = inv.CurrentInventory[i]; local st = e.ChangeableData.CurrentStack
      if st and st > 0 then return (i - 1) .. ":" .. e.ItemDataTable.RowName:ToString() .. "x" .. st end end)
    if not okr then t[#t+1] = "err " .. tostring(txt):sub(-60); break elseif txt then t[#t+1] = txt end
  end
  return table.concat(t, " ")
end
local function inv_take(inv, name, n)     -- remove n of a row from an inventory; returns the engine's count value
  crumb("inv_take " .. name .. " x" .. n)
  inv["Remove Item from Inventory"](inv, item_row(name), false, n)
  crumb("inv_take done")
  return n
end
local function first_box() for _, b in ipairs(FindAllOf("Deployed_Container_ParentBP_C") or {}) do if alive(b) then return b end end end
local function own_inv(which) local pc0 = FindFirstOf("PlayerController"); local p = pc0 and pc0.Pawn; if not valid(p) then return nil end
  return which == "hot" and p.CharacterHotbarInventory or p.CharacterInventory end
local HAND_UU = 450      -- porter takes items from an owner this close (above FOLLOW_UU 400: a follower stops before RECRUIT_UU)
local HAUL = "scrap_"    -- a real owner hands over rows with this prefix (test: haul <prefix>)
local function haul_row(inv)              -- first row in an inventory that the porter carries
  for i = 1, inv.CurrentInventory:GetArrayNum() do
    local e = inv.CurrentInventory[i]; local st = e.ChangeableData.CurrentStack
    if st and st > 0 then local r = e.ItemDataTable.RowName:ToString(); if r:sub(1, #HAUL):lower() == HAUL:lower() then return r end end
  end
end
local BOTHOLD = nil    -- {row=, n=}
local BOXES = {}       -- [box key] = {row = n}
local function porter_item(p)
  if p == BOT then if BOTHOLD and BOTHOLD.n > 0 then return BOTHOLD.row end; return nil end
  local inv = p.CharacterInventory; if valid(inv) then return haul_row(inv) end
end
local function porter_step(m, here, o, dd)   -- true = porter is busy walking to the box (no follow move this tick)
  m.bag = m.bag or {}; m.bagn = m.bagn or 0
  if m.bagn > 0 and m.last then m.walk = (m.walk or 0) + math.sqrt(d2(here, m.last)) end
  m.last = {X=here.X, Y=here.Y, Z=here.Z}
  local row = dd < HAND_UU*HAND_UU and m.bagn < BAG_CAP and not m.unload and not m.boxfail and porter_item(m.owner) or nil
  if row and dd < HAND_UU*HAND_UU and m.bagn < BAG_CAP and not m.unload then
    m.give_s = (m.give_s or 0) + TICK_S
    if m.give_s >= RECRUIT_S then
      m.give_s = 0; local left = -1
      if m.owner == BOT then BOTHOLD.n = BOTHOLD.n - 1; left = BOTHOLD.n else inv_take(m.owner.CharacterInventory, row, 1) end   -- player: a real item leaves the inventory
      m.bag[row] = (m.bag[row] or 0) + 1; m.bagn = m.bagn + 1
      log(string.format("porter %s took %s bag=%d owner has %d left%s", m.name, row, m.bagn, left, m.owner == BOT and "" or " (real item)"))
    end
  else m.give_s = 0 end
  if m.boxfail and clock >= m.boxfail then m.boxfail = nil end
  if m.bagn > 0 and not m.boxfail and m.bed and d2(o, m.home) < BASE_UU*BASE_UU then
    local box, bd
    for _, b in ipairs(FindAllOf("Deployed_Container_ParentBP_C") or {}) do
      if alive(b) then local x = d2(loc(b), m.home); if x < BOX_UU*BOX_UU and (not bd or x < bd) then box, bd = b, x end end
    end
    if not box then if not m.nobox then m.nobox = true; log("porter " .. m.name .. ": no box near home, keeps carrying") end; m.unload = nil; return false end
    m.nobox = nil
    local bl = loc(box); local gx, gy = here.X-bl.X, here.Y-bl.Y; local gap = math.sqrt(gx*gx+gy*gy)   -- flat distance: box origin sits at floor height
    if gap < 220 then
      local k = bed_key(box); BOXES[k] = BOXES[k] or {}
      local kept, keep = 0, {}     -- real items go into the chest's inventory; BOXES counts what was placed
      for r, n in pairs(m.bag) do
        local okp, rem = inv_put(box.ContainerInventory, r, n); if okp then rem = 0 end
        if n - rem > 0 then BOXES[k][r] = (BOXES[k][r] or 0) + n - rem end
        if rem > 0 then keep[r] = rem; kept = kept + rem end
      end
      log(string.format("porter %s unloaded %d real items into box %s, walked %.0f uu with load%s", m.name, m.bagn - kept, k, m.walk or 0,
        kept > 0 and string.format(", keeps %d (box full or unknown row)", kept) or ""))
      m.bag, m.bagn, m.walk, m.unload, m.ugap, m.ustall = keep, kept, 0, nil, nil, nil
      if kept > 0 then
        m.boxfail = clock + 60                  -- box full: no taking and no retry for a minute
        if m.owner ~= BOT and valid(m.owner) and valid(m.owner.CharacterInventory) then     -- a real owner gets the rest back
          for r, n in pairs(keep) do
            local okp, rem = inv_put(m.owner.CharacterInventory, r, n); if okp then rem = 0 end
            keep[r] = rem > 0 and rem or nil; m.bagn = m.bagn - (n - rem)
            log(string.format("porter %s gave back %d %s to the owner, still holds %d", m.name, n - rem, r, rem))
          end
        end
      end
      return false
    end
    if not m.unload then m.unload = true; log(string.format("porter %s unload start: box %.0f uu away, bag=%d", m.name, gap, m.bagn)) end
    local ok, r, direct = move_to(m.pawn, {X=bl.X, Y=bl.Y, Z=here.Z}, 100.0)
    if m.ugap and m.ugap - gap < 20 then m.ustall = (m.ustall or 0) + 1 else m.ustall = 0 end
    m.ugap = gap
    if m.ustall == 8 then log(string.format("porter %s stalled %.0f uu from box (move r=%s direct=%s), keeps trying", m.name, gap, tostring(r), tostring(direct))) end
    return true
  end
  m.unload, m.ugap, m.ustall = nil, nil, nil
  return false
end

-- Guard v1: no damage. With an enemy inside GUARD_UU of its bed it stands on the line bed -> enemy.
-- motion layer (11-13): humanlike moves. mo_go starts or updates a walk goal with a gait speed; mo_step (every 0.1 s)
-- notices a blocked walk (no progress for 0.5 s, not falling) and tries in turn: jump, crouch for 3 s, forward launch.
local STROLL, JOG, SPRINT = 190, 500, 685
local PKO = nil
local MO = {}
local CL = {}                      -- pawns on a ladder: key -> {p, lad, top, rate, dx, dy, t_end}
local XLAD = {}                    -- test ladders (parkour course)
local LADS, LADS_T = {}, -100
-- nearest ladder volume centre within 1500 uu (list refreshed at most every 10 s, only asked when a goal is above)
local function near_ladder(l)
  local now = os.clock()
  if now - LADS_T > 10 then
    LADS_T = now; LADS = {}
    for _, cn in ipairs({"Deployed_Ladder_ParentBP_C", "Ladder_Generic_C"}) do
      crumb("ladders FindAllOf"); local ok, a = pcall(FindAllOf, cn)
      if ok and a then for _, x in ipairs(a) do if valid(x) then LADS[#LADS + 1] = x end end end
    end
    for _, x in ipairs(XLAD) do if valid(x) then LADS[#LADS + 1] = x end end
    crumb("ladders done")
  end
  local best, bc, bd = nil, nil, 1500 * 1500
  for _, x in ipairs(LADS) do
    if valid(x) then
      local ok, c = pcall(function() return x.LadderVolume:K2_GetComponentLocation() end)
      if ok and c then local d = (c.X - l.X)^2 + (c.Y - l.Y)^2; if d < bd then best, bc, bd = x, c, d end end
    end
  end
  return best, bc, math.sqrt(bd)
end
local MVCREW = false
local MVSPD, MVSECS = 500, 14
local MVSTRAIGHT = true
local function MB() return (MVCREW and crew[1] and crew[1].pawn) or BODY end
-- walk speed lever (probe 3): BaseWalkSpeed / CurrentWalkSpeed on the body; MaxWalkSpeed is ignored by this game.
-- Sprint(bool) does nothing on an AI body; ToggleSprint does (probe 1: 685 uu/s).
local function set_gait(p, spd)
  local base = math.min(spd, JOG)
  if p.BaseWalkSpeed ~= base then p.BaseWalkSpeed = base end
  if p.CurrentWalkSpeed ~= base then p.CurrentWalkSpeed = base end
  local want = spd > JOG
  if p:IsSprinting() ~= want then crumb("gait ToggleSprint"); p:ToggleSprint(); crumb("gait done") end
end
local mo_go
mo_go = function(pawn, dest, accept, spd, straight)
  local k = string.format("%x", pawn:GetAddress()); local s = MO[k]
  if not s then s = {pawn = pawn, last = loc(pawn), still = 0, tries = 0}; MO[k] = s end
  if not s.dest or (s.dest.X - dest.X)^2 + (s.dest.Y - dest.Y)^2 > 200*200 then s.dbest = nil end
  s.dest, s.accept, s.spd, s.straight = dest, accept, spd or JOG, straight
  s.t = os.clock(); s.keep = straight   -- crew entries must be refreshed by the tick; a stale one is dropped (no hops while standing at home)
  local ok, e = pcall(set_gait, pawn, s.spd); if not ok and not s.gerr then s.gerr = true; log("gait ERR " .. tostring(e):sub(-90)) end
  if CL[k] then return true, 2, true end
  local l = loc(pawn)
  if dest.Z - l.Z > 150 then          -- goal is above: use a ladder when one is near
    local lad, c, dd = near_ladder(l)
    if lad then
      s.lad_t = os.clock() + 0.5
      if dd < 45 then
        if not pawn.ClimbingLadder then crumb("mo ladder overlap"); pcall(function() lad:Server_ProcessLadderVolumeOverlap(pawn, true) end); crumb("mo done") end
        local ex, ey = dest.X - l.X, dest.Y - l.Y; local en = math.max(1, math.sqrt(ex*ex + ey*ey))
        CL[k] = {p = pawn, lad = lad, top = dest.Z + 10, rate = 14, dx = ex/en*300, dy = ey/en*300, t_end = os.clock() + 12}
        log(string.format("mo ladder climb from %.0f to %.0f climbing=%s", l.Z, dest.Z + 10, tostring(pawn.ClimbingLadder)))
        return true, 2, true
      end
      return move_to(pawn, {X = c.X, Y = c.Y, Z = l.Z}, 5.0, true)
    end
  end
  return move_to(pawn, dest, accept, straight)
end
local function mo_step()
  for k, s in pairs(MO) do
    local ok, e = pcall(function()
      if not alive(s.pawn) then MO[k] = nil; return end
      local p = s.pawn; local l = loc(p); local now = os.clock()
      local dx, dy = s.dest.X - l.X, s.dest.Y - l.Y; local d = math.sqrt(dx*dx + dy*dy)
      if s.crouch_t and now >= s.crouch_t then s.crouch_t = nil; p:UnCrouch(false) end
      if CL[k] then s.still = 0; s.last = l; return end
      if s.lad_t and now >= s.lad_t then s.lad_t = nil; mo_go(p, s.dest, s.accept, s.spd, s.straight); s.last = l; return end
      if s.hop_t and now >= s.hop_t and d > 1 then s.hop_t = nil; crumb("mo hop"); p:LaunchCharacter({X = dx/d*320, Y = dy/d*320, Z = 0}, true, false); crumb("mo hop done") end
      local falling = p.CharacterMovement.MovementMode == 3
      if s.air and not falling then crumb("mo land reissue"); move_to(p, s.dest, s.accept, true); crumb("mo done") end   -- a launch drops the move request
      s.air = falling
      if not s.dbest or d < s.dbest - 80 then s.dbest = d; s.tries = 0 end                                              -- progress: start the ladder of tries again
      if not s.keep and now - (s.t or now) > 4 then MO[k] = nil; return end
      if d <= s.accept + (s.keep and 40 or 120) then
        if s.crouch_t then p:UnCrouch(false) end
        if s.tries > 0 then log(string.format("mo arrived after %d tries", s.tries)) end
        MO[k] = nil; return
      end
      local step = math.sqrt((l.X - s.last.X)^2 + (l.Y - s.last.Y)^2); s.last = l
      local cm = p.CharacterMovement
      if cm.MovementMode == 3 or step > 3 or (s.rest_t and now < s.rest_t) then s.still = 0; return end
      s.still = s.still + 1
      if s.still < 5 then return end
      s.still = 0; s.tries = s.tries + 1
      if s.tries > 8 then log(string.format("mo gave up d=%.0f", d)); s.tries = 0; s.rest_t = now + 20; return end
      local t = s.tries % 3; local what
      if t == 1 then crumb("mo Jump"); p:Jump(); s.hop_t = now + 0.22; what = "jump"
      elseif t == 2 then crumb("mo Crouch"); p:Crouch(false); s.crouch_t = now + 3; what = "crouch"
      else crumb("mo Launch"); p:LaunchCharacter({X = 0, Y = 0, Z = 520}, true, true); s.hop_t = now + 0.25; what = "launch" end
      log(string.format("mo blocked try %d %s d=%.0f at %.0f,%.0f,%.0f", s.tries, what, d, l.X, l.Y, l.Z))
      crumb("mo reissue"); move_to(p, s.dest, s.accept, s.straight or s.tries % 2 == 1); crumb("mo done")
    end)
    if not ok then log("mo ERR " .. tostring(e):sub(-90)); MO[k] = nil end
  end
end

local function enemy_near(m)
  local skip = {}
  for _, c in ipairs(crew) do skip[bed_key(c.pawn)] = true end
  if valid(BOT) then skip[bed_key(BOT)] = true end
  local best, bd, bn
  for _, e in ipairs(FindAllOf("NPC_Base_ParentBP_C") or {}) do
    if alive(e) and not skip[bed_key(e)] then
      local okc, cn = pcall(function() return e:GetClass():GetFName():ToString() end)
      if okc and cn and not cn:find("NarrativeNPC") then
        local dd = d2(loc(e), m.home)
        if dd < GUARD_UU*GUARD_UU and (not bd or dd < bd) then best, bd, bn = e, dd, cn end
      end
    end
  end
  return best, bd, bn
end
local function guard_step(m, here)
  local e, dd, cn = enemy_near(m)
  if not e then if m.post then m.post = nil; m.wander_t = 0; log("guard clear " .. m.name) end; return end
  local el = loc(e); local d = math.sqrt(dd); local s = math.min(GUARD_STEP, d*0.5) / math.max(d, 1)
  local post = {X=m.home.X + (el.X-m.home.X)*s, Y=m.home.Y + (el.Y-m.home.Y)*s, Z=m.home.Z}
  move_to(m.pawn, post, 50.0); m.wander_t = clock + 6
  if not m.post or clock - (m.post_t or 0) >= 6 then
    m.post_t = clock
    local dx, dy = here.X-post.X, here.Y-post.Y
    log(string.format("guard post %s: enemy %s %.0f uu from bed, post %.0f,%.0f, crew %.0f uu off post", m.name, cn, d, post.X, post.Y, math.sqrt(dx*dx+dy*dy)))
  end
  m.post = post
end

local function tick()
  clock = clock + TICK_S
  crumb("t alive"); for i = #crew, 1, -1 do if not alive(crew[i].pawn) then log("lost " .. crew[i].name); if crew[i].bedkey then claimed[crew[i].bedkey] = nil end; table.remove(crew, i) end end
  for _, m in ipairs(crew) do   -- a spawned NPC can start in MOVE_None (0) or with its movement tick off, and then never walks
    crumb("t modefix"); pcall(function() local cm = m.pawn.CharacterMovement; if not cm:IsComponentTickEnabled() then cm:SetComponentTickEnabled(true) end; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0) end end)
  end
  crumb("t players"); local pl = players()
  if #pl == 0 then return end
  crumb("t spawn")
  if AUTOSPAWN and #crew < WORLD_CAP and clock - last_spawn >= RESPAWN_S then last_spawn = clock; spawn_one(pl) end

  crumb("t beds"); refresh_beds()
  for _, m in ipairs(crew) do
    if MVCREW and m == crew[1] then goto skip end
    crumb("t m loc"); local here = loc(m.pawn)
    crumb("t m owner")
    if m.owner and not valid(m.owner) then m.owner = nil end
    m.fed = math.max(0, m.fed - TICK_S/FED_DOWN_S)
    local on_guard = m.job == "guard" and m.bed and not m.owner and not m.off
    if m.owner then m.rest = math.max(0, m.rest - TICK_S/REST_DOWN_S * (JOB_DRAIN[m.job or ""] or 1))
    elseif on_guard then m.rest = math.max(0, m.rest - TICK_S/REST_DOWN_S * JOB_DRAIN.guard)   -- on duty = no rest
    elseif m.bed and d2(here, m.home) < 600*600 then m.rest = math.min(100, m.rest + TICK_S/REST_UP_S) end
    if m.job == "guard" and m.bed and not m.owner then
      if not m.off and (m.rest < QUIT_NEED or m.fed < QUIT_NEED) then
        m.off = true; on_guard = false; m.post = nil; m.wander_t = 0
        log(string.format("guard off duty %s: %s rest=%.0f fed=%.0f", m.name, m.rest < QUIT_NEED and "tired" or "hungry", m.rest, m.fed))
      elseif m.off and m.rest >= JOIN_REST and m.fed >= JOIN_FED then m.off = false; log("guard back on duty " .. m.name) end
    end
    if on_guard then crumb("t m guard"); guard_step(m, here) end
    if not m.owner then
      -- idle: AC-style wander around home; recruit when a player lingers close
      local best, bd
      crumb("t m nearest"); for _, p in ipairs(pl) do local dd = d2(here, loc(p)); if not bd or dd < bd then best, bd = p, dd end end
      crumb("t m gift"); local gift = best and held_gift(best)
      crumb("t m asked")
      -- settled crew (has a bed) decides by its needs: rested + fed joins without a gift, hungry eats the gift first, tired refuses
      local asked = bd and bd < RECRUIT_UU*RECRUIT_UU and (gift or m.bed) and followers(best) < PER_PLAYER and clock >= (m.recruit_cd or 0)
      if asked then
        m.near_s = m.near_s + TICK_S
        if m.near_s >= RECRUIT_S and m.bed then
          local why
          if m.rest < JOIN_REST then why = "tired"
          elseif m.fed < JOIN_FED and not gift then why = "hungry" end
          if why then
            m.near_s = 0; m.recruit_cd = clock + 30
            log(string.format("declined %s: %s rest=%.0f fed=%.0f", m.name, why, m.rest, m.fed))
          end
        end
        if m.near_s >= RECRUIT_S then
          local took = false
          if gift and (not m.bed or m.fed < JOIN_FED) then took = take_gift(best, gift); m.fed = math.min(100, m.fed + GIFT_FED) end
          gift = gift or "no gift"
          m.owner = best; m.settled = false; m.friend = math.min(100, math.max(m.friend, 50) + 10); m.near_s = 0
          log("recruited " .. m.name .. " with " .. gift .. " took=" .. tostring(took) .. " friend=" .. m.friend .. string.format(" rest=%.0f fed=%.0f", m.rest, m.fed))
        end
      else
        m.near_s = 0
        if clock >= m.wander_t then
          m.wander_t = clock + math.random(10, 20)
          local a = math.random() * 2 * math.pi; local r = math.random(m.bed and 100 or 200, m.bed and BED_WANDER_UU or WANDER_UU)
          mo_go(m.pawn, {X=m.home.X + r*math.cos(a), Y=m.home.Y + r*math.sin(a), Z=m.home.Z}, 50.0, STROLL)
        end
      end
    else
      -- following: walk after the owner; friendship grows near, decays when left behind
      crumb("t m ownerloc"); local o = loc(m.owner); local dd = d2(here, o)
      crumb("t m follow")
      crumb("t m porter"); local busy = m.job == "porter" and porter_step(m, here, o, dd)
      if not busy and dd > FOLLOW_UU*FOLLOW_UU then   -- gait by gap: stroll when close, jog, sprint pace when left behind
        mo_go(m.pawn, o, FOLLOW_UU*0.5, dd > 1400*1400 and SPRINT or (dd > 750*750 and JOG or STROLL))
      end
      if dd < 1500*1500 then m.friend = math.min(100, m.friend + TICK_S/10)
      elseif dd > LEFT_UU*LEFT_UU then m.friend = m.friend - TICK_S/2 end
      if m.bed and (m.rest < QUIT_NEED or m.fed < QUIT_NEED) then
        log(string.format("went to bed %s: %s rest=%.0f fed=%.0f", m.name, m.rest < QUIT_NEED and "tired" or "hungry", m.rest, m.fed))
        m.owner = nil; m.wander_t = 0; m.recruit_cd = clock + 30
      elseif m.friend <= 0 then
        m.owner = nil; m.friend = 0; m.wander_t = 0
        if m.bed then claimed[m.bedkey] = nil; m.bed, m.bedkey = nil, nil end
        log("went home " .. m.name)
      else
        -- move in: owner stands at a free bed with this follower close by
        crumb("t m freebed"); local b, k = free_bed_near(o, SETTLE_UU)
        crumb("t m freebed done")
        if b and dd < 800*800 then
          m.settle_s = (m.settle_s or 0) + TICK_S
          if m.settle_s >= SETTLE_S then
            if m.bedkey then claimed[m.bedkey] = nil end
            claimed[k] = m; m.bed, m.bedkey = b, k
            local bl = loc(b); m.home = {X=bl.X, Y=bl.Y, Z=bl.Z}
            m.owner = nil; m.wander_t = 0; m.settle_s = 0
            m.recruit_cd = clock + 30   -- 11-10 run: owner still holding the gift re-recruited it 6 s after move-in (ate a 2nd Bandage)
            log("moved in " .. m.name .. " bed=" .. k)
          end
        else m.settle_s = 0 end
      end
    end
    ::skip::
  end
end

local ticks = 0
local function crew_step()
  do
    crumb("tick"); local ok, err = pcall(tick); if not ok then log("tick error " .. tostring(err)) end; crumb("tick end")
    if SELFTEST and not SELF then selftest_load() end
    if SELF then local ok2, err2 = pcall(SELF, clock); if not ok2 then log("selftest error " .. tostring(err2)) end end
    ticks = ticks + 1
    if ticks % 20 == 0 then
      local parts = {}
      for _, m in ipairs(crew) do local l = loc(m.pawn); parts[#parts+1] = string.format("%s[%s f=%.0f r=%.0f h=%.0f %.0f,%.0f]", m.name:gsub("NarrativeNPC_", ""), (m.owner and "follow" or (m.bed and "home" or "idle")) .. (m.job and ("/" .. m.job .. ((m.bagn or 0) > 0 and (":" .. m.bagn) or "") .. (m.off and ":off" or "")) or ""), m.friend, m.rest, m.fed, l.X, l.Y) end
      log("crew " .. #crew .. " " .. table.concat(parts, " "))
    end
  end
end


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
  for _, m in ipairs(crew) do local l = loc(m.pawn); parts[#parts+1] = string.format("%s[%s f=%.0f r=%.0f h=%.0f %.0f,%.0f]", m.name:gsub("NarrativeNPC_", ""), (m.owner and "follow" or (m.bed and "home" or "idle")) .. (m.job and ("/" .. m.job .. ((m.bagn or 0) > 0 and (":" .. m.bagn) or "") .. (m.off and ":off" or "")) or ""), m.friend, m.rest, m.fed, l.X, l.Y) end
  local pl = p and loc(p) or {X=0, Y=0}
  local bl = {}; for _, b in ipairs(beds) do local q = loc(b); bl[#bl+1] = string.format("%.0f,%.0f,%.0f", q.X, q.Y, q.Z) end
  log(string.format("F10 me=%.0f,%.0f held=%s gift=%s beds=%d crew %d %s", pl.X, pl.Y, tostring(row), tostring(GIFTS[tostring(row):lower()] or false), #beds, #crew, table.concat(parts, " ") .. " beds@" .. table.concat(bl, ";") .. (valid(BOT) and string.format(" bot=%.0f,%.0f", loc(BOT).X, loc(BOT).Y) or "")))
end
function t_bot(dist)
  local p = me(); if not p then log("bot: no pawn"); return end
  local l = loc(p); local f = p:GetActorForwardVector()
  local b = spawn_one({p}, {X=l.X + f.X*dist, Y=l.Y + f.Y*dist, Z=l.Z}, true); if not valid(b) then return end
  -- 11-11 client runs 3+4: the first scripted spawn after level load sits at 0,0,0 and cannot be moved; a second spawn is fine
  local bl = loc(b)
  if bl.X*bl.X + bl.Y*bl.Y < 500*500 then
    log("bot spawn stuck at origin: respawn"); pcall(function() b:K2_DestroyActor() end); BOT = nil
    dist = dist - 100   -- run 5: same spot failed twice in a row, 100 uu nearer works (cause unverified: something blocks that spot)
    b = spawn_one({p}, {X=l.X + f.X*dist, Y=l.Y + f.Y*dist, Z=l.Z}, true); if not valid(b) then return end
  end
  spawn_one({b}, {X=l.X + f.X*dist + 150, Y=l.Y + f.Y*dist, Z=l.Z})
end
-- 11-11 bot walker: runs 1-4 the bot owner got r=2 from MoveToLocation and stood still. Stop its behaviour tree, re-issue the move every
-- second, and if it still has not moved 50 uu in 2 s, glide it (K2_SetActorLocation, 600 uu/s straight line; test-only, bot owner only).
local HEAD = {45, -45, 90, -90, 135, -135}   -- detour headings, degrees off the goal direction
local BG = nil   -- {dest, accept, t, last={X,Y}, stuck, glide}
local function bot_goal(dest, accept)
  if not valid(BOT) then return end
  pcall(function() local bc = BOT.Controller.BrainComponent; if valid(bc) and bc:IsRunning() then bc:StopLogic("FairCrew bot owner"); log("bot BT stopped") end end)
  pcall(function() local cm = BOT.CharacterMovement; if not cm:IsComponentTickEnabled() then cm:SetComponentTickEnabled(true) end; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0) end end)
  local l = loc(BOT); BG = {dest = dest, accept = accept or 50, t = 0, last = {X = l.X, Y = l.Y}, stuck = 0, glide = false, ndet = 0, spots = {}}
  return move_to(BOT, dest, BG.accept)
end
-- parkour course (test), fits the 1200 gym: along +Y from the spare BODY: fenced lane with a hurdle (60 uu) and a low bar (130 uu clearance), then a ladder up a 2 m platform
local LAD, LADMV = nil, nil
local function t_parkour()
  local l = loc(BODY); local g = l.Z - 90; local world = FindFirstOf("World")
  local SMA = StaticFindObject("/Script/Engine.StaticMeshActor")
  LoadAsset("/Engine/BasicShapes/Cube.Cube"); local cube = StaticFindObject("/Engine/BasicShapes/Cube.Cube")
  local n = 0
  local function box(x, y, z, sx, sy, sz)   -- centre offset from BODY's feet; engine cube is 100 uu
    local bx = world:SpawnActor(SMA, {X = l.X + x, Y = l.Y + y, Z = g + z}, {Pitch = 0, Yaw = 0, Roll = 0})
    if not valid(bx) then return end
    local c = bx.StaticMeshComponent; c:SetMobility(2); c:SetStaticMesh(cube); bx:SetActorScale3D({X = sx, Y = sy, Z = sz}); n = n + 1
  end
  PKO = {X = l.X, Y = l.Y, Z = l.Z}; LADS_T = -100
  box(0, 500, -10, 6, 13, 0.2)                                           -- own level floor (the gym floor drops 100 uu further along +Y)
  box(0, 250, 30, 5, 0.3, 0.6)                                           -- hurdle
  box(0, 550, 145, 5, 1.0, 0.3)                                          -- bar, underside 130 uu up
  box(-265, 400, 80, 0.3, 6.0, 1.6); box(265, 400, 80, 0.3, 6.0, 1.6)    -- lane fences y+100..y+700: no way around
  box(235, 900, 100, 3, 3, 2)                                            -- platform, top 200 uu up, ladder on its -X face
  local lp = "/Game/Blueprints/DeployedObjects/Furniture/Ladder_Generic"
  crumb("parkour ladder load"); LoadAsset(lp .. ".Ladder_Generic"); local lc = StaticFindObject(lp .. ".Ladder_Generic_C")
  crumb("parkour ladder spawn"); LAD = lc and world:SpawnActor(lc, {X = l.X + 60, Y = l.Y + 900, Z = g + 200}, {Pitch = 0, Yaw = 0, Roll = 0})   -- the ladder's pivot is near its top (probe 2)
  XLAD[1] = LAD; crumb("parkour done")
  log(string.format("parkour boxes=%d ladder=%s feet %.0f,%.0f,%.0f", n, tostring(valid(LAD)), l.X, l.Y, g))
end
local function mo_clear(p) if valid(p) then MO[string.format("%x", p:GetAddress())] = nil end end
local function lad_info()
  if not valid(LAD) then log("ladinfo: no ladder"); return end
  local a = loc(LAD); local out = string.format("ladinfo actor %.0f,%.0f,%.0f", a.X, a.Y, a.Z)
  pcall(function() local v = LAD.LadderVolume; local c = v:K2_GetComponentLocation(); local e = v:GetScaledBoxExtent(); out = out .. string.format(" vol %.0f,%.0f,%.0f ext %.0f,%.0f,%.0f", c.X, c.Y, c.Z, e.X, e.Y, e.Z) end)
  pcall(function() local r = LAD:K2_GetActorRotation(); out = out .. string.format(" yaw %.0f", r.Yaw) end)
  pcall(function() out = out .. " speed " .. tostring(BODY.LadderClimbSpeed) .. " climbing " .. tostring(BODY.ClimbingLadder) .. " cur " .. tostring(valid(BODY.CurrentLadder)) end)
  log(out)
end
-- Ladder climb for an AI body (probe 4): entering the ladder volume puts the body in the stock climbing state by itself
-- (ClimbingLadder true, movement mode 5), but LadderMove does nothing without a local player, so the mod raises the body itself.
local function climb_step()
 for ck, c in pairs(CL) do
  local ok, e = pcall(function()
    if not valid(c.p) or os.clock() > c.t_end then log("climb timeout/gone"); CL[ck] = nil; return end
    local l = loc(c.p)
    if l.Z < c.top then
      crumb("climb tp"); c.p:K2_TeleportTo({X = l.X, Y = l.Y, Z = l.Z + c.rate}, c.p:K2_GetActorRotation()); crumb("climb tp done")
    else
      crumb("climb exit"); c.p:ToggleLadderClimbing(false, c.lad); c.p:LaunchCharacter({X = c.dx, Y = c.dy, Z = 260}, true, true); crumb("climb exit done")
      log(string.format("climb top at %.0f,%.0f,%.0f climbing=%s", l.X, l.Y, l.Z, tostring(c.p.ClimbingLadder))); CL[ck] = nil
    end
  end)
  if not ok then log("climb ERR " .. tostring(e):sub(-90)); CL[ck] = nil end
 end
end
local function lad_step()
  climb_step()
  if not LADMV then return end
  if os.clock() >= LADMV.t_end or not valid(BODY) then LADMV = nil; return end
  local ok, e = pcall(function() BODY:LadderMove(LADMV.v) end)
  if not ok then log("ladmove ERR " .. tostring(e):sub(-90)); LADMV = nil end
end

local MV = nil   -- movement probe on the spare MB(): one sample per 0.1 s, one summary line at the end
local function mv_start(tag, secs) local l = loc(MB()); MV = {tag = tag, t_end = os.clock() + secs, last = l, z0 = l.Z, zmax = l.Z, n = 0, dist = 0, mov = 0, vmov = 0, vmax = 0, amax = 0, maxstep = 0, fall = 0, cr = 0} end
local function mv_step()
  if not MV then return end
  local ok, e = pcall(function()
    if not valid(MB()) then MV = nil; return end
    local l = loc(MB()); local s = MV
    local step = math.sqrt((l.X-s.last.X)^2 + (l.Y-s.last.Y)^2)
    s.n = s.n + 1; s.dist = s.dist + step; if step > s.maxstep then s.maxstep = step end; if step > 2 then s.mov = s.mov + 1 end
    local q = MB():GetVelocity(); local v = math.sqrt(q.X*q.X + q.Y*q.Y); if v > s.vmax then s.vmax = v end; if v > 50 then s.vmov = s.vmov + 1 end
    if l.Z > s.zmax then s.zmax = l.Z end
    local cm = MB().CharacterMovement; if cm.MovementMode == 3 then s.fall = s.fall + 1 end
    if MB().bIsCrouched then s.cr = s.cr + 1 end
    pcall(function() local sp = MB().Mesh:GetAnimInstance().Speed; if sp > s.amax then s.amax = sp end end)
    s.last = l
    if os.clock() >= s.t_end then
      log(string.format("mv %s n=%d dist=%.0f moving=%d velmoving=%d vmax=%.0f animmax=%.0f maxstep=%.0f zup=%.0f fall=%d crouched=%d mode=%d maxwalk=%.0f at %.0f,%.0f,%.0f", s.tag, s.n, s.dist, s.mov, s.vmov, s.vmax, s.amax, s.maxstep, s.zmax - s.z0, s.fall, s.cr, cm.MovementMode, cm.MaxWalkSpeed, l.X, l.Y, l.Z))
      MV = nil
    end
  end)
  if not ok then log("mv ERR " .. tostring(e):sub(-90)); MV = nil end
end

local function walk_step()
  pcall(function()
    if not BG then return end
    crumb("walk valid"); if not valid(BOT) then BG = nil; return end
    crumb("walk loc"); local l = loc(BOT); crumb("walk modefix"); local dx, dy = BG.dest.X - l.X, BG.dest.Y - l.Y; local d = math.sqrt(dx*dx + dy*dy)
    if d <= BG.accept + 30 then log(string.format("bot arrived %.0f,%.0f glide=%s t=%.1fs modefix=%d", l.X, l.Y, tostring(BG.glide), BG.t/10, BG.mfix or 0)); BG = nil; return end
    BG.t = BG.t + 1
    -- crew get this every tick() (line ~162); the bot is not in crew, and the game drops idle NPCs back to MOVE_None
    pcall(function() local cm = BOT.CharacterMovement; if not cm:IsComponentTickEnabled() then cm:SetComponentTickEnabled(true) end; if cm.MovementMode == 0 then cm:SetMovementMode(1, 0); BG.mfix = (BG.mfix or 0) + 1 end end)
    crumb("walk steer"); if BG.glide then
      local st = math.min(60, d); BOT:K2_SetActorLocation({X = l.X + dx/d*st, Y = l.Y + dy/d*st, Z = l.Z + (BG.dest.Z + 90 - l.Z) * st/d}, false, {}, true)
    elseif BG.t % 10 == 0 then
      local mv = math.sqrt((l.X-BG.last.X)^2 + (l.Y-BG.last.Y)^2); BG.last = {X = l.X, Y = l.Y}
      local D = BG.det
      if D then   -- detour leg (autonav style: candidate headings, smallest turn first, judged by measured progress)
        D.t = D.t + 1
        local gone = math.sqrt((l.X-D.from.X)^2 + (l.Y-D.from.Y)^2)
        local left = math.sqrt((l.X-D.sub.X)^2 + (l.Y-D.sub.Y)^2)
        if left < 90 or D.t >= D.lim or (D.t >= 2 and mv < 50) then
          BG.det = nil
          if gone >= 200 then
            log(string.format("bot detour %+d ok: moved %.0f of %.0f uu, %.0f to go", HEAD[D.sp.hi], gone, D.leg, d)); BG.stuck = 0; BG.ndet = BG.ndet + 1; move_to(BOT, BG.dest, BG.accept)
          else
            log(string.format("bot detour %+d blocked: moved %.0f uu", HEAD[D.sp.hi], gone)); D.sp.hi = D.sp.hi + 1; D.sp.n = 0; BG.stuck = 99
          end
        end
      else
        if mv < 50 then BG.stuck = BG.stuck + 1 else BG.stuck = 0 end
        if BG.stuck >= 4 then
          -- spot memory: stuck again where a detour was already tried -> same heading, longer leg (400, 800, 1200), then the next heading
          local sp = nil
          for _, q in ipairs(BG.spots) do if (l.X-q.X)^2 + (l.Y-q.Y)^2 < 150*150 then sp = q end end
          if sp then sp.n = sp.n + 1; if sp.n > 2 then sp.n = 0; sp.hi = sp.hi + 1 end
          else sp = {X = l.X, Y = l.Y, hi = 1, n = 0}; BG.spots[#BG.spots + 1] = sp end
          if sp.hi > #HEAD or BG.ndet >= 16 then
            BG.glide = true; log(string.format("bot stuck at %.0f,%.0f (%.0f uu to go, mode fixes %d, detours ok %d, spots %d): glide", l.X, l.Y, d, BG.mfix or 0, BG.ndet, #BG.spots))
          else
            local leg = 400 * (sp.n + 1)
            local a = math.atan(dy, dx) + math.rad(HEAD[sp.hi])
            local sub = {X = l.X + math.cos(a)*leg, Y = l.Y + math.sin(a)*leg, Z = l.Z}
            BG.det = {sub = sub, from = {X = l.X, Y = l.Y}, t = 0, sp = sp, leg = leg, lim = math.ceil(leg/120) + 1}
            log(string.format("bot stuck at %.0f,%.0f (%.0f uu to go): detour %+d leg %d", l.X, l.Y, d, HEAD[sp.hi], leg)); move_to(BOT, sub, 40)
          end
        elseif BG.stuck >= 1 then move_to(BOT, BG.dest, BG.accept) end   -- re-issue only when not moving (a re-issue every second restarts the move)
      end
    end
    crumb("walk end")
  end)
end

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
-- job tests: spawn a storage chest / an enemy at an offset from the first crew member's home
local ENEMIES = {}
local function t_thing(path, dx, dz, is_enemy)
  local m = crew[1]; if not m then log("thing: no crew"); return end
  local name = path:match("([^/]+)$")
  LoadAsset(path .. "." .. name); local cls = StaticFindObject(path .. "." .. name .. "_C")
  if not valid(cls) then log("thing: no class " .. name); return end
  local at = {X=m.home.X + dx, Y=m.home.Y, Z=m.home.Z + dz}
  local a = FindFirstOf("World"):SpawnActor(cls, at, {Pitch=0, Yaw=0, Roll=0})
  if not valid(a) then log("thing: spawn failed " .. name); return end
  if is_enemy then
    if not valid(a.Controller) then pcall(function() a:SpawnDefaultController() end) end
    ENEMIES[#ENEMIES+1] = a
  end
  local al = loc(a)
  log(string.format("thing %s at %.0f,%.0f,%.0f (asked %.0f,%.0f) ctrl=%s", name, al.X, al.Y, al.Z, at.X, at.Y, tostring(is_enemy and valid(a.Controller))))
end
local TCMD = "C:/re/abioticfactor/faircrew_cmd.txt"
local function cmd_step()
  local f = io.open(TCMD, "r"); if not f then return end
  local lines = {}; for l in f:lines() do if #l > 0 then lines[#lines+1] = l end end
  f:close(); os.remove(TCMD)
  do
    for _, l in ipairs(lines) do
      local op, n, n2 = l:match("^(%S+)%s*(%S*)%s*(%S*)")
      local ok, e = pcall(function()
        if op == "spawn" then t_spawn(tonumber(n) or 300) elseif op == "status" then t_status()
        elseif op == "bot" then t_bot(tonumber(n) or 400)                         -- bot owner in front of the player + a crew NPC next to it
        elseif op == "botgo" then t_botgo(tonumber(n) or 0, tonumber(n2) or 0)     -- walk the bot owner by an offset (AI pathing)
        elseif op == "botfar" then t_botfar(tonumber(n) or 1500)                  -- walk the bot to a navmesh-reachable point ~n uu away
        elseif op == "botback" then t_botback()                                     -- walk the bot back to its crew member's bed
        elseif op == "crewtobot" then if valid(BOT) and crew[1] then local c = loc(BOT); crew[1].pawn:K2_SetActorLocation({X=c.X+120, Y=c.Y, Z=c.Z}, false, {}, true); log(string.format("crewtobot -> %.0f,%.0f", c.X+120, c.Y)) end   -- test: put the first crew member next to the bot owner
        elseif op == "botcrew" then if valid(BOT) and crew[1] then local c = loc(crew[1].pawn); BOT:K2_SetActorLocation({X=c.X+120, Y=c.Y, Z=c.Z}, false, {}, true); log(string.format("botcrew -> %.0f,%.0f", c.X+120, c.Y)) end   -- test: put the bot owner next to the first crew member
        elseif op == "botgift" then BOTGIFT = (n ~= "0"); log("botgift " .. tostring(BOTGIFT))
        elseif op == "needs" then local r, h = n, n2; for _, m in ipairs(crew) do m.rest = tonumber(r) or m.rest; m.fed = tonumber(h) or m.fed end; log("needs set rest=" .. tostring(r) .. " fed=" .. tostring(h))
        elseif op == "job" then local m = crew[tonumber(n2) or 1]; if m then m.job = (n ~= "none" and n ~= "") and n or nil; m.off = false; m.post = nil; m.unload = nil; log("job " .. m.name .. " = " .. tostring(m.job)) end
        elseif op == "bothold" then BOTHOLD = {row = n, n = tonumber(n2) or 1}; log("bothold " .. n .. " x" .. BOTHOLD.n)   -- bot owner holds n virtual items for the porter
        elseif op == "box" then t_thing("/Game/Blueprints/DeployedObjects/Furniture/Deployed_Container_Chest_Vintage", tonumber(n) or 300, -90, false)
        elseif op == "enemy" then t_thing("/Game/Blueprints/Characters/NPCs/NPC_Peccary_Sow", tonumber(n) or 1000, 100, true)
        elseif op == "enemykill" then for _, e in ipairs(ENEMIES) do pcall(function() if alive(e) then e:K2_DestroyActor() end end) end; log("enemykill " .. #ENEMIES); ENEMIES = {}
        elseif op == "boxes" then for k, t in pairs(BOXES) do local parts = {}; for r, c in pairs(t) do parts[#parts+1] = r .. "=" .. c end; log("box " .. k .. " " .. table.concat(parts, " ")) end
        elseif op == "boxw" then local b = first_box(); log("boxw " .. tostring(b and inv_weight(b.ContainerInventory)))
        elseif op == "ownw" then log("ownw inv=" .. tostring(inv_weight(own_inv())) .. " hot=" .. tostring(inv_weight(own_inv("hot"))))
        elseif op == "boxput" then local b = first_box(); if not b then log("boxput: no box") else local inv = b.ContainerInventory
            local w0 = inv_weight(inv); local okp, rem = inv_put(inv, n, tonumber(n2) or 1)
            log(string.format("boxput %s x%s -> success=%s remaining=%s weight %s -> %s", n, n2, tostring(okp), tostring(rem), tostring(w0), tostring(inv_weight(inv)))) end
        elseif op == "owntake" or op == "owntakehot" then local inv = own_inv(op == "owntakehot" and "hot" or nil)
          if not valid(inv) then log(op .. ": no inventory") else
            local w0 = inv_weight(inv); local c = inv_take(inv, n, tonumber(n2) or 1)
            log(string.format("%s %s x%s -> count=%s weight %s -> %s", op, n, n2, tostring(c), tostring(w0), tostring(inv_weight(inv)))) end
        elseif op == "invsize" then local bx = first_box(); local function num(i) return valid(i) and i.CurrentInventory:GetArrayNum() or -1 end
          log("invsize box=" .. tostring(bx and num(bx.ContainerInventory)) .. " own=" .. tostring(num(own_inv())) .. " hot=" .. tostring(num(own_inv("hot"))))
        elseif op == "ownput" then local inv = own_inv(); local w0 = inv_weight(inv); local okp, rem = inv_put(inv, n, tonumber(n2) or 1)
          log(string.format("ownput %s x%s -> success=%s remaining=%s weight %s -> %s", n, n2, tostring(okp), tostring(rem), tostring(w0), tostring(inv_weight(inv))))
        elseif op == "boxslots" then crumb("boxslots")     -- every chest, with its place
          for _, b in ipairs(FindAllOf("Deployed_Container_ParentBP_C") or {}) do
            if alive(b) and valid(b.ContainerInventory) then local l = loc(b); log(string.format("boxslots @%.0f,%.0f %s", l.X, l.Y, inv_slots(b.ContainerInventory))) end
          end
        elseif op == "ownslots" then crumb("ownslots"); log("ownslots " .. inv_slots(own_inv()))
        elseif op == "haul" then HAUL = n; log("haul prefix " .. HAUL)
        elseif op == "ownbot" then local m = crew[1]; if m and valid(BOT) then m.owner = BOT; m.settled = false; log("ownbot " .. m.name) end
        elseif op == "ownme" then local m = crew[tonumber(n) or 1]; local pc0 = FindFirstOf("PlayerController"); local pl = pc0 and pc0.Pawn   -- test: the local player becomes the owner
          if m and valid(pl) then m.owner = pl; log(string.format("ownme %s owner = local player home %.0f %.0f %.0f", m.name, m.home.X, m.home.Y, m.home.Z)) end
        elseif op == "look" then   -- test camera: turn the local player toward the midpoint of the bot owner and crew[1] (video capture)
          local pc = FindFirstOf("PlayerController"); local m = crew[1]
          if valid(pc) and valid(pc.Pawn) and (valid(BOT) or m) then
            local h = loc(pc.Pawn); local t1 = valid(BOT) and loc(BOT) or loc(m.pawn); local t2 = m and loc(m.pawn) or t1
            local dx, dy = (t1.X + t2.X) / 2 - h.X, (t1.Y + t2.Y) / 2 - h.Y
            local yaw = math.deg(math.atan(dy, dx)); crumb("look SetControlRotation")
            pc:SetControlRotation({Pitch = tonumber(n) or -8, Yaw = yaw, Roll = 0}); crumb("look done")
            log(string.format("look yaw %.0f dist %.0f", yaw, math.sqrt(dx * dx + dy * dy)))
          end
        elseif op == "cam" then   -- test camera: stand beside the bot-crew line (n uu min) and face its midpoint, so both are in frame
          local pc = FindFirstOf("PlayerController"); local m = crew[1]
          if valid(pc) and valid(pc.Pawn) and valid(BOT) and m then
            local h, t1, t2 = loc(pc.Pawn), loc(BOT), loc(m.pawn)
            local mx, my = (t1.X + t2.X) / 2, (t1.Y + t2.Y) / 2
            local ux, uy = t1.X - t2.X, t1.Y - t2.Y; local d = math.sqrt(ux * ux + uy * uy)
            if d < 1 then ux, uy, d = 1, 0, 1 end
            local px, py = -uy / d, ux / d
            if (h.X - mx) * px + (h.Y - my) * py < 0 then px, py = -px, -py end     -- stay on the side the player is already on
            local r = math.max(tonumber(n) or 380, d * 0.9)
            local wx, wy = mx + px * r, my + py * r
            local off = math.sqrt((h.X - wx) ^ 2 + (h.Y - wy) ^ 2)
            if off > 150 then crumb("cam SetActorLocation"); pc.Pawn:K2_SetActorLocation({X = wx, Y = wy, Z = h.Z}, false, {}, true); h = {X = wx, Y = wy, Z = h.Z} end
            local yaw = math.deg(math.atan(my - h.Y, mx - h.X)); crumb("cam SetControlRotation")
            pc:SetControlRotation({Pitch = -6, Yaw = yaw, Roll = 0}); crumb("cam done")
            log(string.format("cam me %.0f,%.0f,%.0f bot %.0f,%.0f,%.0f crew %.0f,%.0f,%.0f apart %.0f moved %s", h.X, h.Y, h.Z, t1.X, t1.Y, t1.Z, t2.X, t2.Y, t2.Z, d, tostring(off > 150)))
          end
        elseif op == "botplace" then   -- test: put the bot owner on a known open-floor spot (x y, player height)
          local pl = me(); if valid(BOT) and pl then local h = loc(pl); BOT:K2_SetActorLocation({X = tonumber(n), Y = tonumber(n2), Z = h.Z}, false, {}, true); log("botplace " .. n .. " " .. n2 .. " z " .. math.floor(h.Z)) end
        elseif op == "body" then   -- probe 11-13: a player-pipeline body with no player controller, n uu east of the player, camera turned to it
          local pc = FindFirstOf("PlayerController"); local pl = pc and pc.Pawn; if not valid(pl) then log("body: no player") else
            local cls = StaticFindObject("/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C"); local h = loc(pl)
            crumb("body SpawnActor"); BODY = FindFirstOf("World"):SpawnActor(cls, {X = h.X + (tonumber(n) or 300), Y = h.Y, Z = h.Z + 20}, {Pitch = 0, Yaw = 180, Roll = 0}); crumb("body spawned")
            pc:SetControlRotation({Pitch = -5, Yaw = 0, Roll = 0})
            if valid(BODY) then local l = loc(BODY); log(string.format("body %s at %.0f,%.0f,%.0f ctrl=%s", BODY:GetFullName():sub(1, 60), l.X, l.Y, l.Z, tostring(valid(BODY.Controller)))) else log("body: spawn failed") end
          end
        elseif op == "bodyctl" then if valid(BODY) then crumb("bodyctl SpawnDefaultController"); BODY:SpawnDefaultController(); crumb("bodyctl done")
            local c = BODY.Controller; local l = loc(BODY); log(string.format("bodyctl ctrl=%s at %.0f,%.0f,%.0f", valid(c) and c:GetFullName():sub(1, 70) or "none", l.X, l.Y, l.Z)) end
        elseif op == "bodygo" then if valid(BODY) then local l = loc(BODY); local ok, r, d = move_to(BODY, {X = l.X, Y = l.Y + (tonumber(n) or 250), Z = l.Z}, 40); log("bodygo ok=" .. tostring(ok) .. " r=" .. tostring(r) .. " direct=" .. tostring(d)) end
        elseif op == "bodyrows" then   -- probe C1: row names of every customization table
          local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary"); ROWS = {}
          for _, t in ipairs({"Head","HairStyle","HairColor","HeadAccessory","UpperBody","LowerBody","ShirtColor","Belt","Shoes","Tie","Beards","Watch","IDCard"}) do
            local dt = StaticFindObject("/Game/Blueprints/DataTables/Customization/DT_Customization_" .. t .. ".DT_Customization_" .. t)
            if valid(dt) then local out = {}; crumb("bodyrows " .. t); local ok, e = pcall(function() lib:GetDataTableRowNames(dt, out) end); crumb("bodyrows done")
              local names = {}; local arr = out.OutRowNames; local how = type(arr)
              if how == "table" then for _, v in pairs(arr) do names[#names+1] = type(v) == "string" and v or v:ToString() end
              elseif how == "userdata" then local ok2, e2 = pcall(function() arr:ForEach(function(_, el) local v = el:get(); names[#names+1] = type(v) == "string" and v or v:ToString() end) end); if not ok2 then how = how .. " " .. tostring(e2):sub(-80) end end
              local et = "?"
              for _, v in pairs(out) do et = type(v); local nm = nil
                if et == "string" then nm = v else pcall(function() nm = v:ToString() end); if not nm then pcall(function() nm = v:get():ToString() end) end end
                if nm then names[#names+1] = nm end end
              log("bodyrows " .. t .. " elem=" .. et)
              ROWS[t] = {dt = dt, names = names}; log(string.format("bodyrows %s ok=%s n=%d first=%s err=%s", t, tostring(ok), #names, tostring(names[1]), tostring(e)))
            else log("bodyrows no table " .. t) end
          end
        elseif op == "bodylook" then   -- probe C2: random rows written on the body's HumanCustomizationComponent, then its own OnRep per part
          if valid(BODY) then log("bodylook " .. random_look(BODY)) end
        elseif op == "bodyclone" then
          if valid(BODY) then local comp = BODY.HumanCustomizationComponent; local pl = FindFirstOf("PlayerController").Pawn; local src = valid(pl) and pl.HumanCustomizationComponent
            if valid(comp) and valid(src) then crumb("bodyclone"); local ok, e = pcall(function() comp:Server_CloneCustomizationDataFromOtherComponent(src) end); crumb("bodyclone done")
              local hn = "?"; pcall(function() hn = src.Customization_Head.RowName:ToString() .. " / " .. comp.Customization_Head.RowName:ToString() end); log("bodyclone ok=" .. tostring(ok) .. " head src/body=" .. hn .. " err=" .. tostring(e)) else log("bodyclone: no comps") end
          end
        elseif op == "pkcam" then local pc = FindFirstOf("PlayerController"); if valid(pc) and valid(pc.Pawn) and PKO then local x, y = PKO.X + (tonumber(n) or -120), PKO.Y + (tonumber(n2) or -380); pc.Pawn:K2_SetActorLocation({X = x, Y = y, Z = PKO.Z + 10}, false, {}, true); pc:SetControlRotation({Pitch = -4, Yaw = math.deg(math.atan(PKO.Y + ((tonumber(n2) or 0) < 300 and 500 or 900) - y, PKO.X + 40 - x)), Roll = 0}); log("pkcam at " .. math.floor(x) .. "," .. math.floor(y)) end
        elseif op == "bodypos" then if valid(MB()) then local l = loc(MB()); log(string.format("bodypos %.0f,%.0f,%.0f", l.X, l.Y, l.Z)) else log("bodypos: gone") end
        elseif op == "mvwho" then MVCREW = (n == "crew"); log("mvwho " .. (MVCREW and "crew" or "body") .. " valid=" .. tostring(valid(MB())))
        elseif op == "mvsample" then if valid(MB()) then mv_start("sample", tonumber(n) or 8) end
        elseif op == "mvauto" then if valid(MB()) then local l = loc(MB()); mv_start("auto", tonumber(MVSECS) or 14); local ok, r, d = mo_go(MB(), {X = l.X + (tonumber(n) or 0), Y = l.Y + (tonumber(n2) or 600), Z = l.Z}, 40, MVSPD, MVSTRAIGHT); log("mvauto ok=" .. tostring(ok) .. " r=" .. tostring(r) .. " direct=" .. tostring(d) .. " spd=" .. MVSPD) end
        elseif op == "mvspd" then MVSPD = tonumber(n) or JOG; MVSECS = tonumber(n2) or 14; log("mvspd " .. MVSPD .. " secs " .. MVSECS)
        elseif op == "parkour" then if valid(BODY) then t_parkour() end
        elseif op == "ladinfo" then lad_info()
        elseif op == "ladon" then if valid(BODY) and valid(LAD) then mv_start("ladon", 3); crumb("ladon"); local ok, e = pcall(function() BODY:ToggleLadderClimbing(n ~= "0", LAD) end); crumb("ladon done"); log("ladon " .. n .. " ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-90)))) end
        elseif op == "ladclimb" then if valid(BODY) and valid(LAD) and PKO then mo_clear(BODY); mv_start("climb", 6); CL["test"] = {p = BODY, lad = LAD, top = PKO.Z + (tonumber(n) or 220), rate = tonumber(n2) or 14, dx = 300, dy = 0, t_end = os.clock() + 8}; log("ladclimb start climbing=" .. tostring(BODY.ClimbingLadder)) end
        elseif op == "mvup" then if valid(MB()) and PKO then mv_start("up", 14); local ok, r = mo_go(MB(), {X = PKO.X + 235, Y = PKO.Y + 900, Z = PKO.Z + 208}, 40, JOG, true); log("mvup ok=" .. tostring(ok) .. " r=" .. tostring(r)) end
        elseif op == "ladmove" then if valid(BODY) then local secs = tonumber(n2) or 4; mv_start("ladmove" .. n, secs + 0.5); LADMV = {v = tonumber(n) or 1.0, t_end = os.clock() + secs} end
        elseif op == "mvprop" then if valid(MB()) then local ok, e = pcall(function() MB()[n] = tonumber(n2) end); local rd = "?"; pcall(function() rd = tostring(MB()[n]) end); log("mvprop " .. n .. "=" .. n2 .. " ok=" .. tostring(ok) .. " reads " .. rd .. (ok and "" or (" " .. tostring(e):sub(-70)))) end
        elseif op == "mvcallb" then if valid(MB()) then mv_start(n, 2); crumb("mvcallb " .. n); local ok, e = pcall(function() MB()[n](MB(), n2 == "1") end); crumb("mvcallb done"); local sp = "?"; pcall(function() sp = tostring(MB():IsSprinting()) end); log("mvcallb " .. n .. " ok=" .. tostring(ok) .. " sprinting=" .. sp .. (ok and "" or (" " .. tostring(e):sub(-70)))) end
        elseif op == "ladgo" then if valid(BODY) and valid(LAD) then mo_clear(BODY); local c = LAD.LadderVolume:K2_GetComponentLocation(); local l = loc(BODY); mv_start("ladgo", 5); local ok, r = pcall(function() return BODY.Controller:MoveToLocation({X = c.X + (tonumber(n) or 0), Y = c.Y, Z = l.Z}, 5.0, true, false, false, false, nil, true) end); log("ladgo ok=" .. tostring(ok) .. " r=" .. tostring(r)) end
        elseif op == "bodytp" then if valid(MB()) and PKO then mo_clear(MB()); crumb("bodytp"); local ok, e = pcall(function() MB():K2_TeleportTo({X = PKO.X + (tonumber(n) or 0), Y = PKO.Y + (tonumber(n2) or 0), Z = PKO.Z + 10}, {Pitch = 0, Yaw = 90, Roll = 0}) end); crumb("bodytp done"); log("bodytp ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-90)))) end
        elseif op == "ladovl" then if valid(BODY) and valid(LAD) then crumb("ladovl"); local ok, e = pcall(function() LAD:Server_ProcessLadderVolumeOverlap(BODY, n ~= "0") end); crumb("ladovl done"); log("ladovl " .. n .. " ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-90)))) end
        elseif op == "mvstraight" then MVSTRAIGHT = n ~= "0"; log("mvstraight " .. tostring(MVSTRAIGHT))
        elseif op == "mvgo" then if valid(MB()) then local l = loc(MB()); mv_start("go", 8); local ok, r, d = move_to(MB(), {X = l.X + (tonumber(n) or 0), Y = l.Y + (tonumber(n2) or 600), Z = l.Z}, 40); log("mvgo ok=" .. tostring(ok) .. " r=" .. tostring(r) .. " direct=" .. tostring(d)) end
        elseif op == "mvjump" then if valid(MB()) then mv_start("jump", 3); crumb("mvjump Jump"); local ok, e = pcall(function() MB():Jump() end); crumb("mvjump done"); log("mvjump ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-70)))) end
        elseif op == "mvcrouch" then if valid(MB()) then mv_start("crouch" .. n, 2); crumb("mvcrouch"); local ok, e = pcall(function() if n == "1" then MB():Crouch(false) else MB():UnCrouch(false) end end); crumb("mvcrouch done"); log("mvcrouch " .. n .. " ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-70)))) end
        elseif op == "mvcall" then if valid(MB()) then mv_start(n, 3); crumb("mvcall " .. n); local ok, e = pcall(function() MB()[n](MB()) end); crumb("mvcall done"); log("mvcall " .. n .. " ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-90)))) end
        elseif op == "mvset" then if valid(MB()) then local ok, e = pcall(function() MB().CharacterMovement[n] = tonumber(n2) or (n2 == "true") end); log("mvset " .. n .. "=" .. tostring(n2) .. " ok=" .. tostring(ok) .. (ok and "" or (" " .. tostring(e):sub(-70)))) end
        elseif op == "who" then   -- harness: our bodies must not count as players
          local na, nr = 0, 0
          for _, p in ipairs(FindAllOf("Abiotic_PlayerCharacter_C") or {}) do if valid(p) then na = na + 1; if not OURS[string.format("%x", p:GetAddress())] then nr = nr + 1 end end end
          log(string.format("who bodies=%d real=%d crew=%d bot=%s", na, nr, #crew, tostring(valid(BOT))))
        elseif op == "anim" then   -- harness: is the body's anim blueprint fed while it walks (velocity + its Speed variable)
          local m = crew[1]
          if m and alive(m.pawn) then local v, sp = -1, "?"
            crumb("anim vel"); pcall(function() local q = m.pawn:GetVelocity(); v = math.sqrt(q.X*q.X + q.Y*q.Y) end)
            crumb("anim inst"); local ok, e = pcall(function() sp = tostring(m.pawn.Mesh:GetAnimInstance().Speed) end); crumb("anim done")
            local l = loc(m.pawn); log(string.format("anim %s at %.0f,%.0f vel=%.0f animSpeed=%s%s", m.name, l.X, l.Y, v, sp, ok and "" or (" ERR " .. tostring(e):sub(-60))))
          else log("anim: no crew") end
        elseif op == "botbed" then t_botbed(tonumber(n) or 150) end               -- cot next to the bot owner
      end)
      if not ok then log("cmd error " .. l .. " " .. tostring(e)) end
    end
  end
end

-- 11-12: all work runs from ONE game-thread pump. Before, three LoopAsync threads ran Lua (file reads, closures,
-- ExecuteInGameThread) next to the game-thread callbacks on the same Lua state; 5 client crashes inside the UE4SS
-- Lua VM (same stack hash, a different Lua call each time). The pump hangs on the player character's ReceiveTick
-- (game thread, every frame; BP_HUD:ReceiveDrawHUD stopped firing ~1 min after level load on the minimized client).
-- The async loop is only a watchdog: it compares two numbers, and feeds the pump itself only while the hook is
-- silent for over 1 s (main menu, dedicated server without players, hook lost on a level change).
local PUMP_FN = "/Game/Blueprints/Characters/Abiotic_PlayerCharacter.Abiotic_PlayerCharacter_C:ReceiveTick"
local t_crew, t_walk, t_cmd, t_hook, t_pump, hooked, via_async, n_async = 0, 0, 0, -10, 0, false, false, 0
local pump
local t_q = 0
local pump_hook
local function try_hook()
  -- the hook only QUEUES the pump (ExecuteInGameThread from the game thread): running commands that spawn actors
  -- directly inside the hook callback hung the client (runs 5 and 6, client "not responding" right at the first command)
  local ok = pcall(RegisterHook, PUMP_FN, function()
    local t = os.clock(); if t - t_q >= 0.1 then t_q = t; ExecuteInGameThread(pump_hook) end
  end)
  if ok then hooked = true; log("pump hooked on PlayerCharacter:ReceiveTick") end
end
pump = function()
  local t = os.clock()
  if via_async then n_async = n_async + 1; if n_async == 1 or n_async % 600 == 0 then log("pump fed by async watchdog x" .. n_async) end end
  t_pump = t
  if t - t_walk >= 0.1 then t_walk = t; walk_step(); mo_step(); lad_step(); mv_step() end
  if t - t_cmd >= 0.5 then t_cmd = t; local ok, e = pcall(cmd_step); if not ok then log("cmd_step error " .. tostring(e)) end end
  if t - t_crew >= TICK_S then t_crew = t; crew_step() end
  if (not hooked or via_async) and t - t_hook >= 5 then t_hook = t; try_hook() end
end
pump_hook = function() via_async = false; pump() end
local function pump_async() via_async = true; pump() end
LoopAsync(100, function()
  if os.clock() - t_pump > 1 then ExecuteInGameThread(pump_async) end
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
