--- freshstuff3.lua
--- Entry point for freshstuff3
---@todo NMDC

if type(Core) == "table" and type(Core.GetPtokaXPath) == "function" then
    local path_separator = package.config:sub(1, 1)
    local ptokax_path = Core.GetPtokaXPath()
    assert(type(ptokax_path) == "string", "Core.GetPtokaXPath() must return a string")
    if not ptokax_path:match("[/\\]$") then
        ptokax_path = ptokax_path .. path_separator
    end

    local host_path = ptokax_path .. "scripts" .. path_separator ..
        "freshstuff3" .. path_separator .. "host" .. path_separator .. "ptokax.lua"
    package.loaded["host.ptokax"] = dofile(host_path) or true
else
    if package.config:sub(1, 1) == "\\" then
        package.path = package.path .. ";C:\\freshstuff3\\freshstuff3\\?.lua"
    else
        package.path = package.path .. ";/freshstuff3/freshstuff3/?.lua"
    end
    require "host.ptokax"
    OnStartup()
end
