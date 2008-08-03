--[[
Core module for FreshStuff3 v5 by bastya_elvtars
License: GNU GPL v2
This module contains functions that generate the required messages, save/load releases etc.
Command functions return a number after the required parameters and the string to be sent:
        1: sendtxt (on env/PM only in BCDC),
        2: PM only (same in BCDC),
        3: to ops (N/A in BCDC, maybe DC():PrintDebug, or hub:injectChat?)
        4: to all (BCDC: hub:sendChat)
That way, we have hostapp-independent code.
]]

do
  setmetatable (Engine,_Engine)
  Engine[Commands.Show]=
    {
      function (user,data)
        if Count < 1 then return "There are no releases yet, please check back soon.",1 end
        local cat= string.match(data, "%b<>%s+%S+%s+(%S+)")
        local latest=string.match(data, "%b<>%s+%S+%s+%S+%s+(%d+)")
        if not cat then
          return MsgAll,1
        else
          if cat == "new" then
            return MsgNew,1
          elseif Types[cat] then
            if latest then
              return ShowRelNum(cat,latest),1
            else
              return ShowRelType(cat),1
            end
          else
            return "No such type.",1 
          end
        end
      end,
      {},Levels.Show,"<type>\t\t\t\t\tShows the releases of the given type, with no type specified, shows all." 
    }
  Engine[Commands.Add]=
    {
      function (user,data)
        local nick
        if hostprg==1 then nick=user.sName end
        local cat,tune= string.match(data, "%b<>%s+%S+%s+(%S+)%s+(.+)")
        if cat then
          if Types[cat] then
            if string.find(tune,"$",1,true) then
              return "The release name must NOT contain any dollar signs ($)!",1
            else
              for _word in Bot.ForbiddenWords do
                if string.find(tune,word,1,true) then
                  return "The release name contains the following forbidden word (thus not added): "..word,1
                end
              end
            end
            if Count > 0 then
              for i,v in ipairs(AllStuff) do
                if v[3]==tune then
                  return "The release is already added under category "..Types[ct].."."
                end
              end
            end
            table.insert(AllStuff,{cat,nick,os.date("%m/%d/%Y"),tune})
            SaveRel()
            ReloadRel()
            if OnRelAdded then OnRelAdded(user,data,cat,tune) end
          else
            return "Unknown category: "..cat,1
          end
        else
          return "yea right, like i know what you got 2 add when you don't tell me!",1
        end
      end,
      {},Levels.Add,"<type> <name>\t\t\t\tAdd release of given type."
    }
  Engine[Commands.Delete]=
    {
      function (user,data)
        local nick; if hostprg==1 then nick=user.sName end
        local what=string.match(data,"%b<>%s+%S+%s+(.+)")
        if what then
          local cnt,x=0,os.clock()
          local tmp={}
          for w in string.gmatch(what,"(%d+)") do
            table.insert(tmp,tonumber(w))
          end
          table.sort(tmp)
          local msg="\r\n"
          for k=#tmp,1,-1 do
            local n=tmp[k]
            if AllStuff[n] then
              if Allowed(user,Levels.Delete) or AllStuff[n][2]==nick then
                msg=msg.."\r\n"..AllStuff[n][4].." is deleted from the releases."
                AllStuff[n]=nil
                cnt=cnt+1
              end
            else
              msg=msg.."\r\nRelease numbered "..n.." wasn't found in the database."
            end
          end
          if cnt>0 then
            SaveRel()
            ReloadRel()
            msg=msg.."\r\n\r\nDeletion of "..cnt.." item(s) took "..os.clock()-x.." seconds."
          end
          return msg,1
        else
          return "yea right, like i know what i got 2 delete when you don't tell me!.",1
        end
      end,
      {},1,"<ID>\t\t\t\t\tDeletes the releases of the given ID, or deletes multiple ones if given like: 1,5,33,6789"
    }
  Engine[Commands.AddCatgry]=
    {
      function (user,data)
        local what1,what2=string.match(data,"%b<>%s+%S+%s+(%S+)%s+(.+)")
        if what1 then
          if string.find(what1,"$",1,true) then return "The dollar sign is not allowed.",1 end
          if not Types[what1] then
            Types[what1]=what2
            SaveCt()
            return "The category "..what1.." has successfully been added.", 1
          else
            if Types[what1]==what2 then
              return "Already having the type "..what1
            else
              Types[what1]=what2
              SaveCt()
              return "The category "..what1.." has successfully been changed.",1
            end
          end
        else
          return "Category should be added properly: +"..Commands.AddCatgry.." <category_name> <displayed_name>", 1
        end
      end,
      {},Levels.AddCatgry,"<new_cat> <displayed_name>\t\t\tAdds a new release category, displayed_name is shown when listed."
    }
  Engine[Commands.DelCatgry]=
    {  
      function (user,data)
        local what=string.match(data,"%b<>%s+%S+%s+(%S+)")
        if what then
          if not Types[what] then
            return "The category "..what.." does not exist.",1
          else
            Types[what]=nil
            SaveCt()
            return "The category "..what.." has successfully been deleted.",1
          end
        else
          return "Category should be deleted properly: +"..Commands.DelCatgry.." <category_name>",1
        end
      end,
      {},Levels.DelCatgry,"<cat>\t\t\t\t\tDeletes the given release category.."
    }
  Engine[Commands.ShowCtgrs]=
    {
      function (user,data)
        local msg="\r\n======================\r\nAvaillable categories:\r\n======================\r\n"
        for a,b in pairs(Types) do
          msg=msg.."\r\n"..a
        end
        return msg,2
      end,
      {},Levels.ShowCtgrs,"\t\t\t\t\tShows the available release categories."
    }
  Engine[Commands.Search]=
    {
      function (user,data)
        local what=string.match(data,"%b<>%s+%S+%s+(.+)")
        if what then
          local res,rest=0,{}
          local msg="\r\n---------- You searched for keyword \""..what.."\". The results: ----------\r\n\r\n"
          for a,b in ipairs(AllStuff) do
            if string.find(string.lower(b[4]),string.lower(what),1,true) then
              table.insert(rest,{b[1],b[2],b[3],b[4],a})
            end
          end
          if #rest~=0 then
            for idx,tab in ipairs(rest) do
            local _type,who,when,title,id=unpack(tab)
            res= res + 1
            msg = msg.."ID: "..id.."\t"..title.." // (Added by "..who.." at "..when..")\r\n"
            end
            msg=msg.."\r\n"..string.rep("-",20).."\r\n"..res.." results."
          else
            msg=msg.."\r\nSearch string "..what.." was not found in releases database."
          end
          return msg,2
        else
          return "yea right, like i know what you got 2 search when you don't tell me!",1
        end
      end,
      {},Levels.Search,"<string>\t\t\t\t\tSearches for release NAMES containing the given string."
    }
  Engine[Commands.ReLoad]=
    {
      function(user)
        local x=os.clock()
        ReloadRel()
        return "Releases reloaded, took "..os.clock()-x.." seconds.",1
      end,
      {},Levels.ReLoad,"\t\t\t\t\t\tReloads the releases database, only needed if you modified the file by hand."
    }
  Engine[Commands.Help]=
    {
      function (user,data,env)
        local count=0
        local hlptbl={}
        local hlp="\r\nCommands available to you are:\r\n=================================================================================================================================\r\n"
        for a,b in pairs(commandtable) do
          if b["level"]~=0 then
            if Allowed (user, b["level"]) then
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
      {},1,"\t\t\t\t\t\tShows the text you are looking at."
    }
