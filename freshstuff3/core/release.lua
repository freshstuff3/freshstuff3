-- core/release.lua

local Data = require "core.data"
lcal Category = require "core.category"

Releases = {
    _data = {},              -- Private storage
    _category_tree = {},      -- Private category tree
    _category_index = {},
    tree_dirty = false
}
