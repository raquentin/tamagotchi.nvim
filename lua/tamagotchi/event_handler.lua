local M = {}

function M.on_event(event_name, mood_inc, sat_inc)
    local pet = _G.tamagotchi_pet
    if not pet then return end

    if mood_inc and mood_inc > 0 then pet:increase_mood(mood_inc) end
    if sat_inc and sat_inc > 0 then pet:increase_satiety(sat_inc) end
end

return M
