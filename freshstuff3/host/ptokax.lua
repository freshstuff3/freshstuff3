---@diagnostic disable: undefined-global
-- host/ptokax.lua


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
---@diagnostic disable-next-line: unresolved-require
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
        -- Event.fire("Timer", os.time())
    end)
    -- Event.fire("HostStarted", "PtokaX", Core.Version)
    end
end

TmrMan.AddTimer(1000, function ()
    print(os.time())
    -- Event.fire("Timer", os.time())
end)

function ChatArrival(user, data)
    local nick = user
    if type(user) == "table" then
        nick = user.sNick
    end
    E--vent.fire("Chat", nick, data)
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

function OnError(err)
    --Event.fire("Error", err)
end
