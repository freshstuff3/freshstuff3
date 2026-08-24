---@diagnostic disable: undefined-global
-- host/ptokax.lua

local path_separator = package.config:sub(1, 1)
local base_path
if type(Core) == "table" and type(Core.GetPtokaXPath) == "function" then
    local ptokax_path = Core.GetPtokaXPath()
    assert(type(ptokax_path) == "string", "Core.GetPtokaXPath() must return a string")
    if not ptokax_path:match("[/\\]$") then
        ptokax_path = ptokax_path .. path_separator
    end
    base_path = ptokax_path .. "scripts" .. path_separator .. "freshstuff3" .. path_separator
elseif path_separator == "\\" then
    base_path = "C:\\freshstuff3\\freshstuff3\\"
else
    base_path = "/freshstuff3/freshstuff3/"
end

package.path = package.path .. string.format(";%s?.lua", base_path)

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

-- Access helper functions 
local Event = require "helpers.event"
local Init = require "helpers.init"

-- ---- HOST EVENT BRIDGE ----
---
function OnStartup()
    if type(Core) ~= "table" then
        Init:load_plugins()
        if package.config:sub(1,1) == "\\" then
            -- Running on Windows
            os.execute("chcp 65001 > nul 2>&1")
            print("🔧 Console set to UTF-8")
        end
        Init:open_lua_shell()
        return
    end
    TmrMan.AddTimer(1000, function ()
       do return end
    end)
    -- Event.fire("HostStarted", "PtokaX", Core.Version)
end

function ChatArrival(user, data)
    local nick = user
    if type(user) == "table" then
        nick = user.sNick
    end
    local cmd, args = data:match("^!(%S+)%s*(.*)$")
    if cmd then
        cmd = cmd:lower()
    end
    local Command = require "helpers.command"
    if Command._registry[cmd] then
        local success, result = Command:execute(cmd, args, nick)
        if not success then
            Core.SendToNick(nick, "Error: " .. result)
        else
            Core.SendToNick(nick, result)
        end
        return true
    end
    --Event.fire("Chat", nick, data)
end

function ToArrival(user, data)
    local nick = user
    if type(user) == "table" then
        nick = user.sNick
    end
    --Event.fire("PrivMsg", nick, data)
end

function UserConnected(user)
    local nick = user
    if type(user) == "table" then
        nick = user.sNick
    end
    --Event.fire("UserConnected", nick, user.iProfile)
end

function UserDisconnected(user)
    local nick = user
    if type(user) == "table" then
        nick = user.sNick
    end
    --Event.fire("UserDisconnected", nick)
end

--function OnError(err)
    --Event.fire("Error", err)
--end
