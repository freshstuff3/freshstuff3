-- core/category.lua
--- DELETE CATEGORY
--- 
--- Removes a category and optionally its releases
---
---@param path string Category path to delete
---@param source_of_truth table source_of_truth to use
---@param force? boolean If true, delete releases. If false, error if not empty.
---@return boolean success
---@return string error
---@todo Implement: check if category exists
---@todo Implement: get all release IDs in category
---@todo Implement: if force, delete all releases (use table.remove, update dirty)
---@todo Implement: if not force and has releases, return error with count
---@todo Implement: remove from _category_tree
---@todo Implement: remove from _category_index
---@todo Implement: return success message with deleted count
---@todo Implement: USE THE --force

--- RENAME CATEGORY
---@param old_path string Current category path
---@param new_path string New category path
---@param source_of_truth table source_of_truth to use
---@return boolean success
---@return string error
---@todo Implement: validate old_path exists
---@todo Implement: validate new_path doesn't exist
---@todo Implement: validate new_path is valid (no spaces, etc.)
---@todo Implement: create new category node
---@todo Implement: move all releases from old to new (update .category field)
---@todo Implement: move _releases to new node
---@todo Implement: delete old category
---@todo Implement: update _category_index
---@todo Implement: mark both categories dirty
---@todo Implement: return success message

--- EMPTY CATEGORY (delete all releases but keep category)
---@param path string Category path
---@param source_of_truth table source_of_truth to use
---@return boolean success
---@return string error
---@todo Implement: check if category exists
---@todo Implement: get all release IDs
---@todo Implement: delete each release from _data
---@todo Implement: clear _releases in tree
---@todo Implement: update _category_index to empty state
---@todo Implement: return success message with deleted count
---@todo EMOJI STORAGE IN _category_index
--- - [ ] Store emoji per-category in _category_index[path].emoji
--- - [ ] Subcategories inherit parent emoji by default (fallback)
--- - [ ] Allow explicit emoji override at any category level
--- - [ ] Inherited emoji should be marked as such (e.g., _inherited = true)
--- - [ ] When parent emoji changes, update children unless they have explicit overrides
--- - [ ] Include emoji in _category_index serialization (categories.lua)
--- - [ ] Add Category:set_emoji(path, emoji) to set explicit emoji
--- - [ ] Add Category:get_emoji(path) to resolve inherited emoji
---
---@example
---   -- Set explicit emoji for Music
---   Category:set_emoji("Music", "🎶")
---   -- Music/Metal inherits 🎶 by default
---   -- Override Music/Metal explicitly
---   Category:set_emoji("Music/Metal", "🤘")
---
---@example Category:get_emoji(path) return logic
---   if _category_index[path].emoji then
---       return _category_index[path].emoji  -- explicit
---   end
---   if path:find("/") then
---       local parent = parent_path(path)
---       return Category:get_emoji(parent)   -- inherited
---   end
---   return "📁"                             -- default

---@class Category
local Category = {}

--- CATEGORY INITIALISATION
---
--- Initialises the category system on script startup or after a memory dump.
--- This function:
---   1. Loads the category index from a file (if it exists)
---   2. Rebuilds the category tree from _data (source of truth)
---   3. Ensures all categories in _data exist in the tree
---   4. Marks all categories as clean (dirty = false)
---   5. Serializes the index back to disk (creates file if missing)
---
--- Why rebuilding from _data is safe:
---   - _data is the authoritative source for which categories exist
---   - Any category with at least one release will be in _data
---   - Empty categories are not recreated (they will be re-added if needed)
---
--- Behaviour:
---   - If the category file exists: Loads it, then adds any missing categories
---   - If the category file is missing: Creates it from scratch from _data
---   - If a release has a category that doesn't exist yet: Creates it
---   - All categories are marked clean (dirty = false) on init
---
--- File format expected:
---   return {
---     ["Music"] = {},
---     ["Music/Metal"] = {},
---     ["Music/Metal/Death"] = {},
---   }
---
---@param filename string Path to the categories file (e.g., "data/categories.lua")
---@param source_of_truth table Namespace containing _data and _category_index
---@return table _category_index Flat index of all categories (with dirty flags)
---@return table _category_tree Nested tree structure for fast lookups
---@todo If file loading fails, create from scratch from _data
---@todo Add validation: ensure _data is not nil before iterating
---@todo Add error recovery: if serialisation fails, keep existing data
---@todo Consider skipping serialisation if no changes detected
---@todo Add support for migrating old category formats (if needed)
---@todo Consider using a temporary file during serialisation to avoid corruption
function Category:init(filename, source_of_truth)
    assert(filename ~= nil and filename ~= "" and source_of_truth ~= nil, 
    "File name and/or source_of_truth unspecified!") 
    local _category_index, _category_tree = {}, {}
    local dummy = { ["_category_tree"] = _category_tree, 
                    ["_category_index"] = _category_index }
    local go, err = loadfile(filename)
    if go then _category_index = go()
    else return false, err end
    for id, piece in ipairs(source_of_truth._data) do
        -- Not checking if exists. We are overwriting nothing.
        -- Also, marking clean by default as it does have releases 
        -- AND is up-to-date.
        local node, err = self:create(piece.category, dummy)
        if node then 
            table.insert(node._releases, id) 
        else
            node = self:get_node(piece.category, dummy)
            if node then
                table.insert(node._releases, id)
            end
        end
    end
    for path, _ in pairs(_category_index) do
        _category_index[path] = _category_index[path] or {}
        _category_index[path].dirty = false
    end
    assert(self:serialize(filename, dummy), "Category serialisation failed!")
    return _category_index, _category_tree
