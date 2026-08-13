-- core/ui.lua
-- ASCII tree renderer for category hierarchies
-- 
-- This module builds and renders category trees from lists of release IDs.
-- It's designed for UI display, search results, and "latest items" views.
-- 
-- Usage:
--   local UI = require "core.ui"
--   local Category = require "core.category"
--   
--   -- Get IDs (e.g., latest 10 items)
--   local ids = {}
--   for i = #Item._data, math.max(1, #Item._data - 9), -1 do
--       table.insert(ids, i)
--   end
--   
--   -- Build and render tree
--   local tree = UI:tree_from_ids(ids)
--   UI:render_tree(tree)
--   
--   -- Or get category IDs via Category module
--   local music_ids = Category:get_subcat("Music", Item)
--   local music_tree = UI:tree_from_ids(music_ids)
--   UI:render_tree(music_tree)
-- 
-- 
---@todo create "X days/weeks ago" from unix timestamp
---@todo return headers and content separately, content as array, 
--- maybe 3 return values. but should only return array on markdown output
--- I think the items to be processed need to be sort()ed PRIOR to processing
---
---@note This replaces hardcoded emoji mapping in UI:render_tree()
---      with data-driven emoji stored alongside categories.
---@see Category:set_emoji()
---@see Category:get_emoji()
---@see UI:render_tree() - should use Category:get_emoji()

---@class UI
local UI = {}

--- Build a category tree containing only the specified release IDs
--- 
--- This function takes a list of release IDs and builds a nested tree
--- structure containing only those IDs, preserving the category hierarchy.
--- Empty parent categories are omitted.
--- 
--- @param ids table List of release IDs to include (e.g., search results, latest items)
--- @return table Nested tree structure where each node has:
---   - _path: Full category path (e.g., "Music/Metal/Death")
---   - _releases: Array of release IDs directly in this category
---   - _children: Array of child category nodes
--- 
--- @usage -- Latest 40 items
---   local ids = {}
---   for i = #Item._data, math.max(1, #Item._data - 39), -1 do
---       table.insert(ids, i)
---   end
---   local tree = UI:tree_from_ids(ids)
---   UI:render_tree(tree)
---   
---   -- Search results
---   local search_ids = {}
---   for id, item in ipairs(Item._data) do
---       if string.find(item.title:lower(), "symphony", 1, true) then
---           table.insert(search_ids, id)
---       end
---   end
---   local search_tree = UI:tree_from_ids(search_ids)
---   UI:render_tree(search_tree)
function UI:tree_from_ids(ids, namespace)
    assert(type(ids) == "table" and type(namespace) == "table" 
            and namespace._data ~= nil and #ids ~= 0,
            "Empty or missing namespace or ID list, or namespace has no"..
            " _data field!"
            )
    -- Group IDs by category path
    local category_map = {}
    
    for _, id in ipairs(ids) do
        local item = namespace._data[id]
        if item then
            local cat = item.category
            if not category_map[cat] then
                category_map[cat] = {}
            end
            table.insert(category_map[cat], id)
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
            local parts = Category:split_path(cat_path)
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
                local parts = Category:split_path(cat_path)
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
                if #Category:split_path(cat_path) > depth then
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
    
    return build_tree(category_map, 1)
end

--- Render a tree as ASCII art with full paths
--- 
--- This function returns a visually structured tree with:
--- - Full category paths for easy copy-paste
--- - Release IDs and titles under each category
--- - Hierarchical indentation with connecting lines
--- 
--- 
--- 
--- @usage local tree = UI:tree_from_ids(latest_ids); 
--- print(UI:render_tree(tree))
---   
--[[OUTPUT
   ├── Music (2 releases)
   │   ├── ID:1 Greatest Hits Vol 1
   │   └── ID:2 Ambient Sounds
   │   ├── Music/Classical (2 releases)
   │   │   ├── ID:9 Beethoven's 9th
   │   │   └── ID:10 Moonlight Sonata
   │   │   └── Music/Classical/Romantic (2 releases)
   │   │       ├── ID:21 Liebesträume
   │   │       └── ID:22 Nocturnes
   │   └── Music/Metal (3 releases)
   │       └── ID:5 Screaming Into The Void
   └── TV (1 releases)
       ├── ID:4 Complete Series
       └── TV/Animation (2 releases)
           ├── ID:15 The Animated Series
           └── ID:16 Epic Ninja Saga
]]
--- 
--- 
--- @param node table The tree node to render (from UI:tree_from_ids())
--- @param namespace table The namespace to be used
--- @param prefix? string Indentation prefix for current level (used internally)
--- @param is_last? boolean Whether this is the last child (used internally)
--- Render a tree as ASCII art with full paths and emojis
--- 
--- This function returns a visually structured tree with:
--- - 📁 for categories
--- - 🎵 for releases
--- - Full category paths for easy copy-paste
--- - Release IDs and titles under each category
--- 
--- @param node table The tree node to render
--- @param namespace table The namespace to be used
--- @param prefix? string Indentation prefix (used internally)
--- @param is_last? boolean Whether this is the last child (used internally)
function UI:render_tree(node, namespace, prefix, is_last)
    assert(type(namespace) == "table" 
            and namespace._data ~= nil,
            "Empty or missing namespace, or namespace has no _data field!"
            )
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
                local item = namespace._data[id]
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
    return msg_arr
