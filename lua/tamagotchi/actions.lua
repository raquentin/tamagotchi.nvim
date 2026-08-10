-- Deliberate interactions: `:Tamagotchi feed`, `play`, `pet`, `clean`.
--
-- These are what make the counters on the settings screen mean anything. v1
-- incremented times_fed inside increase_satiety and times_played_with inside
-- increase_mood, so every BufWritePost bumped both and neither number described
-- anything the user had actually done.
local M = {}

local VERBS = {
    feed = {
        mood = 2,
        satiety = 18,
        cooldown = 300,
        counter = "times_fed",
        done = "%s is full.",
        wait = "%s is not hungry yet.",
    },
    play = {
        -- Playing is fun but works up an appetite.
        mood = 18,
        satiety = -6,
        cooldown = 300,
        counter = "times_played_with",
        done = "you play with %s.",
        wait = "%s is worn out.",
    },
    pet = {
        mood = 8,
        satiety = 0,
        cooldown = 120,
        counter = "times_petted",
        done = "%s purrs.",
        wait = "%s has had enough fuss.",
    },
    clean = {
        mood = 6,
        satiety = 0,
        cooldown = 1800,
        counter = "times_cleaned",
        done = "%s is clean.",
        wait = "%s is already clean.",
    },
}

M.VERBS = VERBS

-- Repeating a verb keeps working, but with diminishing returns, so spamming
-- `:Tamagotchi feed` cannot pin a bar at 100.
local STREAK_FACTOR = 0.6
local STREAK_FLOOR = 0.2
local STREAK_WINDOW = 4 -- multiples of the cooldown before the streak resets

function M.scale_for(streak)
    return math.max(STREAK_FLOOR, STREAK_FACTOR ^ (streak or 0))
end

local function humanize(seconds)
    if seconds >= 3600 then return ("%dh"):format(math.ceil(seconds / 3600)) end
    if seconds >= 60 then return ("%dm"):format(math.ceil(seconds / 60)) end
    return ("%ds"):format(seconds)
end

-- Why this interaction cannot happen right now, or nil if it can.
local function blocked_reason(pet, spec, verb, now)
    if pet:health_state(now) == "dead" then
        return ("%s is gone. try :Tamagotchi revive"):format(
            pet.name or "your pet"
        )
    end

    local last = pet.last_interaction[verb]
    local since = last and (now - last) or math.huge

    if since < spec.cooldown then
        return spec.wait:format(pet.name or "your pet")
            .. (" (%s)"):format(humanize(spec.cooldown - since))
    end

    return nil
end

-- Bump the streak counter and return it. Within a few cooldowns counts as the
-- same bout; past that the streak resets and full effect returns.
local function advance_streak(pet, spec, verb, now)
    local last = pet.last_interaction[verb]
    local since = last and (now - last) or math.huge

    if since < spec.cooldown * STREAK_WINDOW then
        pet.interaction_streak[verb] = (pet.interaction_streak[verb] or 0) + 1
    else
        pet.interaction_streak[verb] = 0
    end

    return pet.interaction_streak[verb]
end

-- Apply `verb` to `pet`. Returns ok, message.
function M.interact(pet, verb, now)
    local spec = VERBS[verb]
    if not spec then return false, ("unknown action '%s'"):format(verb) end
    if not pet then return false, "no active pet" end

    now = now or os.time()

    pet.last_interaction = pet.last_interaction or {}
    pet.interaction_streak = pet.interaction_streak or {}

    local blocked = blocked_reason(pet, spec, verb, now)
    if blocked then return false, blocked end

    local scale = M.scale_for(advance_streak(pet, spec, verb, now))

    if spec.mood ~= 0 then pet:set_mood(pet.mood + spec.mood * scale) end
    if spec.satiety ~= 0 then
        pet:set_satiety(pet.satiety + spec.satiety * scale)
    end

    pet[spec.counter] = (pet[spec.counter] or 0) + 1
    pet.last_interaction[verb] = now

    -- A cared-for pet is no longer neglected, so the illness clock resets.
    if not pet:is_neglected() then pet.low_since = nil end

    -- Restart the animation so the reaction is visible immediately.
    pet.last_state = nil

    return true, spec.done:format(pet.name or "your pet")
end

-- `pet` is optional; the window passes the pet it is actually displaying, so
-- you can never act on one pet while looking at another.
function M.run(verb, pet)
    pet = pet or require("tamagotchi").ensure_setup()
    local ok, message = M.interact(pet, verb)

    vim.notify(message, ok and vim.log.levels.INFO or vim.log.levels.WARN)

    if ok then
        require("tamagotchi.store").save_pet(pet)
        require("tamagotchi.window").update_ui(pet, true)
        require("tamagotchi.statusline").invalidate()
    end

    return ok
end

function M.revive(pet)
    pet = pet or require("tamagotchi").ensure_setup()

    if pet:health_state() ~= "dead" then
        vim.notify(
            ("%s is doing fine."):format(pet.name or "your pet"),
            vim.log.levels.INFO
        )
        return
    end

    pet:revive()
    require("tamagotchi.store").save_pet(pet)
    require("tamagotchi.window").update_ui(pet, true)
    require("tamagotchi.statusline").invalidate()

    vim.notify(
        ("%s is back on their feet."):format(pet.name or "your pet"),
        vim.log.levels.INFO
    )
end

-- Register each verb as a :Tamagotchi subcommand.
function M.setup()
    local command = require("tamagotchi.command")
    for verb in pairs(VERBS) do
        command.register(verb, function() M.run(verb) end)
    end
    command.register("revive", M.revive)
end

return M
