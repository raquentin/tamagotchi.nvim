-- Highlight links, in Lua so they can be re-applied.
--
-- v1 defined these once in plugin/tamagotchi.vim at startup, so any later
-- `:colorscheme` wiped them. They are `default` links, so an explicit user
-- override still wins.
local M = {}

local LINKS = {
    -- Float chrome. Without these the windows render on `Normal` and do not
    -- read as floats at all in most colorschemes.
    TamagotchiNormal = "NormalFloat",
    TamagotchiBorder = "FloatBorder",
    TamagotchiTitle = "FloatTitle",
    TamagotchiFooter = "FloatFooter",
    TamagotchiRule = "FloatBorder",

    TamagotchiMuted = "Comment",
    TamagotchiKey = "Special",
    TamagotchiLabel = "NormalFloat",
    TamagotchiSelection = "PmenuSel",

    -- Stat bars, coloured by how full they are rather than by pet theme, so a
    -- starving pet looks starving whatever colour it is.
    TamagotchiBarHigh = "DiagnosticOk",
    TamagotchiBarMed = "DiagnosticWarn",
    TamagotchiBarLow = "DiagnosticError",
    TamagotchiBarEmpty = "NonText",

    -- A stat that just moved, and the resting marker for one that has not.
    TamagotchiTrendUp = "DiagnosticOk",
    TamagotchiTrendDown = "DiagnosticError",
    TamagotchiTrendFlat = "NonText",

    -- Health states, used on the title when `stakes` is on.
    TamagotchiSick = "DiagnosticWarn",
    TamagotchiDead = "Comment",

    TamagotchiColorRed = "ErrorMsg",
    TamagotchiColorGreen = "DiffAdd",
    TamagotchiColorYellow = "WarningMsg",
    TamagotchiColorBlue = "Function",
    TamagotchiColorMagenta = "Constant",
    TamagotchiColorCyan = "Type",
    TamagotchiColorWhite = "Normal",
}

M.LINKS = LINKS

function M.apply()
    for group, target in pairs(LINKS) do
        vim.api.nvim_set_hl(0, group, { link = target, default = true })
    end
end

function M.setup()
    M.apply()

    vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = M.apply,
        group = vim.api.nvim_create_augroup(
            "TamagotchiHighlights",
            { clear = true }
        ),
    })
end

return M
