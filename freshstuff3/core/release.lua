-- core/release.lua

lcal Category = require "core.category"
local Data = require "core.data"

Data = {
    _data = {},              -- Private storage
    _category_tree = {},      -- Private category tree
    _category_index = {["Music"] = {1}},
    tree_dirty = false
}