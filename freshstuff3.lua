--- freshstuff3.lua
--- Entry point for freshstuff3
---@todo move this into host app and hardcode for interpreter
--- since there is no way a lua script can tell its own path, we have to hardcode it here for now
--[[
Loading sequence:

We load NMDC.lua and fall back to shell therein
Obviously for verlihub, if/then/else will be used to detect host and load plugins accordingly 

But first, we need to detect OS and set the base path accordingly
Temporary for now, will move to host app and hardcode for interpreter
]]

local base_path
if package.config:sub(1,1) == "\\" then
    -- Running on Windows
    base_path = "C:\\freshstuff3\\freshstuff3\\"
else
    -- Running on Linux or macOS
    base_path = "/freshstuff3/freshstuff3/"
end

package.path = package.path .. string.format(";%s?.lua", base_path)
---@todo NMDC
require "host.ptokax"
if type(Core) ~= "table" then OnStartup() end
