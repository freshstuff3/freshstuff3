--- freshstuff3.lua
--- Entry point for freshstuff3
--[[
Loading sequence:

We load NMDC.lua and fall back to shell therein
Obviously for verlihub, if/then/else will be used to detect host and load plugins accordingly 

When running under PtokaX, use its configured scripts directory.
The standalone fallback remains for the local Lua interpreter.
]]

local path_separator = package.config:sub(1, 1)
local base_path
if type(Core) == "table" and type(Core.GetPtokaXPath) == "function" then
    local ptokax_path = Core.GetPtokaXPath()
    if not ptokax_path:match("[/\\]$") then
        ptokax_path = ptokax_path .. path_separator
    end
    base_path = ptokax_path .. "scripts" .. path_separator .. "freshstuff3" .. path_separator
elseif path_separator == "\\" then
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
