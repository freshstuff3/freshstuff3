-- PtokaX module for FreshStuff3 v5 by bastya_elvtars
-- License: GNU GPL v2
-- This module declares the events on PtokaX and contains other PtokaX-specific stuff.
-- Gets loaded only if the script detects PtokaX as host app
-- Warning: the "module" declaration only goes before the OnRelAdded function, since we only need to add that to the "px" table
-- Not so elegant, but works.

SendOut=function (msg)
  SendToOps(Bot.name,msg)
end

GetPath=frmHub:GetPtokaXLocation()

commandtable,rightclick,rctosend={},{},{}
local tbl={[0]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 },[1]={[5]=7, [0]=6, [4]=5, [1]=4, [2]=3, [3]=2, [-1]=1},[2]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 ,[4] = 6, [5] = 7}}
userlevels=tbl[ProfilesUsed] or { [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 }

function Main()
  frmHub:RegBot(Bot.name,1,Bot.desc,Bot.email)
  setmetatable(rightclick,_rightclick)
  for a,b in pairs(Types) do
    rightclick[{Levels.Add,"1 3","Releases\\Add an item to the\\"..b,"!"..Commands.Add.." "..a.." %[line:Name:]"}]=0
    rightclick[{Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\All","!"..Commands.Show.." "..a}]=0
    rightclick[{Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\Latest...","!"..Commands.Show.." "..a.." %[line:Number of items to show:]"}]=0
  end
  for _,arr in pairs(rctosend) do -- and we alphabetize (sometimes eyecandy is also necessary)
    table.sort(arr) -- sort the array
  end
  SetTimer(60000)
  StartTimer()
  for modname in pairs(package.loaded) do
    local t={["_G"]=1,["pickle"]=1}
    if not t[modname] then -- omit the global environment!!!
      local ret1,ret2
      if _G[modname] and _G[modname].Main then ret1,ret2=_G[modname].Main() end
      if ret1 and ret2 then
        local parseret={{SendTxt,{user.sName,env}},{user.SendPM,{user}},{SendToOps,{}},{SendToAll,{}}}
        local c=parseret[ret2]
        c[1](unpack(c[2]),Bot.name,ret1)
      end
    end
  end
end

function ChatArrival(user,data)
  local cmd,msg=data:sub(1,-2):match("%b<>%s+[%!%+%#%?%-](%S+)%s*(.*)")
  if commandtable[cmd] then
    parsecmds(user,msg,"MAIN",string.lower(cmd))
    return 1
  end
end

function ToArrival(user,data)
  local whoto,cmd,msg = data:sub(1,-2):match("$To:%s+(%S+)%s+From:%s+%S+%s+$%b<>%s+[%!%+%#%?%-](%S+)%s*(.*)")
  if commandtable[cmd] then
    parsecmds(user,msg,"PM",string.lower(cmd),whoto)
    return 1
  end
end

function NewUserConnected(user)
  if  user.bUserCommand then -- if login is successful, and usercommands can be sent
    user:SendData(table.concat(rctosend[user.iProfile],"|"))
    user:SendData(Bot.name,(table.getn(rctosend[user.iProfile])).." rightclick commands sent to you by "..botver)
  end
  if Count > 0 then
    if ShowOnEntry ~=0 then
      if ShowOnEntry==1 then
        SendTxt(user.sName,"PM",Bot.name, MsgNew)
      else
        SendTxt(user.sName,"MAIN",Bot.name, MsgNew)
      end
    end
  end
  for modname in pairs(package.loaded) do
    if modname~="_G" then -- omit the global environment!!!
      local ret1,ret2
      if _G[modname] and _G[modname].NewUserConnected then ret1,ret2=_G[modname].NewUserConnected(user.sName) end
      if ret1 and ret2 then
        local parseret={{SendTxt,{user.sName,env}},{user.SendPM,{user}},{SendToOps,{}},{SendToAll,{}}}
        parseret[ret2][1](unpack(parseret[ret2][2]),Bot.name,ret1)
      end
    end
  end
end

function OnTimer()
  if WhenAndWhatToShow[os.date("%H:%M")] then
    if Types[WhenAndWhatToShow[os.date("%H:%M")]] then
      SendToAll(Bot.name, ShowRelType(WhenAndWhatToShow[os.date("%H:%M")]))
    else
      if WhenAndWhatToShow[os.date("%H:%M")]=="new" then
        SendToAll(Bot.name, MsgNew)
      elseif WhenAndWhatToShow[os.date("%H:%M")]=="all" then
        SendToAll(Bot.name, MsgAll)
    else
        SendToOps(Bot.name,"Some fool added something to my timed ad list that I never heard of. :-)")
      end
    end
  end
  Timer=0
end

OpConnected=NewUserConnected
OpDisconnected=UserDisconnected

function parsecmds(user,msg,env,cmd,bot)
  bot=bot or Bot.name
  if commandtable[cmd] then -- if it exists
    local m=commandtable[cmd]
    if m["level"]~=0 then -- and enabled
      if userlevels[user.iProfile] >= m["level"] then -- and user has enough rights
        local ret1,ret2=m["func"](user.sName,msg,unpack(m["parms"])) -- user,data,env and more params afterwards
        if ret2 then
          local parseret={{SendTxt,{user.sName,env,bot,ret1}},{user.SendPM,{user,bot,ret1}},{SendToOps,{bot,ret1}},{SendToAll,{bot,ret1}}}
          parseret[ret2][1](unpack(parseret[ret2][2])); return 1
        end
      end
    else
       SendTxt(user.sName,env,bot,"You are not allowed to use this command."); return 1
    end
  else
    SendTxt(user.sName,env,bot,"The command you tried to use is disabled now. Contact the hubowner if you want it back."); return 1
  end
end

_rightclick=
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

function SendTxt(nick,env,bot,text) -- sends message according to environment (main or pm)
  if env=="PM" then
    SendPmToNick(nick,bot,text)
  else
    SendToNick(nick,"<"..bot.."> "..text)
  end
end

function Allowed (user, level)
  if userlevels[user.iProfile] >= level then return true end
end

for _,profName in ipairs(GetProfiles()) do
  local idx=GetProfileIdx(profName)
	rctosend[idx]=rctosend[idx] or{}
end
setmetatable(rightclick,_rightclick)
rightclick[{Levels.ShowCtgrs,"1 3","Releases\\Show categories","!"..Commands.ShowCtgrs}]=0
rightclick[{Levels.Delete,"1 3","Releases\\Delete a release","!"..Commands.Delete.." %[line:ID number(s):]"}]=0
rightclick[{Levels.ReLoad,"1 3","Releases\\Reload releases database","!"..Commands.ReLoad}]=0
rightclick[{Levels.Search,"1 3","Releases\\Search among releases","!"..Commands.Search.." %[line:Search string:]"}]=0
rightclick[{Levels.AddCatgry,"1 3","Releases\\Add a category","!"..Commands.AddCatgry.." %[line:Category name:] %[line:Displayed name:]"}]=0
rightclick[{Levels.DelCatgry,"1 3","Releases\\Delete a category","!"..Commands.DelCatgry.." %[line:Category name:]"}]=0
rightclick[{Levels.Help,"1 3","Releases\\Help","!"..Commands.Help}]=0
rightclick[{Levels.Show,"1 3","Releases\\Show all items","!"..Commands.Show}]=0

-- We're done. Now let's do something with FreshStuff's own events. :-D

_Engine= -- The metatable for commands engine. I thought it should be hostapp-specific, so we can avoid useless things, like rightclick in BCDC.
  { 
    __newindex=function(tbl,cmd,stuff)
      commandtable[cmd]={["func"]=stuff[1],["parms"]=stuff[2],["level"]=stuff[3],["help"]=stuff[4]}
    end
  }

function OnRelAdded(nick,data,cat,tune)
  SendTxt(nick,env,Bot.name, tune.." is added to the releases as "..cat)
  SendToAll(Bot.name, nick.." added to the "..cat.." releases: "..tune)
  for modname in pairs(package.loaded) do
  local func=loadstring(modname.."OnRelAdded")
    if func then
      local txt,ret=func(user,data,cat,tune)
      if txt and ret then
        local parseret={{SendTxt,{nick,env,Bot.name,ret1}},{user.SendPM,{user,Bot.name,ret1}},{SendToOps,{Bot.name,ret1}},{SendToAll,{Bot.name,ret1}}}
        parseret[ret2][1](unpack(parseret[ret2][2]));
      end
    end
  end
end

function OnReqFulfilled(nick,data,cat,tune,reqcomp,username,reqdetails)
  local usr=GetItemByName(username); if usr then
    usr:SendPM(Bot.name,"\""..reqdetails.."\" has been added by "..nick.." on your request. It is named \""..tune.."\" under category "..cat..".")
    Requests.Completed[usr.sName]=nil
    local f=io.open("freshstuff/data/requests_comp.dat","w+")
    for k,v in pairs(Requests.Completed) do
      f:write(k.."$"..table.concat(v,"$").."\n")
    end
    f:close()
  end
end

local x,y=getHubVersion()
SendOut("*** "..botver.." running on "..x.." "..y.." loading.")