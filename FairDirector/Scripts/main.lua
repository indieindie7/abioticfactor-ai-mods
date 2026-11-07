-- FairDirector v0.2: Alien-Isolation-style pacing. The director (not the AI's senses) eases off when
-- players are stressed and lets pressure build when they are calm. Pairs with FairSight (fair senses).
-- Actuators: Abiotic_AIDirector_C.NPCCap (stock 120), Abiotic_NPCSpawn_ParentBP_C.SpawnCooldown_Default.
local LOG = "C:/re/abioticfactor/fairdirector_log.txt"
local TICK = 2000            -- ms
local NEAR = 1500            -- uu: NPC counts as pressure inside this radius
local PEAK, CALM = 0.65, 0.25
local RELAX_S = 60           -- after a peak, hold the relaxed state this long
local RELAX_CAP, RELAX_COOL = 0.5, 2.0   -- NPCCap x0.5, spawn cooldown x2 while relaxed
local BUILD_COOL = 0.75      -- calm for long: spawn cooldown x0.75 (pressure builds)
local CALM_S = 120

local function log(s) local f = io.open(LOG, "a"); if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end end
log("loaded")

local base = { cap = nil, cool = {} }    -- stock values, keyed by spawner full name
local maxhp, lasthp, dmg = {}, {}, {}
local state, since, t = "normal", 0, 0

local function hp(p)
  local ok, v = pcall(function() return p.CurrentHealth_Head + p.CurrentHealth_Torso end)
  return ok and v or nil
end

local function dist2(a, b) local dx, dy, dz = a.X-b.X, a.Y-b.Y, a.Z-b.Z; return dx*dx+dy*dy+dz*dz end

local function stress()
  local worst = 0
  local npcs = FindAllOf("Abiotic_AI_Controller_ParentBP_C") or {}
  local npos = {}
  for _, c in ipairs(npcs) do
    local pw = c:IsValid() and c.Pawn
    if pw and pw:IsValid() then npos[#npos+1] = pw:K2_GetActorLocation() end
  end
  for _, p in ipairs(FindAllOf("Abiotic_PlayerCharacter_C") or {}) do
    if p:IsValid() then
      local k = p:GetFullName(); local h = hp(p)
      if h then
        maxhp[k] = math.max(maxhp[k] or h, h)
        local d = math.max(0, (lasthp[k] or h) - h); lasthp[k] = h
        dmg[k] = (dmg[k] or 0) * 0.85 + d            -- ~12 s decay at 2 s ticks
        local frac = maxhp[k] > 0 and h / maxhp[k] or 1
        local loc, near = p:K2_GetActorLocation(), 0
        for _, q in ipairs(npos) do if dist2(loc, q) < NEAR*NEAR then near = near + 1 end end
        local s = 0.5*(1-frac) + 0.3*math.min(1, dmg[k]/40) + 0.2*math.min(1, near/4)
        worst = math.max(worst, s)
      end
    end
  end
  return worst
end

local function apply(capMul, coolMul)
  local d = FindFirstOf("Abiotic_AIDirector_C")
  if d and d:IsValid() then
    base.cap = base.cap or d.NPCCap
    d.NPCCap = math.floor(base.cap * capMul + 0.5)
  end
  for _, sp in ipairs(FindAllOf("Abiotic_NPCSpawn_ParentBP_C") or {}) do
    if sp:IsValid() then
      local k = sp:GetFullName()
      base.cool[k] = base.cool[k] or sp.SpawnCooldown_Default
      sp.SpawnCooldown_Default = base.cool[k] * coolMul
    end
  end
end

local function set(s, capMul, coolMul, why)
  if state ~= s then state, since = s, t; log(string.format("state %s (%s)", s, why)); apply(capMul, coolMul) end
end

LoopAsync(TICK, function() ExecuteInGameThread(function() pcall(function()
  t = t + TICK/1000
  local s = stress()
  if s >= PEAK then set("relax", RELAX_CAP, RELAX_COOL, string.format("stress %.2f", s))
  elseif state == "relax" and t - since >= RELAX_S then set("normal", 1, 1, "relax over")
  elseif state == "normal" and s <= CALM then
    if t - since >= CALM_S then set("build", 1, BUILD_COOL, "calm " .. CALM_S .. " s") end
  elseif state == "build" and s > CALM then set("normal", 1, 1, string.format("stress %.2f", s))
  end
  if math.floor(t) % 30 == 0 then log(string.format("tick stress=%.2f state=%s", s, state)) end
end) end); return false end)
