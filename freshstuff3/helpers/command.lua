-- core/commands.lua
-- Global command system - scan once on init, then use cache

local Commands = {}

_registry = {},  -- command_name -> { instance, handler, level, aliases }

---@note should be required inside hsotapp main stack
function Commands:init()
    for module_name, module in pairs(package.loaded) do
        if module_name:match("^plugins%.%S+$") then
            if type(module) == "table" and module._cmd_handlers then
                self:_register_plugin(module)
            end
        end
    end
end


function Commands:_register_plugin(plugin)
    for cmd_name, cmd_def in pairs(plugin._cmd_handlers) do
        if type(cmd_def) == "table" and type(cmd_def.func) == "function" then
            self._registry[cmd_name] = {
                -- reference to the instance where it was created
                instance = plugin,
                handler = cmd_def.func,
                level = cmd_def.level or 0,
            }
            
            -- Aliases
            if cmd_def.aliases then
                for _, alias in ipairs(cmd_def.aliases) do
                    self._registry[alias] = {
                        instance = plugin,
                        handler = cmd_def.func,
                        level = cmd_def.level or 0,
                        is_alias = true,
                        target = cmd_name,
                    }
                end
            end
        end
    end
end

function Commands:execute(command, params, user)
    local entry = self._registry[command]
    if not entry then
        return false, "Unknown command: " .. command
    end
    
    local result, err = entry.handler(entry.instance, params, user)
    if err then
        return false, err
    end
    
    return true, result
end,

function Commands:list()
    local cmds = {}
    for name, entry in pairs(self._registry) do
        if not entry.is_alias then
            table.insert(cmds, name)
        end
    end
    table.sort(cmds)
    return cmds
end

return Commands


