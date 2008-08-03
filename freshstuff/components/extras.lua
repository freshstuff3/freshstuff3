--[[
Extras for FreshStuff3 v5 by bastya_elvtars
Release pruning and top adders
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]

local conf = ScriptsPath.."config/extras.lua"
local _,err = loadfile (conf)
if not err then dofile (conf) else error(err) end

function CountTopAdders()
  local TopAdders, TA = {}, {}
  for _, w in ipairs(AllStuff) do
    local _, who = unpack(w)
    TA[who] = TA[who] or 0
    TA[who] = TA[who] + 1
  end
  local TAC = 0
  for name, number in pairs(TA) do
    local x = TopAdders[number]
    if x then
      TopAdders[number] = x..", "..name
    else
      TopAdders[number] = name
      TAC = TAC+1
    end
  end
  TA=nil; collectgarbage ("collect"); io.flush()
  return TopAdders, TAC
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
        local filename = ScriptsPath.."data/releases"..os.date("%Y%m%d%H%M%S")..".dat"
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
          table.save(AllStuff,ScriptsPath.."data/releases.dat")
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
      function (nick, data, env)
        local TopAdders, TAC = CountTopAdders()
        local num
        num = tonumber (data) or TopAddersCount
        if num > TAC then num = TAC end
        local tmp2 = {}
        for num, ppl in pairs(TopAdders) do table.insert(tmp2, {["N"] = num, ["P"] = ppl} ) end
        table.sort(tmp2, function(a, b) return a.N > b.N end)
        local msg="\r\nThe top "..num.." release-addders sorted by the number of releases are:\r\n"..("-"):rep(33).."\r\n"
        for nm = 1, num do
          msg=msg..tmp2[nm].P..": "..tmp2[nm].N.." items added\r\n"
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

SendOut("*** "..Bot.version.." 'extras' module loaded.")