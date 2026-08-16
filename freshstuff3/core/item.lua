-- core/item.lua
---@todo assertions for passed variables

local Item = {}

--- ITEM INITIALISATION
--- 
--- Replays and compacts the journal.
--- @param file string The journal to be replayed.
--- @return boolean success  
--- @return string|nil failed Error message in case of failure
function Item:Item_init(file)
    assert(file ~= nil and file ~= "", "Journal file not specified!")
    -- Replay the file
    local result, failed = self:Journal_replay(file)
    if result then -- success
        -- compact() expects _data in a table: 
        -- We are also compacting. This is expensive but startup times are
        -- of no concern since during real-world use, restarts are infrequent
        -- so might as well take a bit longer
        -- Purposely using dotted here as self._data is not yet available
        local succ, err = self.Journal_compact({ _data = result }, file)
        if succ then
            -- Only initialise self._data if journal compact succeeds
            self._data = result
            return true, failed
        else return false, err end
    -- Categories need to be initialised separately.
    end
    -- If we are here, journal replay has failed
    return false, failed
end

--- ---- ADD DATA ITEM ----
--- 
--- Category must exist
--- 
--- 
--- @param rel_object table cat, nick, title, timestamp
--- @param journal_path? string Journal path. No journaling takes place if unspecified.
--- @return boolean success 
--- @return string? error Error message in case of failure
function Item:Item_add(rel_object, journal_path)
    assert(rel_object ~= nil, "Release object unspecified!")
    if not self._category_index[rel_object.category] then
        return false, "Category does not exist! Needs to be created first..."
    else -- category exists
        -- Mark corresponding node as dirty
        self._category_index[rel_object.category].dirty = true
    end
    -- Also mark parent categories dirty
    self:Category_mark_parents_dirty(rel_object.category)
    -- Finally, add the item
    table.insert(self._data, rel_object)
    -- If specified, save to journal file
    if journal_path then
        local succ, err = self:Journal_append_add(rel_object, journal_path)
        return succ, err
    end
    return true
end

--- MOVE ITEM BETWEEN CATEGORIES
---
--- @param id integer Item ID to move
--- @param path string New category (sanitised)
--- @param journal_file string? Optional, file path if journaling needed
--- @return boolean success True on success, false only
--- on serialisation failure
--- @return string err If serialisation failed, returns the error message
function Item:Item_move_id(id, path, journal_file)   
-- TODO: check if the old category will become empty after move --- WHY???
-- WE ARE REBUILDING WHEN QUERIED
    if not self._category_index[path] then
        return false, string.format("Category %s does not exist!", path)
    end
    if not self._data[id] then
        return false, string.format("Item with ID %d does not exist!", id)
    end
    local before = self._data[id].category
    self._data[id].category = path
    self._category_index[before].dirty = true
    self._category_index[path].dirty = true
    self:Category_mark_parents_dirty(before); self:Category_mark_parents_dirty(path)
    -- We do not serialise categories on moved IDs. Category states are not 
    -- persistent, since a restart will result in a clean slate anyway.
    -- However, we do journal the move 
    if journal_file then
        return self:Journal_append_move(id, path, journal_file)
    end
    return true
end


--- ---- DELETE DATA ITEM ----
--- Lorem ipsum
--- 
--- 
---@param id integer ID
---@param journal_path string? Journal path (optional). No journaling happens if not stated.
---@return boolean success True on success
---@return string? err Error message
function Item:Item_delete(id, journal_path)
    if not self._data[id] then
        -- Item already deleted, return success
        return false, string.format("Item with ID %d does not exist", id)
    end
    
    -- Mark category as dirty
    if self._data[id] and self._data[id].category then
        local cat = self._data[id].category
        if self._category_index[cat] then
            self._category_index[cat].dirty = true
        end
        self:Category_mark_parents_dirty(cat)
    end
    
    -- Remove from _data
    table.remove(self._data, id)
    
    -- Optional journaling
    if journal_path then
        return self:Journal_append_del(id, journal_path)
    end
    return true, nil
end

--- VALIDATE DATA ITEM 
--- 
--- Lorem ipsum
--- 
--- 
---@param item string item to validate
---@return boolean success If true, validation succeeded
---@return string? err error message, if validation failed
function Item:Item_validate_title(item)
    -- sanitize: not needed
    -- TODO: config variable for FORBIDDEN
    -- local FORBIDDEN = require "config".FORBIDDEN or {}
    -- Check new item for forbidden words first
    local FORBIDDEN = FORBIDDEN or { "shit" }
    for _, word in ipairs(FORBIDDEN) do
        if string.find(item:lower(), word:lower(), 1, true) then 
            return false, string.format("Forbidden word detected %s", word)
        end
    end

    -- We only traverse _data if no forbidden words
    -- Check for 100% match
    for id, rel in ipairs(self._data) do
        if item:lower() == rel.title:lower() then
            return false, 
            string.format ("Item with the same name already exists in "..
            "database. Its ID is:\r\n\r\n%d", 
            id)
        end
    end 
    return true 
end

--- Get IDs for items newer than a specified timeframe
--- 
--- Time format: <number><unit> where unit is:
---   - d: days (e.g., 7d = 7 days)
---   - w: weeks (e.g., 2w = 14 days)
---   - m: months (e.g., 3m = 90 days)
--- 
--- Special shortcuts:
---   - "today"    : Start of today (00:00:00)
---   - "yesterday": Start of yesterday (00:00:00)
--- 
--- @param param string Timeframe (e.g., "5d", "2w", "1m", "today", "yesterday")
--- @return table|false ids Array of release IDs newer than the cutoff
--- or false on invalid string
function Item:Item_get_newer_than(param)
    local result = {}
    local conversion = {
        ["today"] = "0d",
        ["yesterday"] = "1d"
    }
    param = conversion[param] or param
    local number, mult = param:match("^(%d+)([dwm])$")
    if not (number and mult) or number == "" or mult == "" then return false end
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
    for id, obj in ipairs(self._data) do
        if obj.when >= cutoff then
            table.insert(result, id)
        end
    end
    return result
end

-- 
function Item:Item_search(query)
    local result, result_cat  = {}, {}
    if not query:find("%s+") then
        -- no spaces, search categories first
        for cat, _ in pairs(self._category_index) do
            if cat:lower():match(query:lower(), 1, true) then
                table.insert(result_cat, cat)
            end
        end
        -- If category found, searching for releases becomes pointless.
        if #result_cat ~= 0 then return {}, result_cat end
    end
    for id, obj in ipairs(self._data) do
        if obj.nick:lower():match(query:lower(), 1, true) or 
        obj.title:lower():match(query:lower(), 1, true) then
            table.insert(result, id)
        end
    end
    return result, result_cat
end

return Item

-- for some reason emmylua still sees stuff as undefined, but only with this file, not with categories.lua or journal.lua etc.
---@class Item
