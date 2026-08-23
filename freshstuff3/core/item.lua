-- core/item.lua
---@todo assertions for passed variables
---@diagnostic disable: undefined-field
---
local Item = {}
--- # INDIVIDUAL ITEM MANUPULATION FOR FRESHSTUFF3
--- 
--- CRUD operations on items
--- 
--- ## ITEMS' INITIALISATION
--- 
--- Replays and compacts the journal.
--- Does nothing with categories
--- Called on instance initialisation
--- 
--- @return boolean success  
--- @return string|nil failed Error message in case of failure
--- 
function Item:Item_init()

    local result, failed = self:Journal_replay()
    -- Check if replay failed
    if result == false then
        self._data = {}
        return false, failed or "Failed to replay journal"
    end

    -- Check if no data
    if not result or #result == 0 then
        self._data = {}
        return true
    end
    
    -- Compact the journal
    --local compact_self = { _data = result, JOURNAL_FILE = self.JOURNAL_FILE }
    self._data = result
    local succ, err = self:Journal_compact()

    if succ then
        return true, failed
    else
        self._data = nil
        return false, err
    end
end

--- ## ADD/CREATE DATA ITEM
--- 
--- Category must exist
---  
--- @param obj table { category, nick, title, when }
--- @param is_journal boolean If true, journal the addition. Default: false
--- @return boolean success 
--- @return string|integer result Error message in case of failure, item ID on success
--- 
function Item:Item_add(obj, is_journal)
    assert(obj ~= nil, "Item object unspecified!")

    if not self._category_index[obj.category] then
        return false, "Category does not exist! Needs to be created first..."
    else -- category exists
        if is_journal then
            local succ, err = self:Journal_append_add(obj)
            if not succ then
                return false, err
            end
        end
        -- Mark corresponding node as dirty
        self._category_index[obj.category].dirty = true
    end
    -- Also mark parent categories dirty
    self:Tree_mark_parents_dirty(obj.category)
    -- Finally, add the item
    table.insert(self._data, obj)
    return true, #self._data
end



--- ## MOVE ITEM BETWEEN CATEGORIES
---
--- @param id integer Item ID to move
--- @param path string New category (sanitised)
--- @param is_journal? boolean If true, journals the move. Default: false
--- @return boolean success True on success, false only
--- on serialisation failure
--- @return string? err If serialisation failed, returns the error message
--- 
function Item:Item_move_id(id, path, is_journal)   
-- TODO: check if the old category will become empty after move --- WHY???
-- WE ARE REBUILDING WHEN QUERIED
    if not self._category_index[path] then
        return false, string.format("Category %s does not exist!", path)
    end
    if not self._data[id] then
        return false, string.format("Item with ID %d does not exist!", id)
    end
    local before = self._data[id].category
    self._data[id].category = path
    self._category_index[before].dirty = true
    self._category_index[path].dirty = true
    self:Tree_mark_parents_dirty(before); self:Tree_mark_parents_dirty(path)
    -- We do not serialise categories on moved IDs. Category states are not 
    -- persistent, since a restart will result in a clean slate anyway.
    -- However, we do journal the move 
    if is_journal then
        return self:Journal_append_move(id, path, self.JOURNAL_FILE)
    end
    return true
end

--- ## DELETE DATA ITEM
---
---
---
---
---@param id integer ID of the item to delete
---@param is_journal? boolean If true, journals the deletion. Default: false
---@return boolean success True on success, false on failure
---@return table|string deleted The deleted item object on success, or error message on failure
---
function Item:Item_delete(id, is_journal)
    if not self._data[id] then
        -- Item already deleted, return success
        return false, string.format("Item with ID %d does not exist", id)
    end
    -- Store the item before deletion
    ---@type table
    local deleted_item = self._data[id]

    -- Mark category as dirty
    if deleted_item and deleted_item.category then
        local cat = deleted_item.category
        if self._category_index[cat] then
            self._category_index[cat].dirty = true
            self:Tree_mark_parents_dirty(cat)
        end
    end

    if is_journal then
        local succ = self:Journal_append_del(id)
        if not succ then
            return false, "Failed to write deletion to journal, NOT deleted"
        end
    end
    -- Remove from _data finally
    table.remove(self._data, id)
    return true, deleted_item
end

