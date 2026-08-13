-- core/release.lua
---@todo search
---@todo instead of return, it shoud send message, needs hostapp module first -- no, command wraps
---@todo COMMAND-LINE OUTPUT OPTIONS
--- - [ ] Implement --md switch: output markdown instead of ASCII tree
--- - [ ] Implement sorting switches for markdown output:
---       --sn : sort by nick (ascending)
---       --sw : sort by submission time (ascending)
---       --st : sort by title (ascending)
---       --rsn: reverse sort by nick (descending)
---       --rsw: reverse sort by time (descending)
---       --rst: reverse sort by title (descending)
---       --r  : reverse by ID
--- - [ ] Default sort: by ID (natural order) when no sort specified
--- - [ ] Sorting should only affect markdown output (tree stays hierarchical)
--- - [ ] Consider: sort by category + title for grouped markdown output
--- - [ ] Consider: --sort=field syntax as alternative to separate switches
---
---@example
---   freshstuff3 --category "Music" --md --st    → markdown sorted by title
---   freshstuff3 --latest 20 --md --rsw          → markdown, newest first
---   freshstuff3 --search "jazz" --md --sn       → markdown sorted by nick
---@todo also implement --force switch for non-emtpy category deletion
---@todo for getting info, !rel.getinfo 1 | !rel.getinfo 3,9,6,11 | !rel.getinfo 1-6
---this also adds some kind of pagination support

--- Search and display results (business logic)
---@param query string Search term
---@param source_of_truth table source_of_truth to use
---@return string result Formatted output
---@todo Implement: call Search:all(query, source_of_truth)
---@todo Implement: use UI:tree_from_ids(results, source_of_truth)
---@todo Implement: return formatted tree or "No results"

--- Show category details with count
---@param path string Category path
---@param source_of_truth table source_of_truth to use
---@return string result Formatted output
---@todo Implement: get category count
---@todo Implement: get subcategory count
---@todo Implement: show category info with release count

--- Show release details
---@param id number Release ID
---@param source_of_truth table source_of_truth to use
---@return string result Formatted output
---@todo Implement: get release from source_of_truth._data[id]
---@todo Implement: format: ID, Title, Category, Nick, Date
---@todo Implement: return "Release not found" if missing

---@class AllStuff
local AllStuff = {}

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
---
---@param number integer Number of items to show (or "all" to show everything)
---@param source_of_truth table Namespace containing _data (e.g., Item, Request)
---@return string result Formatted tree with header indicating "LATEST N" or "ALL ITEMS"
---@todo If number is "all" or "everything", show all items
---@todo If number is negative, show error message
---@todo If number exceeds total, show all items with note: "Showing all N items"
---@todo Consider adding pagination for large results (e.g., !new 50 --page 2)
---@todo Add timestamp range filter: !new 20 --since 2024-01-15
---@todo Add category filter: !new 20 --category Music/Metal
---@todo Support output formats: tree, markdown, plain list (configurable)

function AllStuff:show_new(number, source_of_truth)
    assert (number ~= nil and source_of_truth ~= nil, "Number or source_of_truth "..
                                                    "not specified!")
    local ret = ""
    local UI = require "core.ui"

    local smallest = math.max(1, #source_of_truth._data - number)
    local ids = {}
    local x = 1
    for i = #source_of_truth._data, smallest, -1 do
        table.insert(ids,i)
    end
    local what
    if number >= #source_of_truth._data then
        ret = ret..string.format("\r\n\r\nALL THE ITEMS ( TOTAL: %d )\r\n\r\n"
        , #source_of_truth._data
        )
    else
        ret = ret..string.format("\r\n\r\nLATEST %d ITEMS\r\n\r\n", #ids)
    end
    local tree = UI:tree_from_ids(ids, source_of_truth)
    ret = ret..table.concat(UI:render_tree(tree, source_of_truth), "\r\n")
    return (ret == "" and "No results" or ret) 
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
---@param source_of_truth table Namespace containing _data (e.g., Item, Request)
---@return string result Formatted tree showing releases grouped by category
---@todo If path is empty, show all categories (tree root) or fallback to latest
---@todo If path is just "/", treat as root (show all categories)
---@todo Add support for wildcard patterns: e.g., "Music/*" (experimental)
---@todo Add option to exclude subcategories: e.g., "Music/Metal --no-subcats"
---@todo Add count summary at top: "Music/Metal (15 releases, 3 subcategories)"
---@todo Consider pagination for large categories (>50 releases)
---@todo Add output format options: tree, flat list, markdown table
---@todo Detect and handle circular category references (prevent infinite loops)
---@todo Cache category lookups for performance in large data sets
function AllStuff:show_category(path, source_of_truth)
    local ret = ""
    local Category = require "core.category"
    local UI = require "core.ui"
    local ids = Category:get_subcat(path, source_of_truth)
    if #ids > 0 then
        local tree = UI:tree_from_ids(ids, source_of_truth)
        ret = ret..table.concat(UI:render_tree(tree, source_of_truth), "\r\n")
    end
    return (ret == "" and "No results" or ret)
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
---@param source_of_truth table Namespace containing _data (e.g., Item, Request)
---@return string result Formatted tree or "No results"
---@todo If timeframe is empty or invalid, fallback to default (e.g., "7d")
---@todo If timeframe is "all" or "ever", show all releases (with pagination)
---@todo Consider adding "hour" support for very recent releases (e.g., "12h")
---@todo Add support for "since <date>" format (e.g., "since 2024-01-15")
function AllStuff:show_newer_than(time_window, source_of_truth)
    local UI = require "core.ui"
    local ids = UI:get_newer_than(time_window, source_of_truth)
    if #ids == 0 then
        return "No results"
    end
    local tree = UI:tree_from_ids(ids, source_of_truth)
    --tree = UI:clean_tree_array(tree)
    local lines = UI:render_tree(tree, source_of_truth)
    if not lines or #lines == 0 then
        return "No results"
    end
    return table.concat(lines, "\r\n")
end

return AllStuff