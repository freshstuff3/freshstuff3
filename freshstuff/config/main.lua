--[[
FreshStuff3 v5 main configuration file
Distributed under the terms of the Common Development and Distribution License (CDDL) Version 1.0. See docs/license.txt for details.
]]

--[[
-----------------------------------------------------------
Generic section
-----------------------------------------------------------
]]


-- Set the bot's data. (Relevant only for hubsofts, of course.)
Bot.name = "post-it_memo"
Bot.email="bastyaelvtars@gmail.com"
Bot.desc="Release bot"

-- Used profiles (only for PtokaX): 0 for lawmaker/terminator (standard), 1 for robocop, 2 for psyguard
-- This setting is unsupported and going to be removed soon. Custom profiles are a Bad Thing (tm).
ProfilesUsed = 0

-- Show latest stuff to a newly connected user? 1=PM, 2=mainchat, 0=no
ShowOnEntry = 2

-- Max stuff shown to new users, or when getting new releases.
-- This is the number of releases (backwards from the newest) that you consider new.
MaxNew = 20 

-- Timed release announcing. You can specify a category name, or "all" or "new"
WhenAndWhatToShow = {
  ["23:50"]="Lossless",
  ["20:48"]="warez",
  ["20:49"]="new",
  ["20:50"]="all",
  ["00:20"]="new",
}

-- Releases and requests containing such words cannot be added.
ForbiddenWords = {
"rape","incest",
}

-- Set to 1 to sort the releases within the category-based view alphabetically.
-- Otherwise they will be sorted by ID within a category.
SortStuffByName = 0

--[[
-----------------------------------------------------------
Commands and levels section. Enter the specific commands here, DO NOT INCLUDE THE PREFIX!
For levels (i. e. who are allowed to use the command) you give a number: 0-5. The numbers mean:

0: command is disabled
1: command is available to everyone
2: command is available to regs & above
3: command is available to vips & above
4: command is available to operators & above
5: command is available to masters only

(Custom profiles are not supported.)
-----------------------------------------------------------
]]

-- Add a new release
Commands.Add = "addrel" 
Levels.Add = 1

-- This command shows the stuff, syntax : +albums with options new/game/warez/music/movie
Commands.Show = "releases"
Levels.Show = 1

-- This command deletes an entry, syntax : +delalbum THESTUFF2DELETE. Note that everyone is allowed to delete the releases he/she added.
Commands.Delete="delrel"
Levels.Delete = 4

-- This command reloads the datafile. (This command is only needed if you manually edit the datafile which is disrecommended.)
Commands.ReLoad = "reloadrel"
Levels.ReLoad = 5

-- This is for searching among releases.
Commands.Search = "searchrel"
Levels.Search = 1

-- For adding a category
Commands.AddCatgry = "addcat"
Levels.AddCatgry = 4

-- For deleting a category
Commands.DelCatgry = "delcat" 
Levels.DelCatgry = 4

-- For showing categories
Commands.ShowCtgrs = "showcats"
Levels.ShowCtgrs = 1

-- Guess what! :P
Commands.Help = "relhelp"
Levels.Help = 1