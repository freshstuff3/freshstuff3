--[[
FreshStuff3 v5
This is the common script that gets loaded by host apps, then takes care of
   everything else :-D
Distributed under the terms of the Common Development and Distribution License
   (CDDL) Version 1.0.
See docs/license.txt for details.
]]
AllStuff, NewestStuff, PendingStuff, Engine, Bot, Commands, Levels, Allowed,
   Coroutines = {}, {}, {}, {}, {}, {}, {}, {}, {}
Bot.version="FreshStuff3 5.5 alpha 3"
ModulesLoaded = {}
unpack = unpack or table.unpack -- Lua 5.1 compatibility

function LoadCfg(dir, fn)
  file = dir.."config/"..fn
  local f=io.open(file,"r")
  local str
  if not f then
    SendOut (dir.."config/"..fn.." is missing, creating a new one.")
    f = io.open(dir.."config/original/"..fn)
    assert(f, "FATAL: "..dir.."config/original/"..fn..
      " is missing! Please redownload it!")
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

do -- detect the host app
-- This is done by detecting global tables that are specific to the host app.
local Host=
  {
--     ["DC"]="bcdc",
--     ["VH"]="verli",
    ["Core"] = {
      func = "GetPtokaXPath",
      path = "scripts/freshstuff/?.lua",
      mod = "ptokax"},
  }

local c
  for glob, loader in pairs(Host) do
    if _G[glob] then
      if loader.param then
        package.path = _G[glob][loader.func](_G[loader.param])..loader.path
      else
        package.path = _G[glob][loader.func]()..loader.path
      end
      require (loader.mod)
      c = true
      break
    end
  end
  assert(c,"FATAL: This script does not support your host application. :-(")
end

require "tables"
require "kernel"

local hostloader =
  {
    ["ptokax"] =
      function()
        package.path = Core.GetPtokaXPath()..
        "scripts/freshstuff/components/?.lua"
        if os.getenv("windir") then -- we are running on Windows
          package.cpath = Core.GetPtokaXPath().."scripts/freshstuff/lib/?.dll"
          require "lfs"
          for entry in lfs.dir( Core.GetPtokaXPath()..
          "scripts/freshstuff/components" ) do
            local filename, ext = entry:match("([^%.]+)%.lua$")
            if filename then require (filename) end
          end
        else
          local f = io.popen("which ls")
          local ls = f:read("*l")
          f:close()
          f = io.popen(ls.." -1 "..Core.GetPtokaXPath()..
          "scripts/freshstuff/components/")
          for line in f:lines() do
            local filename, ext = line:match("([^%.]+)%.lua$")
            if filename then require (filename) end
          end
          f:close()
        end
      end,
  }

for k,v in pairs(hostloader) do
  if package.loaded[k] then v() break end
end

Functions={}
