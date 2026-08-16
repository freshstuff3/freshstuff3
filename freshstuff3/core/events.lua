-- core/events.lua
---@field handlers table event_name -> list of handler functions
---@field timer_handlers table interval -> list of handler functions



--- Unregister an event handler
---@param event string Event name
---@param handler_id number Handler ID returned by on()
---@return boolean success
---@todo Implement: remove handler from handlers[event] using handler_id
---@todo Implement: return false if event or handler not found

--- Fire an event
---@param event string Event name
---@param ... any Arguments to pass to handlers
---@todo Implement: call all handlers for the event
---@todo Implement: wrap each handler in pcall for error isolation
---@todo Implement: capture and log errors
---@todo Implement: pass event name and arguments

--- Register a timer handler (runs periodically)
---@param interval number Seconds between calls
---@param handler function Function to call
---@return number timer_id Unique timer ID
---@todo Implement: store timer with interval, last_run, handler
---@todo Implement: return timer_id for cancellation

--- Cancel a timer
---@param timer_id number Timer ID returned by on_timer()
---@return boolean success
---@todo Implement: remove timer from timers list
---@todo Implement: return false if timer not found

--- Process timers (call from main loop/OnTimer)
---@param timestamp? number Current time (default: os.time())
---@todo Implement: iterate over timers
---@todo Implement: check if interval has passed
---@todo Implement: call handler if elapsed >= interval
---@todo Implement: update last_run
---@todo Implement: wrap in pcall for error isolation

---@class Events
local Event = {
    _events = {}
}


--- Register an event handler
---@param event string Event name (e.g., "RelAdded", "RelDeleted", "CategoryCreated")
---@param handler function Function to call when event fires
---@param priority? number Higher priority = called first (default: 0)
---@todo Implement: store handler in handlers[event] table
---@todo Implement: sort by priority
---@todo Implement: return unique handler ID for unregister
Event:Event_register = function(name, function)
    self._events[name] = self._events[name]  or {}
    table.insert(self._events[name], function)


-- Define event signatures in one place
Event_define("RelAdded", {
    fields = {"nick", "category", "title", "id"},
    description = "Fired when a release is added",
})

-- Fire checks argument count
function Event.fire(name, ...)
    local sig = Event.signatures[name]
    if sig then
        local args = {...}
        if #args < #sig.fields then
            error(string.format("Event %s: expected %d args, got %d", 
                name, #sig.fields, #args))
        end
    end
    -- Fire handlers...
end