--[[
Kernel for FreshStuff3 v5 by bastya_elvtars
This module contains functions that generate the required messages, save/load releases etc.
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]



do
  setmetatable (Engine,_Engine)

  Engine[Commands.Show]=
    {
      function (nick,data)
        if #AllStuff < 1 then return "There are no releases yet, please check back soon.",1 end
        local cat,latest= data:match("(%S+)%s*(%d*)")
        if not cat then
          return MsgAll,2
        else
          if cat == "new" then
            return MsgNew,2
          elseif Types[cat] then
            if latest~="" then
              return ShowRelNum(cat,latest),2
            else
              return ShowRelType(cat),2
            end
          elseif cat:find("^%d+%-%d+$") then
            return ShowRelRange(cat), 2
          else
            return "No such type.",1
          end
        end
      end,
      {},Levels.Show,"<type> or <start#-end#> // Shows the releases of the given type, with"
      .."no type specified, shows all. If you specify the start and end numbers, it will show the "
      .."releases of that ID range (range must not exceed 100 releases)."
    }
  Engine[Commands.Add]=
    {
      function (nick,data)
        local cat,tune=string.match(data,"(%S+)%s+(.+)")
        if cat then
          if Types[cat] then
            for _,word in pairs(ForbiddenWords) do
              if string.find(tune,word,1,true) then
                return "The release name contains the following forbidden word (thus not added): "..word, 1
              end
            end
            if Coroutines[nick] then return "A release of yours is already being processed. Please wait a few seconds!", 2 end
            local count = #AllStuff
            if count == 0 then
              if ReleaseApprovalPolicy ~= 1 then
                AllStuff(cat, nick, os.date("%m/%d/%Y"), tune)
                --HandleEvent("OnRelAdded", nick, data, cat, tune, count + 1)
                return "\""..tune.."\" has been added to the releases in this category: \""..Types[cat].."\" with ID "..count + 1, 2
              else
                PendingStuff(cat, nick, os.date("%m/%d/%Y"), tune)
                return "\""..tune.."\" has been added to the pending releases in this category: \""..Types[cat].."\" with ID "..count + 1
                ..", please wait until someone reviews it.", 2
              end
            else
              Coroutines[nick] =
               {
                  Coroutine = coroutine.create(Main.ComparisonHelper),
                  Release = tune,
                  CurrID = 0, -- to check rel #1 so avoid off-by-one errors
                  Category = cat,
               }
              return "Your release is being processed. You will be notified of the result.", 2
            end
          else
            return "Unknown category: "..cat, 1
          end
        else
          return "yea right, like i know what you got 2 add when you don't tell me!",1
        end
      end,
      {},Levels.Add,"<type> <name> // Add release of given type."
    }
  Engine[Commands.Change]=
    {
      function (nick,data)
        if data~="" then
          local id, what, new_data = string.match(data, "(%d+)%s+(%d+)%s+(.+)")
          if id then
            id = tonumber (id); what = tonumber (what)
            if AllStuff[id] then
              if Allowed[{nick,Levels.Change}] or AllStuff[id][2] == nick then
                local what_tbl = {{1, "category"}, {4, "name"} }
                AllStuff[id][what_tbl[what][1]] = new_data
                table.save(AllStuff, ScriptsPath.."data/releases.dat")
                ReloadRel()
                return "Release #"..id.." is changed: its "..what_tbl[what][2].." is now "..new_data..".",1
              else
                return "You are not allowed to use this command.",1
              end
            else
              return "\r\nRelease numbered "..id.." wasn't found in the database.",1
            end
          else return "yea right, like i know what i got 2 change when you don't tell me!.",1 end
        else
          return "yea right, like i know what i got 2 change when you don't tell me!.",1
        end
      end,
      {},1,"<ID> <field ID> <new data> // Changes a release. Field ID can be 1 for category and 2 for release name."
    }
  Engine[Commands.Delete]=
    {
      function (nick,data)
        if data~="" then
          local cnt,x,tmp,msg=0,os.clock(),{},"\r\n"
          setmetatable(tmp,
          {
          __newindex = function (tbl, n, val)
            if AllStuff[n] then
              if Allowed[{nick,Levels.Delete}] or AllStuff[n][2] == nick then
                HandleEvent ("OnRelDeleted", nick, n)
                msg=msg..AllStuff[n][4].." is deleted from the releases.\r\n"
                table.remove(AllStuff,n)
                for k,v in ipairs (NewestStuff) do
                  if v[5] == n then
                    table.remove(NewestStuff, k)
                    break
                  end
                end
                cnt=cnt+1
              else
                return "You are not allowed to use this command.",1
              end
            else
              msg=msg.."Release numbered "..n.." wasn't found in the database.\r\n"
            end
          end
          })
          for w in string.gmatch(data,"(%d+)") do
            tmp[tonumber(w)]=true
          end
          if cnt > 0 then
            table.save(AllStuff,ScriptsPath.."data/releases.dat")
            ReloadRel()
            msg=msg.."\r\n\r\nDeletion of "..cnt.." item(s) took "..os.clock()-x.." seconds."
          end
          return msg,1
        else
          return "yea right, like i know what i got 2 delete when you don't tell me!.",1
        end
      end,
      {},1,"<ID> // Deletes the releases of the given ID, or deletes multiple ones if given like: 1,5,33,6789"
    }
	-- TODO now:
	-- Engine[Commands.Approve]
	-- Engine[Commands.REject]
	-- Approval/reject messages to users like in request fulfilling
	-- (shameless copy/paste to be expected :-P)
	-- OnRelAdded should be called
	-- store messages for offline users
  Engine[Commands.AddCatgry]=
    {
      function (nick, data)
        local what1,what2=string.match(data, "(%S+)%s+(.+)")
        if what1 then
          if string.find(what1, "$", 1, true) then return "The dollar sign is not allowed.", 1 end
          if not Types[what1] then
            Types[what1]=what2
            table.save(Types,ScriptsPath.."data/categories.dat")
            return "The category "..what1.." has successfully been added.", 1
          else
            if Types[what1] == what2 then
              return "Already having the type "..what1.."with name "..what2, 1
            else
              Types[what1] = what2
              table.save(Types,ScriptsPath.."data/categories.dat")
              return "The category "..what1.." has successfully been changed.", 1
            end
          end
          for k in pairs(Types) do table.insert(CatArray,k) table.sort(CatArray) end
        else
          return "Category should be added properly: +"..Commands.AddCatgry.." <category_name> <displayed_name>", 1
        end
      end,
      {}, Levels.AddCatgry, "<new_cat> <displayed_name> // Adds a new release category, displayed_name is shown when listed."
    }
  Engine[Commands.DelCatgry]=
    {
      function (nick,data)
        local what=string.match(data,"(%S+)")
        if what then
          if not Types[what] then
            return "The category "..what.." does not exist.",1
          else
            local filename = ScriptsPath.."data/releases"..os.date("%Y%m%d%H%M%S")..".dat"
            local bRemoved
            local ret = "The category "..what.." has successfully been deleted."
            if #AllStuff > 0 then
              table.save(AllStuff, filename)
              for key, value in ipairs (AllStuff) do
                if value[1] == what then
                  for k, v in ipairs(NewestStuff) do
                    if v[5] == key then
                      table.remove(NewestStuff, k)
                    end
                  end
                  HandleEvent("OnRelDeleted", nick, key)
                  table.remove (AllStuff, key)
                  bRemoved = true
                  ret = "The category "..what.." has successfully been deleted. Note that the old releases"
                  .."have been backed up to "..filename.." in case you have made a mistake."
                end
              end
            end
            if bRemoved then
              table.save(AllStuff,ScriptsPath.."data/releases.dat")
              ReloadRel()
            else
              os.remove (filename)
            end
            Types[what]=nil
            table.save(Types,ScriptsPath.."data/categories.dat")
            HandleEvent("OnCatDeleted", nick, what)
            return ret,1
          end
        else
          return "Category should be deleted properly: +"..Commands.DelCatgry.." <category_name>",1
        end
      end,
      {},Levels.DelCatgry,"<cat> // Deletes the given release category.."
    }
  Engine[Commands.ShowCtgrs]=
    {
      function (nick,data)
        local msg="\r\n======================\r\nAvailable categories:\r\n======================\r\n"
        for a,b in pairs(Types) do
          msg=msg.."\r\n"..a.."\t\t"..b
        end
        return msg,2
      end,
      {},Levels.ShowCtgrs," // Shows the available release categories."
    }
  Engine[Commands.Search]=
    {
      function (nick,data)
        if data~="" then
          local res,rest=0,{}
          local msg="\r\n---------- You searched for keyword \""..data.."\". The results: ----------\r\n\r\n"
          for a,b in ipairs(AllStuff) do
            if string.find(string.lower(b[4]),string.lower(data),1,true) or string.find(string.lower(b[2]),string.lower(data),1,true) then
              table.insert(rest,{b[1],b[2],b[3],b[4],a})
            end
          end
          if #rest~=0 then
            for idx,tab in ipairs(rest) do
            local _type,who,when,title,id=unpack(tab)
            res= res + 1
            msg = msg.."ID: "..string.rep("0", tostring(#AllStuff):len()-tostring(id):len())..id.." - "..title.." // (Added by "..who.." at "..when..")\r\n"
            end
            msg=msg.."\r\n"..string.rep("-",20).."\r\n"..res.." results."
          else
            msg=msg.."\r\nSearch string "..data.." was not found in releases database."
          end
          return msg,1
        else
          return "yea right, like i know what you got 2 search when you don't tell me!",1
        end
      end,
      {},Levels.Search,"<string> // Searches for release NAMES containing the given string."
    }
  Engine[Commands.ReLoad]=
    {
      function()
        local x=os.clock()
        ReloadRel()
        return "Releases reloaded, took "..os.clock()-x.." seconds.",1
      end,
      {},Levels.ReLoad," // Reloads the releases database, only needed if you modified the file by hand."
    }
  Engine[Commands.Help]=
    {
      function (nick)
        local count=0
        local hlptbl={}
        local hlp="\r\nCommands available to you are:\r\n=================================================================================================================================\r\n"
        for a,b in pairs(commandtable) do
          if b["level"]~=0 then
            if Allowed [{nick, b["level"]}] then
              count=count+1
              table.insert(hlptbl,"!"..a.." "..b["help"])
            end
          end
        end
        table.sort(hlptbl)
        hlp=hlp..table.concat(hlptbl,"\r\n").."\r\n\r\nAll the "..count.." commands you can use can be typed in main or in PM session with anyone, and the available prefixes are:"..
        " ! # + - ?\r\n=================================================================================================================================\r\n"..Bot.version
        return hlp,2
      end,
      {},1," // Shows the text you are looking at."
    }
end

function OpenRel()
  local x = os.clock()
	AllStuff, NewestStuff, Types = nil, nil, nil
	collectgarbage ("collect"); io.flush()
	AllStuff, NewestStuff, Types = {}, {}, {}, {}
  setmetatable (AllStuff, nil)
  if loadfile(ScriptsPath.."data/categories.dat") then
    Types = table.load(ScriptsPath.."data/categories.dat")
  else
    Types={
      ["warez"]="Warez",
      ["game"]="Games",
      ["music"]="Music",
      ["movie"]="Movies",
    }
    SendOut("The categories file is corrupt or missing! Created a new one.")
    SendOut("If this is the first time you run this script, or newly installed it,"
    .."please copy your old releases.dat (if any) to freshstuff/data and restart the script. Thank you!")
    table.save(Types,ScriptsPath.."data/categories.dat")
  end
  if not loadfile(ScriptsPath.."data/releases.dat") then
    -- Old file format converter
    local f=io.open(ScriptsPath.."data/releases.dat","r")
    if f then
      for line in f:lines() do
        local cat,who,when,title=line:match("^(.-)%$(.-)%$(.-)%$(.-)$")
        if cat then
          if not Types[cat] then Types[cat] = cat; SendOut("New category detected: "..cat..
          ". It has been automatically added to the categories, however you ought to check if"..
          " everything is alright."); table.save(Types,ScriptsPath.."data/categories.dat"); end
          if when:find("%d+/%d+/0%d") then -- compatibility with old file format
            local m,d,y=when:match("(%d+)/(%d+)/(0%d)")
            when=m.."/"..d.."/".."20"..y
          end
          table.insert(AllStuff,{cat,who,when,title})
        else
          SendOut("Releases file is corrupt, failed to load all items.")
          break
        end
      end
      f:close()
      table.save(AllStuff,ScriptsPath.."data/releases.dat")
    end
    -- End of old file format converter
  else
    AllStuff = table.load(ScriptsPath.."data/releases.dat")
    for id, rel in ipairs (AllStuff) do
      local cat = rel[1]
      if not Types[cat] then Types[cat] = cat
        SendOut("New category detected: "..cat..
        ". It has been automatically added to the categories, however you ought to check if"..
        " everything is alright."); table.save(Types, ScriptsPath.."data/categories.dat")
      end
    end
  end
  local removed
  --- The code below  is destined to fix broken release tables but
  -- not sure if this is an issue in a nontesting environment. Anyway,
  -- I do not care about script load times because they should not be
  -- interfering with normal hub operation since in a production environment
  -- there are very few script restarts.
  for id = 1, #AllStuff do
    if AllStuff[id] == nil then table.remove (AllStuff, id) removed = true end
  end
  if removed then table.save(AllStuff,ScriptsPath.."data/releases.dat") end
	if #AllStuff > MaxNew then
		local c1, c2 = 0, #AllStuff
		while c1 ~= MaxNew do
      local a, b, c ,d = unpack (AllStuff[c2])
      table.insert (NewestStuff, {a, b, c ,d ,c2})
      c1 = c1 + 1
      c2 = c2 - 1
    end
    table.sort(NewestStuff, function(a, b) return b[5] > a[5] end)
	else
		for id, rel in ipairs (AllStuff) do
      local a, b, c, d = unpack (rel)
      table.insert(NewestStuff, {a, b, c, d, id})
    end
	end
  setmetatable (AllStuff,
  { -- This metatable handles adding stuff to NewestStuff as well.
    __call = function (tbl, ...)
       -- So We have more entries than the 'new' limit
      if #AllStuff >= #NewestStuff then
		-- so the earliest entry from the newest is deleted
        table.remove (NewestStuff, 1)
      end
      local cat, who, when, title, msg, msg_op = unpack({...})
	  -- and the new entry gets added to the latest
      table.insert (NewestStuff, {cat, who, when, title, #tbl+1})
	  -- set this in the original table, too
      table.insert (AllStuff, {cat, who, when, title})
      table.save(AllStuff, ScriptsPath.."data/releases.dat") -- save
      ShowRel(NewestStuff); ShowRel() -- refresh the global texts
	  -- send message
      if msg then PM(who, msg) end
      if msg_op then PMOps(msg_op) end
	  -- and do something hostapp-specific
      HandleEvent("OnRelAdded", who, _, cat, title, #tbl)
    end
  })
  SendOut("Loaded "..#AllStuff.." releases in "..os.clock()-x.." seconds.")
  PendingStuff = table.load(ScriptsPath.."data/releases_pending.dat") or {}
   setmetatable (PendingStuff,
   {
      __call = function (tbl, ...)
         local cat, who, when, title, msg, msg_op = unpack({...})
         table.insert(PendingStuff, {cat, who, when, title}) -- set this in the original table
         table.save(PendingStuff, ScriptsPath.."data/releases_pending.dat") -- save
         if msg then PM(who, msg) end
         if msg_op then PMOps(msg_op) end
      end
   })
   SendOut("Loaded "..#PendingStuff.." pending releases in "..os.clock()-x..
   " seconds.")
end

function ShowRel(tab)
  local CatArray={}
  local Msg = "\r\n"
  local cat, who, when, title, oid
  local tmptbl={}
  setmetatable(tmptbl,{__newindex=function(tbl,k,v) rawset(tbl,k,v); table.insert(CatArray,k); end})
  local cunt=0
  if tab == NewestStuff then
    if #AllStuff == 0 then
      MsgNew = "\r\n\r\n".." --------- The Latest Releases -------- \r\n\r\n  No releases on the list yet\r\n\r\n --------- The Latest Releases -------- \r\n\r\n"
    else
      for k, v in ipairs(NewestStuff) do
        cat, who, when, title, oid = unpack(v)
        if title then
          tmptbl[Types[cat]]=tmptbl[Types[cat]] or {}
          table.insert(tmptbl[Types[cat]],Msg.."ID: "..string.rep("0", tostring(#AllStuff):len()-tostring(oid):len())..oid.." - "..title.." // (Added by "..who.." at "..when..")")
          cunt=cunt+1
        end
      end
    end
    table.sort(CatArray)
    for _,a in ipairs (CatArray) do
      local b=tmptbl[a]
      if SortStuffByName==1 then table.sort(b,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
      Msg=Msg.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
    end
    local new=MaxNew if cunt < MaxNew then new=cunt end
    MsgNew = "\r\n\r\n".." --------- The Latest "..new.." Releases -------- "..Msg.."\r\n --------- The Latest "..new.."  Releases -------- \r\n\r\n"
  else
    if #AllStuff == 0 then
      MsgAll = "\r\n\r\r\n".." --------- All The Releases -------- \r\n\r\n  No releases on the list yet\r\n\r\n --------- All The Releases -------- \r\n\r\n"
    else
      MsgHelp  = "  use "..Commands.Show.." <new>"
      for a,b in pairs(Types) do
	      MsgHelp  = MsgHelp .."/"..a
      end
      MsgHelp  = MsgHelp .."> to see only the selected types"
      for id, rel in ipairs (AllStuff) do
        cat,who,when,title = unpack(rel)
        if cat and title then
          tmptbl[Types[cat]] = tmptbl[Types[cat]] or {}
          table.insert(tmptbl[Types[cat]], Msg.."ID: "..string.rep("0", tostring(#AllStuff):len()-tostring(id):len())..id.." - "..title.." // (Added by "..who.." at "..when..")")
        end
      end
      table.sort(CatArray)
      for _,a in ipairs (CatArray) do
        local b = tmptbl[a]
        if SortStuffByName == 1 then table.sort(b,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
        Msg=Msg.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
      end
      MsgAll = "\r\n\r\r\n".." --------- All The Releases -------- "..Msg.."\r\n --------- All The Releases -------- \r\n"..MsgHelp .."\r\n"
    end
  end
end

function ShowRelType(what)
  local cat,who,when,title
  local Msg,MsgType,tmp,tbl = "\r\n",nil,0,{}
  if #AllStuff == 0 then
    MsgType = "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n\r\n  No "
    ..string.lower(Types[what]).." yet\r\n\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
  else
    for id, rel in ipairs(AllStuff) do
      cat,who,when,title=unpack(rel)
      if cat == what then
        tmp = tmp + 1
        table.insert(tbl,"ID: "..string.rep("0", tostring(#AllStuff):len()-tostring(id):len())..id.." - "..title.." // (Added by "..who.." at "..when)
      end
    end
    if SortStuffByName==1 then table.sort(tbl,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
    if tmp == 0 then
      MsgType = "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n\r\n  No "
      ..(Types[what]):lower().." yet\r\n\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
    else
      MsgType= "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n"
      ..table.concat(tbl,"\r\n").."\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
    end
  end
  return MsgType
end

function ShowRelNum(what,num) -- to show numbers of categories
  num=tonumber(num)
  local Msg="\r\n"
  local cunt=0
--   local target=#AllStuff+1
  local cat,who,when,title
  if num > #AllStuff then num=#AllStuff end
--   for t = 1, #AllStuff do
  for t = #AllStuff+1, 1, -1 do
-- 		target = target-1
    local tbl = AllStuff[t]
    if type(tbl) == "table" then cat, who, when, title = unpack(tbl) else cat, who, when, title = nil, nil, nil, nil end -- I do not get why I get nil errors.
    if num ~= cunt then
      if cat == what then
        Msg = Msg.."ID: "..string.rep("0", tostring(#AllStuff):len()-tostring(t):len())..t.." - "..title.." // (Added by "..who.." at "..when..")\r\n"
        cunt=cunt+1
      end
    end
  end
  if cunt < num then num=cunt end
  local MsgType = "\r\n\r\n".." --------- The Latest "..num.." "..Types[what].." -------- \r\n\r\n"
  ..Msg.."\r\n\r\n --------- The Latest "..num.." "..Types[what].." -------- \r\n\r\n"
  return MsgType
end

function ShowRelRange(range)
   local MsgRange = "\r\n"
   local tbl = {}
   local tmptbl = {}
   local CatArray = {}
   local Msg = "\r\n"
   local cat, who, when, title, oid
   setmetatable(tmptbl,
   {__newindex = function(tbl,k,v)
      rawset(tbl,k,v)
      table.insert(CatArray,k)
   end})
   local s,e = range:match("^(%d+)%-(%d+)$")
   if not s then
      return "Syntax error: it should be !"..Commands.Show.." start#-end#", 1
   end
   s = tonumber (s)
   if s > #AllStuff then
      return "There are only "..#AllStuff.." releases!", 1
   end
   e = tonumber (e)
   if e > #AllStuff then e = #AllStuff; end
   if e-s > 100 then return "You can only specify a range no larger than 100"
   .."releases.",1 end
   for c = s, e do
      local tbl = AllStuff[c]
      if type(tbl) == "table" then
         cat, who, when, title = unpack(tbl)
      else
         cat, who, when, title = nil, nil, nil, nil
      end
      if cat and title then
         tmptbl[Types[cat]] = tmptbl[Types[cat]] or {}
         table.insert(tmptbl[Types[cat]], Msg.."ID: "..string.rep("0",
         tostring(#AllStuff):len()-tostring(c):len())
         ..c.." - "..title.." // (Added by "..who.." at "..when..")")
      end
   end
   table.sort(CatArray)
   for _,a in ipairs (CatArray) do
      local b = tmptbl[a]
      if SortStuffByName == 1 then
         table.sort(b, function(v1, v2)
            local c1=v1:match("ID:%s+%d+(.+)%/%/")
            local c2=v2:match("ID:%s+%d+(.+)%/%/")
            return c1:lower() < c2:lower()
         end)
      end
      MsgRange = MsgRange.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..
      table.concat(b).."\r\n"
   end
   MsgRange = "\r\n\r\n".." --------- Releases from "..s.."-"..e.." (out of "
   ..#AllStuff..") -------- \r\n"..MsgRange.."\r\n --------- Releases from "..s
   .."-"..e.." (out of "..#AllStuff..") -------- \r\n\r\n"
   return MsgRange
end

--- Reloads releases and generates the required global tables.
function ReloadRel()
   OpenRel()
   ShowRel(NewestStuff)
   ShowRel()
end

--- Splits a time format to components, originally written by RabidWombat.
-- Supported formats: MM/DD/YYYY HH:MM, YYYY. MM. DD. HH:MM, MM/DD/YY HH:MM
-- and YY. MM. DD. HH:MM
function SplitTimeString(TimeString)
   local D,M,Y,HR,MN,SC
   if string.find(TimeString,"/") then
      M,D,Y,HR,MN,SC=string.match(TimeString,"(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)"
      ..":(%d+)")
   else
      Y,M,D,HR,MN,SC = string.match(TimeString, "([^.]+).([^.]+).([^.]+)."
      .."([^:]+).([^:]+).(%S+)")
   end
   assert(Y:len()==2 or Y:len()==4,"Year must be 4 or 2 digits!")
   if Y:len()==2 then if Y:sub(1,1)=="0" then Y="20"..Y else Y="19"..Y end end
   D = tonumber(D)
   M = tonumber(M)
   Y = tonumber(Y)
   HR = tonumber(HR)
   MN = tonumber(MN)
   SC = tonumber(SC)
   return {year=Y, month=M, day=D, hour=HR, min=MN, sec=SC}
end

-- The following 2 functions are
-- Copyright (c) 2005, plop
-- All rights reserved.
JulianDate = function(tTime)
  tTime = tTime or os.date("*t")
  return os.time({year = tTime.year, month = tTime.month, day = tTime.day,
    hour = tTime.hour, min = tTime.min, sec = tTime.sec}
  )
end

JulianDiff = function(iThen, iNow)
  return os.difftime( (iNow or JulianDate()) , iThen)
end
-- End of plop's code

function GetNewRelNumForToday()
  local new_today = 0
  for k,v in ipairs(AllStuff) do
    if v[3] == os.date("%m/%d/%Y") then
      new_today = new_today + 1
    end
  end
  return new_today
end

--- Levenshtein distance algorithm from http://bit.ly/bCGkiX
-- The above page also links to the wikipedia entry.
-- Here I use it for comparing two strings. In my practice, 75% means they're
-- nearly identical so further check is required.
-- @return Is actually the ratio of the difference and the longer string, sub-
-- @return tracted from 1.
function Levenshtein (string1, string2)
  string1 = string1:lower(); string2 = string2:lower()
  local str1, str2, distance = {}, {}, {};
  local str1len, str2len = string1:len(), string2:len();
  for s in string.gmatch(string1, "(.)") do
    table.insert(str1, s);
  end
  for s in string.gmatch(string2, "(.)") do
    table.insert(str2, s)
  end
  for i = 0, str1len do
    distance[i] = distance[i] or {}
    distance[i][0] = i;
  end
  for i = 0, str2len do
    distance[i] = distance[i] or {}
    distance[0][i] = i;
  end
  for i = 1, str1len do
    for j = 1, str2len do
      local tmpdist = 1;
      if(str1[i-1] == str2[j-1]) then
        tmpdist = 0;
      end
      distance[i][j] = math.min( distance[i-1][j] + 1,
      distance[i][j-1]+1, distance[i-1][j-1] + tmpdist);
    end
  end
  return 1-distance[str1len][str2len]/math.max(str1len, str2len)
end

--module ("Main", package.seeall)
ModulesLoaded["Main"] = true

function ComparisonHelper(tbl, nick)
   local PIC = 0 -- Processed Items Counter (smart acronym, SRSLY)
   local req, id = tbl.Release, tbl.CurrID
   local match = {}
   local bExact
   while true do -- endless loop
      -- raise release ID by 1
      id = id + 1
      if id > #AllStuff then
         -- we have reached the last release, so stop this thread
         break
      end
      local percent = 100*Levenshtein (AllStuff[id][4], req) -- compare
      PIC = PIC + 1
      if percent >= MaxMatch then
         table.insert(match, {id, req, percent}) -- there is a match, register
         -- if 100% match found, further checking is futile
         if percent == 100 then return PIC, match; end
      end
      if PIC >= ItemsToCheckAtOnce then -- no more for this session
         Coroutines[nick].CurrID = id -- record the last processed ID
         coroutine.yield(PIC)-- and go sleeping
         PIC = 0
         -- When we wake up, the loop resumes
      end
   end
   id = 0
   while true do
      id = id + 1
      if id > #PendingStuff then break end
      local percent = 100*Levenshtein (PendingStuff[id][4], req)
      PIC = PIC + 1
      if percent == 100 then -- if matches
         table.insert(match, {id, req, percent, true})
         return PIC, match
      end
      if PIC >= ItemsToCheckAtOnce then
         Coroutines[nick].CurrID = id
         coroutine.yield(PIC)
         PIC = 0
      end
   end
  return PIC, match -- return if there are matches, stopping the coroutine
end

local function MainTableParser()
   local bOK, rePIC, match, nick, tbl
   while true do
      nick, tbl = next (Coroutines, nick)
      if nick then
         if coroutine.status(tbl.Coroutine) ~= "dead" then
            bOK, rePIC, match = coroutine.resume(tbl.Coroutine, tbl, nick)
            -- syntax error
            if not bOK then return nil, rePIC; end
            -- the coroutine finished
            if match then return match, tbl, nick end
            -- reached the max number of items, sleep
            if rePIC >= ItemsToCheckAtOnce then coroutine.yield() end
         else
            Coroutines[nick] = nil
         end
      else
         -- If the table is empty, we just return an empty table plus 2 nil's.
         -- If not, the gets returned with friends either non-nil.
         -- See Timer() below.
         return match or {}, tbl, nick
      end
   end
end

local MainTableHelper = coroutine.create (MainTableParser)

function Timer()
   if coroutine.status (MainTableHelper) == "dead" then
      MainTableHelper = coroutine.create (MainTableParser)
   end
   local bOK, match, tbl, nick = coroutine.resume (MainTableHelper)
   if nick then -- the coroutine explicitly returned = finished
      local tune, cat = tbl.Release, tbl.Category
      if next (match) then
         -- Sort the table in reverse order for percentages.
         -- This ensures that if a 100% is found nothing will get added
         -- afterwards.
         table.sort(match, function (el1, el2)
            return el1[3] > el2[3]
         end)
         for k, v in ipairs (match) do
            local id, rel, percent, bPending = unpack (v)
            local msg =
            "\""..rel.."\" has been added to the to-be-reviewed releases "
            .."in this category: \""..Types[cat].."\" with ID "
            ..(#PendingStuff + 1)
            ..". \r\nIt needs to be accepted by an authorized user before it"
            .." appears on the list"
            local msg_op = "A release has been added by "..nick.. " that is"
            .." quite similar to the following release(s):\r\n"
            local FoundSame -- boolean for 100% match
            local policy_msg =
            {
               msg..". Note that it is quite similar to the followi"
               .."ng release(s):",
               msg.." BECAUSE it is quite similar to the followi"
               .."ng release(s):",
            }
            msg = policy_msg[ReleaseApprovalPolicy] or "\""..tune
            .."\" has been added to the releases in this category: \""
            ..Types[cat].."\" with ID "..(#AllStuff + 1)..". Note that it is"
            .." quite similar to the following release(s):"
            if percent == 100 then -- identical!
               if bPending then
                  PM(nick, "A release with the same name is already "
                  .."awaiting  approval. Release has NOT been added.")
               else
                  PM(nick, "Your release is identical to the following "
                  .."release(s): \r\nID# "..id.." - Name: "..tune
                  ..".\r\n\r\nRelease has NOT been added.")
               end
               FoundSame = true
               break -- break the loop, we already have this release
            else
               msg = msg.."\r\n"..id.." - "..tune.." ("..percent.."%)"
               msg_op = msg_op.."\r\n"..id.." - "..tune.." ("..percent
               .."%)"
            end
            if not FoundSame then
               if ReleaseApprovalPolicy ~= 3 then
                  msg_op = msg_op.."\r\n\r\nPlease review! Thanks!"
                  PendingStuff(cat, nick, os.date("%m/%d/%Y"),
                  tune, msg, msg_op)
               else
                  AllStuff(cat, nick, os.date("%m/%d/%Y"), tune, msg, msg_op)
               end
            end
         end
      else -- not even a single similar release found, add the stuff
         if ReleaseApprovalPolicy ~= 1 then
            msg = "\""..tbl.Release
            .."\" has been added to the releases in this category: \""
            ..Types[cat].."\" with ID "..(#AllStuff + 1).."."
            AllStuff(cat, nick, os.date("%m/%d/%Y"), tune, msg)
         end
      end
   elseif not bOK then -- there is a syntax error
      SendOut(match) -- forward it to ops
   end
end

ReloadRel()

SendOut(Bot.version.." kernel loaded.")
