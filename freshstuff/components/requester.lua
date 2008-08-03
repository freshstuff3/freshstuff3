--[[
Requester module for freshstuff
You can:
    - add a request
    - list requests
    - delete a request, if you have the right or you are the one who has added it
    - add releases with an extra option that tells the script you are fulfilling a request
    - Note that you can only delete a request from the non-completed ones, completed requests get deleted
    when the user who requested logs in. If this is a problem, future versions may contain comp. request pruning.
    - It calls OnReqFulfilled when a request is fulfilled. that way, hostapp-specific modules take care of proper user
    notification, which ensures portability.

Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]

local conf = ScriptsPath.."config/requester.lua"
local _, err = loadfile (conf)
if not err then dofile (conf) else error(err) end

Requests ={Completed = {}, NonCompleted = {}}

do
  setmetatable(Engine,_Engine)
--   Engine[Commands.Add]= -- Yeah, we are redeclaring it. :-)
--     {-- You enter a number reflecting the request you completed by releasing this (optional).
--       function (nick,data)
--         setmetatable (AllStuff,
--           {
--             __newindex=function (tbl, key, value)
--               if #tbl >= #NewestStuff then -- Take care of removing the thing from NewestStuff too
--                 table.remove (NewestStuff, 1)
--               end
--               local cat, nick, date, tune = unpack(value)
--               table.insert (NewestStuff,{cat, nick, date, tune,key}) -- and the new 'Newest' entry gets added
--               rawset(tbl, key, value)
--               table.save(tbl,ScriptsPath.."data/releases.dat")
--               ShowRel(NewestStuff); ShowRel()
--             end
--           })
--         local reqcomp,cat,tune=string.match(data,"(%d*)%s*(%S+)%s+(.+)")
--         if cat then
--           if Types[cat] then
--             for _,word in pairs(ForbiddenWords) do
--               if string.find(tune,word,1,true) then
--                 return "The release name contains the following forbidden word (thus not added): "..word, 1
--               end
--             end
--             if #AllStuff > 0 then
--               for i,v in ipairs(AllStuff) do
--                 if string.lower(v[4]) == string.lower(tune) then
--                   return "The release is already added under category "..v[1].." by "..v[2]..".", 1
--                 end
--               end
--             end
--             if reqcomp == "" then
--               local count = #AllStuff
--               AllStuff[count + 1] = {cat,nick,os.date("%m/%d/%Y"),tune}
--               HandleEvent("OnRelAdded", nick, data, cat, tune)
--               return tune.." is added to the releases as "..cat, 1
--             else
--               reqcomp = tonumber(reqcomp)
--               if Requests.NonCompleted[reqcomp] then
--                 local done = Requests.NonCompleted[reqcomp]
--                 if done[2] ~= cat then
--                   return "This is not the same category as the request. You have specified "..cat.." while the request's category was "..done[2]..". Request and release have NOT been added.", 1
--                 else
--                   local count = #AllStuff
--                   AllStuff[count + 1] = {cat,nick,os.date("%m/%d/%Y"),tune}
--                   local username, cat, reqdetails=unpack(done)
--                   --Requests.NonCompleted[tonumber(reqcomp)]=nil
--                   table.remove (Requests.NonCompleted, reqcomp)
--                   Requests.Completed[username]={reqdetails, tune, cat, nick}
--                   table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
--                   table.save(Requests.Completed,ScriptsPath.."data/requests_comp.dat")
--                   HandleEvent("OnRelAdded", nick, data, cat, tune)
--                   HandleEvent("OnReqFulfilled", nick, data, cat, tune, reqcomp, username, reqdetails)
--                   return tune.." is added to the releases as "..cat..". Request #"..reqcomp.." has successfully been fulfilled. Thank you.", 1
--                   end
--               else
--                 return "No request with ID "..reqcomp..". Release has NOT been added.",1
--               end
--             end
--             return tune.." is added to the releases as "..cat, 1
--           else
--             return "Unknown category: "..cat, 1
--           end
--         else
--           return "yea right, like i know what you got 2 add when you don't tell me!",1
--         end
--       end,
--       {},Levels.Add,"<requestnumber> <type> <name>\t\t\t\tAdd release of given type. Enter the number of request that you are fulfilling wih this release, before category and release name (optional)."
--     }
    Engine[Commands.AddReq]=
    {
      function(nick,data)
        if data~="" then
          local cat,req = string.match (data,"(%S+)%s+(.+)")
          if cat then
            if not Types[cat] then
              return "The category "..cat.." does not exist.",1
            else
              for _,word in ipairs(ForbiddenWords) do
                if string.find(req,word,1,true) then
                  return "The request name contains the following forbidden word (thus not added): "..word,1
                end
              end
              for nick,tbl in pairs(Requests.Completed) do
                if req == tbl[2] then
                  return req.." has already been requested by "..nick.." and has been fulfilled under category "..tbl[3].. " with name "..tbl[2].." by "..tbl[4],1
                end
              end
              for id,tbl in pairs(Requests.NonCompleted) do
                if tbl[3] == req then
                  return req.." has already been requested by "..tbl[1].." in category "..tbl[2].." (ID: "..id..").",1
                end
              end
                --table.insert(Requests.NonCompleted,{nick, cat, req})
                local no = #Requests.NonCompleted + 1
                Requests.NonCompleted[no] = {nick, cat, req}
                table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
                HandleEvent("OnReqAdded", nick, data, cat, req)
                return "Your request has been saved, you will have to wait until it gets fulfilled. Thanks for your patience!",1
            end
          else return "yea right, like i know what i got 2 add when you don't tell me!.",1 end
        else
          return "yea right, like i know what i got 2 add when you don't tell me!.",1
        end
      end,
      {},Levels.AddReq,"<type> <name>\t\t\t\tAdd a request for a particular release."
    }
    Engine[Commands.LinkReq] = 
    {
      function (nick, data)
        local relid, reqid = string.match (data,"(%d+)%D+(%d+)")
        if relid and reqid then
          if AllStuff[tonumber(relid)] then
            if Requests.NonCompleted[tonumber(reqid)] then
              local done = Requests.NonCompleted[tonumber(reqid)]
              local cat, usernick, date, tune = unpack (AllStuff[tonumber(relid)])
              if done[2] ~= cat then
                return "This is not the same category as the request. The release's category is "..Types[cat].." while the request's category is "..Types[done[2]]
                ..". Request and release have NOT been linked.", 1
              else
                local username, cat, reqdetails=unpack(done)
                --table.remove (Requests.NonCompleted, tonumber(reqid))
                Requests.NonCompleted[tonumber(reqid)] = nil
                Requests.Completed[username]={reqdetails, tune, cat, nick}
                table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
                table.save(Requests.Completed,ScriptsPath.."data/requests_comp.dat")
                HandleEvent("OnReqFulfilled", usernick, data, cat, tune, reqid, username, reqdetails)
                return "Release "..tune.." in category "..cat.." has fulfilled request #"..reqid..". Thank you.", 1
              end
            else
              return "This request ("..reqid..") does not exist.",1
            end
          else
            return "This release ("..relid..") does not exist.",1
          end
        else
          return "Syntax should be: !"..Commands.LinkReq.." release_id request_id",1
        end
      end,
      {},Levels.LinkReq,"<release_id> <request_id>\t\t\t\tLink a release with a request, thus fulfilling it."
    }
    Engine[Commands.ShowReqs]=
    {
      function(nick,data)
        local CatArray={}
        local MsgAll
        local Msg = "\r\n"
        local cat, who, title
        local tmptbl={}
        setmetatable(tmptbl,{__newindex=function(tbl,k,v) rawset(tbl,k,v); table.insert(CatArray,k); end})
        local cunt=0
        if #Requests.NonCompleted == 0 then
          return "\r\n\r\r\n".." --------- All The Requests -------- \r\n\r\nThere are no requests now, everyone seems to be satisfied. :-)\r\n\r\n --------- All The Requests -------- \r\n\r\n", 2
        else
          for key, val in pairs(Requests.NonCompleted) do
            who, cat, title = unpack(val)
            if who then
              tmptbl[Types[cat]]=tmptbl[Types[cat]] or {}
              table.insert(tmptbl[Types[cat]],Msg.."ID: "..key.."\t"..title.." // (Added by "..who..")")
            end
          end
          for _,a in ipairs (CatArray) do
            local b=tmptbl[a]
            if SortStuffByName==1 then table.sort(b,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
            Msg=Msg.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
          end
          return "\r\n\r\r\n".." --------- All The Requests -------- "..Msg.."\r\n --------- All The Requests --------", 2
        end
      end,
      {},Levels.ShowReqs,"<type> <name>\t\t\t\tShow pending requests."
    }
    Engine[Commands.DelReq]=
    {
      function (nick, data)
        if data ~="" and string.find(data,"%d+") then
          local msg = ""
          for req in string.gmatch (data,"(%d+)") do
            req=tonumber(req)
            if Requests.NonCompleted[req] then
              local reqnick=Requests.NonCompleted[req][1]
              if nick == reqnick or Allowed(nick,Levels.DelReq) then
                --table.remove(Requests.NonCompleted, req)
                Requests.NonCompleted[req] = nil
                table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
                msg=msg.."\r\nRequest #"..req.." has been deleted."
              else
                return "You aren't allowed to delete requests that haven't bee submitted by you.", 1
              end
            else
              msg=msg.."\r\nRequest #"..req.." does not exist."
            end
          end
          return msg, 1
        else
          return "yea right, like i know what i got 2 delete when you don't tell me!.", 1
        end
      end,
      {},1,"<type> <name>\t\t\t\tDelete a request from the non-completed ones."
    }
end

rightclick[{Levels.DelReq,"1 3","Requests\\Delete a request","!"..Commands.DelReq.." %[line:ID number(s):]"}]=0
rightclick[{Levels.ShowReqs,"1 3","Requests\\Show requests","!"..Commands.ShowReqs}]=0
rightclick[{Levels.Add,"1 3","Requests\\Link a release with a request","!"..Commands.LinkReq.." %[line:Release ID:] %[line:Request ID:]"}]=0

module("Request",package.seeall)
ModulesLoaded["Request"] = true

function Connected (nick)
  if Requests.Completed[nick] then
    local reqdetails,tune,cat,goodguy=unpack(Requests.Completed[nick])
    Requests.Completed[nick]=nil
    table.save(Requests.Completed, ScriptsPath.."data/requests_comp.dat")
    return "Your request (\""..reqdetails.."\") has been completed! It is named "..tune.." under category "..cat..". Has been addded by "..goodguy,2
  end
end

function Start()
  local file_non, file_comp = ScriptsPath.."data/requests_non_comp.dat", ScriptsPath.."data/requests_comp.dat"
  local x = os.clock()
  local _, e1 = loadfile (file_non)
  local _, e2 = loadfile (file_comp)
  local bErr
  if not e1 then
      Requests.NonCompleted = table.load (file_non)
    if not e2 then
      Requests.Completed = table.load (file_comp)
    else bErr = true end
  else bErr = true end
  e1 = e1 or e2; if e1 then SendOut ("Warning: "..e1) end
  SendOut("*** Loaded "..#Requests.NonCompleted.." requests in "..os.clock()-x.." seconds.")
  for a,b in pairs(Types) do -- Add categories to rightclick. This MIGHT be possible on-the-fly, just get the DC ÜB3RH4XX0R!!!11one1~~~ guys to fucking document $UserCommand
    rightclick[{Levels.AddReq,"1 3","Requests\\Add an item to the\\"..b,"!"..Commands.AddReq.." "..a.." %[line:Name:]"}]=0
  end
end

function OnCatDeleted (cat)
  local filename = ScriptsPath.."data/requests_non_comp"..os.date("%Y%m%d%H%M%S")..".dat"
  table.save(Requests.NonCompleted, filename)
  local bRemoved
  for key, value in pairs (Requests.NonCompleted) do
    if value[2] == cat then
      --table.remove (Requests.NonCompleted, key)
      Requests.NonCompleted[key] = nil
      bRemoved = true
    end
  end
  if bRemoved then
    table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
  else
    os.remove (filename)
  end
  return "Note that incomplete requests have been backed up to "..filename.." in case you have made a mistake.", 1
end

function OnReqAdded (nick, data, cat, req)
	return "A new request has been added to the "..Types[cat].." category by "..nick..": \""
	..req.."\". Who will be the first to fulfill it? ;-)",4
end

SendOut("*** "..Bot.version.." 'requester' module loaded.")
