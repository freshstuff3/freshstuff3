-- core/ui.lua
---@class UI

local UI = {}

--- Build a category tree containing only the specified IDs
--- Node names are full paths for easy copy-pasting
--- 
--- @param ids table List of release IDs to include
--- @return table Nested tree structure with full paths
function UI:tree_from_ids(ids)
    -- Group IDs by category
    local category_map = {}
    
    for _, id in ipairs(ids) do
        local item = Item._data[id]
        if item then
            local cat = item.category
            if not category_map[cat] then
                category_map[cat] = {}
            end
            table.insert(category_map[cat], id)
        end
    end
    
    -- Build nested tree
    local function build_tree(cat_paths, depth)
        depth = depth or 1
        local result = {}
        
        -- Group categories at this depth level
        local level_map = {}
        for cat_path, ids in pairs(cat_paths) do
            local parts = Category.split_path(cat_path)
            if #parts >= depth then
                local name = parts[depth]
                if not level_map[name] then
                    level_map[name] = {}
                end
                level_map[name][cat_path] = ids
            end
        end
        
        -- Build nodes
        for name, submap in pairs(level_map) do
            -- Find the full path for this node
            local full_path = nil
            for cat_path, _ in pairs(submap) do
                local parts = Category.split_path(cat_path)
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
                _path = full_path or name,  -- Full path
                _releases = {},
                _children = {},
            }
            
            -- Check for direct releases at this level
            for cat_path, ids in pairs(submap) do
                if cat_path == full_path then
                    for _, id in ipairs(ids) do
                        table.insert(node._releases, id)
                    end
                end
            end
            
            -- Recurse into deeper levels
            local has_deeper = false
            for cat_path, _ in pairs(submap) do
                if #Category.split_path(cat_path) > depth then
                    has_deeper = true
                    break
                end
            end
            
            if has_deeper then
                node._children = build_tree(submap, depth + 1)
            end
            
            table.insert(result, node)
        end
        
        table.sort(result, function(a, b)
            return (a._path or "") < (b._path or "")
        end)
        
        return result
    end
    
    return build_tree(category_map, 1)
end

--- Render tree as ASCII with full paths
function UI:render_tree(node, prefix, is_last)
    prefix = prefix or ""
    
    local function render_node(n, pre, last)
        local path = n._path or "root"
        local releases = n._releases or {}
        local count = #releases
        
        if path ~= "root" then
            local connector = last and "└── " or "├── "
            print(pre .. connector .. path .. " (" .. count .. " releases)")
        end
        
        if path ~= "root" and count > 0 then
            local rel_pre = pre .. (last and "    " or "│   ")
            for i, id in ipairs(releases) do
                local rel_connector = (i == #releases) and "└── " or "├── "
                local item = Item._data[id]
                local label = item and item.title or "unknown"
                print(rel_pre .. rel_connector .. "  ID:" .. id .. " " .. label)
            end
        end
        
        local children = {}
        for key, value in pairs(n) do
            if key ~= "_releases" and key ~= "_path" then
                table.insert(children, value)
            end
        end
        table.sort(children, function(a, b)
            return (a._path or "") < (b._path or "")
        end)
        
        local child_pre = pre
        if path ~= "root" then
            child_pre = pre .. (last and "    " or "│   ")
        end
        
        for i, child in ipairs(children) do
            render_node(child, child_pre, i == #children)
        end
    end
    
    render_node(node, prefix, is_last or true)
end

--- Get list of paths from tree
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

return UI