local M = {}

M.defaults = {
    keybind = "<leader>tg",
    pets = {
        {
            name = "Tamagotchi",
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

    -- if user provided additional pets, append them to the default list
    if user_config.pets then
        local all_pets = {}
        for _, pet in ipairs(M.defaults.pets) do
            table.insert(all_pets, pet)
        end
        for _, pet in ipairs(user_config.pets) do
            table.insert(all_pets, pet)
        end
        combined.pets = all_pets
    end

    M.values = combined
end

return M
