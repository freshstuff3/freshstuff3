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
---@param nick string User context (for permissions)
---@param options table Options: { preview = boolean, fire_events = boolean }
---@return boolean success
---@return table result { deleted = {}, errors = {}, not_found = {} }
---@return string message Formatted message for user
---
function Bus2:Bus_delete_releases(ids, nick, options)
    if type(ids) ~= "table" then
        if type(ids) == "number" or tonumber(ids) then
            ids = { tonumber(ids) or ids }
        elseif type(ids) == "string" then
            local parsed_ids = self:Bus_split_ids(ids)
            if not parsed_ids then
                local result = {
                    deleted = {},
                    errors = { "Invalid release IDs. Use id1,id2,... or id1-id2." },
                    not_found = {},
                }
                return false, result, self:_format_release_deletion(result)
            end
            ids = parsed_ids
        end
    end
    options = options or {}
    local preview = options.preview or false
    local fire_events = options.fire_events
    if fire_events == nil then
        fire_events = not preview
    end
    
    local id_list, normalize_error = self:Item_normalize_ids(ids)
    if not id_list then
        local result = { deleted = {}, errors = { normalize_error }, not_found = {} }
        return false, result, normalize_error
    end
    if #id_list == 0 then
        local result = { deleted = {}, errors = { "No IDs specified" }, not_found = {} }
        return false, result, "No IDs specified"
    end
    
    -- Collect items with permission check
    local to_delete = {}
    local not_found = {}
    local errors = {}
    
    for _, id in ipairs(id_list) do
        local ok = true -- AI created a super-ugly goto here
        local rel = self._data[id]
        if not rel then
            table.insert(not_found, id)
            ok = false
