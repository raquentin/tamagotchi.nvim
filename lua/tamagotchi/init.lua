local M = {}

local config = require("tamagotchi.config")

local Pet = require("tamagotchi.pet")
local pet = Pet.load() or Pet:new()
_G.tamagotchi_pet = pet

vim.cmd([[
  autocmd VimLeavePre * lua if _G.tamagotchi_pet then _G.tamagotchi_pet:save() end
]])

function M.setup(user_config)
    config.setup(user_config)

    vim.api.nvim_set_keymap(
        "n",
        config.values.keybind,
        '<cmd>lua require("tamagotchi.window").toggle()<CR>',
        { noremap = true, silent = true }
    )
end

return M
