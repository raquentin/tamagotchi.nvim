local config = require("tamagotchi.config")
local Pet = require("tamagotchi.pet")
local M = {}

local pet_instance
local win, buf

function M.create_window()
	if not pet_instance then
		pet_instance = Pet:new(config.options.pet.name, config.options.pet.sprites)
	end
	buf = vim.api.nvim_create_buf(false, true)

	local width = config.options.ui.width
	local height = config.options.ui.height
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = (vim.o.lines - height) / 2 - 1,
		column = (vim.o.columns - width) / 2,
		style = "minimal",
		border = "rounded",
	}

	win = vim.api.nvim_open_win(buf, true, opts)

	M.render()
end

function M.render()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		pet_instance:get_sprite(),
		"Happiness: " .. pet_instance.happiness,
		"Hunger: " .. pet_instance.hunger,
		"Energy: " .. pet_instance.energy,
	})
end

function M.toggle()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
		win = nil
	else
		M.create_window()
	end
end

return M