--- Retrieve items from database by ID
---@param ids table List of IDs to retrieve, single ID can be passed as a number
---@return table|boolean items Items retrieved from the database, or false on failure
---@return table|string notfound IDs not found in the database, or error string on failure
function Item:get(ids)
    ids = tonumber(ids) and { ids } or ids
    local normalized_ids, err = self:_normalize_ids(ids)
    if not normalized_ids then
        return false, err or "Invalid IDs parameter"
    end
    local items = {}
    local notfound = {}
    for _, id in ipairs(normalized_ids) do
        local obj = self._data[id]
        if obj then
            obj._id = id
            table.insert(items, obj)

        else
            table.insert(notfound, id)
        end
    end
    return items, notfound
end

--- ## VALIDATE TITLE 
--- 
--- Good to use before adding to database
--- Checks for forbidden words and duplicates
--- 
---@param title string Title of the item to validate
---@return boolean success If true, validation succeeded
---@return string? err Error message, if validation failed
---
function Item:Item_validate_title(title)
    -- sanitize: not needed
    ---@todo : config variable for FORBIDDEN
    -- local FORBIDDEN = require "config".FORBIDDEN or {}
    -- Check new item for forbidden words first
    ---@type table
    local _FORBIDDEN = FORBIDDEN or { "shit" }
    for _, word in ipairs(_FORBIDDEN) do
        if string.find(title:lower(), word:lower(), 1, true) then
            return false, string.format("Forbidden word detected %s", word)
        end
    end

    -- We only traverse _data if no forbidden words
    -- Check for 100% match
    for id, rel in ipairs(self._data) do
        if title:lower() == rel.title:lower() then
            return false, 
            string.format ("Item with the same name already exists in "..
            "database. Its ID is:\r\n\r\n%d",
            id)
        end
    end
    return true
end

--- ## ITEM SEARCH
---
--- Case-insensitive
--- Very basic but typical user has a better search tool (client)
--- 
---@param query string Search query.
---@return table result Results in items.
---@return table result_cat Results in categories.
---     Returns empty tables if no items.
--- 
function Item:Item_search(query)
    assert(type(query) == "string" and query ~= "", "Invalid search query!")
    local result, result_cat  = {}, {}
    if not query:find("%s+") then
        -- no spaces, search categories first
        for cat, _ in pairs(self._category_index) do
            if cat:lower():match(query:lower(), 1, true) then
                table.insert(result_cat, cat)
            end
        end
        -- If category found, searching for releases becomes pointless.
        if #result_cat ~= 0 then return {}, result_cat end
    end
    for id, obj in ipairs(self._data) do
        if obj.nick:lower():match(query:lower(), 1, true) or
        obj.title:lower():match(query:lower(), 1, true) then
            table.insert(result, id)
        end
    end
    return result, result_cat
end

