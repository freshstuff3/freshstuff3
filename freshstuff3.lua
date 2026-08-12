-- freshstuff3.lua

local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
package.path = package.path .. string.format(";%s?.lua", base_path)
JOURNAL_FILE = base_path.."data/journals/freshstuff3.lua"
TEST_CATEGORY = base_path.."data/test_category.lua"

Item = require "core.item"

local result, failed = Item:init(JOURNAL_FILE)

print("Item._category_index", Item._category_index or "not available yet")

print("result and failures",
     (#result ~= 0 and "SUCCESS\r\n") or "ERROR\r\n", 
     "failures",(#failed == 0 and "no failures\r\n") or
     table.concat(failed, "\r\n").."\r\n")

Item._data = result

print("total items", #Item._data) 
local Category = require "core.category"
local idx, tree = Category:init(TEST_CATEGORY, Item)
Item._category_index = idx
Item._category_tree = tree
print("Item._category_index", (Item._category_index ~= nil and "loaded successfully") or "failed to load category index")

print "\r\n\r\nLIST OF CATEGORIES:"
local c = 1
for cat, _ in pairs (Item._category_index) do
    print (c, cat)
    c = c + 1
end

local UI = require "core.ui"
local all = {}
for i = 1, #Item._data do
    table.insert (all, i)
end
--local tree = UI:tree_from_ids(all, Item)
--print(string.format( "\r\n\r\nALL THE STUFF (%d)\r\n\r\n", #Item._data))
--print(table.concat(UI:render_tree(tree, Item), "\r\n"))

local list = {}

for i = 1, 13 do
    table.insert(list,i)
end

local AllStuff = require "core.release"

--print(string.format("\r\n\r\nLATEST %d STUFF\r\n\r\n", #ids))
--local tree2 = UI:tree_from_ids(ids, Item)
--print(table.concat(UI:render_tree(tree2, Item), "\r\n"))
print(AllStuff:show_new(166, Item))
print(AllStuff:show_new(#Item._data, Item))
table.insert(list, 1293)
print(UI:render_markdown(all, Item))
print(UI:get_items_details(list, Item))