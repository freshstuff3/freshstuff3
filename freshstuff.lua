--[[
FreshStuff3 v5
This is the common script that gets loaded by host apps, then takes care of everything else :-D
Characteristics (well, proposed - no, they are almost real as of end-feb 2007): modular and portable among host programs
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]

--------
-- TODO:
--------
  -- make the script fully portable, i. e. it can use all stuff from the host program, while it interoperates with it smoothly (especially data sending)
  -- Showing latest n releases... +releases new 4 -- DONE
  -- Split this config below into module-specific parts.
  -- Document stuff for module developers -- ALMOST DONE
  -- Multilanguage. *shrugs*
  -- More bot descriptions (array), changing every X minute. -- POSTPONED
  -- Make the BCDC module -- POSTPONED
  -- Maybe create a +releases today
  
  -- Release rating plugin (reworked metatable for AllStuff, rating goes by indices of course, stored by nicks) - POST-5.0
  -- RSS plugin (generate a static page, any webserver should be able to serve that, content type rss etc. etc.) - POST-5.0
  -- Add a prune function for completed requests (low priority, since they get autodeleted upon the requester's joining.) - POST-5.0 OR ON-DEMAND

Bot = {
        name="post-it_memo",
        email="bastyaelvtars@gmail.com",
        desc="Release bot",
      } -- Set the bot's data. (Relevant only for hubsofts, so hubsoftmodule-specific)
    ProfilesUsed= 0 -- 0 for lawmaker/terminator (standard), 1 for robocop, 2 for psyguard (ptokax-only)
    Commands={
      Add="addrel", -- Add a new release
      Show="releases", -- This command shows the stuff, syntax : +albums with options new/game/warez/music/movie
      Delete="delrel", -- This command deletes an entry, syntax : +delalbum THESTUFF2DELETE
      ReLoad="reloadrel", -- This command reloads the txt file. syntax : +reloadalbums (this command is needed if you manualy edit the text file)
      Search="searchrel", -- This is for searching inside releases.
      AddCatgry="addcat", -- For adding a category
      DelCatgry="delcat", -- For deleting a category
      ShowCtgrs="showcats", -- For showing categories
      Prune="prunerel", -- Pruning releases (removing old entries)
      TopAdders="topadders", -- Showing top adders
      Help="relhelp", -- Guess what! :P
      AddReq="addreq",
      ShowReqs="requests",
      DelReq="delreq",
    } -- No prefix for commands! It is automatically added. (<--- multiple prefixes)
    Levels={
      Add=1, -- adding
      Show=1, -- showing all
      Delete=4,   -- Delete releases. Note that everyone is allowed to delete the releases they added.
      ReLoad=4,   -- reload
      Search=1, -- search
      AddCatgry=4, -- add category
      DelCatgry=4, -- delete category
      ShowCtgrs=1, -- show categories
      Prune=5, -- prune (delete old)
      TopAdders=1, -- top release adders
      Help=1, -- Guess what! :P
      AddReq=1, -- Add a request.
      ShowReqs=1, -- Show requests.
      DelReq=4, -- Delete requests. Note that everyone is allowed to delete their own requests.
    } -- You set the userlevels according to... you know what :P
    MaxItemAge=30 -- IN DAYS
    TopAddersCount=5 -- shows top-adders on command, this is the number how many it should show
    ShowOnEntry = 2 -- Show latest stuff on entry 1=PM, 2=mainchat, 0=no
    MaxNew = 20 -- Max stuff shown on newalbums/entry
    WhenAndWhatToShow={
      ["23:50"]="Lossless",
      ["20:48"]="warez",
      ["20:49"]="new",
      ["20:50"]="all",
      ["00:20"]="new",
    }-- Timed release announcing. You can specify a category name, or "all" or "new"
    ForbiddenWords={ -- Releases and requests containing such words cannot be added.
    "rape",
    "incest",
    }
    SortStuffByName=0 -- Set to 1 to sort the releases within the category-based view alphabetically.


AllStuff,NewestStuff,Engine={},{},{}

package.path="freshstuff/?.lua"
Bot.version="FreshStuff3 5.0 Release Candidate 2"
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
        package.cpath="freshstuff/lib/?.dll" -- Set the path for C libs.
        require "pxlfs" 
        package.path="freshstuff/components/?.lua" -- Set the path for Lua libs.
        for entry in lfs.dir( lfs.currentdir().."\\freshstuff\\components" ) do -- open the components directory
          local filename,ext=entry:match("([^%.]+)%.(%w%w%w)") -- search for Lua files
          if ext == "lua" then
            require (filename) -- and load them
          end
        end
      end,
    ["ptokaxnew"] = 
      function()
        package.cpath="freshstuff/libnew/?.dll"
        require "pxlfs"
        package.path="freshstuff/components/?.lua"
        for entry in lfs.dir( lfs.currentdir().."\\freshstuff\\components" ) do
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