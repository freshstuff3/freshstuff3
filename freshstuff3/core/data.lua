-- core/data.lua
-- 
-- TODO:
-- add category rebuild from AI
-- data.delete
-- maybe split out category manipulation as we are at 500 lines
-- validation

local Data = {}


-- ---- SAVE CATEGORIES ----
-- Lorem ipsum
-- 
-- 
-- @param param stringe - Table name to be used.
-- @param filename string - Category file path relative to ptokax script folder
-- @param table_name string|table|number - (table: addition, string: move, number. deletion)
-- @param category string - category
-- @return boolean|nil - Journal success if performed
-- 
function Data:save_cats(filename, table_name, category)
    filename = filename or "freshstuff3/data/category.dat"
    local idx = _G[table_name]._category_index
    local f = io.open (filename, "w+")
    if f then
        f:write(table_name.."._category_index = {\n")  
        for path, val in pairs(idx) do
            f:write ("["..path.."] = "..val..",\n")
        end
        f:write("}\n")
        f:flush()
        f:close()
    end
end


-- ---- DATA JOURNAL APPEND ----
-- Lorem ipsum
-- 
-- 

-- @param table_name string - Name of the global table being used
-- @param param string|table|number (table: addition, string: move, number. deletion)
-- @param journal_file string - Journal file path relative to ptokax script folder
-- @param rel_id nunmber - release id
-- @return boolean|nil - True on success
-- 
function Data:journal_append(table_name, param, journal_file, rel_id)
    -- so its journal_append("Releases", object, "journals/rel.journal") for addition to Releases
    -- ("Releases", 23, "journals/rel.journal") for deletion of release 23
    -- ("Releases", "Movie/Romantic", "journals/rel.journal", 44) for move release 44 to Movies/Romantic
    -- bit confusing
    local str
    local function write_to_file (filename, str)
    local f = io.open(filename,"a+")
    if f then
        f:write(str)
        f:flush(); f:close()
        end
    end

    if type(param) == "number" then
        -- we are deleting
        -- we have the DELETED id with param
        str = string.format("table.remove(%s._data, %d)",table_name, param )

    elseif type(param) == "string" then 
        -- category name, so we are moving
        str = string.format("%s._data[%d].category = \"%s\"",table_name, rel_id, param )
    else
        -- we are adding as release object received
        str = string.format("table.insert(%s._data, {category = \"%s\", nick =  \"%s\", title = \"%s\", when = %d })",table_name, param.category, param.nick, param.title, param.when )
    end
    return pcall(write_to_file (journal_file,str))
end

-- ---- DATA ADD ----
-- Lorem ipsum
-- 
-- 
-- @param table_name string 
-- @param rel_object table - cat, nick, title, timestamp
-- @param journal_path string 
-- @return number|nil - The numerical index of the new item within _data
-- @return boolean|nil - Journal success if performed
function Data:add(table_name, rel_object, journal_path) -- table, string, string
    local namespace = _G[table_name]
    table.insert(namespace._data, rel_object)
    if not namespace._category_index[rel_object.category] then 
        self:cat_create(table_name, rel_object.category, true)
   else 
        -- category exists, add release ID to tree
        local tbl = self:traverse_cat_path(rel_object.category, namespace)
        -- into the returned reference, we insert the max index of 
        -- _data because that is our ID here
        table.insert(tbl.node._releases,#namespace._data)
        -- We are not adding the category, that should be called 
        -- Category tree never saved
   end

    local success
    if journal_path then
        success = self:journal_append(table_name, rel_object, journal_path)
        -- we are not passing the 4th parameter as it is only used when moving
    end
    return #namespace._data, success
end


-- ---- Category creation ----
-- Lorem ipsum
-- 
-- 
-- @param table_name string 
-- @param cat string - category name
-- @param has_items boolean - true if category not empty (stored as 0/1)
-- @return number|nil - The numerical index of the new item within _data
-- @return boolean|nil - Journal success if performed
function Data:cat_create(table_name, cat, has_items)
    local c = 0; if has_items then c = 1 end
    _G[table_name]._category_index[cat] = c
    self:cat_create_path(cat)
    self:save_cats(_, table_name, cat)
end


-- @param id number - Release ID to move
-- @param new_category string - New category
-- @param table_name string - 
-- @param journal_path string - Optional
function Data:move(id, old_category, new_category, table_name, journal_path) 
-- dont need release object, we can use id    
   local namespace = _G[table_name]
   -- TODO: check if the old category will become empty after move 
   _G[table_name]._data[id].cat = new_category
   local cat_arr = self:cat_create_path(new_category)
   local tbl = self:traverse_cat_path(rel_object.category, namespace)
   if journal_path then
      self:journal_append(table_name, id, journal_path)
   end
end


-- @param path string - Category path x/z/y
-- @return list  - Ordered list of category parts
function Data:split_cat_path(path)
    local parts = {}
    for part in path:gmatch("([^/]+)") do
        table.insert(parts, part)
    end
    return parts
end
-- AI code follows with few mods
-- 
----------------------------------------------
-- Category path traversal and tree navigation

-- ---- TRAVERSE ----
-- Traverses the category tree following a path like "Music/Metal/Death"
-- Returns the node at the end of the path, or nil if any segment doesn't exist
-- 
-- @param path string - The category path to traverse (e.g., "Music/Metal/Death")
-- @param namespace table The namespace within _G to be used. E. g. Releases
-- @return table|nil - The node at the end of the path, or nil if not found
-- @return string|nil - Error message if traversal fails
-- 

function Data:traverse_cat_path(path, namespace)
    -- Split the path string
    local parts = self:split_cat_path(path)
    
    -- if namespace not declared, fall back to Releases
    namespace = namespace or Releases

    -- Add the path parts that have already been dealt with
    local full_path_parts = {}
    local current = namespace.category_tree
    -- Declare the last found node here, so that we can use it
    -- outside the loop below
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
        parent = #parts > 1 and table.concat(parts, "/", 1, #parts - 1) or nil,
    }