end

function OpenRel()
	AllStuff,NewestStuff,TopAdders = nil,nil,nil
	collectgarbage(); io.flush()
	AllStuff,NewestStuff,TopAdders = {},{},{}
	Count2 = 0
  if not loadfile("freshstuff/data/releases.dat") then
    local f=io.open("freshstuff/data/releases.dat","r")
    if f then
      for line in f:lines() do
        local cat,who,when,title=string.match(line, "(.+)$(.+)$(.+)$(.+)")
        if cat then
          if TopAdders[who] then TopAdders[who] = TopAdders[who]+1 else TopAdders[who]=1 end
          if string.find(when,"%d+/%d+/0%d") then -- compatibility with old file format
            local m,d,y=string.match(when,"(%d+)/(%d+)/(0%d)")
            when=m.."/"..d.."/".."20"..y
          end
          table.insert(AllStuff,{cat,who,when,title})
        else
          return "Releases file is corrupt, failed to load all items."
        end
      end
      f:close()
    end
  else
    AllStuff=table.load("freshstuff/data/releases.dat")
    for _,w in ipairs(AllStuff) do
      local cat,who,when,title=unpack(w)
      if TopAdders[who] then TopAdders[who] = TopAdders[who]+1 else TopAdders[who]=1 end
    end
  end
  Count=#AllStuff
	if Count > MaxNew then
		local tmp = Count - MaxNew
		Count2=(Count - MaxNew)
		for i = tmp, Count do
			Count2=Count2 + 1
			if AllStuff[Count2] then
				NewestStuff[Count2]=AllStuff[Count2]
			end
		end
	else
		for i=1, Count do
			Count2 = Count2
				if AllStuff[i] then
					NewestStuff[Count2]=AllStuff[i]
				end
			end
	end
