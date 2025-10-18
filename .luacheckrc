-- Luacheck configuration for tamagotchi.nvim

-- Make luacheck aware of global vim API
globals = {
    "vim",
}

-- Read globals are okay to use
read_globals = {
    "vim",
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