end

--- GET NODE
---
--- Retrieves a category node from the category tree by traversing the given path.
--- Returns the node at the end of the path, or nil if any segment is missing.
---
--- Behavior:
---   - Top-level path (e.g., "Music"): Direct lookup in _category_tree
---   - Nested path (e.g., "Music/Metal/Death"): Traverses each segment
---   - If any segment is missing: Returns nil immediately
---   - Returns the full node table containing _releases and child nodes
---
--- The node structure:
---   {
---     _releases = {1, 5, 12, 23},   -- Array of release IDs in this category
---     ["Subcategory"] = { ... },    -- Child nodes (subcategories)
---     ["Another"] = { ... },
---   }
---
--- Examples:
---   Category:get_node("Music", Item)          -- Returns top-level Music node
---   Category:get_node("Music/Metal", Item)    -- Returns Metal node
---   Category:get_node("Invalid/Path", Item)   -- Returns nil
---
---@param path string The category path to retrieve (e.g., "Music/Metal/Death")
---@param source_of_truth table Namespace containing _category_tree (e.g., Item, Request)
---@return table|nil node The node at the end of the path, or nil if not found
---@todo Consider caching frequently accessed nodes for performance
---@todo Add support for case-insensitive matching (optional, configurable)
---@todo Add support for path validation before traversal (ensure no empty segments)
---@todo Return more detailed error information (e.g., which segment failed)
function Category:get_node(path, source_of_truth)
    -- Throw error in case of missing parameters
    assert(path ~= nil and path ~= "" and source_of_truth ~= nil, 
        "Path and/or source_of_truth unspecified!")
    -- Check if path top-level. If yes, GTFO
    if not path:find("/") then 
        return source_of_truth._category_tree[path]
    end
    -- not top-level: split it!
    local parts = self:split_path(path) -- maybe add error handling?
    -- List of path parts that have already been dealt with
    local full_path_parts = {}
    -- Get the current tree
    local current = source_of_truth._category_tree
    -- Traverse through the path, starting from level 1 and going deeper
    for i, part in ipairs(parts) do
        table.insert(full_path_parts, part)
        if not current[part] then
            return nil  -- Path segment doesn't exist
        end
        -- Current tree overwritten
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
function Category:create(path, source_of_truth)
    assert(path ~= nil and path ~= "" and source_of_truth ~= nil, 
    "Path and/or source_of_truth unspecified!")
    if source_of_truth._category_index[path] and self:get_node(path, source_of_truth) then
        return nil, string.format("Category %s already exists!", path)
    end
    -- Add to index if not present
    source_of_truth._category_index[path] = source_of_truth._category_index[path] or {}
    if not path:find("/") then --top-level category
        local node = { _releases = {} }
        source_of_truth._category_tree[path] = node
        return node, nil
    end
    local parts = self:split_path(path)
    local current = source_of_truth._category_tree
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

