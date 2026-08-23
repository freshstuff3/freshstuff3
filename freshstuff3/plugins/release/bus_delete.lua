--- plugins/release/bus_delete.lua
--- Business logic for deletion operations

local Bus2 = {}
local Event = require "helpers.event"
-- plugins/release/bus_delete_core.lua
-- Unified deletion bus for releases and categories

-- ============================================================
-- RELEASE DELETION (CORE)
-- ============================================================

--- Delete releases with preview support
---@param ids table|number Release IDs to delete
---@param user table User context (for permissions)
---@param options table Options: { preview = boolean, fire_events = boolean }
---@return boolean success
---@return table result { deleted = {}, errors = {}, not_found = {} }
---@return string message
function Bus2:delete_releases(ids, user, options)
    options = options or {}
    local preview = options.preview or false
    local fire_events = options.fire_events or (not preview)
    
    -- Normalize IDs
    local id_list = self:_normalize_ids(ids)
    if #id_list == 0 then
        local result = { deleted = {}, errors = { "No IDs specified" }, not_found = {} }
        return false, result, "No IDs specified"
    end
    
    -- Collect items with permission check
    local to_delete = {}
    local not_found = {}
    local errors = {}
    
    for _, id in ipairs(id_list) do
        local rel = self._data[id]
        if not rel then
            table.insert(not_found, id)
            goto continue
        end
        
        -- Permission check (delegated to host)
        if not self:_can_modify(user, rel) then
            table.insert(errors, string.format(
                "ID %d: Permission denied. Only owner (%s) or operator can delete.",
                id, rel.nick or "unknown"
            ))
            goto continue
        end
        
        table.insert(to_delete, {
            id = id,
            rel = rel,
            category = rel.category,
            title = rel.title,
            nick = rel.nick,
            when = rel.when,
        })
        ::continue::
    end
    
    if #to_delete == 0 then
        local result = { deleted = {}, errors = errors, not_found = not_found }
        local msg = #errors > 0 and errors[1] or "No valid items to delete"
        return false, result, msg
    end
    
    -- Preview mode: return what would be deleted
    if preview then
        local result = {
            deleted = {},
            errors = errors,
            not_found = not_found,
            preview = to_delete,
        }
        return true, result, string.format("Preview: %d items would be deleted", #to_delete)
    end
    
    -- Fire pre-delete events
    if fire_events then
        local pre_data = {
            ids = ids,
            items = to_delete,
            count = #to_delete,
            not_found = not_found,
        }
        local event_result = Event:fire("ItemsPreDelete", pre_data)
        if event_result.cancelled then
            return false, { deleted = {}, errors = { "Cancelled" }, not_found = not_found },
                string.format("Deletion cancelled: %s", event_result.cancel_reason or "Unknown")
        end
    end
    
    -- Perform deletion (sorted descending to avoid index shifting)
    table.sort(to_delete, function(a, b) return a.id > b.id end)
    local deleted = {}
    local delete_errors = {}
    
    for _, item in ipairs(to_delete) do
        local success, err = self:Item_delete(item.id, true)
        if success then
            table.insert(deleted, item)
        else
            table.insert(delete_errors, {
                id = item.id,
                error = err or "Unknown error"
            })
        end
    end
    
    -- Fire post-delete events
    if fire_events and #deleted > 0 then
        local post_data = {
            ids = ids,
            items = deleted,
            count = #deleted,
            not_found = not_found,
            errors = delete_errors,
        }
        Event:fire("ItemsPostDelete", post_data)
    end
    
    -- Build result
    local result = {
        deleted = deleted,
        errors = delete_errors,
        not_found = not_found,
    }
    local msg = string.format("Deleted %d items, %d errors", #deleted, #delete_errors)
    
    return #delete_errors == 0, result, msg
end

-- ============================================================
-- CATEGORY DELETION (UNIFIED)
-- ============================================================

--- Delete category with unified release deletion
---@param path string Category path
---@param user table User context
---@param options table Options: { preview = boolean, force = boolean, nuke = boolean }
---@return boolean success
---@return table result
---@return string message
function Bus2:delete_category(path, user, options)
    options = options or {}
    local preview = options.preview or true
    local force = options.force or false
    local nuke = options.nuke or false
    
    -- Validate category exists
    if not self._category_index[path] then
        return false, { items = {}, categories = {}, errors = { "Category does not exist" } },
            "Category does not exist: " .. path
    end
    
    -- Get node and check subcategories
    local node = self:Category_rebuild_node(path)
    if not node then
        return false, { items = {}, categories = {}, errors = { "Error retrieving node" } },
            "Error retrieving node for category path " .. path
    end
    
    -- Collect all releases in category and subcategories
    local all_ids = self:Category_get_subcat(path)
    local items_to_delete = {}
    local categories_to_delete = { path }
    
    -- Collect subcategory paths
    local function collect_subcats(current_node, current_path)
        for name, child in pairs(current_node) do
            if name ~= "_releases" then
                local full_path = current_path .. "/" .. name
                table.insert(categories_to_delete, full_path)
                collect_subcats(child, full_path)
            end
        end
    end
    collect_subcats(node, path)
    
    -- Check if empty
    if #all_ids == 0 and #categories_to_delete == 1 then
        -- Empty category
        if preview then
            return true, {
                categories = { path },
                items = {},
                preview = true,
            }, "Preview: Empty category would be deleted"
        end
        
        -- Delete empty category
        self._category_index[path] = nil
        self:Category_delete_node(path)
        self:Category_serialize()
        return true, { categories = { path }, items = {}, errors = {} },
            "Empty category deleted: " .. path
    end
    
    -- Check if force is needed
    if #all_ids > 0 and not force and not nuke then
        return false, { items = {}, categories = {}, errors = { "Force required" } },
            string.format("Category '%s' has %d releases. Use --force to delete.", path, #all_ids)
    end
    
    -- Check if nuke is needed
    if #categories_to_delete > 1 and not nuke then
        return false, { items = {}, categories = {}, errors = { "Nuke required" } },
            string.format("Category '%s' has subcategories. Use --nuke to delete recursively.", path)
    end
    
    -- Preview mode
    if preview then
        return true, {
            categories = categories_to_delete,
            items = all_ids,
            preview = true,
        }, string.format("Preview: %d items in %d categories would be deleted",
            #all_ids, #categories_to_delete)
    end
    
    -- ✅ Use unified release deletion!
    local items_flat = {}
    for _, id in ipairs(all_ids) do
        if self._data[id] then
            table.insert(items_flat, id)
        end
    end
    
    -- Delete releases using the unified bus
    local success, result, msg = self:delete_releases(items_flat, user, {
        preview = false,
        fire_events = true,
    })
    
    if not success then
        return false, { categories = {}, items = {}, errors = result.errors },
            "Failed to delete releases: " .. msg
    end
    
    -- Delete category nodes (bottom-up)
    table.sort(categories_to_delete, function(a, b)
        local depth_a = #self:Category_split_path(a)
        local depth_b = #self:Category_split_path(b)
        return depth_a > depth_b
    end)
    
    local deleted_cats = {}
    for _, cat_path in ipairs(categories_to_delete) do
        self._category_index[cat_path] = nil
        self:Category_delete_node(cat_path)
        table.insert(deleted_cats, cat_path)
    end
    
    -- Serialize
    self:Category_serialize()
    
    -- Fire category post-delete event
    Event:fire("CategoryPostDelete", {
        path = path,
        categories = deleted_cats,
        category_count = #deleted_cats,
        items = result.deleted or {},
        item_count = #(result.deleted or {}),
        errors = result.errors or {},
    })
    
    return true, {
        categories = deleted_cats,
        items = result.deleted or {},
        errors = result.errors or {},
    }, string.format("Deleted category '%s' (%d items, %d categories)",
        path, #(result.deleted or {}), #deleted_cats)
end

-- ============================================================
-- PRIVATE HELPERS
-- ============================================================

--- Normalize IDs to a table
function Bus2:_normalize_ids(ids)
    if type(ids) == "number" then
        return { ids }
    end
    if type(ids) == "table" then
        return ids
    end
    -- Try to parse string
    if type(ids) == "string" then
        local result = {}
        -- Range: 1-5
        local a, b = ids:match("^(%d+)%-(%d+)$")
        if a and b then
            a = tonumber(a); b = tonumber(b)
            for i = a, b do
                table.insert(result, i)
            end
            return result
        end
        -- List: 1,2,3
        for id in ids:gmatch("%d+") do
            table.insert(result, tonumber(id))
        end
        return result
    end
    return {}
end

return Bus2