local config = require("tamagotchi.config")
local ui = require("tamagotchi.ui")

config.setup(user_opts)

vim.api.nvim_set_keymap(
	"n",
	config.options.ui.keybind,
	':lua require("tamagotchi.ui").toggle()<CR>',
	{ noremap = true, silent = true }
)
