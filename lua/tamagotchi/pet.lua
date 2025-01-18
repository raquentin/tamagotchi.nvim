local Pet = {}
Pet.__index = Pet

function Pet:new(o)
    o = o or {}
    setmetatable(o, Pet)
    o.name = o.name or "Anonymous Pet"
    o.satiety = o.satiety or 80
    o.mood = o.mood or 80
    o.birth_time = vim.loop.now()

    local config = require("tamagotchi.config").values

    -- if no sprites provided, fallback to the first pet's sprites in config, if available.
    -- TODO: log this
    if not o.sprites then
        if config.pets and #config.pets > 0 then
            local default_pet = config.pets[1]
            o.sprites = default_pet.sprites
        else
            -- as a last resort, initialize empty sprite lists.
            o.sprites = { happy = {}, hungry = {}, neutral = {} }
        end
    end

    o.sprite_indices = { happy = 1, hungry = 1, neutral = 1 }
    o.last_state = nil

    return o
end

function Pet:get_satiety() return self.satiety end

function Pet:set_satiety(value) self.satiety = math.max(1, math.min(100, value)) end

function Pet:get_mood() return self.mood end

function Pet:set_mood(value) self.mood = math.max(1, math.min(100, value)) end

-- get current pet age in ms
function Pet:get_age() return vim.loop.now() - self.birth_time end

-- convert pet to a plain table for serialization
function Pet:to_table()
    return {
        satiety = self.satiety,
        mood = self.mood,
        birth_time = self.birth_time,
    }
end

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
    -- TODO: log

    local idx = self.sprite_indices[state] or 1
    local sprite = sprite_list[idx] or sprite_list[1]

    self.sprite_indices[state] = (idx % #sprite_list) + 1

    return sprite
end
return Pet
