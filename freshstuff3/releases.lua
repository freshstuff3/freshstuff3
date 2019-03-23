-- FreshStuff3 6.0 releases module.
-- Distributed under the MIT license.
-- TODO:
-- Levenshtein + coroutines
-- Commands
-- Config loader
-- get and edit releases
-- for getting the desired command syntax is: music/today, music/new
-- and music/23-59, maybe music/1,5,7,9,13,23-59
-- same as above for deletion (the numbers)
-- todo: remove unnecessary time fields from database
-- now where are we? about to fix pendingstuff nil errors
-- when category created, journal it in PendingStuff too
ReleaseApprovalPolicy = 2

if not Host then 
  package.path = "C:/Users/szaka/Desktop/Linux/devel/"
  .."freshstuff3/freshstuff3/?.lua" 
end
local persistence = require "persistence"
local t = { Commands = {}, Coroutines = {} }
t.AllStuff = persistence.load (string.sub(package.path, 1, -6)
  .."data/releases.lua") or {}
t.PendingStuff  = persistence.load (string.sub(package.path, 1, -6)
  .."data/pendingrel.lua") or {}
setmetatable (t.AllStuff, {
__len = function (tbl)
  local number = 0
  if tbl[1] then -- non-empty category
    number = #tbl
  else -- empty category or main AllStuff
    for k, v in pairs (tbl) do
      number = number + #v
    end
  end
  return number
end})

setmetatable (t.PendingStuff, {
__len = function (tbl)
  local number = 0
  if tbl[1] then -- non-empty category
    number = #tbl
  else -- empty category or main AllStuff
    for k, v in pairs (tbl) do
      number = number + #v
    end
  end
  return number
end})

-- temporarily hardcoded config data, to be removed later
t.ForbiddenWords = { "fuck", "shit" }

  -- Events: you call these from the event handler Event ("EventName", ...)
t.CategoryAdded = function (ev, cat, nick)
  SendDebug ("added a new category: "..cat)
end

