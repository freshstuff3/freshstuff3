--- core/ui.lua
--- Data visualiser core module for FreshStuff3

--[[ 
# Data visualiser core module for FreshStuff3
(part 1 of 2)

Provides ASCII tree, Markdown table, and detailed item views.

## PUBLIC: UNIFIED RENDERER
Unified renderer for all output formats

This is the main entry point for rendering. It handles:
  - "tree"  : ASCII tree with emojis (default)
  - "md"    : Markdown table with ID, Category, Title, Nick, Age
  - "detail": Detailed multi-line view with full item info
All rendering functions take a list of release IDs
and return formatted strings ready for display.

Usage:
  -- Get IDs (e.g., latest 10 items)
  local ids = {}
  for i = -- fix this later
      table.insert(ids, i)
  end
  
  -- Render as tree (default)
  local output = UI.render(ids, Item)
  
  -- Or get category IDs and render as markdown
  local music_ids = Category:get_subcat("Music", Item)
  local output = UI.render(music_ids, Item, "md", "st")

 Output formats (via render()):
   - `tree`   - ASCII tree with emojis (📁 categories, ✅ releases)
   - `md`    - Markdown table with ID, Category, Title, Nick, Age
   - `detail` - Detailed multi-line view with full item info

 Sort options (for md/detail):

 Default sort order is oldest first.
    -  c   : chronological (oldest first) - default
    -  r   : reverse chronological (newest first)
    -  n   : sort by nick (ascending)
    -  rn  : reverse sort by nick (descending)
    -  t   : sort by title (ascending)
    -  rt  : reverse sort by title (descending)


## MARKDOWN OUTPUT

```text
    | ID | Category | Title |
    |----|----------|-------|
    | 1 | Music | Greatest Hits Vol 1 |
    | 2 | Music | Ambient Sounds |
    | 3 | Movies | Classic Collection |
    | 4 | TV | Complete Series |
    | 5 | Music/Metal | Eternal Darkness |
    | 6 | Music/Jazz | Midnight Sax |
    | 7 | Music/Jazz | Blue Note Sessions |
    | 8 | Music/Classical | Beethoven's 9th |
    | 9 | Music/Classical | Moonlight Sonata |
    | 10 | Movies/Horror | The Cabin In The Woods |
    | 11 | Movies/Horror | Friday Night Massacre |
    | 12 | Movies/Sci-Fi | Interstellar Voyage |
    | 13 | Movies/Sci-Fi | The Android's Dream |
    | 1293 | ID not found | ID not found |
```

## DETAILED LIST

```text
[freshstuff3-releases]> Hello! You summoned me...
--------------------------------------------------
🔬 DETAILED VIEW OF ALL THE ITEMS IN THE 19,88,643,9999 RANGE
↕️ SORTING ORDER: chronological / order of added IDs (default)

Details of requested item(s):

--------------------------------------------------------------------------------
✅ ID: 19
        📁 Category: Music/Rock/Classic-Rock
        📝 Title: Hey Jude 
        👤 Added by: Audiophile
        📅 Added on: 2025-Aug-09 14:11 (54.0 weeks ago)
--------------------------------------------------------------------------------
✅ ID: 88
        📁 Category: TV/Animation/Anime
        📝 Title: Dream 
        👤 Added by: RobotLover
        📅 Added on: 2025-Feb-14 05:50 (79.2 weeks ago)
--------------------------------------------------------------------------------
✅ ID: 643
        📁 Category: Music/Jazz/Fusion
        📝 Title: Midnight Basss 
        👤 Added by: JazzLover
        📅 Added on: 2025-Oct-23 05:52 (43.4 weeks ago)
--------------------------------------------------------------------------------

The following IDs have not been found in the database:
--------------------------------------------------------------------------------
9999
```

# ASCII TREE OF CATEGORIES, NO ID LIST

```
    [freshstuff3-releases]> Hello! You summoned me...
    --------------------------------------------------
    🌳 TREE VIEW OF Movies

    📁 Movies (322 releases)
        ├── 📁 Movies/Comedy (69 releases)
        │   ├── 📁 Movies/Comedy/Rom-Com (20 releases)
        │   ├── 📁 Movies/Comedy/Satire (19 releases)
        │   └── 📁 Movies/Comedy/Slapstick (14 releases)
        ├── 📁 Movies/Drama (83 releases)
        │   ├── 📁 Movies/Drama/Contemporary (24 releases)
        │   ├── 📁 Movies/Drama/Crime (22 releases)
        │   └── 📁 Movies/Drama/Period (18 releases)
        ├── 📁 Movies/Horror (69 releases)
        │   ├── 📁 Movies/Horror/Psychological (22 releases)
        │   ├── 📁 Movies/Horror/Slasher (14 releases)
        │   └── 📁 Movies/Horror/Supernatural (11 releases)
        └── 📁 Movies/Sci-Fi (74 releases)
            ├── 📁 Movies/Sci-Fi/Cyberpunk (10 releases)
            ├── 📁 Movies/Sci-Fi/Post-Apocalyptic (22 releases)
            └── 📁 Movies/Sci-Fi/Space-Opera (20 releases)
```

### TREE WITH IDS:

```
[freshstuff3-releases]> Hello! You summoned me...
--------------------------------------------------
🌳 TREE VIEW OF ALL THE ITEMS IN Music (TOTAL: 408)
↕️ SORTING ORDER: chronological / order of added IDs (default)

└── 📁 Music (5 releases)
    ├── ✅ ID: 48 Chronicles Eternal 132
    ├── ✅ ID: 176 Civilization 692
    ├── ✅ ID: 712 Nightmare Volume 2 Stories 180
    ├── ✅ ID: 871 The Matrix 435
    ├── ✅ ID: 938 Essential Revolutionary Echoes 154
    ├── 📁 Music/Classical (3 releases)
    │   ├── ✅ ID: 46 Myth Volume 3 Infinite 6
    │   ├── ✅ ID: 82 The Shawshank Redemption 203
    │   ├── ✅ ID: 205 Stories Essential 152
    │   ├── 📁 Music/Classical/Baroque (2 releases)
    │   │   ├── ✅ ID: 61 Modern Volume 2 255
    │   │   ├── ✅ ID: 296 The End The Best Of Revolutionary 289
    │   ├── 📁 Music/Classical/Modern (2 releases)
    │   │   ├── ✅ ID: 45 Reality 379
    │   │   ├── ✅ ID: 111 Classic Epic 782
    │   └── 📁 Music/Classical/Romantic (1 releases)
    │       └── ✅ ID: 1549 Volume 2 299
    ├── 📁 Music/Electronic (2 releases)
    │   ├── ✅ ID: 94 Awakening 629
    │   ├── ✅ ID: 137 Tales 240
    │   ├── 📁 Music/Electronic/House (1 releases)
    │   │   ├── ✅ ID: 90 Ultimate Collection 612
    │   └── 📁 Music/Electronic/Techno (2 releases)
    │       ├── ✅ ID: 318 Awakening Volume 2 585
    │       ├── ✅ ID: 388 Rebirth Epic 605
```

### HANDLING OF NONEXISTENT IDs

If such IDs are specified, something like this is appended to each view:

```
The following IDs have not been found in the database:
-------------------------------------------------------------------------------
27, 28, 29, 30, 31, 32, 33, 34, 35
```
 ]]

