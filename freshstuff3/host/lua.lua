-- host/lua.lua
-- Host app module for Lua interpreter
-- provides an interactive shell
-- should be run via rlwrap on Unix-like systems

-- host/lua.lua
-- Interactive shell with command support
---@object Lua
local Lua = {}

print("FreshStuff3 Interactive Shell")
print("Type 'help' for commands, 'exit' to quit")
print("Lua expressions work too!")
function Lua.Lua_OpenShell(self)
    -- Environment for Lua expressions
    local env = {
    AllStuff = AllStuff,
    Releasas = AllStuff,  -- alias
    print = print,
    table = table,
    string = string,
    math = math,
    os = os,
    pairs = pairs,
    ipairs = ipairs,
    type = type,
    tostring = tostring,
    tonumber = tonumber,
    -- Quick access to common functions
    show = function(cat)
        local ids = self:Category_get_subcat(cat)
        if #ids == 0 then return "No releases found" end
        return self:UI_render(ids, "tree")
    end,
    list = function()
        local ids = {}
        for i = 1, #self._data do
            table.insert(ids, i)
        end
        return self:UI_render(ids, "tree")
    end,
}
    while true do
        io.write("> ")
        local input = io.read()
        if not input then break end
        input = input:gsub("^%s+", ""):gsub("%s+$", "")
        if input == "" then
            -- skip
        elseif input == "exit" or input == "quit" then
            print("Goodbye!")
            break
        elseif input == "help" or input == "?" then
            print([[
    Commands:
    !releases [category|number]  - Show releases
    !add <category> <title>      - Add a release
    !delete <id>                 - Delete a release
    !search <query>              - Search releases
    !categories                  - List categories
    !info <id>                   - Show release details
    !stats                       - Show statistics
    !help, ?                     - Show this help
    exit, quit                   - Exit shell

    Lua expressions also work:
    AllStuff._data[1].title
    show("Music/Metal")
    list()
    ]])
        else
            -- Try as command first
            if input:match("^!") then
                local cmd, args = input:match("^!(%S+)%s*(.*)$")
                if cmd then
                    local result, err = self:cmd_execute(cmd, args)
                    if err then
                        print("Error:", err)
                    elseif result then
                        print(result)
                    end
                    goto continue
                end
            end
            
            -- Try as command without !
            local result, err = self:cmd_execute(input, "")
            if not err then
                if result then
                    print(result)
                end
                goto continue
            end
            
            -- Try as Lua expression
            local func, err = load(input)
            if func then
                debug.setupvalue(func, 1, env)
                local ok, result = pcall(func)
                if ok then
                    if result ~= nil then
                        if type(result) == "table" then
                            -- Simple table inspection
                            for k, v in pairs(result) do
                                print(k, v)
                            end
                        else
                            print(result)
                        end
                    end
                else
                    print("Error:", result)
                end
            else
                print("Error:", err)
            end
            
            ::continue::
        end
    end
end

return Lua