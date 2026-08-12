-- freshstuff3.lua
local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
package.path = package.path .. string.format(";%s?.lua", base_path)
JOURNAL_FILE = base_path.."data/journals/freshstuff3.lua"
TEST_CATEGORY = base_path.."data/test_category.lua"

Item = require "core.item"
Item:init()
print(#Item._data) 

local Category = require "core.category"
local Journal = require "core.journal"
--local test_journal = require("test_journal")



--- ============================================
--- DUMMY DATA FOR TESTING
--- ============================================
--- 
local base_time = os.time() - 86400 * 30  -- 30 days ago

if not Item._data or #Item._data == 0 then
    local base_time = os.time() - 86400 * 30  -- 30 days ago
end  
--- ============================================
--- DUMMY DATA FOR TESTING (with top-level items)
--- ============================================
if not Item._data or #Item._data == 0 then
    local base_time = os.time() - 86400 * 30  -- 30 days ago
    
    Item._data = {
        -- ===== TOP-LEVEL CATEGORIES (no slashes) =====
        -- Music (IDs 1-2)
        {
            category = "Music",
            nick = "MusicLover",
            title = "Greatest Hits Vol 1",
            when = base_time + 0,
        },
        {
            category = "Music",
            nick = "Audiophile",
            title = "Ambient Sounds",
            when = base_time + 3600,
        },
        -- Movies (ID 3)
        {
            category = "Movies",
            nick = "FilmBuff",
            title = "Classic Collection",
            when = base_time + 7200,
        },
        -- TV (ID 4)
        {
            category = "TV",
            nick = "BingeWatcher",
            title = "Complete Series",
            when = base_time + 10800,
        },
        
        -- ===== 2ND LEVEL CATEGORIES =====
        -- Music/Metal (IDs 5-6)
        {
            category = "Music/Metal",
            nick = "MetalHead",
            title = "Screaming Into The Void",
            when = base_time + 14400,
        },
        {
            category = "Music/Metal",
            nick = "ThrashLord",
            title = "Eternal Darkness",
            when = base_time + 18000,
        },
        -- Music/Jazz (IDs 7-8)
        {
            category = "Music/Jazz",
            nick = "JazzCat",
            title = "Midnight Sax",
            when = base_time + 21600,
        },
        {
            category = "Music/Jazz",
            nick = "SmoothOperator",
            title = "Blue Note Sessions",
            when = base_time + 25200,
        },
        -- Music/Classical (IDs 9-10)
        {
            category = "Music/Classical",
            nick = "Maestro",
            title = "Beethoven's 9th",
            when = base_time + 28800,
        },
        {
            category = "Music/Classical",
            nick = "PianoMan",
            title = "Moonlight Sonata",
            when = base_time + 32400,
        },
        -- Movies/Horror (IDs 11-12)
        {
            category = "Movies/Horror",
            nick = "HorrorFan",
            title = "The Cabin In The Woods",
            when = base_time + 36000,
        },
        {
            category = "Movies/Horror",
            nick = "SlasherGuy",
            title = "Friday Night Massacre",
            when = base_time + 39600,
        },
        -- Movies/Sci-Fi (IDs 13-14)
        {
            category = "Movies/Sci-Fi",
            nick = "SpaceCadet",
            title = "Interstellar Voyage",
            when = base_time + 43200,
        },
        {
            category = "Movies/Sci-Fi",
            nick = "RobotLover",
            title = "The Android's Dream",
            when = base_time + 46800,
        },
        -- TV/Animation (IDs 15-16)
        {
            category = "TV/Animation",
            nick = "CartoonFan",
            title = "The Animated Series",
            when = base_time + 50400,
        },
        {
            category = "TV/Animation",
            nick = "AnimeLover",
            title = "Epic Ninja Saga",
            when = base_time + 54000,
        },
        
        -- ===== 3RD LEVEL CATEGORIES =====
        -- Music/Metal/Death (IDs 17-18)
        {
            category = "Music/Metal/Death",
            nick = "DeathMetalFan",
            title = "Grave Digger",
            when = base_time + 57600,
        },
        {
            category = "Music/Metal/Death",
            nick = "GoreLord",
            title = "Crimson Eclipse",
            when = base_time + 61200,
        },
        -- Music/Metal/Symphonic (IDs 19-20)
        {
            category = "Music/Metal/Symphonic",
            nick = "OrchestraNerd",
            title = "Symphony of Destruction",
            when = base_time + 64800,
        },
        {
            category = "Music/Metal/Symphonic",
            nick = "EpicFan",
            title = "The Phoenix Rises",
            when = base_time + 68400,
        },
        -- Music/Classical/Romantic (IDs 21-22)
        {
            category = "Music/Classical/Romantic",
            nick = "RomanticSoul",
            title = "Liebesträume",
            when = base_time + 72000,
        },
        {
            category = "Music/Classical/Romantic",
            nick = "ChopinFan",
            title = "Nocturnes",
            when = base_time + 75600,
        },
    }
    
    print("[DEBUG] Loaded " .. #Item._data .. " dummy items")
    print("[DEBUG] Top-level categories: Music, Movies, TV")
end


local TEST_JOURNAL = "/home/szg/ptokax-config/scripts/freshstuff3/data/journals/test_journal.lua"
local TEST_CATEGORY = "/home/szg/ptokax-config/scripts/freshstuff3/data/test_category.lua"

-- ✅ Initialize categories from existing data FIRST
 Category:init(TEST_CATEGORY, Item)
print("[DEBUG] Contents of", TEST_CATEGORY, "before test:")
local f = io.open(TEST_CATEGORY, "r")
if f then
    for line in f:lines() do
        print("  " .. line)
    end
    f:close()
else
    print("  File does not exist")
end



-- Clean up old test journal
os.remove(TEST_JOURNAL)

print("\n[1] INITIAL STATE")
print("-" .. string.rep("-", 40))
print("Items before init:", #Item._data)
--print("Categories before init:", #Category:debug_category_count())
Journal:compact(TEST_JOURNAL, Item)

print("\n[2] INITIALIZE ITEM (loads from journal)")
print("-" .. string.rep("-", 40))
Item:init()
print("Items after init:", #Item._data)
--print("Categories after init:", #Category:debug_category_count())

print("\n[3] ADD ITEMS")
print("-" .. string.rep("-", 40))

-- Add some items with journaling
local items = {
    { category = "Music", nick = "user1", title = "Test Song 1", when = base_time + 0 },
    { category = "Music", nick = "user2", title = "Test Song 2", when = base_time + 100 },
    { category = "Music/Metal", nick = "user3", title = "Metal Song", when = base_time + 200 },
    { category = "Music/Jazz", nick = "user4", title = "Jazz Song", when = base_time + 300 },
    { category = "Movies", nick = "user5", title = "Test Movie", when = base_time + 400 },
}

for i, obj in ipairs(items) do
    local ok, err = Item:add(obj, TEST_JOURNAL)
    if ok then
        print(string.format("  Added item %d: %s -> %s", i, obj.category, obj.title))
    else
        print(string.format("  Failed to add item %d: %s", i, err))
    end
end

print("\nItems after add:", #Item._data)

print("\n[4] VERIFY CATEGORY TREE")
print("-" .. string.rep("-", 40))

-- Show tree structure
local function print_tree(node, indent)
    indent = indent or ""
    for key, value in pairs(node) do
        if key ~= "_releases" then
            local releases = value._releases or {}
            local release_str = #releases > 0 and " (" .. table.concat(releases, ",") .. ")" or ""
            print(indent .. key .. release_str)
            print_tree(value, indent .. "  ")
        end
    end
end

print("Category Tree:")
print_tree(Item._category_tree)

print("\n[5] CHECK CATEGORY RELEASES")
print("-" .. string.rep("-", 40))

local categories = {"Music", "Music/Metal", "Music/Jazz", "Movies"}
for _, cat in ipairs(categories) do
    local releases = Category:get_no_subcat(cat)
    local all = Category:get_subcat(cat)
    print(string.format("  %s: direct=%d, all=%d", cat, #releases, #all))
end

print("\n[6] TEST MOVE")
print("-" .. string.rep("-", 40))

-- Move item 3 (Metal Song) from Music/Metal to Music/Classical
print("Moving item 3 (Metal Song) from Music/Metal to Music/Classical")
local ok, err = Item:move_id(3, "Music/Classical", TEST_JOURNAL)
if ok then
    print("  Move successful")
else
    print("  Move failed:", err)
end

print("\nAfter move:")
for id, item in ipairs(Item._data) do
    print(string.format("  %d: %s -> %s", id, item.category, item.title))
end

print("\n[7] TEST DELETE")
print("-" .. string.rep("-", 40))

-- Delete item 5 (Test Movie)
print("Deleting item 5 (Test Movie)")
local ok, err = Item:delete(5, TEST_JOURNAL)
if ok then
    print("  Delete successful")
else
    print("  Delete failed:", err)
end

print("\nAfter delete:")
for id, item in ipairs(Item._data) do
    print(string.format("  %d: %s -> %s", id, item.category, item.title))
end

print("\n[8] CHECK DIRTY CATEGORIES")
print("-" .. string.rep("-", 40))

for path, entry in pairs(Item._category_index) do
    local state = entry.dirty == nil and "empty" or (entry.dirty and "dirty" or "clean")
    print(string.format("  %s: %s", path, state))
end

print("\n[9] REBUILD (force clean)")
print("-" .. string.rep("-", 40))

-- Trigger rebuild by querying a dirty category
Category:get_no_subcat("Music/Metal")
Category:get_no_subcat("Music/Classical")

print("After rebuild:")
for path, entry in pairs(Item._category_index) do
    local state = entry.dirty == nil and "empty" or (entry.dirty and "dirty" or "clean")
    print(string.format("  %s: %s", path, state))
end

print("\n[10] SIMULATE CRASH & RECOVERY")
print("-" .. string.rep("-", 40))

-- Save current state
print("Saving state...")
local saved_data = {}
for id, item in ipairs(Item._data) do
    saved_data[id] = item
end

-- Reset Item
print("Resetting Item (simulating crash)...")
Item._data = {}
Item._category_tree = {}
Item._category_index = {}

print("Items before replay:", #Item._data)

-- Replay journal
print("Replaying journal...")
local result, failed = Journal:replay(TEST_JOURNAL)
if result then
    Item._data = result
    Category:init(TEST_CATEGORY, Item)
    print("Items after replay:", #Item._data)
        print("[DEBUG] Categories after Category:init():")
    local count = 0
    for path, _ in pairs(Item._category_index) do
        print("  " .. path)
        count = count + 1
    end
    print("[DEBUG] Total categories:", count)
    -- Verify data matches saved state
    local match = true
    for id, item in ipairs(Item._data) do
        if not saved_data[id] or 
           saved_data[id].category ~= item.category or
           saved_data[id].title ~= item.title then
            match = false
            break
        end
    end
    if match then
        print("✓ Data matches saved state!")
    else
        print("✗ Data does NOT match saved state!")
    end
else
    print("Replay failed:", failed)
end

print("\n[11] FINAL STATE")
print("-" .. string.rep("-", 40))

print("Items:", #Item._data)
--print("Categories:", #Category:debug_category_count())

print("\nFinal Category Tree:")
print_tree(Item._category_tree)

print("\nFinal Category Index:")
for path, entry in pairs(Item._category_index) do
    local state = entry.dirty == nil and "empty" or (entry.dirty and "dirty" or "clean")
    print(string.format("  %s: %s", path, state))
end

print("\n[DEBUG] Categories before serialize:")
for path, _ in pairs(Item._category_index) do
    print("  " .. path)
end
print("\n[DEBUG] Categories before serialize (pairs):")
local count = 0
for path, _ in pairs(Item._category_index) do
    print("  " .. path)
    count = count + 1
end
print("[DEBUG] Count using pairs:", count)

-- Check if serialize is being called with a different Item
print("[DEBUG] Item reference:", Item)
print("[DEBUG] Item._category_index reference:", Item._category_index)

Journal:compact(TEST_JOURNAL, Item)
Category:serialize(TEST_CATEGORY, Item)

-- Check the file after serialize
print("[DEBUG] File contents after serialize:")
local f = io.open(TEST_CATEGORY, "r")
if f then
    for line in f:lines() do
        print("  " .. line)
    end
    f:close()
end
Journal:compact(TEST_JOURNAL, Item)
Category:init(TEST_CATEGORY, Item)

print("✅ Categories serialized to:", TEST_CATEGORY)

print("\n" .. "=" .. string.rep("=", 60))
print("TEST COMPLETE")
print("=" .. string.rep("=", 60))
