-- core/category.lua
--[[
local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"

package.path = package.path .. string.format(";%s?.lua", base_path)

local CATEGORIES_FILE = base_path.."data/categories.lua"
local TEST_CATEGORY = "/home/szg/ptokax-config/scripts/freshstuff3/data/test_category.lua"
]]

local Category = {}

--- CATEGORY INITIALISATION
--- 
--- Usually run on script restart or memory dump
--- 
--- @param filename string file to open
function Category:init(filename)
    filename = filename or TEST_CATEGORY
    namespace =  Item 
    Item._category_index = {}
    Item._category_tree = {}
    local go = loadfile(filename)
    if go then Item._category_index = go()
    --else
        --"Categories file is missing or corrupt. Will create"..
         --   "a new one from the items."
    end
    for id, piece in ipairs(Item._data) do
        -- Not checking if exists. We are overwriting nothing.
        -- Also, marking clean by default as it does have releases 
        -- AND is up-to-date.
        local node, err = self:create(piece.category)
        if node then 
            table.insert(node._releases, id) 
        else
            node = self:get_node(piece.category)
            if node then
                table.insert(node._releases, id)
            end
        end
    end
    for path, _ in pairs(Item._category_index) do
        Item._category_index[path] = Item._category_index[path] or {}
        Item._category_index[path].dirty = false
    end
    self:serialize(filename)
end

--- GET NODE 
--- 
--- Returns the node at the end of the path, or nil if any segment doesn't exist
--- 
--- @param path string The category path to retrieve (e.g., "Music/Metal/Death")
--- @return table|nil node The node at the end of the path, or nil if not found
function Category:get_node(path)
    -- Load data from memory

    -- Check if path top-level. If yes, GTFO
    if not path:find("/") then 
        return Item._category_tree[path]
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
        if not current[part] then
            return nil  -- Path segment doesn't exist
        end
        -- Last found node declared/overwritten
        current = current[part]
    end
    return current
end


--- ---- CREATE CATEGORY ----
--- 
--- Creates the node in _category_tree, but ONLY if parent category exists
--- 
--- If item ID is specified, it will be added to the created node
--- 
--- @param path string The category path to create (e.g., "Music/Metal/Death")
--- @return table|nil node Returns node on success, nil on error
--- @return string error Upon failure, returns error message.
function Category:create(path)
    if Item._category_index[path] and self:get_node(path) then
        return nil, string.format("Category %s already exists!", path)
    end
    -- Add to index if not present
    if not Item._category_index[path] then
        Item._category_index[path] = {}
    end

    if not path:find("/") then --top-level category
        local node = { _releases = {} }
        Item._category_tree[path] = node
        return node, nil
    end
    local parts = self:split_path(path)
    local current = Item._category_tree
    local full_path_parts = {}

    for i, part in ipairs(parts) do
        table.insert(full_path_parts, part)
        
        if not current[part] then -- nonexistent node
            if i == #parts then -- innermost, create it
                current[part] = {
                    _releases = {},
                }
            else -- parent category does not exist, return error
                return nil, string.format(
                "Parent category %s for specified category %s does not exist."..
                "Create it first!",
                table.concat(full_path_parts, "/"), path
                )
            end
        end
        current = current[part]
    end
    return current, nil
end

--- Category path sanitisation/validation
--- 
--- Not checking for spaces as it is detected as %S+ in business logic anyway
--- 
--- This is a STRING validation, does not check for emptiness
--- 
--- We don't even want to start manipulating categories without a valid path.
--- 
--- @param path string Category path x/z/y
--- @return boolean success Return true on success, false on error
--- @return string sanitized_path__or__error_msg the sanitized path string 
--- on success, error message on error
function Category:process_path(path)
    -- check if path exists
    if not path or path == "" then
        return false, "Category path cannot be empty."
    end

    -- string longer than 70 chars
    -- This should be hardcoded as for messages (ie. expected use case), 
    -- the display is the bottleneck
    if #path > 70 then 
        return false, string.format("Category path %s too long. "..
        "Maximum 70 characters.", path) 
    end

    -- Replace trailing and leading slashes, 
    -- also multiple consecutive slashes
    path = path:gsub( "^/+", ""):gsub( "/+$", ""):gsub("//+", "/")
    if string.find (path, "/") then -- subcategory
        local depth = #self:split_path(path)
        if depth > 5 then 
            return false, string.format("Subcategory %s deeper than"..
                                            " five levels.", path
                                            )
         end
    end
    if not Item._category_index[path] then return false, string.format(
        "Category %s not found in categories. It needs to be created"..
        " first. ", path
        )
    end
    return true, path 
