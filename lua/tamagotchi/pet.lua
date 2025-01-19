local Pet = {}
Pet.__index = Pet

function Pet:new(o)
    o = o or {}
    setmetatable(o, Pet)

    local config = require("tamagotchi.config").values

    if not o.name then
        vim.notify("Pet created without a name!", vim.log.levels.WARN)
    end

    -- use sprites from global config defaults if not provided

    if not o.sprites then
        -- Attempt to find sprites based on the pet's name in the config
        local found = false
        if o.name then
            for _, pet_def in ipairs(config.pets or {}) do
                if pet_def.name == o.name and pet_def.sprites then
                    o.sprites = pet_def.sprites
                    found = true
                    break
                end
            end
        end

        -- If sprites are still not found, assign empty tables and warn
        if not found then
            vim.notify(
                "Pet "
                    .. (o.name or "unknown")
                    .. " has no sprites and no default sprites found! Using empty sprite sets.",
                vim.log.levels.WARN
            )
            o.sprites = { happy = {}, hungry = {}, neutral = {} }
        end
    end
    -- setup mood and satiety
    o.initial_mood = o.initial_mood or config.initial_mood or 80
    o.initial_satiety = o.initial_satiety or config.initial_satiety or 80
    o.mood = o.mood or o.initial_mood
    o.satiety = o.satiety or o.initial_satiety

    -- assign non-critical values without warning
    o.tick_length_ms = o.tick_length_ms or 100
    o.sprite_update_interval = o.sprite_update_interval or 5
    o.birth_time = o.birth_time or vim.loop.now()
    o.mood_decay_probability = o.mood_decay_probability or 0.02
    o.satiety_decay_probability = o.satiety_decay_probability or 0.02

    -- state variables for rendering
    o.sprite_indices = { happy = 1, hungry = 1, neutral = 1 }
    o.last_state = nil

    return o
end
------------------------------------------------------------------------
-- get / set
------------------------------------------------------------------------

function Pet:set_name(value) self.name = value end

function Pet:get_name() return self.name end

function Pet:get_satiety() return self.satiety end

function Pet:set_satiety(value) self.satiety = math.max(1, math.min(100, value)) end

function Pet:get_mood() return self.mood end

function Pet:set_mood(value) self.mood = math.max(1, math.min(100, value)) end

function Pet:get_age() return ((vim.loop.now() - self.birth_time) / 1000) end

function Pet:get_age_formatted()
    local elapsed = math.floor(self:get_age())

    local years = math.floor(elapsed / (365 * 24 * 3600))
    elapsed = elapsed - years * 365 * 24 * 3600
    local days = math.floor(elapsed / (24 * 3600))
    elapsed = elapsed - days * 24 * 3600
    local hours = math.floor(elapsed / 3600)
    elapsed = elapsed - hours * 3600
    local minutes = math.floor(elapsed / 60)
    local seconds = elapsed - minutes * 60

    local parts = {}
    local started = false

    if years > 0 then
        started = true
        table.insert(parts, years .. "yr")
    end
    if started or days > 0 then
        started = true
        table.insert(parts, days .. "day")
    end
    if started or hours > 0 then
        started = true
        table.insert(parts, hours .. "hr")
    end
    if started or minutes > 0 then
        started = true
        table.insert(parts, minutes .. "min")
    end

    table.insert(parts, seconds .. "sec")

    return table.concat(parts, " ")
end

-- convert pet to a plain table for serialization
function Pet:to_table()
    local t = {}
    for key, value in pairs(self) do
        t[key] = value
    end
    return t
end

------------------------------------------------------------------------
-- state updating
------------------------------------------------------------------------

-- decrement satiety and mood
function Pet:update()
    if math.random() < self.mood_decay_probability then
        self:set_mood(math.max(1, self.mood - 1))
    end
    if math.random() < self.satiety_decay_probability then
        self:set_satiety(math.max(1, self.satiety - 1))
    end
end

function Pet:increase_mood(amount)
    amount = amount or 1
    self:set_mood(self.mood + amount)
end

function Pet:increase_satiety(amount)
    amount = amount or 1
    self:set_satiety(self.satiety + amount)
end
------------------------------------------------------------------------
-- sprite logic
------------------------------------------------------------------------

local function determine_state(pet)
    if pet.satiety < 70 then
        return "hungry"
    elseif pet.mood > 70 then
        return "happy"
    else
        return "neutral"
    end
end

function Pet:get_sprite()
    local state = determine_state(self)

    -- reset sprite index if state has changed
    if not self.last_state or self.last_state ~= state then
        self.last_state = state
        self.sprite_indices[state] = 1
    end

    local sprite_list = self.sprites[state] or {}
    if #sprite_list == 0 then return "" end

    local idx = self.sprite_indices[state] or 1
    local sprite = sprite_list[idx] or sprite_list[1]

    self.sprite_indices[state] = (idx % #sprite_list) + 1

    return sprite
end

------------------------------------------------------------------------
-- persistence
------------------------------------------------------------------------

-- save pet state to a file (default path in Neovim data directory)
function Pet:save(filepath)
    filepath = filepath or (vim.fn.stdpath("data") .. "/tamagotchi.json")

    -- ensure dir exists
    local dir = vim.fn.fnamemodify(filepath, ":h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

    local data = vim.fn.json_encode(self:to_table())
    vim.fn.writefile({ data }, filepath)
end

-- load pet state from a file, returns a new Pet or nil if file does not exist
function Pet.load(filepath)
    filepath = filepath or (vim.fn.stdpath("data") .. "/tamagotchi.json")

    if vim.fn.filereadable(filepath) == 0 then return nil end

    local lines = vim.fn.readfile(filepath)
    if not lines or #lines == 0 then return nil end

    local content = table.concat(lines, "")
    local status, data = pcall(vim.fn.json_decode, content)
    if not status or type(data) ~= "table" then return nil end

    return Pet:new(data)
end

return Pet
