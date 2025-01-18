local Pet = {}
Pet.__index = Pet

function Pet:new(o)
    o = o or {}
    setmetatable(o, Pet)
    o.hunger = o.hunger or 50
    o.happiness = o.happiness or 50
    o.age = 0
    return o
end

function Pet:get_hunger() return self.hunger end

function Pet:set_hunger(value) self.hunger = math.max(1, math.min(100, value)) end

function Pet:get_happiness() return self.happiness end

function Pet:set_happiness(value)
    self.happiness = math.max(1, math.min(100, value))
end

function Pet:get_age() return self.age end

function Pet:set_age(value) self.age = math.max(0, value) end

return Pet
