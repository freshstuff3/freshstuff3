-- plugins/release/bus_delete.lua
-- Business logic for deletion operations

local Bus2 = {}
local Event = require "helpers.event"

-- ============================================================
-- DELETE RELEASES
-- ============================================================

--- Delete releases
---@param ids table|number IDs to delete
---@param fire_events boolean Whether to fire events
---@return boolean success
---@return table result
---@return string message
function Bus2:Bus_delete_releases(ids, fire_events)
    if fire_events == nil then fire_events = true end
    
    -- Normalize IDs (business logic)
    local id_list = self:_normalize_ids(ids)
    if #id_list == 0 then
        local result = { deleted = {}, errors = { "No IDs specified" }, missing = {} }
        return false, result, "No IDs specified"
    end
    
    -- Collect items (business logic)
    local items, missing = {}, {}
    for _, id in ipairs(id_list) do
        if self._data[id] then
            table.insert(items, {
                id = id,
                category = self._data[id].category,
                title = self._data[id].title,
                nick = self._data[id].nick,
                when = self._data[id].when,
            })
        else
            table.insert(missing, id)
        end
    end
    
    if #items == 0 then
        local result = { deleted = {}, errors = {}, missing = missing }
        return false, result, "No valid items found"
    end
    
    -- Fire pre-delete events (business logic)
    if fire_events then
        local pre_data = {
            ids = ids,
            items = items,
            count = #items,
            missing = missing,
        }
        
        local event_result = Event:fire("ItemsPreDelete", pre_data)
        if event_result.cancelled then
            return false, { deleted = {}, errors = {}, missing = missing }, 
                string.format("Deletion cancelled: %s", event_result.cancel_reason or "Unknown")
        end
    end
    
    -- Perform deletion (business logic)
    local deleted_items = {}
    local errors = {}
    
    for _, item_info in ipairs(items) do
        local id = item_info.id
        local success, result = self:Item_delete(id, self.JOURNAL_FILE)
        
        if success then
            table.insert(deleted_items, result or item_info)
        else
            table.insert(errors, { id = id, error = result })
        end
    end
    
    -- Fire post-delete events (business logic)
    if fire_events and #deleted_items > 0 then
        local post_data = {
            ids = ids,
            items = deleted_items,
            count = #deleted_items,
            missing = missing,
            errors = errors,
        }
        Event:fire("ItemsPostDelete", post_data)
    end
    
    -- Build result (business logic)
    local result = { deleted = deleted_items, errors = errors, missing = missing }
    local msg = string.format("Deleted %d items, %d errors", #deleted_items, #errors)
    
    return #errors == 0, result, msg
end

-- ============================================================
-- DELETE CATEGORY
-- ============================================================

--- Delete category
---@param path string Category path
---@param is_force boolean Force delete with releases
---@param is_nuke boolean Delete subcategories recursively
---@param is_preview boolean Preview mode
---@return boolean success
---@return table result
---@return string message
function Bus2:Bus_delete_category(path, is_force, is_nuke, is_preview)
    if is_preview == nil then is_preview = true end
    if is_force == nil then is_force = false end
    if is_nuke == nil then is_nuke = false end
    
    -- Validate category (business logic)
    local valid, err = self:Category_process_path(path)
    if not valid then
        return false, { items = {}, categories = {}, errors = { err } }, err
    end
    
    -- Get preview data (business logic)
    local preview_ids, preview_cats = self:Category_delete(path, "preview", "preview", is_force, is_nuke, true)
    if not preview_ids then
        return false, { items = {}, categories = {}, errors = { preview_cats } }, preview_cats
    end
    
    -- Fire pre-delete event (business logic)
    local pre_data = {
        path = path,
        categories = preview_cats,
        category_count = #preview_cats,
        items = preview_ids,
        item_count = #preview_ids,
        is_force = is_force,
        is_nuke = is_nuke,
        is_preview = is_preview,
    }
    
    local event_result = Event:fire("CategoryPreDelete", pre_data)
    if event_result.cancelled then
        return false, { items = {}, categories = {}, errors = { "Cancelled" } }, 
            string.format("Deletion cancelled: %s", event_result.cancel_reason or "Unknown")
    end
    
    -- UI handles formatting - even preview uses UI headers
    if is_preview then
        local data = { items = preview_ids, categories = preview_cats, errors = {} }
        local header = self:UI_header_deletion_preview()
        local formatted = header .. self:UI_format_deletion(data, path, true)
        return true, data, formatted
    end
    
    -- Perform actual deletion (business logic)
    local success, deleted_items, deleted_cats, errors = self:Category_delete(
        path, 
        self.TEST_CATEGORY,
        self.JOURNAL_FILE,
        is_force, 
        is_nuke, 
        false
    )
    
    if not success then
        return false, { items = {}, categories = {}, errors = { deleted_items } }, deleted_items
    end
    
    -- Fire post-delete event (business logic)
    local post_data = {
        path = path,
        categories = deleted_cats or {},
        category_count = #(deleted_cats or {}),
        items = deleted_items or {},
        item_count = #(deleted_items or {}),
        is_force = is_force,
        is_nuke = is_nuke,
        errors = errors,
    }
    Event:fire("CategoryPostDelete", post_data)
    
    -- Build result (business logic)
    local result = { 
        items = deleted_items or {}, 
        categories = deleted_cats or {}, 
        errors = errors or {} 
    }
    
    -- UI handles formatting
    local header = self:UI_header_deletion_result()
    local formatted = header .. self:UI_format_deletion(result, path, false)
    
    return true, result, formatted
end

-- ============================================================
-- PRIVATE HELPERS
-- ============================================================

--- Normalize IDs to a table
---@param ids table|number|nil
---@return table
function Bus2:_normalize_ids(ids)
    if type(ids) == "number" then
        return { ids }
    end
    if type(ids) == "table" then
        return ids
    end
    return {}
end

return Bus2