end

--- Split category path into parts
--- 
--- 
--- @param path string category path
--- @return table parts Returns an array of parts, 
--- ordered fromm top level downwards.
function Category:split_path(path)
    -- Check if top-level category
    if not path:find("/") then; return { path }; end
    -- Not-top-level category, split required
    local parts = {}
    for part in path:gmatch("([^/]+)") do
        table.insert(parts, part)
    end
    return parts
end

--- ---- SAVE CATEGORIES TO FILE ----
--- This serializes _category_index only.
--- _category_tree only resides in memory and is created from _data initially
--- 
--- 
--- @param filename string File name to be used.
--- @return boolean success Succes or failure
--- @return string|nil err Error message in case of failure
function Category:serialize(filename)
    filename = filename or TEST_CATEGORY
    local f, err = io.open (filename, "w+")
    if f then
        f:write("return {\n")  
        for path, _ in pairs(Item._category_index) do
            f:write ("[\""..path.."\"] = {},\r\n")
        end
        f:write("}\n")
        f:flush()
        f:close()
        return true
    end
    return false, err -- serialisation failed
end


--- ---- GET ITEMS ----
--- Returns all releases at a specific category node 
--- (not including subcategories)
--- 
--- @param path string The category path
--- @return table IDs Array of release IDs at this category
function Category:get_no_subcat(path)
    -- No state checking. rebuild_node returns anyway if no rebuild needed
    local result = self:rebuild_node(path) or self:get_node(path)
    if not result then return {} end
    return result._releases
end

--- ---- GET ALL ITEMS (RECURSIVE) ----
--- Returns all releases in a category INCL. all its subcategories
--- 
--- @param path string The category path
--- @return table IDs Array of all release IDs found
function Category:get_subcat(path)
    local result = self:rebuild_node(path) or self:get_node(path)
    if not result then return {} end
    
    local list = {}
    
    -- Recursively collect releases from this node and all children
    local function collect(node)
    -- Add releases from current node
        for _, id in ipairs(node._releases or {}) do
            table.insert(list, id)
        end
        -- Recurse into child nodes
        for key, child in pairs(node) do
            if key ~= "_releases" then
                collect(child)
            end
        end
    end
    collect(result)
    return list
end


--- ---- LAZY TREE REBUILD ----
--- 
--- 
--- State matrix for _category_index[category]:
--- 
---   nil                    = Category doesn't exist
--- 
---   {}                     = Category exists, empty (no releases)
--- 
---   { dirty = false }      = Category exists, has releases, clean
--- 
---   { dirty = true }       = Category exists, has releases, dirty (needs rebuild)
--- 
--- Categories are marked dirty upon item addition, deletion or move.
--- When moving, old and new category both need to be marked dirty.

--- Rebuild a single dirty category from _data
--- 
--- @param path string Category path to rebuild
--- @return table|nil node Returns the rebuilt node on success.
function Category:rebuild_node(path)
    -- If no namespace passed, fall back
    -- Get the state from _category_index
    local entry = Item._category_index[path]
    if not entry or entry.dirty == nil or not entry.dirty then
        return nil -- Doesn't exist, empty, or already clean
    end
    
    -- Clear old items from tree
    local node = self:get_node(path)
    if node then
        node._releases = nil; node._releases = {}
    else return nil end
    
    -- Scan _data for items in this category
    local has_releases = false
    for id, item in ipairs(Item._data) do
        if item.category == path then
            table.insert(node._releases, id)
            has_releases = true
        end
    end
    
    -- Update state
    if has_releases then
        Item._category_index[path] = { dirty = false }
    else
        Item._category_index[path] = {}  -- Empty
    end
    return node
end

return Category