end

--- Extract all category paths from a tree
--- 
--- @param node table The tree node to traverse
--- @param result table Accumulator for paths (optional)
--- @return table Array of full category paths
--- 
--- @usage
---   local tree = UI:tree_from_ids(latest_ids)
---   local paths = UI:get_tree_paths(tree)
---   -- paths = {"Music", "Music/Classical", "Music/Metal", "TV"}
function UI:get_tree_paths(node, result)
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

--- Create markdown table from array of IDs
--- 
---@param ids table array of IDs
---@param namespace table namespace to be used
---@return string result The resulting markdown table
---@todo add date or nick, but not immportant
---@todo sorting, also not important as tree is preferred
--[[OUTPUT
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
]]
function UI:render_markdown(ids, namespace)
    assert(type(ids) == "table" and type(namespace) == "table" 
        and namespace._data ~= nil and #ids > 0,
        "Empty or missing namespace or ID list, or namespace has no"..
        " _data field!"
        )
    local result = "| ID | Category | Title |\r\n"..
    "|----|----------|-------|\r\n"
    for _, id in ipairs(ids) do
        if namespace._data[id] then
            result = result..string.format("| %d | %s | %s |\r\n",
            id,
            namespace._data[id].category,
            namespace._data[id].title
            )
        else
            result = result..string.format("| %d | %s | %s |\r\n",
            id,
            "ID not found",
            "ID not found"
            )
        end
    end
    return result
end

--- Get details on items
--- 
--- @param ids table Array of IDs
--- @param namespace table Namespace to be used
--- @return string result 
--[[OUTPUT
================================================================================
Details of requested item(s):
================================================================================
ID: 1
Category: Music
Title: Greatest Hits Vol 1
Added by: MusicLover
Added on: 2026-Jul-13 12:58
--------------------------------------------------------------------------------
ID: 2
Category: Music
Title: Ambient Sounds
Added by: Audiophile
Added on: 2026-Jul-13 13:58
--------------------------------------------------------------------------------
ID: 3
Category: Movies
Title: Classic Collection
Added by: FilmBuff
Added on: 2026-Jul-13 14:58
--------------------------------------------------------------------------------
ITEM WITH ID 1293 DOES NOT EXIST IN DATABASE
--------------------------------------------------------------------------------
]]
function UI:get_items_details(ids, namespace)
    assert(type(ids) == "table" and type(namespace) == "table" 
        and namespace._data ~= nil and #ids > 0,
        "Empty or missing namespace or ID list, or namespace has no"..
        " _data field!"
        )
    local sep = string.rep("=", 80)
    local sep2 = string.rep("-", 80)
    local result = sep.."\r\nDetails of requested item(s):"..
    "\r\n"..sep.."\r\n"
    for _, id in ipairs(ids) do
        if namespace._data[id] then
            result = result..string.format("ID: %d\r\n"..
            "Category: %s\r\nTitle: %s\r\nAdded by: %s\r\nAdded on: %s",
            id,
            namespace._data[id].category,
            namespace._data[id].title,
            namespace._data[id].nick,
            os.date("%Y-%b-%d %H:%M", namespace._data[id].when
            ))
        else
            result = result..string.format("ITEM WITH "..
            "ID %d DOES NOT EXIST IN DATABASE", id
            )
        end
        result = result.."\r\n"..sep2.."\r\n"
    end
    return result 
end

--- Show releases newer than ...
--- 
--- A timeframe is specified. d is for days, w for weeks, m for months. 
--- Supports "today" and "yesterday". Also see below.
--- 
--- @param param string today, yesterday, 5d, 6w, 1m etc
--- @param namespace table Namespace to be used.
--- @return table result Returns array of IDs as result
function UI:get_newer_than(param, namespace)
    local result = {}
    local conversion = {
        ["today"] = "0d",
        ["yesterday"] = "1d"
    }
    param = conversion[param] or param
    local number, mult = param:match("^(%d+)([dwm])$")
    assert(number ~= "" and mult ~= "")
    number = tonumber(number)
    local multiplier = { d = 24*3600, w = 7*24*3600, m = 30*24*3600 }
    local seconds = number * multiplier[mult]
    local cutoff
    -- Special case: "today" means start of today (00:00:00)
    if number == 0 and mult == "d" then
        local now = os.time()
        local today_start = os.time({
            year = os.date("%Y", now),
            month = os.date("%m", now),
            day = os.date("%d", now),
            hour = 0,
            min = 0,
            sec = 0
        })
        cutoff = today_start
    else
        cutoff = os.time() - seconds
    end
    for id, obj in ipairs(namespace._data) do
        if obj.when >= cutoff then
            table.insert(result, id)
        end
    end
    return result
end

return UI
