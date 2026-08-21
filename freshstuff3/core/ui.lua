--- core/ui.lua
--- 
local UI = {}
--- # UI rendering module for FreshStuff3
--- 
--- Provides ASCII tree, Markdown table, and detailed item views.
--- 
--- ## PUBLIC: UNIFIED RENDERER
--- Unified renderer for all output formats
--- 
--- This is the main entry point for rendering. It handles:
---   - "tree"  : ASCII tree with emojis (default)
---   - "md"    : Markdown table with ID, Category, Title, Nick, Age
---   - "detail": Detailed multi-line view with full item info
--- All rendering functions take a list of release IDs
--- and return formatted strings ready for display.
---
--- Usage:
---   local UI = require "core.ui"
---   local Category = require "core.category"
---   
---   -- Get IDs (e.g., latest 10 items)
---   local ids = {}
---   for i = #Item._data, math.max(1, #Item._data - 9), -1 do
---       table.insert(ids, i)
---   end
---   
---   -- Render as tree (default)
---   local output = UI.render(ids, Item)
---   
---   -- Or get category IDs and render as markdown
---   local music_ids = Category:get_subcat("Music", Item)
---   local output = UI.render(music_ids, Item, "md", "st")
--- 
-- Output formats (via render()):
--   - `tree`   - ASCII tree with emojis (📁 categories, ✅ releases)
--   - `md`    - Markdown table with ID, Category, Title, Nick, Age
--   - `detail` - Detailed multi-line view with full item info
--
-- Sort options (for md/detail):
---   sn  : sort by nick (ascending)
---   sw  : sort by when (ascending)
---   st  : sort by title (ascending)
---   rsn : reverse sort by nick
---   rsw : reverse sort by when (newest first)
---   rst : reverse sort by title
---   r   : reverse by ID
--- 
--- ## MARKDOWN OUTPUT
--- 
--- ```text
--- | ID | Category | Title |
--- |----|----------|-------|
--- | 1 | Music | Greatest Hits Vol 1 |
--- | 2 | Music | Ambient Sounds |
--- | 3 | Movies | Classic Collection |
--- | 4 | TV | Complete Series |
--- | 5 | Music/Metal | Eternal Darkness |
--- | 6 | Music/Jazz | Midnight Sax |
--- | 7 | Music/Jazz | Blue Note Sessions |
--- | 8 | Music/Classical | Beethoven's 9th |
--- | 9 | Music/Classical | Moonlight Sonata |
--- | 10 | Movies/Horror | The Cabin In The Woods |
--- | 11 | Movies/Horror | Friday Night Massacre |
--- | 12 | Movies/Sci-Fi | Interstellar Voyage |
--- | 13 | Movies/Sci-Fi | The Android's Dream |
--- | 1293 | ID not found | ID not found |
--- ```
---
--- ## DETAILED LIST
--- 
--- ```text
--- ===============================================================================
--- Details of requested item(s):
--- ===============================================================================
--- 
--- -------------------------------------------------------------------------------
--- ID: 2
--- Category: Music
--- Title: Ambient Sounds
--- Added by: Audiophile
--- Added on: 2026-Jul-13 13:58 (age: 4.6 weeks)
--- -------------------------------------------------------------------------------
--- ID: 8
--- Category: Music/Classical
--- Title: Beethoven's 9th
--- Added by: Maestro
--- Added on: 2026-Jul-13 20:58 (age: 4.5 weeks)
--- -------------------------------------------------------------------------------
--- ID: 7
--- Category: Music/Jazz
--- Title: Blue Note Sessions
--- Added by: SmoothOperator
--- Added on: 2026-Jul-13 19:58 (age: 4.6 weeks)
--- -------------------------------------------------------------------------------
--- ID: 3
--- Category: Movies
--- Title: Classic Collection
--- Added by: FilmBuff
--- Added on: 2026-Jul-13 14:58 (age: 4.6 weeks)
--- -------------------------------------------------------------------------------
--- ```
--- 
--- # ASCII TREE
--- 
--- ```text
---    ├── Music (2 releases)
---    │   ├── ID:1 Greatest Hits Vol 1
---    │   └── ID:2 Ambient Sounds
---    │   ├── Music/Classical (2 releases)
---    │   │   ├── ID:9 Beethoven's 9th
---    │   │   └── ID:10 Moonlight Sonata
---    │   │   └── Music/Classical/Romantic (2 releases)
---    │   │       ├── ID:21 Liebesträume
---    │   │       └── ID:22 Nocturnes
---    │   └── Music/Metal (3 releases)
---    │       └── ID:5 Screaming Into The Void
---    └── TV (1 releases)
---        ├── ID:4 Complete Series
---        └── TV/Animation (2 releases)
---            ├── ID:15 The Animated Series
---            └── ID:16 Epic Ninja Saga
--- 
--- ```
--- ## HANDLING OF NONEXISTENT IDs
--- 
--- If such IDs are specified, something like this is appended to each view:
--- ```text
--- The following IDs have not been found in the database:
--- -------------------------------------------------------------------------------
--- 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46
--- ```
--- 
---@param ids table Array of IDs to render
---@param format? "tree"|"md"|"detail" default: "tree"
---@param sort_order? "sn"|"sw"|"st"|"rsn"|"rsw"|"rst"|"r" Sort order 
---@return string|false result Formatted output, or false on error
---@todo return headers and content separately, content as array maybe
---
---
---
function UI:UI_render(ids, format, sort_order)
    if type(ids) == "number" then
        ids = { ids }
    end
    -- format = format or "tree"
    if format == "tree" then
        return self:UI_render_tree(ids)
    end
    local sort = {
        sn = function(a, b) return a.nick > b.nick end,
        sw = function(a, b) return a.when > b.when end,
        st = function(a, b) return a.title > b.title end,
        rsn = function(a, b) return b.nick > a.nick end,
        rsw = function(a, b) return b.when > a.when end,
        rst = function(a, b) return b.title > a.title end,
        r = function(a, b) return a._id > b._id end
    }
    if sort_order and not sort[sort_order] then return false end
    assert(type(ids) == "table",
        "Invalid ID list!"
        )
    local result, tmp, notfound = 
    {}, {}, {}
    for _, id in ipairs(ids) do
        local obj = self._data[id]
        if obj then
            obj._id = id
            table.insert(tmp, obj)
        else
            table.insert(notfound, id)
        end
    end
    if sort_order then
        table.sort(tmp, sort[sort_order])
    end
    for _, piece in ipairs(tmp) do
        local d = (os.time() - piece.when) / 86400
        if format == "md" then
            table.insert(result,
            string.format("| %d | %s | %s | %s | %s |",
            piece._id,           
            piece.category,
            piece.title,
            piece.nick,
            --os.date("%Y-%b-%d %H:%M", -- TODO: weeks/days etc., not date
            --piece.when
            d < 28 and string.format("%.0fd", d) or 
                string.format("%.1fw", d/7)
                ))
        elseif format == "detail" then
            table.insert(result, string.format("✅ ID: %d\r\n"..
            "\t📁 Category: %s\r\n\t📝 Title: %s\r\n\t👤 Added by: %s\r\n\t📅 Added on:"..
            " %s (%s ago)",
            piece._id,
            piece.category,
            piece.title,
            piece.nick,
            os.date("%Y-%b-%d %H:%M",
            piece.when),
            d < 28 and string.format("%.0f days", d) or 
                string.format("%.1f weeks", d/7)
                ))
        end
    end   
    if #notfound > 0 then 
        table.insert(result, "\r\nThe following IDs have not been "..
                        "found in the database: ")
        table.insert(result, table.concat(notfound, ", "))
    end
    if format == "md" then
        table.insert(result, 1,
        "| ID | Category | Title | Nick | Age | "..
        "\r\n|----|----------|-------|------|-----|")
        return table.concat(result, "\r\n")
    elseif format == "detail" then
        local sep = string.rep("=",80)
        table.insert(result, 1, sep.."\r\nDetails of requested item(s):"..
        "\r\n"..sep.."\r\n")
        return table.concat(result, "\r\n"..string.rep("-", 80).."\r\n")
    end
    return false
end

--- # Render category tree with release counts only (no individual releases)
--- 
--- This function returns a visually structured tree with:
--- - 📁 for categories
--- - Release counts per category (including subcategories)
--- - Full category paths for easy copy-paste
--- 
--- @param path? string Starting path (default: root)
--- @param prefix? string Indentation prefix (used internally)
--- @param is_last? boolean Whether this is the last child (used internally)
--- @return string tree Formatted tree with category counts
--- Render category tree with release counts only (no individual releases)
function UI:UI_render_category_tree(path, prefix, is_last)
    prefix = prefix or ""
    is_last = is_last or true
    
    local start_path = type(path) == "string" and path or ""
    
    local function get_count(category_path)
        local ids = self:Category_get_subcat(category_path)
        return #ids
    end
    
    local function render_node(node, current_path, pre, last, is_root)
        local lines = {}
        
        -- ✅ If this is the root node and we have a path, display it first
        if is_root and start_path ~= "" then
            local count = get_count(start_path)
            table.insert(lines, pre .. "📁 " .. start_path .. " (" .. count .. " releases)")
            -- Update pre for children
            pre = pre .. "    "
        end
        
        -- Get direct children
        local children = {}
        for key, value in pairs(node) do
            if key ~= "_releases" then
                table.insert(children, { name = key, node = value })
            end
        end
        table.sort(children, function(a, b) return a.name < b.name end)
        
        for i, child in ipairs(children) do
            local child_path = current_path == "" and child.name or current_path .. "/" .. child.name
            local is_last_child = (i == #children)
            local connector = is_last_child and "└── " or "├── "
            local count = get_count(child_path)
            
            table.insert(lines, pre .. connector .. "📁 " .. child_path .. " (" .. count .. " releases)")
            
            local child_pre = pre .. (is_last_child and "    " or "│   ")
            local child_lines = render_node(child.node, child_path, child_pre, is_last_child, false)
            for _, line in ipairs(child_lines) do
                table.insert(lines, line)
            end
        end
        
        return lines
    end
    
    local start_node
    if start_path == "" then
        start_node = self._category_tree
        if not start_node or not next(start_node) then
            return "No categories found"
        end
    else
        start_node = self:Category_get_node(start_path)
        if not start_node then
            return "Category not found: " .. start_path
        end
    end
    
    local result = render_node(start_node, start_path, prefix, is_last, true)
    return table.concat(result, "\r\n")
end

-- ============================================================
-- INTERNAL: TREE BUILDING
-- ============================================================

--- Build a category tree containing only the specified release IDs
--- 
--- This function takes a list of release IDs and builds a nested tree
--- structure containing only those IDs, preserving the category hierarchy.
--- Empty parent categories are omitted.
--- 
--- @param ids table List of release IDs to include (e.g., search results, latest items)
--- @return table tree Nested tree structure where each node has:
---   - _path: Full category path (e.g., "Music/Metal/Death")
---   - _releases: Array of release IDs directly in this category
---   - _children: Array of child category nodes
--- @return table not_found IDs that don't exist in the database
function UI:UI_tree_from_ids(ids)
    assert(type(ids) == "table" and type(self) == "table" 
            and self._data ~= nil and #ids ~= 0,
            "Empty or invalid ID list!"
            )
    -- Group IDs by category path
    local category_map, not_found = {}, {}
    for _, id in ipairs(ids) do
        local item = self._data[id]
        if item then
            local cat = item.category
            if not category_map[cat] then
                category_map[cat] = {}
            end
            table.insert(category_map[cat], id)
        else
            table.insert(not_found, id)
        end
    end
    
    -- Recursively build nested tree from category_map
    local function build_tree(cat_paths, depth)
        depth = depth or 1
        local result = {}
        
        -- Group categories at this depth level
        local level_map = {}
        local Category = require "core.category"
        for cat_path, ids in pairs(cat_paths) do
            local parts = self:Category_split_path(cat_path)
            if #parts >= depth then
                local name = parts[depth]
                if not level_map[name] then
                    level_map[name] = {}
                end
                level_map[name][cat_path] = ids
            end
        end
        
        -- Build nodes for each category at this level
        for name, submap in pairs(level_map) do
            -- Build full path from parts up to this depth
            local full_path = nil
            for cat_path, _ in pairs(submap) do
                local parts = self:Category_split_path(cat_path)
                if #parts >= depth then
                    local path_parts = {}
                    for i = 1, depth do
                        table.insert(path_parts, parts[i])
                    end
                    full_path = table.concat(path_parts, "/")
                    break
                end
            end
            
            local node = {
                _path = full_path or name,  -- Full path for copy-paste
                _releases = {},
                _children = {},
            }
            
            -- Add releases that belong directly at this level
            for cat_path, ids in pairs(submap) do
                if cat_path == full_path then
                    for _, id in ipairs(ids) do
                        table.insert(node._releases, id)
                    end
                end
            end
            
            -- Recurse into deeper levels if any subcategories exist
            local has_deeper = false
            for cat_path, _ in pairs(submap) do
                if #self:Category_split_path(cat_path) > depth then
                    has_deeper = true
                    break
                end
            end
            
            if has_deeper then
                node._children = build_tree(submap, depth + 1)
            end
            
            table.insert(result, node)
        end
        
        -- Sort categories alphabetically for consistent display
        table.sort(result, function(a, b)
            return (a._path or "") < (b._path or "")
        end)
        
        return result
    end
    
    return build_tree(category_map, 1), not_found, _
end

-- ============================================================
-- INTERNAL: ASCII TREE RENDERER
-- ============================================================

--- Render a tree as ASCII art with full paths and emojis
--- 
--- This function returns a visually structured tree with:
--- - 📁 for categories
--- - ✅ for releases
--- - Full category paths for easy copy-paste
--- - Hierarchical indentation with connecting lines
--- 
--- @param ids table Array of IDs to render tree from
--- @param prefix? string Indentation prefix (used internally)
--- @param is_last? boolean Whether this is the last child (used internally)
--- @return string tree Formatted tree with specified IDs
function UI:UI_render_tree(ids, prefix, is_last)
    local node, not_found = self:UI_tree_from_ids(ids, self)
    prefix = prefix or ""
    local msg_arr = {}
    
    local function render_node(n, pre, last)
        local path = n._path or "root"
        local releases = n._releases or {}
        local count = #releases
        
        -- Print category node with 📁
        if path ~= "root" then
            local connector = last and "└── " or "├── "
            if count > 0 then
                table.insert(msg_arr, pre .. connector .. "📁 " .. path .. " (" .. count .. " releases)")
            else
                table.insert(msg_arr, pre .. connector .. "📁 " .. path)
            end
        end
        
        -- Print releases under this category with 🎵
        if path ~= "root" and count > 0 then
            local rel_pre = pre .. (last and "    " or "│   ")
            for i, id in ipairs(releases) do
                local rel_connector = (i == #releases) and "└── " or "├── "
                local item = self._data[id]
                local label = item and item.title or "unknown"
                table.insert(msg_arr, rel_pre .. rel_connector .. "✅ ID: " .. id .. " " .. label)
            end
        end
        
        -- Collect and sort child nodes
        local children = {}
        for key, value in pairs(n) do
            if key ~= "_releases" and key ~= "_path" then
                table.insert(children, value)
            end
        end
        table.sort(children, function(a, b)
            return (a._path or "") < (b._path or "")
        end)
        
        -- Recursively render children
        local child_pre = pre
        if path ~= "root" then
            child_pre = pre .. (last and "    " or "│   ")
        end
        
        for i, child in ipairs(children) do
            render_node(child, child_pre, i == #children)
        end
    end
    
    render_node(node, prefix, is_last or true)

    if #not_found > 0 then 
        table.insert(msg_arr, "\r\nThe following IDs have not been "..
                        "found in the database: ")
        table.insert(msg_arr, table.concat(not_found, ", "))
    end
    return table.concat(msg_arr, "\r\n")
end

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

--- Extract all category paths from a tree
--- 
--- @param node table The tree node to traverse
--- @param result table Accumulator for paths (optional)
--- @return table Array of full category paths
function UI:UI_get_tree_paths(node, result)
    result = result or {}
    local function collect(n)
        if n._path and n._path ~= "root" then
            table.insert(result, n._path)
        end
        for key, child in pairs(n) do
            if key ~= "_releases" and key ~= "_path" then
                collect(child)
            end
        end
    end
    collect(node)
    return result
end

--- Split a comma-separated list of IDs or an ID range to a list of IDs.
--- 
--- Examples:
---   "1,2,3"     → {1, 2, 3}
---   "1-6"       → {1, 2, 3, 4, 5, 6}
---   "5-1"       → {5, 4, 3, 2, 1} (reverse range)
--- 
--- @param str string String to split (e.g., "1,2,3" or "1-6")
--- @return table|false result Array of IDs, or false on invalid string
function UI:UI_split_ids(str)
    local result = {}
    -- ID list, comma-separated
    if str:find("%d+%,%d+.*") and not str:find("%-") then 
        str = str:gsub("%s+","") -- remove whitespaces
        for id in str:gmatch("(%d+)") do
            table.insert(result, tonumber(id))
        end
    -- ID range
    elseif str:find("%d+%-%d+") then -- ID range
        local a, b = str:match("(%d+)%-(%d+)")
        a = tonumber(a); b = tonumber(b)
        local x = a > b and -1 or 1
        for i = a, b, x do
            table.insert(result, i)
        end 
    end
    return result
end

return UI
