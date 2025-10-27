local M = {}

function M.on_event(event_name, mood_inc, sat_inc)
    assert(type(event_name) == "string", "event_name must be a string")
    assert(type(mood_inc) == "number", "mood_inc must be a number")
    assert(type(sat_inc) == "number", "sat_inc must be a number")

    local pet = _G.tamagotchi_pet
    if not pet then
        return
    end

    pet:record_event()

    if mood_inc > 0 then
        pet:increase_mood(mood_inc)
    elseif mood_inc < 0 then
        pet:set_mood(pet:get_mood() + mood_inc)
    end

    if sat_inc > 0 then
        pet:increase_satiety(sat_inc)
    elseif sat_inc < 0 then
        pet:set_satiety(pet:get_satiety() + sat_inc)
    end
end

return M
