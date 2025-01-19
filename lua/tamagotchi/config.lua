local kitty_sprites = require("tamagotchi.sprites.kitty")

local M = {}

M.defaults = {
    keybind = "<leader>tg",
    tick_length_ms = 100,
    mood_decay_probability = 0.02,
    satiety_decay_probability = 0.02,
    vim_events = {
        {
            name = "BufWritePost",
            mood_increment = 5,
            satiety_increment = 0,
        },
        {
            name = "TextYankPost",
            mood_increment = 0,
            satiety_increment = 2,
        },
    },
    default_pet = "Kitty",
    pets = {
        {
            name = "Kitty",
            tick_length_ms = 100,
            sprite_update_interval = 5,
            sprites = kitty_sprites,
            native = true,
            mood_decay_probability = 0.02,
            satiety_decay_probability = 0.02,
            initial_mood = 80,
            initial_satiety = 80,
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
