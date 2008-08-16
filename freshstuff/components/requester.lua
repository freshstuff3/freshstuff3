--[[
Requester module for freshstuff
You can:
    - add a request
    - list requests
    - delete a request, if you have the right or you are the one who has added it
    - add releases with an extra option that tells the script you are fulfilling a request
    - subscribe for requests
    - Note that you can only delete a request from the non-completed ones, completed requests get deleted
      when the user who requested logs in. If this is a problem, future versions may contain comp. request pruning.
    - It calls OnReqFulfilled() and OnReqAdded() when a request is fulfilled. that way, hostapp-specific modules
      take care of proper user notification, which ensures portability.

Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0.
See docs/license.txt for details.
]]

local conf = ScriptsPath.."config/requester.lua"
local _, err = loadfile (conf)
if not err then dofile (conf) else error(err) end

Requests = {Completed = {}, NonCompleted = {}, Subscribers = {}, Coroutines = {},}

do
  setmetatable(Engine,_Engine)
    Engine[Commands.AddReq]=
    {
      function(nick,data)
        if data~="" then
          local cat, req = string.match (data,"(%S+)%s+(.+)")
          if cat then
            if not Types[cat] then
              return "The category "..cat.." does not exist.", 1
            else
              for _,word in ipairs(ForbiddenWords) do
                if string.find(req, word, 1, true) then
                  return "The request name contains the following forbidden word (thus not added): "..word, 1
                end
              end
              if Requests.Coroutines[nick] then return "A request of yours is already being processed. Please wait a few seconds!", 2 end
              if not next(Requests.NonCompleted) then
                Requests.NonCompleted[table.maxn(Requests.NonCompleted) + 1] = {nick, cat, req}
                table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
                HandleEvent("OnReqAdded", nick, _, cat, req)
                return " Your request has been saved, you will have to wait until it gets fulfilled. Thanks for your patience!", 2
              else
                local cor = coroutine.create(Request.ComparisonHelper)
                Requests.Coroutines[nick] = {Coroutine = cor, Request = req, CurrID = 1, Category = cat}
                return "Your request is being processed. You will be notified of the result.", 2
              end
            end
          else return "yea right, like i know what i got 2 add when you don't tell me!.", 1 end
        else
          return "yea right, like i know what i got 2 add when you don't tell me!.", 1
        end
      end,
      {},Levels.AddReq,"<type> <name>\t\t\t\tAdd a request for a particular release."
    }
    Engine[Commands.LinkReq] = 
    {
      function (nick, data)
        local relid, reqid = string.match (data,"(%d+)%D+(%d+)")
        if relid and reqid then
          local rel = AllStuff[tonumber(relid)] 
          if rel then
            local req = Requests.NonCompleted[tonumber(reqid)]
            if req then
              if Allowed[{nick,Levels.DelReq}] or rel[1] == nick or req[1] == nick then
                local cat, usernick, date, tune = unpack(rel)
                if req[2] ~= cat then
                  return "This is not the same category as the request. The release's category is "..Types[cat].." while the request's category is "..Types[done[2]]
                  ..". Request and release have NOT been linked.", 1
                else
                  local username, cat, reqdetails=unpack(req)
                  Requests.NonCompleted[tonumber(reqid)] = nil
                  AllReq, NewReq = Request.GetReq()
                  if req[1] ~= nick then -- When a requester links his/her own request, notification is redundant.
                    Requests.Completed[username]={reqdetails, tune, cat, nick}
                    table.save(Requests.Completed,ScriptsPath.."data/requests_comp.dat")
                  end
                  table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
                  HandleEvent("OnReqFulfilled", usernick, data, cat, tune, reqid, username, reqdetails)
                  return "Release "..tune.." in category "..cat.." has fulfilled request #"..reqid..". Thank you.", 1
                end
              else return "You are not allowed to use this command!", 1 end
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
      function(nick, data)
        local trick = {["nope"] = "There are no requests now, everyone seems satisfied. :-)"}
        if string.find(data, "new", 1, true) then return trick[Request.NewReq] or Request.NewReq, 2 else return trick[Request.AllReq] or Request.AllReq, 2 end
      end,
      {},Levels.ShowReqs,"<type> <name>\t\t\t\tShow pending requests. If you add 'new' as an option, it will show the latest "..MaxNewReq.." ones."
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
              if nick == reqnick or Allowed[{nick,Levels.DelReq}] then
                Requests.NonCompleted[req] = nil
                table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
                msg=msg.."\r\nRequest #"..req.." has been deleted."
                AllReq, NewReq = Request.GetReq()
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
      {}, 1,"<type> <name>\t\t\t\tDelete a request from the non-completed ones."
    }
    Engine[Commands.SubscrReq]=
    {
      function (nick, data)
        local ret_neg = "Insufficient or incorrect parameters, please refer to the help."
        if data ~="" and data:find("^%d+$") then
          local what = data:match("^(%d+)$")
          if what then
            what = tonumber(what)
            local repl_arr = 
            {
              "You will be notified of new requests and will get the latest "..MaxNewReq.." requests every time you connect the hub.",
              "You will be notified of new requests.",
              "You will get the latest "..MaxNewReq.." requests every time you connect the hub.",
            }
            if repl_arr[what] then
              Requests.Subscribers[nick] = nil
              Requests.Subscribers[nick] = what
              return repl_arr[what], 1
            else
              return ret_neg, 1
            end
          else
            return ret_neg, 1
          end
        else
          return ret_neg, 1
        end
      end,
      {}, Levels.SubscrReq, "<option>\t\t\t\tSubscribe for requests. Option can be: 1 for new requests and on-connect, 2 for new requests, 3 for on-connect. If you are already subscribed, your preference will be changed.."
    }
