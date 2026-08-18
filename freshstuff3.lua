-- freshstuff3.lua
-- Entry point for freshstuff3
base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
package.path = package.path .. string.format(";%s?.lua", base_path)
-- ============================================================================



-- Load AllStuff
--- Loading sequence:
--- Detect host -> Hand over to host so that it can load plugins and then do its thing
--- No host detected -> Load plugins and start REPL console
--- 
--- Plugins initialise themselves like:
--- 
--- ```lua
--- local Init = require "core.init"
--- AllStuff = Init:Create_instance()
--- if type(AllStuff) ~= "table" then error("FATAL: Failed to initialise release module!") end
--- AllStuff:Data_init(JOURNAL_FILE, CATEGORY_FILE)
--- ```

-- Detect host app
--if type(Core) ~= "table" then
--    local Init = require "helpers.init"
--    Init:load_plugins()
--    Init:open_lua_shell()
--end

-- We load ptokax.lua and fall back to shell therein 
require "host.ptokax"; if type(Core) ~= "table" then OnStartup() end



local RemoteDebug = {
    enabled = true,
    log_path = "/tmp/freshstuff_debug.log",  -- Use /tmp for remote
}

function RemoteDebug.log(...)
    if not RemoteDebug.enabled then return end
    
    local f = io.open(RemoteDebug.log_path, "a+")
    if not f then return end
    
    local timestamp = os.date("%H:%M:%S")
    local args = {...}
    local parts = {timestamp}
    
    for _, arg in ipairs(args) do
        if type(arg) == "table" then
            parts[#parts + 1] = RemoteDebug.inspect(arg) -- the fuck is this
        else
            parts[#parts + 1] = tostring(arg)
        end
    end
    
    f:write(table.concat(parts, " ") .. "\n")
    f:close()
end

function RemoteDebug.inspect(tbl, prefix)
    prefix = prefix or ""
    local result = {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            result[#result + 1] = prefix .. tostring(k) .. " = {...}"
            local sub = RemoteDebug.inspect(v, prefix .. "  ")
            for _, line in ipairs(sub) do
                result[#result + 1] = line
            end
        else
            result[#result + 1] = prefix .. tostring(k) .. " = " .. tostring(v)
        end
    end
    return table.concat(result, "\n")
end
