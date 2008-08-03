--[[
Core module for FreshStuff3 v5 by bastya_elvtars
License: GNU GPL v2
This module contains functions that generate the required messages, save/load releases etc.
]]

do
  setmetatable (Engine,_Engine)
  Engine[Commands.Show]=
    {
      function (nick,data)
        if Count < 1 then return "There are no releases yet, please check back soon.",1 end
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
          else
            return "No such type.",1
          end
        end
      end,
      {},Levels.Show,"<type>\t\t\t\t\tShows the releases of the given type, with no type specified, shows all." 
    }
  Engine[Commands.Add]=
    {
      function (nick,data)
        local cat,tune= string.match(data, "(%S+)%s+(.+)")
        if cat then
          if Types[cat] then
            for _word in Bot.ForbiddenWords do
              if string.find(tune,word,1,true) then
                return "The release name contains the following forbidden word (thus not added): "..word,1
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
            table.save(AllStuff,"freshstuff/data/releases.dat")
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
      function (nick,data)
        if data~="" then
          local cnt,x=0,os.clock()
          local tmp={}
          for w in string.gmatch(data,"(%d+)") do
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
            table.save(AllStuff,"freshstuff/data/releases.dat")
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
      function (nick,data)
        local what1,what2=string.match(data,"(%S+)%s+(.+)")
        if what1 then
          if string.find(what1,"$",1,true) then return "The dollar sign is not allowed.",1 end
          if not Types[what1] then
            Types[what1]=what2
            table.save(Types,"freshstuff/data/categories.dat")
            return "The category "..what1.." has successfully been added.", 2
          else
            if Types[what1]==what2 then
              return "Already having the type "..what1
            else
              Types[what1]=what2
              table.save(Types,"freshstuff/data/categories.dat")
              return "The category "..what1.." has successfully been changed.",1
            end
          end
          for k in pairs(Types) do table.insert(CatArray,k) table.sort(CatArray) end
        else
          return "Category should be added properly: +"..Commands.AddCatgry.." <category_name> <displayed_name>", 2
        end
      end,
      {},Levels.AddCatgry,"<new_cat> <displayed_name>\t\t\tAdds a new release category, displayed_name is shown when listed."
    }
  Engine[Commands.DelCatgry]=
    {  
      function (nick,data)
        local what=string.match(data,"(%S+)")
        if what then
          if not Types[what] then
            return "The category "..what.." does not exist.",1
          else
            Types[what]=nil
            table.save(Types,"freshstuff/data/categories.dat")
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
      function (nick,data)
        local msg="\r\n======================\r\nAvaillable categories:\r\n======================\r\n"
        for a,b in pairs(Types) do
          msg=msg.."\r\n"..a.."\t\t"..b
        end
        return msg,1
      end,
      {},Levels.ShowCtgrs,"\t\t\t\t\tShows the available release categories."
    }
  Engine[Commands.Search]=
    {
      function (nick,data)
        if data then
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
          return msg,1
        else
          return "yea right, like i know what you got 2 search when you don't tell me!",1
        end
      end,
      {},Levels.Search,"<string>\t\t\t\t\tSearches for release NAMES containing the given string."
    }
  Engine[Commands.ReLoad]=
    {
      function()
        local x=os.clock()
        ReloadRel()
        return "Releases reloaded, took "..os.clock()-x.." seconds.",1
      end,
      {},Levels.ReLoad,"\t\t\t\t\t\tReloads the releases database, only needed if you modified the file by hand."
    }
  Engine[Commands.Help]=
    {
      function ()
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
	collectgarbage("collect"); io.flush()
	AllStuff,NewestStuff,TopAdders = {},{},{}
	Count2 = 0
  if not loadfile("freshstuff/data/releases.dat") then
    local f=io.open("freshstuff/data/releases.dat","r")
    if f then
      for line in f:lines() do
        line=string.gsub(line,"(%[)","(")
        line=string.gsub(line,"(%])",")")
        local cat,who,when,title=string.match(line, "(.+)$(.+)$(.+)$(.+)")
        if cat then
          if TopAdders[who] then TopAdders[who] = TopAdders[who]+1 else TopAdders[who]=1 end
          if string.find(when,"%d+/%d+/0%d") then -- compatibility with old file format
            local m,d,y=string.match(when,"(%d+)/(%d+)/(0%d)")
            when=m.."/"..d.."/".."20"..y
          end
          table.insert(AllStuff,{cat,who,when,title})
        else
          SendOut("Releases file is corrupt, failed to load all items.")
          break
        end
      end
      f:close()
      table.save(AllStuff,"freshstuff/data/releases.dat")
    end
  else
    AllStuff=table.load("freshstuff/data/releases.dat")
  end
  for _,w in ipairs(AllStuff) do
    local cat,who,when,title=unpack(w)
    if TopAdders[who] then TopAdders[who] = TopAdders[who]+1 else TopAdders[who]=1 end
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
  local CatArray={}
  local Msg = "\r\n"
  local cat,who,when,title
  local tmptbl={}
  setmetatable(tmptbl,{__newindex=function(tbl,k,v) rawset(tbl,k,v); table.insert(CatArray,k); end})
  local cunt=0
  if tab == NewestStuff then
    if Count2 == 0 then
      MsgNew = "\r\n\r\n".." --------- The Latest Releases -------- \r\n\r\n  No releases on the list yet\r\n\r\n --------- The Latest Releases -------- \r\n\r\n"
    else
      for i=1, Count2 do
        if NewestStuff[i] then
          cat,who,when,title=unpack(NewestStuff[i])
          if title then
            tmptbl[Types[cat]]=tmptbl[Types[cat]] or {}
            table.insert(tmptbl[Types[cat]],Msg.."ID: "..i.."\t"..title.." // (Added by "..who.." at "..when..")")
            cunt=cunt+1
          end
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
            tmptbl[Types[cat]]=tmptbl[Types[cat]] or {}
            table.insert(tmptbl[Types[cat]],Msg.."ID: "..i.."\t"..title.." // (Added by "..who.." at "..when..")")
          end
        end
      end
      for _,a in ipairs (CatArray) do
        local b=tmptbl[a]
        if SortStuffByName==1 then table.sort(b,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
        Msg=Msg.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
      end
      MsgAll = "\r\n\r\r\n".." --------- All The Releases -------- "..Msg.."\r\n --------- All The Releases -------- \r\n"..MsgHelp .."\r\n"
    end
  end
end

function ShowRelType(what)
  local cat,who,when,title
  local Msg,MsgType,tmp,tbl = "\r\n",nil,0,{}
  if Count == 0 then
    MsgType = "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n\r\n  No "..string.lower(Types[what]).." yet\r\n\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
  else
    for i=1, Count do
      cat,who,when,title=unpack(AllStuff[i])
      if cat == what then
        tmp = tmp + 1
        table.insert(tbl,"ID: "..i.."\t"..title.." // (Added by "..who.." at "..when)
      end
    end
    if SortStuffByName==1 then table.sort(tbl,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
    if tmp == 0 then
      MsgType = "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n\r\n  No "..(Types[what]):lower().." yet\r\n\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
    else
      MsgType= "\r\n\r\n".." --------- All The "..Types[what].." -------- \r\n"..table.concat(tbl,"\r\n").."\r\n --------- All The "..Types[what].." -------- \r\n\r\n"
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

function ReloadRel()
  OpenRel()
  ShowRel(NewestStuff)
  ShowRel()
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

-- OK, we are loading the categories now.
if loadfile("freshstuff/data/categories.dat") then
  Types=table.load("freshstuff/data/categories.dat")
else
  Types={
    ["warez"]="Warez",
    ["game"]="Games",
    ["music"]="Music",
    ["movie"]="Movies",
  }
  SendOut("The categories file is corrupt or missing! Created a new one.")
  SendOut("If this is the first time you run this script, or newly installed it, please copy your old releases.dat (if any) to freshstuff/data and restart the script. Thank you!")
  table.save(Types,"freshstuff/data/categories.dat")
end
for k,v in ipairs(AllStuff) do if not Types[v[1]] then Types[v[1]]=v[1]; SendOut("Unknown category :"..Types[v[1]].." - added with description same as name, please take action!") end end
ReloadRel()

SendOut("*** "..botver.." kernel loaded.")