local M = {}

local config = require("tamagotchi.config")
local ui = require("tamagotchi.ui")
local pet = require("tamagotchi.pet")
local events = require("tamagotchi.events")

function M.setup()
	vim.api.nvim_set_keymap(
		"n",
		config.options.ui.keybind,
		':lua require("tamagotchi.ui").toggle()<CR>',
		{ noremap = true, silent = true }
	)

	pet.initialize(config.options.pet)

	events.setup()
end

return M
