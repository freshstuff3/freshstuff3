-- plugins/release.lua
-- Business logic and frontend for freshstuff3 core fucntionality
-- This plugin cannot be disabled.

-- Variables that are to be hardcoded/become config
 JOURNAL_FILE = base_path.."data/journals/freshstuff3.journal"
 TEST_CATEGORY = base_path.."data/categories.dat"

--
-- First we load item manipulation fuctionality into our namespace
-- Namespace is global as data needs to be accessible from anywhere
local Instance = require "core.instance"
AllStuff = Instance:new()
-- Populate _data from journal replay
--AllStuff:Item_init(JOURNAL_FILE)
local success, err = AllStuff:Item_init(JOURNAL_FILE)
if not success then
    print("ERROR: Item_init failed:", err)
    AllStuff._data = {}
end

if not next(AllStuff._data) then print("No data could be loaded from journal") AllStuff._data = {} end
AllStuff:Category_init(TEST_CATEGORY)

--- # Search and display results (business logic)
--- 
--- ## Usage:
--- 
--- - `!rel.search` -- Search for a string. Checks nicks and titles, as well as categories.
--- 
---@param query string Search term
---@param format string "tree", "md" etc
---@param sort_order string Sort order
---@return string result Formatted output
function AllStuff:Rel_search(query, format, sort_order) 
    local result = {        
        string.rep("==", 50),
        string.format("🔎 SEARCH RESULTS\r\n🧐 QUERY: %s", query),
        string.rep("==", 50),
        }
    local rel, cat = self:Item_search(query)
    if #rel == 0 then
        if #cat ~= 0 then
            table.insert(result, "📁 CATEGORIES FOUND:")
            table.move(cat, 1, #cat, #result + 1, result)
        else
            table.insert(result,
            string.format("\r\nNo results for query %s", query))
        end
        return table.concat(result, "\r\n")
    else
        table.insert(result, 
        self:UI_render(rel, format, sort_order) or "Rendering error")
    end
    return table.concat(result, "\r\n")
end

--- # Delete category
--- 
---
--- ## Usage:
--- - `!rel.cat.del` - Delete empty category
--- - `!rel.cat.delforce` - Delete category and subcategories. Will not delete anything if category has subcategories. Optional --imeanit switch, defaults to preview
--- - `!rel.cat.nuke` - Delete category *also deleting its releases and suncategories*. Optional --imeanit switch, defaults to preview
---@param path string Category path
---@param category_file string Category file
---@param journal_file string Journmal file
---@param is_force? boolean Delete category with releases if it has no subcategories
---@param is_nuke? boolean Delete category with releases if it has no subcategories
---@param is_preview? boolean WWhether we are doing a dry run. If unspecified, it's a dry run.
---@return string|false response Formatted ouput or false on error
---@return string? result Error message
function AllStuff:Rel_del_category(path, category_file, journal_file, is_force, is_nuke, is_preview)
    is_preview = (is_preview == nil) and true or is_preview
    
    if is_preview then
        local ok, msg = self:Rel_del_category_drill(path, is_force, is_nuke)
        if not ok then
            return false, msg
        end
        return msg
    end
    
    -- Full deletion
    local ids, result = self:Category_delete(path, category_file, journal_file, is_force, is_nuke, false)
    if not ids then
        return false, result
    end
    
    local msg = {
        "CATEGORY DELETION FULL RUN",
        "===========================",
        string.format("Deleted %d items", #ids),
    }
    
    if #ids > 0 then
        table.insert(msg, "")
        table.insert(msg, "Items deleted:")
        for _, id in ipairs(ids) do
            local item = self._data[id]
            if item then
                table.insert(msg, string.format("  ID: %d - %s (%s)", id, item.title, item.category))
            else
                table.insert(msg, string.format("  ID: %d (not found)", id))
            end
        end
    else
        table.insert(msg, "No items were deleted")
    end
    
    if type(result) == "string" then
        table.insert(msg, "")
        table.insert(msg, "Result: " .. result)
    end
    
    return table.concat(msg, "\r\n")
end

--- ## Delete category (preview/dry run wrapper)
--- 
--- THIS IS A DRILL :D
--- 
--- - `!rel.cat.del` --> `is_force` and `is_nuke` false
--- - `!rel.cat.forcedel` --> `is_force` true, `is_nuke` false
--- - `!rel.cat.nuke` --> `is_force` and `is_nuke` true
--- 
--- The first one will delete empty categories only.
--- 
--- The others will only do any actual deletion if the `--imeanit` switch is specified
--- 
---@param path string Category path
---@param is_force? boolean Delete category even if it has items. Will not delete if subcategories are present.
---@param is_nuke? boolean Deep-delete category even if it has items and/or subcategories. Needs `force` to be `true`
---@return string|boolean err Returns list of categories to be deleted if preview or error string on failure.
---@return string err Returns list of categories to be deleted if preview or error string on failure.
function AllStuff.Rel_del_category_drill(self, path, is_force, is_nuke)
    local ids, result = self:Category_delete(path, "preview", "preview", is_force, is_nuke, true)
    if not ids then
        return false, result
    end
    
    local msg = {
        "CATEGORY DELETION TEST RUN",
        "=========================="
    }
    
    -- ✅ Only show IDs that will be deleted, not the full tree
    if #ids > 0 then
        table.insert(msg, "Items to be deleted (" .. #ids .. "):")
        -- ✅ Use a simple list, not UI_render_tree (which shows the full tree)
        for _, id in ipairs(ids) do
            local item = self._data[id]
            if item then
                table.insert(msg, string.format("  ID: %d - %s (%s)", id, item.title, item.category))
            else
                table.insert(msg, string.format("  ID: %d (not found)", id))
            end
        end
    else
        table.insert(msg, "No items to delete")
    end
    
    if type(result) == "table" and #result > 0 then
        table.insert(msg, "")
        table.insert(msg, "Categories to be deleted:")
        for _, cat in ipairs(result) do
            table.insert(msg, "  " .. cat)
        end
    elseif type(result) == "string" then
        table.insert(msg, result)
    end
    
    return true, table.concat(msg, "\r\n")
end
--- Show category tree with count but not individual releases
--- 
--- Starts from root when path is nil.
--- 
---@param path? string Category path
---@return string|boolean result Formatted output or false on error
---@return string|nil error Formatted output
---@todo Implement: get category count
---@todo Implement: get subcategory count
---@todo Implement: show category info with release count
function AllStuff:Rel_show_category_tree(path)
    if path then
        local p, ret = self:Category_process_path(path)
        if p then
            if not self._category_index[ret] then 
                return false, string.format("Category %s does not exist!", ret)
            end
            return self:UI_render_category_tree(ret)
        else return false, ret end
    else
        return self:UI_render_category_tree()
    end
end


--- Show release details
--- 
--- 
---@param ids table|number Array of integers, ID don't have to point to existing items. Also accepts single integer.
---@param format string "tree", "md" etc
---@param sort_order string Sort order
---@return string result Formatted output
---@todo Implement: get release from source_of_truth._data[id]
---@todo Implement: format: ID, Title, Category, Nick, Date
---@todo Implement: return "Release not found" if missing
function AllStuff:Rel_show_details(ids, format, sort_order)
    if type(ids) == "number" then
        ids = { ids }
    end
    if type(ids) ~= "table" then
        return "Invalid ID format"
    end
    return self:UI_render(ids, format, sort_order) or "invalid sort order"
end


function AllStuff:Rel_move(ids, new_path, journal_file)
    if type(ids) == "number" then
        ids = { ids }
    end
    if type(ids) ~= "table" then
        return "Invalid ID format"
    end
    if new_path and type (new_path) == "string" then
        local succ, p = self:Category_process_path(new_path)
        if p then
            if not self._category_index[p] then 
                return false, string.format("Category %s does not exist!", p)
            end
            local result = {}
            for _, id in ipairs(ids) do
                local succ, err = self:Item_move_id(id, p, journal_file)
                if succ then
                    table.insert(result,
                    string.format("Moved id %d from %s to %s",
                    id,
                    self._data[id].category,
                    p
                    ))
                else
                    table.insert(result,
                    string.format("Failed to move id %d from %s to %s because %s",
                    id,
                    self._data[id].category,
                    p,
                    err
                    ))
                end
            end
            return true, table.concat(result, "\r\n")
        else return false, err end
    else
        return false, "No/invalid path specified"
    end
end


--AllStuff:create_category
function AllStuff:Rel_create_category(path)
    if path and type (path) == "string" then
        local p, err = self:Category_process_path(path)
        if p then
            if self._category_index[err] then 
                return false, string.format("Category %s already exists!", err)
            end
            return self:UI_render_category_tree(err)
        else return false, err end
    else
        return false, "No path specified"
    end
end

---Rename a category
---
---@param old_path string
---@param new_path string
---@param format? string
---@param sort_order? string
function AllStuff:Rel_rename_category(old_path, new_path, format, sort_order)
    local result = { 
        "Category rename operation - results",
        string.format("Renaming category %s to %s", old_path, new_path) 
        }
    local old, new = self:Category_rename(old_path, new_path)
    if not old then
        table.insert(result, new)
    else
        table.insert(result, self:UI_render(new, format, sort_order))
        table.insert(result, string.format ("Moved %d items", #new))
    end
    return(table.concat(result, "\r\n"))
end

---Add a release
---
---@param nick string
---@param title string
---@param path string
---@return string result
function AllStuff:Rel_add(nick, title, path)
    local x, clean_path = self:Category_process_path(path)
    if not x then return clean_path end
    local t, err = self:Item_validate_title(title)
    if not t then return err end
    if self._category_index[clean_path] then
        self:Item_add({ 
            nick = nick,
            title = title,
            category = clean_path,
            when = os.time()
        }, JOURNAL_FILE)
        return self:UI_render(#self._data, "detail")
    else
        return (string.format("Category %s does not exist, create it first!", clean_path))
    end
end

---Delete a release
---
---@param ids table
---@return string result
function AllStuff:Rel_del(ids) -- todo: create backup
    if type (ids) == "number" then ids = { ids } end
    local succeeded, failed = { "SUCCESSFUL DELETE"}, { "FAILED DELETE" }
    for _, id in ipairs(ids) do
       local succ, err = self:Item_delete(id, JOURNAL_FILE)
        if not succ then 
            table.insert(failed, 
            string.format("Deletion of ID %d failed with error %s", 
            id,
            err
            ))
        else
            table.insert(succeeded, 
            string.format("Deletion of ID %d successful",
            id
            ))
        end
    end
    return table.concat(succeeded, "\r\n") .."\r\n".. table.concat(failed, "\r\n")
end

---Move one or more release
---
---@param ids table
---@param new_path string
---@return string result
function AllStuff:Rel_move(ids, new_path)
    local x, clean_path = self:Category_process_path(new_path) 
    if not x then return clean_path end
    if type (ids) == "number" then ids = { ids } end
    local succeeded, failed = { "SUCCESSFUL MOVE"}, { "FAILED MOVE" }
    for id, _ in ipairs(ids) do
        local oldpath = self._data[id] and self._data[id].category or "UNKNOWN"
        local succ, err = self:Item_move_id(id, new_path, JOURNAL_FILE)
        if not succ then 
            table.insert(failed, 
            string.format("Moving of ID %d "..
            "from %s to %s failed with error %s", 
            id,
            oldpath, 
            new_path, 
            err
            ))
        else
            oldpath = self._data[id].category
            table.insert(succeeded, 
            string.format("Moving of ID %d from %s to %s successful",
            id,
            oldpath, 
            new_path
            ))
        end
    end
    return table.concat(succeeded, "\r\n") .. table.concat(failed, "\r\n")
end

--- GET NEW RELEASES
---
--- Displays the most recently added releases, up to the specified count.
--- Releases are shown in reverse chronological order (newest first).
---
--- Behavior:
---   - If number < total releases: Shows the latest N releases
---   - If number >= total releases: Shows ALL releases with "ALL ITEMS" header
---   - If number <= 0 or not provided: Shows default (e.g., 10)
---
--- The output is rendered as a hierarchical category tree, with releases
--- grouped under their respective categories.
---
--- Examples:
---   !rel.show 5   - Shows the 5 most recent releases
---   !rel.show 50  - Shows the 50 most recent releases
---   !rel.show 999 - If there are 500 releases total, shows ALL releases
---   !rel.show     - Shows default (configurable, e.g., 10)
---   OPTIONAL SWITCHES:
---       --sn : sort by nick (ascending)
---       --sw : sort by submission time (ascending)
---       --st : sort by title (ascending)
---       --rsn: reverse sort by nick (descending)
---       --rsw: reverse sort by time (descending)
---       --rst: reverse sort by title (descending)
---       --r  : reverse by ID
---
---@todo If number is "all" or "everything", show all items
---@todo If number is negative, show error message
---@todo If number exceeds total, show all items with note: "Showing all N items"
---@todo Consider adding pagination for large results (e.g., !new 50 --page 2)
---@todo Add timestamp range filter: !new 20 --since 2024-01-15
---@todo Add category filter: !new 20 --category Music/Metal
---@todo Support output formats: tree, markdown, plain list (configurable)
---@param number integer Number of items to show (or "all" to show everything)
---@param format? string
---@param sort_order? string
---@return string|false result Formatted tree with header indicating "LATEST N" or "ALL ITEMS"
function AllStuff:Rel_show_new(number, format, sort_order)
    format = format or "tree"
    -- validity of number is checked by now
    assert (number ~= nil and self ~= nil, "Number or source "..
                                                    "of_truth not specified!"
                                                    )
    local result = {}
    local total = #self._data
    -- Get the actual count to show
    local count = math.min(number, total)

    -- Build IDs from the end
    local ids = {}
    for i = 1, count do
        local id = total - count + i
        table.insert(ids, id)
    end

    if count >= total then
        table.insert(result, 
            string.format("\r\n\r\nALL THE ITEMS ( TOTAL: %d )\r\n\r\n",
        total
        ))
    else
        table.insert(result, 
            string.format("\r\n\r\nLATEST %d ITEMS\r\n\r\n", count
        ))
    end
    local ret = self:UI_render(ids, format, sort_order)
    if type(ret) == "string" then
        table.insert(result, ret)
        return table.concat(result, "\r\n")
    end 
    return false
end

--- SHOW RELEASES BY CATEGORY
---
--- Displays all releases belonging to a specific category, including
--- releases in all subcategories (recursive traversal).
---
--- Behavior:
---   - If path exists and has releases: Shows full category tree for that path
---   - If path exists but is empty: Returns "No results"
---   - If path does not exist: Returns "No results"
---   - If path is a parent category: Includes all subcategories (recursive)
---   - If path is empty or nil: Shows all categories (falls back to "new" view)
---
--- The output preserves the full category hierarchy, making it easy to
--- see the structure of releases within the requested category.
---
--- Category path examples:
---   "Music"          - Shows all Music releases (including subcategories)
---   "Music/Metal"    - Shows only Metal releases (and its subcategories)
---   "Movies/Horror"  - Shows Horror movies (and subgenres like Slasher, Giallo)
---   "TV"             - Shows all TV releases
---
---@param path string Category path (e.g., "Music/Metal", "Movies/Horror")
---@param format? string "tree", "md", "detail", defaults to "tree"
---@param sort_order? string
---@return string|false result Formatted tree showing releases grouped by category 
--- or false if category does not exist
---@todo --no-subcat switch
function AllStuff:Rel_show_in_category(path, format, sort_order)
    format = format or "tree"
    if self._category_index[path] ~=nil then
        local result
        local ids = self:Category_get_subcat(path)
        if #ids > 0 then
            result = self:UI_render(ids, format, sort_order)
            if not result then return false end
        else
            return "No releases found in category: " .. path
        end
        return result
    else return "Non-existent category: " .. path end
end
---Show a range of releases
---@usage
--- - !rel.show 1,2,3,4
--- - !rel.show 3-19
--- - Spaces allowed, so is reverse or random order. 
--- - Will display results in order of IDs input.
---@param str string String to be processed.
---@param format? string "tree", "md" etc. Falls back to "tree".
---@param sort_order? string  Sort order
function AllStuff:Rel_show_range(str, format, sort_order)
    format = format or "tree"
    if tonumber (str) then -- single item, give details
       return self:UI_render({ tonumber(str) },
                         "detail", sort_order)
    else
        local ids = self:UI_split_ids(str) or {}
        if not next(ids) then
            return "Invalid parameter! Usage: id1,id2,id3 or id1-id2"
        else
            return self:UI_render(ids, format, sort_order)
        end
    end
end

--- Displays releases added within a specified time window.
--- 
--- Supports human-readable time formats and natural language shortcuts.
---
--- Time format: <number><unit> where unit is:
---   - d: days (e.g., 7d = 7 days)
---   - w: weeks (e.g., 2w = 14 days)
---   - m: months (e.g., 3m = 90 days, approximated as 30 days/month)
---
--- Special shortcuts:
---   - "today"   : Releases from today (00:00:00 onwards)
---   - "yesterday": Releases from yesterday (00:00:00 to 23:59:59)
---   - "week"    : Releases from the last 7 days (equivalent to "7d")
---   - "month"   : Releases from the last 30 days (equivalent to "30d")
---
--- Examples:
---   !rel.show 1d   - Releases from the last 24 hours
---   !rel.show 3w   - Releases from the last 21 days
---   !rel.show 1m   - Releases from the last 30 days
---   !rel.show today - Releases added today
---   !rel.show yesterday - Releases added yesterday
--- 
---@param time_window string Timeframe string (e.g., "5d", "3w", "1m", "today", "yesterday")
---@param format? "tree"|"md"|"detail"
---@param sort_order? string
---@return string|false result Formatted tree or "No results" or false if invalid format
---@todo If timeframe is empty or invalid, fallback to default (e.g., "7d")
function AllStuff:Rel_show_newer_than(time_window, format, sort_order)
    time_window = time_window:lower()
    format = format or "tree"
    local ids = self:Item_get_newer_than(time_window)
    if #ids == 0 then
        return "No results"
    end
    return self:UI_render(ids, format, sort_order)
end

AllStuff:cmd_register("rel.show", function(args)
    args = args or ""
    args = args:gsub("^%s+", ""):gsub("%s+$", "")

        -- Parse args
        if args == "" then
            return AllStuff:Rel_show_new(10)
        end
        
        if args == "new" then
            return AllStuff:Rel_show_new(25)
        end
        
        if args == "all" then
            return AllStuff:Rel_show_new(#AllStuff._data)
        end
        
        local num = tonumber(args)
        if num then
            return AllStuff:Rel_show_new(num)
        end
        
        local tm = args:match("^(%d+[dwm])$")
        if tm then
            return AllStuff:Rel_show_newer_than(tm)
        end
        ---@todo: sanitise
        if AllStuff._category_index[args] then
            return AllStuff:Rel_show_in_category(args)
        end

        if next(AllStuff:UI_split_ids(args)) then
            return AllStuff:Rel_show_range(args)
        end
        
        return AllStuff:Rel_search(args)
end,
{ "releases", "rel.tree" })

AllStuff:cmd_register("rel.md", function(args)
    local format = "md"
    args = args or ""
    args = args:gsub("^%s+", ""):gsub("%s+$", "")

        -- Parse args
        if args == "" then
            return AllStuff:Rel_show_new(10, format)
        end
        
        if args == "new" then
            return AllStuff:Rel_show_new(25, format)
        end
        
        if args == "all" then
            return AllStuff:Rel_show_new(#AllStuff._data, format)
        end
        
        local num = tonumber(args)
        if num then
            return AllStuff:Rel_show_new(num, format)
        end
        
        local tm = args:match("^(%d+[dwm])$")
        if tm then
            return AllStuff:Rel_show_newer_than(tm, format)
        end
        ---@todo sanitise
        if AllStuff._category_index[args] then
            return AllStuff:Rel_show_in_category(args, format)
        end
        if next(AllStuff:UI_split_ids(args)) then
            return AllStuff:Rel_show_range(args, format)
        end
        return AllStuff:Rel_search(args)
end)

AllStuff:cmd_register("rel.details", 
function(args)
    return AllStuff:Rel_show_range(args, "detail")
end)

--for k,v in pairs(AllStuff) do
--    print(string.format("---@field %s %s", k, type(v)))
--end

---@class AllStuff
---@field Item_move_id function
---@field Category_rebuild_node function
---@field Category_get_node function
---@field Item_add function
---@field UI_render function
---@field Rel_move function
---@field Category_create function
---@field Category_delete_node function
---@field Journal_compact function
---@field Rel_show_details function
---@field Journal_append function
---@field Category_split_path function
---@field UI_get_tree_paths function
---@field Category_get_subcat function
---@field Rel_show_range function
---@field UI_render_tree function
---@field Rel_add function
---@field Item_search function
---@field Category_process_path function
---@field Category_serialize function
---@field _category_tree table
---@field Category_get_no_subcat function
---@field Rel_show_newer_than function
---@field Rel_show_in_category function
---@field Journal_append_add function
---@field Category_rename function
---@field Item_delete function
---@field Rel_del function
---@field UI_tree_from_ids function
---@field Category_init function
---@field Rel_rename_category function
---@field Journal_append_del function
---@field Rel_show_category_details function
---@field Rel_search function
---@field Rel_show_new function
---@field Category_delete function
---@field UI_split_ids function
---@field Journal_append_move function
---@field _data table
---@field Category_mark_parents_dirty function
---@field Item_init function
---@field Item_get_newer_than function
---@field Item_validate_title function
---@field _category_index table
---@field Journal_replay function