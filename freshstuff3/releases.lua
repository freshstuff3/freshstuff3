if not Host then 
  package.path = "C:/Users/szaka/Desktop/Linux/devel/"
  .."freshstuff3/freshstuff/components/?.lua" 
end
local persistence = require "persistence"
local t = {}

t.AllStuff = persistence.load (string.sub(package.path, 1, -6).."../data/releases.lua") or {}
t.Commands, t.Meta = {}, {}

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

t.Meta.__newindex = function (tbl, key, value) 
    rawset (tbl, key, value)
    Event("CategoryAdded", key)
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

-- t.Delete = function with OnRelDeleted() returning a list of deletions

-- t.Move = function with OnRelMoved() returning a list of moved

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

t.CategoryAdded = function (ev, cat)
  SendDebug ("added a new category: "..cat)
end

t.RelAdded = function (ev, cat, rel, self)
  SendDebug ("added "..rel.title.." by "..rel.nick.." with ID "..cat.."/"..#self.AllStuff[cat])
end

t.FakeStuff = function (self, num)
  local randomtype = {}
  for k, v in pairs(self.AllStuff) do
    table.insert (randomtype, k)
  end
  for k = 1, num do
    local no = math.random(#randomtype)
    self:Add (randomtype[no], {nick = "bastya_elvtars"..no^3,  title = os.tmpname ()}) 
  end
end

setmetatable (t.AllStuff, t.Meta)

return t
