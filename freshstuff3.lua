-- freshstuff3.lua
-- Entry point for freshstuff3
---@todo move this into host app and hardcode for interpreter
--- since there is no way a lua script can tell its own path, we have to hardcode it here for now
base_path = "C:\\freshstuff3\\freshstuff3\\"
package.path = package.path .. string.format(";%s?.lua", base_path)
-- ============================================================================
-- Load AllStuff
--- Loading sequence:
--- Detect host -> Hand over to host so that it can load plugins and then do its thing
--- No host detected -> Load plugins and start REPL console 
--- 
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

--- We load ptokax.lua and fall back to shell therein
--- Obviously for verlihub, if/then/else will be used to detect host and load plugins accordingly 
---
--- But first, we need to detect OS and set the base path accordingly
--- Temporary for now, will move to host app and hardcode for interpreter
local base_path
if package.config:sub(1,1) == "\\" then
    -- Running on Windows
    base_path = "C:\\freshstuff3\\freshstuff3\\"
else
    -- Running on Linux or macOS
    base_path = "/freshstuff3/"
end

package.path = package.path .. string.format(";%s?.lua", base_path)
require "host.ptokax"
if type(Core) ~= "table" then OnStartup() end
