local Bus = {}
--- # BUSINESS LOGIC FOR FRESHSTUFF3
--- 
--- ## Search and display results (business logic)
--- 
--- ### Usage:
--- 
--- - `!rel.search` -- Search for a string. Checks nicks and titles, as well as categories.
--- 
---@param query string Search term
---@param format string "tree", "md" etc
---@param sort_order string Sort order
---@return string result Formatted output

function Bus:Bus_search(query, format, sort_order) 
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

--- ## Delete category
--- 
--- ### Usage:
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
function Bus:Bus_del_category(path, category_file, journal_file, is_force, is_nuke, is_preview)
    is_preview = (is_preview == nil) and true or is_preview
    
    if is_preview then
        local ok, msg = self:Bus_del_category_drill(path, is_force, is_nuke)
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
function Bus:Bus_del_category_drill(path, is_force, is_nuke)
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
function Bus:Bus_show_category_tree(path)
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
function Bus:Bus_show_details(ids, format, sort_order)
    if type(ids) == "number" then
        ids = { ids }
    end
    if type(ids) ~= "table" then
        return "Invalid ID format"
    end
    return self:UI_render(ids, format, sort_order) or "invalid sort order"
end

--- Get IDs for items newer than a specified timeframe
--- 
--- Time format: <number><unit> where unit is:
---   - d: days (e.g., 7d = 7 days)
---   - w: weeks (e.g., 2w = 14 days)
---   - m: months (e.g., 3m = 90 days)
--- 
--- Special shortcuts:
---   - "today"    : Start of today (00:00:00)
---   - "yesterday": Start of yesterday (00:00:00)
--- 
--- @param param string Timeframe (e.g., "5d", "2w", "1m", "today", "yesterday")
--- @return table|false ids Array of release IDs newer than the cutoff
--- or false on invalid string
--- 
function Bus:Bus_create_category(path)
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
function Bus:Bus_rename_category(old_path, new_path, format, sort_order)
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
function Bus:Bus_add(nick, title, path)
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
function Bus:Bus_del(ids) -- todo: create backup
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

function Bus:Bus_move(ids, new_path, journal_file)
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
function Bus:Bus_show_new(number, format, sort_order)
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
function Bus:Bus_show_in_category(path, format, sort_order)
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

--- ## Show a range of releases
--- 
--- ### Usage
--- - `!rel.show 1,2,3,4`
--- - `!rel.show 3-19`
--- - Spaces allowed, so is reverse or random order. 
--- - Will return results in order of IDs entered.
--- 
---@param str string String to be processed.
---@param format? string "tree", "md" etc. Falls back to "tree".
---@param sort_order? string  Sort order
function Bus:Bus_show_range(str, format, sort_order)
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
---@param time_window string  timeframe string 
---         e.g., "5d", "3w", "1m", "today", "yesterday"
---@param format? "tree"|"md"|"detail" format to be used
---@param sort_order? string sorting order
---     
---@return string|false result Result of the operation
--- - formatted tree
--- or
--- -  "No results" or false if invalid format
---@todo : 
---    - If timeframe is empty or invalid, fallback to default (e.g., "7d")

function Bus:Bus_show_newer_than(time_window, format, sort_order)
    time_window = time_window:lower()
    format = format or "tree"
    
    local conversion = {
        ["today"] = "0d",
        ["yesterday"] = "1d"
    }
    time_window = conversion[time_window] or time_window
    
    local number, mult = time_window:match("^(%d+)([dwm])$")
    if not (number and mult) or number == "" or mult == "" then 
        return "Invalid time format. Use: <number>d, <number>w, <number>m, today, yesterday"
    end
    
    number = tonumber(number)
    local multiplier = { d = 24*3600, w = 7*24*3600, m = 30*24*3600 }
    local seconds = number * multiplier[mult]
    local cutoff
    
    if number == 0 and mult == "d" then
        local now = os.time()
        local today_start = os.time({
            year = os.date("%Y", now),
            month = os.date("%m", now),
            day = os.date("%d", now),
            hour = 0,
            min = 0,
            sec = 0
        })
        cutoff = today_start
    else
        cutoff = os.time() - seconds
    end
    
    local ids = {}
    for id, obj in ipairs(self._data) do
        if obj.when >= cutoff then
            table.insert(ids, id)
        end
    end
    
    if #ids == 0 then
        return "No results"
    end
    
    return self:UI_render(ids, format, sort_order)
end

-- core/business.lua
-- Business logic orchestrates core operations and fires events
---@note AI stuff

    --- Delete releases (business level)
