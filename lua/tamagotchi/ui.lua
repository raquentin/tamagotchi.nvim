local config = require("tamagotchi.config")
local Pet = require("tamagotchi.pet")
local M = {}

local pet_instance
local win, buf

local function create_bar(label, value, max, length)
	length = length or 20
	local filled_length = math.floor((value / max) * length)
	local bar = string.rep("█", filled_length) .. string.rep("░", length - filled_length)
	return label .. ": [" .. bar .. "] " .. value .. "/" .. max
end

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
		col = (vim.o.columns - width) / 2,
		style = "minimal",
		border = "rounded",
	}

	win = vim.api.nvim_open_win(buf, true, opts)

	M.render()
end

function M.render()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		pet_instance:get_sprite(),
		create_bar("Happiness", pet_instance.happiness, 100),
		create_bar("Hunger", pet_instance.hunger, 100),
		create_bar("Energy", pet_instance.energy, 100),
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
