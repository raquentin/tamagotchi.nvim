local M = {}

M.defaults = {
	keybind = "<leader>tg",
	pet = { name = "Ilya" },
	ui = { width = 50, height = 15 },
}

M.options = {}

function M.setup(user_opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, user_opts or {})
end

return M
