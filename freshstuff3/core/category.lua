-- core/Category_lua
--- DELETE CATEGORY
--- 
--- Removes a category and optionally its releases
---
---@param path string Category path to delete
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



--- EMPTY CATEGORY (delete all releases but keep category)
---@param path string Category path
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
---@todo If file loading fails, create from scratch from _data
---@todo Add validation: ensure _data is not nil before iterating---@todo Add support for migrating old category formats (if needed)
function Category:Category_init(filename)
    self._category_index, self._category_tree = {}, {}
    
    -- Load from file
    local go, err = loadfile(filename)
    if go then 
        local loaded = go()
        if type(loaded) == "table" then
            for path, _ in pairs(loaded) do
                self._category_index[path] = {}
            end
        end
    end
    
    -- CRITICAL: Rebuild from _data and populate _releases for ALL parent categories
    for id, piece in ipairs(self._data) do
        local parts = self:Category_split_path(piece.category)
        local current_path = ""
    
        -- Create all parent categories AND add the release ID to each level
        for i, part in ipairs(parts) do
            current_path = i == 1 and part or (current_path .. "/" .. part)
            
            -- Create in index if missing
            if not self._category_index[current_path] then
                self._category_index[current_path] = {}
            end
            
            -- Create in tree if missing
            local node = self:Category_get_node(current_path)
            if not node then
                node = self:Category_create(current_path)
            end
            
            -- ✅ FIX: Add the release ID to EVERY parent category
            if node then
                if not node._releases then
                    node._releases = {}
                end
                -- Avoid duplicates (in case this runs multiple times)
                local found = false
                for _, existing_id in ipairs(node._releases) do
                    if existing_id == id then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(node._releases, id)
                end
            end
        end
    end
    
    -- Mark all categories as clean
    for path, _ in pairs(self._category_index) do
        self._category_index[path] = self._category_index[path] or {}
        self._category_index[path].dirty = false
    end
    
    assert(self:Category_serialize(filename), "Category serialisation failed!")
end

-- Helper: Ensure all parent categories exist in both tree and index
function Category:Category_ensure_path(path)
    local parts = self:Category_split_path(path)
    local current_path = ""
    
    for i, part in ipairs(parts) do
        current_path = i == 1 and part or (current_path .. "/" .. part)
        
        -- Create in index if missing
        if not self._category_index[current_path] then
            self._category_index[current_path] = {}
        end
        
        -- Create in tree if missing
        if not self:Category_get_node(current_path) then
            self:Category_create(current_path)
        end
    end
    return true
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
---@return table|nil node The node at the end of the path, or nil if not found
---@todo Consider caching frequently accessed nodes for performance
---@todo Add support for case-insensitive matching (optional, configurable)
---@todo Add support for path validation before traversal (ensure no empty segments)
---@todo Return more detailed error information (e.g., which segment failed)
function Category:Category_get_node(path)
    -- Throw error in case of missing parameters
    assert(path ~= nil and path ~= "", "Path unspecified!")
    -- Check if path top-level. If yes, GTFO
    if not path:find("/") then 
        return self._category_tree[path]
    end
    -- not top-level: split it!
    local parts = self:Category_split_path(path) -- maybe add error handling?
    -- List of path parts that have already been dealt with
    local full_path_parts = {}
    -- Get the current tree
    local current = self._category_tree
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