function Bus:Bus_delete_releases(ids, journal_file, fire_events)
    -- fire_events defaults to true
    if fire_events == nil then fire_events = true end
        
    if type(ids) == "number" then
        ids = { ids }
    end
        
    if #ids == 0 then
        return false, "No IDs specified"
    end
        
    -- Collect items first (before any deletion)
    local items = {}
    local missing = {}
        
    for _, id in ipairs(ids) do
        if self._data[id] then
            table.insert(items, {
                id = id,
                item = self._data[id],
                category = self._data[id].category,
                title = self._data[id].title,
                nick = self._data[id].nick,
                when = self._data[id].when,
            })
        else
            table.insert(missing, id)
        end
    end
        
    if #items == 0 then
        return false, "No valid items found"
    end
        
    -- ============================================================
    -- FIRE PRE-DELETE EVENTS (if enabled)
    -- ============================================================
    if fire_events then
        local pre_data = {
            ids = ids,
            items = items,
            count = #items,
            missing = missing,
        }
            
        local result = self:Event_fire("ItemsPreDelete", pre_data)
            
        if result.cancelled then
            return false, string.format("Deletion cancelled: %s", 
                result.cancel_reason or "Unknown")
        end
    end
        
    -- ============================================================
    -- PERFORM DELETION (call core)
    -- ============================================================
    local deleted_items = {}
    local errors = {}
        
    for _, item_info in ipairs(items) do
        local id = item_info.id
        local success, deleted = self:Item_delete(id, journal_file)
            
        if success then
            table.insert(deleted_items, deleted)
        else
            table.insert(errors, string.format("ID %d: %s", id, deleted))
        end
    end
        
    -- ============================================================
    -- FIRE POST-DELETE EVENTS (if enabled)
    -- ============================================================
    if fire_events and #deleted_items > 0 then
        local post_data = {
            ids = ids,
            items = deleted_items,
            count = #deleted_items,
            missing = missing,
            errors = errors,
        }
            
        self:Event_fire("ItemsPostDelete", post_data)
    end
        
    if #errors > 0 then
        return true, string.format("Deleted %d items, %d errors", 
            #deleted_items, #errors)
    end
        
    return true, string.format("Deleted %d items", #deleted_items)
end


--- Delete category (business level with its own events)
function Bus:Bus_delete_category(path, category_file, journal_file, is_force, is_nuke, is_preview)
    -- ============================================================
    -- COLLECT EVERYTHING FIRST
    -- ============================================================
    local state = self._category_index[path]
    if not state then
        return false, string.format("Category %s does not exist!", path)
    end
        
    -- Get the node
    local node = self:Category_rebuild_node(path)
    if not node then
        return false, string.format("Error retrieving node for category path %s", path)
    end
        
    -- Collect all items in this category and subcategories
    local all_ids = self:Category_get_subcat(path)
    local items_to_delete = {}
        
    for _, id in ipairs(all_ids) do
        if self._data[id] then
            table.insert(items_to_delete, {
                id = id,
                item = self._data[id],
                category = self._data[id].category,
                title = self._data[id].title,
                nick = self._data[id].nick,
                when = self._data[id].when,
            })
        end
    end
        
    -- Check for subcategories
    local cats_to_delete = { path }
    local function collect_subcats(current_node, current_path)
        for name, child in pairs(current_node) do
            if name ~= "_releases" then
                local full_path = current_path .. "/" .. name
                table.insert(cats_to_delete, full_path)
                collect_subcats(child, full_path)
            end
        end
    end
    collect_subcats(node, path)
        
    -- ============================================================
    -- VALIDATE
    -- ============================================================
    local has_subcats = #cats_to_delete > 1
        
    if has_subcats and not is_nuke then
        return false, string.format(
            "❌ Category %s has subcategories. Use --nuke to delete recursively.", path
        )
    end
        
    if #items_to_delete > 0 and not is_force and not is_nuke then
        return false, string.format(
            "❌ Category %s has %d releases. Use --force to delete with releases.", 
            path, #items_to_delete
        )
    end
        
    -- ============================================================
    -- PRE-DELETE EVENT (Category-specific)
    -- ============================================================
    if not is_preview then
        local pre_data = {
            path = path,
            categories = cats_to_delete,
            category_count = #cats_to_delete,
            items = items_to_delete,
            item_count = #items_to_delete,
            is_force = is_force,
            is_nuke = is_nuke,
        }
            
    local result = self:Event_fire("CategoryPreDelete", pre_data)
            
        if result.cancelled then
            return false, string.format("Deletion cancelled: %s", 
                result.cancel_reason or "Unknown")
        end
    end
        
    -- ============================================================
    -- PERFORM DELETION
    -- ============================================================
    if is_preview then
        -- Preview mode: just return what would be deleted
        return items_to_delete, cats_to_delete
    end
        
    -- Delete items from _data (using core item deletion)
    local deleted_items = {}
    local errors = {}
        
    for _, item_info in ipairs(items_to_delete) do
        local success, deleted = self:Item_delete(item_info.id, journal_file)
        if success then
            table.insert(deleted_items, deleted)
        else
            table.insert(errors, string.format("ID %d: %s", item_info.id, deleted))
        end
    end
        
    -- Delete categories from tree (bottom-up)
    table.sort(cats_to_delete, function(a, b)
        local depth_a = #self:Category_split_path(a)
        local depth_b = #self:Category_split_path(b)
         return depth_a > depth_b
    end)
        
    for _, cat_path in ipairs(cats_to_delete) do
        self._category_index[cat_path] = nil
        self:Category_delete_node(cat_path)
    end
        
    -- Serialize
    self:Category_serialize(category_file)
        
    --- ============================================================
    --- POST-DELETE EVENT (Category-specific)
    --- ============================================================
    local post_data = {
        path = path,
        categories = cats_to_delete,
        category_count = #cats_to_delete,
        items = deleted_items,
        item_count = #deleted_items,
        is_force = is_force,
        is_nuke = is_nuke,
        errors = errors,
    }
        
    self:Event_fire("CategoryPostDelete", post_data)
        
    if #errors > 0 then
        return true, string.format("Deleted category %s with %d items (%d errors)", 
            path, #deleted_items, #errors)
    end
        
    return true, string.format("Deleted category %s with %d items", path, #deleted_items)
end

    --- Move releases (business level)
function Bus:Bus_move_releases(ids, new_path, journal_file)
        if type(ids) == "number" then
            ids = { ids }
        end
        
        local results = {}
        local errors = {}
        
        for _, id in ipairs(ids) do
            local success, result = self:Item_move(id, new_path, journal_file)
            if success then
                table.insert(results, result)
            else
                table.insert(errors, result)
            end
        end
        
        -- Fire move event if any succeeded
        if #results > 0 then
            self:Event_fire("ItemsMoved", {
                ids = ids,
                results = results,
                errors = errors,
                new_path = new_path,
            })
        end
        
        return #errors == 0, { results = results, errors = errors }
    end

return Bus
