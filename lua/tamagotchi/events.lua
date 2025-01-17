local M = {}

function M.setup()
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = "*",
		callback = function()
			-- TODO: call pet update logic
			local ui = require("tamagotchi.ui")
			if ui and ui.render and vim.api.nvim_win_is_valid(ui.win) then
				ui.render()
			end
		end,
	})
end

return M