local UI = {}

--- ============================================================
--- CONSTANTS
--- ============================================================

--- Sort order mapping
local SORT_MAP = {
    c   = function(a, b) return a._id < b._id end,  -- chronological (default)
    sn  = function(a, b) return a.nick < b.nick end,
    st  = function(a, b) return a.title < b.title end,
    rsn = function(a, b) return a.nick > b.nick end,
    rst = function(a, b) return a.title > b.title end,
    r   = function(a, b) return a._id > b._id end
}

--- Sort order names for display
local SORT_NAMES = {
    c = "chronological (oldest on top)",
    sn  = "owner's nick",
    st  = "item title",
    rsn = "owner's nick, reverse",
    rst = "item title, reverse",
    r   = "reverse chronological (newest on top)",
}

-- ============================================================
-- HEADER HELPERS (internal)
-- ============================================================

--- Get format display name
---@param format string "tree"|"md"|"detail"
---@return string
local function get_format_name(format)
    local names = {
        tree = "🌳 TREE VIEW",
        md = "📋 MARKDOWN VIEW",
        detail = "🔬 DETAILED VIEW"
    }
    return names[format] or "VIEW"
end

--- Get sort order display line
---@param sort_order string|nil
---@return string
local function get_sort_line(sort_order)
    local name = SORT_NAMES[sort_order] or SORT_NAMES["c"]
    return "↕️ SORTING ORDER: " .. name
