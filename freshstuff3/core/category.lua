-- core/category.lua
-- TODO:
--    add category rebuild from AI
package.path = package.path .. ";/home/szg/ptokax-config/scripts/freshstuff3/?.lua"

-- local Item = Item or require "core.item"

local Category = {}
local CATEGORIES_FILE = "/home/szg/ptokax-config/scripts/freshstuff3/data/categories.lua"


function Category:init()
    local Item = Item or require "core.item"
    Item._category_index = {}
    Item._category_tree = {}
    for id, piece in Item._data do
        -- Not checking if exists. We are overwriting nothing.

        Item._category_index[piece.category] = { dirty = false }
        self:tree_add_id(piece.category, id)
    end
    for path, flag in Item._category_index do
        self:create (path)
    end
    end

--- Category validation
--- 
--- Not checking for spaces as it is detected as %S+ in input
--- 
--- This is a STRING validation, does not check for existence/emptiness
--- 
--- We don't even want to start manioulating categories without a valid path.
--- 
--- @param cat_str string - Category path x/z/y
--- @return boolean success Return true on success, false on error
--- @return string path_sanitized|error the sanitized path string on success, error message on error
function Category:process_path(path)
    -- check if path exists
    if not path or path == "" then
        return false, "Category path cannot be empty."
    end

    -- string longer than 70 chars
    -- This should be hardcoded as for messages, the display is the bottleneck
    if #path > 70 then 
        return false, string.format("Category path %s too long. "..
        "Maximum 70 characters.", path) 
    
    end

    -- Replace trailing and leading slashes, also multiple consecutive slashes
    path = path:gsub( "^/+", ""):gsub( "/+$", ""):gsub("//+", "/")

    if string.find (path, "/") then -- subcategory
        local depth = #self:split_path(path)
        if depth > 5 then 
            return false, string.format("Subcategory %s deeper than"..
                                            " five levels.", path)
         end
    end
    return true, path 
end

--- Split category path into parts
--- 
--- 
--- @param path string category path
--- @return table parts Returns an array of parts, ordered fromm top level downwards.
function Category:split_path(path)
    -- Check if top-level category
    print(path)
    if not path:find("/") then; return { path }; end
    -- Not-top-level category, split required
    local parts = {}
    for part in path:gmatch("([^/]+)") do
        table.insert(parts, part)
    end
    return parts
end

--- ---- SAVE CATEGORIES TO FILE ----
--- Lorem ipsum
--- 
--- 
--- @param filename string Table name to be used.
--- @param table_name string Name of table to be serialized
--- @param tbl table Table to be serialized that has _category_index.
--- @param category string category path
--- @return boolean success Journal success
--- @return string? err Error message in case of failure
function Category:serialize(filename, category)
    local Item = Item or require "core/item"
    filename = filename or "freshstuff3/data/category.dat"
    local f, err = io.open (filename, "w+")
    if f then
        f:write("data._category_index = {\n")  
        for path, val in pairs(Item._category_index) do
            local dirty = val.dirty
            if not val.dirty then dirty = "false" else dirty = "true" end
            f:write ("[\""..path.."\"] = { \""..dirty.."\" },\n")
        end
        f:write("}\n")
        f:flush()
        f:close()
        return true
    end
    return false, err -- serialization failed
end

