-- core/release.lua
---@class AllStuff
---@todo search
---@ todo 

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

    local finish = math.max(1, #namespace._data - number)
    local ids = {}
    local x = 1
    for i = #namespace._data, finish, -1 do
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

return AllStuff