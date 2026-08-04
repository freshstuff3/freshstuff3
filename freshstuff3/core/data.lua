-- core/data.lua

local Data = {}


-- ---- SAVE CATEGORIES ----
-- Lorem ipsum
-- 
-- 
-- @param param stringe - Table name to be used.
-- @param filename string - Category file path relative to ptokax script folder
-- @param table_name string|table|number - (table: addition, string: move, number. deletion)
-- @return boolean|nil - Journal success if performed
-- 
function Data:save_cats(filename, table_name)
    local idx = _G[table_name].category_index
    local f = io.open (filename, "w+")
    if f then
        f:write(table_name..".category_index = {\n")  
        for path, val in idx:pairs() do
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
-- @param journal_file string - Journal file path relative to ptokax script folder
-- @param table_name string - Name of the global table being used
-- @param param string|table|number (table: addition, string: move, number. deletion)
-- @return boolean|nil - True on success
-- 
function Data:journal_append(journal_file, table_name, param)
    local str
    local function write_to_file (filename, str)
    local f = io.open(filename,"a+")
    if f then
        f:write(string)
        f:flush; f:close()
        end
    end

    if type(param) == "number" then
        -- we are deleting
        -- we have the DELETED id with param
        str = string.format("table.remove(%S, %d)",table_name, param )

    elseif type(param) == "string" then 
        -- category name, so we are moving
        str = string.format("%S._data[id].category = \"%S\"",table_name, param )
    else
        -- we are adding as release object received
        str = string.format("table.insert(%S.__data, {category = \"%S\", nick =  \"%S\", title = \"%S\", when = \"%d\" })",table_name, param.category, param.nick, param.title, param.when )
    end
    return pcall(write_to_file (journal_file,str))
end

-- ---- DATA ADD ----
-- Lorem ipsum
-- 
-- 
-- @param rel_object table - cat, nick, title, timestamp
-- @param table_name string 
-- @param jourrnal_path string 
-- @return number|nil - The numerical index of the new item within _data
-- @return boolean|nil - Journal success if performed
function Data:add(rel_object, table_name, jourrnal_path) -- table, string, string
    local namespace = _G[table_name]
    table.insert(namespace._data, rel_object)
    if not namespace.category_index[rel_object.category] then 
        self:cat_create_path(rel_object.category)
        _G[table_name]._category_index[rel_object.category] = true
        self:save_cats(table_name, rel_object.category)
   else 
        -- category exists, add it to tree
        local tbl = self:traverse_cat_path(rel_object.category, namespace)
        table.insert (tbl, #namespace._data)
   end

    local success
    if journal_path then
        success = self:journal_append(table_name, rel_object, is_move)
    end
    return #namespace._data, success
end

function Data:move(id, old_category, new_category, table_name, journal_path) 
-- dont need release object or old category    
   local namespace = _G[table_name]
   table.insert(namespace, rel_object)
   _G[table_name][id].cat = new_category
   if journal_path then
      self:journal_append(table_name, id, is_move)
      -- string should be
      -- if move: _G[table_name]._data[1]


function Data:split_cat_path(path)
    local parts = {}
    for part in path:gmatch("([^/]+)") do
        table.insert(parts, part)
    end
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
    local result = self.traverse_cat_path(path)
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
    local result = self.traverse_cat_path(path)
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
function Data:get_cat_rel_count(path)
    return #self.get_cat_with_subcat(path)
end

-- ---- EXISTS ----
-- Checks if a category exists
-- 
-- @param path string - The category path
-- @return boolean - True if the category exists
function Data:validate_cat(path)
    local result = self.traverse_cat_path(path)
    return result ~= nil
end

-- ---- ADD RELEASE ----
-- Adds a release ID to a category
-- 
-- @param path string - The category path
-- @param id number - The release ID to add
-- @return boolean - True if successful
function Data:add_release_to_tree(path, id)
    local result = self.traverse_cat_path(path)
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
function Category.remove_release_from_tree(path, id)
    local result = self.traverse_cat_path(path)
    
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