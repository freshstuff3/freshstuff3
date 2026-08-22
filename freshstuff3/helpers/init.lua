-- helpers/init.lua
-- Basic init functions for entry point and plugins
-- Also provides Lua console REPL
-- 
-- 
local Init = {}

---@debug
--function OnTimer() print "time" end

function Init:load_plugin(plugin_name)
    -- Handle both "release" and "plugins.release" formats
    local package_name = plugin_name
    if not plugin_name:match("^plugins%.") then
        package_name = "plugins." .. plugin_name
    end
    
    -- Check if already loaded
    if package.loaded[package_name] then
        return package.loaded[package_name]
    end
    
    -- Try to require the plugin
    local ok, result = pcall(require, package_name)
    if not ok then
        return false, result
    end
    
    -- Plugin should have stored itself in package.loaded
    if package.loaded[package_name] then
        return package.loaded[package_name]
    end
    
    return result
end

--- Plugin loader that loads the (not yet) pre-configured plugin list
--- No returns
--- Ideally should only run at startup
--- 
function Init:load_plugins()
    ---@todo make configurable
    local PLUGINS = { 
        "release",
        --"game", 
    }
    -- Scan once and cache all events at startup
    -- Load events and cpommands from all plugins into package.loaded 
    -- after plugins have been started
    for _,p in ipairs(PLUGINS) do
        self:load_plugin(p)
    end
    local Command = require 'helpers.command'
    local Event = require 'helpers.event'
    Command:init()
    Event:init()
end

function Init:merge (module_name)
    assert(type(module_name) == "string", 
    "Invalid module name: " .. tostring(module_name))
    local module
    module = package.loaded[module_name] or require(module_name)
    for k, v in pairs(module) do
        assert(self[k] == nil,
        module_name .. " is trying to redefine an already defined function " .. k)
        self[k] = v
    end
end

function Init:create_instance()
    local obj = {
        _data = {},
        _category_index = {},
        _category_tree = {},
        _cmd_handlers = {},
        }
    
    --- Create merger directly herein
    function obj:merge(module_name)
        assert(type(module_name) == "string", 
        "Invalid module name: " .. tostring(module_name))
        local module
        module = package.loaded[module_name] or require(module_name)
        for k, v in pairs(module) do
            -- overwrite functions only, so redeclaration is possible
            self[k] = type(v) == "function" and v or self[k]
        end
    end

    function obj:win_rename_file(file, new_name)
        -- Windows: Use move (rename) with /Y to force overwrite
        local cmd = 'move /Y "' .. file .. '" "' .. new_name .. '" 2>&1'
        local handle = io.popen(cmd)
        local result = handle:read("*all")
        local success = handle:close()
        
        if success then
            return true
        else
            -- If move fails, try deleting target first then move
            os.execute('del /F /Q "' .. new_name .. '" 2>nul')
            local cmd2 = 'move /Y "' .. file .. '" "' .. new_name .. '" 2>&1'
            local handle2 = io.popen(cmd2)
            local result2 = handle2:read("*all")
            local success2 = handle2:close()
            
            if success2 then
                return true
            end
            return false, "Move failed: " .. (result or result2 or "unknown error")
        end
    end
-- 
--- Events and commands are loaded separately via respective helpers
--- See also freshstuff3.lua, ptokax.lua
---@todo and verlihub.lua

--- Attach core logics (item and category manipulation, journal, UI)
        obj:merge("core.category")
        obj:merge("core.item")
        obj:merge("core.journal")
        obj:merge('core.ui')


    function obj:open_lua_shell()
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
            OnTimer = OnTimer,
            ChatArrival = ChatArrival,
            io = io,
        }
        
        print("FreshStuff3 Interactive Shell")
        print("Type '!help' for commands, 'exit' to quit")
        print("Lua expressions work too!")
        print("Use 'self' to access the application")
        
        local Command = require 'helpers.command'
        local cmds = Command:list()
        
        while true do
            io.write("> ")
            local input
            local ok = pcall(function()
                input = io.read()
            end)
            
            if not ok then
                print("\n(Ctrl-C detected, type 'exit' to quit)")
            elseif not input then
                break
            else
                input = input:gsub("^%s+", ""):gsub("%s+$", "")
                
                if input == "" then
                    -- skip
                elseif input == "exit" or input == "quit" then
                    print("Goodbye!")
                    break
                else
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
                    else
                        -- Try as Lua expression
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
                    end
                end
            end
        end
    end


    --- Attach data initialisation function to instance for plugins that require it
    function obj:data_init()
    -- Populate _data first
        local success, err = self:Item_init()
        if not success then
            self._data = {}
            local err_msg = err or "unknown error"
            return false, "ERROR: Item_init failed: " .. err_msg
        end
        ---
        --- Now initialise categories
        ---
        self:Category_init(self.TEST_CATEGORY)

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
    return obj
end

function Init:open_lua_shell()
    -- Get instance from package.loaded if this function has not 
    -- been called from within an instance (i. e. called from freshstuff3.lua)
    if not self._data then
        local AllStuff = require "plugins.release"
        print("Warning: No instance found! Falling back to AllStuff.")
        AllStuff:open_lua_shell()
        return
    end
    -- Use the instance's shell method
    self:open_lua_shell()
end

return Init

