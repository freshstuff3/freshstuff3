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
function Bus2:Bus_delete_releases(ids, user, options)
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
function Bus2:Bus_delete_category(path, user, options)
    options = options or {}
    local preview = options.preview ~= false
    local force = options.force or false
    local nuke = options.nuke or false
    
    -- Category_delete owns validation, recursive traversal, tree mutation,
    -- category serialization, and item deletion. First use it as a dry run
    -- to obtain a stable event payload for either preview or execution.
    local item_ids, category_paths = self:Category_delete(path, force, nuke, true, false)
    if not item_ids then
        return false, { items = {}, categories = {}, errors = { category_paths } }, category_paths
    end

    local result = {
        categories = category_paths,
        items = item_ids,
        errors = {},
    }
    if preview then
        result.preview = true
        return true, result, string.format(
            "Preview: %d items in %d categories would be deleted",
            #item_ids,
            #category_paths
        )
    end

    local pre_data = {
        path = path,
        categories = category_paths,
        category_count = #category_paths,
        items = item_ids,
        item_count = #item_ids,
        force = force,
        nuke = nuke,
    }
    local event_result = Event:fire("CategoryPreDelete", pre_data)
    if event_result.cancelled then
        return false, { items = {}, categories = {}, errors = { "Cancelled" } },
            string.format("Deletion cancelled: %s", event_result.cancel_reason or "Unknown")
    end

    local deleted_ids, message = self:Category_delete(path, force, nuke, false, true)
    if not deleted_ids then
        return false, { items = {}, categories = {}, errors = { message } }, message
    end

    result.items = deleted_ids
    Event:fire("CategoryPostDelete", {
        path = path,
        categories = category_paths,
        category_count = #category_paths,
        items = deleted_ids,
        item_count = #deleted_ids,
        errors = {},
    })

    return true, result, message
end

-- ============================================================
-- PRIVATE HELPERS
-- ============================================================

--- Normalize IDs to a table
function Bus2:_normalize_ids(ids)
    local function dedup(arr)
        -- Deduplication
        local seen = {}
        local result = {}
        for _, id in ipairs(arr) do
            if not seen[id] then
                seen[id] = true
                table.insert(result, id)
            end
        end
        return result
    end

    if type(ids) == "number" then
        return { ids }
    end
    if type(ids) == "table" then
        return dedup(ids)
    end

    -- Try to parse string
    if type(ids) ~= "string" then return false, "❌ Invalid argument" end
    local result = {}

    -- Range: 1-5
    local a, b = ids:match("^(%d+)%-(%d+)$")
    if a and b then
        a = tonumber(a); b = tonumber(b)
        for i = a, b do
            table.insert(result, i)
        end
        return dedup(result)
    end

    -- List: 1,2,3
    for id in ids:gmatch("%d+") do
        table.insert(result, tonumber(id))
    end
    return dedup(result)
end

return Bus2