local Pet = {}
Pet.__index = Pet

function Pet:new(o)
    o = o or {}
    setmetatable(o, Pet)
    o.hunger = o.hunger or 50
    o.happiness = o.happiness or 50
    o.birth_time = vim.loop.now()
    return o
end

function Pet:get_hunger() return self.hunger end

function Pet:set_hunger(value) self.hunger = math.max(1, math.min(100, value)) end

function Pet:get_happiness() return self.happiness end

function Pet:set_happiness(value)
    self.happiness = math.max(1, math.min(100, value))
end

-- get current pet age in ms
function Pet:get_age() return vim.loop.now() - self.birth_time end

-- convert pet to a plain table for serialization
function Pet:to_table()
    return {
        hunger = self.hunger,
        happiness = self.happiness,
        birth_time = self.birth_time,
    }
end

-- save pet state to a file (default path in Neovim data directory)
function Pet:save(filepath)
    filepath = filepath or (vim.fn.stdpath("data") .. "/tamagotchi.json")
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
