-- AfPilot (TEST ONLY, never ship enabled): drives menus/console from a command file so tests need no mouse.
-- Write lines to C:/re/abioticfactor/pilot_cmd.txt; results append to C:/re/abioticfactor/pilot_out.txt.
--   call <ClassShortName> <Function>   call a no-arg function on every live instance of that class
--   exec <console command>             run a console command
--   list <ClassShortName>              full names of live instances
--   set <Class> <Prop> <value> | sub <Class> <Prop> <Func>   (never pass FText from Lua: SetText(FText()) crashed the game)
--   prop <ClassShortName> <Property>   tostring of a property on the first instance
local CMD, OUT = "C:/re/abioticfactor/pilot_cmd.txt", "C:/re/abioticfactor/pilot_out.txt"
local function out(s)
  local f = io.open(OUT, "a"); if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end
end
local function live(cls)
  local t = {}
  for _, o in ipairs(FindAllOf(cls) or {}) do
    if o:IsValid() and not o:GetFullName():find("Default__") and not o:GetFullName():find("/Game/[^ ]*:WidgetTree") then t[#t+1] = o end
  end
  return t
end
local function run(line)
  local op, a, b = line:match("^(%S+)%s+(%S+)%s*(.*)$")
  if not op then return end
  if op == "exec" then
    local c = line:match("^exec%s+(.+)$")
    local ksl, pc = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary"), FindFirstOf("PlayerController")
    ksl:ExecuteConsoleCommand(FindFirstOf("World"), c, pc); out("exec ok: " .. c)
  elseif op == "list" then
    local t = live(a); out("list " .. a .. " n=" .. #t)
    for i = 1, math.min(#t, 12) do out("  " .. t[i]:GetFullName()) end
  elseif op == "call" then
    local t = live(a); local n = 0
    for _, o in ipairs(t) do
      local ok, e = pcall(function() o[b](o) end)
      out("call " .. a .. ":" .. b .. " on " .. o:GetFName():ToString() .. " -> " .. (ok and "ok" or tostring(e))); n = n + 1
    end
    if n == 0 then out("call " .. a .. ":" .. b .. " -> no live instance") end
  elseif op == "set" then
    local t = live(a); local k, v = b:match("^(%S+)%s+(.+)$")
    local val = v == "true" and true or (v == "false" and false or (tonumber(v) or v))
    for _, o in ipairs(t) do o[k] = val; out("set " .. a .. "." .. k .. " = " .. tostring(val)) end
  elseif op == "sub" then    -- sub <Class> <Prop> <Func>: no-arg function on the object held in a property (e.g. SetKeyboardFocus)
    local t = live(a); local k, fn = b:match("^(%S+)%s+(%S+)$")
    for _, o in ipairs(t) do local x = o[k]; x[fn](x); out("sub " .. a .. "." .. k .. ":" .. fn .. " ok") end
  elseif op == "prop" then
    local t = live(a)
    if #t == 0 then out("prop " .. a .. " -> no live instance") return end
    local ok, v = pcall(function()
      local x = t[1][b]
      if type(x) == "userdata" then
        local ok2, s = pcall(function() return x:ToString() end); if ok2 then return s end
        local ok3, s3 = pcall(function() return x:GetFullName() end); if ok3 then return s3 end
      end
      return tostring(x)
    end)
    out("prop " .. a .. "." .. b .. " = " .. tostring(v))
  end
end
LoopAsync(500, function()
  local f = io.open(CMD, "r"); if not f then return false end
  local lines = {}
  for l in f:lines() do if #l > 0 then lines[#lines+1] = l end end
  f:close(); os.remove(CMD)
  if #lines == 0 then return false end
  ExecuteInGameThread(function()
    for _, l in ipairs(lines) do
      local ok, e = pcall(run, l)
      if not ok then out("ERR " .. l .. " -> " .. tostring(e)) end
    end
  end)
  return false
end)
out("AfPilot loaded")
