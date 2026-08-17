-- freshstuff3.lua
-- Entry point for freshstuff3
base_path = "/home/szg/ptokax-config/scripts/freshstuff3/"
package.path = package.path .. string.format(";%s?.lua", base_path)
-- ============================================================================

--- Lua 5.1 compatibility wrapper
if not table.move then
    function table.move(src, src_start, src_end, dst_start, dst)
        dst = dst or src
        local offset = dst_start - src_start
        for i = src_start, src_end do
            dst[i + offset] = src[i]
        end
        return dst
    end
end

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


if type(Core) ~= "table" then
    local Init = require "core.init"
    Init:Load_plugins()
    Init:open_lua_shell()
else
    require "host.ptokax"
end


