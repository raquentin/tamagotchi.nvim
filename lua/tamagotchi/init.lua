local M = {}

local config = require("tamagotchi.config")

function M.setup(user_opts)
	config.setup(user_opts)
end

return M
