-- core/ui.lua
-- Add these formatting helper functions to ui.lua

--- Format deletion preview for display
--- Converts raw deletion data into a formatted preview message
---
---@param data table { items = table, categories = table }
---@param path string Category path
---@param is_preview boolean Whether this is a preview
---@return string formatted output
function UI:UI_format_deletion_preview(data, path, is_preview)
    local lines = {
        is_preview and "CATEGORY DELETION PREVIEW" or "CATEGORY DELETION COMPLETE",
        string.rep("=", 50),
        string.format("Category: %s", path or "unknown"),
        string.format("Items affected: %d", #(data.items or {})),
        string.format("Categories affected: %d", #(data.categories or {})),
    }
    
    if #(data.categories or {}) > 1 then
        table.insert(lines, "")
        table.insert(lines, "Subcategories:")
        for _, cat in ipairs(data.categories or {}) do
            if cat ~= path then
                table.insert(lines, string.format("  - %s", cat))
            end
        end
    end
    
    if #(data.items or {}) > 0 then
        table.insert(lines, "")
        table.insert(lines, "Items:")
        local count = 0
        for _, id in ipairs(data.items or {}) do
            if count >= 20 then
                table.insert(lines, string.format("  ... and %d more", #(data.items or {}) - 20))
                break
            end
            local item = self._data[id]
            if item then
                table.insert(lines, string.format("  [%d] %s", id, item.title))
                count = count + 1
            end
        end
    end
    
    if #(data.items or {}) == 0 and #(data.categories or {}) <= 1 then
        table.insert(lines, "")
        table.insert(lines, "⚠️  Empty category - nothing to delete")
    end
    
    return table.concat(lines, "\r\n")
end

--- Format deletion result for display
---
---@param data table { items = table, categories = table, errors = table }
---@param path string Category path
---@return string formatted output
function UI:UI_format_deletion_result(data, path)
    local lines = {
        "CATEGORY DELETION COMPLETE",
        string.rep("=", 50),
        string.format("Category: %s", path or "unknown"),
        string.format("Items deleted: %d", #(data.items or {})),
        string.format("Categories deleted: %d", #(data.categories or {})),
    }
    
    if #(data.errors or {}) > 0 then
        table.insert(lines, "")
        table.insert(lines, "⚠️  Errors:")
        for _, err in ipairs(data.errors or {}) do
            table.insert(lines, string.format("  %s", err))
        end
    end
    
    if #(data.items or {}) > 0 and #(data.items or {}) <= 20 then
        table.insert(lines, "")
        table.insert(lines, "Deleted items:")
        for _, item in ipairs(data.items or {}) do
            table.insert(lines, string.format("  [%s] %s", 
                item.id or "?",
                item.title or "unknown"
            ))
        end
    end
    
    return table.concat(lines, "\r\n")
end

-- core/ui.lua
-- UI rendering module for FreshStuff3

local UI = {}

--- # PUBLIC: UNIFIED RENDERER
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
---@param ids table Array of IDs to render
---@param format? "tree"|"md"|"detail" default: "tree"
---@param sort_order? "sn"|"sw"|"st"|"rsn"|"rsw"|"rst"|"r" Sort order 
---@return string|false result Formatted output, or false on error
function UI:UI_render(ids, format, sort_order)
    if type(ids) == "number" then
        ids = { ids }
    end
    format = format or "tree"
    
    if format == "tree" then
        return self:UI_render_tree(ids)
    end
    
    -- Get structured data first
    local data, not_found = self:UI_render_data(ids, format, sort_order)
    if not data then
        return false
    end
    
    -- Format the structured data
    return self:UI_format(data, format, not_found)
end

--- Render items as structured data (not formatted strings)
--- Returns a table that can be further manipulated or formatted
---
---@param ids table Array of release IDs
---@param format? "md"|"detail"|"list" (tree is handled separately)
---@param sort_order? string Sort order
---@return table|false result Structured data table
---
---@usage
--- local data = UI:UI_render_data({1,2,3}, "md", "rsw")
--- -- data = { headers = {...}, rows = {...}, metadata = {...} }
--- -- Then: UI:UI_format(data, "markdown") or modify data.rows
function UI:UI_render_data(ids, format, sort_order)
    format = format or "md"
    
    -- Normalize input
    if type(ids) == "number" then
        ids = { ids }
    end
    
    if type(ids) ~= "table" or #ids == 0 then
        return false
    end
    
    -- Collect items
    local items = {}
    local not_found = {}
    
    for _, id in ipairs(ids) do
        local obj = self._data[id]
        if obj then
            local age = (os.time() - obj.when) / 86400
            table.insert(items, {
                id = id,
                category = obj.category,
                title = obj.title,
                nick = obj.nick,
                when = obj.when,
                age_days = age,
                age_display = age < 28 and string.format("%.0fd", age) or string.format("%.1fw", age/7),
                timestamp = os.date("%Y-%b-%d %H:%M", obj.when),
            })
        else
            table.insert(not_found, id)
        end
    end
    
    -- Sort if requested
    if sort_order and #items > 1 then
        self:_sort_items(items, sort_order)
    end
    
    -- Build structured data
    local data = {
        format = format,
        sort = sort_order,
        total = #items,
        missing_count = #not_found,
        missing_ids = not_found,
        headers = self:_get_headers(format),
        rows = items,
        raw_ids = ids,
    }
    
    return data
end

--- Format structured data into display strings
---
---@param data table Structured data from UI_render_data
---@param format string "md"|"detail"|"list"
---@param not_found table|nil IDs that don't exist
---@return string Formatted output
function UI:UI_format(data, format, not_found)
    if not data or not data.rows then
        return "No data to display"
    end
    
    local result = {}
    not_found = not_found or {}
    
    if format == "md" then
        table.insert(result, self:_format_markdown(data))
    elseif format == "detail" then
        table.insert(result, self:_format_detail(data))
    elseif format == "list" then
        table.insert(result, self:_format_list(data))
    else
        return false
    end
    
    -- Append missing IDs if any
    if #not_found > 0 then
        table.insert(result, "")
        table.insert(result, "⚠️  The following IDs were not found:")
        table.insert(result, table.concat(not_found, ", "))
    end
    
    return table.concat(result, "\r\n")
end

--- Format as markdown table
---
---@param data table Structured data
---@return string Markdown table
function UI:_format_markdown(data)
    local lines = {}
    
    -- Headers
    table.insert(lines, "| " .. table.concat(data.headers, " | ") .. " |")
    table.insert(lines, "|" .. string.rep("----|", #data.headers))
    
    -- Rows
    for _, row in ipairs(data.rows) do
        local cells = {
            row.id,
            row.category,
            row.title,
            row.nick,
            row.age_display,
        }
        table.insert(lines, "| " .. table.concat(cells, " | ") .. " |")
    end
    
    return table.concat(lines, "\r\n")
end

--- Format as detailed view
---
---@param data table Structured data
---@return string Detailed view
function UI:_format_detail(data)
    local sep = string.rep("=", 80)
    local lines = { sep, "Details of requested item(s):", sep }
    
    for _, row in ipairs(data.rows) do
        local details = string.format(
            "✅ ID: %d\r\n" ..
            "\t📁 Category: %s\r\n" ..
            "\t📝 Title: %s\r\n" ..
            "\t👤 Added by: %s\r\n" ..
            "\t📅 Added on: %s (%s ago)",
            row.id,
            row.category,
            row.title,
            row.nick,
            row.timestamp,
            row.age_display
        )
        table.insert(lines, details)
        table.insert(lines, string.rep("-", 80))
    end
    
    return table.concat(lines, "\r\n")
end

--- Format as simple list
---
---@param data table Structured data
---@return string Simple list
function UI:_format_list(data)
    local lines = {}
    for _, row in ipairs(data.rows) do
        table.insert(lines, string.format("%d. %s [%s]", row.id, row.title, row.category))
    end
    return table.concat(lines, "\r\n")
end

-- ============================================================
-- SORTING HELPERS
-- ============================================================

--- Sort items by various criteria
---
---@param items table Array of item tables
---@param sort_order string Sort key
function UI:_sort_items(items, sort_order)
    local sorts = {
        sn  = function(a, b) return a.nick < b.nick end,
        sw  = function(a, b) return a.when < b.when end,
        st  = function(a, b) return a.title < b.title end,
        rsn = function(a, b) return a.nick > b.nick end,
        rsw = function(a, b) return a.when > b.when end,
        rst = function(a, b) return a.title > b.title end,
        r   = function(a, b) return a.id > b.id end,
        new = function(a, b) return a.when > b.when end,
        old = function(a, b) return a.when < b.when end,
    }
    
    local sort_func = sorts[sort_order]
    if sort_func then
        table.sort(items, sort_func)
    end
end

--- Get headers for each format
---
---@param format string "md"|"detail"|"list"
---@return table Headers
function UI:_get_headers(format)
    local headers = {
        md = {"ID", "Category", "Title", "Nick", "Age"},
        detail = {"ID", "Category", "Title", "Nick", "Added", "Age"},
        list = {"ID", "Title"},
    }
    return headers[format] or headers.md
end

-- ============================================================
-- TREE STRUCTURED DATA
-- ============================================================

--- Build structured tree data (not formatted)
--- Returns nested structure that can be rendered in multiple ways
---
---@param ids table Array of release IDs
---@return table tree_data
---@return table not_found
function UI:UI_tree_data(ids)
    local category_map = {}
    local not_found = {}
    
    for _, id in ipairs(ids) do
        local item = self._data[id]
        if item then
            local cat = item.category
            if not category_map[cat] then
                category_map[cat] = {}
            end
            table.insert(category_map[cat], { id = id, title = item.title })
        else
            table.insert(not_found, id)
        end
    end
    
    -- Build nested tree
    local function build_tree(cat_paths, depth)
        depth = depth or 1
        local result = {}
        
        for cat_path, releases in pairs(cat_paths) do
            local parts = self:Category_split_path(cat_path)
            if #parts >= depth then
                local name = parts[depth]
                if not result[name] then
                    result[name] = { 
                        _path = cat_path,
                        _releases = {},
                        _children = {},
                        _name = name,
                        _depth = depth,
                    }
                end
                if #parts == depth then
                    -- Releases belong at this level
                    for _, rel in ipairs(releases) do
                        table.insert(result[name]._releases, rel)
                    end
                else
                    -- Deeper levels
                    local deeper = {}
                    deeper[cat_path] = releases
                    local children = build_tree(deeper, depth + 1)
                    for child_name, child_data in pairs(children) do
                        result[name]._children[child_name] = child_data
                    end
                end
            end
        end
        
        return result
    end
    
    return build_tree(category_map, 1), not_found
end

--- Render tree from structured data
---
---@param tree_data table Structured tree data
---@param prefix string Indentation prefix
---@param is_last boolean Whether this is the last child
---@return string Formatted tree
function UI:UI_format_tree(tree_data, prefix, is_last)
    prefix = prefix or ""
    local lines = {}
    
    local function render_node(node, pre, last)
        local path = node._path or "root"
        local releases = node._releases or {}
        local count = #releases
        
        -- Print category node
        if path ~= "root" then
            local connector = last and "└── " or "├── "
            if count > 0 then
                table.insert(lines, pre .. connector .. "📁 " .. path .. " (" .. count .. " releases)")
            else
                table.insert(lines, pre .. connector .. "📁 " .. path)
            end
        end
        
        -- Print releases
        if path ~= "root" and count > 0 then
            local rel_pre = pre .. (last and "    " or "│   ")
            for i, rel in ipairs(releases) do
                local rel_connector = (i == #releases) and "└── " or "├── "
                table.insert(lines, rel_pre .. rel_connector .. "✅ ID: " .. rel.id .. " " .. rel.title)
            end
        end
        
        -- Render children
        local children = {}
        for key, value in pairs(node) do
            if key ~= "_releases" and key ~= "_path" and key ~= "_name" and key ~= "_depth" then
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
    
    render_node(tree_data, prefix, true)
    return table.concat(lines, "\r\n")
end

-- ============================================================
-- BACKWARD COMPATIBILITY WRAPPERS
-- ============================================================

--- Render tree (backward compatible)
---
---@param ids table Array of IDs
---@return string Formatted tree
function UI:UI_render_tree(ids)
    local tree_data, not_found = self:UI_tree_data(ids)
    local output = self:UI_format_tree(tree_data)
    
    if #not_found > 0 then
        output = output .. "\r\n\r\n⚠️  IDs not found: " .. table.concat(not_found, ", ")
    end
    
    return output
end

--- Render category tree (backward compatible)
---
---@param path string Starting path
---@param prefix string Indentation prefix
---@param is_last boolean Whether this is the last child
---@return string Formatted category tree
function UI:UI_render_category_tree(path, prefix, is_last)
    -- Get all categories under this path
    local ids = self:Category_get_subcat(path or "")
    local tree_data, _ = self:UI_tree_data(ids)
    
    -- Filter to only show the requested path
    if path and path ~= "" then
        -- Find the node for this path
        local function find_node(node, target)
            if node._path == target then
                return node
            end
            for key, child in pairs(node) do
                if key ~= "_releases" and key ~= "_path" and key ~= "_name" and key ~= "_depth" then
                    local found = find_node(child, target)
                    if found then return found end
                end
            end
            return nil
        end
        local filtered = find_node(tree_data, path)
        if filtered then
            return self:UI_format_tree(filtered, prefix or "", is_last or true)
        end
        return "Category not found: " .. path
    end
    
    return self:UI_format_tree(tree_data, prefix or "", is_last or true)
end

return UI