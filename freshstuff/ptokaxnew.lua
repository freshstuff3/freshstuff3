--[[
PtokaX module for FreshStuff3 v5 by bastya_elvtars
This is for the new PtokaX API (beta)
This module declares the events on PtokaX and contains other PtokaX-specific stuff.
Gets loaded only if the script detects PtokaX as host app
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]

-- Debug message sending
SendOut = Core.SendToOps
-- SendOut(Core.GetPtokaXPath())
ScriptsPath = Core.GetPtokaXPath().."scripts/freshstuff/"
local conf = ScriptsPath.."config/main.lua"
local _,err = loadfile (conf)
if not err then dofile (conf) else error(err) end

-- We need the application path
GetPath = Core.GetPtokaXPath

-- Declare table for commands and rightclick.
commandtable,rightclick,rctosend={},{},{}
-- This table is for deciding between RoboCop, Leviathan and others. These are unmaintained so I really dunno if
-- this type of support for them should be kept at all.
local tbl={[0]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 },[1]={[5]=7, [0]=6, [4]=5, [1]=4, [2]=3, [3]=2, [-1]=1},[2]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 ,[4] = 6, [5] = 7}}
userlevels=tbl[ProfilesUsed] or { [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 }

-- This is executed when the script starts.
function OnStartup()
  Today = os.date("%m/%d/%Y")
  Core.RegBot(Bot.name, "["..GetNewRelNumForToday().." new releases today] "..Bot.desc, Bot.email, true)
  if pcall (SetMan.GetBool, 55) then -- Log script errors.
    SetMan.SetBool(55, true)
  end
  setmetatable(rightclick, 
  {
    __newindex=function (tbl,key,PM)
      local level,context,name,command=unpack(key)
      if level~=0 then
        for idx,perm in pairs(userlevels) do
          rctosend[idx]=rctosend[idx] or {}
          if perm >= level then -- if user is allowed to use
            local message; if PM~=0 then
              message = "$UserCommand "..context.." "..name.."$$To: "..Bot.name.." From: %[mynick] $<%[mynick]> "..command.."&#124;"
            else
              message = "$UserCommand "..context.." "..name.."$<%[mynick]> "..command.."&#124;"
            end
            table.insert(rctosend[idx],message) -- then put to the array
          end
        end
      end
    end
  })
  for a,b in pairs(Types) do -- Add categories to rightclick. This is impossible on-the-fly.
    rightclick[{Levels.Add,"1 3","Releases\\Add an item to the\\"..b,"!"..Commands.Add.." "..a.." %[line:Name:]"}]=0
    rightclick[{Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\All","!"..Commands.Show.." "..a}]=0
    rightclick[{Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\Latest...","!"..Commands.Show.." "..a.." %[line:Number of items to show:]"}]=0
  end
  for _,arr in pairs(rctosend) do -- and we alphabetize (sometimes eyecandy is also necessary)
    table.sort(arr) -- sort the array
  end
  TmrMan.AddTimer(60000, "OnTimer")
  HandleEvent ("Start")
end

-- This is executed on a chat message
function ChatArrival(user,data)
  local cmd,msg=data:match("^%b<>%s+[%!%+%#%?%-](%S+)%s*(.*)%|$")
  -- We are parsing the command here
  if commandtable[cmd] then
    parsecmds(user,msg,"MAIN",string.lower(cmd))
    return true
  end
  -- This event is only fired if the chat message is NOT a command.
  HandleEvent ("ChatMsg",user.sNick,data)
end

-- This is executed on a private message
function ToArrival(user,data)
  local whoto,cmd,msg = data:match("^$To:%s+(%S+)%s+From:%s+%S+%s+$%b<>%s+[%!%+%#%?%-](%S+)%s*(.*)%|$")
  if commandtable[cmd] then
    parsecmds(user,msg,"PM",string.lower(cmd),whoto)
    return true
  end
  HandleEvent ("PrivMsg",user.sNick,data)
end

-- This is executed when a new user connects.
-- Covers regs and operators as well.
function UserConnected(user)
  if  Core.GetUserValue(user, 12) then -- if login is successful, and usercommands can be sent
    Core.SendToUser(user, table.concat(rctosend[user.iProfile], "|")) -- This may be faster than sending one by one.
    Core.SendToUser(user, (table.getn(rctosend[user.iProfile])).." rightclick commands sent to you by "..Bot.version)
  end
  if #AllStuff > 0 then
    if ShowOnEntry ~=0 then
      if ShowOnEntry==1 then
        SendTxt(user,"PM",Bot.name, MsgNew)
      else
        SendTxt(user,"MAIN",Bot.name, MsgNew)
      end
    end
  end
  HandleEvent ("Connected",user.sNick)
end

function OnTimer()
  -- Only do event handling here.
  -- This is to avoid stack overflows caused by recursions.
  HandleEvent("Timer")
end

OpConnected=UserConnected
RegConnected=UserConnected
OpDisconnected=UserDisconnected
RegDisconnected=UserDisconnected

function OnError(err)
  SendOut(err)
end

function parsecmds(user,msg,env,cmd,bot)
  bot = bot or Bot.name
  if commandtable[cmd] then -- if it exists
    local m = commandtable[cmd]
    if m["level"]~=0 then -- and enabled
      if userlevels[user.iProfile] >= m["level"] then -- and user has enough rights
        local ret1,ret2 = m["func"](user.sNick,msg,unpack(m["parms"])) -- user,data,env and more params afterwards
        if ret1:len() > 128000 then ret1 = 
          "The command's output would exceed 128,000 characters. Please report this issue "..
          "to the hubowner, (s)he will be able to help as the bot contains alternative methods with which you can retrieve the "..
          "information you need." 
        end
        if ret2 then
          local parseret=
            {
              {SendTxt,{user, env, bot, ret1}},
              {Core.SendPmToUser,{user, bot, ret1}},
              {Core.SendToOps,{"<"..bot.."> "..ret1}},
              {Core.SendToAll,{"<"..bot.."> "..ret1}},
            }
          parseret[ret2][1](unpack(parseret[ret2][2])); return true
        end
      else
        SendTxt(user,env,bot,"You are not allowed to use this command."); return true
      end
    else
      SendTxt(user,env,bot,"The command you tried to use is disabled now. Contact the hubowner if you want it back."); return true
    end
  end
end
 
function SendTxt(user, env, bot, text) -- sends message according to environment (main or pm)
--   local user = Core.GetUser(nick)
  if env=="PM" then
    Core.SendPmToUser(user, bot, text)
  else
    Core.SendToUser(user,"<"..bot.."> "..text)
  end
end

function Allowed (nick, level) -- This is hostapp-independent checking. All hostapp-modules MUST declare it.
  if userlevels[Core.GetUser(nick).iProfile] >= level then return 1 end
end

-- Rightclick hadling.

for _, prof in ipairs(ProfMan.GetProfiles()) do
	rctosend[prof.iProfileNumber]=rctosend[prof.iProfileNumber] or {}
end

setmetatable(rightclick,
  {
  __newindex=function (tbl, key, PM)
    local level,context,name,command=unpack(key)
    if level~=0 then
      for idx,perm in pairs(userlevels) do
        rctosend[idx]=rctosend[idx] or {}
        if perm >= level then -- if user is allowed to use
          local message; if PM~=0 then
            message="$UserCommand "..context.." "..name.."$$To: "..Bot.name.." From: %[mynick] $<%[mynick]> "..command.."&#124;"
          else
            message="$UserCommand "..context.." "..name.."$<%[mynick]> "..command.."&#124;"
          end
          table.insert(rctosend[idx],message) -- then put to the array
        end
      end
    end
  end
  }
)

rightclick[{Levels.ShowCtgrs,"1 3","Releases\\Show categories","!"..Commands.ShowCtgrs}]=0
rightclick[{Levels.Delete,"1 3","Releases\\Delete a release","!"..Commands.Delete.." %[line:ID number(s):]"}]=0
rightclick[{Levels.ReLoad,"1 3","Releases\\Reload releases database","!"..Commands.ReLoad}]=0
rightclick[{Levels.Search,"1 3","Releases\\Search among releases","!"..Commands.Search.." %[line:Search string:]"}]=0
rightclick[{Levels.AddCatgry,"1 3","Releases\\Add a category","!"..Commands.AddCatgry.." %[line:Category name:] %[line:Displayed name:]"}]=0
rightclick[{Levels.DelCatgry,"1 3","Releases\\Delete a category","!"..Commands.DelCatgry.." %[line:Category name:]"}]=0
rightclick[{Levels.Help,"1 3","Releases\\Help","!"..Commands.Help}]=0
rightclick[{Levels.Show,"1 3","Releases\\Show all items","!"..Commands.Show}]=0
rightclick[{Levels.Show,"1 3","Releases\\Show last "..MaxNew.." items","!"..Commands.Show.." new"}]=0
rightclick[{Levels.Show,"1 3","Releases\\Show items in a certain range","!"..Commands.Show.." %[line:Start ID:]-%[line:End ID:]"}]=0

-- We're done. Now let's do something with FreshStuff's own events. :-D

_Engine= -- The metatable for commands engine. I thought it should be hostapp-specific, so we can avoid useless things, like rightclick in BCDC.
  { 
    __newindex=function(tbl,cmd,stuff)
      commandtable[cmd]={["func"]=stuff[1],["parms"]=stuff[2],["level"]=stuff[3],["help"]=stuff[4]}
    end
  }
  
-- This is our event handler.
function HandleEvent (event, nick, ...)
  for pkg, moddy in pairs(package.loaded) do
    if ModulesLoaded[pkg] and type(moddy[event]) == "function" then
      local txt, ret = moddy[event](nick, ...)
      if txt and ret then
--         local user  = Core.GetUser(nick)
        local parseret={{Core.SendToNick,{nick,"<"..Bot.name.."> "..txt.."|"}},{Core.SendPmToNick,{nick,Bot.name,txt.."|"}},{Core.SendToOps,{"<"..Bot.name.."> "..txt.."|"}},{Core.SendToAll,{"<"..Bot.name.."> "..txt.."|"}}}
        parseret[ret][1](unpack(parseret[ret][2]));
      end
    end
  end
end
  
-- Many thanks to Luiz Henrique de Figueiredo and Jérôme Vuarand for hints on module handling

module("ptokax", package.seeall)
-- We track modules to avoid overflows
ModulesLoaded["ptokax"] = 1
  
function OnRelAdded (nick, data, cat, tune)
  Core.UnregBot(Bot.name)
  Core.RegBot(Bot.name,"["..GetNewRelNumForToday().." new releases today] "..Bot.desc,Bot.email, true)
  Core.SendToAll("<"..Bot.name.."> "..nick.." added to the "..cat.." releases: "..tune)
end

function OnRelDeleted ()
  Core.UnregBot(Bot.name)
  Core.RegBot(Bot.name,"["..(GetNewRelNumForToday()-1).." new releases today] "..Bot.desc,Bot.email,true)
end

OnCatDeleted = OnRelDeleted

function OnReqFulfilled(nick, data, cat, tune, reqcomp, username, reqdetails)
  local usr=Core.GetUser(username); if usr then
    Core.SendPmToUser(usr,Bot.name,"The stuff you requested (you named it \""..reqdetails.."\")"
    .."has been added by "..nick.." on your request. It is named \""..tune.."\" under category "..cat..".")
    -- Since we 've notified the user, the table entry can be removed.
    Requests.Completed[usr.sNick]=nil
    table.save(Requests.Completed, ScriptsPath.."data/requests_comp.dat")
  end
  Core.SendToAll("<"..Bot.name.."> Request #"..reqcomp.." has successfully been fulfilled thanks to "..nick..".")
end

function Timer()
  if os.date("%m/%d/%Y") ~= Today then
    Today = os.date("%m/%d/%Y")
    Core.UnregBot(Bot.name)
    Core.RegBot(Bot.name,"["..GetNewRelNumForToday().." new releases today] "..Bot.desc,Bot.email, true)
  end
  if #AllStuff > 0 then
     -- to avoid sync errors and unnecessary function calls/tanle lookups
     -- declare the local variable
    local stuff = WhenAndWhatToShow[os.date("%H:%M")]
    if stuff then
      if Types[stuff] then
        Core.SendToAll("<"..Bot.name.."> "..ShowRelType(stuff))
      else
        if stuff == "new" then
          Core.SendToAll("<"..Bot.name.."> "..MsgNew)
        elseif stuff == "all" then
          Core.SendToAll("<"..Bot.name.."> "..MsgAll)
        else
          Core.SendToOps("<"..Bot.name.."> Some fool added something to my timed ad list that I have never heard of. :-)")
        end
      end
    end
  end
end

SendOut("*** "..Bot.version.." detected PtokaX "..Core.Version.." as host app.")