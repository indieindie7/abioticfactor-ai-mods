-- FairSight: NPCs keep tracking you through walls only for a short grace after losing sight.
-- Stock: Abiotic_AI_Controller_ParentBP_C.LastSawTargetCheatDuration (parent 2 s; Zombie/Coworker/Boxy 999999,
-- BogMan/Boss_Shadow/Boss_Tentacle/Snowman/Tarasque 120, Robot_Defense 60, ...). See C:/re/abioticfactor/AI-MAP.md C1.
local CAP = 2.0                      -- seconds of post-LoS live tracking allowed (stock parent default)
local LOG = "C:/re/abioticfactor/fairsight_log.txt"
local TESTFLAG = "C:/re/abioticfactor/fairsight_test.txt" -- if present: contains a map to open after menu (headless test)
local CP = "/Game/Blueprints/Characters/NPCs/Abiotic_AI_Controller_ParentBP.Abiotic_AI_Controller_ParentBP_C"

local function log(s) local f = io.open(LOG, "a"); if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end end
log("loaded, cap=" .. CAP)

local logged = {}
local function clamp(c)
  if not c or not c:IsValid() then return end
  local ok, v = pcall(function() return c.LastSawTargetCheatDuration end)
  if ok and type(v) == "number" and v > CAP then
    c.LastSawTargetCheatDuration = CAP
    local cls = c:GetClass():GetFName():ToString()
    if not logged[cls] then logged[cls] = true; log(string.format("clamp %s %.0f -> %.1f", cls, v, CAP)) end
  end
end

local notified = false
local total = 0
local function sweep()
  local all = FindAllOf("Abiotic_AI_Controller_ParentBP_C")
  local n = all and #all or 0
  if all then for _, c in ipairs(all) do clamp(c) end end
  if n ~= total then total = n; log("controllers live: " .. n) end
  if not notified and n > 0 then
    notified = pcall(NotifyOnNewObject, CP, function(c) clamp(c) end)
    if notified then log("NotifyOnNewObject registered") end
  end
end

LoopAsync(3000, function() ExecuteInGameThread(function() pcall(sweep) end); return false end)

local tf = io.open(TESTFLAG, "r")
if tf then
  local map = (tf:read("*l") or ""):gsub("%s+$", ""); tf:close()
  ExecuteWithDelay(25000, function() ExecuteInGameThread(function()
    local pc = FindFirstOf("PlayerController")
    local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    log("test: open " .. map .. " pc=" .. tostring(pc and pc:IsValid()))
    if pc and ksl then ksl:ExecuteConsoleCommand(pc, "open " .. map, nil) end
  end) end)
  -- after the map is up, spawn one stock zombie (999999 s cheat) so its controller must get clamped
  ExecuteWithDelay(45000, function() ExecuteInGameThread(function()
    local ok, err = pcall(function()
      LoadAsset("/Game/Blueprints/Characters/NPCs/NPC_Zombie.NPC_Zombie")
      local cls = StaticFindObject("/Game/Blueprints/Characters/NPCs/NPC_Zombie.NPC_Zombie_C")
      local world = FindFirstOf("World")
      local ps = FindFirstOf("PlayerStart")
      log("test: cls=" .. tostring(cls and cls:IsValid()) .. " world=" .. tostring(world and world:IsValid() and world:GetFullName()) .. " ps=" .. tostring(ps and ps:IsValid()))
      local loc = (ps and ps:IsValid()) and ps:K2_GetActorLocation() or {X=0, Y=0, Z=0}
      local a = world:SpawnActor(cls, {X=loc.X+300, Y=loc.Y, Z=loc.Z+100}, {Pitch=0, Yaw=0, Roll=0})
      log("test: spawned " .. tostring(a and a:IsValid() and a:GetFullName()))
    end)
    if not ok then log("test: spawn error " .. tostring(err)) end
  end) end)
  ExecuteWithDelay(60000, function() ExecuteInGameThread(function()
    for _, c in ipairs(FindAllOf("Abiotic_AI_Controller_ParentBP_C") or {}) do
      log(string.format("check %s = %.1f", c:GetClass():GetFName():ToString(), c.LastSawTargetCheatDuration))
    end
  end) end)
end
