
-- host/ptokax.lua

-- ---- HOST EVENT BRIDGE ----

function OnStartup()
    Event.fire("HostStarted", "PtokaX", Core.Version)
end

function OnTimer()
    Event.fire("Timer", os.time())
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
