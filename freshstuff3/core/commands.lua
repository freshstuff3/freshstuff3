-- core/commands.lua
---@field registry table command_name -> command_definition
---@field aliases table alias -> command_name

--- Command definition
---@class CommandDefinition
---@field func function The command handler
---@field help string Help text
---@field usage string Usage example
---@field level? number Required permission level (default: 0)

--- Register a command
---@param name string Command name (e.g., "add", "show")
---@param def CommandDefinition Command definition
---@param aliases? table List of aliases (e.g., {"del", "remove"})
---@todo Implement: store command in registry[name]
---@todo Implement: register aliases

--- Parse and execute a command
---@param input string Raw command input (e.g., "add Music/Metal Symphony")
---@param namespace table Namespace to operate on (Item, Request, etc.)
---@param user? table User context (nick, level, etc.) for permissions
---@return string output Result message
---@return number level Output level (1=user, 2=pm, 3=ops, 4=all)
---@todo Implement: split input into cmd + args
---@todo Implement: resolve aliases to command name
---@todo Implement: check permission level
---@todo Implement: call command function with args
---@todo Implement: return formatted output and level

--- Get help for a command
---@param name string Command name
---@return string help_text Formatted help text
---@todo Implement: return command.help and command.usage
---@todo Implement: list all commands if name is empty

--- List all registered commands
---@return table commands List of command names
---@todo Implement: iterate over registry
---@todo Implement: return sorted list of names

--- Add command aliases
---@param alias string Alias name
---@param target string Target command name
---@return boolean success
---@todo Implement: alias -> target mapping
---@todo Implement: check target exists
---@todo Implement: prevent alias conflicts

---@todo COMMAND SYSTEM FOR !rel PREFIX
--- - [ ] Command: !rel.show [argument]
---       No argument   → show latest 25 (configurable default)
---       <category>    → show releases in category (tree view)
---       <number>      → show latest N releases
---       <Nd/Nw/Nm>    → show releases from last N days/weeks/months
---       all           → show all releases
---       --md          → output as markdown instead of tree
---       --md=sort     → markdown with sorting (sn, sw, st, rsn, rsw, rst)
---
--- - [ ] Command: !rel.search <query> [--md] [--md=sort]
---       Search by title (case-insensitive, partial match)
---       Optional: --md for markdown output
---
--- - [ ] Command: !rel.add <category> <title> [nick]
---       Add new release
---
--- - [ ] Command: !rel.delete <id>
---       Delete release by ID
---
--- - [ ] Command: !rel.move <id> <new_category>
---       Move release to different category
---
--- - [ ] Command: !rel.cat
---       List all categories (with counts)
---
--- - [ ] Command: !rel.info <id>
---       Show detailed info for a release
---
--- - [ ] Command: !rel.stats
---       Show statistics (total items, categories, etc.)
---
---@example
---   !rel.show                        → latest 25 (tree)
---   !rel.show Music                  → Music category (tree)
---   !rel.show 10                     → latest 10 (tree)
---   !rel.show 5d                     → last 5 days (tree)
---   !rel.show 2w --md=st             → last 2 weeks, markdown sorted by title
---   !rel.search symphony --md        → search results as markdown
---   !rel.add Music New Song   → add release
---   !rel.delete 5                    → delete release 5
---   !rel.move 5 Music/Classical      → move release 5
---   !rel.cat                         → list all categories
---   !rel.info 3                      → show details for ID 3

---@class Commands
-- core/commands.lua
-- Simple command registration and dispatch

local Commands = {}
-- core/commands.lua

-- Direct registry: cmd -> handler
Commands._cmd_handlers = {}

--- ## Register a command
--- 
--- @param cmd string Command
--- @param handler function function to execute
--- @param aliases? table command aliases
function Commands:cmd_register(cmd, handler, aliases)
    self._cmd_handlers[cmd] = handler
    if not aliases or not next(aliases) then return end
    for _,alias in ipairs (aliases) do
        -- We do not check for existing here
        self._cmd_handlers[alias] = handler
    end
end

--- Register an alias (just points to another command)
function Commands:cmd_alias(alias, target)
    self._cmd_handlers[alias] = self._cmd_handlers[target]  -- Same function!
end

--- Execute command (O(1) lookup)
function Commands:cmd_execute(cmd, args)
    local handler = self._cmd_handlers[cmd]
    if not handler then
        return nil, "Unknown command: " .. cmd
    end
    return handler(args)
end

return Commands