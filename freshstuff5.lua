-- FreshStuff3 v5 alpha
-- License: GNU GPL v2
-- This is the common script that gets loaded by host apps, then takes care of everything else :-D
-- Characteristics (well, proposed - no, they are almost real as of end-feb 2007): modular and portable among host programs

--------
-- TODO:
--------
  -- make rightclick registration use metatables,
  -- make script decide whether to register rightclicks or not (BCDC++ issue mainly) - this is easy, just need to (not) register this on host-spec. mods
  -- make the script fully portable, i. e. it can use all stuff from the host program, while it interoperates with it smoothly (especially data sending)
  -- make the script automatically detect the environment
  -- Showing latest n releases... (?)
  -- Split this config below into module-specific parts.
  -- Add a prune function for completed requests (low priority, since they get autodeleted upon the requester's joining.)
  -- Merge Rodeo73's patches

hostprg=1

Bot = {
        name="post-it_memo",
        email="bastyaelvtars@gmail.com",
        desc="Release bot",
        version="5.0 pre-alpha",
      } -- Set the bot's data. (Relevant only for hubsofts, so hubsoftmodule-specific)
    ProfilesUsed= 0 -- 0 for lawmaker/terminator (standard), 1 for robocop, 2 for psyguard (ptokax-only)
    Commands={
      Add="addrel", -- Add a new release
      Show="releases", -- This command shows the stuff, syntax : +albums with options new/game/warez/music/movie
      Delete="delrel", -- This command deletes an entry, syntax : +delalbum THESTUFF2DELETE
      ReLoad="reloadrel", -- This command reloads the txt file. syntax : +reloadalbums (this command is needed if you manualy edit the text file)
      Search="searchrel", -- This is for searching inside releases.
      AddCatgry="addcat", -- For adding a category
      DelCatgry="delcat", -- For deleting a category
      ShowCtgrs="showcats", -- For showing categories
      Prune="prunerel", -- Pruning releases (removing old entries)
      TopAdders="topadders", -- Showing top adders
      Help="relhelp", -- Guess what! :P
      AddReq="addreq",
      ShowReqs="requests",
      DelReq="delreq",
    } -- No prefix for commands! It is automatically added. (<--- multiple prefixes)
    Levels={
      Add=1, -- adding
      Show=1, -- showing all
      Delete=4,   -- Delete releases. Note that everyone is allowed to delete the releases they added.
      ReLoad=4,   -- reload
      Search=1, -- search
      AddCatgry=4, -- add category
      DelCatgry=4, -- delete category
      ShowCtgrs=1, -- show categories
      Prune=5, -- prune (delete old)
      TopAdders=1, -- top release adders
      Help=1, -- Guess what! :P
      AddReq=1, -- Add a request.
      ShowReqs=1, -- Show requests.
      DelReq=4, -- Delete requests. Note that everyone is allowed to delete their own requests.
    } -- You set the userlevels according to... you know what :P
    MaxItemAge=30 -- IN DAYS
    TopAddersCount=5 -- shows top-adders on command, this is the number how many it should show
    ShowOnEntry = 2 -- Show latest stuff on entry 1=PM, 2=mainchat, 0=no
    MaxNew = 20 -- Max stuff shown on newalbums/entry
    WhenAndWhatToShow={
      ["20:47"]="music",
      ["20:48"]="warez",
      ["20:49"]="new",
      ["20:50"]="all",
      ["23:44"]="new",
    }-- Timed release announcing. You can specify a category name, or "all" or "new"
    ForbiddenWords={ -- Releases and requests containing such words cannot be added.
    "rape",
    "incest",
    }
    SortStuffByName=1 -- Set to 1 to sort the releases within the category-based view alphabetically.

Host={"ptokax","bcdc","verli","aquila"}
AllStuff,NewestStuff,rightclick,commandtable,rctosend,Engine={},{},{},{},{},{}
botver="FreshStuff3 v 5.0 alpha1"
package.path="freshstuff/?.lua"
require(Host[hostprg])
require "kernel"
require "tables"
require "components.extras"
require "components.requester"

Functions={}