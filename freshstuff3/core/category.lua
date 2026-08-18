-- core/Category_lua

return {

--- # CATEGORY MANAGEMENT CORE MODULE FOR FRESHSTUFF3
---
--- ## I. CRUD OPERATIONS FOR CATEGORIES
--- 
--- 
--- ### CATEGORY INITIALISATION
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
--- ```lua
---   return {
---     ["Music"] = {},
---     ["Music/Metal"] = {},
---     ["Music/Metal/Death"] = {},
---   }
--- ```
---
---@param filename string Path to the categories file (e.g., "data/categories.lua")
---@todo If file loading fails, create from scratch from _data
---@todo Add validation: ensure _data is not nil before iterating---@todo Add support for migrating old category formats (if needed)
Category_init = function(self, category_file)
    self._category_index, self._category_tree = {}, {}
    
    -- Load from file
    local go, err = loadfile(category_file)
    if go then 
        local loaded = go()
        if type(loaded) == "table" then
            for path, _ in pairs(loaded) do
                self._category_index[path] = {}
            end
        end
    end
    
    -- Return early if _data empty
    if next(self._data) then 
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
                local node
                if self:Category_create(current_path) then
                    node = self:Category_get_node(current_path)
                end
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
    end
    
    -- Mark all categories as clean
    for path, _ in pairs(self._category_index) do
        self._category_index[path] = self._category_index[path] or {}
        self._category_index[path].dirty = false
    end
    
            -- ✅ Optional serialization (like journal_path)
    if category_file then
        local ok, err = self:Category_serialize(category_file)
        if not ok then
                -- Rollback on serialization failure
                return nil, "Serialization failed: " .. err
        end   
    end
end,

--- ### DELETE CATEGORY
---
--- Deletes a category and optionally its releases and subcategories.
--- Supports preview mode, force deletion (with releases), and nuke deletion (with subcategories).
---
--- Behavior:
---   - If category doesn't exist: Returns error
---   - If category is empty (no releases, no subcats): Deletes immediately (no force needed)
---   - If category has releases but no subcats and is_force = false: Returns error with release count
---   - If category has releases but no subcats and is_force = true: Deletes category and all releases
---   - If category has subcategories and is_nuke = false: Returns error with subcategory list
---   - If category has subcategories and is_nuke = true: Deletes category, all subcategories, and all releases
---   - If is_preview = true: Returns what would be deleted without actually deleting anything
---
--- State matrix for _category_index[category]:
---   nil                    -- Category doesn't exist
---   {}                     -- Category exists, empty (no releases)
---   { dirty = false }      -- Category exists, has releases, clean
---   { dirty = true }       -- Category exists, has releases, dirty
---
--- Deletion modes:
---   1. Empty category deletion (no flags needed):
---      - Category exists but has no releases and no subcategories
---      - Removes from _category_index and _category_tree
---      - Serializes category file
---
---   2. Force deletion (is_force = true):
---      - Deletes category even if it has releases
---      - Only works if category has NO subcategories
---      - Deletes all releases in category from _data
---      - Removes from _category_index and _category_tree
---      - Serializes category file
---
---   3. Nuke deletion (is_nuke = true):
---      - Deletes category AND all subcategories recursively
---      - Deletes ALL releases in category and subcategories from _data
---      - Removes all subcategories from _category_index and _category_tree
---      - Serializes category file
---
---   4. Preview mode (is_preview = true):
---      - Shows what would be deleted
---      - Returns list of items and categories that would be affected
---      - NO changes are made to _data, _category_index, or _category_tree
---
--- Examples:
--- ```lua
---   -- Preview deletion (dry run)
---   local ids, cats = Category:Category_delete("Music/Rock", "cats.dat", "journal.dat", false, false, true)
---   -- ids = {1, 2, 3}, cats = {"Music/Rock"}
---
---   -- Force delete category with releases (no subcategories)
---   local ids, result = Category:Category_delete("Music/Rock", "cats.dat", "journal.dat", true, false, false)
---   -- ids = {1, 2, 3}, result = "Deleted category Music/Rock (3 items)"
---
---   -- Nuke delete category with subcategories
---   local ids, result = Category:Category_delete("Music", "cats.dat", "journal.dat", true, true, false)
---   -- ids = {1,2,3,4,5,6,7,8,9}, result = "Deleted category Music (9 items)"
---
---   -- Try to delete non-empty category without force (fails)
---   local ids, err = Category:Category_delete("Music/Rock", "cats.dat", "journal.dat", false, false, false)
---   -- ids = false, err = "Category `Music/Rock` not deleted: it has 3 releases, but this is not a 'force' deletion."
---
---   -- Try to delete category with subcategories without nuke (fails)
---   local ids, err = Category:Category_delete("Music", "cats.dat", "journal.dat", true, false, false)
---   -- ids = false, err = "Category Music not deleted: it has subcategories (Rock, Jazz, Classical), but this is not a 'nuke' deletion."
--- ```
---@param path string Category path to delete
---@param category_file string Path to category file for serialization
---@param journal_file string Path to journal file for journalling deletions
---@param is_force? boolean Delete category with releases (only if no subcategories). Default: false
---@param is_nuke? boolean Delete category, subcategories, and all releases recursively. Requires is_force = true. Default: false
---@param is_preview? boolean Dry run - return what would be deleted without making changes. Default: true
---@return table|boolean items Returns:
---   - On preview: table of item IDs that would be deleted
---   - On success: table of deleted item IDs
---   - On error: false
---@return table|string result Returns:
---   - On preview: table of category paths that would be deleted
---   - On success: string message with deletion summary
---   - On error: string error message
---@todo Add backup creation before deletion (create backup journal)
---@todo Add --imeanit confirmation flag for actual deletion (prevent accidents)
---@todo Add recovery/restore capability from backup
---@todo Add dry-run with detailed summary (items, categories, subcategories)
---@todo Add progress indication for large deletions (1000+ items)
---@todo Add validation to prevent deleting root categories (optional)
---@todo Add logging of deletion operations for audit trail
---@todo Consider moving deleted items to a "trash" category instead of permanent deletion
---@todo Add confirmation prompt for nuke deletions (safety) -- for Lua only
---@todo Update all parent categories' dirty flags after deletion -- taken care of by Item:add // b_e
Category_delete = function (self, path, category_file, journal_file, is_force, is_nuke, is_preview)
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
                "❌ Category %s not deleted: it has subcategories (%s), "..
                "but this is not a \"nuke\" deletion.", 
                path, table.concat(subcat_names, ", ")
            )
        end
    else
        -- No subcategories, check if force is needed
        if #to_del > 0 and not is_force then
            return false, string.format(
                "❌ Category `%s` not deleted: it has %d releases, "..
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
end,

--- ### CREATE CATEGORY
--- 
--- Creates the node in _category_tree, but ONLY if parent category exists
--- 
--- @param path string The category path to create (e.g., "Music/Metal/Death")
--- @return boolean node Returns true if already exists, false on failure
--- @return string? error Upon failure, returns error message.
--- 
--- 
Category_create = function (self, path, category_file)
    assert(path ~= nil and path ~= "", "❌ Category unspecified!")

    if self._category_index[path] then
        return true -- return true if exists
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
        
        if i == #parts then -- successfully created node in tree
            -- Optional serialisation (like journal_path)
            if category_file then
                local ok, err = self:Category_serialize(category_file)
                if not ok then
                    -- Rollback on serialisation failure
                    self._category_index[path] = nil
                    return false, "Serialization failed: " .. err
                end
                return true
            end
            return current[part]
        end
        
        current = current[part]
    end
    -- Roll back if we got here
    self._category_index[path] = nil
    return false, "❌ Failed to create category: " .. path
end,

--- ### CATEGORY PATH SANITISER/VALIDATOR
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
---       Spaces are NOT checked here (handled by %S+ in command parsing).
---       Emptiness is NOT checked here (handled by caller).
---
---@param path string Category path to validate (e.g., "Music/Metal/Death")
---@return string|false success False on error, true if category exists
---@return string result Sanitized path on success, error message on failure
---@todo Consider case sensitivity option (optional, default: case-sensitive)
Category_process_path = function (self, path)
    assert(path ~= nil and path ~= "", "❌ Path unspecified!")
    -- string longer than 70 chars
    -- This should be hardcoded as for messages (ie. expected use case), 
    -- the display is the bottleneck
    if #path > 70 then 
        return false, string.format("❌ Category path %s too long. "..
        "Maximum 70 characters.", path) 
    end

    if path:find("_releases", 1, true) then
        return false, "The string _releses is not allowed in category names/paths!"
    end

    -- Replace trailing and leading slashes, 
    -- also multiple consecutive slashes
    path = path:gsub( "^/+", ""):gsub( "/+$", ""):gsub("//+", "/")
    if path:find ("/") then -- subcategory, check how deep
        local depth = #self:Category_split_path(path)
        if depth > 5 then 
            return false, string.format("❌ Subcategory %s deeper than"..
                                            " five levels.", path
                                            )
         end
    end
    if not self._category_index[path] then return true, string.format(
        "❌ Category %s not found in categories. It needs to be created"..
        " first. ", path
        )
    end
    return true, path 
end,

--- ### SAVE CATEGORIES TO FILE
---
--- Serializes the category index (_category_index) to a Lua file.
--- The category tree (_category_tree) is NOT serialised as it will be
--- rebuilt into a fullly clean state from _data (i.e. RAM) on startup anyway.
---
--- Why only _category_index:
---   - _category_index is a flat list of all categories that exist
---   - _category_tree is a nested structure derived from _data
---   - On startup, _category_tree is rebuilt from _data
---   - _category_index provides fast existence checks without traversing _data
---
--- File format:
--- 
--- ```lua
---   return {
---     ["Music"] = {},
---     ["Music/Metal"] = {},
---     ["Music/Metal/Death"] = {},
---   }
--- ```
--- 
--- Empty tables are used as placeholders. The dirty state is NOT persisted;
--- a clean tree is built during startup based upon _data.
--- 
---
---@param filename string File path to save to (e.g., "data/categories.lua")
---@return boolean success True if save succeeded
---@return string|nil err Error message if save failed
---@todo Add backup before overwriting (rename old file to .bak)
---@todo Add atomic write: write to temp file, then rename
---@todo Add validation: ensure _category_index is not empty before saving
---@todo Add logging: when save happens, how many categories saved
---@todo Add error recovery: if save fails, keep existing file intact
Category_serialize = function (self, filename)
    -- File does not have to exist.
    assert(filename ~= nil and filename ~= "", "❌ File name unspecified!")
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
end,

--- ###  GET ITEMS (NON-RECURSIVE) 
--- 
--- Returns all items at a specific category node, not including subcategories
--- 
--- @param path string The category path
--- @return table IDs Array of release IDs at this category
Category_get_no_subcat = function(self, path)
    assert(path ~= nil and path ~="" ,"Path unspecified!")
    -- No state checking. rebuild_node returns anyway if no rebuild needed
    local result = self:Category_rebuild_node(path)
    if not result then return {} end
    return result._releases
end,

--- ###  GET ITEMS (RECURSIVE) 
--- 
--- Returns all items in a category path recursively, i.e. INCLUDING all its 
--- subcategories
--- 
--- @param path string The category path
--- @return table|false result 
--- - Array of all release IDs found. 
--- - False on failed retrieval
Category_get_subcat = function(self, path)
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
end,

--- ### RENAME CATEGORY
---
--- Renames an existing category to a new path. All releases in the category
--- are updated to the new category path. The category must be a leaf node
--- (no subcategories) to be renamed.
---
--- #### Behavior:
---   - Validates both old and new paths
---   - Checks that old category exists and new category doesn't
---   - Verifies category has releases (cannot rename empty categories)
---   - Verifies category has NO subcategories (leaf node only)
---   - Creates new category node
---   - Moves all release IDs from old node to new node
---   - Updates each release's category field in _data
---   - Removes old category from tree and index
---   - Marks new category as clean (dirty = false)
---   - Journals each move operation
---
--- #### Limitations:
---   - Cannot rename empty categories
---   - Cannot rename to an already existing category
---   - Only leaf nodes (categories with no subcategories) can be renamed
---
--- #### Examples:
---   -- Rename "Music/Rock" to "Music/RockAndRoll"
---   Category:Category_rename("Music/Rock", "Music/RockAndRoll", JOURNAL_FILE)
---
---   -- Rename "Movies/SciFi" to "Movies/ScienceFiction"
---   Category:Category_rename("Movies/SciFi", "Movies/ScienceFiction", JOURNAL_FILE)
---
---   -- This will fail because "Music" has subcategories
---   Category:Category_rename("Music", "Music2", JOURNAL_FILE)  -- ❌ Error
---
---@param old_path string Current category path (must exist, must be leaf)
---@param new_path string New category path (must not exist)
---@param journal_file string Path to journal file for journalling moves
---@return table|false node_new The new category node on success, false on error
---@return string|nil error Error message on failure, nil on success
---@todo Add support for renaming categories with subcategories (recursive rename)
---@todo Add validation to prevent renaming to a path that would create a cycle
---@todo Consider adding an option to rename empty categories (currently not allowed)
---@todo Add logging for rename operations for debugging
---@todo Handle concurrent operations (lock category during rename)
---@todo Add support for renaming top-level categories (currently allowed)
---@todo Consider updating category_index for all subcategories if recursive rename is implemented
Category_rename = function(self, old_path, new_path, journal_file, category_file)
    if self._category_index[new_path] then
        return false, "❌ Target category already exists."
    elseif not self._category_index[old_path] then
        return false, "❌ Source category does not exist."
    end

    -- First, get all IDs in old_path
    local node_old = self:Category_rebuild_node(old_path)
    if not node_old then
        return false, string.format("❌ Failed to retrieve node for path %s", old_path)
    end

    -- Check if node has subcategories
    local has_subcats = false
    for key, _ in pairs(node_old) do
        if key ~= "_releases" then
            has_subcats = true
            return false, "❌ Categories that have subcategories cannot be renamed."
        end
    end
    local node_new = self:Category_create(new_path)

    -- Move items to new category
    table.move(node_old._releases, 1, #node_old._releases, 1, node_new._releases)
    for id, _ in ipairs(node_new._releases) do
        self:Item_move_id(id, new_path, journal_file)
    end
    self._category_index[new_path] = { dirty = false }

    -- 
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
    -- ✅ Optional serialization (like journal_path)
     if category_file then
        local ok, err = self:Category_serialize(category_file)
        if not ok then
            ---@bug No rollback on serialisation failure
            return false, "Serialization failed: " .. err
        end
    end
    return node_new._releases, node_old._releases
end,

--- # CATEGORY TREE LOGIC
--- 
--- Will be moved into its separate CatTree namespace and file
--- 
--- ## State matrix 
--- 
--- for _category_index[category]:
--- 
--- ```lua
---   nil                    -- Category doesn't exist
--- 
---   {}                     -- Category exists, empty (no releases)
--- 
---   { dirty = false }      -- Category exists, has releases, clean
--- 
---   { dirty = true }       -- Category exists, has releases, dirty (needs rebuild)
--- ```
--- 
--- Categories are marked dirty upon item addition, deletion or move.
--- 
--- When moving, old and new category both need to be marked dirty.
--- 
--- 
--- ## IN-MEMORY TREE STRUCTURE
--- 
--- ```lua
--- _category_tree = {
---    ["Movies"] = {
---        _releases = { 1 },              -- IDs directly in Movies
---        ["Horror"] = {
---            _releases = { 2, 3, 4 },    -- IDs in Movies/Horror
---        },
---        ["Sci-Fi"] = {
---            _releases = { 5, 6 },       -- IDs in Movies/Sci-Fi
---        },
---    },
---    ["Music"] = {
---        _releases = { 7 },              -- IDs directly in Music
---        ["Classical"] = {
---            _releases = { 8 },          -- IDs directly in Music/Classical
---            ["Romantic"] = {
---                _releases = { 9 },      -- IDs in Music/Classical/Romantic
---            },
---        },
---        -- ... etc
---    },
--- }
--- ```
--- 
--- 
--- ## METHODS
---  
--- ### Rebuild a single dirty category tree node from _data
--- 
--- @param path string Category path to rebuild
--- @return table|boolean node Returns the rebuilt node on success, false if not found
Category_rebuild_node = function(self, path)
    assert(path ~= nil and path ~= "", "❌ Path unspecified!")
    
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
end,

--- ### Split category path into parts
--- 
--- @param path string category path
--- @return table|false parts Returns an array of parts, 
--- ordered fromm top level downwards.
Category_split_path = function (self, path)
    assert(type(path) =="string" and path ~= "", "Invalid or no path" )
    -- Check if top-level category
    if not path:find("/") then; return { path }; end
    -- Not-top-level category, split required
    local parts = {}
    for part in path:gmatch("([^/]+)") do
        table.insert(parts, part)
    end
    return parts
end,

--- ### Delete node from category tree
--- 
--- @param path string Category path
Category_delete_node = function (self, path)
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
end,

--- ### Mark parents of given category path's respective node dirty in tree
--- 
--- @param path string Category path
--- 
Category_mark_parents_dirty = function (self, path)
    local parts, err = self:Category_split_path(path)
    if not parts then return false, err end
    for i = 1, #parts - 1 do
        local parent_path = table.concat(parts, "/", 1, i)
        if self._category_index[parent_path] then
            self._category_index[parent_path].dirty = true
        end
    end
    return true
end,

--- ### Get node
---
--- Retrieves a category node from the category tree by traversing the given path.
--- Returns the node at the end of the path, or nil if any segment is missing.
---
--- Behaviour:
---   - Top-level path (e.g., "Music"): Direct lookup in _category_tree
---   - Nested path (e.g., "Music/Metal/Death"): Traverses each segment
---   - If any segment is missing: Returns nil immediately
---   - Returns the full node table containing _releases and child nodes
---
--- The node structure as per above:
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
Category_get_node = function (self, path)
    -- Throw error in case of missing parameters
    assert(path ~= nil and path ~= "", "❌ Path unspecified!")
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
end,

-- Helper: Ensure all parent categories exist in both tree and index
Category_ensure_path = function (self, path)
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
end,

Tree_ensure_path = function (self, path); return self:Category_ensure_path(self, path); end,
Tree_get_node = function (self, path); return self:Category_get_node(self, path); end,
Tree_mark_parents_dirty = function (self, path); return self:Category_mark_parents_dirty(self, path); end,
Tree_rebuild_node = function (self, path); return self:Category_rebuild_node(self, path); end,
Tree_delete_node = function (self, path); return self:Category_delete_node(self, path); end,
Tree_split_path = function (self, path); return self:Category_split_path(self, path); end,

}
