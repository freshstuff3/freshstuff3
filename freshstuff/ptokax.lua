-- PtokaX module for FreshStuff3 v5 by bastya_elvtars
-- License: GNU GPL v2
-- This module declares the events on PtokaX and contains other PtokaX-specific stuff.
-- Gets loaded only if the script detects PtokaX as host app
-- Warning: the "module" declaration only goes before the OnRelAdded function, since we only need to add that to the "px" table
-- Not so elegant, but works.

SendOut=SendToOps

function Main()
	local tbl={[0]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 },[1]={[5]=7, [0]=6, [4]=5, [1]=4, [2]=3, [3]=2, [-1]=1},[2]={ [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 ,[4] = 6, [5] = 7}}
	userlevels=tbl[ProfilesUsed] or { [-1] = 1, [0] = 5, [1] = 4, [2] = 3, [3] = 2 }
  frmHub:RegBot(Bot.name,1,Bot.desc,Bot.email)
  if loadfile("freshstuff/data/categories.dat") then
    Types=table.load("freshstuff/data/categories.dat")
  else
    Types={
      ["warez"]="Warez",
      ["game"]="Games",
      ["music"]="Music",
      ["movie"]="Movies",
    }
    SendToOps(Bot.name,"The categories file is corrupt or missing! Created a new one.")
    SendToOps(Bot.name,"If this is the first time you run this script, or newly installed it, please copy your old releases.dat (if any) to the folder called freshstuff (located inside scripts folder, and restart your scripts. Thank you!")
    table.save(Types,"freshstuff/data/categories.dat")
  end
  CreateRightClicks()
  ReloadRel()
  SetTimer(60000)
  StartTimer()
  for modname in pairs(package.loaded) do
    local t={["_G"]=1,["pickle"]=1}
    if not t[modname] then -- omit the global environment!!!
      local ret1,ret2
      if _G[modname] and _G[modname].Main then ret1,ret2=_G[modname].Main() end
      if ret1 and ret2 then
        local parseret={{SendTxt,{user,env}},{user.SendPM,{user}},{SendToOps,{}},{SendToAll,{}}}
        parseret[ret2][1](unpack(parseret[ret2][2]),Bot.name,ret1)
      end
    end
  end
end

function ChatArrival(user,data)
  data=string.sub(data,1,string.len(data)-1)
  local _,_,cmd=string.find(data,"%b<>%s+[%!%+%#%?%-](%S+)")
  if commandtable[cmd] then
    parsecmds(user,data,"MAIN",string.lower(cmd))
    return 1
  end
end

function ToArrival(user,data)
  data=string.sub(data,1,string.len(data)-1)
  local _,_,whoto,cmd = string.find(data,"$To:%s+(%S+)%s+From:%s+%S+%s+$%b<>%s+[%!%+%#%?%-](%S+)")
  if commandtable[cmd] then
    parsecmds(user,data,"PM",string.lower(cmd),whoto)
    return 1
  end
end

function NewUserConnected(user)
  if  user.bUserCommand then -- if login is successful, and usercommands can be sent
    user:SendData(table.concat(rctosend[user.iProfile],"|"))
    user:SendData(Bot.name,(table.getn(rctosend[user.iProfile])).." rightclick commands sent to you by ")
  end
  if Count > 0 then
    if ShowOnEntry ~=0 then
      if ShowOnEntry==1 then
        SendTxt(user,"PM",Bot.name, MsgNew)
      else
        SendTxt(user,"MAIN",Bot.name, MsgNew)
      end
    end
  end
  for modname in pairs(package.loaded) do
    if modname~="_G" then -- omit the global environment!!!
      local ret1,ret2
      if _G[modname] and _G[modname].NewUserConnected then ret1,ret2=_G[modname].NewUserConnected(user) end
      if ret1 and ret2 then
        local parseret={{SendTxt,{user,env}},{user.SendPM,{user}},{SendToOps,{}},{SendToAll,{}}}
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

