-- core/item.lua
local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"

package.path = package.path .. string.format(";%s?.lua", base_path)

local JOURNAL_FILE = base_path.."data/journals/freshstuff3.lua"
local TEST_CATEGORY = "/home/szg/ptokax-config/scripts/freshstuff3/data/test_category.lua"

local Item = {}

function Item:init()
    self._data = {}              -- Private storage
    self._category_tree = {}      -- Private category tree
    -- Private path index with per-category dirty flag
    self._category_index = {}
    local Journal = Journal or require "core.journal"
    local result, failed = Journal:replay(JOURNAL_FILE)
    if result then -- success
        self._data = result
        Category:init(TEST_CATEGORY, self)
        Journal:compact(JOURNAL_FILE, self)
        return failed
    else -- failed, return error message
        return failed
        -- no init for categories here as _data is untouched
    end
end


--- ---- ADD DATA ITEM ----
--- Category autocreated
--- 
--- 
--- @param rel_object table cat, nick, title, timestamp
--- @param journal_path string|nil Journal path. No journaling takes place if nil.
--- @return boolean success The numerical index of the new item within _data
--- @return boolean|nil error Error message in case of failure
function Item:add(rel_object, journal_path)
  local Category = Category or require "core.category"
    -- Create category if does not exist
    if not self._category_index[rel_object.category] then
        local succ, fail = Category:create(rel_object.category)
        if not succ then return false, fail end
        local node = Category:get_node(rel_object.category)
        -- Only adding to category tree for previously nonexistent categories
        table.insert(node._releases, #self._data+1)
        -- Mark node as clean as it is in sync with 1 item
        self._category_index[rel_object.category].dirty = false
    else -- category exists
        -- Mark corresponding node as dirty
        self._category_index[rel_object.category].dirty = true
    end
    -- Finally, add the item
    table.insert(self._data, rel_object)
    -- If specified, save to journal
    if journal_path then
        local Journal = Journal or require "core.journal"
        local succ, err = Journal:append_add(rel_object, journal_path)
        return succ, err
    end
    return true
end

--- MOVE ITEM BETWEEN CATEGORIES
---
--- @param id integer Item ID to move
--- @param path string New category 
--- @param journal_file string? Optional, file path if journaling needed
--- @return boolean success True on success, false only
--- on serialisation failure
--- @return string err If serialisation failed, returns the error message
function Item:move_id(id, path, journal_file)   
-- TODO: check if the old category will become empty after move --- WHY???
-- WE ARE REBUILDING WHEN QUERIED
    if not self._category_index[path] then
        return false, "Category does not exist'"
    end
    local before = self._data[id].category
    self._data[id].category = path
    self._category_index[before].dirty = true
    self._category_index[path].dirty = true
    -- We do not serialise categories on moved IDs. Category states are not 
    -- persistent, since a restart will result in a clean slate anyway.
    -- However, we do journal the move 
    if journal_file then
        local Journal = Journal or require "core.journal"
        return Journal:append_move(id, path, journal_file)
    end
    return true, _
end


--- ---- DELETE DATA ITEM ----
--- Lorem ipsum
--- 
--- 
---@param id integer ID
---@param journal_path string? Journal path (optional). No journaling happens if not stated.
---@return boolean success True on success
---@return string? err Error message
function Item:delete(id, journal_path)
    if not self._data[id] then
        return false, string.format("No item with ID number %d exists.", id)
    else 
        -- No need to check for category existence! 
        -- We are deleting so category implicitly exists.
        -- First, we set the dirty flag
        self._category_index[self._data[id].category] = { dirty = true }
        -- and then nuke the item
        table.remove(self._data, id)
    end
    -- optional journaling
    if journal_path then
        local Journal = Journal or require "core.journal"
        return Journal:append_del(id, journal_path)
    end
    return true, _
end

--- VALIDATE DATA ITEM 
--- 
--- Lorem ipsum
--- 
--- 
---@param item string item to validate
---@return boolean success If true, validation succeeded
---@return string? err error message, if validation failed
---@return integer|string? ID_or_word Detected forbidden word OR ID number of identical release, whichever applies
function Item:validate(item)
    -- sanitize: not needed
    -- TODO: config variable for FORBIDDEN
    local FORBIDDEN = require "config".FORBIDDEN or {}
    -- Check new item for forbidden words first
    for _, word in ipairs(FORBIDDEN) do
        if string.find(item:lower(), word:lower(), 1, true) then 
            return false, "Forbidden word detected", word
        end
    end

    -- We only traverse _data if no forbidden words
    -- Check for 100% match
    for id, rel in ipairs(self._data) do
        if item:lower() == rel.title:lower() then
            return false, "Item with the same name already exists in database.", rel.id
        end
    end 
    return true 
end

return Item