end

--- Join header parts with separator
---@param parts table Array of strings
---@return string
local function join_header(parts)
    -- Filter out empty parts
    local filtered = {}
    for _, part in ipairs(parts) do
        if part ~= "" then
            table.insert(filtered, part)
        end
    end
    return table.concat(filtered, "\r\n") .. "\r\n" .. string.rep("=", 50) .. "\r\n"
end

-- ============================================================
-- HEADER BUILDERS (public)
-- ============================================================

--- Build header for search results
---@param query string
---@param format string
---@param sort_order string|nil
---@return string
function UI:UI_header_search(query, format, sort_order)
    local parts = {
        "🔎 SEARCH RESULTS",
        "🧐 QUERY: " .. query,
        "👀 VIEW: " .. get_format_name(format),
        get_sort_line(sort_order),
    }
    return join_header(parts)
end

--- Build header for latest items
---@param count number
---@param total number
---@param format string
---@param sort_order string|nil
---@return string
function UI:UI_header_latest(count, total, format, sort_order)
    local label = (count >= total) and "ALL THE ITEMS" or string.format("THE LATEST %d ITEMS", count)
    if count >= total then
        label = string.format("%s ( TOTAL: %d )", label, total)
    end
    local parts = {
        get_format_name(format) .. " OF " .. label,
        get_sort_line(sort_order),
    }
    return join_header(parts)
end

--- Build header for ID range
---@param range string
---@param format string
---@param sort_order string|nil
---@return string
function UI:UI_header_range(range, format, sort_order)
    local parts = {
        get_format_name(format) .. " OF ALL THE ITEMS IN THE " .. range .. " RANGE",
        get_sort_line(sort_order),
    }
    return join_header(parts)
end

--- Build header for "newer than" time window
---@param time_window string
---@param format string
---@param sort_order string|nil
---@return string
function UI:UI_header_newer(time_window, format, sort_order)
    local number, mult = time_window:match("^(%d+)([dwm])$")
    local mult_tbl = { d = "day(s)", w = "week(s)", m = "month(s)" }
    local label = string.format("ITEMS FROM THE LAST %d %s", tonumber(number) or 0, mult_tbl[mult] or "day(s)")
    local parts = {
        get_format_name(format) .. " OF " .. label,
        get_sort_line(sort_order),
    }
    return join_header(parts)
end

--- Build header for category view
---@param path string
---@param count number
---@param format string
---@param sort_order string|nil
---@return string
function UI:UI_header_category(path, count, format, sort_order)
    local parts = {
        get_format_name(format) .. " OF ALL THE ITEMS IN " .. path .. " (TOTAL: " .. count .. ")",
        get_sort_line(sort_order),
    }
    return join_header(parts)
end

--- Build header for deletion preview and result
---@return string
function UI:UI_header_delete(is_preview)
    local label = is_preview and "PREVIEW" or "COMPLETE"
    return "CATEGORY DELETION " .. label .. "\r\n" .. string.rep("=", 50) .. "\r\n"
end

--- Build header for category tree
---@param path? string Category path (optional)
---@return string
function UI:UI_header_flat_tree(path)
    if path and path ~= "" then
        return "🌳 FLAT TREE VIEW OF CATEGORY " .. path .. "\r\n" .. string.rep("=", 50) .. "\r\n"
    else
        return "🌳 FLAT TREE VIEW OF ALL THE CATEGORIES:\r\n" .. string.rep("=", 50) .. "\r\n"
    end