--- CATEGORY PATH SANITISATION AND VALIDATION
---
--- Validates and sanitises a category path string before it is used for
--- any category operations (creation, traversal, deletion, etc.).
---
--- Validation rules:
---   - Maximum length: 70 characters (hardcoded for message display limits)
---   - No leading slashes (e.g., "/Music" → "Music")
---   - No trailing slashes (e.g., "Music/" → "Music")
---   - No consecutive slashes (e.g., "Music//Metal" → "Music/Metal")
---   - Maximum depth: 5 levels (e.g., "Music/Metal/Death/Slam/Brutal" is OK)
---   - Category must exist in _category_index (for operations on existing cats)
---
--- Sanitisation steps:
---   1. Remove leading slashes: "/Music/Metal" → "Music/Metal"
---   2. Remove trailing slashes: "Music/Metal/" → "Music/Metal"
---   3. Collapse consecutive slashes: "Music//Metal" → "Music/Metal"
---
--- Note: This function validates the STRING path, not the data.
---       Spaces are NOT checked here (handled by %S+ in business logic).
---       Emptiness is NOT checked here (handled by caller).
---
---@param path string Category path to validate (e.g., "Music/Metal/Death")
---@param source_of_truth table Namespace containing _category_index
---@return boolean success True if valid, false if invalid
---@return string result Sanitized path on success, error message on failure
---@todo Consider case sensitivity option (optional, default: case-sensitive)
function Category:process_path(path, source_of_truth)
        assert(path ~= nil and path ~= "" and source_of_truth ~= nil, 
        "Path and/or source_of_truth unspecified!")
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
    if not source_of_truth._category_index[path] then return false, string.format(
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

--- SAVE CATEGORIES TO FILE
---
--- Serializes the category index (_category_index) to a Lua file.
--- The category tree (_category_tree) is NOT serialized as it can be
--- rebuilt from _data on startup.
---
--- Why only _category_index:
---   - _category_index is a flat list of all categories that exist
---   - _category_tree is a nested structure derived from _data
---   - On startup, _category_tree is rebuilt from _data
---   - _category_index provides fast existence checks without traversing _data
---
--- File format:
---   return {
---     ["Music"] = {},
---     ["Music/Metal"] = {},
---     ["Music/Metal/Death"] = {},
---   }
---
--- Empty tables are used as placeholders. The dirty state is NOT persisted;
--- it is re-evaluated on startup based on _data.
---
---@param filename string File path to save to (e.g., "data/categories.lua")
---@param source_of_truth table Namespace containing _category_index
---@return boolean success True if save succeeded
---@return string|nil err Error message if save failed
---@todo Add backup before overwriting (rename old file to .bak)
---@todo Add atomic write: write to temp file, then rename
---@todo Add validation: ensure _category_index is not empty before saving
---@todo Add logging: when save happens, how many categories saved
---@todo Add error recovery: if save fails, keep existing file intact
function Category:serialize(filename, source_of_truth)
    assert(filename ~= nil and filename ~= "" and source_of_truth ~= nil, 
        "File name and/or source_of_truth unspecified!")
    local f, err = io.open (filename, "w+")
    if f then
        f:write("return {\n")  
        for path, _ in pairs(source_of_truth._category_index) do
            f:write ("[\""..path.."\"] = {},\r\n")
        end
        f:write("}\n")
        f:flush()
        f:close()
        return true
    end
    return false, err -- serialisation failed
end


--- ---- GET ITEMS (NON-RECURSIVE) ----
--- Returns all items at a specific category node 
--- (not including subcategories)
--- 
--- @param path string The category path
--- @param source_of_truth table Source of truth
--- @return table IDs Array of release IDs at this category
function Category:get_no_subcat(path, source_of_truth)
    assert(path ~= nil and path ~="" and source_of_truth ~= nil, 
        "Path and/or source_of_truth unspecified!")
    -- No state checking. rebuild_node returns anyway if no rebuild needed
    local result = self:rebuild_node(path, source_of_truth) or 
        self:get_node(path, source_of_truth)
    if not result then return {} end
    return result._releases
end

--- ---- GET ITEMS (RECURSIVE) ----
--- Returns all items in a category INCL. all its subcategories
--- 
--- @param path string The category path
--- @return table IDs Array of all release IDs found
function Category:get_subcat(path, source_of_truth)
    assert(path ~= nil and path ~="" and source_of_truth ~= nil, 
        "Path and/or source_of_truth unspecified!")
    --assert(type(source_of_truth._category_index[path]) == "table" )
    local result = self:rebuild_node(path, source_of_truth) or self:get_node(path, source_of_truth)
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
--- @param source_of_truth table source_of_truth to be used
--- @return table|nil node Returns the rebuilt node on success, or nil on error
function Category:rebuild_node(path, source_of_truth)
    assert(path ~= nil and path ~= "" and source_of_truth ~= nil, 
        "Path and/or source_of_truth unspecified!")
    -- Get the state from _category_index
    local entry = source_of_truth._category_index[path]
    if not entry or entry.dirty == nil or not entry.dirty then
        return nil -- Doesn't exist, empty, or already clean
    end
    
    -- Clear old items from tree
    local node = self:get_node(path, source_of_truth)
    if node then
        node._releases = nil; node._releases = {}
    else return nil end
    
    -- Scan _data for items in this category
    local has_releases = false
    for id, item in ipairs(source_of_truth._data) do
        if item.category == path then
            table.insert(node._releases, id)
            has_releases = true
        end
    end
    
    -- Update state
    if has_releases then
        source_of_truth._category_index[path] = { dirty = false }
    else
        source_of_truth._category_index[path] = {}  -- Empty
    end
    return node
end

return Category