function parsecmds(user,data,env,cmd,bot)
  if commandtable[cmd] then -- if it exists
    local m=commandtable[cmd]
    if m["level"]~=0 then -- and enabled
      if userlevels[user.iProfile] >= m["level"] then -- and user has enough rights
        local ret1,ret2=m["func"](user,data,env,unpack(m["parms"])) -- user,data,env and more params afterwards
        if ret2 then
          local parseret={{SendTxt,{user,env,Bot.name,ret1}},{user.SendPM,{user,Bot.name,ret1}},{SendToOps,{Bot.name,ret1}},{SendToAll,{Bot.name,ret1}}}
          parseret[ret2][1](unpack(parseret[ret2][2])); return 1
        end
      end
    else
       SendTxt(user,env,bot,"You are not allowed to use this command.")
    end
  else
    SendTxt(user,env,bot,"The command you tried to use is disabled now. Contact the hubowner if you want it back.")
  end
end

function RegCmd(cmnd,func,parms,level,help) -- regs a command, parsed on ToArrival and ChatArrival
  commandtable[cmnd]={["func"]=func,["parms"]=parms,["level"]=level,["help"]=help}
end

function RegRC(level,context,name,command,PM)
  if level==0 then return 1 end
  if not PM then
    rightclick["$UserCommand "..context.." "..name.."$<%[mynick]> "..command.."&#124;"]=level
  else
    rightclick["$UserCommand "..context.." "..name.."$$To: "..Bot.name.." From: %[mynick] $<%[mynick]> "..command.."&#124;"]=level
  end
end

function SendTxt(user,env,bot,text) -- sends message according to environment (main or pm)
  if env=="PM" then
    user:SendPM(bot,text)
  else
    user:SendData(bot,text)
  end
end

function CreateRightClicks()
	for _,profName in ipairs(GetProfiles()) do
		rctosend[GetProfileIdx(profName)]=rctosend[GetProfileIdx(profName)] or{}
	end
  for idx,perm in pairs(userlevels) do -- usual profiles
    rctosend[idx]=rctosend[idx] or {} -- create if not exist (but this is not SQL :-P)
    for a,b in pairs(rightclick) do -- run thru the rightclick table
      if perm >= b then -- if user is allowed to use
        table.insert(rctosend[idx],a) -- then put to the array
      end
    end
    for _,arr in pairs(rctosend) do -- and we alphabetize (sometimes eyecandy is also necessary)
      table.sort(arr) -- sort the array
    end
  end
end

function Allowed (user, level)
  if userlevels[user.iProfile] >= level then return true end
end

