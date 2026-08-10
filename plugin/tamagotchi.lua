if vim.g.loaded_tamagotchi then return end
vim.g.loaded_tamagotchi = 1

-- Keep plugin-load time cheap: only highlights and the user command, both of
-- which a user may want before any pet exists.
require("tamagotchi.highlights").setup()
require("tamagotchi.command").setup()

-- Zero-config users -- which is exactly what the README's install snippets
-- produce -- still get a pet without calling setup{}.
--
-- Deferred to VimEnter rather than run here, because plugin/ is sourced before
-- user config under vim-plug and packer. v1 called setup() at this point, which
-- meant <leader> expanded against the pre-config mapleader and an explicit
-- setup{} afterwards built a second pet, keymap and timer.
vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
        local tamagotchi = require("tamagotchi")
        if not tamagotchi._did_setup then tamagotchi.setup() end
    end,
})
