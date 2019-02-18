-- This data structure is very easily extensible as additional fields
-- do not disturb the main operations so release up/downvotes, magnet URI
-- etc. are possible to implement very easily, even from plugins.
-- AllStuff from now on is a proxy table. It handles release addons/lookups
-- and special table lookups are used for new and today's releases etc.
-- This way everything is dealt with by the metamethods and we have very easy 
-- syntax: AllStuff("new") as well as AllStuff ("today") return a ready to send string
-- only so a hostapp module requires the above simplistic syntax.
-- They also return an ordered list where a field is added with music/34 like ID
-- therefore the you can get a release data structure directly with lookup possibilities
-- and different sorting orders can also easily be achieved.
-- The user commands are directly fed to the metamethods, that is if something
-- like !delrel music/31[,44,2,654][5-9] is issued the music/31[,44,2,654[5-9]
-- part is parsed by the metamethod only so one does not have to do much pattern
-- matching on chatlines and can rather concentrate on the extra functionality to add. :)

-- Default number of releases to display when unspecified
MaxNew = 5

-- Set the below to false in order to achieve date/time format 
-- YY. MM. DD. HH:MM instead of DD/MM/YY HH:MM. 
DDMMYYYY = true

-- Splits a time format to components; originally written by RabidWombat.
-- Supported formats: DD/MM/YYYY HH:MM, YYYY. MM. DD. HH:MM, DD/MM/YY HH:MM
-- and YY. MM. DD. HH:MM 
function SplitTimeString(TimeString)
  local D, M, Y, HR, MN =  TimeString:match("(%d+)/(%d+)/(%d+)%s+(%d+):(%d+)")
  if not D then
    Y, M, D, HR, MN = TimeString:match("([^.]+).([^.]+).([^.]+).([^:]+).([^:]+)")
  end
 if Y:len() == 2 then Y = "20"..Y end -- the 20th century is dead :D
  return Y, M, D, HR, MN
end

if DDMMYYYY == true then 
    date = "%d/%m/%Y %H:%M" 
  else
    date = "%Y. %m. %d. %H:%M" 
end

Releases = {}
AllStuff = {}

for k, v in pairs (Releases) do
  AllStuff[k] = {}
  setmetatable (AllStuff[k], 
    {
    __len = function () return #v end,
--  __newindex = function(tbl, max, cat) AllStuff.cat[max] = "cat"
-- or if max is a table then it is a release object and needs to be added to cat
-- or if max is a string it can be music/new-music/today-music/all
-- where max is number and cat is a string
-- maybe this could have new/today
-- like !releases music/new and music/today
-- TO BE CONTINUED HERE TOMORROW
    })
end

