--- plugins/release/bus.lua
--[[
# BUSINESS LOGIC FOR FRESHSTUFF3

## CRU operations

Separate file for deletion

### Search

Default release retrieval command, !rel.get or !releases falls back to search if
there is no category match or parameter does not indicate ID (range). As a result,
it has no own command.
]]
 
local Event = require "helpers.event"
local Bus = {}
---@param query string Search term
---@param format string "tree", "md" etc
---@param sort_order string Sort order
---@return string result Formatted output
---
function Bus:Bus_search(query, format, sort_order)
    local result = {}
    
    -- UI handles ALL header formatting
    local header = self:UI_header_search(query, format or "tree", sort_order)
    table.insert(result, header)
    
    local rel, cat = self:Item_search(query)
    
    if #rel == 0 then
        if #cat ~= 0 then
            table.insert(result, "\r\n\r\n📁 CATEGORIES FOUND:")
            table.move(cat, 1, #cat, #result + 1, result)
        else
            table.insert(result, string.format("\r\nNo results for query %s", query))
        end
        return table.concat(result, "\r\n")
    end
    
    -- UI renders the actual content
    table.insert(result, self:UI_render(rel, format, sort_order))
    
    local footer = string.format("\r\nTotal items found: %d\r\nTotal categories found: %d", #rel, #cat)
    return table.concat(result, "\r\n") .. "\r\n" .. footer
end
--- Show category tree with count but not individual releases
--- 
--- Starts from root when path is nil or empty.
--- 
---@param path? string Category path
---@return string|boolean result Formatted output or false on error
---@return string|nil error Formatted output
---@todo Implement: get category count
---@todo Implement: get subcategory count
---@todo Implement: show category info with release count
--- Show category tree with count but not individual releases
--- 
function Bus:Bus_show_flat_tree(path)
    -- Business only validates and gets raw data
    if path then
        local p, ret = self:Category_process_path(path)
        if p then
            if not self._category_index[ret] then 
                return false, string.format("Category %s does not exist!", ret)
            end
            -- Get all categories under this path
            local categories = {}
            local prefix = ret .. "/"
            for cat, _ in pairs(self._category_index) do
               if cat == ret then
                    table.insert(categories, cat)
               elseif #cat > #prefix and cat:sub(1, #prefix) == prefix then
                    table.insert(categories, cat)
                end
            end
            -- UI handles ALL formatting
            return self:UI_render_flat_tree(categories, ret)
        else 
            return false, ret 
        end
    else
        -- Get all categories
        local categories = {}
        for cat, _ in pairs(self._category_index) do
            table.insert(categories, cat)
        end
        -- UI handles ALL formatting
        return self:UI_render_flat_tree(categories)
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
    ids = self:Item_normalize_ids(ids)
    if not ids or #ids == 0 then
        return "Invalid ID format"
    end
    return self:UI_render(ids, format, sort_order) or "invalid sort order"
end
--[[
Get IDs for items newer than a specified timeframe

Time format: <number><unit> where unit is:
  - d: days (e.g., 7d = 7 days)
  - w: weeks (e.g., 2w = 14 days)
  - m: months (e.g., 3m = 90 days)

Special shortcuts:
  - "today"    : Start of today (00:00:00)
  - "yesterday": Start of yesterday (00:00:00)
]]
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

---Add a release
---
---@param nick string
---@param title string
---@param path string
---@return boolean success True on success, false on error
---@return string result Formatted output on success, error message on failure
function Bus:Bus_add(nick, title, path)
    local x, result = self:Category_process_path(path)
    if not x then return false, result end
    local t, err = self:Item_validate_title(title)
    if not t then return false, err end
    local succ, res = self:Item_add({ 
        nick = nick,
        title = title,
        category = result,
        when = os.time()
    }, true)
    if succ then
        return true, self:UI_render(res, "detail")
    else
        return false, "Error adding release: " .. res
    end
end
---
--[[
GET NEW RELEASES

Displays the most recently added releases, up to the specified count.
Releases are shown in chronological order (newest last).

Behavior:
  - If number < total releases: Shows the latest N releases
  - If number >= total releases: Shows ALL releases with "ALL ITEMS" header
  - If number <= 0 or not provided: Shows default (e.g., 10)

The output is rendered as a hierarchical category tree, with releases
grouped under their respective categories.

Examples:
  !rel.show 5   - Shows the 5 most recent releases
  !rel.show 50  - Shows the 50 most recent releases
  !rel.show 999 - If there are 500 releases total, shows ALL releases
  !rel.show     - Shows default (configurable, e.g., 10)
  OPTIONAL SWITCHES:
      --sn : sort by nick (ascending)
      --sw : sort by submission time (ascending)
      --st : sort by title (ascending)
      --rsn: reverse sort by nick (descending)
      --rsw: reverse sort by time (descending)
      --rst: reverse sort by title (descending)
      --r  : reverse by ID
]]
--- @todo If number is "all" or "everything", show all items
--- @todo If number is negative, show error message
--- @todo If number exceeds total, show all items with note: "Showing all N items"
--- @todo Consider adding pagination for large results (e.g., !new 50 --page 2)
--- @todo Add timestamp range filter: !new 20 --since 2024-01-15
--- @todo Add category filter: !new 20 --category Music/Metal
--- @todo Support output formats: tree, markdown, plain list (configurable)
--- @param number integer Number of items to show (or "all" to show everything)
--- @param format? string Format to render in
--- @param sort_order? string Sorting order
--- @return string|false result Formatted tree with header indicating "LATEST N" or "ALL ITEMS"
function Bus:Bus_show_new(number, format, sort_order)
    format = format or "tree"
    
    -- Parse input
    if type(number) == "string" and number:lower() == "all" then
        number = 999999
    end
    number = tonumber(number) or 10
    if number <= 0 then number = number * -1 end

    local total = #self._data
    if total == 0 then
        return "📭 No releases found in the database."
    end
    
    -- Build IDs (business logic)
    local count = math.min(number, total)
    local ids = {}
    for i = 1, count do
        table.insert(ids, total - count + i)
    end
    
    -- UI handles header AND content
    local header = self:UI_header_latest(count, total, format, sort_order)
    return header .. self:UI_render(ids, format, sort_order)
end

---
--[[
SHOW RELEASES BY CATEGORY

Displays all releases belonging to a specific category, including
releases in all subcategories (recursive traversal).

Behavior:
  - If path exists and has releases: Shows full category tree for that path
  - If path exists but is empty: Returns "No results"
  - If path does not exist: Returns "No results"
  - If path is a parent category: Includes all subcategories (recursive)
  - If path is empty or nil: Shows all categories (falls back to "new" view)

The output preserves the full category hierarchy, making it easy to
see the structure of releases within the requested category.

Category path examples:
  "Music"          - Shows all Music releases (including subcategories)
  "Music/Metal"    - Shows only Metal releases (and its subcategories)
  "Movies/Horror"  - Shows Horror movies (and subgenres like Slasher, Giallo)
  "TV"             - Shows all TV releases
]]

--- @param path string Category path (e.g., "Music/Metal", "Movies/Horror")
--- @param format? string "tree", "md", "detail", defaults to "tree"
--- @param sort_order? string
--- @return string|false result Formatted tree showing releases grouped by category 
--- or false if category does not exist
--- @todo --no-subcat switch
function Bus:Bus_show_by_category(path, format, sort_order)
    format = format or "tree"
    
    -- Validate category (business logic)
    if self._category_index[path] == nil then 
        return "Non-existent category: " .. path 
    end
    
    -- Get IDs (business logic)
    local ids = self:Category_get_subcat(path)
    if not next(ids) then
        return "No releases found in category: " .. path
    end
    
    -- UI handles header AND content
    local header = self:UI_header_category(path, #ids, format, sort_order)
    return header .. self:UI_render(ids, format, sort_order) ..
        string.format("\r\n\r\nTotal items retrieved: %d", #ids)
end

--[[
## Show a range of releases

### Usage
- `!rel.show 1,2,3,4`
- `!rel.show 3-19`
- Spaces allowed, so is reverse or random order. 
- Will return results in order of IDs entered.
]]
---@param str string String to be processed.
---@param format? string "tree", "md" etc. Falls back to "tree".
---@param sort_order? string  Sort order
---
function Bus:Bus_show_range(str, format, sort_order)
    format = format or "tree"
    local result, ids
    
    -- Parse input (business logic)
    if tonumber(str) then
        -- Single ID -> show details
        result = self:UI_render({ tonumber(str) }, "detail", sort_order)
    else
        -- Parse range using UI helper (parsing, not formatting)
        ids = self:Bus_split_ids(str) or {}
        if not next(ids) then
            result = "Invalid parameter! Usage: id1,id2,id3 or id1-id2"
        else
            result = self:UI_render(ids, format, sort_order)
        end
    end
    
    -- UI handles header
    local header = self:UI_header_range(str, format, sort_order)
    result = header .. result
    return result .. string.format("\r\n\r\nTotal items retrieved: %d", #ids or 0)
end
---
--[[
Displays releases added within a specified time window.

Supports human-readable time formats and natural language shortcuts.

Time format: <number><unit> where unit is:
  - d: days (e.g., 7d = 7 days)
  - w: weeks (e.g., 2w = 14 days)
  - m: months (e.g., 3m = 90 days, approximated as 30 days/month)

Special shortcuts:
  - "today"   : Releases from today (00:00:00 onwards)
  - "yesterday": Releases from yesterday (00:00:00 to 23:59:59)
  - "week"    : Releases from the last 7 days (equivalent to "7d")
  - "month"   : Releases from the last 30 days (equivalent to "30d")

Examples:
  !rel.show 1d   - Releases from the last 24 hours
  !rel.show 3w   - Releases from the last 21 days
  !rel.show 1m   - Releases from the last 30 days
  !rel.show today - Releases added today
  !rel.show yesterday - Releases added yesterday
]]
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
--- 
function Bus:Bus_show_newer_than(time_window, format, sort_order)
    time_window = time_window:lower()
    format = format or "tree"
    
    -- Parse time window (business logic)
    local conversion = { today = "0d", yesterday = "1d" }
    time_window = conversion[time_window] or time_window
    
    local number, mult = time_window:match("^(%d+)([dwm])$")
    if not (number and mult) or number == "" or mult == "" then 
        return "Invalid time format. Use: <number>d, <number>w, <number>m, today, yesterday"
    end
    
    -- Calculate cutoff (business logic)
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
    
    -- Collect IDs (business logic)
    local ids = {}
    for id, obj in ipairs(self._data) do
        if obj.when >= cutoff then
            table.insert(ids, id)
        end
    end
    
    if #ids == 0 then
        return "No results"
    end
    
    -- UI handles header AND content
    local result = self:UI_render(ids, format, sort_order)
    local header = self:UI_header_newer(time_window, format, sort_order)
    result = header .. result
    return result .. string.format("\r\n\r\nTotal items retrieved: %d", #ids)
end

---
--[[ 
Split a comma-separated list of IDs or an ID range to a list of IDs.

Examples:
  "1,2,3"     → {1, 2, 3}
  "1-6"       → {1, 2, 3, 4, 5, 6}
  "5-1"       → {5, 4, 3, 2, 1} (reverse range)
]]
--- 
--- @param str string String to split (e.g., "1,2,3" or "1-6")
--- @return table|false result Array of IDs, or false on invalid string
function Bus:Bus_split_ids(str)
    if type(str) ~= "string" then
        return false
    end

    str = str:gsub("%s+", "")
    local result = {}
    -- ID list, comma-separated
    if str:find(",", 1, true) then
        for id in str:gmatch("([^,]+)") do
            if not id:match("^%d+$") then
                return false
            end
            table.insert(result, tonumber(id))
        end
        if #result < 2 then
            return false
        end
    -- ID range
    elseif str:match("^%d+%-%d+$") then
        local a, b = str:match("^(%d+)%-(%d+)$")
        a = tonumber(a); b = tonumber(b)
        local x = a > b and -1 or 1
        for i = a, b, x do
            table.insert(result, i)
        end 
    end
    local ids = self:Item_normalize_ids(result)
    return ids and #ids > 0 and ids or false
end

return Bus
