-- helpers/command.lua
-- Global command system - scan once on init, then use cache

local Commands = { _registry = {}, _config = {} }

--- Initialise after plugins have loaded so their command handlers are discoverable.
function Commands:init()
    self._registry = {}
    self._config = require "config"
    assert(type(self._config) == "table", "config.lua must return a table")

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
            local config = self._config.commands and self._config.commands[cmd_name]
            assert(type(config) == "table", "Missing config for command: " .. cmd_name)
            if config.enabled ~= false then
                assert(type(config.command) == "string", "Command name must be a string: " .. cmd_name)
                assert(type(config.aliases) == "table", "Command aliases must be a table: " .. cmd_name)
                assert(type(config.level) == "number", "Command level must be a number: " .. cmd_name)
                assert(type(config.helptext) == "string", "Command helptext must be a string: " .. cmd_name)

                self._registry[config.command] = {
                    instance = plugin,
                    handler = cmd_def.func,
                    level = config.level,
                    helptext = config.helptext,
                }

                for _, alias in ipairs(config.aliases) do
                    self._registry[alias] = {
                        instance = plugin,
                        handler = cmd_def.func,
                        level = config.level,
                        helptext = config.helptext,
                        is_alias = true,
                        target = config.command,
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
end

function Commands:get_help(command)
    local entry = self._registry[command]
    if not entry then
        return false, "Unknown command: " .. command
    end
    return entry.helptext
end

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
