-- core/search.lua
---@class Search
---@field namespace table Reference to the data namespace (Item, Request, etc.)
---@field results table Cached search results for pagination
---@field last_query string Last search query for reference
local Search = {}

--- MIGHT INTEGRATE WITH UI

--- Search by title (case-insensitive, partial match)
---@param query string Search term
---@param namespace table Namespace to search (Item._data)
---@param options? table Optional: {exact = boolean, case_sensitive = boolean}
---@return table ids Matching release IDs
---@todo Implement: iterate over namespace._data, match title:lower():find(query:lower())
---@todo Implement: options.exact for exact match
---@todo Implement: options.case_sensitive for case-sensitive search
---@todo Implement: return table of IDs, sorted by relevance or date
function Search:by_title() end

--- Search by category (exact or partial)
---@param query string Category path (e.g., "Music/Metal")
---@param namespace table Namespace to search
---@param options? table Optional: {exact = boolean, include_subcategories = boolean}
---@return table ids Matching release IDs
---@todo Implement: exact match vs partial match
---@todo Implement: include_subcategories (use Category:get_subcat)
function Search:by_category() end

--- Search by nick (who added it)
---@param query string Nickname
---@param namespace table Namespace to search
---@param options? table Optional: {exact = boolean}
---@return table ids Matching release IDs
---@todo Implement: iterate over namespace._data, match nick:lower():find(query:lower())
function Search:by_nick() end

--- Search by date range
---@param from number Unix timestamp (start)
---@param to number Unix timestamp (end)
---@param namespace table Namespace to search
---@return table ids Matching release IDs
---@todo Implement: check item.when >= from and item.when <= to
---@todo Implement: handle "today", "yesterday", "last N days" shortcuts
function Search:by_date_range() end

--- Combined search (title + category + nick)
---@param query string Search term
---@param namespace table Namespace to search
---@param fields? table Optional: {"title", "category", "nick"} (default: all)
---@return table ids Matching release IDs
---@todo Implement: search across multiple fields
---@todo Implement: deduplicate results
---@todo Implement: sort by date (newest first)
function Search:combined() end

--- Pagination support
---@param ids table List of IDs
---@param page number Page number (1-indexed)
---@param page_size number Items per page
---@return table paged_ids Subset of IDs for the requested page
---@return number total_pages Total pages available
---@todo Implement: slice ids based on page and page_size
---@todo Implement: return total count for pagination metadata
function Search:paginate() end