--[[         else
        -- Permission check (delegated to host)
            if type(nick) ~= "string" or nick:lower() ~= rel.nick:lower() then
                table.insert(errors, string.format(
                    "ID %d: Permission denied. Only owner (%s) or operator can delete.",
                    id, rel.nick or "unknown"
                ))
                ok = false
            end ]]
        end

        if ok then
            table.insert(to_delete, {
                id = id,
                rel = rel,
                category = rel.category,
                title = rel.title,
                nick = rel.nick,
                when = rel.when,
            })
        end
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
        return true, result, self:_format_release_deletion(result)
    end
    
    -- Fire pre-delete events
    if fire_events then
        local pre_data = {
            ids = id_list,
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
    
    -- Perform one batch deletion; Item_delete handles ordering and cache
    -- invalidation for all shifted item IDs.
    local delete_ids = {}
    for _, item in ipairs(to_delete) do
        table.insert(delete_ids, item.id)
    end
    local deleted = {}
    local delete_errors = {}

    local success, deleted_items, failed_ids = self:Item_delete(delete_ids, true)
    if success then
        local failed_by_id = {}
        for _, id in ipairs(failed_ids or {}) do
            failed_by_id[id] = true
            table.insert(not_found, id)
        end
        for _, item in ipairs(to_delete) do
            if not failed_by_id[item.id] then
                table.insert(deleted, item)
            end
        end
    else
        table.insert(delete_errors, deleted_items or "Unknown error")
    end
    
    -- Fire post-delete events
    if fire_events and #deleted > 0 then
        local post_data = {
            ids = id_list,
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
    return #delete_errors == 0, result, self:_format_release_deletion(result)
end

-- ============================================================
-- CATEGORY DELETION (UNIFIED)
-- ============================================================

--- Delete category with unified release deletion
---@param path string Category path
---@param user table User context
---@param options table Options: { preview = boolean, force = boolean, nuke = boolean }
---@return boolean success
---@return table|nil result table if success
---@return string message on success or error message
function Bus2:Bus_delete_category(path, user, options)
    local exists, clean_path = self:Category_exists(path)
    if not exists then
        return false, nil, "❌ Category not found: " .. clean_path
    end

    options = options or {}
    local preview = options.preview ~= false
    local force = options.force or false
    local nuke = options.nuke or false

    -- Target discovery powers preview and event payloads without giving
    -- execution a stale plan from an earlier command phase.
    local item_ids, category_paths = self:Category_get_deletion_targets(clean_path, force, nuke)
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
        return true, result, self:_format_category_deletion(clean_path, result)
    end

    local pre_data = {
        path = clean_path,
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

    local deleted_ids, message = self:Category_delete(clean_path, force, nuke, true)
    if not deleted_ids then
        return false, { items = {}, categories = {}, errors = { message } }, message
    end

    result.items = deleted_ids
    Event:fire("CategoryPostDelete", {
        path = clean_path,
        categories = category_paths,
        category_count = #category_paths,
        items = deleted_ids,
        item_count = #deleted_ids,
        errors = {},
    })

    return true, result, self:_format_category_deletion(clean_path, result)
end

-- ============================================================
-- PRIVATE HELPERS
-- ============================================================

function Bus2:_format_release_deletion(result)
    local is_preview = result.preview ~= nil
    local items = is_preview and result.preview or result.deleted
    local lines = {
        is_preview and "🔍 RELEASE DELETION PREVIEW" or "🚮 RELEASE DELETION COMPLETE",
    }

    if #items == 0 then
        table.insert(lines, "No releases were deleted.")
    else
        for _, item in ipairs(items) do
            table.insert(lines, string.format(
                "[%d] %s (%s)",
                item.id,
                item.title or "Untitled",
                item.category or "Uncategorized"
            ))
        end
    end

    if #result.not_found > 0 then
        table.insert(lines, "Not found: " .. table.concat(result.not_found, ", "))
    end
    for _, error in ipairs(result.errors) do
        table.insert(lines, type(error) == "table"
            and string.format("Error deleting ID %d: %s", error.id, error.error)
            or "Error: " .. error)
    end

    return table.concat(lines, "\r\n")
end

function Bus2:_format_category_deletion(path, result)
    local is_preview = result.preview == true
    local lines = {
        is_preview and "🔍 CATEGORY DELETION PREVIEW" or "🚮 CATEGORY DELETION COMPLETE",
        "Category: " .. path,
        string.format("Categories: %d", #result.categories),
        string.format("Releases: %d", #result.items),
    }

    if #result.categories > 0 then
        table.insert(lines, "Affected categories: " .. table.concat(result.categories, ", "))
    end
    if #result.items > 0 then
        table.insert(lines, "Affected release IDs: " .. table.concat(result.items, ", "))
    end
    for _, error in ipairs(result.errors) do
        table.insert(lines, "Error: " .. error)
    end

    return table.concat(lines, "\r\n")
end

---Rename a category
---@inprogress WIP
---@param old_path string
---@param new_path string
---
function Bus2:Bus_rename_category(old_path, new_path)
    local succ, err = self:Category_rename(old_path, new_path, true)
    if not succ then
        return self.HP .. err else return self.HP ..
        string.format("✅ Category renamed successfully from %s to %s",
        old_path,
        new_path)
    end
end

--- Move one or more releases to a category.
---@param ids table Release IDs
---@param new_category string Destination category path
---@return boolean success
---@return table|string moved_or_error
---@return table|nil failed IDs that could not be moved
---
function Bus2:Bus_move_rel(ids, new_category)
    local exists, clean_category = self:Category_exists(new_category)
    if not exists then
        return false, "❌ Category does not exist: " .. clean_category
    end

    local id_list, err = self:Item_normalize_ids(ids)
    if not id_list or #id_list == 0 then
        return false, err or "❌ No release IDs specified"
    end
    local moved, failed = {}, {}

    for _, id in ipairs(id_list) do
        local rel = self._data[id]
        if not rel then
            table.insert(failed, id)
        else
            local success = self:Item_move_id(id, clean_category, true)
            if success then
                table.insert(moved, id)
            else
                table.insert(failed, id)
            end
        end
    end

    if #moved == 0 then
        return false, "❌ No releases were moved. Failed IDs: " .. table.concat(failed, ", ")
    end
    return true, moved, failed
end

return Bus2