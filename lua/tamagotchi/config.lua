local M = {}

M.defaults = {
	keybind = "<leader>pt",
	pet = {
		name = "Ilya",
		sprites = {
			happy = "😃",
			hungry = "😢",
			sad = "😞",
		},
	},
	ui = {
		width = 40,
		height = 10,
		keybind = "<leader>pt",
	},
}

M.options = {}

function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
