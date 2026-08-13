-- core/journal.lua
-- Journaling functions for FreshSuff3
-- This one is namespace-agnostic, except for compact()
-- where we need to have the source of truth from RAM
--- @class Journal
--- @todo assertions for passed variables

local base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"

package.path = package.path .. string.format(";%s?.lua", base_path)

local Journal = {}

--- JOURNAL WRITE
--- 
--- Does the effective append job 
--- 
--- 
--- @param filename string Journal file name
--- @param str string The line to write
--- @return boolean success Returns true on success, false on failure
--- @return string? err Error message in case of failure
function Journal:append(filename, str)
     local f, err = io.open(filename,"a+")
    if f then
        f:write(str)
        f:flush(); f:close()
        return true
    else 
        return false, err
    end
end

--- ---- JOURNAL APPEND: ADD ----
--- 
--- Add action journalling
--- 
--- @param obj table Item object to be added 
--- string: new path upon moving, number: ID for deletion)
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Returns error message in case of failure
function Journal:append_add(obj, journal_file)
    if not (obj and journal_file) then
        return false, "Release object and/or journal file not specified!"
    end 
    local str = string.format(
     'return { action = \"add\", category = \"%s\", nick = \"%s\",'..
                ' when = %d, title = \"%s\" }\r\n',
        obj.category, 
        obj.nick, 
        obj.when, 
        obj.title
        )
    return self:append(journal_file, str)
end


--- ---- JOURNAL APPEND: DELETE ----
--- 
--- Delete action journalling
--- 
--- @param id integer ID of item to be deleted 
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Error message in case of failure
function Journal:append_del(id, journal_file)
    if not (id and journal_file) then
        return false, "Release ID and/or journal file not specified!"
    end
    local str = string.format('return { action = \"delete\", id = %d }',id)
    return self:append(journal_file, str)
end

--- ---- JOURNAL APPEND: MOVE ----
--- 
--- Move action journalling
--- 
--- @param id integer ID of item to be deleted 
--- @param new_category string Category the item is being moved INTO 
--- @param journal_file string Journal file path 
--- @return boolean success True on success, false on error
--- @return string|nil err Error message in case of failure
function Journal:append_move(id, new_category, journal_file)
    if not (id and journal_file and new_category) then
        return false, "Release object and/or journal file and/or new category not specified!"
    end
    local str = string.format(
        'return { action = "move", id = %d, new_category = "%s" }\n',
        id,
        new_category
    )
    return self:append(journal_file, str)
end

--- COMPACTING JOURNAL 
--- 
--- Takes namespace as optional argument, falls back to Item 
--- 
--- @param journal_file string Filename. 
--- @param namespace table Namespace containing _data to be used. 
--- @return boolean success True if success, false if failure
--- @return string|nil error In case of failure, returns error message
function Journal:compact(journal_file, namespace)
    assert(journal_file ~= nil and namespace ~= nil, 
            "Journal file and/or namespace not specified!")
    assert( namespace._data ~= nil or type(namespace._data) ~= "table",
    "No _data field in specified namespace or _data is not a table!"
    )
     local f, err = io.open(journal_file, "w+")
    if not f then return false, err end
    for id, obj in ipairs(namespace._data) do
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
    return true, _
end

--- JOURNAL REPLAY
--- 
--- @param journal_file string Joural file to be used
--- @return table _data  Returns the data after replay, in an array, or 
--- empty table on file open failure/in case of an empty or nonexistent file.
--- @return table ret2 Returns list of failed single items on an 
--- otherwise successful replay or error string added to array or error.
--- On total success, returns empty table
function Journal:replay(journal_file)
    assert(journal_file ~= nil, "Journal file not specfied")
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
end

return Journal
