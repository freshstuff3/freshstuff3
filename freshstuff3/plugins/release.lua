-- plugins/release.lua
-- Business logic and frontend for freshstuff3 core fucntionality
-- This plugin cannot be disabled.
--[[ local path_separator = package.config:sub(1, 1)
local base_path
if type(Core) == "table" and type(Core.GetPtokaXPath) == "function" then
    local ptokax_path = Core.GetPtokaXPath()
    if not ptokax_path:match("[/\\]$") then
        ptokax_path = ptokax_path .. path_separator
    end
    base_path = ptokax_path .. "scripts" .. path_separator .. "freshstuff3" .. path_separator
elseif path_separator == "\\" then
    -- Running on Windows
    base_path = "C:\\freshstuff3\\freshstuff3\\"
else
    -- Running on Linux or macOS
    base_path = "/freshstuff3/freshstuff3/"
end
local journal = base_path .. "data" .. path_separator .. "journals" .. path_separator .. "freshstuff3.journal"
local category = base_path .. "data" .. path_separator .. "categories.dat" ]]

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

local SORT_SWITCHES = {
    ["--c"] = "c",
    ["--r"] = "r",
    ["--n"] = "sn",
    ["--rn"] = "rsn",
    ["--t"] = "st",
    ["--rt"] = "rst",
}

--- Extract one sorting switch while preserving the remaining command argument.
---@param str string|nil
---@return string argument
---@return string|nil sort_order
---@return string|nil err
function AllStuff:Bus_parse_sort_args(str)
    local argument = {}
    local sort_order

    for token in (str or ""):gmatch("%S+") do
        local requested_order = SORT_SWITCHES[token]
        if requested_order then
            if sort_order then
                return "", nil, "❌ Specify only one sorting switch."
            end
            sort_order = requested_order
        else
            table.insert(argument, token)
        end
    end

    return table.concat(argument, " "), sort_order
end