t.RelAdded = function (ev, cat, rel)
  table.insert (Releases.AllStuff[cat], {nick = nick, title = rel.title,
  when = os.date("%m/%d/%Y") } );
  Releases:Journal ("releases.lua", "table.insert (Releases.AllStuff[\""
  ..cat.."\"], {nick = \""..rel.nick.."\", title = \""..rel.title
  .."\", when = "..os.date("%m/%d/%Y").." })")
  SendOut ("\""..rel.title.."\" has been added to the releases with ID "..cat..
  "/"..#Releases.AllStuff)
end

t.PendingRelAdded = function (ev, cat, rel, self)
  table.insert (Releases.PendingStuff[cat], {nick = nick, title = rel.title})
  Releases:Journal ("pendingrel.lua", "table.insert (Releases.PendingStuff[\""
  ..cat.."\"], {nick = \""..rel.nick.."\", title = \""..rel.title.."\"  }")
  SendOut( "\""..rel.title.."\" has been added to the pending releases "
  .."with ID "..cat.."/"..#Releases.PendingStuff
  ..", please wait until someone reviews it.")
end

t.Timer = function ()
  local arr = { "releases.lua", "pendingrel.lua" }
  for _, filename in ipairs (arr) do
    os.remove (string.sub(package.path, 1, -6).."journal/"..filename)
    persistence.store (string.sub (package.path, 1, -6).."data/"..filename, Releases.AllStuff)
  end
  Releases:OpenJournal ("releases.lua")
  Releases:OpenJournal ("pendingrel.lua")
  if coroutine.status (Releases.MainTableHelper) == "dead" then
    Releases.MainTableHelper = coroutine.create (Releases.MainTableParser)
  end
  local bOK, match, tbl, nick = coroutine.resume (Releases.MainTableHelper)
  if nick then -- the coroutine explicitly returned = finished
    local rel, cat = tbl.Release, tbl.Category
    if next (match) then
      -- Sort the table in reverse order for percentages.
      -- This ensures that if a 100% is found nothing will get added
      -- afterwards.
      table.sort(match, function (el1, el2)
        return el1[3] > el2[3]
      end)
      for k, v in ipairs (match) do
        local id, rel, percent, bPending = table.unpack (v)
        local msg =
        "\""..rel.title.."\" has been added to the to-be-reviewed releases "
        .."in this category: \""..cat.."\" with ID "
        ..(#Releases.PendingStuff + 1)
        ..". \r\nIt needs approval by an authorized user before it"
        .."could appear on the list"
        local msg_op = "A release has been added by "..nick.. " that is"
        .." quite similar to the following release(s):\r\n"
        local FoundSame -- boolean for 100% match
        local policy_msg =
        {
        msg..". Note that it is quite similar to the following release(s):",
        msg.." BECAUSE it is quite similar to the following release(s):",
        }
        msg = policy_msg[ReleaseApprovalPolicy] or "\""..rel.title
        .."\" has been added to the releases in this category: \""
        ..cat.."\" with ID "..cat.."/"..(#Releases.AllStuff + 1)..". Note that it is"
        .." quite similar to the following release(s):"
        if percent == 100 then -- identical!
          if bPending then
            return  "A release with the same name is already "
            .."awaiting  approval. Release has NOT been added.", rel.title
          else
            return "Your release is identical to the following "
            .."release(s): \r\nID# "..cat.."/"..id.." - Name: "..rel.title
            ..".\r\n\r\nRelease has NOT been added.", rel.title
          end
          FoundSame = true
          break -- break the loop, we already have this release
        else
          msg = msg.."\r\n"..cat.."/"..id.." - "..rel.title.." ("..percent.."%)"
          msg_op = msg_op.."\r\n"..cat.."/"..id.." - "..rel.title.." ("..percent
          .."%)"
        end
        if not FoundSame then
          if ReleaseApprovalPolicy ~= 3 then
            msg_op = msg_op.."\r\n\r\nPlease review! Thanks!"
            Event("PendingRelAdded", cat, {nick = nick, title = rel.title }, self);            
            return msg_op
          else
            Event("RelAdded", cat, {nick = nick, title = rel.title, 
            when = date_arr}, self);
            return msg
          end
        end
      end
    else -- not even a single similar release found, add the stuff
      if ReleaseApprovalPolicy ~= 1 then
        msg = "\""..tbl.Release.title
        .."\" has been added to the releases in this category: \""
        ..cat.."\" with ID "..(#Releases.AllStuff + 1).."."
        Event("RelAdded", cat, {nick = nick, title = rel.title, 
        when = date_arr}, self);
      return msg
      end
    end
  elseif not bOK then -- there is a syntax error
    return match -- forward it to ops
  end
end

-- Levenshtein distance algorithm from http://bit.ly/bCGkiX
-- Here I use it for comparing two strings. In my practice, 75% means they're
-- nearly identical so further check is required.
-- @return Is actually the ratio of the difference and the longer string, sub-
-- @return tracted from 1.
t.Levenshtein = function (self, string1, string2)
  string1 = string1:lower(); string2 = string2:lower()
  local str1, str2, distance = {}, {}, {};
  local str1len, str2len = string1:len(), string2:len();
  for s in string.gmatch(string1, "(.)") do
    table.insert(str1, s);
  end
  for s in string.gmatch(string2, "(.)") do
    table.insert(str2, s)
  end
  for i = 0, str1len do
    distance[i] = distance[i] or {}
    distance[i][0] = i;
  end
  for i = 0, str2len do
    distance[i] = distance[i] or {}
    distance[0][i] = i;
  end
  for i = 1, str1len do
    for j = 1, str2len do
      local tmpdist = 1;
      if(str1[i-1] == str2[j-1]) then
        tmpdist = 0;
      end
      distance[i][j] = math.min( distance[i-1][j] + 1,
      distance[i][j-1]+1, distance[i-1][j-1] + tmpdist);
    end
  end
  return 1-distance[str1len][str2len]/math.max(str1len, str2len)
end

-- this function is executed by 
t.ComparisonHelper = function (tbl, nick)
  local PIC = 0 -- Processed Items Counter (smart acronym, SRSLY)
  local rel, id = tbl.Release, tbl.CurrID
  local match = {}
  local bExact
  while true do -- endless loop
    -- raise release ID by 1
    id = id + 1
    if id > #Releases.AllStuff[tbl.Category] then break end
    local percent = 100*Releases:Levenshtein (Releases.AllStuff[tbl.Category][id].title, rel.title) -- compare
    SendDebug (percent)
    PIC = PIC + 1
    -- todo: make variable for value 75 below max match
    if percent >= 75 then
      table.insert(match, {id, rel, percent}) -- there is a match, register
      -- if 100% match found, further checking is futile
      if percent == 100 then return PIC, match; end
    end
--    if PIC >= ItemsToCheckAtOnce then -- max reached  for this session
    if PIC >= 30 then -- max reached  for this session
      Releases.Coroutines[nick].CurrID = id -- record the last processed ID
      coroutine.yield(PIC)-- and go to sleep
      PIC = 0
      -- When we wake up, the loop resumes
    end
  end
  id = 0
  while true do
    id = id + 1
    if id > #Releases.PendingStuff[tbl.Category] then break end
    local percent = 100*Releases:Levenshtein (Releases.PendingStuff[tbl.Category][id].title, rel.title)
    PIC = PIC + 1
    if percent == 100 then -- if matches
      table.insert(match, {id, rel, percent, true})
      return PIC, match
    end
--    if PIC >= ItemsToCheckAtOnce then
    if PIC >= 30 then
      Coroutines[nick].CurrID = id
      coroutine.yield(PIC)
      PIC = 0
    end
  end
  return PIC, match -- return if there are matches, stopping the coroutine
end

t.MainTableParser = function ()
  local bOK, rePIC, match, nick, tbl
  while true do
    nick, tbl = next (Releases.Coroutines, nick)
    if nick then
      if coroutine.status (tbl.Coroutine) ~= "dead" then
        bOK, rePIC, match = coroutine.resume (tbl.Coroutine, tbl, nick)
        -- syntax error
        if not bOK then return false, rePIC; end
        -- the coroutine finished
        if match then return match, tbl, nick end
        -- reached the max number of items, sleep
        if rePIC >= 30 then coroutine.yield() end
      else
        Releases.Coroutines[nick] = nil
      end
    else
      -- If the table is empty, we just return an empty table plus 2 nil's.
      -- If not, the gets returned with friends either non-nil.
      -- See Timer() below.
      return match or {}, tbl, nick
    end
  end
end

t.MainTableHelper = coroutine.create (t.MainTableParser)

-- Functions called with Releases:Blah(...)

-- add a category
t.AddCat = function (self, cat)
  if not self.AllStuff[cat] then
    self.AllStuff[cat] = {}
    self.PendingStuff[cat] = {}
    Event("CategoryAdded", cat, self)
    self:Journal ("releases.lua", "Releases.AllStuff[\""..cat.."\"] = {}")
    self:Journal ("pendingrel.lua", "Releases.PendingStuff[\""..cat.."\"] = {}")
    return "added category "..cat
  else 
    if not self.PendingStuff[cat] then
      self.PendingStuff[cat] = {}
      self:Journal ("pendingrel.lua", "Releases.PendingStuff[\""..cat.."\"] = {}")
    end
    return "category already exists!"
  end
end
--TODO:
-- t.ChangeDel(cat, id[, rel])
-- multi id looking like {ps2 = {1,2,3,7,31}, music = {1,999}}
-- "music/1-99" and things will be processed in Commands table
-- RelEdited(), RelDeleted()
-- t.Move (id, newCat) with RelMoved() returning a list of moved 

-- primitive function to get data, TODO: include stuff from metatable.lua
t.Get = function (self, Y, M, D)
--  local td, YY, MM, DD; if Y == "today" then td = os.date ("%d/%m/%Y") else td = os.date (
  local td = os.date ("*t")
  local dt = { td.day, td.month, td.year }
  for cat, arr in pairs (self.AllStuff) do
    local c = #arr
    local Y, M, D = arr[c].when.year, arr[c].when.month, arr[c].when.day
    local dt = D.."/"..M.."/"..Y
    while c > 0 and dt == td do
      local rel = arr[c]
      result[{cat = cat, ID = c}] = rel
      max = max + 1 
      c = c - 1
      Y, M, D = arr[c].when.year, arr[c].when.month, arr[c].when.day
      dt = D.."/"..M.."/"..Y
    end
  end
end
-- Add a release, largely grabbed from 5.x
t.Add = function (self, cat, tune, nick)
  local rel
  nick = nick or "butcher"..math.random(1, 25)
  if cat then
    if self.AllStuff[cat] then
      for _, word in pairs(t.ForbiddenWords) do
        if string.find (tune, word, 1, true) then
          return "The release name contains the following forbidden"
          .." word (thus not added): "..word
        end
      end
    -- Coroutines below should be like an array with a limit of 5; neater and who knows? :}
      if self.Coroutines[nick] then return ("A release of yours is already "
      .."being processed. Please wait a few seconds!") end
      local rel = { nick = nick, 
              title = tune, 
            }
      local count = #self.AllStuff
      if count == 0 then
        if ReleaseApprovalPolicy ~= 1 then
          Event("RelAdded", cat, rel, self);
        else -- everything must be queued
          Event("PendingRelAdded", cat, rel, self);
        end
      else
        self.Coroutines[nick] =  {
        Coroutine = coroutine.create (self.ComparisonHelper),
        Release = rel,
        CurrID = 0, -- to check rel #1 so avoid off-by-one errors
        Category = cat }
        return "Your release is being processed.", 2
      end
    else
      return "Unknown category: "..cat, 1
    end
  else
    return "yea right, like i know what you got 2 add when you don't tell"
    .."me!",1
  end
end --    ,{},Levels.Add,"<type> <name> // Add release of given type."

-- Approve a pending release. 
t.Approve = function (self, cat, id, nick)
  -- here nick is the one that approves
  if not self.PendingStuff[cat] then return "unknown category!" end
  local rel = self.PendingStuff[cat][id]
  if rel then
    self.PendingStuff[cat][id] = nil
    Event("RelAdded", cat, rel.title, rel.nick)
    Event("RelApproved", cat, Releases.AllStuff[#Releases.AllStuff[cat]], nick)
    return "added "..rel.title.." with id "..cat.."/"..id.." by "..rel.who
  else
    return "release with given ID does not exist"
  end
end

-- Journaling functionality. This one adds a new entry to the journal.
-- We just append so it's fast.
t.Journal = function (self, filename, transaction)
  local f = io.open (string.sub(package.path, 1, -6).."journal/"
  ..filename, "a+")
  f:write (transaction.."\n")
  f:close()
end

-- Journal file loading. Note that journals also consist of proper Lua code.
-- Journal has to be deleted at certain intervals (following a successful save)
-- It only exists if the hub did not exit properly so it has to be deleted on a
-- successful exit. This way the FULL database is saved every X seconds only
-- therefore significantly fewer hub-stalling write operations are required.
-- Only if there is a crash in between two full saves will the journal file
-- remain in place.
-- SSD owners will love this.
t.OpenJournal = function (self, filename)
  local JournalTbl = {}
  local f = io.open (string.sub(package.path, 1, -6).."journal/"
  ..filename, "r+")
  if f then
    for line in f:lines() do
      local func = load (line)
      if func then table.insert (JournalTbl, func) end
    end
    f:close ()
  end
  for _, func in ipairs (JournalTbl) do func() end
  if not next (JournalTbl) then SendDebug ("Journal empty: "..filename) return end
  SendDebug ("Recovered "..#JournalTbl.." items from journal file "..filename)
  os.remove (string.sub(package.path, 1, -6).."journal/"..filename)
  persistence.store (string.sub (package.path, 1, -6).."data/"..filename, self.AllStuff)
end

-- fake database generator
t.FakeStuff = function (self, num)
  local randomtype = {}
  for k, v in pairs (self.AllStuff) do
    table.insert (randomtype, k)
  end
  for k = 1, num do
    local no = math.random(#randomtype)
    print (self:Add (randomtype[no], string.sub(os.tmpname (),2,-1), "bastya_elvtars"..no^3) )
  end
end



return t