end

function ShowRel(tab)
  local Msg = "\r\n"
  local cat,who,when,title
  local tmptbl={}
  local cunt=0
  if tab == NewestStuff then
    if Count2 == 0 then
      MsgNew = "\r\n\r\n".." --------- The Latest Releases -------- \r\n\r\n  No releases on the list yet\r\n\r\n --------- The Latest Releases -------- \r\n\r\n"
    else
      for i=1, Count2 do
	if NewestStuff[i] then
	  cat,who,when,title=unpack(NewestStuff[i])
	  if title then
	    if Types[cat] then cat=Types[cat] end
	    if not tmptbl[cat] then tmptbl[cat]={} end
	    table.insert(tmptbl[cat],Msg.."ID: "..i.."\t"..title.." // (Added by "..who.." at "..when..")")
            cunt=cunt+1
	  end
	end
      end
    end
    for a,b in pairs (tmptbl) do
      Msg=Msg.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
    end
    local new=MaxNew if cunt < MaxNew then new=cunt end
    MsgNew = "\r\n\r\n".." --------- The Latest "..new.." Releases -------- "..Msg.."\r\n\ --------- The Latest "..new.."  Releases -------- \r\n\r\n"
  else
    if Count == 0 then
      MsgAll = "\r\n\r\r\n".." --------- All The Releases -------- \r\n\r\n  No releases on the list yet\r\n\r\n --------- All The Releases -------- \r\n\r\n"
    else
      MsgHelp  = "  use "..Commands.Show.." <new>"
      for a,b in pairs(Types) do
	      MsgHelp  = MsgHelp .."/"..a
      end
      MsgHelp  = MsgHelp .."> to see only the selected types"
      for i=1, Count do
	if AllStuff[i] then
	  cat,who,when,title=unpack(AllStuff[i])
	  if title then
	    if Types[cat] then cat=Types[cat] end
	    if not tmptbl[cat] then tmptbl[cat]={} end
	    table.insert(tmptbl[cat],Msg.."ID: "..i.."\t"..title.." // (Added by "..who.." at "..when..")")
	  end
	end
      end
      for a,b in pairs (tmptbl) do
        Msg=Msg.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
      end
      MsgAll = "\r\n\r\r\n".." --------- All The Releases -------- "..Msg.."\r\n --------- All The Releases -------- \r\n"..MsgHelp .."\r\n"
    end
  end