---
--- Delete category
---
---@param path string Category path
---@param category_file string Category file to use
---@param journal_file string Journal file to use
---@param is_force? boolean Delete category even if it has items. Will not delete if subcategories are present.
---@param is_nuke? boolean Deep-delete category even if it has items and/or subcategories. Needs `force` to be `true`
---@param is_preview? boolean Whether we are doing a dry run. If unspecified, it's a dry run.
---@return table|boolean items Returns list of ITEMS to be deleted if preview, true on real deletion success and false on error
---@return table|string err Returns response on non-preview deletion or error message. Returns list of categories to be deleted if preview
function Category:Category_delete(path, category_file, journal_file, is_force, is_nuke, is_preview)
    assert(path ~= nil and category_file ~= nil, "Unspecified path and/or category file!")
    
    local state = self._category_index[path]
    if not state then
        return false, string.format("Category %s does not exist!", path)
    end
    
    -- Get the node (rebuild if dirty)
    local node = self:Category_rebuild_node(path)
    if not node then
        return false, string.format("Error retrieving node for category path %s", path)
    end
    
    -- Collect all items in this category and subcategories
    local all_ids = self:Category_get_subcat(path)
    local to_del = {}
    for _, id in ipairs(all_ids) do
        if self._data[id] then
            table.insert(to_del, id)
        end
    end
    
    -- Check for subcategories
    local has_subcats = false
    local subcat_names = {}
    local cats_to_delete = { path }
    
    -- Collect all subcategory paths
    local function collect_all_subcats(current_node, current_path)
        for name, child in pairs(current_node) do
            if name ~= "_releases" then
                has_subcats = true
                table.insert(subcat_names, name)
                local full_path = current_path .. "/" .. name
                table.insert(cats_to_delete, full_path)
                collect_all_subcats(child, full_path)
            end
        end
    end
    collect_all_subcats(node, path)
    
    -- Handle subcategories
    if has_subcats then
        if not is_nuke then 
            return false, string.format(
                "Category %s not deleted: it has subcategories (%s), "..
                "but this is not a \"nuke\" deletion.", 
                path, table.concat(subcat_names, ", ")
            )
        end
    else
        -- No subcategories, check if force is needed
        if #to_del > 0 and not is_force then
            return false, string.format(
                "Category `%s` not deleted: it has %d releases, "..
                "but this is not a \"force\" deletion.", 
                path, #to_del
            )
        end
    end
    
    -- If preview, return what would be deleted
    if is_preview then
        return to_del, cats_to_delete
    end
    
    -- ✅ FIX: Delete categories from tree (bottom-up - deepest first)
    -- Sort by depth (deepest first)
    table.sort(cats_to_delete, function(a, b)
        local depth_a = #self:Category_split_path(a)
        local depth_b = #self:Category_split_path(b)
        return depth_a > depth_b
    end)
    
    -- Delete each category node from the tree
    for _, cat_path in ipairs(cats_to_delete) do
        -- Remove from index
        self._category_index[cat_path] = nil
        -- Remove from tree
        self:Category_delete_node(cat_path)
    end
    
    -- Also remove the root path from index (in case it wasn't removed)
    self._category_index[path] = nil
    
    -- Serialize the category file
    local succ, err = self:Category_serialize(category_file)
    if not succ then return false, err end
    
    -- Actually delete the items from _data
    if #to_del > 0 then
        -- Sort descending so we don't shift indices
        table.sort(to_del, function(a, b) return a > b end)
        local deleted_count = 0
        for _, id in ipairs(to_del) do
            if self._data[id] then
                self:Item_delete(id, journal_file)
                deleted_count = deleted_count + 1
            end
        end
        return to_del, string.format("Deleted %d items", deleted_count)
    end
    
    return {}, string.format("Empty category %s deleted!", path)
end


--- Delete node from category tree
--- 
--- @param path string Category path
function Category:Category_delete_node(path)
    if not path or path == "" then return false end
    
    local parts = self:Category_split_path(path)
    if not next(parts) then return false end
    
    if #parts == 1 then
        -- Top-level category
        self._category_tree[path] = nil
        return true
    end
    
    -- Find the parent
    local parent_path = table.concat(parts, "/", 1, #parts - 1)
    local parent = self:Category_get_node(parent_path)
    if not parent then return false end
    
    local name = parts[#parts]
    parent[name] = nil
    return true
end

--- Mark parents of given category path's respective node dirty in tree
--- 
--- @param path string Category path
function Category:Category_mark_parents_dirty(path)
    local parts, err = self:Category_split_path(path)
    if not parts then return false, err end
    for i = 1, #parts - 1 do
        local parent_path = table.concat(parts, "/", 1, i)
        if self._category_index[parent_path] then
            self._category_index[parent_path].dirty = true
        end
    end
    return true
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
--- 
--[[
function Category:Category_create(path)
    assert(path ~= nil and path ~= "" and self ~= nil, 
    "Path and/or namespace unspecified!")
    if self._category_index[path] and self:Category_rebuild_node(path) then
        return nil, string.format("Category %s already exists!", path)
    end
    -- Add to index if not present
    self._category_index[path] = self._category_index[path] or {}
    if not path:find("/") then --top-level category
        local node = { _releases = {} }
        self._category_tree[path] = node
        return node, nil
    end
    local parts = self:Category_split_path(path)
    local current = self._category_tree
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
]]
function Category:Category_create(path)
    assert(path ~= nil and path ~= "", "Path unspecified!")

    local node = self:Category_get_node(path)
    
    if self._category_index[path] and node then
        return node  -- return node if exists
    end
    -- Add to index if not present
    self._category_index[path] = {}
    
    local parts = self:Category_split_path(path)
    local current = self._category_tree
    local full_path = ""
    
    for i, part in ipairs(parts) do
        full_path = i == 1 and part or (full_path .. "/" .. part)
        
        if not current[part] then
            current[part] = { _releases = {} }
        end
        
        if i == #parts then
            return current[part]
        end
        
        current = current[part]
    end
    
    return nil
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
---@return boolean success True if valid, false if invalid
---@return string result Sanitized path on success, error message on failure
---@todo Consider case sensitivity option (optional, default: case-sensitive)
function Category:Category_process_path(path)
        assert(path ~= nil and path ~= "", "Path unspecified!")
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
        local depth = #self:Category_split_path(path)
        if depth > 5 then 
            return false, string.format("Subcategory %s deeper than"..
                                            " five levels.", path
                                            )
         end
    end
    if not self._category_index[path] then return false, string.format(
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
function Category:Category_split_path(path)
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
---@return boolean success True if save succeeded
---@return string|nil err Error message if save failed
---@todo Add backup before overwriting (rename old file to .bak)
---@todo Add atomic write: write to temp file, then rename
---@todo Add validation: ensure _category_index is not empty before saving
---@todo Add logging: when save happens, how many categories saved
---@todo Add error recovery: if save fails, keep existing file intact
function Category:Category_serialize(filename)
    -- File does not have to exist.
    assert(filename ~= nil and filename ~= "", "File name unspecified!")
    local tmp = filename -- os.tmpname()
    local f, err = io.open (tmp, "w+")
    if f then
        f:write("return {\n")  
        for path, _ in pairs(self._category_index) do
            f:write ("[\""..path.."\"] = {},\r\n")
        end
        f:write("}\n")
        f:flush()
        f:close()
        --os.rename(tmp, filename)
        return true
    end
    return false, err -- serialisation failed
end


--- ---- GET ITEMS (NON-RECURSIVE) ----
--- Returns all items at a specific category node 
--- (not including subcategories)
--- 
--- @param path string The category path
--- @return table IDs Array of release IDs at this category
function Category:Category_get_no_subcat(path)
    assert(path ~= nil and path ~="" and self ~= nil, 
        "Path unspecified!")
    -- No state checking. rebuild_node returns anyway if no rebuild needed
    local result = self:Category_rebuild_node(path)
    if not result then return {} end
    return result._releases
end

--- ---- GET ITEMS (RECURSIVE) ----
--- Returns all items in a category INCL. all its subcategories
--- 
--- @param path string The category path
--- @return table IDs Array of all release IDs found
function Category:Category_get_subcat(path)
    assert(path ~= nil and path ~= "", "Path unspecified!")
    
    local result = self:Category_rebuild_node(path)
    if result then
        local child_names = {}
        for k, _ in pairs(result) do
            if k ~= "_releases" then
            end
        end
    end

    if not result then return {} end
    
    local list = {}
    local seen = {}  -- ✅ Track which IDs we've already added
    
    -- Recursively collect IDs from this node and all children
    local function collect(node)
        -- Add IDs from current node
        for _, id in ipairs(node._releases or {}) do
            -- ✅ Only add if we haven't seen this ID before
            if not seen[id] then
                seen[id] = true
                table.insert(list, id)
            end
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
--- @return table|boolean node Returns the rebuilt node on success, false if not found
function Category:Category_rebuild_node(path)
    assert(path ~= nil and path ~= "", "Path unspecified!")
    
    local entry = self._category_index[path]
    if not entry then return false end
    
    -- Get or create the node
    local node = self:Category_get_node(path)
    if not node then
        node = self:Category_create(path)
        if not node then return false end
    end
    
    if not entry.dirty and #(node._releases or {}) > 0 then
        return node
    end
    
    -- Clear old releases
    node._releases = {}
    
    -- Scan ALL releases and add ones that belong to this category OR subcategories
    for id, item in ipairs(self._data) do
        -- Check if the item's category is this path OR a subcategory of it
        if item.category == path or item.category:find("^" .. path .. "/") then
            table.insert(node._releases, id)
        end
    end
    
    -- Update state
    entry.dirty = false
    return node
end

function Category:Category_rename(old_path, new_path, journal_file)
    if self._category_index[new_path] then
        return false, "Target category already exists."
    elseif not self._category_index[old_path] then
        return false, "Source category does not exist."
    end
    -- First, get all IDs in old_path
    local node_old = self:Category_rebuild_node(old_path)
    local rel = node_old._releases or {}
    if not next(rel) then
        return false, "Source category is empty."
    end
    -- Check if node has subcategories
    local has_subcats = false
    for key, _ in pairs(node_old) do
        if key ~= "_releases" then
            has_subcats = true
            return false, "Categories that have subcategories cannot be renamed."
        end
    end
    local node_new = self:Category_create(new_path)

    table.move(node_old._releases, 1, #node_old._releases, 1, node_new._releases)
    for id, _ in ipairs(node_new._releases) do
        self:Item_move_id(id, new_path, journal_file)
    end
    self._category_index[new_path] = { dirty = false }

    local parent_path = old_path:match("^(.*)/[^/]+$")
    if parent_path then
        -- It's a subcategory, remove from parent's children
        local parent = self:Category_rebuild_node(parent_path)
        if parent then
            local name = old_path:match("^.*/([^/]+)$")
            parent[name] = nil
        end
    else
        -- It's top-level, remove directly
        self._category_tree[old_path] = nil
    end
    self._category_index[old_path] = nil
    return node_new._releases, node_old._releases
end

return Category
-- for some reason emmylua still sees stuff as undefined, but only with this file, not with categories.lua or journal.lua etc.
---@class Category
