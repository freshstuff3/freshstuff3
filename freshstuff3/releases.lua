-- FreshStuff3 6.0 releases module.
-- Distributed under the MIT license.
-- TODO:
-- Levenshtein + coroutines
-- Commands
-- Config loader
-- get and edit releases

if not Host then 
  package.path = "C:/Users/szaka/Desktop/Linux/devel/"
  .."freshstuff3/freshstuff3/?.lua" 
end
local persistence = require "persistence"
local t = {}
print (string.sub(package.path, 1, -6).."data/releases.lua")
t.AllStuff = persistence.load (string.sub(package.path, 1, -6).."data/releases.lua") or {}
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
t.Commands, t.Meta, t.JournalTbl = {}, {}, {}

-- Events: you call these from the event handler Event()
t.CategoryAdded = function (ev, cat, self)
  SendDebug ("added a new category: "..cat)
  self:Journal ("releases.lua", "Releases.AllStuff[\""..cat.."\"] = {}")
end

t.RelAdded = function (ev, cat, rel, self)
  self:Journal ("releases.lua", "table.insert(Releases.AllStuff[\""..cat.."\"], {nick = \""..rel.nick.."\", title = \""..rel.title.."\", when = os.date (\"*t\")})")
  SendDebug ("added "..rel.title.." by "..rel.nick.." with ID "..cat.."/"..#self.AllStuff[cat])
end

t.AddCat = function (self, cat)
  if not self.AllStuff[cat] then
    self.AllStuff[cat] = {}
    Event("CategoryAdded", cat, self)
  else 
    SendDebug ("category already exists!")
  end
end

t.Add = function (self, cat, rel)
  if rel then
    local nick, title = rel.nick, rel.title
    assert (nick and title, "Invalid release object!")
    if self.AllStuff[cat] then
      table.insert (self.AllStuff[cat], {nick = nick, title = title, when = os.date ("*t")})
      Event("RelAdded", cat, rel, self); 
    end
  end
end

-- t.Edit(cat, id[, rel])
-- if rel is unspecified then it deletes and id can be multiple, 
-- looking like {ps2 = {1,2,3,7,31}, music = {1,999}}
-- "music/1-99" and things will be processed in Commands table
-- RelEdited(), RelDeleted()
-- t.Move (id, newCat) with RelMoved() returning a list of moved

t.Get = function (self, Y, M, D)
--  local td, YY, MM, DD; if Y == "today" then td = os.date ("%d/%m/%Y") else td = os.date (
  local td = os.date ("%d/%m/%Y")
  for cat, arr in pairs (self.AllStuff) do
    local c = #arr
    local Y, M, D = arr[c].when.year, arr[c].when.month, arr[c].when.day
    local dt = D.."/"..M.."/"..Y
    while c > 0 and dt == td do
      print (td,dt)
      local rel = arr[c]
      result[{cat = cat, ID = c}] = rel
      max = max + 1 
      c = c - 1
      Y, M, D = arr[c].when.year, arr[c].when.month, arr[c].when.day
      dt = D.."/"..M.."/"..Y
    end
  end
end

-- Journaling functionality. This one adds a new entry to the journal.
-- We just append so it's fast.
t.Journal = function (self, filename, transaction)
  local f = io.open (string.sub(package.path, 1, -6).."journal/"..filename, "a+")
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
  local f = io.open (string.sub(package.path, 1, -6).."journal/"..filename, "r+")
  local c = 0
  if f then
    for line in f:lines() do
      local func = load (line)
      if func then table.insert (self.JournalTbl, func) end
    end
    f:close ()
  end
  for _, func in ipairs (self.JournalTbl) do func() c = c + 1 end
  self:DelJournal (filename)
  if c == 0 then SendDebug ("Journal empty.") return end
  SendDebug ("Recovered "..c.." items from journal.")
end

t.DelJournal = function (self, filename)
  os.remove (string.sub(package.path, 1, -6).."journal/"..filename)
  persistence.store (string.sub(package.path, 1, -6).."data/"..filename, self.AllStuff)  
end

-- fake database generator
t.FakeStuff = function (self, num)
  local randomtype = {}
  for k, v in pairs(self.AllStuff) do
    table.insert (randomtype, k)
  end
  for k = 1, num do
    local no = math.random(#randomtype)
    self:Add (randomtype[no], {nick = "bastya_elvtars"..no^3, title = string.sub(os.tmpname (),2,-1)}) 
  end
end

t.OnTimer = function (self)
  t:DelJournal("releases.lua")
end

t.OnExit = t.OnTimer

return t
