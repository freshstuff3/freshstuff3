--[[
FreshStuff3 v5
This is the common script that gets loaded by host apps, then takes care of
   everything else :-D
Distributed under the terms of the Common Development and Distribution License
   (CDDL) Version 1.0.
See docs/license.txt for details.
]]
--AllStuff, NewestStuff, PendingStuff, Engine, Bot, Commands, Levels, Allowed,
--   Coroutines = {}, {}, {}, {}, {}, {}, {}, {}, {}
local Version="FreshStuff3 6.0 alpha 1"
--ModulesLoaded = {}
unpack = unpack or table.unpack -- Lua 5.1 compatibility

-- Desired package.path for lua/stdout fallback if you are using standalone Lua.
local luapath = "C:/Users/szaka/Desktop/Linux/devel/freshstuff3/freshstuff3/?.lua"

function LoadCfg(dir, fn)
  file = dir.."config/"..fn
  local f = io.open(file,"r")
  local str
  if not f then -- unlikely but play safe
    SendDebug (dir.."config/"..fn.." is missing, creating a new one.")
    f = io.open(dir.."config/original/"..fn)
    assert(f, "FATAL: "..dir.."config/original/"..fn.." is missing! "
      .."Please redownload it from https://freshstuff3.bitbucket.io/ ")
    local g = io.open(dir.."config/"..fn, "w")
    str = f:read("*a")
    g:write(str)
    f:close(); g:close()
  else
    SendOut ("Found"..dir.."config/"..fn)
    str = f:read("*a")
    f:close()
  end
  local run = loadstring or load
  local chunk, err = run (str)
  if not err then chunk() else error(err) end
end

-- This is done by detecting global tables that are specific to the host app.
local Host= {
  pxlua = function ()
    if Core then 
      return Core.GetPtokaXPath().."scripts/freshstuff3/?.lua", true; end
  end,
}

local ok, t
for modname, loader in pairs(Host) do
  package.path, ok = loader ()
  if ok then 
    local t = require (modname)
    SendOut = t.SendOut or print
    SendDebug = t.SendDebug or print
    break
  end
  if not ok then 
    package.path = luapath 
    SendOut = SendOut or print
    SendDebug = SendDebug or print
  end
end
--SendOut (...) and SendDebug(...) send the appropriate messages. 
-- Hostapp-specific mods MUST declare these with the desired behaviour.
-- If either is nil, code above falls back to stdout.


Event = Event or function (...)
  local x, event = {...}; event = x[1]
  local therewas
  for _, mod in pairs (_G) do
    if type (mod) =="table" and mod[event] then mod[event](...); therewas = true; end
  end
  if not therewas then print (...) end
end

Releases = require "releases"

Releases.AllStuff.PS2 = {}
Releases:Add ("PS2", {nick = "deaddy", title = "lovin' it", when = os.date ("*t")})
Releases:FakeStuff (50)