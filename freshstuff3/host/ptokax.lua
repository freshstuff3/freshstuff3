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
        Init:open_lua_shell()
    else
        SetTimer(1000)
        StartTimer()
    -- Event.fire("HostStarted", "PtokaX", Core.Version)
    end
end

function OnTimer()
    print(os.time())
    -- Event.fire("Timer", os.time())
end

function ChatArrival(user, data)
    
    Event.fire("Chat", user.sNick, data)
end

function ToArrival(user, data)
    Event.fire("PrivMsg", user.sNick, data)
end

function UserConnected(user)
    Event.fire("UserConnected", user.sNick, user.iProfile)
end

function UserDisconnected(user)
    Event.fire("UserDisconnected", user.sNick)
end

function OnError(err)
    Event.fire("Error", err)
end