--- TREE MASTER (BEHOLD)
--- Retrieve a node from the tree, add to it or delete from it.
--- Specify release ID as second argument to add to node (optional)
--- Specify a boolean as to whether this is a deletion (optional, need ID as well if used)
--- 
--- 
--- @param path string Category path Music/Classical/Baroque
--- @param id number Optional item
--- @param should_delete boolean Optional, whether this is a deletion
--- @param journal_path string Optional, file path if journaling needed
--- @return table target Returns the updated tree node containing the new item
function Category:tree_master(path, id, should_delete)
    local Item = Item or require "core.item"
    if not Item._category_index[path] then return false end
    if Item._category_index[path].dirty then
        os.clock()
        -- TODO: rebuild categoory
    end
    local nodes = self:split_path(path)
    -- This is a disgusting trick.
    -- We create Lua code from the path directly
    local parent, node
    if #nodes == 1 then 
        parent = "nil"
        node = "[\""..nodes[1].."\"]"
    else
        parent = table.concat(nodes, "\"][\"", 1, (#nodes - 1))
        node = "[\""..table.concat(nodes, "\"][\"").."\"]"
    end
    if #nodes == 1 then parent = "nil" end
    local cheat = string.format(
        "Item._category_tree%s.parent = %s; return "..
        "Item._category_tree%s", node,  parent, node
        )
    local todo; if not should_delete then 
        todo = table.insert 
    else 
        todo = table.remove 
    end

    local target
       -- Build the environment with needed variables
    local env = {
        Item = Item,
        table = table,
        -- Add any other dependencies here
    }

    print(cheat,"GHECC")
    local chunk = load(cheat, nil, "t", env)
    if chunk then target = chunk() end
    if target and id then todo (target, id) end
    return target
end

--- @param id number - Release ID to move
--- @param new_category string - New category
--- @param journal_path string - Optional, file path if journaling needed
--- @return 
function Category:move_id(id, new_category)    
   -- TODO: check if the old category will become empty after move -- nope, no purpose
    local Item = Item or require "core.item"
    Item._data[id].cat = new_category
    local cat_arr = self:create_path(new_category)
    local tbl = self:path_into_tree(Item[id].category)
    if journal_path then -- this maybe should be fleshed out?
        return self:serialize(id, journal_path)
    end
end



-- AI code follows with few mods
-- 
----------------------------------------------
-- Category path traversal and tree navigation

--- ---- TRAVERSE ----
--- Traverses the category tree following a path like "Music/Metal/Death"
--- Returns the node at the end of the path, or nil if any segment doesn't exist
--- 
--- @param path string - The category path to traverse (e.g., "Music/Metal/Death")
--- @param tbl table The table to be manipulated hich also has _ctegory.tree
--- @return table The node at the end of the path, or nil if not found

function Category:path_into_tree(path)
    -- Load data from memory
    local Item = Item or require "core.item"

    -- Check if path top-level
    if not path:find("/") then 
        -- we have a top-level category, so GTFO
        return {
                node = Item._category_tree[path],
                path = path,
                parts = { path },
                depth = 1,
                parent = "/"
                }
    end

    -- not top-level: split it!
    local parts = self:split_path(path) -- maybe add error handling?

    -- List of path parts that have already been dealt with
    local full_path_parts = {}

    -- Get the current tree
    local current = Item._category_tree

    -- Declare the last found node here so that it's in scope for returning
    local last_node
    
    -- Traverse through the path, starting from level 1 and going deeper
    for i, part in ipairs(parts) do
        table.insert(full_path_parts, part)

        -- Last found node declared/overwritten
        last_node = current[part]
        current = current[part]._children
    end
    
    return {
        node = last_node,
        path = path,
        parts = parts,
        depth = #parts,
        parent = #parts > 1 and table.concat(
            parts, "/", 1, #parts - 1
            ) or nil,
    }
end

--- ---- CREATE PATH ----
--- Creates all missing nodes along a path
--- 
--- @param path string The category path to create (e.g., "Music/Metal/Death")
--- @return table The created node at the end of the path 
function Category:create_path(path)
    local parts = self:split_path(path)
    local Item = Item or require "core.item"
    local current = Item._category_tree
    local full_path_parts = {}
    local last_node = nil
    
    for i, part in ipairs(parts) do
        full_path_parts[#full_path_parts + 1] = part
        
        if not current[part] then
            current[part] = {
                _children = {},
                _releases = {},
                _path = table.concat(full_path_parts, "/"),
                _name = part,
            }
        end
        
        last_node = current[part]
        current = current[part]._children
    end
    
    -- After the loop, last_node is the final node
    return {
        node = last_node,
        path = path,
        parts = parts,
        depth = #parts,
    }
end

--- ---- GET RELEASES ----
--- Returns all releases at a specific category node (not including subcategories)
--- 
--- @param path string The category path
--- @return table IDs Array of release IDs at this category
function Category:get_no_subcat(path)
    local result = self:path_into_tree(path)
    if not result then
        return {}
    end
    return result.node._releases
end

--- ---- GET ALL RELEASES (RECURSIVE) ----
--- Returns all releases in a category AND all its subcategories
--- 
--- @param path string The category path
--- @return table IDs Array of all release IDs found
function Category:get_subcat(path)
    local result = self:path_into_tree(path)
    if not result then
        return {}
    end
    
    local all_releases = {}
    
    -- Recursively collect releases from this node and all children
    local function collect(node)
        -- Add releases from current node
        for _, id in ipairs(node._releases) do
            table.insert(all_releases, id)
        end
        -- Recurse into children
        for key, child in pairs(node._children) do
            collect(child)
        end
    end
    
    collect(result.node)
    return all_releases
end


--- GET COUNT
--- 
--- Returns the number of releases in a category (not including subcategories)
--- Completely useless. Use #self:get_subcat(path) or #self:get_no_subcath
--- 
--- @param path string The category path
--- @return number Count of releases
function Category:get_count(path)
    return #self:get_subcat(path)
end


--- ---- ADD RELEASE ----
--- 
--- Adds a release ID to a category
--- 
--- @param path string The category path
--- @param id number The release ID to add
--- @return boolean True if successful
function Category:tree_add_id(path, id)
    local result = self:path_into_tree(path, id)
    if not result then
        return false
    end
    table.insert(result.node._releases, id)
    return true
end

--- ---- REMOVE RELEASE ----
--- 
--- Removes a release ID from a category
--- 
--- @param path string The category path
--- @param id number The release ID to remove
--- @return boolean True if successful
function Category:tree_remove_item(path, id)
    local result = self:path_into_tree(path)
    
    local releases = result.node._releases
    for i, rel_id in ipairs(releases) do
        if rel_id == id then
            table.remove(releases, i)
            return true
        end
    end
    return false
end

-- lazy tree rebuild

-- ---- LAZY TREE REBUILD ----
-- State matrix for _category_index[category]:
--   nil                    = Category doesn't exist
--   {}                     = Category exists, empty (no releases)
--   { dirty = false }      = Category exists, has releases, clean
--   { dirty = true }       = Category exists, has releases, dirty (needs rebuild)

-- Mark category as dirty (or empty if no releases)
function Category:mark_dirty(tbl, category)
    if not category then return end
    
    -- Check if category has releases
    local has_releases = false
    for _, rel in ipairs(tbl._data) do
        if rel.category == category then
            has_releases = true
            break
        end
    end
    
    if has_releases then
        tbl._category_index[category] = { dirty = true }
    else
        tbl._category_index[category] = {}  -- Empty
    end
end

-- Rebuild a single dirty category from _data
function Category:rebuild_in_tree(tbl, category)
    local entry = tbl._category_index[category]
    if not entry or entry.dirty == nil or not entry.dirty then
        return  -- Doesn't exist, empty, or already clean
    end
    
    -- Clear old releases from tree
    local result = self:path_into_tree(category, tbl)
    if result and result.node then
        result.node._releases = {}
    end
    
    -- Scan _data for releases in this category
    local has_releases = false
    for id, rel in ipairs(tbl._data) do
        if rel.category == category then
            self:tree_add_id(category, id, tbl)
            has_releases = true
        end
    end
    
    -- Update state
    if has_releases then
        tbl._category_index[category] = { dirty = false }
    else
        tbl._category_index[category] = {}  -- Empty
    end
end

-- Rebuilds dirty category in tree
function Category:rebuild_in_tree(path)
    local Item = Item or require "core.item"
    if not Item._category_tree[path].dirty then
        return
    end
    if not Item._category_tree[path].dirty then return end -- false
    -- Clear tree
    Item._category_tree[path] = {}
    
    -- Rebuild from _data
    for id, rel in ipairs(Item._data) do
        if rel.category == path then
            self:create_path(rel.category)
            local result = self:path_into_tree(rel.category)
            if result and result.node then
                table.insert(result.node._releases, id)
            end
        end
    end
    
    Item._category_tree[path].dirty = false
end


return Category