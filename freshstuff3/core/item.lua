-- core/item.lua
-- Manipulates individual data items, and journals them at will.
-- TODO:
-- data.delete
package.path = package.path .. ";/home/szg/ptokax-config/scripts/freshstuff3/?.lua"

-- local Category = Category or require "core.category"

local Item = {
    _data = {},              -- Private storage
    _category_tree = {},      -- Private category tree
    -- Private path index with per-category dirty flag
    _category_index = { ["Music"] = { dirty = false } },
}

--- ---- ADD DATA ITEM ----
--- Category autocreated
--- 
--- 
--- @param rel_object table cat, nick, title, timestamp
--- @param journal_path string|nil Journal path. No journaling takes place if nil.
--- @return number index The numerical index of the new item within _data
--- @return boolean|nil journal_success Journal success if performed
function Item:add(rel_object, journal_path)
  local Category = Category or require "core.category"
    -- Add item to _data
    table.insert(self._data, rel_object)
    if not self._category_index[rel_object.category] then 
        -- Also auto-adds to tree when ID passed and marks it clean:
        Category:create(rel_object.category, #self._data)
    else 
        -- add release ID to tree
        -- not passing around self, loading Item if needed at point of use
        Category:tree_master(rel_object.category, ID)
        -- Mark tree item dirty
        self._category_index[rel_object.category].dirty = true 
    end

    -- Return the index always, return nil if journaling failed
    return #self._data, journal_path and self:journal_append(
                rel_object, journal_path) or nil
end

--- ---- DATA JOURNAL APPEND ----
--- 
--- Append action to journal
--- Can be deletion, move or addition, the function decides
--- 
--- @param param string|table|number (table: release object to be added, string: new path upon moving, number: ID for deletion)
--- @param journal_file string Journal file path relative to ptokax script folder
--- @param rel_id nunmber release id
--- @return boolean|nil True on success
function Item:journal_append(param, journal_file, rel_id)
    local str
    -- local write helper function
    local function write_to_file (filename, str)
        local f, err = io.open(filename,"a+")
        if f then
            f:write(str)
            f:flush(); f:close()
            return true
        else 
            return false, err
        end
    end

    if type(param) == "number" then
        -- we are deleting
        -- we have the DELETED id with param
        str = string.format("table.remove(data, %d)",param )
    elseif type(param) == "string" then 
        -- category name, so we are moving
        str = string.format("data[%d].category = \"%s\"",
        rel_id, param 
        )
    else
       -- we are adding as release object (table) received
       -- str = string.format("table.insert(data, {category = \"%s\", "
       -- .."nick =  \"%s\", title = \"%s\", when = %d }; JOURNAL_LAST_WRITE = "
       -- ..os.time(),param.category, param.nick, param.title, param.when)
        str = string.format(
    "table.insert(data, {category = \"%s\", nick = \"%s\", title = \"%s\", when = %d };"..
        " JOURNAL_LAST_WRITE = %d", param.category, param.nick, param.title, 
        param.when, os.time()
    )

    end
    return write_to_file (journal_file, str)
end

--- ---- DELETE DATA ITEM ----
--- Lorem ipsum
--- 
--- 
---@param id number - ID
---@param journal_path string - Journal path (optional). No journaling happens if not stated.
---@return boolean - True on success
---@return string - Error message
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
        return self:journal_append(id, journal_path)
        -- we are not passing the 4th parameter as it is only used when moving
    end
end

--- VALIDATE DATA ITEM 
--- Lorem ipsum
--- 
--- 
---@param item string  - item to validate
---@return boolean - If true, validation succeeded
---@return string - error message, if validation failed
---@return number|string - Detected forbidden word OR ID number of identical release, whichever applies
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
