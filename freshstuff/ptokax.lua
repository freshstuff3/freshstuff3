--[[
PtokaX module for FreshStuff3 v5 by bastya_elvtars
This module declares the events on PtokaX and contains other PtokaX-specific stuff.
Gets loaded only if the script detects PtokaX as host app
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]


SendOut = SendToOps

-- We need the application path
GetPath=frmHub:GetPtokaXLocation()

-- Declare table for commands and rightclick.
commandtable,rightclick,rctosend={},{},{}
-- This table is for deciding between RoboCop, Leviathan and others. These are unmaintained so I really dunno if
-- this type of support for them should be kept at all.
local tbl={[0]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 },[1]={[5]=7, [0]=6, [4]=5, [1]=4, [2]=3, [3]=2, [-1]=1},[2]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 ,[4] = 6, [5] = 7}}
userlevels=tbl[ProfilesUsed] or { [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 }

-- This is executed when the script starts.
function Main()
  frmHub:RegBot(Bot.name,1,"["..GetNewRelNumForToday().." new releases today] "..Bot.desc,Bot.email)
  setmetatable(rightclick, 
  {
    __newindex=function (tbl,key,PM)
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
  })
  for a,b in pairs(Types) do -- Add categories to rightclick. This MIGHT be possible on-the-fly, just get the DC ÜB3RH4XX0R!!!11one1~~~ guys to fucking document $UserCommand
    rightclick[{Levels.Add,"1 3","Releases\\Add an item to the\\"..b,"!"..Commands.Add.." "..a.." %[line:Name:]"}]=0
    rightclick[{Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\All","!"..Commands.Show.." "..a}]=0
    rightclick[{Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\Latest...","!"..Commands.Show.." "..a.." %[line:Number of items to show:]"}]=0
  end
  for _,arr in pairs(rctosend) do -- and we alphabetize (sometimes eyecandy is also necessary)
    table.sort(arr)
  end
  SetTimer(60000) -- Start a timer.
  StartTimer()
  HandleEvent ("Start")
end

-- This is executed on a chat message
function ChatArrival(user,data)
  local cmd,msg=data:match("^%b<>%s+[%!%+%#%?%-](%S+)%s*(.*)%|$")
  -- We are parsing the command here
  if commandtable[cmd] then
    parsecmds(user,msg,"MAIN",string.lower(cmd))
    return 1
  end
  -- This event is only fired if the chat message is NOT a command.
  HandleEvent ("ChatMsg",user.sName,data)
end

-- This is executed on a private message
function ToArrival(user,data)
  local whoto,cmd,msg = data:match("^$To:%s+(%S+)%s+From:%s+%S+%s+$%b<>%s+[%!%+%#%?%-](%S+)%s*(.*)%|$")
  if commandtable[cmd] then
    parsecmds(user,msg,"PM",string.lower(cmd),whoto)
    return 1
  end
  HandleEvent ("PrivMsg",user.sName,data)
end

-- This is executed when a new user connects.
-- Covers operators as well.
function NewUserConnected(user)
  if  user.bUserCommand then -- if login is successful, and usercommands can be sent
    user:SendData(table.concat(rctosend[user.iProfile],"|")) -- This may be faster than sending one by one.
    user:SendData(Bot.name,(table.getn(rctosend[user.iProfile])).." rightclick commands sent to you by "..Bot.version)
  end
  if #AllStuff > 0 then
    if ShowOnEntry ~=0 then
      if ShowOnEntry==1 then
        SendTxt(user.sName,"PM",Bot.name, MsgNew)
      else
        SendTxt(user.sName,"MAIN",Bot.name, MsgNew)
      end
    end
  end
  HandleEvent ("UserConnected",user.sName)
end

function Ontimer()
  -- Only do event handling here.
  -- This is to avoid stack overflows caused by recursions.
  HandleEvent("Timer")
end

OpConnected=NewUserConnected
OpDisconnected=UserDisconnected

function OnError(err)
  SendOut(err)
end


function parsecmds(user,msg,env,cmd,bot)
  bot=bot or Bot.name
  if commandtable[cmd] then -- if it exists
    local m=commandtable[cmd]
    if m["level"]~=0 then -- and enabled
      if userlevels[user.iProfile] >= m["level"] then -- and user has enough rights
        local ret1,ret2=m["func"](user.sName,msg,unpack(m["parms"])) -- user,data,env and more params afterwards
        if ret1:len() > 128000 then ret1 = 
          "The command's output would exceed 128,000 characters. Please report this issue "..
          "to the hubowner, (s)he will be able to help as the bot contains alternative methods with which you can retrieve the "..
          "information you need." 
        end
        if ret2 then
          local parseret={{SendTxt,{user.sName,env,bot,ret1}},{user.SendPM,{user,bot,ret1}},{SendToOps,{bot,ret1}},{SendToAll,{bot,ret1}}}
          parseret[ret2][1](unpack(parseret[ret2][2])); return 1
        end
      else
        SendTxt(user.sName,env,bot,"You are not allowed to use this command."); return 1
      end
    else
      SendTxt(user.sName,env,bot,"The command you tried to use is disabled now. Contact the hubowner if you want it back."); return 1
    end
  end
end
 
function SendTxt(nick,env,bot,text) -- sends message according to environment (main or pm)
  if env=="PM" then
    SendPmToNick(nick, bot, text)
  else
    SendToNick(nick, "<"..bot.."> "..text)
  end
end

function Allowed (nick, level) -- This is hostapp-independent checking. All hostapp-modules MUST declare it.
  local user=GetItemByName(nick)
  if userlevels[user.iProfile] >= level then return true end
end

-- Rightclick hadling.

for _,profName in ipairs(GetProfiles()) do
  local idx=GetProfileIdx(profName)
	rctosend[idx]=rctosend[idx] or{}
end

setmetatable(rightclick,
  {
  __newindex=function (tbl,key,PM)
    SendToAll(Bot.name,key)
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
rightclick[{Levels.Show,"1 3","Releases\\Show items in a certain range","!"..Commands.Show.." %[line:Start ID:]-%[line:End ID:]"}]=0

-- We're finished. Now let's do something with FreshStuff's own events. :-D

_Engine= -- The metatable for commands engine. I thought it should be hostapp-specific, so we can avoid useless things, like rightclick in BCDC.
  { 
    __newindex=function(tbl,cmd,stuff)
      commandtable[cmd]={["func"]=stuff[1],["parms"]=stuff[2],["level"]=stuff[3],["help"]=stuff[4]}
    end
  }

-- This is our event handler.
function HandleEvent (event, ...)
  for pkg, moddy in pairs(package.loaded) do
    if ModulesLoaded[pkg] and type(moddy[event]) == "function" then
      local txt, ret = moddy[event](...)
      if txt and ret then
        local args = { ... }
        local user  = GetItemByName(args[1])
        local parseret={{SendTxt,{nick,env,Bot.name,txt}},{user.SendPM,{user,Bot.name,txt}},{SendToOps,{Bot.name,txt}},{SendToAll,{Bot.name,txt}}}
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
  frmHub:UnregBot(Bot.name)
  frmHub:RegBot(Bot.name,1,"["..GetNewRelNumForToday().." new releases today] "..Bot.desc,Bot.email)
  SendToAll(Bot.name, nick.." added to the "..cat.." releases: "..tune)
end

function OnRelDeleted ()
  frmHub:UnregBot(Bot.name)
  frmHub:RegBot(Bot.name,1,"["..(GetNewRelNumForToday()-1).." new releases today] "..Bot.desc,Bot.email)
end

function OnReqFulfilled(nick, data, cat, tune, reqcomp, username, reqdetails)
  local usr=GetItemByName(username); if usr then
    usr:SendPM(Bot.name,"\""..reqdetails.."\" has been added by "..nick.." on your request. It is named \""..tune.."\" under category "..cat..".")
    -- Since we 've notified the user, the table entry can be removed.
    Requests.Completed[usr.sName]=nil
    table.save(Requests.Completed, "freshstuff/data/requests_comp.dat")
  end
end

function Timer()
  if #AllStuff > 0 then
     -- to avoid sync errors and unnecessary function calls/table lookups
     -- declare the local variable
    local stuff = WhenAndWhatToShow[os.date("%H:%M")]
    if stuff then
      if Types[stuff] then
        SendToAll(Bot.name, ShowRelType(stuff))
      else
        if stuff == "new" then
          SendToAll(Bot.name, MsgNew)
        elseif stuff == "all" then
          SendToAll(Bot.name, MsgAll)
        else
          SendToOps(Bot.name,"Some fool added something to my timed ad list that I have never heard of. :-)")
        end
      end
    end
  end
end

local x,y=getHubVersion()
SendOut("*** "..Bot.version.." detected "..x.." "..y.." as host app.")