-- core/release.lua
---@todo search
---@todo instead of return, it shoud send message, needs hostapp module first
---@todo result sorting in markdown if appropriate
---@todo COMMAND-LINE OUTPUT OPTIONS
--- - [ ] Implement --md switch: output markdown instead of ASCII tree
--- - [ ] Implement sorting switches for markdown output:
---       --sn : sort by nick (ascending)
---       --sw : sort by submission time (ascending)
---       --st : sort by title (ascending)
---       --rsn: reverse sort by nick (descending)
---       --rsw: reverse sort by time (descending)
---       --rst: reverse sort by title (descending)
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


-- core/release.lua
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
--- If number >= total no. of items, it interprets this as a 
--- request for all items and changes text accordingly
---@param number integer Number of items to show
---@param source_of_truth table source_of_truth to be used.
---@return string result Returns the result 
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
--- @param path string Category path
--- @param source_of_truth table source_of_truth to be used.
--- @return string result Returns formatted result
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

--- SHOW RELEASES NEWER THAN A CERTAIN TIMEFRAME
--- 
--- Usage: 1d, 3w, 30m etc. Accepts "today" and "yesterday"
--- @param param string today, yesterday, 5d, 6w, 1m etc
--- @param source_of_truth table source_of_truth to be used.
--- @return string result Returns formatted result
function AllStuff:show_newer_than(param, source_of_truth)
    local UI = require "core.ui"
    local ids = UI:get_newer_than(param, source_of_truth)
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