-- FairCrew self-test (dedicated server, env AF_FAIRCREW_SELFTEST=1). Run: tools/selftest.ps1
-- A scripted mock player (Lua table) drives the real mod logic against real spawned scientists.
-- Result table: C:/re/abioticfactor/faircrew_selftest.md (rewritten after every step; ends with DONE).
-- Tests LOGIC + spawning + walking on the server. It cannot test: rendering, real inventory, combat, a real client.
return function(H)
  local OUT = "C:/re/abioticfactor/faircrew_selftest.md"
  local rows, idx, t0, entered = {}, 1, 0, false
  local function flush(done)
    local f = io.open(OUT, "w"); if not f then return end
    f:write("# FairCrew self-test " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n| # | Step | Result | Detail |\n|---|---|---|---|\n")
    for i, r in ipairs(rows) do f:write(string.format("| %d | %s | %s | %s |\n", i, r[1], r[2], r[3])) end
    if done then
      local p, n = 0, 0
      for _, r in ipairs(rows) do if r[2] == "PASS" then p = p + 1; n = n + 1 elseif r[2] == "FAIL" then n = n + 1 end end   -- SKIP/INFO rows are not counted
      f:write(string.format("\nDONE %d/%d pass\n", p, n))
    end
    f:close()
  end
  local function v(a) local l = H.loc(a); return {X=l.X, Y=l.Y, Z=l.Z} end
  local function dist(a, b) local x, y = a.X-b.X, a.Y-b.Y; return math.sqrt(x*x + y*y) end

  -- mock player: only what main.lua touches
  local P = {pos={X=0, Y=0, Z=0}, row="None", consumed=0}
  function P:IsValid() return true end
  function P:K2_GetActorLocation() return self.pos end
  P.CurrentItemRow = {ToString=function() return P.row end}
  function P:GetCurrentHeldItem(o) o.Success = false end
  function P:ConsumeItemOfSpecificCount(_, n) self.consumed = self.consumed + n end
  local function stand(at, dx) P.pos = {X=at.X + (dx or 0), Y=at.Y, Z=at.Z} end

  local ps = FindFirstOf("PlayerStart")
  local origin = (ps and ps:IsValid()) and v(ps) or {X=0, Y=0, Z=0}
  stand(origin, -3000)
  H.set_fake({P}); H.set_autospawn(false)

  local world = FindFirstOf("World")
  local function spawn(path)
    local name = path:match("([^/]+)$")
    pcall(LoadAsset, path .. "." .. name)
    local cls = StaticFindObject(path .. "." .. name .. "_C")
    if not (cls and cls:IsValid()) then return nil, "no class" end
    return cls
  end
  local m1, m2, bed, bedpos, mark
  local mockbed = false

  local steps = {
    {"mod loads, gift table", 0, nil, function()
      local n = 0; for _ in pairs(H.gifts) do n = n + 1 end
      return n > 100 and H.gifts["bandage"] == true, "gift rows=" .. n
    end},
    {"spawn scientist (plan 4)", 3, function() H.spawn_one({P}, {X=origin.X+300, Y=origin.Y, Z=origin.Z}) end, function()
      m1 = H.crew[1]; if not m1 then return false, "crew empty" end
      local c = m1.pawn.Controller
      mark = v(m1.pawn)
      return c and c:IsValid(), m1.name .. " ctrl=" .. tostring(c and c:IsValid() and c:GetClass():GetFName():ToString())
    end},
    {"idle wander walks (plan 5)", 22, nil, function()
      local d = dist(v(m1.pawn), mark)
      local function q(f) local ok, r = pcall(f); return ok and tostring(r) or "err" end
      local cm = m1.pawn.CharacterMovement
      local diag = " mode=" .. q(function() return cm.MovementMode end) .. " pawnTick=" .. q(function() return m1.pawn:IsActorTickEnabled() end)
        .. " cmTick=" .. q(function() return cm:IsComponentTickEnabled() end) .. " maxWalk=" .. q(function() return cm.MaxWalkSpeed end)
        .. " ctrlTick=" .. q(function() return m1.pawn.Controller:IsActorTickEnabled() end) .. " timeDil=" .. q(function() return m1.pawn.CustomTimeDilation end)
      return d > 30 and not m1.owner, string.format("moved %.0f uu in 22 s, z %.0f -> %.0f", d, mark.Z, v(m1.pawn).Z) .. diag
    end},
    {"empty hands: no recruit (plan 5)", 8, function() P.row = "None"; stand(v(m1.pawn), 100) end, function()
      return m1.owner == nil, "owner=" .. tostring(m1.owner ~= nil)
    end},
    {"non-gift item: no recruit", 8, function() P.row = "not_a_gift_row"; stand(v(m1.pawn), 100) end, function()
      return m1.owner == nil, "owner=" .. tostring(m1.owner ~= nil)
    end},
    {"gift recruit, 1 item taken (plan 6)", 8, function() P.row = "bandage"; P.consumed = 0; stand(v(m1.pawn), 100) end, function()
      return m1.owner == P and m1.friend >= 60 and P.consumed == 1, string.format("owner=%s friend=%.0f consumed=%d", tostring(m1.owner == P), m1.friend, P.consumed)
    end},
    {"follows the owner (plan 7)", 15, function() P.row = "None"; mark = v(m1.pawn); stand(mark, 1200) end, function()
      local d0, d1 = 1200, dist(v(m1.pawn), P.pos)
      return d1 < d0 - 200, string.format("gap %.0f -> %.0f uu in 15 s", d0, d1)
    end},
    {"bed move-in (plan 9)", 7, function()
      bedpos = v(m1.pawn); bedpos.X = bedpos.X + 150
      local cls, err = spawn("/Game/Blueprints/DeployedObjects/Furniture/Deployed_Furniture_Cot_Military")
      local ok, a = pcall(function() return cls and world:SpawnActor(cls, bedpos, {Pitch=0, Yaw=0, Roll=0}) end)
      if ok and a and a:IsValid() then bed = a; bedpos = v(a) else
        mockbed = true
        bed = {IsValid=function() return true end, GetFullName=function() return "MockBed Level:MockBed_0" end, K2_GetActorLocation=function() return bedpos end}
        H.set_fake_beds({bed})
      end
      H.beds_reset(); stand(bedpos, 100)
    end, function()
      local k = bed:GetFullName()
      return m1.bed ~= nil and m1.owner == nil and H.claimed[k] == m1, (mockbed and "MOCK bed (real cot did not spawn)" or "real cot actor") .. " bedkey=" .. tostring(m1.bedkey and m1.bedkey:match("[^%.:]+$"))
    end},
    {"stays home when owner leaves (plan 10)", 6, function() stand(bedpos, 4000) end, function()
      local d = dist(v(m1.pawn), bedpos)
      return m1.owner == nil and m1.bed ~= nil and d < 900, string.format("%.0f uu from bed", d)
    end},
    {"claimed bed refuses a 2nd scientist", 16, function()
      H.spawn_one({P}, {X=bedpos.X + 2000, Y=bedpos.Y, Z=bedpos.Z})
      m2 = H.crew[2]
      if m2 then P.row = "bandage"; stand(v(m2.pawn), 100) end
    end, nil, function(el)   -- staged: recruit m2 (8 s), then bring both to the bed (8 s)
      if el >= 8 and m2 and m2.owner == P and P.row ~= "None" then
        P.row = "None"; stand(bedpos, 100)
        pcall(function() m2.pawn:K2_SetActorLocation({X=bedpos.X + 300, Y=bedpos.Y + 200, Z=bedpos.Z + 100}, false, {}, true) end)
      end
    end},
    {"re-gift at bed: follows again (plan 11)", 8, function() P.row = "bandage"; stand(v(m1.pawn), 60) end, function()
      return m1.owner == P and m1.bed ~= nil, "owner=" .. tostring(m1.owner == P) .. " keeps bed=" .. tostring(m1.bed ~= nil)
    end},
    {"left behind: friendship 0 -> home, bed freed (plan 12)", 12, function()
      P.row = "None"; m1.friend = 2; if m2 then m2.friend = 2 end; stand(bedpos, 6000)
    end, function()
      local k = bed:GetFullName()
      return m1.owner == nil and m1.bed == nil and H.claimed[k] == nil and (not m2 or m2.owner == nil), string.format("m1 owner=%s bed=%s claim=%s", tostring(m1.owner ~= nil), tostring(m1.bed ~= nil), tostring(H.claimed[k] ~= nil))
    end},
    {"dead scientist leaves the crew", 4, function() if m2 then local ok, e = pcall(function() m2.pawn:K2_DestroyActor() end); mark = ok and "ok" or tostring(e) end end, function()
      local function q(f) local ok, r = pcall(f); return (ok and "" or "err:") .. tostring(r) end
      local gone = not q(function() return m2.pawn:IsValid() end):find("true") or q(function() return m2.pawn:IsActorBeingDestroyed() end) == "true"
      local res = m2 ~= nil and #H.crew == 1
      if not res and not gone then res = "SKIP" end   -- the test could not destroy its own actor: nothing to judge
      return res, "destroy call=" .. tostring(mark) .. " crew=" .. #H.crew .. " valid=" .. q(function() return m2.pawn:IsValid() end)
        .. " dying=" .. q(function() return m2.pawn:IsActorBeingDestroyed() end) .. " root=" .. q(function() return m2.pawn.RootComponent:IsValid() end)
    end},
    {"probe: real player pawn + held item row", 5, function()
      flush(false)   -- evidence on disk before the risky spawn
      local cls = spawn("/Game/Blueprints/Characters/Abiotic_PlayerCharacter")
      local ok, a = pcall(function() return cls and world:SpawnActor(cls, {X=origin.X, Y=origin.Y + 400, Z=origin.Z + 100}, {Pitch=0, Yaw=0, Roll=0}) end)
      mark = (ok and a and a:IsValid()) and a or nil
      if mark then pcall(function() mark.CurrentItemRow = FName("bandage") end) end
    end, function()
      if not mark or not mark:IsValid() then return "INFO", "player pawn did not spawn" end
      local ok, row = pcall(function() return mark.CurrentItemRow:ToString() end)
      local d = dist(v(m1.pawn), mark and v(mark) or origin)
      pcall(function() mark:K2_DestroyActor() end)
      return "INFO", "CurrentItemRow reads " .. tostring(row) .. string.format(" after 5 s; scientist %.0f uu away", d)
    end},
  }
  -- the staged step needs its own check
  steps[10][4] = function()
    if not m2 then return false, "2nd scientist did not spawn" end
    local k = bed:GetFullName()
    return m2.owner == P and m2.bed == nil and H.claimed[k] == m1, "m2 follows=" .. tostring(m2.owner == P) .. " bed owner still m1=" .. tostring(H.claimed[k] == m1)
  end

  -- scientists wander now, so the mock player keeps standing next to m1 during the hold steps
  for _, i in ipairs({4, 5, 6, 11}) do steps[i][5] = function() stand(v(m1.pawn), i == 11 and 60 or 100) end end

  H.log("selftest: start, " .. #steps .. " steps")
  return function(clock)
    local s = steps[idx]; if not s then return end
    if not entered then
      entered = true; t0 = clock
      if s[3] then local ok, err = pcall(s[3]); if not ok then H.log("selftest setup error " .. tostring(err)) end end
    end
    if s[5] then pcall(s[5], clock - t0) end
    if clock - t0 >= s[2] then
      local ok, pass, detail = pcall(s[4])
      rows[#rows+1] = {s[1], (ok and type(pass) == "string") and pass or ((ok and pass) and "PASS" or "FAIL"), ok and tostring(detail) or ("lua error: " .. tostring(pass))}
      H.log("selftest " .. rows[#rows][2] .. " " .. s[1] .. " | " .. rows[#rows][3])
      idx = idx + 1; entered = false
      flush(idx > #steps)
    end
  end
end