--- ## FAKE DB GENERATOR
--- 
--- Generate fake database with random releases
--- 
--- No journaling
--- 
---@param count number Number of fake releases to generate
---@return boolean success
---@return string | nil error
---
function Item:Item_fake_database(count)
    if not count or count < 1 then
        return false, "Count must be a positive number"
    end
    if count > 10000 then
        return false, "Maximum 10000 releases allowed"
    end
    
    -- Categories with subcategories
    local category_tree = {
        ["Music"] = {
            ["Rock"] = {"Classic-Rock", "Alternative", "Progressive"},
            ["Metal"] = {"Death-Metal", "Black-Metal", "Symphonic-Metal"},
            ["Jazz"] = {"Bebop", "Cool-Jazz", "Fusion"},
            ["Classical"] = {"Baroque", "Romantic", "Modern"},
            ["Electronic"] = {"House", "Techno", "Ambient"},
        },
        ["Movies"] = {
            ["Horror"] = {"Slasher", "Supernatural", "Psychological"},
            ["Sci-Fi"] = {"Space-Opera", "Cyberpunk", "Post-Apocalyptic"},
            ["Drama"] = {"Period", "Contemporary", "Crime"},
            ["Comedy"] = {"Rom-Com", "Satire", "Slapstick"},
        },
        ["TV"] = {
            ["Animation"] = {"Anime", "Cartoon", "Stop-Motion"},
            ["Documentary"] = {"Nature", "History", "True-Crime"},
            ["Drama"] = {"Crime", "Medical", "Legal"},
            ["Comedy"] = {"Sitcom", "Sketch", "Improvisation"},
        },
        ["Games"] = {
            ["RPG"] = {"Fantasy", "Sci-Fi", "Post-Apocalyptic"},
            ["FPS"] = {"Military", "Sci-Fi", "Horror"},
            ["Strategy"] = {"RTS", "Turn-Based", "4X"},
            ["Platformer"] = {"2D", "3D", "Puzzle"},
        },
        ["Software"] = {
            ["Tools"] = {"Development", "Design", "Audio"},
            ["Games"] = {"Indie", "AAA", "Retro"},
            ["Utilities"] = {"System", "Network", "Security"},
        },
    }
    
    -- Extract all category paths
    local all_categories = {}
    for main, subcats in pairs(category_tree) do
        table.insert(all_categories, main)
        for sub, subsubs in pairs(subcats) do
            local path = main .. "/" .. sub
            table.insert(all_categories, path)
            for _, subsub in ipairs(subsubs) do
                table.insert(all_categories, path .. "/" .. subsub)
            end
        end
    end
    
    -- Nicks
    local nicks = {
        "MusicLover", "Audiophile", "DJ_Sonic", "GuitarHero", "DrummerBoy",
        "RetroFan", "VinylCollector", "JazzCat", "SmoothOperator", "BebopKing",
        "Maestro", "PianoMan", "RomanticSoul", "ChopinFan", "MetalHead",
        "ThrashLord", "DeathMetalFan", "GoreLord", "SkeletonKey", "OrchestraNerd",
        "EpicFan", "FilmBuff", "HorrorFan", "SlasherGuy", "GhostHunter",
        "SpaceCadet", "RobotLover", "BingeWatcher", "CartoonFan", "AnimeLover",
        "NatureLover", "HistoryBuff", "Gamer", "RPGMaster", "FPSPro",
        "StrategyGenius", "PlatformerKing", "DevGuru", "DesignWizard",
        "AudioEngineer", "RetroGamer", "TechEnthusiast", "SecurityExpert",
    }
    
    local title_parts = {
        "Greatest Hits", "Ultimate Collection", "The Best Of", "Essential",
        "Masterpiece", "Symphony", "Anthology", "Chronicles", "Legend",
        "Classic", "Modern", "Revolutionary", "Timeless", "Epic",
        "Dark", "Light", "Eternal", "Infinite", "Beyond",
        "Dream", "Nightmare", "Reality", "Fantasy", "Myth",
        "Volume 1", "Volume 2", "Volume 3", "The Beginning", "The End",
        "Origins", "Destiny", "Awakening", "Rebirth", "Phoenix",
        "Stories", "Tales", "Fables", "Sagas", "Legends",
        "Echoes", "Shadows", "Crimson", "Emerald", "Golden",
    }
    
    local titles = {
        "Symphony of Destruction", "The Dark Side", "Ride the Lightning",
        "Master of Puppets", "Back in Black", "The Wall", "Dark Side of the Moon",
        "Thriller", "Purple Rain", "Hotel California", "Stairway to Heaven",
        "Bohemian Rhapsody", "Imagine", "Yesterday", "Hey Jude",
        "Like a Rolling Stone", "Respect", "What's Going On", "Smells Like Teen Spirit",
        "Civilization", "The Art of War", "The Prince", "The Republic",
        "A Tale of Two Cities", "War and Peace", "The Great Gatsby",
        "1984", "Brave New World", "Fahrenheit 451", "The Catcher in the Rye",
        "The Matrix", "Inception", "Interstellar", "The Dark Knight",
        "Pulp Fiction", "Forrest Gump", "The Shawshank Redemption",
        "The Godfather", "The Silence of the Lambs", "The Big Lebowski",
    }
    
    -- ✅ Step 1: Create ALL categories first    
    for _, cat_path in ipairs(all_categories) do
        if not self._category_index[cat_path] then
            self:Category_create(cat_path)
        end
    end
    
    -- ✅ Step 2: Clear existing data
    self._data = {}
    self.next_id = 1
    
    -- ✅ Step 3: Generate and add releases
    local now = os.time()
    
    for i = 1, count do
        local category = all_categories[math.random(#all_categories)]
        local title
        if math.random() < 0.3 then
            title = titles[math.random(#titles)]
        else
            local parts = {}
            local num_parts = math.random(1, 3)
            for _ = 1, num_parts do
                table.insert(parts, title_parts[math.random(#title_parts)])
            end
            title = table.concat(parts, " ")
        end
        title = title .. " " .. math.random(1, 999)
        
        local release = {
            category = category,
            title = title,
            nick = nicks[math.random(#nicks)],
            when = now - math.random(86400 * 365 * 2),
        }
        
        -- ✅ Temporarily disable journaling
        local success, err = self:Item_add(release, false)
        
        if not success then
            return false, "Failed to add release: " .. err
        end
    end
    
    return true, string.format("Generated %d fake releases", #self._data)
end

return Item