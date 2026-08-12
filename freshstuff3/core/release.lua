-- core/release.lua
---@todo search
---@todo reweite show_new to use ui full tree
---@todo instead of return, it shoud send message, needs hostapp module first

---@class AllStuff
local AllStuff = {}

--- GET NEW ITEMS
--- If number >= total no. of items, it interprets this as a 
--- request for all items and changes text accordingly
---@param number integer Number of items to show
---@param namespace table Namespace to be used.
---@return string result Returns the result 
function AllStuff:show_new(number, namespace)
    assert (number ~= nil and namespace ~= nil, "Number or namespace "..
                                                    "not specified!")
    local ret = ""
    local UI = require "core.ui"

    local smallest = math.max(1, #namespace._data - number)
    local ids = {}
    local x = 1
    for i = #namespace._data, smallest, -1 do
        table.insert(ids,i)
    end
    local what
    if number >= #namespace._data then
        ret = ret..string.format("\r\n\r\nALL THE ITEMS ( TOTAL: %d )\r\n\r\n"
        , #namespace._data
        )
    else
        ret = ret..string.format("\r\n\r\nLATEST %d ITEMS\r\n\r\n", #ids)
    end
    local tree = UI:tree_from_ids(ids, namespace)
    ret = ret..table.concat(UI:render_tree(tree, namespace), "\r\n")
    return (ret == "" and "No results" or ret) 
end

function AllStuff:show_category(path, namespace)
    local ret = ""
    local Category = require "core.category"
    local UI = require "core.ui"
    local ids = Category:get_subcat(path, namespace)
    if #ids > 0 then
        local tree = UI:tree_from_ids(ids, namespace)
        ret = ret..table.concat(UI:render_tree(tree, namespace), "\r\n")
    end
    return (ret == "" and "No results" or ret)
end

-- AllStuff uses UI internally
--[[
function AllStuff:show_newer_than(param, namespace)
local result = ""
    local UI = require "core.ui"
    local ids = UI:get_newer_than(param, namespace)
    if #ids > 0 then
        for _, id in ipairs(ids) do
            result = result.."\r\n"..namespace._data[id].title.." - "..id
        end
    end
    return result
end
]]
function AllStuff:show_newer_than(param, namespace)
    local UI = require "core.ui"
    local ids = UI:get_newer_than(param, namespace)
    if #ids == 0 then
        return "No results"
    end
    local tree = UI:tree_from_ids(ids, namespace)
    --tree = UI:clean_tree_array(tree)
    local lines = UI:render_tree(tree, namespace)
    if not lines or #lines == 0 then
        return "No results"
    end
    return table.concat(lines, "\r\n")
end

return AllStuff