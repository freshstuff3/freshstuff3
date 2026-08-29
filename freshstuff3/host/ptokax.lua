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

--- Escape text that will be embedded in an NMDC message.
--- NMDC reserves "|" as its message terminator; its character entity displays
--- as a literal pipe in DC++ without splitting the protocol message.
---@param message string
---@return string
local function escape_nmdc_message(message)
    return tostring(message):gsub("%z", ""):gsub("|", "&#124;")
end

--- Send a response to a private command.
---@param nick string
---@param message string
local function send_to_nick(nick, message)
    Core.SendToNick(nick,
        "$To: " .. nick .. " From: FreshStuff3 $<FreshStuff3> " ..
        escape_nmdc_message(message) .. "|")
end

--- Send a response to a main-chat command only to the issuer's main chat.
---@param nick string
---@param message string
local function send_to_main_chat(nick, message)
    Core.SendToNick(nick, "<FreshStuff3> " .. escape_nmdc_message(message) .. "|")
end

-- ---- HOST EVENT BRIDGE ----
---
function OnStartup()
    Init:load_plugins()
    if type(Core) ~= "table" then
        if package.config:sub(1,1) == "\\" then
            -- Running on Windows
            os.execute("chcp 65001 > nul 2>&1")
            print("🔧 Console set to UTF-8")
        end
        Init:open_lua_shell()
        return
    end
--[[     local timer_id = TmrMan.AddTimer(1000, function ()
        Core.SendToAll("<b_e> " .. os.time() .. "|")
    end)
    assert(timer_id, "Failed to register freshstuff3 timer") ]]
    -- Event.fire("HostStarted", "PtokaX", Core.Version)
end

function ChatArrival(user, data)
    local nick = type(user) == "table" and user.sNick or   user
    data = data:sub(1, -2)
    local prefix, cmd = data:match("^%b<>%s*(%p)(%S+)")
    if prefix ~= "!" or not cmd then
        return
    end

    cmd = cmd:lower()
    local args = data:match("^%b<>%s*!%S+%s*(.*)$") or ""
    local Command = require "helpers.command"
    if Command._registry[cmd] then
        local success, result = Command:execute(cmd, args, nick)
        if not success then
            send_to_main_chat(nick, "Error: " .. result)
        else
            send_to_main_chat(nick, result)
        end
        return true
    end
    --Event.fire("Chat", nick, data)
end

function ToArrival(user, data)
    local nick = type(user) == "table" and user.sNick or user
    data = data:sub(1, -2)
    local prefix, cmd = data:match("%$<[^>]+>%s*(%p)(%S+)")
    if prefix ~= "!" or not cmd then
        return
    end

    cmd = cmd:lower()
    local args = data:match("%$<[^>]+>%s*!%S+%s*(.*)$") or ""
    local Command = require "helpers.command"
    if Command._registry[cmd] then
        local success, result = Command:execute(cmd, args, nick)
        if not success then
            send_to_nick(nick, "Error: " .. result)
        else
            send_to_nick(nick, result)
        end
        return true
    end
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
