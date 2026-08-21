-- plugins/release/bus_delete.lua
-- Business logic for deletion operations
-- Events are fired here, core operations are delegated to category/item modules
-- Formatting is delegated to UI module

local Bus = {}
local Event = require "helpers.event"

--- Delete releases (business level with events)
--- Orchestrates deletion of one or more releases, firing pre/post events.
--- Delegates actual deletion to Item:Item_delete core module.
---
---@param ids table|number IDs to delete. Can be a single ID or array of IDs.
---@param fire_events boolean Whether to fire pre/post events (default: true)
---@return boolean success True if operation completed (even with partial errors)
---@return table result { deleted = table, errors = table, missing = table }
---@return string message Human-readable summary
function Bus:Bus_delete_releases(ids, fire_events)
    if fire_events == nil then fire_events = true end
    
    if type(ids) == "number" then
        ids = { ids }
    end
    
    if #ids == 0 then
        return false, { deleted = {}, errors = { "No IDs specified" }, missing = {} }, "No IDs specified"
    end
    
    -- Collect items before deletion
    local items = {}
    local missing = {}
    
    for _, id in ipairs(ids) do
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
        return false, { deleted = {}, errors = {}, missing = missing }, "No valid items found"
    end
    
    -- Fire pre-delete events
    if fire_events then
        local pre_data = {
            ids = ids,
            items = items,
            count = #items,
            missing = missing,
        }
        
        local result = Event:fire("ItemsPreDelete", pre_data)
        
        if result.cancelled then
            return false, { deleted = {}, errors = {}, missing = missing }, 
                string.format("Deletion cancelled: %s", result.cancel_reason or "Unknown")
        end
    end
    
    -- Perform deletion via core
    local deleted_items = {}
    local errors = {}
    
    for _, item_info in ipairs(items) do
        local id = item_info.id
        local success, result = self:Item_delete(id, self.JOURNAL_FILE)
        
        if success then
            table.insert(deleted_items, result)
        else
            table.insert(errors, { id = id, error = result })
        end
    end
    
    -- Fire post-delete events
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
    
    return true, { deleted = deleted_items, errors = errors, missing = missing }, 
        string.format("Deleted %d items, %d errors", #deleted_items, #errors)
end

--- Delete category (business level with events)
--- Orchestrates deletion of a category and optionally its releases/subcategories.
--- Delegates actual deletion to Category:Category_delete core module.
---
---@param path string Category path to delete
---@param is_force boolean Force delete even with releases (default: false)
---@param is_nuke boolean Delete subcategories recursively (default: false)
---@param is_preview boolean Preview mode (default: true)
---@return boolean success True if operation completed successfully
---@return table result { items = table, categories = table, errors = table }
---@return string message Human-readable summary
function Bus:Bus_delete_category(path, is_force, is_nuke, is_preview)
    if is_preview == nil then is_preview = true end
    if is_force == nil then is_force = false end
    if is_nuke == nil then is_nuke = false end
    
    -- Validate category using existing core validation
    local valid, err = self:Category_process_path(path)
    if not valid then
        return false, { items = {}, categories = {}, errors = { err } }, err
    end
    
    -- Get preview data first (for events)
    local preview_ids, preview_cats = self:Category_delete(path, "preview", "preview", is_force, is_nuke, true)
    if not preview_ids then
        return false, { items = {}, categories = {}, errors = { preview_cats } }, preview_cats
    end
    
    -- Fire pre-delete event
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
    
    -- Preview mode
    if is_preview then
        return true, { 
            items = preview_ids, 
            categories = preview_cats, 
            errors = {} 
        }, string.format("PREVIEW: %d items in %d categories", #preview_ids, #preview_cats)
    end
    
    -- Perform actual deletion
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
    
    -- Fire post-delete event
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
    
    return true, { 
        items = deleted_items or {}, 
        categories = deleted_cats or {}, 
        errors = errors or {} 
    }, string.format("Deleted %d items from %d categories", 
        #(deleted_items or {}), 
        #(deleted_cats or {})
    )
end

--- Move releases (business level with events)
--- Orchestrates moving one or more releases to a new category.
--- Delegates actual move to Item:Item_move_id core module.
---
---@param ids table|number IDs to move
---@param new_path string Target category path
---@return boolean success True if ALL moves succeeded
---@return table result { results = table, errors = table, moved = table }
function Bus:Bus_move_releases(ids, new_path)
    if type(ids) == "number" then
        ids = { ids }
    end
    
    if #ids == 0 then
        return false, { results = {}, errors = { "No IDs specified" }, moved = {} }
    end
    
    -- Validate target category using existing core validation
    local valid, err = self:Category_process_path(new_path)
    if not valid then
        return false, { results = {}, errors = { err }, moved = {} }
    end
    
    local results = {}
    local errors = {}
    local moved_items = {}
    
    for _, id in ipairs(ids) do
        if not self._data[id] then
            table.insert(errors, string.format("ID %d does not exist", id))
        else
            local old_category = self._data[id].category
            local success, result = self:Item_move_id(id, new_path, self.JOURNAL_FILE)
            if success then
                table.insert(results, string.format("[%d] %s -> %s", id, old_category, new_path))
                table.insert(moved_items, {
                    id = id,
                    old_category = old_category,
                    new_category = new_path,
                })
            else
                table.insert(errors, string.format("ID %d: %s", id, result))
            end
        end
    end
    
    -- Fire move event if any succeeded
    if #moved_items > 0 then
        Event:fire("ItemsMoved", {
            ids = ids,
            moved_items = moved_items,
            results = results,
            errors = errors,
            new_path = new_path,
        })
    end
    
    return #errors == 0, { results = results, errors = errors, moved = moved_items }
end

return Bus