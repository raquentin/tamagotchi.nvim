local M = {}

local Pet = require("tamagotchi.pet")
local pet = Pet.load() or Pet:new()
_G.tamagotchi_pet = pet

vim.cmd([[
  autocmd VimLeavePre * lua if _G.tamagotchi_pet then _G.tamagotchi_pet:save() end
]])

function M.setup()
    vim.api.nvim_set_keymap(
        "n",
        "<leader>tg",
        '<cmd>lua require("tamagotchi.window").toggle()<CR>',
        { noremap = true, silent = true }
    )
end

return M
