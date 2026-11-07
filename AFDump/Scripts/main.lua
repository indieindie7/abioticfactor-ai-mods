-- AFDump: one-shot SDK/object/usmap dump, then writes done marker.
local OUT = "C:/re/abioticfactor/dump_done.txt"
local function mark(s) local f = io.open(OUT, "a"); if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end end
mark("loaded")
ExecuteWithDelay(30000, function()
  ExecuteInGameThread(function()
    local ok, e
    ok, e = pcall(DumpUSMAP);          mark("usmap " .. tostring(ok) .. " " .. tostring(e))
    ok, e = pcall(DumpAllObjects);     mark("objects " .. tostring(ok) .. " " .. tostring(e))
    ok, e = pcall(GenerateSDK);        mark("sdk " .. tostring(ok) .. " " .. tostring(e))
    ok, e = pcall(GenerateLuaTypes);   mark("luatypes " .. tostring(ok) .. " " .. tostring(e))
    mark("DONE")
  end)
end)
