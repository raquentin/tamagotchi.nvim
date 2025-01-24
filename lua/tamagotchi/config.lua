local kitty_sprites = require("tamagotchi.sprites.kitty")
local lucy_sprites = require("tamagotchi.sprites.lucy")

local M = {}

M.defaults = {
    window_toggle_keybind = "<leader>tg",
    tick_length_ms = 100,
    default_pet = "Lucy",
    pets = {
        {
            name = "Ilya",

            sprite_update_interval = 5,
            sprites = kitty_sprites,

            initial_mood = 95,
            initial_satiety = 95,
            decay_class = 3,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 22,
                    satiety_increment = 2,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 0,
                    satiety_increment = 13,
                },
            },
        },

        {
            name = "Lucy",

            sprite_update_interval = 6,
            sprites = lucy_sprites,

            initial_mood = 95,
            initial_satiety = 95,
            decay_class = 4,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 1,
                    satiety_increment = 29,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 8,
                    satiety_increment = 0,
                },
            },
        },
    },
}

M.values = {}

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
        table.insert(all_pets, pet)
    end

    -- if user provided pets, mark them as immigrants and append them
    if user_config.pets then
        for _, pet in ipairs(user_config.pets) do
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
