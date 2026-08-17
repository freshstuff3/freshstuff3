-- plugins/release.lua
-- Business logic and frontend for freshstuff3 core fucntionality
-- This plugin cannot be disabled.
local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
-- Variables that are to be hardcoded/become config
---@type string
 ---@type string

--
-- First we load item manipulation fuctionality into our namespace
-- Namespace is global as data needs to be accessible from anywhere
local Init = require "core.init"
local AllStuff = Init:Create_instance()
assert(type(AllStuff) == "table","FATAL: Failed to initialise release module!") 
AllStuff.JOURNAL_FILE = base_path.."data/journals/freshstuff3.journal"
AllStuff.TEST_CATEGORY = base_path.."data/categories.dat"
AllStuff:Data_init(AllStuff.JOURNAL_FILE, AllStuff.TEST_CATEGORY)


--- Command registration
--- 
--- STRUCTURE:
--- 
--- ```lua
--- cmds["rel.show"] = {
--- 
---     aliases = { -- Will be configuration variable, temporary declaration
---                 "rel.tree", "AllStuff", "AllStuff"
---               },
--- 
---     level = 4,
--- 
---     helptext = 
---     [[ 
---         Show AllStuff in a hierarchical tree view.
---         Supports categories, numbers, time ranges, and ID lists.
---    
---         Examples:
---             !rel.show              - Latest 10 AllStuff
---             !rel.show Music        - Music category
---             !rel.show 1,2,3        - Specific IDs
---             !rel.show 1-10         - ID range
---             !rel.show 44d          - Last 44 days
---     ]],
---     
---     function (str) 
---         return "something" 
---     end 
--- }
--- ```
--- 
---@todo 
--- - aliases and help as configuration variables, declared here temporarily only
--- - sorting order
--- - [x] Command: !rel.show [argument]
---       No argument   → show latest 25 (configurable default)
---       <category>    → show AllStuff in category (tree view)
---       <number>      → show latest N AllStuff
---       <Nd/Nw/Nm>    → show AllStuff from last N days/weeks/months
---       all           → show all AllStuff
---       --md          → output as markdown instead of tree
---       --md=sort     → markdown with sorting (sn, sw, st, rsn, rsw, rst)
---
--- - [ ] Command: !rel.search <query> [--md] [--md=sort]
---       Search by title (case-insensitive, partial match)
---       Optional: --md for markdown output
---
--- - [ ] Command: !rel.add <category> <title> [nick]
---       Add new release
---
--- - [ ] Command: !rel.delete <id>
---       Delete release by ID
---
--- - [ ] Command: !rel.move <id> <new_category>
---       Move release to different category
---
--- - [ ] Command: !rel.cat
---       List all categories (with counts)
---
--- - [ ] Command: !rel.info <id>
---       Show detailed info for a release
---
--- - [ ] Command: !rel.stats
---       Show statistics (total items, categories, etc.)

AllStuff._cmd_handlers = {
["rel.show"] = { 

---@todo CONFIG_VAR
aliases = { "AllStuff", "rel.tree" },

---@todo CONFIG_VAR
level = 1,

func = function(self, str)
    str = str or ""
    str = str:gsub("^%s+", ""):gsub("%s+$", "")

        -- Parse str
        if str == "" then
            return self:Bus_show_new(10)
        end
        
        if str == "new" then
            return self:Bus_show_new(25)
        end
        
        if str == "all" then
            return self:Bus_show_new(#self._data)
        end
        
        local num = tonumber(str)
        if num then
            return self:Bus_show_new(num)
        end
        
        local tm = str:match("^(%d+[dwm])$")
        if tm then
            return self:Bus_show_newer_than(tm)
        end
        ---@todo: sanitise
        if self._category_index[str] then
            return self:Bus_show_in_category(str)
        end

        if next(self:UI_split_ids(str)) then
            return self:Bus_show_range(str)
        end
        
        return self:Bus_search(str)
end
},



["rel.md"] = {

---@todo CONFIG_VAR
aliases = { "rel-in-markdown" },

---@todo CONFIG_VAR
level = 1,

--- Markdown release list
---@param str string 
---    The raw string separated from preceding command by whitespace(s).
--- 
func = function (self, str)
    local format = "md"
    str = str or ""
    str = str:gsub("^%s+", ""):gsub("%s+$", "")

        -- Parse str
        if str == "" then
            return self:Bus_show_new(10, format)
        end
        
        if str == "new" then
            return self:Bus_show_new(25, format)
        end
        
        if str == "all" then
            return self:Bus_show_new(#self._data, format)
        end
        
        local num = tonumber(str)
        if num then
            return self:Bus_show_new(num, format)
        end
        
        local tm = str:match("^(%d+[dwm])$")
        if tm then
            return self:Bus_show_newer_than(tm, format)
        end
        ---@todo sanitise
        if self._category_index[str] then
            return self:Bus_show_in_category(str, format)
        end
        if next(self:UI_split_ids(str)) then
            return self:Bus_show_range(str, format)
        end
        return self:Bus_search(str)
end
},

--- Details of self
--- 
---@param str string 
---    The raw string separated from preceding command by whitespace(s).
--- 
["rel.details"] = {
---@todo config
level = 1,

aliases = { "reldetails" },
func = function(self, str)
    return self:Bus_show_range(str, "detail")
end
},

--- Fake data generator
--- 
---@param number integer 
---    Desired number of fake items to be created.
--- 
["rel.fake"] = {

aliases = { "fakerel" },

level = 1,  

func = function(self, number)
    local count = tonumber(number) or 100
    if count < 1 then
        return "Count must be a positive number"
    end
    if count > 10000 then
        return "Maximum 10000 self allowed"
    end
    local success, msg = self:Item_fake_db(count)
    if not success then
        return "Error: " .. msg
    end
    return msg
end
}
}

return AllStuff
