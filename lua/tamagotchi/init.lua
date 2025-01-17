local M = {}
local config = require("tamagotchi.config")
local events = require("tamagotchi.events")
local pet = require("tamagotchi.pet")

function M.setup(user_opts)
	config.setup(user_opts)

	vim.api.nvim_set_keymap(
		"n",
		config.options.ui.keybind,
		':lua require("tamagotchi.ui").toggle()',
		{ noremap = true, silent = true }
	)

	pet.initialize(config.options.pet)

	events.setup()
end

return M