end

rightclick[{Levels.DelReq,"1 3","Requests\\Delete a request","!"..Commands.DelReq.." %[line:ID number(s):]"}]=0
rightclick[{Levels.ShowReqs,"1 3","Requests\\Show requests","!"..Commands.ShowReqs}]=0
rightclick[{Levels.ShowReqs,"1 3","Requests\\Show latest "..MaxNewReq.."requests","!"..Commands.ShowReqs.." new"}]=0
rightclick[{Levels.ShowReqs,"1 3","Requests\\Subscribe to new requests","!"..Commands.SubscrReq.."%[line:Option (1: on new/onjoin, 2: on new, 3 onjoin):]"}]=0
rightclick[{Levels.Add,"1 3","Requests\\Link a release with a request","!"..Commands.LinkReq.." %[line:Release ID:] %[line:Request ID:]"}]=0

module("Request",package.seeall)
ModulesLoaded["Request"] = true

-- Events

function Connected (nick)
  if Requests.Completed[nick] then
    local reqdetails,tune,cat,goodguy=unpack(Requests.Completed[nick])
    Requests.Completed[nick]=nil
    table.save(Requests.Completed, ScriptsPath.."data/requests_comp.dat")
    return "Your request (\""..reqdetails.."\") has been completed! It is named "..tune.." under category "..cat..". Has been addded by "..goodguy,2
  end
  local opt = Requests.Subscribers[nick]
  if opt and opt ~= 2 then SendReqTo (nick, false) end
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
    else bErr = true; Requests.Completed = {} end
  else bErr = true; Requests.NonCompleted = {} end