end

-- ---- CREATE PATH ----
-- Creates all missing nodes along a path
-- 
-- @param path string - The category path to create (e.g., "Music/Metal/Death")
-- @return table|nil - The created node at the end of the path
-- @return string|nil - Error message if creation fails
function Data:cat_create_path(path)
    local parts = self:split_cat_path(path)
    
    local current = Data.category_tree
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

-- ---- GET RELEASES ----
-- Returns all releases at a specific category node (not including subcategories)
-- 
-- @param path string - The category path
-- @return table - Array of release IDs at this category
function Data:get_cat_no_subcat(path)
    local result = self:traverse_cat_path(path)
    if not result then
        return {}
    end
    return result.node._releases
end

-- ---- GET ALL RELEASES (RECURSIVE) ----
-- Returns all releases in a category AND all its subcategories
-- 
-- @param path string - The category path
-- @return table - Array of all release IDs found
function Data:get_cat_with_subcat(path)
    local result = self:traverse_cat_path(path)
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

-- ---- GET COUNT ----
-- Returns the number of releases in a category (not including subcategories)
-- 
-- @param path string - The category path
-- @return number - Count of releases
-- Completely useless. Use #self:get_cat_with_subcat(path) directly
function Data:get_cat_rel_count(path)
    return #self:get_cat_with_subcat(path)
end

-- ---- EXISTS ----
-- Checks if a category exists
-- 
-- @param path string - The category path
-- @return boolean - True if the category exists
-- Completely useless. Do lookup like _category_index[path]
function Data:validate_cat(path)
    local result = self:traverse_cat_path(path)
    return result ~= nil
end

-- ---- ADD RELEASE ----
-- Adds a release ID to a category
-- 
-- @param path string - The category path
-- @param id number - The release ID to add
-- @return boolean - True if successful
function Data:add_release_to_tree(path, id)
    local result = self:traverse_cat_path(path)
    if not result then
        return false
    end
    table.insert(result.node._releases, id)
    return true
end

-- ---- REMOVE RELEASE ----
-- Removes a release ID from a category
-- 
-- @param path string - The category path
-- @param id number - The release ID to remove
-- @return boolean - True if successful
function Date:remove_release_from_tree(path, id)
    local result = self:traverse_cat_path(path)
    
    local releases = result.node._releases
    for i, rel_id in ipairs(releases) do
        if rel_id == id then
            table.remove(releases, i)
            return true
        end
    end
    return false
end

return Data

---- 2nd part of ai code
function Data:delete(table_name, id, journal_path)
    local namespace = _G[table_name]
    if not namespace then
        return false, "Namespace not found: " .. table_name
    end
    
    local record = namespace._data[id]
    if not record then
        return false, "Record not found: " .. id
    end
    
    local old_category = record.category
    
    -- Remove from category tree
    self:remove_release_from_tree(old_category, id)
    
    -- Journal
    if journal_path then
        self:journal_append(table_name, id, journal_path)
    end
    
    -- Remove from _data
    table.remove(namespace._data, id)
    
    -- Rebuild the category (IDs shifted)
    self:rebuild_category(table_name, old_category)
    
    return true
end

function Data:rebuild_category(table_name, category)
    local namespace = _G[table_name]
    if not namespace then return end
    
    local result = self:traverse_cat_path(category, namespace)
    if not result or not result.node then
        return
    end
    
    result.node._releases = {}
    
    for id, rel in ipairs(namespace._data) do
        if rel.category == category then
            table.insert(result.node._releases, id)
        end
    end
end

-- for category move:
function Data:move(id, new_category, table_name, journal_path)
    local namespace = _G[table_name]
    if not namespace then
        return false, "Namespace not found: " .. table_name
    end
    
    local record = namespace._data[id]
    if not record then
        return false, "Record not found: " .. id
    end
    
    local old_category = record.category
    
    -- Skip if same
    if old_category == new_category then
        return true, "Already in this category"
    end
    
    -- Remove from old category tree
    self:remove_release_from_tree(old_category, id)
    
    -- Update category in record
    record.category = new_category
    
    -- Add to new category tree
    self:add_release_to_tree(new_category, id)
    
    -- Journal
    if journal_path then
        self:journal_append(table_name, new_category, journal_path, id)
    end
    
    return true
end


-- BUUUUUUUUUUUUUUUUUUUT:
-- 
-- lazy tree rebuild
--Data = {
--    _data = {},
--    _category_tree = {},
--    tree_dirty = false,  -- ← Track if tree needs rebuild
--}

function Data:mark_dirty(table_name) -- cat
    _G[table_name].tree_dirty = true
end

function Data:ensure_tree_built(table_name) -- cat
    if not _G[table_name].tree_dirty then
        return  -- Tree is fresh
    end
    
    -- Rebuild tree from _data
    _G[table_name]._category_tree = {}
    for id, rel in ipairs(_G[table_name]._data) do
        if rel.category then
            self:_add_to_tree(rel.category, id)
        end
    end
    _G[table_name].tree_dirty = false
end

-- these should be added to existing functions
function Data:delete(table_name, id)
    table.remove(_G[table_name]._data, id)
    _G[table_name].tree_dirty = true -- ← Tree is now stale
end

-- dont even see the use for this
function Data:get_category(category, table_name) -- cat
    self:ensure_tree_built()  -- ← Only rebuilds when needed
    return _G[table_name]._category_tree[category]
end