-- RegCmd(Commands.Add,AddCrap,{},Levels.Add,"<type> <name>\t\t\t\tAdd release of given type.")
-- RegCmd(Commands.Show,ShowCrap,{},Levels.Show,"<type>\t\t\t\t\tShows the releases of the given type, with no type specified, shows all.")
-- RegCmd(Commands.Delete,DelCrap,{},Levels.Delete,"<ID>\t\t\t\t\tDeletes the releases of the given ID, or deletes multiple ones if given like: 1,5,33,6789")
-- RegCmd(Commands.ReLoad,ReloadRel,{},Levels.ReLoad,"\t\t\t\t\t\tReloads the releases database.")
-- RegCmd(Commands.Search,SearchRel,{},Levels.Search,"<string>\t\t\t\t\tSearches for release NAMES containing the given string.")
-- RegCmd(Commands.AddCatgry,AddCatgry,{},Levels.AddCatgry,"<new_cat> <displayed_name>\t\t\tAdds a new release category, displayed_name is shown when listed.")
-- RegCmd(Commands.DelCatgry,DelCatgry,{},Levels.DelCatgry,"<cat>\t\t\t\t\tDeletes the given release category..")
-- RegCmd(Commands.ShowCtgrs,ShowCatgries,{},Levels.ShowCtgrs,"\t\t\t\t\tShows the available release categories.")
-- RegCmd(Commands.Prune,PruneRel,{},Levels.Prune,"<days>\t\t\t\t\tDeletes all releases older than n days, with no option, it deletes the ones older than "..MaxItemAge.." days.")
-- RegCmd(Commands.TopAdders,ShowTopAdders,{},Levels.TopAdders,"<number>\t\t\t\tShows the n top-release-adders (with no option, defaults to 5).")
RegRC(Levels.ShowCtgrs,"1 3","Releases\\Show categories","!"..Commands.ShowCtgrs)
RegRC(Levels.Delete,"1 3","Releases\\Delete a release","!"..Commands.Delete.." %[line:ID number(s):]")
RegRC(Levels.ReLoad,"1 3","Releases\\Reload releases database","!"..Commands.ReLoad)
RegRC(Levels.Search,"1 3","Releases\\Search among releases","!"..Commands.Search.." %[line:Search string:]")
RegRC(Levels.AddCatgry,"1 3","Releases\\Add a category","!"..Commands.AddCatgry.." %[line:Category name:] %[line:Displayed name:]")
RegRC(Levels.DelCatgry,"1 3","Releases\\Delete a category","!"..Commands.DelCatgry.." %[line:Category name:]")
-- RegRC(Levels.Prune,"1 3","Releases\\Delete old releases","!"..Commands.Prune.." %[line:Max. age in days (Enter=defaults to "..MaxItemAge.."):]")
-- RegRC(Levels.TopAdders,"1 3","Releases\\Show top release-adders","!"..Commands.TopAdders.." %[line:Number of top-adders (Enter defaults to 5):]")


-- 	RegRC(Levels.Help,"1 3","Releases\\Help","!"..Commands.Help)
--   for a,b in pairs(Types) do
--     RegRC(Levels.Add,"1 3","Releases\\Add an item to the\\"..b,"!"..Commands.Add.." "..a.." %[line:Name:]")
--     RegRC(Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\All","!"..Commands.Show.." "..a)
--     RegRC(Levels.Show,"1 3","Releases\\Show items of type\\"..b.."\\Latest...","!"..Commands.Show.." "..a.." %[line:Number of items to show:]")
--   end
-- 	RegRC(Levels.Show,"1 3","Releases\\Show all items","!"..Commands.Show)

-- We're done. Now let's do something with FreshStuff's own events. :-D

_Engine= -- The metatable for commands engine. I thought it should be hostapp-specific, so we can avoid useless things, like rightclick in BCDC.
  { 
    __newindex=function(tbl,cmd,stuff)
      commandtable[cmd]={["func"]=stuff[1],["parms"]=stuff[2],["level"]=stuff[3],["help"]=stuff[4]}
    end
  }

function OnRelAdded(user,data,cat,tune)
  SendTxt(user,env,Bot.name, tune.." is added to the releases as "..cat)
  SendToAll(Bot.name, user.sName.." added to the "..cat.." releases: "..tune)
  for modname in pairs(package.loaded) do
  local func=loadstring(modname.."OnRelAdded")
    if func then
      local txt,ret=func(user,data,cat,tune)
      if txt and ret then
        local parseret={{SendTxt,{user,env,Bot.name,ret1}},{user.SendPM,{user,Bot.name,ret1}},{SendToOps,{Bot.name,ret1}},{SendToAll,{Bot.name,ret1}}}
        parseret[ret2][1](unpack(parseret[ret2][2]));
      end
    end
  end
end

function OnReqFulfilled(user,data,cat,tune,nick,reqcomp,username,reqdetails)
  local usr=GetItemByName(username); if usr then
    usr:SendPM(Bot.name,"\""..reqdetails.."\" has been added by "..user.sName.." on your request. It is named \""..tune.."\" under category "..cat..".")
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