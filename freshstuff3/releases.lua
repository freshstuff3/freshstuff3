if not Host then 
  package.path = "C:/Users/szaka/Desktop/Linux/devel/"
  .."freshstuff3/freshstuff3/?.lua" 
end
local persistence = require "persistence"
local t = {}
print (string.sub(package.path, 1, -6).."data/releases.lua")
t.AllStuff = persistence.load (string.sub(package.path, 1, -6).."data/releases.lua") or {}
t.Commands, t.Meta, t.JournalTbl = {}, {}, {}

-- Events, you call these from the event handler

t.CategoryAdded = function (ev, cat, self)
  SendDebug ("added a new category: "..cat)
  self:Journal ("releases.lua", "Releases.AllStuff[\""..cat.."\"] = {}")
end

t.RelAdded = function (ev, cat, rel, self)
  self:Journal ("releases.lua", "table.insert(Releases.AllStuff[\""..cat.."\"], {nick = \""..rel.nick.."\", title = \""..rel.title.."\", when = os.date (\"*t\")})")
  SendDebug ("added "..rel.title.." by "..rel.nick.." with ID "..cat.."/"..#self.AllStuff[cat])
end

t.Meta.__len = function (tbl)
  local number = 0
  if tbl[1] then -- non-empty category
    number = #tbl
  else -- empty category or main AllStuff
    for k, v in pairs (tbl) do
      if type (v) == "table" then number = number + #v end
    end
  end
  return number
end

t.AddCat = function (self, cat) 
  self.AllStuff[cat] = {}
  Event("CategoryAdded", cat, self)
end

t.Add = function (self, cat, rel)-- Releases:AddNew(...)
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

-- Journaling functionality.

t.Journal = function (self, filename, transaction)
  local f = io.open (string.sub(package.path, 1, -6).."journal/"..filename, "a+")
  f:write (transaction.."\n")
  f:close()
end

t.OpenJournal = function (self, filename)
  local f = io.open (string.sub(package.path, 1, -6).."journal/"..filename, "r+")
  if f then
    for line in f:lines() do
      local func = load (line)
      if func then table.insert (self.JournalTbl, func) print (line) end
    end
    f:close ()
  end
  local c = 0
  for _, func in ipairs (self.JournalTbl) do func() c = c + 1 end
  SendDebug ("Loaded "..c.." items from journal.")
  os.remove (string.sub(package.path, 1, -6).."journal/"..filename)
  persistence.store (string.sub(package.path, 1, -6).."data/releases.lua", self.AllStuff)
end

-- fake release generator

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

setmetatable (t.AllStuff, t.Meta)

return t
