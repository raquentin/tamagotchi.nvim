local Pet = {}
Pet.__index = Pet

function Pet:new(name, sprites)
	local obj = setmetatable({}, Pet)
	obj.name = name
	obj.happiness = 100
	obj.hunger = 0
	obj.energy = 100
	obj.sprites = sprites or { happy = "...", hungry = "...", sad = "..." }
	return obj
end

function Pet:update(event) end

function Pet:get_sprite()
	if self.hunger > 70 then
		return self.sprites.hungry
	elseif self.happiness < 30 then
		return self.sprites.sad
	else
		return self.sprites.happy
	end
end

return Pet
