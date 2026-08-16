-- freshstuff3.lua
-- Entry point for freshstuff3
base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
package.path = package.path .. string.format(";%s?.lua", base_path)
-- ============================================================================


-- Load AllStuff
require "plugins.release"


--- 5.1 compatibility wrapper
if not table.move then
    function table.move(src, src_start, src_end, dst_start, dst)
        dst = dst or src
        local offset = dst_start - src_start
        for i = src_start, src_end do
            dst[i + offset] = src[i]
        end
        return dst
    end
end


--print "\r\n\r\nLIST OF CATEGORIES:"
--local c = 1
--for cat, _ in pairs (AllStuff._category_index) do
--    print (c, cat)
--    c = c + 1
--end
--[[
local all = {}
for i in ipairs(AllStuff._data) do
    table.insert (all, i)
end

--local tree = AllStuff:UI_tree_from_ids(all, Item)
--print(string.format( "\r\n\r\nALL THE STUFF (%d)\r\n\r\n", #Item._data))
--print(table.concat(UI:render_tree(tree, Item), "\r\n"))

local list = {}


--print(AllStuff:show_range("1-88", "detail", _))
--print(AllStuff:show_range("1-88"))
print(AllStuff:Rel_show_newer_than("1000d"))

]]

--print(AllStuff:Rel_show_new(11, "md"))

--print(AllStuff:Rel_del_category_drill("TV", true, true))
-- print(AllStuff:Rel_show_category_tree())
-- print(AllStuff:Rel_del_category("Music", TEST_CATEGORY, JOURNAL_FILE, true, true, false))
--[[
local ids = AllStuff:Category_get_subcat("TV")
print("TV subcat IDs:", table.concat(ids, ", "))


print("=== Debug Category_init ===")
for id, piece in ipairs(AllStuff._data) do
    print("Release", id, piece.category)
    local node = AllStuff:Category_get_node(piece.category)
    if node then
        print("  Node found, releases:", table.concat(node._releases or {}, ", "))
    else
        print("  Node NOT found!")
    end
end



print("=== Testing Category_get_subcat ===")
local tv_ids = AllStuff:Category_get_subcat("TV")
print("TV IDs:", table.concat(tv_ids, ", "), "Count:", #tv_ids)

print("\n=== Testing Category_delete (preview) ===")
local ids, cats = AllStuff:Category_delete("TV", "test_categories.dat", "test_journal.journal", true, true, true)
print("Items to delete:", #ids or 0)
print("Categories to delete:", table.concat(cats or {}, ", "))

print("\n=== Testing Category_delete (actual) ===")
local result, msg = AllStuff:Category_delete("TV", "test_categories.dat", "test_journal.journal", true, true, false)
if type(result) == "table" then
    print("Deleted items:", #result)
else
    print("Error:", msg)
end

print("\n=== Verify deletion ===")
print("TV exists:", AllStuff._category_index["TV"] ~= nil)
print("Total releases:", #AllStuff._data)

--print(AllStuff:Rel_search("phoenix") )

--print(AllStuff:Category_delete_drill("Music", TEST_CATEGORY, true, true))

--print(AllStuff:Rel_move({1, 4}, "Music/Rock", JOURNAL_FILE))
]]

AllStuff:Lua_OpenShell()