end

function ShowRelType(what)
  local cat,who,when,title
  local Msg,MsgType,tmp = "\r\n",nil,0
  if Count == 0 then
    MsgType = "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n\r\n  No "..string.lower(Types[what]).." yet\r\n\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
  else
    for i=1, Count do
      cat,who,when,title=unpack(AllStuff[i])
      if cat == what then
	tmp = tmp + 1
	Msg = Msg.."ID: "..i.."\t"..title.." // (Added by "..who.." at "..when..")\r\n"
      end
    end
    if tmp == 0 then
      MsgType = "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n\r\n  No "..string.lower(Types[what]).." yet\r\n\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
    else
      MsgType= "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n"..Msg.."\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
    end
  end
  return MsgType
end

function ShowRelNum(what,num) -- to show numbers of categories
  num=tonumber(num)
  local Msg="\r\n"
  local cunt=0
  local target=Count+1
  local cat,who,when,title
  if num > Count then num=Count end
  for t=1,num do
		target=target-1
    if AllStuff[target] then
      cat,who,when,title=unpack(AllStuff[target])
      Msg = Msg.."ID: "..target.."\t"..title.." // (Added by "..who.." at "..when..")\r\n"
      cunt=cunt+1
    else
      break
    end
  end
  if cunt < num then num=cunt end
  local MsgType = "\r\n\r\n".." --------- The Latest "..num.." "..Types[what].." -------- \r\n\r\n"..Msg.."\r\n\r\n --------- The Latest "..num.." "..Types[what].." -------- \r\n\r\n"
  return MsgType
end

function SaveRel()
  table.save(AllStuff,"freshstuff/data/releases.dat")
end

function ReloadRel()
  OpenRel()
  ShowRel(NewestStuff)
  ShowRel(AllStuff)
end

function SaveCt()
  local f=io.open("freshstuff/data/categories.dat","w+")
  f:write("Types={\n")
  for a,b in pairs(Types) do
    f:write("[\""..a.."\"]=\""..b.."\",\n")
  end
  f:write("}")
  f:close()
end

function SplitTimeString(TimeString)
  -- Splits a time format to components, originally written by RabidWombat.
  -- Supported formats: MM/DD/YYYY HH:MM, YYYY. MM. DD. HH:MM, MM/DD/YY HH:MM and YY. MM. DD. HH:MM
  local D,M,Y,HR,MN,SC
  if string.find(TimeString,"/") then
    _,_,M,D,Y,HR,MN,SC=string.find(TimeString,"(%d+)/(%d+)/(%d+)%s+(%d+):(%d+):(%d+)")
  else
    _,_,Y,M,D,HR,MN,SC = string.find(TimeString, "([^.]+).([^.]+).([^.]+). ([^:]+).([^:]+).(%S+)")
  end
  assert(Y:len()==2 or Y:len()==4,"Year must be 4 or 2 digits!")
  if Y:len()==2 then if Y:sub(1,1)=="0" then Y="20"..Y else Y="19"..Y end end
  D = tonumber(D)
  M = tonumber(M)
  Y = tonumber(Y)
  HR = tonumber(HR)
  MN = tonumber(MN)
  SC = tonumber(SC)
  return {year=Y,month=M,day=D,hour=HR,min=MN,sec=SC}
end

--code snipe from a.i. v2 by plop
JulianDate = function(tTime)
  if not tTime then
    local tTime = os.date("*t")
    return os.time({year = tTime.year, month = tTime.month, day = tTime.day, 
    hour = tTime.hour, min = tTime.min, sec = tTime.sec}
  )
  end
  return os.time({year = tTime.year, month = tTime.month, day = tTime.day, 
    hour = tTime.hour, min = tTime.min, sec = tTime.sec}
  )
end

JulianDiff = function(iThen, iNow)
  return os.difftime( (iNow or JulianDate()) , iThen)
end

SendOut("*** "..botver.." kernel loaded.")