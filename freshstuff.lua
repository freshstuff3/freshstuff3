--[[ 
FreshStuff3 v5
This is the common script that gets loaded by host apps, then takes care of everything else :-D
Characteristics (well, proposed - no, they are almost real as of end-feb 2007): modular and portable among host programs
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]
AllStuff,NewestStuff,Engine,Bot,Commands,Levels = {},{},{},{},{},{}

if Core and Core.GetPtokaXPath() then
    package.path = Core.GetPtokaXPath().."scripts/freshstuff/?.lua"
else
    package.path = frmHub:GetPtokaXLocation().."scripts/freshstuff/?.lua"
end
Bot.version="FreshStuff3 5.0"
ModulesLoaded = {}

do -- detect the host app
-- This is done by detecting global tables that are specific to the host app.
local Host=
  {
    ["frmHub"]= "ptokax",
    ["DC"]="bcdc",
    ["VH"]="verli",
    ["Core"] = "ptokaxnew",
  }

local c
  for k,v in pairs(Host) do
    if _G[k] then
      c = require (v)
      break
    end
  end
  assert(c,"FATAL: This script does not support your host application. :-(")
end

require "tables"
require "kernel"

local hostloader =
  {
    ["ptokax"] = -- This is for old PtokaX
      function()
        package.cpath = frmHub:GetPtokaXLocation().."/scripts/freshstuff/lib/?.dll" -- Set the path for C libs.
        require "pxlfs" 
        package.path = frmHub:GetPtokaXLocation().."/scripts/freshstuff/components/?.lua" -- Set the path for Lua libs.
        for entry in lfs.dir(  frmHub:GetPtokaXLocation().."/scripts/freshstuff/components" ) do -- open the components directory
          local filename, ext = entry:match("([^%.]+)%.(%w%w%w)") -- search for Lua files
          if ext == "lua" then
            require (filename) -- and load them
          end
        end
      end,
    ["ptokaxnew"] = 
      function()
        package.cpath=Core.GetPtokaXPath().."scripts/freshstuff/libnew/?.dll"
        require "pxlfs"
        package.path=Core.GetPtokaXPath().."scripts/freshstuff/components/?.lua"
        for entry in lfs.dir( Core.GetPtokaXPath().."scripts/freshstuff/components" ) do
          local filename,ext=entry:match("([^%.]+)%.(%w%w%w)")
          if ext == "lua" then
            require (filename)
          end
        end
      end,
  }

for k,v in pairs(hostloader) do
  if package.loaded[k] then v() break end
end

Functions={}