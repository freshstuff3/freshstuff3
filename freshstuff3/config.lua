-- Published command registration for the release plugin.
--
-- `command` changes the exact command name registered by the command helper.
-- `aliases` lists alternate names for the command; use {} for none.
-- `enabled = false` prevents the command from being registered.
-- `level` and `helptext` are available to host integrations through
-- helpers.command. Levels are metadata until a host enforces them.

return {
    commands = {
        ["rel.get"] = {
            command = "rel.get",
            aliases = { "releases", "rel.show", "rel.search" },
            level = 1,
            helptext = "Show releases. Sort with --c, --r, --n, --rn, --t, or --rt.",
        },
        ["rel.md"] = {
            command = "rel.md",
            aliases = { "relmd" },
            level = 1,
            helptext = "Show releases in Markdown format. Sort with --c, --r, --n, --rn, --t, or --rt.",
        },
        ["rel.details"] = {
            command = "rel.details",
            aliases = { "reldetails" },
            level = 1,
            helptext = "Show detailed release information. Sort with --c, --r, --n, --rn, --t, or --rt.",
        },
        ["rel.cat"] = {
            command = "rel.cat",
            aliases = { "rel.category" },
            level = 1,
            helptext = "Show the category tree, optionally rooted at a category.",
        },
        ["rel.fake"] = {
            command = "rel.fake",
            aliases = { "fakerel" },
            level = 3,
            helptext = "Create test releases. Usage: !rel.fake [count].",
        },
        ["rel.add"] = {
            command = "rel.add",
            aliases = { "addrel" },
            level = 1,
            helptext = "Add a release. Usage: !rel.add <category> <title>.",
        },
        ["rel.del"] = {
            command = "rel.del",
            aliases = { "delrel", "reldelete" },
            level = 3,
            helptext = "Preview release deletion, or add --imeanit to confirm a batch.",
        },
        ["rel.delcat"] = {
            command = "rel.delcat",
            aliases = { "delcat", "catdelete" },
            level = 3,
            helptext = "Preview empty-category deletion, or add --imeanit to confirm.",
        },
        ["rel.nukecat"] = {
            command = "rel.nukecat",
            aliases = { "nukecat" },
            level = 3,
            helptext = "Preview recursive category deletion, or add --imeanit to confirm.",
        },
        ["rel.move"] = {
            command = "rel.move",
            aliases = { "moverel" },
            level = 3,
            helptext = "Move releases. Usage: !rel.move <id[,id...|start-end]> <category>.",
        },
    },
}
