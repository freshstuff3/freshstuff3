# FreshStuff3 Copilot Instructions

## Runtime and validation

- This repository has no checked-in build, lint, or automated test commands, and no test files.
- Run the standalone smoke check with `lua53.exe freshstuff3.lua` from the repository root. The local REPL starts after initialization; enter `exit` to stop it. `!releases` is a useful command-dispatch smoke check.
- Runtime state under `freshstuff3/data/` is ignored by Git. Do not treat journals or category data as source fixtures.

## Architecture

- `freshstuff3.lua` is the bootstrap. Under PtokaX it loads `host/ptokax.lua` from `<PtokaX>/scripts/freshstuff3`; outside PtokaX it sets the local fallback module path and opens the standalone shell.
- `host/ptokax.lua` owns PtokaX integration and must set `package.path` before requiring project modules. It starts plugins through `Init:load_plugins()`, registers timers with `TmrMan.AddTimer(interval_ms, callback)`, and bridges PtokaX callbacks such as `ChatArrival`.
- `helpers/init.lua` builds each plugin instance by merging the category, item, journal, and UI modules. Plugins load before command/event registries are initialized; registry discovery scans `package.loaded` for `plugins.*`.
- `plugins/release.lua` is the main feature plugin. It assigns journal/category file paths, initializes persisted data, merges its business/deletion modules, and exposes `_cmd_handlers`.
- `core/item.lua` owns the in-memory release array. `core/journal.lua` replays MessagePack journal actions at startup and compacts the journal afterward. `core/category.lua` rebuilds category trees from item data and persists the category index. Treat `_data` as the source of truth for releases.
- `core/ui.lua` renders tree, Markdown, and detail output. Business methods gather IDs and defer presentation to UI methods.

## Repository conventions

- A command handler key in `plugin._cmd_handlers` must have a matching entry in `config.lua`. Command names, aliases, enablement, level, and help text belong in `config.lua`; handler functions belong in the plugin.
- Release commands use `Bus_*` business methods and `UI_*` renderers. Keep command parsing/dispatch in `plugins/release.lua`, business selection in `plugins/release/business.lua`, and formatting in `core/ui.lua`.
- Markdown/detail sorting uses internal keys `c`, `r`, `sn`, `rsn`, `st`, and `rst`; command-line switches are `--c`, `--r`, `--n`, `--rn`, `--t`, and `--rt`. Tree output intentionally ignores sort switches.
- PtokaX `ChatArrival` receives raw NMDC data such as `<Nick> !releases|`. Remove the final protocol delimiter before parsing the `<Nick>` envelope and command prefix. Return `true` only after handling a recognized command.
- For PtokaX file locations, derive the plugin directory from `Core.GetPtokaXPath()` and use `package.config:sub(1, 1)` for separators. Keep the release plugin's journal/category path construction aligned with the host bootstrap.
- The host includes a Lua 5.1 `table.move` compatibility shim; preserve it when changing host startup code.