function AllStuff:Bus_dispatch_args(str, format)
    format = format or "tree"
    local argument, sort_order, sort_error = self:Bus_parse_sort_args(str)
    if sort_error then
        return self.HP .. sort_error
    end
    if format == "tree" then
        sort_order = nil
    end

    -- Parse str
    if argument == "" then
        return self.HP..self:Bus_show_new(10, format, sort_order)
    end
    
    if argument == "new" then
        return self.HP..self:Bus_show_new(25, format, sort_order)
    end
    
    if argument == "all" then
        return self.HP..self:Bus_show_new(#self._data, format, sort_order)
    end
    
    local num = tonumber(argument)
    if num then
        return self.HP..self:Bus_show_new(num, format, sort_order)
    end
    
    local tm = argument:match("^(%d+[dwm])$")
    if tm then
        return self.HP..self:Bus_show_newer_than(tm, format, sort_order)
    end
    ---@todo sanitise
    if self._category_index[argument] then
        return self.HP..self:Bus_show_by_category(argument, format, sort_order)
    end
    local ids = self:Bus_split_ids(argument)
    if ids then
        return self.HP..self:Bus_show_range(argument, format, sort_order)
    end
    -- Fall back to search if no other match
    return self.HP..self:Bus_search(argument, format, sort_order)
end

AllStuff._cmd_handlers = {
    ["rel.get"] = { 

    func = function(self, str)
        return self:Bus_dispatch_args(str, "tree")
    end
    },

    ["rel.md"] = {

    --- Markdown release list
    ---@param str string 
    ---    The raw string separated from preceding command by whitespace(s).
    --- 
    func = function (self, str)
        return self:Bus_dispatch_args(str, "md")
    end
    },


    ["rel.details"] = {
    --- 
    ---@param str string 
    ---    The raw string separated from preceding command by whitespace(s).
    --- 
    func = function(self, str)
        local argument, sort_order, sort_error = self:Bus_parse_sort_args(str)
        if sort_error then
            return self.HP .. sort_error
        end
        return self.HP..self:Bus_show_range(argument, "detail", sort_order)
    end
    },

    ["rel.cat"] = {

    func = function(self, str)
        if not str or str == "" then
            return self.HP .. self:UI_header_flat_tree() ..
                self:Bus_show_flat_tree()
        end
        
        local succ, path = self:Category_process_path(str:match("(%S+)"))
        if succ and self._category_index[path] then
            local header = self:UI_header_flat_tree(path)
            return self.HP .. header .. self:Bus_show_flat_tree(path)
        else
            return self.HP ..
            "❌ Category not found: " .. str
        end
    end
    },

    ["rel.fake"] = {
    --- Fake data generator
    --- 
    ---@param number integer 
    ---    Desired number of fake items to be created.
    --- 
    func = function(self, number)
        local count = tonumber(number) or 100
        if count < 1 then
            return "❌ Count must be a positive number"
        end
        if count > 10000 then
            return "❌ Maximum 10000 items allowed"
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
    ["rel.del"] = { -- needx to handle mass deletion NOT category deletion
    -- also --imeanit switch options for category deletion
    func = function (self, str, nick)
        str = (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local rel_id = tonumber(str) -- if number, delete single release without preview
        if rel_id then
            local _, _, result = self:Bus_delete_releases({ rel_id }, nick, { preview = false })
            return self.HP..result
        end

        local is_preview = not str:match("%s+%-%-imeanit$")
        if not is_preview then
            str = str:gsub("%s+%-%-imeanit$", "")
        end
        local _, _, result = self:Bus_delete_releases(str, nick, { preview = is_preview })
        return self.HP..result
    end,
    },

    ["rel.add"] = { -- need to use Bus_logic
        func = function (self, str, nick)
            print(str)
            local cat, title = str:match("(%S+)%s+(.+)")
            print(cat, title)
            if not (cat and title) or cat == "" or title == "" then
                return "❌ Usage: !rel.add <category> <title>"
            end
            local _, result = self:Bus_add(nick, title, cat)
            return self.HP .. result
        end,
    },

    ["rel.delcat"] = { -- needx to handle mass deletion NOT category deletion
    -- also --imeanit switch options for category deletion
        func = function (self, str, nick)
            str = (str or ""):gsub("^%s+", ""):gsub("%s+$", "")

            local is_preview = not str:match("%s+%-%-imeanit$")
            if not is_preview then
                str = str:gsub("%s+%-%-imeanit$", "")
            end
            local _, _, result = self:Bus_delete_category(str, nick, { preview = is_preview })
            return self.HP .. result
        end,
    },
    ["rel.nukecat"] = {
        func = function (self, str, nick)
            str = (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
            local is_preview = not str:match("%s+%-%-imeanit$")
            if not is_preview then
                str = str:gsub("%s+%-%-imeanit$", "")
            end
            local _, _, result = self:Bus_delete_category(str, nick, {
                preview = is_preview,
                force = true,
                nuke = true,
            })
            return self.HP .. result
        end,

    },

    ["rel.move"] = {
        func = function (self, str, nick)
            local id_spec, new_category = (str or ""):match("^(.-)%s+(%S+)%s*$")
            if not id_spec or id_spec == "" then
                return self.HP .. "❌ Usage: !rel.move <id[,id...|start-end]> <category>"
            end

            local ids
            local id = tonumber(id_spec)
            if id then
                ids = { id }
            else
                ids = self:Bus_split_ids(id_spec)
            end
            if not ids then
                return self.HP .. "❌ Invalid release IDs. Use id1,id2,... or id1-id2."
            end

            local succ, moved_or_error, failed = self:Bus_move_rel(ids, new_category)
            if succ then
                return self.HP .. table.concat ({
                    "Moved: " .. table.concat(moved_or_error, ", "),
                    "Failed: " .. table.concat(failed, ", ")
                }, "\r\n")
            else
                return self.HP .. moved_or_error
            end
        end,

    }
}

return AllStuff
