--[[ Requester module for freshstuff
You can:
    - add a request
    - list requests
    - delete a request, if you have the right or you are the one who has added it
    - add releases with an extra option that tells the script you are fulfilling a request
    - Note that you can only delete a request from the non-completed ones, completed requests get deleted 
    when the user who requested logs in. If this is a problem, future versions may contain comp. request pruning.
    - It calls OnReqFulfilled when a request is fulfilled. that way, hostapp-specific modules take care of proper user
    notification, which ensures portability.
 ]]
do
  Requests={Completed={},NonCompleted={}}
  _RequestsComp=
    {
      __newindex=function(tbl,key,value)
        rawset(tbl,key,value) -- save the data and set in the table
        local f=io.open("freshstuff/data/requests_comp.dat","w+")
        for k,v in pairs(tbl) do
          f:write(k.."$"..table.concat(v,"$").."\n")
        end
        f:close()
      end
    }
  _RequestsIncomp=
    {
      __newindex=function(tbl,key,value)
        rawset(tbl,key,value)
        local f=io.open("freshstuff/data/requests_incomp.dat","w+")
        for _,v in ipairs(tbl) do
          f:write(table.concat(v,"$").."\n")
        end
        f:close()
      end
    }
  setmetatable(Engine,_Engine)
  setmetatable(Requests.Completed,_RequestsComp)
  setmetatable(Requests.NonCompleted,_RequestsIncomp)
  Engine[Commands.Add]= -- Yeah, we are redeclaring it. :-) You enter a number reflecting the request you compelted by releasing this (optional).
    { 
      function (user,data)
        local nick; if hostprg==1 then nick=user.sName end
        local cat,reqcomp,tune=string.match(data,"%b<>%s+%S+%s+(%S+)%s*(%d*)%s+(.+)")
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
              for i=1, Count do
                local ct,who,when,title=unpack(AllStuff[i])
                if title==tune then
                  return "The release is already added under category "..Types[ct]..".",1
                end
              end
            end
            Count = Count + 1
            AllStuff[Count]={cat,nick,os.date("%m/%d/%Y"),tune}
            SaveRel()
            ReloadRel()
            if OnRelAdded then OnRelAdded(user,data,cat,tune) end
            if reqcomp~="" then
              if Requests.NonCompleted[tonumber(reqcomp)] then
                local username, reqdetails=unpack(Requests.NonCompleted[tonumber(reqcomp)])
                Requests.NonCompleted[tonumber(reqcomp)]=nil
                Requests.Completed[username]={reqdetails,tune,cat,nick,}
                SaveReq()
                if OnReqFulfilled then OnReqFulfilled(user,data,cat,tune,nick,reqcomp,username,reqdetails) end
                --os.date("%Y. %m. %d. %X")
              else
                return "No request with ID "..reqcomp,1
              end
            end
          else
            return "Unknown category: "..cat,1
          end
        else
          return "yea right, like i know what you got 2 add when you don't tell me!",1
        end
      end,
      {},Levels.Add,"<type> <name>\t\t\t\tAdd release of given type. Enter the number of request that you are fulfilling wih this release, right after category but before release name ( e. g. Music 3 Backstreetboys) - this is optional."
    }
    Engine[Commands.AddReq]=
    {
      function(user,data)
        local nick; if hostprg==1 then nick=user.sName end
        local req=string.match(data,"%b<>%s+%S+%s+(.+)")
        if req then
          if string.find(req,"$",1,true) then
            return "The release name must NOT contain any dollar signs ($)!",1
          else
            for _word in Bot.ForbiddenWords do
              if string.find(req,word,1,true) then
                return "The release name contains the following forbidden word (thus not added): "..word,1
              end
            end
          end
          for nick,tbl in pairs(Requests.Completed) do
            if req==request then
              return req.." has already been requested by "..nick.." and has been fulfilled under category "..tbl[2].. " with name "..tbl[3].." by "..tbl[4],1
            else
              for _,tbl in ipairs(Requests.NonCompleted) do
                if tbl[2]==req then
                  return req.." has already been requested by "..tbl[1]..".",1
                end
              end
            end
          end
          Requests.NonCompleted[#Requests.NonCompleted+1]={nick,req}
          SaveReq()
          return "Your request has been saved, you will have to wait until it gets fulfilled. Thanks for your patience!",1
        end
      end,
      {},Levels.AddReq,"<type> <name>\t\t\t\tAdd a request for a particular release."
    }
    Engine[Commands.ShowReqs]=
    {
      function(user,data)
        local msg="\r\n"
        if #Requests.NonCompleted > 0 then
          for key,val in ipairs(Requests.NonCompleted) do
            msg=msg.."ID: "..key.."; "..val[2].." -// Requested by "..val[1]
          end
          return msg,2
        else
          return "There are no requests now, everyone seems to be satisfied. :-)",1
        end
      end,
      {},Levels.ShowReqs,"<type> <name>\t\t\t\tShow pending requests."
    }
    Engine[Commands.DelReq]=
    {
      function (user,data)
        local nick; if hostprg==1 then nick=user.sName end
        local req=string.match(data,"%b<>%s+%S+%s+(%d+)")
        if req then
          req=tonumber(req)
          if Requests.NonCompleted[req] then
            local reqnick=Requests.NonCompleted[req][1]
            if nick==reqnick or Allowed(user,Levels.DelReq) then
              Requests.NonCompleted[req]=nil
              return "Request #"..req.." has been deleted.",1
            else
              return "You aren't allowed to delete requests.",1
            end
          else
            return "Request #"..req.." does not exist.",1
          end
        else
          return "yea right, like i know what i got 2 delete when you don't tell me!.",1
        end
      end,
      {},1,"<type> <name>\t\t\t\tDelete a request from the non-completed ones."
    }
end

function SaveReq()
    local f=io.open("freshstuff/data/requests_comp.dat","w+")
    for k,v in pairs(Requests.Completed) do
      f:write(k.."$"..table.concat(v,"$").."\n")
    end
    f:close()
    local f=io.open("freshstuff/data/requests_incomp.dat","w+")
    for _,v in ipairs(Requests.NonCompleted) do
      f:write(table.concat(v,"$").."\n")
    end
    f:close()
end

module("Request",package.seeall)

function NewUserConnected(user)
  local nick; if hostprg==1 then nick=user.sName end
  if Requests.Completed[nick] then
    local reqdetails,tune,cat,goodguy=unpack(Requests.Completed[nick])
    Requests.Completed[nick]=nil
    SaveReq()
    return "Your request (\""..reqdetails.."\" has been completed! It is named "..tune.." under category "..cat..". Has been addded by "..goodguy,2
  end
end

function Main()
  local f=io.open("freshstuff/data/requests_comp.dat","r")
  if f then
    for line in f:lines() do
      local nick,reqdetails,tune,cat=string.match(line,"(.+)%$(.+)%$(.+)%$(.+)")
      rawset(Requests.Completed,nick,{reqdetails,tune,cat})
    end
    f:close()
  end
  f=io.open("freshstuff/data/requests_incomp.dat","r")
  if f then
    local c=0
    for line in f:lines() do
      c=c+1
      local nick,reqdetails=string.match(line,"(.+)%$(.+)")
      rawset(Requests.NonCompleted,c,{nick,reqdetails})
    end
    f:close()
  end
end

-- [1]={"testnick","request"}

SendOut("*** "..botver.." 'requester' module loaded.")