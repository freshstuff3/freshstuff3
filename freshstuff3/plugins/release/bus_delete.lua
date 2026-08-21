-- core/business.lua
-- Business logic orchestrates core operations and fires events
---@note AI stuff
local Bus = {}
--- Delete releases (business level)
function Bus:Bus_delete_releases(ids, fire_events)
    -- fire_events defaults to true
    if fire_events == nil then fire_events = true end
        
    if type(ids) == "number" then
        ids = { ids }
    end
        
    if #ids == 0 then
        return false, "No IDs specified"
    end
        
    -- Collect items first (before any deletion)
    local items = {}
    local missing = {}
        
    for _, id in ipairs(ids) do
        if self._data[id] then
            table.insert(items, {
                id = id,
                item = self._data[id],
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
        return false, "No valid items found"
    end
        
    -- ============================================================
    -- FIRE PRE-DELETE EVENTS (if enabled)
    -- ============================================================
    if fire_events then
        local pre_data = {
            ids = ids,
            items = items,
            count = #items,
            missing = missing,
        }
            
        local result = Event:fire("ItemsPreDelete", pre_data)
            
        if result.cancelled then
            return false, string.format("Deletion cancelled: %s", 
                result.cancel_reason or "Unknown")
        end
    end
        
    -- ============================================================
    -- PERFORM DELETION (call core)
    -- ============================================================
    local deleted_items = {}
    local errors = {}
        
    for _, item_info in ipairs(items) do
        local id = item_info.id
        local success, deleted = self:Item_delete(id, self.JOURNAL_FILE)
            
        if success then
            table.insert(deleted_items, deleted)
        else
            table.insert(errors, string.format("ID %d: %s", id, deleted))
        end
    end
        
    -- ============================================================
    -- FIRE POST-DELETE EVENTS (if enabled)
    -- ============================================================
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
        
    if #errors > 0 then
        return true, string.format("Deleted %d items, %d errors", 
            #deleted_items, #errors)
    end
        
    return true, string.format("Deleted %d items", #deleted_items)
end


--- Delete category (business level with its own events)
function Bus:Bus_delete_category(path, is_force, is_nuke, is_preview)
    -- ============================================================
    -- COLLECT EVERYTHING FIRST
    -- ============================================================
    local state = self._category_index[path]
    if not state then
        return false, string.format("Category %s does not exist!", path)
    end
        
    -- Get the node
    local node = self:Category_rebuild_node(path)
    if not node then
        return false, string.format("Error retrieving node for category path %s", path)
    end
        
    -- Collect all items in this category and subcategories
    local all_ids = self:Category_get_subcat(path)
    local items_to_delete = {}
        
    for _, id in ipairs(all_ids) do
        if self._data[id] then
            table.insert(items_to_delete, {
                id = id,
                item = self._data[id],
                category = self._data[id].category,
                title = self._data[id].title,
                nick = self._data[id].nick,
                when = self._data[id].when,
            })
        end
    end
        
    -- Check for subcategories
    local cats_to_delete = { path }
    local function collect_subcats(current_node, current_path)
        for name, child in pairs(current_node) do
            if name ~= "_releases" then
                local full_path = current_path .. "/" .. name
                table.insert(cats_to_delete, full_path)
                collect_subcats(child, full_path)
            end
        end
    end
    collect_subcats(node, path)
        
    -- ============================================================
    -- VALIDATE
    -- ============================================================
    local has_subcats = #cats_to_delete > 1
        
    if has_subcats and not is_nuke then
        return false, string.format(
            "❌ Category %s has subcategories. Use --nuke to delete recursively.", path
        )
    end
        
    if #items_to_delete > 0 and not is_force and not is_nuke then
        return false, string.format(
            "❌ Category %s has %d releases. Use --force to delete with releases.", 
            path, #items_to_delete
        )
    end
        
    -- ============================================================
    -- PRE-DELETE EVENT (Category-specific)
    -- ============================================================
    if not is_preview then
        local pre_data = {
            path = path,
            categories = cats_to_delete,
            category_count = #cats_to_delete,
            items = items_to_delete,
            item_count = #items_to_delete,
            is_force = is_force,
            is_nuke = is_nuke,
        }
            
    local result = Event:Event_fire("CategoryPreDelete", pre_data)
            
        if result.cancelled then
            return false, string.format("Deletion cancelled: %s", 
                result.cancel_reason or "Unknown")
        end
    end
        
    -- ============================================================
    -- PERFORM DELETION
    -- ============================================================
    if is_preview then
        -- Preview mode: just return what would be deleted
        return items_to_delete, cats_to_delete
    end
        
    -- Delete items from _data (using core item deletion)
    local deleted_items = {}
    local errors = {}
        
    for _, item_info in ipairs(items_to_delete) do
        local success, deleted = self:Item_delete(item_info.id, self.JOURNAL_FILE)
        if success then
            table.insert(deleted_items, deleted)
        else
            table.insert(errors, string.format("ID %d: %s", item_info.id, deleted))
        end
    end
        
    -- Delete categories from tree (bottom-up)
    table.sort(cats_to_delete, function(a, b)
        local depth_a = #self:Category_split_path(a)
        local depth_b = #self:Category_split_path(b)
         return depth_a > depth_b
    end)
        
    for _, cat_path in ipairs(cats_to_delete) do
        self._category_index[cat_path] = nil
        self:Category_delete_node(cat_path)
    end
        
    -- Serialize
    self:Category_serialize(self.TEST_CATEGORY)
        
    --- ============================================================
    --- POST-DELETE EVENT (Category-specific)
    --- ============================================================
    local post_data = {
        path = path,
        categories = cats_to_delete,
        category_count = #cats_to_delete,
        items = deleted_items,
        item_count = #deleted_items,
        is_force = is_force,
        is_nuke = is_nuke,
        errors = errors,
    }
        
    Event:fire("CategoryPostDelete", post_data)
        
    if #errors > 0 then
        return true, string.format("Deleted category %s with %d items (%d errors)", 
            path, #deleted_items, #errors)
    end
        
    return true, string.format("Deleted category %s with %d items", path, #deleted_items)
end

    --- Move releases (business level)
function Bus:Bus_move_releases(ids, new_path)
    if type(ids) == "number" then
        ids = { ids }
    end
        
    local results = {}
    local errors = {}
        
    for _, id in ipairs(ids) do
         local success, result = self:Item_move(id, new_path, self.JOURNAL_FILE)
        if success then
            table.insert(results, result)
        else
            table.insert(errors, result)
        end
    end
        
    -- Fire move event if any succeeded
    if #results > 0 then
        Event:fire("ItemsMoved", {
            ids = ids,
            results = results,
            errors = errors,
            new_path = new_path,
        })
     end
        
    return #errors == 0, { results = results, errors = errors }
end

return Bus