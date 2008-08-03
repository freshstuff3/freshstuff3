-- Extras for FreshStuff3 v5 by bastya_elvtars
-- Release pruning and top adders
-- License: GNU GPL v2

do
  setmetatable (Engine,_Engine)
  Engine[Commands.Prune]=
    {
      function (user,data,env)
        local days=string.match(data,"%b<>%s+%S+%s+(%d+)")
        days=days or MaxItemAge
        local cnt=0
        local x=os.clock()
        local oldest=days*1440
        for i=Count,1,-1 do
          local diff=JulianDiff(JulianDate(SplitTimeString(AllStuff[i][3].." 00:00:00")))
          local mins = math.floor(diff/60)
          if mins > oldest then
            AllStuff[i]=nil
            cnt=cnt+1
          end
        end
        if cnt ~=0 then
          SaveRel()
          ReloadRel()
        end
        return "Release prune process just finished, all releases older than "..days.." days have been deleted from the database. "..Count.." items were parsed and "..cnt.." were removed. Took "..os.clock()-x.." seconds.",4
      end,
      {},Levels.Prune,"<days>\t\t\t\t\tDeletes all releases older than n days, with no option, it deletes the ones older than "..MaxItemAge.." days."
    }
  Engine[Commands.TopAdders]=
    {
      function (user,data,env)
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
        local msg="\r\nThe top "..num.." release-addders sorted by the number of releases are:\r\n"..string.rep("-",33).."\r\n"
        for nm=num,1,-1 do
          msg=msg..weird_but_works[nm].P..": "..weird_but_works[nm].N.." items added\r\n"
        end
        return msg,2
      end,
      {},Levels.TopAdders,"<number>\t\t\t\tShows the n top-release-adders (with no option, defaults to 5)."
    }
end

SendOut("*** "..botver.." 'extras' module loaded.")