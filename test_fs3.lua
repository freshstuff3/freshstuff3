-- test_category_delete.lua
-- Test suite for category deletion with lazy rebuild

local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
package.path = package.path .. string.format(";%s?.lua", base_path)
-- test_category_delete.lua
-- Test suite for category deletion with lazy rebuild

local Instance = require "core.instance"
local AllStuff = Instance:new()

-- Also need Item for direct access
local Item = require "core.item"

-- ---- HELPER: Dummy data generator ----
function generate_dummy_data()
    local dummy_releases = {
        { category = "Movies", title = "Classic Collection", nick = "user1" },
        { category = "Movies/Horror", title = "The Cabin In The Woods", nick = "user2" },
        { category = "Movies/Horror", title = "Friday Night Massacre", nick = "user3" },
        { category = "Movies/Horror", title = "Poltergeist", nick = "user4" },
        { category = "Movies/Sci-Fi", title = "Interstellar Voyage", nick = "user5" },
        { category = "Movies/Sci-Fi", title = "The Android's Dream", nick = "user6" },
        { category = "Music", title = "Classic Collection", nick = "user7" },
        { category = "Music/Classical", title = "Beethoven's 9th", nick = "user8" },
        { category = "Music/Classical/Romantic", title = "Nocturnes", nick = "user9" },
        { category = "Music/Jazz", title = "Midnight Sax", nick = "user10" },
        { category = "Music/Jazz", title = "Blue Note Sessions", nick = "user11" },
        { category = "Music/Metal", title = "Symphony of Destruction", nick = "user12" },
        { category = "Music/Metal/Death", title = "Grave Digger", nick = "user13" },
        { category = "Music/Metal/Death", title = "Crimson Eclipse", nick = "user14" },
        { category = "Music/Metal/Death", title = "Bone Crusher", nick = "user15" },
        { category = "Music/Metal/Symphonic", title = "Symphony of the Night", nick = "user16" },
        { category = "Music/Rock", title = "Electric Storm", nick = "user17" },
        { category = "Music/Rock/Classic", title = "Golden Era", nick = "user18" },
        { category = "TV", title = "Complete Series", nick = "user19" },
        { category = "TV/Animation", title = "The Animated Series", nick = "user20" },
        { category = "TV/Animation", title = "Epic Ninja Saga", nick = "user21" },
        { category = "TV/Documentary", title = "Planet Earth", nick = "user22" },
    }
    
    -- We need to create categories first
    for _, rel in ipairs(dummy_releases) do
        AllStuff:Category_create(rel.category)
    end
    
    -- Then add items
    for _, rel in ipairs(dummy_releases) do
        rel.when = os.time()
        AllStuff:Item_add(rel, "test_journal.journal")
    end
end

-- ---- HELPER: Print test results ----
function print_test_result(name, passed, details)
    print(string.rep("=", 60))
    print(string.format("TEST: %s", name))
    print(string.rep("-", 60))
    if passed then
        print("✅ PASSED")
    else
        print("❌ FAILED")
    end
    if details then
        print(string.rep("-", 40))
        print(details)
    end
    print(string.rep("=", 60))
    print()
end

-- ---- TEST 1: Verify categories exist ----
function test_categories_exist()
    local count = 0
    for _ in pairs(AllStuff._category_index) do
        count = count + 1
    end
    local passed = count > 0
    local details = "Categories found: " .. count
    print_test_result("Categories Exist", passed, details)
end

-- ---- TEST 2: Count total releases ----
function test_total_releases()
    local count = #AllStuff._data
    local expected = 22
    local passed = count == expected
    print_test_result("Total Releases", passed, string.format("Expected: %d, Got: %d", expected, count))
end

-- ---- TEST 3: Get items in TV category (including subcategories) ----
function test_tv_category_items()
    local ids = AllStuff:Category_get_subcat("TV")
    local count = #ids
    local expected = 4
    local passed = count == expected
    local details = string.format("Expected: %d, Got: %d", expected, count)
    print_test_result("TV Category Items (with subcats)", passed, details)
end

-- ---- TEST 4: Get items in Music/Metal/Death category ----
function test_metal_death_items()
    local ids = AllStuff:Category_get_subcat("Music/Metal/Death")
    local count = #ids
    local expected = 3
    local passed = count == expected
    local details = string.format("Expected: %d, Got: %d", expected, count)
    print_test_result("Music/Metal/Death Items", passed, details)
end

