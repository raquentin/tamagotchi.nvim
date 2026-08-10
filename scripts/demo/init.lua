-- Neovim config for the README recording. Not a user-facing example: it seeds
-- the pet so a 40-second clip shows bars that are worth watching, which a fresh
-- 75/75 pet does not.
--
--   nvim -u scripts/demo/init.lua
--
-- scripts/record-demo.sh points XDG_DATA_HOME at a throwaway directory first,
-- so recording never touches a real save.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:prepend(root)

vim.g.mapleader = " "

vim.o.termguicolors = true
vim.o.background = "dark"

-- Catppuccin Mocha, matching the terminal theme the tape sets, so the padding
-- around the frame is the same colour as the editor inside it. record-demo.sh
-- exports $CATPPUCCIN; without it the stock colorscheme still records fine, it
-- just resolves several of the sprite themes nearly white.
local catppuccin = os.getenv("CATPPUCCIN")
if catppuccin and vim.fn.isdirectory(catppuccin) == 1 then
    vim.opt.runtimepath:prepend(catppuccin)
    vim.cmd.colorscheme("catppuccin-mocha")
else
    vim.cmd.colorscheme("default")
end

vim.o.number = true
vim.o.signcolumn = "yes"
vim.o.laststatus = 3
vim.o.showmode = false
vim.o.shortmess = vim.o.shortmess .. "I"
vim.o.winborder = "rounded"

-- A global statusline reports whichever window has focus, which for most of the
-- clip is a float called "[Scratch]". The file being edited never changes, so
-- name it once.
vim.o.statusline = " "
    .. vim.fn.expand("%:t")
    .. " %= %{%v:lua.require'tamagotchi.statusline'.get()%} "

-- Floats are `style = "minimal"`, so the cursor parks in the top-left corner of
-- whichever one has focus and reads as a rendering artifact. Painting it the
-- float background hides it; `blend` would not, since the terminal draws the
-- cursor and only picks up its colour.
local float_bg = vim.api.nvim_get_hl(0, { name = "NormalFloat" }).bg
vim.api.nvim_set_hl(0, "Cursor", { fg = float_bg, bg = float_bg })
vim.o.guicursor = "a:block-Cursor/lCursor-blinkon0"

-- The block still covers whatever character it sits on, so start it on an empty
-- line rather than in the middle of the comment on line 1.
vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function() pcall(vim.api.nvim_win_set_cursor, 0, { 5, 0 }) end,
})

require("tamagotchi").setup({
    default_pet = "Sasha",
    tick_length_ms = 1000,
    -- The clip closes the float and writes a buffer to show the vim_events
    -- feature; at the real 60s idle rate the statusline would not repaint
    -- before the recording ended.
    idle_tick_ms = 1000,
})

-- A pet mid-life, run down enough that both bars start amber and the sprite
-- starts on the hungry animation. The four interactions then carry it to 80
-- mood / 72 satiety, which is green bars and the happy animation -- the arc is
-- the point of the clip, and a fresh 75/75 pet does not have one.
local pet = _G.tamagotchi_pet
if pet then
    local now = os.time()

    pet.birth_time = now - (2 * 3600 + 14 * 60)
    pet.last_decay_time = now
    pet.last_seen_time = now
    pet:set_mood(46)
    pet:set_satiety(60)
    pet.times_fed = 14
    pet.times_played_with = 9

    require("tamagotchi.statusline").invalidate()
end
