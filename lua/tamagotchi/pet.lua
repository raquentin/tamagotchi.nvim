local Pet = {}
Pet.__index = Pet

local DECAY_CLASSES = {
    [0] = { mood = 0.0, satiety = 0.0 },
    [1] = { mood = 0.01, satiety = 0.01 },
    [2] = { mood = 0.03, satiety = 0.03 },
    [3] = { mood = 0.05, satiety = 0.05 },
    [4] = { mood = 0.08, satiety = 0.08 },
    [5] = { mood = 0.12, satiety = 0.12 },
    [6] = { mood = 0.20, satiety = 0.20 },
}

local function find_pet_def_by_name(name)
    local config = require("tamagotchi.config").values
    if not name or not config.pets then return nil end

    for _, pet_def in ipairs(config.pets) do
        if pet_def.name == name then return pet_def end
    end

    return nil
end

function Pet:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    local config = require("tamagotchi.config").values

    if not o.name then
        vim.notify("pet created without a name!", vim.log.levels.DEBUG)
    end

    if not o.sprites and o.name then
        local pet_def = find_pet_def_by_name(o.name)
        if pet_def and pet_def.sprites then             o.sprites = pet_def.sprites end
    end

    if not o.sprites then
        vim.notify(
            string.format(
                "pet '%s' has no sprites! using empty sprite sets.",
                o.name or "unknown"
            ),
            vim.log.levels.DEBUG
        )
        o.sprites = { happy = {}, hungry = {}, neutral = {} }
    end

    o.initial_mood = o.initial_mood or config.initial_mood or 80
    o.initial_satiety = o.initial_satiety or config.initial_satiety or 80
    o.mood = o.mood or o.initial_mood
    o.satiety = o.satiety or o.initial_satiety

    o.tick_length_ms = o.tick_length_ms or 100
    o.sprite_update_interval = o.sprite_update_interval or 5
    o.birth_time = o.birth_time or vim.loop.now()

    o.decay_speed = (o.decay_speed ~= nil) and o.decay_speed or 3
    local class_vals = DECAY_CLASSES[o.decay_speed] or DECAY_CLASSES[3]
    o.mood_decay_probability = class_vals.mood
    o.satiety_decay_probability = class_vals.satiety

    o.sprite_indices = { happy = 1, hungry = 1, neutral = 1 }
    o.last_state = nil

    o.last_vim_close_time = o.last_vim_close_time or vim.loop.now()
    o.last_window_close_time = o.last_window_close_time or vim.loop.now()

    o.session_start_time = o.session_start_time or vim.loop.now()
    o.total_vim_events = o.total_vim_events or 0
    o.total_mood_gained = o.total_mood_gained or 0
    o.total_satiety_gained = o.total_satiety_gained or 0
    o.times_fed = o.times_fed or 0
    o.times_played_with = o.times_played_with or 0

    o.color_theme = o.color_theme or nil

    return o
end