end

-- ============================================================
-- PUBLIC HELPERS
-- ============================================================

--- Get sort order display name
---@param sort_order string|nil
---@return string
function UI:UI_get_sort_name(sort_order)
    return SORT_NAMES[sort_order] or SORT_NAMES["c"]
end

--- Apply sort to items
---@param items table
---@param sort_order string|nil
---@return table sorted_items
function UI:UI_apply_sort(items, sort_order)
    -- Fall back to chronological if sort_order is nil or invalid
    -- or if sort_func is not found in SORT_MAP (unlikely)
    local sort_key = sort_order or "c"
    local sort_func = SORT_MAP[sort_key] or SORT_MAP["c"]
    local sorted = {}
    for _, item in ipairs(items) do
        table.insert(sorted, item)
    end
    table.sort(sorted, sort_func)
    return sorted
end

---@param ids table Array of IDs to render
---@param format? "tree"|"md"|"detail" default: "tree"
---@param sort_order? "sn"|"st"|"rsn"|"rst"|"r"|"c" Sort order:
--- - "c"   : chronological (oldest first) - default
--- - "r"   : reverse chronological (newest first)
--- - "sn"  : sort by nick (ascending)
--- - "rsn" : reverse sort by nick (descending)
--- - "st"  : sort by title (ascending)
--- - "rst" : reverse sort by title (descending)
---  
---@return string|false result Formatted output, or false on error
---@todo return headers and content separately, content as array maybe
---
function UI:UI_render(ids, format, sort_order)
    if type(ids) == "number" then
        ids = { ids }
    end
    assert(type(ids) == "table",
        "Invalid ID list!"
        )

    if not format or format == "tree" then
        return self:UI_render_tree(ids)
    end

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

    local sorted = self:UI_apply_sort(tmp, sort_order)
    for _, piece in ipairs(sorted) do
        local d = (os.time() - piece.when) / 86400
        if format == "md" then
            table.insert(result,
            string.format("| %d | %s | %s | %s | %s |",
            piece._id,           
            piece.category,
            piece.title,
            piece.nick,
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
    local ret = false
    if format == "md" then
        table.insert(result, 1,
        "| ID | Category | Title | Nick | Age | "..
        "\r\n| -- | -------- | ----- | ---- | --- |")
        ret = table.concat(result, "\r\n")
    elseif format == "detail" then
        ret = table.concat(result, "\r\n"..string.rep("-", 80).."\r\n")
    end
    return ret
end

--[[
# Render category tree with ID counts only (no individual IDs)

This function returns a visually structured tree with:
    - 📁 for categories
    - Release counts per category (including subcategories)
    - Full category paths for easy copy-paste 
]]
---@param categories table Array of category paths
---@param root_path? string Starting path (default: root)
---@return table tree_data
function UI:UI_build_flat_tree(categories, root_path)
    local tree = { _path = "", _count = 0, _children = {} }
    
    for _, cat in ipairs(categories) do
        -- Skip if not under root_path
        if root_path and root_path ~= "" then
            if cat ~= root_path and not cat:find("^" .. root_path .. "/") then
                goto continue
            end
        end
        
        local parts = self:Tree_split_path(cat)
        local current = tree
        for i, part in ipairs(parts) do
            if not current._children[part] then
                local full_path = table.concat(parts, "/", 1, i)
                current._children[part] = { _path = full_path, _count = 0, _children = {} }
            end
            current = current._children[part]
        end
        -- Count releases in this category
        local ids = self:Category_get_subcat(cat)
        current._count = #ids
        
        ::continue::
    end
    
    return tree
end

--- Render category tree from raw category data
---@param categories table Array of category paths
---@param root_path? string Starting path (default: root)
---@param prefix? string Indentation prefix (used internally)
---@param is_last? boolean Whether this is the last child (used internally)
---@return string tree Formatted tree with category counts
function UI:UI_render_flat_tree(categories, root_path, prefix, is_last)
    prefix = prefix or ""
    is_last = is_last or true
    
    if not categories or #categories == 0 then
        return "No categories found"
    end
    
    -- Build tree from raw data
    local tree = self:UI_build_flat_tree(categories, root_path)
    
    -- Render tree
    local function render_node(node, pre, last, is_root)
        local lines = {}
        local path = node._path or ""
        local count = node._count or 0
        
        -- Only render non-root nodes
        if path ~= "" then
            local connector = last and "└── " or "├── "
            local count_str = count == 1 and " (1 release)" or " (" .. count .. " releases)"
            table.insert(lines, pre .. connector .. "📁 " .. path .. count_str)
            pre = pre .. (last and "    " or "│   ")
        end
        
        -- Render children
        local children = {}
        for key, value in pairs(node._children or {}) do
            table.insert(children, value)
        end
        table.sort(children, function(a, b) return (a._path or "") < (b._path or "") end)
        
        for i, child in ipairs(children) do
            local child_lines = render_node(child, pre, i == #children, false)
            for _, line in ipairs(child_lines) do
                table.insert(lines, line)
            end
        end
        
        return lines
    end
    
    -- If root_path specified, show it as the root node
    local result = {}
    if root_path and root_path ~= "" then
        -- Find the root node in the tree
        local function find_node(node, target)
            if node._path == target then
                return node
            end
            for _, child in pairs(node._children or {}) do
                local found = find_node(child, target)
                if found then return found end
            end
            return nil
        end
        local root_node = find_node(tree, root_path)
        if root_node then
            local child_lines = render_node(root_node, "", true, false)
            for _, line in ipairs(child_lines) do
                table.insert(result, line)
            end
        else
            return "Category not found: " .. root_path
        end
    else
        -- Render all categories
        local child_lines = render_node(tree, "", true, true)
        for _, line in ipairs(child_lines) do
            table.insert(result, line)
        end
    end
    
    return table.concat(result, "\r\n")
end

--[[ 
INTERNAL: TREE BUILDING

Build a category tree containing only the specified release IDs

This function takes a list of release IDs and builds a nested tree
structure containing only those IDs, preserving the category hierarchy.
Empty parent categories are omitted.
]]
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
            local parts = self:Tree_split_path(cat_path)
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
                local parts = self:Tree_split_path(cat_path)
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
                if #self:Tree_split_path(cat_path) > depth then
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

--[[
INTERNAL: ASCII TREE RENDERER

Render a tree as ASCII art with full paths and emojis

This function returns a visually structured tree with:
- 📁 for categories
- ✅ for releases
- Full category paths for easy copy-paste
- Hierarchical indentation with connecting lines ]]
--- 
--- @param ids table Array of IDs to render tree from
--- @param prefix? string Indentation prefix (used internally)
--- @param is_last? boolean Whether this is the last child (used internally)
--- @return string tree Formatted tree with specified IDs
function UI:UI_render_tree(ids, prefix, is_last)
    local node, not_found = self:UI_tree_from_ids(ids, self)
    prefix = prefix or ""
    local msg_arr = {}
    
    local function render_node(node, pre, last)
        local path = node._path or "root"
        local releases = node._releases or {}
        local count = #releases
        
        -- Print category node 
        if path ~= "root" then
            local connector = last and "└── " or "├── "
            if count > 0 then
                table.insert(msg_arr, pre .. connector .. "📁 " .. path .. " (" .. count .. " releases)")
                local rel_pre = pre .. (last and "    " or "│   ")
                for i, id in ipairs(releases) do
                    -- Print releases under this category
                    local rel_connector = (i == #releases) and "└── " or "├── "
                    local item = self._data[id]
                    local label = item and item.title or "unknown"
                    table.insert(msg_arr, rel_pre .. rel_connector .. "✅ ID: " .. id .. " " .. label)
                end
            else
                table.insert(msg_arr, pre .. connector .. "📁 " .. path)
            end
        end
        
        -- Collect and sort child nodes
        local children = {}
        for key, value in pairs(node) do
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

return UI