--     e1 = e1 or e2; if e1 then SendOut ("Warning: "..e1)end
  for _, req in ipairs (Requests.Completed) do
    local cat = req[3]
    if not Types[cat] then Types[cat] = cat; SendOut("New category detected: "..cat..
          ". It has been automatically added to the categories, however you ought to check if"..
          " everything is alright."); table.save(Types,ScriptsPath.."data/categories.dat"); end
  end
  for _,req in pairs (Requests.NonCompleted) do
    local cat = req[2]
    if not Types[cat] then Types[cat] = cat; SendOut("New category detected: "..cat..
          ". It has been automatically added to the categories, however you ought to check if"..
          " everything is alright."); table.save(Types,ScriptsPath.."data/categories.dat"); end
  end
  setmetatable(Requests.NonCompleted,
  {
    __len = function(tbl)
      local c = 0
      for _, _ in pairs(tbl) do
        c = c+1
      end
      return c
    end
  })
  AllReq, NewReq = GetReq()
  SendOut("*** Loaded "..#Requests.NonCompleted.." requests in "..os.clock()-x.." seconds.")
  for a,b in pairs(Types) do -- Add categories to rightclick.
    rightclick[{Levels.AddReq,"1 3","Requests\\Add an item to the\\"..b,"!"..Commands.AddReq.." "..a.." %[line:Name:]"}]=0
  end
  local f = io.open(ScriptsPath.."data/reqsubscr.dat","r+")
  if not f then return end
  for line in f:lines() do
    local name, opt = line:find("([^%|]+)%|(.+)")
    Requests.Subscribers[name] = opt
  end
  f:close()
  f = io.open(ScriptsPath.."data/reqsubscr.dat","w+")
  for name, opt in pairs (Requests.Subscribers) do
    f:write(name.."|"..opt)
  end
  setmetatable(Requests.Subscribers,
  {
    __newindex = function(tbl, key, val)
      local f = io.open(ScriptsPath.."data/reqsubscr.dat","a+")
      f:write(key.."|"..val)
      f:close()
    end
  })
end

function OnCatDeleted (cat)
  local filename = ScriptsPath.."data/requests_non_comp"..os.date("%Y%m%d%H%M%S")..".dat"
  table.save(Requests.NonCompleted, filename)
  local bRemoved
  for key, value in pairs (Requests.NonCompleted) do
    if value[2] == cat then
      Requests.NonCompleted[key] = nil
      bRemoved = true
    end
  end
  if bRemoved then
    table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
  else
    os.remove (filename)
  end
  AllReq, NewReq = GetReq()
  return "Note that incomplete requests have been backed up to "..filename.." in case you have made a mistake.", 1
end

function OnReqAdded (nick, data, cat, req)
  local msg = "A new request has been added to the "..Types[cat].." category by "..nick..": \""
	..req.."\". Who will be the first to fulfill it? ;-)"
  AllReq, NewReq = GetReq()
  for nick, opt in pairs(Requests.Subscribers) do
    if opt~=3 then SendReqTo (nick, true, msg) end
  end
	return msg, 4
end

function Timer()
  Max = table.maxn(Requests.NonCompleted)
  for nick, tbl in pairs(Requests.Coroutines) do -- loop through coroutines
    local co = tbl.Coroutine -- retrieve the coroutine
    local status = coroutine.status(co)
    if status == "suspended" then -- if it can be started/resumed
      local bOK, match = coroutine.resume(co, tbl, nick) -- do it!
      if bOK and match then -- the coroutine explicitly returned, aka finished
        local cat, req = tbl.Category, tbl.Request
        if next(match) then
          local msg = "Your request has been saved, you will have to wait until it gets fulfilled."
          .."However, it is quite similar to the following requests:"
          local FoundSame
          for id, tbl in pairs(match) do
            if tbl[2] == 100 then
              PM(nick, "Your request is identical to the following request: \r\nID# "..id.." - Name: "..tbl[1]..".\r\n\r\nIt has NOT been added.")
              FoundSame = true
              break
            else
              msg = msg.."\r\n"..id.." - "..tbl[1].." ("..tbl[2].."%)"
            end
          end
          if not FoundSame then
            msg = msg.."\r\n\r\nPlease review! Thanks!"
            Requests.NonCompleted[table.maxn(Requests.NonCompleted) + 1] = {nick, cat, req}
            table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
            HandleEvent("OnReqAdded", nick, _, cat, req)
            PM(nick, msg)
          end
        else
          Requests.NonCompleted[table.maxn(Requests.NonCompleted) + 1] = {nick, cat, req}
          table.save(Requests.NonCompleted,ScriptsPath.."data/requests_non_comp.dat")
          HandleEvent("OnReqAdded", nick, _, cat, req)
          PM(nick, " Your request has been saved, you will have to wait until it gets fulfilled. Thanks for your patience!")
        end
      elseif not bOK then
        SendOut(match) -- forward errors to ops
      end
    elseif status == "dead" then -- it is finished
      Requests.Coroutines[nick] = nil -- so wipe it
    end
  end
end

-- Helper functions

function ComparisonHelper(tbl, cor_id)
  local req, id = tbl.Request, tbl.CurrID
  local PIC = 0 --  processed item counter (PIC)
  local match = {}
  while true do -- endless loop
    id = id + 1 -- raise request ID by 1
    if id == Request.Max + 1 then break end -- we have reached the last request, so stop this thread
    if Requests.NonCompleted[id] then -- if we have this number (NonCompleted not an array!)
      PIC = PIC + 1 -- raise the PIC by 1 only now!
      local percent = 100*Levenshtein (Requests.NonCompleted[id][3], req) -- compare
      if percent >= MaxMatch then -- if matches
        match[id] = {Requests.NonCompleted[id][3], percent} -- there is a match, register it
        if percent == 100 then break end -- break when there is an exact match; why check all others, it will be rejected anyway
      end
      if PIC >= ItemsToCheckAtOnce then -- we have processed 40 items
        Requests.Coroutines[cor_id].CurrTblID = id -- update the global table with the ID of the last processed item
        PIC = 0 -- reset the PIC
        coroutine.yield()-- and go sleeping
      end
    end
  end
  return match -- here we return if there are matches
end

function GetReq()
  if not next(Requests.NonCompleted) then return "nope" end
  local CatArray={}
  local Msg1, Msg2 = "\r\n", "\r\n"
  local cat, who, title
  local tmptbl={}
  setmetatable(tmptbl,{__newindex=function(tbl,k,v) rawset(tbl,k,v); table.insert(CatArray,k); end})
  local cunt=0
  for key, val in pairs(Requests.NonCompleted) do
    who, cat, title = unpack(val)
    if who then
      tmptbl[Types[cat]]=tmptbl[Types[cat]] or {}
      table.insert(tmptbl[Types[cat]],Msg1.."ID: "..key.."\t"..title.." // (Added by "..who..")")
    end
  end
  for _,a in ipairs (CatArray) do
    local b=tmptbl[a]
    if SortStuffByName==1 then table.sort(b,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
    Msg1 = Msg1.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
  end
  tmptbl = nil; tmptbl = {}
  local biggest, counter = table.maxn(Requests.NonCompleted), 0
  for n = biggest, 1, -1 do
    if counter == MaxNewReq then break end
    local val = Requests.NonCompleted[n]
    if val then
    counter = counter + 1
      who, cat, title = unpack(val)
      if who then
        tmptbl[Types[cat]]=tmptbl[Types[cat]] or {}
        table.insert(tmptbl[Types[cat]],Msg2.."ID: "..n.."\t"..title.." // (Added by "..who..")")
      end
    end
  end
  for _,a in ipairs (CatArray) do
    local b=tmptbl[a]
    if SortStuffByName==1 then table.sort(b,function(v1,v2) local c1=v1:match("ID:%s+%d+(.+)%/%/") local c2=v2:match("ID:%s+%d+(.+)%/%/") return c1:lower() < c2:lower() end) end
    Msg2 = Msg2.."\r\n"..a.."\r\n"..string.rep("-",33).."\r\n"..table.concat(b).."\r\n"
  end
  local new; if counter < MaxNewReq then new = counter else new = MaxNewReq end
  return "\r\n\r\r\n".." --------- All The Requests -------- "..Msg1.."\r\n --------- All The Requests --------",
  "\r\n\r\r\n".." --------- The Latest "..new.." Requests -------- "..Msg2.."\r\n --------- The Latest "..new.." Requests --------"
end

function SendReqTo (nick, bNew, msg)
  if bNew then
    PM(nick, msg)
  else
    if NewReq ~="nope" then
      PM(nick, Request.NewReq)
    end
  end
end

SendOut("*** "..Bot.version.." 'requester' module loaded.")
