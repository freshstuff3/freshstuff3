-- core/events.lua
-- Global event system - nothing instance-specific
--[[
-- Registration
xxx._event_handlers = {
    CategoryPostDelete = {
        {
            priority = 10,
            func = function(self, data)
                -- handle event
            end
        }
    },
    ItemsPostDelete = {
        {
            priority = 5,
            func = function(self, data)
                -- handle event
            end
        },
        {
            priority = 1,
            func = function(self, data)
                -- another handler for same event
            end
        }
    }
}
]]

local Event = {}
Event._registry = {}  -- event_name -> list of { instance, handler, priority }

function Event:init()
    for module_name, module in pairs(package.loaded) do
        if module_name:match("^plugins%.%S+$") then
            if type(module) == "table" and module._event_handlers then
                self:_register_plugin(module)
            end
        end
    end
end

function Event:_register_plugin(plugin)
    for event_name, handlers in pairs(plugin._event_handlers) do
        for _, h in ipairs(handlers) do
            if type(h) == "table" and type(h.func) == "function" then
                local priority = h.priority or 0
                
                if not self._registry[event_name] then
                    self._registry[event_name] = {}
                end
                
                table.insert(self._registry[event_name], {
                    instance = plugin,
                    handler = h.func,
                    priority = priority,
                })
                
                table.sort(self._registry[event_name], function(a, b)
                    return a.priority > b.priority
                end)
            end
        end
    end
end

function Event:fire(event_name, data)
    
    local handlers = self._registry[event_name]
    if not handlers or #handlers == 0 then
        return { ok = true, errors = {} }
    end
    
    local errors = {}
    local cancelled = false
    local cancel_reason = nil
    
    data.cancel = function(reason)
        cancelled = true
        cancel_reason = reason or "Cancelled by event handler"
    end
    
    for _, entry in ipairs(handlers) do
        local ok, err = pcall(entry.handler, entry.instance, data)
        if not ok then
            table.insert(errors, {
                instance = entry.instance,
                error = err,
            })
        end
        if cancelled then
            break
        end
    end
    
    return {
        ok = #errors == 0,
        errors = errors,
        cancelled = cancelled,
        cancel_reason = cancel_reason,
    }
end

---@todo need separate timer fire for multitimer
return Event