setmetatable (AllStuff, 
  {
  __call = function (func, key, nr)
  local result = {} -- table of found items ["blah/55"] = {title, nick, date}
  local list = {} -- sorted list of the above by time descending
  setmetatable (result, 
    {__newindex = function (res, id, rel)
      rel.ID = id.cat.."/"..id.ID
      table.insert (list, rel)
    end})
  local max = 0 -- addition counter for breaking loops when max value reached
  if #AllStuff < 1 then return "no releases yet" end
  nr = nr or MaxNew
  if key =="today" then
    local td = os.date ("%d/%m/%Y")
    for cat, arr in pairs (Releases) do
      if max == nr then break end
      local c = #arr
      local Y, M, D = SplitTimeString (arr[c].date)
      local dt = D.."/"..M.."/"..Y
      while c > 0 and dt == td do
        local rel = arr[c]
        result[{cat = cat, ID = c}] = rel
        max = max +1 
        c = c - 1
        Y, M, D = SplitTimeString (arr[c].date)
        dt = D.."/"..M.."/"..Y
        if max == nr then break end
      end
    end
    if max < 1 then result = "no releases today" end
  elseif tonumber (key) or key =="new" then
    if key == "new" then key = nr end
    local s = 0; for k, v in pairs (Releases) do s = s + 1 end
    local perCat = 0
    for cat, rel in pairs (Releases) do
      if max == tonumber(key) then break end
      if math.ceil (key/s) >= #rel then
        for idx, rlz in ipairs (rel) do
          if max == key then break end
          result[{cat = cat, ID = idx}] = rlz
          max = max + 1
        end
      else       
        while perCat <= math.ceil (key/s) do
          if max == tonumber(key) then break end
          local rlz = rel[#rel-perCat]
          result[{cat = cat, ID = #rel-perCat}] = rlz
          max = max + 1
          perCat = perCat + 1
        end
      end
    end
  elseif Releases[key] then -- latest [MaxNew] by category
    local max = 0
    local c = #Releases[key]
    while max < nr and c~=0 do
      result[{cat = key, ID = c}] = Releases[key][c]
      c = c - 1
    end
  else -- generic lookup: the music/34 format
        -- also perhaps the music/all and simply an all siwtch
       -- has to understand commas and hyphens eg. 1,22,34-56 (TBD)
    local cat, id = key:match("(.+)/(%d+)")
    if cat and id then
      if not Releases[cat] then result = "category "..cat
      .." does not exist! cannot show" end
      local rel = Releases[cat][tonumber(id)]
      if rel then
        result[{cat = cat, ID = id}] = rel
        max = max + 1
      else
        result = "no release with ID "..key
        .." or wrong format: use it like !release movie/1 (see !relhelp)"
      end
    end
  end
  -- maybe add the search herea/ if all the above fails a search is automatically done?
  if type (result) == "table" then
    table.sort (list, function (a,b)
      local A, B = {}, {}
      A.year, A.month, A.day, A.hour, A.min = SplitTimeString(a.date)
      B.year, B.month, B.day, B.hour, B.min = SplitTimeString(b.date)
      return os.time (A) > os.time (B)
    end)
    local result_txt = ""
    for id, rel in ipairs (list) do
      result_txt = result_txt.."\r\nID: "..rel.ID.." || "..rel.title
      .." || Added by "..rel.nick.." on "..rel.date
    end
    return result_txt, list
  else
    return result
  end
end,
  __len = function () -- #AllStuff will return the total number of releases. 
      local c = 0
      for _, arr in pairs (Releases) do
        c = c + #arr
      end
      return c
    end,
  __mul = function (t, key)
    if not Releases[key] then
      local tbl = {}
      setmetatable (tbl, {__len = function () return #t end})
      rawset (AllStuff, key, tbl); Releases[key] = {}
      return ("new category "..key.." added")
    else return ("category "..key.." already exists!") end
  end,
  __div = function (t, key)
     if Releases[key] then
       --- DO BACKUP
       local c = #Releases[key]
       Releases[key] = nil
       return ("category "..key.." containing "..c.." release(s) has been deleted; backup made at")
    else return ("category "..key.." does not exist! cannot delete") end
  end,
  __add = function (as, tbl)
    local cat, rel = table.unpack (tbl)
    if not Releases[cat] then return ("category "..cat
    .." does not exist! cannot add rel") end
    table.insert (Releases[cat], rel)
    local res = "ID: "..cat.."/"..#Releases[cat].." // "..rel.title
          .." (Added by "..rel.nick.." on "..rel.date..")"
    return res
  end,
  __sub = function (tbl, key) -- needs to use same syntax as lookup above
    local cat, id = key:match("(.+)/(%d+)")
      if cat and id then
        if not Releases[cat] then return ("category "..cat
        .." does not exist! cannot delete rel") end
        if Releases[cat][tonumber(id)] then
          local title  = Releases[cat][tonumber(id)].title
          table.remove(Releases[cat], tonumber(id))
          return "deleted release id "..key.." titled "..title
        else
          return "release with ID "..key.." not found"
          .." or wrong format: use it like !release movie/1 (see !relhelp)"
        end
      end
    end,
  -- __pow for release edit
--  __band for moving between categories (multi-item)
  })

_ = AllStuff * "music"
_ = AllStuff * "movie"
_ = AllStuff * "fuck you"
_ = AllStuff + {"music", {nick = "joe",title = "stoner rock collection", date = "17/02/19 11:11"}}
_ = AllStuff + {"music", {nick = "jill", title = "scores for porn", date = "13/02/19 11:12"}}
_ = AllStuff + {"movie", {nick = "tim",title = "mr nobody", date = "13/02/19 11:11"}}
_ = AllStuff + {"movie", {nick = "tom", title = "the babadook", date = "17/02/19 00:11"}}
_ = AllStuff + {"fuck you", {nick = "dan", title = "no ur mom gay", date = "16/02/19 00:11"}}
_ = AllStuff + {"music", {nick = "greg", title = "another music", date = os.date(date)}} -- add a release
print (AllStuff("fuck you/1")) -- show an existing release
print (AllStuff("music/21")) -- show a nonexistent one
--print (AllStuff["frog/21"]) -- show a nonexistent category
-- the length operator returns the total number of releases even though AlStuff is empty and Releases is _not_ an array
-- print (#AllStuff.." new releases, let's add another!") 

--print (AllStuff - "music/1") -- delete a release
print ("total music releases: "..#AllStuff.music)
print "today:"
print (AllStuff("today",2))
print "end of today"
print (AllStuff + {"frog", {nick = "greg", title = "another music", date = os.date(date)}}) -- add a release to a nonexistent cat
print (AllStuff*"frog") -- add a new category
print (AllStuff/"toad") -- delete a nonexistent category
print( AllStuff + {"frog", {nick = "greg", title = "tadpole", date = os.date(date)}}) -- add a release to the newly created cat
print "NEW"
print (AllStuff("new")) -- new releases
print "END OF NEW\r\n++++++++++++"
print "LATEST"
print (AllStuff(4)) -- show the latest 3s
print "END OF LATEST"
print (AllStuff("fuck you"))
print (AllStuff/"frog") -- delete a category

--todo: 
--* __pow and __band metamethods for editind and moving between categories
--_ = AllStuff ^ {"frog/3", {nick = "greg", title = "tadpole", date = os.date(date)}} -- edit
--_ = AllStuff & {"frog/3", "fuck you"} -- move to another category, perhaps w/ mass
--* fake release generation and old release database converter
--       (latter has mm/dd/yy so SplitTimeString tinkering needed
--* this will then be the Kernel module and will look like Kernel.AllStuff and Kernel.Releases???
--* release search option if all the above fails in ___call a search is automatically done?
--* and if there is no option issued whatsoever? a short help text then
--* !releases today/new/music and music/34 or music/34,26,45,19 as well as music/22-49
--* !delrel music/34 or music/34,26,45,19 as well as music/22-49 same
--* maybe Allstuff.new[4] and Allstuff.new[MaxNew] would definitely be neater with __newindex 
--        within categories inside AllStuff -- started above
--* idea of customizable timers: "16:30" format everty day sametime or every "10m", "3h" etc.
--* also releases all and releases music/all and releases today/all
--       (return a limited string but full table so one can use the data for stats)