-- ---- TEST 5: Preview deletion of TV category ----
function test_preview_tv_deletion()
    local ids, cats = AllStuff:Category_delete("TV", "test_categories.dat", "test_journal.journal", true, true, true)
    local passed = ids and type(ids) == "table" and #ids == 4
    local details = "Items to delete: " .. (type(ids) == "table" and #ids or 0)
    print_test_result("Preview TV Deletion", passed, details)
end

-- ---- TEST 6: Verify TV still exists after preview ----
function test_tv_exists_after_preview()
    local exists = AllStuff._category_index["TV"] ~= nil
    local passed = exists == true
    print_test_result("TV Still Exists After Preview", passed, "TV category exists: " .. tostring(exists))
end

-- ---- TEST 7: Actual deletion of TV category ----
function test_delete_tv()
    local ids, result = AllStuff:Category_delete("TV", "test_categories.dat", "test_journal.journal", true, true, false)
    local passed = ids and type(ids) == "table" and #ids == 4
    local details = "Deleted " .. (type(ids) == "table" and #ids or 0) .. " items"
    print_test_result("Delete TV Category", passed, details)
end

-- ---- TEST 8: Verify TV is gone ----
function test_tv_is_gone()
    local exists = AllStuff._category_index["TV"] ~= nil
    local passed = exists == false
    print_test_result("TV is Gone", passed, "TV category exists: " .. tostring(exists))
end

-- ---- TEST 9: Verify total releases after deletion ----
function test_total_after_deletion()
    local count = #AllStuff._data
    local expected = 18  -- 22 - 4
    local passed = count == expected
    print_test_result("Total After Deletion", passed, string.format("Expected: %d, Got: %d", expected, count))
end

-- ---- TEST 10: Preview deletion of Music/Metal (nuke) ----
function test_preview_metal_nuke()
    local ids, cats = AllStuff:Category_delete("Music/Metal", "test_categories.dat", "test_journal.journal", true, true, true)
    -- Music/Metal has 5 direct items (12,13,14,15,16) + 3 from Death (13,14,15) + 1 from Symphonic (16)
    -- Unique items: 12, 13, 14, 15, 16 = 5 items total (since 13,14,15,16 are shared with subcategories)
    local expected = 5  -- Unique items in Music/Metal
    local passed = ids and type(ids) == "table" and #ids == expected
    local details = "Items to delete: " .. (type(ids) == "table" and #ids or 0) .. " (expected: " .. expected .. ")"
    print_test_result("Preview Music/Metal Nuke", passed, details)
end

-- ---- TEST 11: Dirty flag check ----
function test_dirty_flag()
    AllStuff._category_index["Music/Jazz"].dirty = true
    local dirty = AllStuff._category_index["Music/Jazz"].dirty
    local passed = dirty == true
    print_test_result("Dirty Flag Set", passed, "Music/Jazz dirty: " .. tostring(dirty))
end

-- ---- TEST 12: Rebuild dirty category ----
function test_rebuild_dirty()
    local node = AllStuff:Category_rebuild_node("Music/Jazz")
    local passed = node ~= nil and type(node._releases) == "table"
    local details = string.format("Node found: %s, Releases: %d", 
        node and "yes" or "no", 
        node and #node._releases or 0
    )
    print_test_result("Rebuild Dirty Category", passed, details)
end

-- ---- TEST 13: Force deletion of non-empty category without force ----
function test_force_without_force()
    local ids, result = AllStuff:Category_delete("Music/Rock", "test_categories.dat", "test_journal.journal", false, false, true)
    local passed = ids == false and type(result) == "string"
    print_test_result("Force Without Force (Should Fail)", passed, "Result: " .. tostring(result))
end

-- ---- TEST 14: Force deletion with force enabled ----
function test_force_with_force()
    -- Use Music/Jazz which has no subcategories
    local ids, result = AllStuff:Category_delete("Music/Jazz", "test_categories.dat", "test_journal.journal", true, false, false)
    local passed = type(ids) == "table" and #ids == 2  -- Music/Jazz has IDs 10 and 11
    local details = "Deleted " .. (type(ids) == "table" and #ids or 0) .. " items"
    if type(ids) == "string" then
        details = "Error: " .. ids
    end
    print_test_result("Force With Force", passed, details)
end


-- ---- TEST 15: Final state verification ----
function test_final_state()
    local total = #AllStuff._data
    local categories = {}
    for cat in pairs(AllStuff._category_index) do
        table.insert(categories, cat)
    end
    table.sort(categories)
    print_test_result("Final State", true, 
        string.format("Total releases: %d\nCategories: %s", 
            total, 
            table.concat(categories, ", ")
        )
    )
end

-- ---- RUN ALL TESTS ----
function run_all_tests()
    print()
    print("🔬 FreshStuff3 Category Deletion Test Suite")
    print(string.rep("=", 60))
    print()
    
    -- Setup
    print("📦 Generating dummy data...")
    generate_dummy_data()
    print("✅ Dummy data generated\n")
    
    -- Run tests
    test_categories_exist()
    test_total_releases()
    test_tv_category_items()
    test_metal_death_items()
    test_preview_tv_deletion()
    test_tv_exists_after_preview()
    test_delete_tv()
    test_tv_is_gone()
    test_total_after_deletion()
    test_preview_metal_nuke()
    test_dirty_flag()
    test_rebuild_dirty()
    test_force_without_force()
    test_force_with_force()
    test_final_state()
    
    print(string.rep("=", 60))
    print("✅ All tests completed!")
    print(string.rep("=", 60))
end

-- ---- RUN ----
run_all_tests()