--[[
Extras for FreshStuff3 v5 by bastya_elvtars
Release pruning and top adders
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]

TopAdders = {}

for _, w in ipairs(AllStuff) do
  local cat, who, when, title = unpack(w)
  if TopAdders[who] then TopAdders[who] = TopAdders[who]+1 else TopAdders[who] = 1 end
end

do
  setmetatable (Engine,_Engine)
  Engine[Commands.Prune]=
    {
      function (nick,data,env)
        if #AllStuff == 0 then return "There is nothing to prune.",1 end
        setmetatable (AllStuff,nil)
        local Count=#AllStuff
        local days=data:match("(%d+)")
        days=days or MaxItemAge
        local cnt=0
        local x=os.clock()
        local oldest=days*1440*60
        local filename = "freshstuff/data/releases"..os.date("%Y%m%d%H%M%S")..".dat"
        if #AllStuff > 0 then table.save(AllStuff, filename) end
        for i=#AllStuff,1,-1 do
          local diff=JulianDiff(JulianDate(SplitTimeString(AllStuff[i][3].." 00:00:00")))
          if diff > oldest then
            HandleEvent("OnRelDeleted", nick, i)
            table.remove(AllStuff,i)
            cnt=cnt+1
          end
        end
        if cnt ~=0 then
          table.save(AllStuff,"freshstuff/data/releases.dat")
          ReloadRel()
        else
          os.remove (filename)
        end
        return "Release prune process just finished, all releases older than "..days.." days have been deleted from the database. "..Count.." items were parsed and "..cnt.." were removed. Took "..os.clock()-x.." seconds.",4
      end,
      {},Levels.Prune,"<days>\t\t\t\t\tDeletes all releases older than n days, with no option, it deletes the ones older than "..MaxItemAge.." days."
    }
  Engine[Commands.TopAdders]=
    {
      function (nick,data,env)
        local num=TopAddersCount
        local tmp={}
        local adderz=0
        for name,number in pairs(TopAdders) do
          tmp[number] = tmp[number] or {}
          table.insert(tmp[number],name)
        end
        local weird_but_works={}
        for num,ppl in pairs(tmp) do local _suck={}; _suck.N=num; _suck.P=table.concat(ppl,", "); table.insert(weird_but_works,_suck); adderz=adderz+1; end
        table.sort(weird_but_works,function(a,b) return a.N < b.N end)
        if TopAddersCount > adderz then num = adderz end
        local msg="\r\nThe top "..num.." release-addders sorted by the number of releases are:\r\n"..("-"):rep(33).."\r\n"
        for nm=num,1,-1 do
          msg=msg..weird_but_works[nm].P..": "..weird_but_works[nm].N.." items added\r\n"
        end
        return msg,2
      end,
      {},Levels.TopAdders,"<number>\t\t\t\tShows the n top-release-adders (with no option, defaults to 5)."
    }
end

rightclick[{Levels.Prune,"1 3","Releases\\Delete old releases","!"..Commands.Prune.." %[line:Max. age in days (Enter=defaults to "..MaxItemAge.."):]"}]=0
rightclick[{Levels.TopAdders,"1 3","Releases\\Show top release-adders","!"..Commands.TopAdders.." %[line:Number of top-adders (Enter defaults to 5):]"}]=0

module ("Extras",package.seeall)
ModulesLoaded["Extras"] = true

function OnCatDeleted (nick, id)
  SendOut (nick..": "..id)
end

function OnRelAdded (who, _, cat, tune)
  if TopAdders[who] then TopAdders[who] = TopAdders[who]+1 else TopAdders[who]=1 end
end

function OnRelDeleted (nick, n)
  local who = AllStuff[n][2]
  if TopAdders[who] then TopAdders[who] = TopAdders[who]-1 end
  if TopAdders[who] == 0 then TopAdders[who] = nil end
end

SendOut("*** "..Bot.version.." 'extras' module loaded.")