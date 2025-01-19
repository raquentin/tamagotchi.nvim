local M = {}

M.defaults = {
    keybind = "<leader>tg",
    default_pet = "Tamagotchi",
    pets = {
        {
            name = "Tamagotchi",
            sprite_update_interval = 20,
            sprites = {
                happy = { " ^_^ ", " (^-^) " },
                hungry = { " >_< ", " (U_U) " },
                neutral = { " -_- ", " (._.) " },
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
