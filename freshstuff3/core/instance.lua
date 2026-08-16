-- core/instance.lua
-- Creates and returns an object instance
-- 
local Instance = {}

function Instance:new()
    -- Create basic layout
    local obj = {
        _data = {},
        _category_index = {},
        _category_tree = {},
    }
    
    -- Attach all functions
    local function merge(module)
        for k, v in pairs(module) do
            obj[k] = v
        end
    end
    
    merge(require "core.ui")
    merge(require "core.category")
    merge(require "core.item")
    merge(require "core.journal")
    merge(require "core.commands")
    merge(require "host.lua")
    -- events
    
    setmetatable(obj, { __index = self })
    return obj
end

return Instance
