local kitty_sprites = require("tamagotchi.sprites.kitty")
local lucy_sprites = require("tamagotchi.sprites.lucy")
local doggo_sprites = require("tamagotchi.sprites.doggo")
local bunny_sprites = require("tamagotchi.sprites.bunny")
local dragon_sprites = require("tamagotchi.sprites.dragon")
local bear_sprites = require("tamagotchi.sprites.bear")

local M = {}

M.defaults = {
    window_toggle_keybind = "<leader>tg",
    tick_length_ms = 1000, -- 1 second per tick (more reasonable than 100ms)
    default_pet = "Lucy",
    pets = {
        {
            name = "Bunny",

            sprite_update_interval = 4,
            sprites = bunny_sprites,

            initial_mood = 75,
            initial_satiety = 65,
            decay_speed = 3, -- Bunnies are active

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 4,
                    satiety_increment = 6,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 5,
                    satiety_increment = 1,
                },
            },
        },

        {
            name = "Churro",

            sprite_update_interval = 5,
            sprites = doggo_sprites,

            initial_mood = 80,
            initial_satiety = 70,
            decay_speed = 2, -- Dogs need regular walks

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 6,
                    satiety_increment = 2,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 3,
                    satiety_increment = 3,
                },
            },
        },

        {
            name = "Dragon",

            sprite_update_interval = 7,
            sprites = dragon_sprites,

            initial_mood = 65,
            initial_satiety = 75,
            decay_speed = 1, -- Dragons are hardy

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 2,
                    satiety_increment = 4,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 3,
                    satiety_increment = 3,
                },
            },
        },

        {
            name = "Grizz",

            sprite_update_interval = 6,
            sprites = bear_sprites,

            initial_mood = 70,
            initial_satiety = 85,
            decay_speed = 2, -- Bears need lots of food

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 3,
                    satiety_increment = 7,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 4,
                    satiety_increment = 2,
                },
            },
        },

        {
            name = "Kitty",

            sprite_update_interval = 5,
            sprites = kitty_sprites,

            initial_mood = 75,
            initial_satiety = 75,
            decay_speed = 2, -- Moderate decay

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 5,
                    satiety_increment = 3,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 2,
                    satiety_increment = 1,
                },
            },
        },

        {
            name = "Lucy",

            sprite_update_interval = 6,
            sprites = lucy_sprites,

            initial_mood = 70,
            initial_satiety = 80,
            decay_speed = 3, -- Slightly faster decay

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 3,
                    satiety_increment = 5,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 4,
                    satiety_increment = 2,
                },
            },
        },

        {
            name = "Po",

            sprite_update_interval = 6,
            sprites = require("tamagotchi.sprites.po"),

            initial_mood = 80,
            initial_satiety = 90,
            decay_speed = 2, -- Pandas love to eat

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 4,
                    satiety_increment = 8,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 3,
                    satiety_increment = 4,
                },
            },
        },
    },
}

M.values = {}

-- Validate a single vim event definition
local function validate_vim_event(event)
    assert(type(event) == "table", "vim event must be a table")
    assert(
        type(event.name) == "string" and #event.name > 0,
        "vim event must have a non-empty name"
    )
    assert(
        type(event.mood_increment) == "number",
        "mood_increment must be a number"
    )
    assert(
        type(event.satiety_increment) == "number",
        "satiety_increment must be a number"
    )
end

-- Validate a pet definition
local function validate_pet(pet)
    assert(type(pet) == "table", "pet must be a table")
    assert(
        type(pet.name) == "string" and #pet.name > 0,
        "pet must have a non-empty name"
    )

    if pet.sprites then
        assert(type(pet.sprites) == "table", "sprites must be a table")
    end

    if pet.vim_events then
        assert(type(pet.vim_events) == "table", "vim_events must be a table")
        for i, event in ipairs(pet.vim_events) do
            local ok, err = pcall(validate_vim_event, event)
            if not ok then
                error(
                    string.format(
                        "Invalid vim_event at index %d for pet '%s': %s",
                        i,
                        pet.name,
                        err
                    )
                )
            end
        end
    end

    if pet.initial_mood then
        assert(
            type(pet.initial_mood) == "number",
            "initial_mood must be a number"
        )
        assert(
            pet.initial_mood >= 1 and pet.initial_mood <= 100,
            "initial_mood must be between 1 and 100"
        )
    end

    if pet.initial_satiety then
        assert(
            type(pet.initial_satiety) == "number",
            "initial_satiety must be a number"
        )
        assert(
            pet.initial_satiety >= 1 and pet.initial_satiety <= 100,
            "initial_satiety must be between 1 and 100"
        )
    end

    if pet.decay_speed then
        assert(
            type(pet.decay_speed) == "number",
            "decay_speed must be a number"
        )
        assert(
            pet.decay_speed >= 0 and pet.decay_speed <= 6,
            "decay_speed must be between 0 and 6"
        )
    end
end

function M.setup(user_config)
    user_config = user_config or {}

    -- start by deep extending default config with user-provided config
    local combined = vim.tbl_deep_extend("force", {}, M.defaults, user_config)

    -- mark default pets as native
    for _, pet in ipairs(M.defaults.pets) do
        pet.native = true
    end

    assert(
        M.defaults.pets,
        "M.defaults.pets is nil. Ensure pets are defined in defaults."
    )

    local all_pets = {}

    for _, pet in ipairs(M.defaults.pets) do
        validate_pet(pet)
        table.insert(all_pets, pet)
    end

    -- if user provided pets, mark them as immigrants and append them
    -- users can add custom pets by passing pets array:
    --   require('tamagotchi').setup({ pets = { { name = "Custom", sprites = ..., ... } } })
    if user_config.pets then
        for _, pet in ipairs(user_config.pets) do
            validate_pet(pet)
            pet.native = false
            table.insert(all_pets, pet)
        end
    end

    -- sort pets alphabetically by name
    table.sort(all_pets, function(a, b) return a.name < b.name end)

    combined.pets = all_pets
    M.values = combined
end

return M
