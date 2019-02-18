-- An array is associated with every cat. Array contains tables with
-- fields id, nick, title, every release is therefore a table/object.
-- This way  releases today and release pruning is easier.
-- ID is now per-category therefore commands should be 
-- issued like !delrel misc/1 !showrel music/1-15 or just !showrel game
-- matter of pattern matching only
-- !addcat, delcat (the latter with backup) 
Releases = 
{
  music = 
  {
    {nick = "joe",title = "stoner rock collection", date = "12/02/2019"},
    {nick = "jill", title = "scores for porn", , date = "12/02/2019"},
  }
  movie = 
  {
    {nick = "joe",title = "stoner rock collection", date = "13/02/2019"},
    {nick = "tom", title = "scores for porn", , date = "11/02/2019"},
  }
}

for k, v in Releases do
  AllStuff[k] = v
end


-- table.insert (Releases[cat][date], {nick = nick, id = id, title = title})
-- but we should do an AllStuff table with the same structure just the date 
-- arrays would be empty and using metamethods they'd access Releases
-- Therein every date array has a __newindex that calls OnRelAdded() as well as   
-- adds and takes care of newest releases  
-- __index returns the message to be sent like "ID: X //Added by etc."
--- or even send back a list like music/1 to facilitate the use of this ID type
-- hello, we can rawget anything if needed (for eg. topadders)
-- a __len (#Releases) should return a sum of all IDs in all categories
-- 

-- newest releases should be generated dynamically
-- 


-- module "Kernel" so Kernel.Commands and Kernel.Coroutines and 
-- Kernel.Commnands.Levels