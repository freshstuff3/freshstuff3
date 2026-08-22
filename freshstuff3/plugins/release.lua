-- plugins/release.lua
-- Business logic and frontend for freshstuff3 core fucntionality
-- This plugin cannot be disabled.
local base_path, journal, category
if package.config:sub(1,1) == "\\" then
    -- Running on Windows
    base_path = "C:\\freshstuff3\\freshstuff3\\"
    journal = base_path.."data\\journals\\freshstuff3.journal"
    category = base_path.."data\\categories.dat"
else
    -- Running on Linux or macOS
    base_path = "/freshstuff3/freshstuff3/"
    journal = base_path.."data/journals/freshstuff3.journal"
    category = base_path.."data/categories.dat"
end

--
-- First we load item manipulation functionality into our namespace

-- local AllStuff = Init:load_plugin("release")

--assert(type(AllStuff) == "table","FATAL: Failed to initialise release module!") 
local Init = require "helpers.init"
local AllStuff = package.loaded["plugins.release"] 
-- This had been loaded before, most likely at startup, so
-- just return the cached copy and get outta here
if AllStuff then return AllStuff end

-- AllStuff does not exist: first load, not subsequent require.
-- We therefore need to create the plugin instance
--  
AllStuff = Init:create_instance()

--- OPTIONAL SECTION
--- Do the below only on initial load
--- These only have to be done if you plan to have your plugin's
--- own database, which we do in this case.

--- Now that our instance has been created, let's let it take control!

-- Load submodules specific to this plugin
-- For example, I have put the entire business logic into an outside file,
-- limiting this script file to command/event registration
-- 
AllStuff:merge('plugins.release.business')
AllStuff:merge('plugins.release.bus_delete')

-- Declare category and journal file (OPTIONAL)
AllStuff.JOURNAL_FILE = journal
AllStuff.TEST_CATEGORY = category
AllStuff.HP = 
    "[freshstuff3-releases]> Hello! You summoned me...\r\n"..
    string.rep("=", 50).."\r\n"
AllStuff.P = "[freshstuff3-releases]> "
-- Initialise data (OPTIONAL)
AllStuff:data_init()
--- END OPTIONAL SECTION
--[[ 

Command registration

STRUCTURE:

```lua
cmds["rel.show"] = {

    aliases = { -- Will be configuration variable, temporary declaration
                "rel.tree", "AllStuff", "AllStuff"
              },

    level = 4,

    helptext = 
    
        Show AllStuff in a hierarchical tree view.
        Supports categories, numbers, time ranges, and ID lists.
   
        Examples:
            !rel.show              - Latest 10 AllStuff
            !rel.show Music        - Music category
            !rel.show 1,2,3        - Specific IDs
            !rel.show 1-10         - ID range
            !rel.show 44d          - Last 44 days
    ,
    
    function (str) 
        return "something" 
    end 
}
```

@todo 
- aliases and help as configuration variables, declared here temporarily only
- sorting order
- [x] Command: !rel.show [argument]
      No argument   → show latest 25 (configurable default)
      <category>    → show AllStuff in category (tree view)
      <number>      → show latest N AllStuff
      <Nd/Nw/Nm>    → show AllStuff from last N days/weeks/months
      all           → show all AllStuff
      --md          → output as markdown instead of tree
      --md=sort     → markdown with sorting (sn, sw, st, rsn, rsw, rst)

- [ ] Command: !rel.search <query> [--md] [--md=sort]
      Search by title (case-insensitive, partial match)
      Optional: --md for markdown output

- [ ] Command: !rel.add <category> <title> [nick]
      Add new release

- [ ] Command: !rel.delete <id>
      Delete release by ID

- [ ] Command: !rel.move <id> <new_category>
      Move release to different category

- [ ] Command: !rel.delcat <category>
      delete category with --force and --nuke 
 ]]

function AllStuff:Bus_dispatch_args(str, format)
    format = format or "tree"
    -- Parse str
    if not str or str == "" then
        return self.HP..self:Bus_show_new(10, format)
    end
    
    if str == "new" then
        return self.HP..self:Bus_show_new(25, format)
    end
    
    if str == "all" then
        return self.HP..self:Bus_show_new(#self._data, format)
    end
    
    local num = tonumber(str)
    if num then
        return self.HP..self:Bus_show_new(num, format)
    end
    
    local tm = str:match("^(%d+[dwm])$")
    if tm then
        return self.HP..self:Bus_show_newer_than(tm, format)
    end
    ---@todo sanitise
    if self._category_index[str] then
        return self.HP..self:Bus_show_by_category(str, format)
    end
    if next(self:UI_split_ids(str)) then
        return self.HP..self:Bus_show_range(str, format)
    end
    -- Fall back to search if no other match
    return self.HP..self:Bus_search(str, format)
end

AllStuff._cmd_handlers = {
    ["rel.get"] = { 

    ---@todo CONFIG_VAR
    aliases = { "releases", "rel.show", "rel.search" },

    ---@todo CONFIG_VAR
    level = 1,

    func = function(self, str)
        return self:Bus_dispatch_args(str, "tree")
    end
    },

    ["rel.md"] = {

    ---@todo CONFIG_VAR
    aliases = { "relmd" },

    ---@todo CONFIG_VAR
    level = 1,

    --- Markdown release list
    ---@param str string 
    ---    The raw string separated from preceding command by whitespace(s).
    --- 
    func = function (self, str)
        return self:Bus_dispatch_args(str, "md")
    end
    },


    ["rel.details"] = {
    ---@todo config
    level = 1,

    aliases = { "reldetails" },
    --- 
    ---@param str string 
    ---    The raw string separated from preceding command by whitespace(s).
    --- 
    func = function(self, str)
        return self.HP..self:Bus_show_range(str, "detail")
    end
    },

    ["rel.cat"] = {

    ---@todo config
    level = 1,

    aliases = { "rel.category" },

    func = function(self, str)
        if not str or str == "" then
            return self.HP .. 
            "🌳 TREE VIEW OF ALL THE CATEGORIES:\r\n\r\n"..
            self:Bus_show_category_tree()
        end
        local succ, path = self:Category_process_path(str:match("(%S+)"))
        if succ and self._category_index[path] then
            return self.HP .. 
            "🌳 TREE VIEW OF CATEGORY " .. path .. "\r\n" ..
            string.rep("=", 50) .. "\r\n" ..self:Bus_show_category_tree(path)
        else
            return self.HP ..
            "❌ Category not found: " .. str
        end
    end
    },


    ["rel.fake"] = {
    ---@todo config

    aliases = { "fakerel" },

    level = 1,

    --- Fake data generator
    --- 
    ---@param number integer 
    ---    Desired number of fake items to be created.
    --- 
    func = function(self, number)
        local count = tonumber(number) or 100
        if count < 1 then
            return "Count must be a positive number"
        end
        if count > 10000 then
            return "Maximum 10000 self allowed"
        end
        local success, msg = self:Item_fake_database(count)
        if not success then
            return "Error: " .. msg
        end
        return msg
    end
    
},
---@todo add delete, move, category delete/rename
--- Store the above in package.loaded upon require
--- 
--- Delete releases
--- 
    ["rel.del"] = {
    
    func = function (self, str)
        local id  = tonumber(str)
        if id then -- single item
            local succ, err = self:Item_delete(id)
            if succ then return self:UI_render(id, "detail")
            else return err end
        end
        if id:find("%d+,") or id:find(("%d+%-%d+")) then --range
            return
        end
    end,

    level = 3,

    aliases = { "delrel", "reldelete" }
    }
}
return AllStuff
