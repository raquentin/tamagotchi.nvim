local config = require("tamagotchi.config")
local window = require("tamagotchi.window")

local M = {}

function M.setup(user_config)
    config.setup(user_config)

    local Pet = require("tamagotchi.pet")

    local loaded_pet = Pet.load()
    if loaded_pet then
        _G.tamagotchi_pet = loaded_pet
    else
        local desired_name = config.values.default_pet
        local chosen_def

        if desired_name then
            for _, pet_def in ipairs(config.values.pets) do
                if pet_def.name == desired_name then
                    chosen_def = pet_def
                    break
                end
            end
        end

        if not chosen_def then
            math.randomseed(os.time())
            local idx = math.random(#config.values.pets)
            chosen_def = config.values.pets[idx]
        end

        _G.tamagotchi_pet = Pet:new(chosen_def)
    end

    vim.api.nvim_set_keymap(
        "n",
        config.values.window_toggle_keybind,
        '<cmd>lua require("tamagotchi.window").toggle(_G.tamagotchi_pet)<CR>',
        { noremap = true, silent = true }
    )

    -- link vim events to event handlers
    for _, evt_def in ipairs(_G.tamagotchi_pet.vim_events) do
        local cmd = string.format(
            [[autocmd %s * lua require("tamagotchi.event_handler").on_event("%s", %d, %d)]],
            evt_def.name,
            evt_def.name,
            evt_def.mood_increment,
            evt_def.satiety_increment
        )
        vim.cmd(cmd)
    end

    -- save on leave
    vim.cmd([[
        autocmd VimLeavePre * lua if _G.tamagotchi_pet then _G.tamagotchi_pet:save() end
    ]])

    window.start_refresh_loop(_G.tamagotchi_pet)
end

function M.open_pet_ui()
    if _G.tamagotchi_pet then
        window.open(_G.tamagotchi_pet)
    else
        vim.notify("No active pet to display.", vim.log.levels.ERROR)
    end
end

return M