function Pet:set_name(value)
    assert(type(value) == "string", "name must be a string")
    assert(#value > 0, "name cannot be empty")
    self.name = value
end

function Pet:get_name() return self.name end

function Pet:get_satiety() return self.satiety end

function Pet:set_satiety(value)
    assert(type(value) == "number", "satiety must be a number")
    self.satiety = math.max(1, math.min(100, value))
end

function Pet:get_mood() return self.mood end

function Pet:set_mood(value)
    assert(type(value) == "number", "mood must be a number")
    self.mood = math.max(1, math.min(100, value))
end

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
    if started or minutes > 0 then table.insert(parts, minutes .. "min") end

    table.insert(parts, seconds .. "sec")

    return table.concat(parts, " ")
end

function Pet:to_table()
    local t = {}
    for key, value in pairs(self) do
        t[key] = value
    end
    return t
end

function Pet:update()
    -- Use separate random values to avoid correlation between mood and satiety decay
    local rand_mood = math.random()
    if rand_mood < self.mood_decay_probability then
        self:set_mood(math.max(10, self.mood - 1))
    end

    local rand_satiety = math.random()
    if rand_satiety < self.satiety_decay_probability then
        self:set_satiety(math.max(10, self.satiety - 1))
    end
end

function Pet:increase_mood(amount)
    amount = amount or 1
    assert(type(amount) == "number", "amount must be a number")
    assert(amount >= 0, "amount must be non-negative")
    self:set_mood(self.mood + amount)
    self.total_mood_gained = (self.total_mood_gained or 0) + amount
    self.times_played_with = (self.times_played_with or 0) + 1
end

function Pet:increase_satiety(amount)
    amount = amount or 1
    assert(type(amount) == "number", "amount must be a number")
    assert(amount >= 0, "amount must be non-negative")
    self:set_satiety(self.satiety + amount)
    self.total_satiety_gained = (self.total_satiety_gained or 0) + amount
    self.times_fed = (self.times_fed or 0) + 1
end

function Pet:record_event()
    self.total_vim_events = (self.total_vim_events or 0) + 1
end

function Pet:get_session_duration()
    return (vim.loop.now() - (self.session_start_time or vim.loop.now())) / 1000
end

function Pet:reset()
    self.mood = self.initial_mood
    self.satiety = self.initial_satiety
    self.birth_time = vim.loop.now()
    self.session_start_time = vim.loop.now()
    self.last_vim_close_time = vim.loop.now()
    self.last_window_close_time = vim.loop.now()

    self.total_vim_events = 0
    self.total_mood_gained = 0
    self.total_satiety_gained = 0
    self.times_fed = 0
    self.times_played_with = 0

    self.sprite_indices = { happy = 1, hungry = 1, neutral = 1 }
    self.last_state = nil
    
    self.color_theme = nil
end

function Pet:transfer_stats_to(target_pet)
    target_pet.mood = self.mood
    target_pet.satiety = self.satiety
    target_pet.birth_time = self.birth_time
    target_pet.session_start_time = self.session_start_time
    target_pet.last_vim_close_time = self.last_vim_close_time
    target_pet.last_window_close_time = self.last_window_close_time

    target_pet.total_vim_events = self.total_vim_events
    target_pet.total_mood_gained = self.total_mood_gained
    target_pet.total_satiety_gained = self.total_satiety_gained
    target_pet.times_fed = self.times_fed
    target_pet.times_played_with = self.times_played_with
end

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

function Pet:save_on_vim_close(filepath)
    self.last_vim_close_time = vim.loop.now()
    self:store(filepath)
end

function Pet:save_on_window_close(filepath)
    self.last_window_close_time = vim.loop.now()
    self:store(filepath)
end

function Pet:get_save_path()
    local base_dir = vim.fn.stdpath("data")
    if self.name and #self.name > 0 then
        return base_dir .. "/tamagotchi_" .. self.name .. ".json"
    else
        return base_dir .. "/tamagotchi.json"
    end
end

function Pet:store(filepath)
    filepath = filepath or self:get_save_path()

    local dir = vim.fn.fnamemodify(filepath, ":h")
    if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, "p") end

    local data = vim.fn.json_encode(self:to_table())
    vim.fn.writefile({ data }, filepath)
end

function Pet.load_on_vim_open(filepath)
    filepath = filepath or (vim.fn.stdpath("data") .. "/tamagotchi.json")

    if vim.fn.filereadable(filepath) == 0 then return nil end

    local lines = vim.fn.readfile(filepath)
    if not lines or #lines == 0 then return nil end

    local content = table.concat(lines, "")
    local status, data = pcall(vim.fn.json_decode, content)
    if not status or type(data) ~= "table" then return nil end

    local pet = Pet:new(data)

    local elapsed_seconds = (vim.loop.now() - pet.last_vim_close_time) / 1000

    local max_decay_time = 3600
    local effective_time = math.min(elapsed_seconds, max_decay_time)

    local mood_decay = pet.mood_decay_probability * effective_time
    local satiety_decay = pet.satiety_decay_probability * effective_time

    pet.mood = math.max(10, pet.mood - mood_decay)
    pet.satiety = math.max(10, pet.satiety - satiety_decay)

    return pet
end

return Pet
