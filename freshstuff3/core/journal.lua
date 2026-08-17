-- core/journal.lua
-- Journaling functions for FreshSuff3
-- This one is namespace-agnostic, except for compact()
-- where we need to have the source of truth from RAM
--- @class Journal
--- @todo assertions for passed variables

return {
--- JOURNAL WRITE
--- 
--- Does the effective append job 
--- 
--- Internal function
--- 
--- @param filename string Journal file name
--- @param str string The line to write
--- @return boolean success Returns true on success, false on failure
--- @return string? err Error message in case of failure
Journal_append = function(self, filename, str)
     local f, err = io.open(filename,"a+")
    if f then
        f:write(str)
        f:flush(); f:close()
        return true
    else 
        return false, err
    end
end,

--- ---- JOURNAL APPEND: ADD ----
--- 
--- Add action journalling
--- 
--- @param obj table Item object to be added 
--- string: new path upon moving, number: ID for deletion)
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Returns error message in case of failure
Journal_append_add = function(self, obj, journal_file)
    if not (obj and journal_file) then
        return false, "Release object and/or journal file not specified!"
    end 
    local str = string.format(
     'return { action = \"add\", category = \"%s\", nick = \"%s\",'..
                ' when = %d, title = \"%s\" }\n',
        obj.category, 
        obj.nick, 
        obj.when, 
        obj.title
        )
    return self:Journal_append(journal_file, str)
end,

--- ---- JOURNAL APPEND: DELETE ----
--- 
--- Delete action journalling
--- 
--- @param id integer ID of item to be deleted 
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Error message in case of failure
Journal_append_del = function(self, id, journal_file)
    if not (id and journal_file) then
        return false, "Release ID and/or journal file not specified!"
    end
    local str = string.format('return { action = \"delete\", id = %d }\n',id)
    return self:Journal_append(journal_file, str)
end,

--- ---- JOURNAL APPEND: MOVE ----
--- 
--- Move action journalling
--- 
--- @param id integer ID of item to be deleted 
--- @param new_category string Category the item is being moved INTO 
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Error message in case of failure
Journal_append_move = function(self, id, new_category, journal_file)
    if not (id and journal_file and new_category) then
        return false, "Release object and/or journal file and/or new category not specified!"
    end
    local str = string.format(
        'return { action = "move", id = %d, new_category = "%s" }\n',
        id,
        new_category
    )
    return self:Journal_append(journal_file, str)
end,

--- # COMPACTING JOURNAL 
--- 
--- Only runs on script restart
--- 
--- 
--- @param journal_file string Filename. 
--- @return boolean success True if success, false if failure
--- @return string|nil error In case of failure, returns error message
Journal_compact = function (self, journal_file)
    assert(journal_file ~= nil, "Journal file not specified!")
    -- Write to temp file first
    local temp = os.tmpname()
    local f, err = io.open(temp, "w+")
    if not f then return false, err end
    for id, obj in ipairs(self._data) do
        f:write(string.format(
            'return { action = \"add\", category = \"%s\", nick = \"%s\",'..
            ' when = %d, title = \"%s\" }\r\n',
            obj.category,
            obj.nick, 
            obj.when, 
            obj.title 
            ))
    end
    f:flush()
    f:close()
    -- Write succeeded, replace previous journal file with temp
    os.rename(temp, journal_file)
    return true, nil
end,

--- JOURNAL REPLAY
--- 
--- @param journal_file string Journal file to be used
--- @return table _data  Returns the data after replay, in an array, or 
--- empty table on file open failure/in case of an empty or nonexistent file.
--- @return table ret2 Returns list of failed single items on an 
--- otherwise successful replay or error string added to array or error.
--- On total success, returns empty table
Journal_replay = function(self, journal_file)
    assert(journal_file ~= nil and self ~= nil and self._data ~= nil,
             "Journal file not specfied, or invalid container")
    local f, err = io.open(journal_file, "r+")
    if f then
        local _data = {}
        local failed = {}
        for line in f:lines() do
            
            local c, err = load (line)
            if c then
                local obj = c()
                if obj.action == "add" then
                    obj.action = nil
                    table.insert(_data, obj)
                elseif obj.action == "delete" then
                    table.remove(_data, obj.id)
                elseif obj.action == "move" then
                    _data[obj.id].category = obj.new_category
                end
            else
                table.insert(failed, line.." - "..err)
            end
        end
        f:close()
        return _data, failed
    else
        return {}, { ""..err.."" }
    end
end,
}