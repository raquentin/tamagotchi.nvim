local M = {}

function M.setup()
    vim.api.nvim_set_keymap(
        "n",
        "<leader>tg",
        '<cmd>lua require("tamagotchi.window").toggle()<CR>',
        { noremap = true, silent = true }
    )
end

return M
