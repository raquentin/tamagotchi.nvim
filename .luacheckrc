-- Luacheck configuration for tamagotchi.nvim

-- Make luacheck aware of the global vim API.
--
-- Declared writable (`globals`, not `read_globals`) because the plugin assigns
-- through it: vim.bo[buf].modifiable, vim.wo[win].wrap, vim.g.loaded_tamagotchi.
-- Declaring it in both tables, as this file used to, makes luacheck report every
-- one of those as "setting read-only field".
globals = {
    "vim",
    -- The active pet is intentionally global so statuslines and user mappings
    -- can reach it without requiring the plugin.
    "tamagotchi_pet",
}

-- Don't report unused self arguments of methods
self = false

-- Ignore some pedantic warnings
ignore = {
    "212", -- Unused argument (like self)
}

-- Configure for Neovim Lua
std = "luajit"

-- Additional files/patterns to exclude
exclude_files = {
    ".luacheckrc",
    "lua/tamagotchi/sprites/*.lua", -- sprites have intentional trailing whitespace
}

-- Maximum line length
max_line_length = 120

-- Maximum cyclomatic complexity
max_cyclomatic_complexity = 15


