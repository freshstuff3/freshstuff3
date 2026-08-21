--- core/journal.lua
--- 
--- Journaling functions for FreshSuff3
--- 
--- Uses MessagePack for efficient binary journaling
--- 
--- NOTE: 
--- 
--- The code is more complex as it could have been, but it's for our own good.
--- 
--- I know I could just string.dump() functios, but that would 
--- have tradeoffs:
--- 
--- - Sigificantly slower load and save times
--- - Much larger journal files, since the entire function is dumped, 
---     not just the data
--- - Journal non-editable and not trasferrable between Lua versions, 
---     since the function dump is version-specific
--- 
---@todo assertions for passed variables
---@diagnostic disable: undefined-global


--- Left the name in PascalCase
local msgpack = require "helpers.MessagePack"

local Journal = {}

--- JOURNAL APPEND
--- 
--- Does the effective append job 
--- 
--- Internal function
--- 
--- @param filename string Journal file name
--- @param str string The line to write
--- @return boolean success Returns true on success, false on failure
--- @return string? err Error message in case of failure
function Journal:Journal_append(filename, data)
    print("Writing to journal:", filename, "action:", data.action)  -- DEBUG
    local f, err = io.open(filename,"a+b")
    if f then
        local packed = msgpack.pack(data)
        print("Packed size:", #packed, "bytes")  -- DEBUG
        f:write(packed)
        f:flush(); f:close()
        return true
    else 
        print("Failed to open journal for writing:", err)  -- DEBUG
        return false, err
    end
end

--- WRAPPERS FOR THE ABOVE FUNCTION
--- ---- JOURNAL APPEND: ADD ----
--- 
--- Add action journalling
--- 
--- @param obj table Item object to be added 
--- string: new path upon moving, number: ID for deletion)
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Returns error message in case of failure
function Journal:Journal_append_add(obj, journal_file)
    if not (obj and journal_file) then
        return false, "Release object and/or journal file not specified!"
    end 
        local data = {
        action = "add",
        category = obj.category,
        nick = obj.nick,
        when = obj.when,
        title = obj.title
    }
    return self:Journal_append(journal_file, data)

end

--- ---- JOURNAL APPEND: DELETE ----
--- 
--- Delete action journalling
--- 
--- @param id integer ID of item to be deleted 
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Error message in case of failure
function Journal:Journal_append_del(id, journal_file)
    if not (id and journal_file) then
        return false, "Release ID and/or journal file not specified!"
    end
    local data = {
        action = "delete",
        id = id
    }
    return self:Journal_append(journal_file, data)
end

--- ---- JOURNAL APPEND: MOVE ----
--- 
--- Move action journalling
--- 
--- @param id integer ID of item to be deleted 
--- @param new_category string Category the item is being moved INTO 
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return table|string? err Error message in case of failure
function Journal:Journal_append_move(id, new_category, journal_file)
    if not (id and journal_file and new_category) then
        return false, "Release object and/or journal file and/or new category not specified!"
    end
    local data = {
        action = "move",
        id = id,
        new_category = new_category
    }
    return self:Journal_append(journal_file, data)
end

--- # COMPACTING JOURNAL 
--- 
--- Only runs on script restart
--- 
--- 
--- @param journal_file string Filename. 
--- @return boolean success True if success, false if failure
--- @return string|nil error In case of failure, returns error message
function Journal:Journal_compact(journal_file)
    assert(journal_file ~= nil, "Journal file not specified!")
    -- Write to temp file first
    local temp = os.tmpname()
    local f, err = io.open(temp, "w+b")
    if not f then return false, err end
    for id, obj in ipairs(self._data) do
        local data = {
            action = "add",
            category = obj.category,
            nick = obj.nick,
            when = obj.when,
            title = obj.title
        }
        f:write(msgpack.pack(data))
    end
    f:flush()
    f:close()
    -- Write succeeded, replace previous journal file with temp
    os.rename(temp, journal_file)
    return true, nil
end

--- JOURNAL REPLAY
--- 
--- @param journal_file string Journal file to be used
--- @return table _data  Returns the data after replay, in an array, or 
--- empty table on file open failure/in case of an empty or nonexistent file.
--- @return table ret2 Returns list of failed single items on an 
--- otherwise successful replay or error string added to array or error.
--- On total success, returns empty table
--- 
function Journal:Journal_replay(journal_file)
    assert(journal_file ~= nil,
             "Journal file not specfied")
    local f, err = io.open(journal_file, "rb")
    if f then
        local _data = {}
        local failed = {}
        local content = f:read("*all")
        f:close()
        
        -- Use the unpacker iterator from MessagePack
        local unpacker = msgpack.unpacker(content)
        local count = 0
        
        for pos, data in unpacker do
            count = count + 1
            
            if data.action == "add" then
                data.action = nil
                table.insert(_data, data)
            elseif data.action == "delete" then
                -- Delete by ID (1-based index)
                if _data[data.id] then
                    table.remove(_data, data.id)
                else
                    table.insert(failed, "Delete failed: ID "..data.id.." not found")
                end
            elseif data.action == "move" then
                if _data[data.id] then
                    _data[data.id].category = data.new_category
                else
                    table.insert(failed, "Move failed: ID "..data.id.." not found")
                end
            else
                table.insert(failed, "Unknown action: "..tostring(data.action))
            end
        end
        
        return _data, failed
    else
        return {}, { ""..err.."" }
    end
end



return Journal
