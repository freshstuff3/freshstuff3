-- core/init.lua
-- Basic init functions
-- Also provides Lua console REPL
-- 
return
{
Load_plugins = function()
    ---@todo config
    local PLUGINS = 
    { 
        "release",
        "game", 
    }

    for _, plugin in ipairs(PLUGINS) do
        local fn, err = loadfile(string.format("%splugins/%s.lua", base_path, plugin))
        if not fn then
            ---@note SendOut
            print(string.format("❌ Failed to load plugin '%s': %s", plugin, err))
        else
            local ok, result = pcall(require, "plugins." .. plugin)
            if not ok then
            ---@note SendOut
                print(string.format("❌ Plugin '%s' error: %s", plugin, result))
            else
            ---@note SendOut
                print(string.format("✅ Plugin '%s' loaded", plugin))
            end
        end
    end
    local Command = require "core.command"
    local Event = require "core.event"
    -- Scan once and cache all events at startup
    -- Load events from all plugins into package.loaded 
    -- after plugins have been started
    Command:init()
    Event:init()
end,

Create_instance = function(self)
    -- Create basic layout
    local obj = {
        _data = {},
        _category_index = {},
        _category_tree = {},
        _cmd_handlers = {},
    }
    
    -- Attach all functions
    local function merge(module)
        for k, v in pairs(module) do
            obj[k] = v
        end
    end
    
    -- Events and commands are loaded separately
    merge(require "core.ui")
    merge(require "core.category")
    merge(require "core.item")
    merge(require "core.journal")
    merge(require "core.business")

    -- Attach shell directly as a method
    obj.open_lua_shell = function(self)
        -- Get the environment with self
        local env = {
            self = self,
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
        }
        
        print("FreshStuff3 Interactive Shell")
        print("Type 'help' for commands, 'exit' to quit")
        print("Lua expressions work too!")
        print("Use 'self' to access the application")
        
        local Command = require "core.command"
        local cmds = Command:list()
        print("Commands loaded:", #cmds)
        
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
  self._data[1].title
  self:Bus_show_new(10)
]])
            else
                -- ============================================================
                -- TRY AS COMMAND
                -- ============================================================
                local cmd, args = input:match("^!(%S+)%s*(.*)$")
                if not cmd then
                    cmd = input
                    args = input
                end
                
                local ok, result = Command:execute(cmd, args, "Console")
                if ok then
                    if result then
                        print(result)
                    end
                    goto continue
                end
                
                -- ============================================================
                -- TRY AS LUA EXPRESSION
                -- ============================================================
                local func, err = load(input)
                if func then
                    debug.setupvalue(func, 1, env)
                    local ok, result = pcall(func)
                    if ok then
                        if result ~= nil then
                            if type(result) == "table" then
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





    -- Attach data initialisation function to instance
    obj.Data_init = function(self, journal_file, category_file)
    -- Populate _data first
        local success, err = self:Item_init(journal_file)
        if not success then
            self._data = {}
            return false, "ERROR: Item_init failed: "..err
        end

        ---@note DEBUG
        if not next(self._data) then 
            self._data = {}
            return {}, "No data could be loaded from journal"
        end

        ---
        --- Now initialise categories
        ---
        self:Category_init(category_file)

        --- 
        --- Protect _cmd_handlers from accidental overwrites
        --- 
        setmetatable(self._cmd_handlers, {
        __newindex = function(tbl, key, value)
            if tbl[key] then
                error("Command already exists: " .. key)
            else
                if next(value.aliases) then
                    for _, alias in ipairs(value.aliases) do
                        if not tbl[alias] then
                            rawset(tbl, alias, value)
                        else
                            error("Alias would overwrite an existing command: " .. alias)
                        end
                    end
                end
            end
            rawset(tbl, key, value)
        end})
    end

    -- Attach shell function to instance

    return obj
end,

open_lua_shell = function()
    -- Get instance from package.loaded
    local AllStuff = package.loaded["plugins.release"]
    if not AllStuff then
        print("❌ No instance found! Make sure plugins are loaded.")
        return
    end
    
    -- Use the instance's shell method
    AllStuff:open_lua_shell()
end
}