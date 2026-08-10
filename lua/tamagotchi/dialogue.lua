local render = require("tamagotchi.render")
local ui = require("tamagotchi.ui")

local M = {}

local WIDTH = 50
local TEXT_WIDTH = WIDTH - 4

-- Above the menu and settings screens, which is where dialogues get opened
-- from.
local ZINDEX = 200

-- Shared by confirm() and choice(), which each carried their own near-identical
-- copy of this layout in v1 (as did input(), before it stopped drawing a float).
local function build(message)
    local lines = { "" }

    for _, line in ipairs(render.wrap(message, TEXT_WIDTH)) do
        lines[#lines + 1] = "  " .. line
    end

    lines[#lines + 1] = ""

    return lines
end

-- The options live in the border footer rather than as a body line: they are
-- the window's affordances, not part of the message.
local function open(title, message, options, mappings)
    local lines = build(message)

    local handle = ui.open({
        lines = lines,
        width = WIDTH,
        title = ui.chunks({ { title, "TamagotchiTitle" } }),
        footer = ui.key_chunks(options),
        filetype = "tamagotchi-dialogue",
        zindex = ZINDEX,
        -- Every close key here has to route through a callback, so the shell's
        -- own bare-close bindings would give <Esc> the wrong meaning.
        close_keys = {},
    })

    -- `false` means "close, run nothing" -- distinct from a missing key, which
    -- would silently drop the mapping.
    for keys, callback in pairs(mappings) do
        handle.map(keys, function()
            handle.close()
            if callback then callback() end
        end)
    end

    return handle.win
end

function M.confirm(title, message, on_yes, on_no)
    return open(
        title,
        message,
        { { key = "y", label = "yes" }, { key = "n", label = "no" } },
        {
            [{ "y", "Y" }] = on_yes,
            [{ "n", "N", "<Esc>", "<C-c>", "q" }] = on_no,
        }
    )
end

function M.choice(title, message, option1, option2, on_option1, on_option2)
    return open(
        title,
        message,
        { { key = "1", label = option1 }, { key = "2", label = option2 } },
        {
            [{ "1" }] = on_option1,
            [{ "2" }] = on_option2,
            -- Cancelling picks neither option; the window still closes.
            [{ "<Esc>", "<C-c>", "q" }] = false,
        }
    )
end

-- Text entry. Delegates straight to vim.ui.input so it picks up whatever input
-- UI the user has configured.
--
-- v1 built a full float here and then closed it one event-loop tick later in a
-- vim.schedule before calling vim.ui.input anyway -- visible flicker, and the
-- buffer was never wiped.
function M.input(title, message, default, on_submit, on_cancel)
    vim.ui.input({
        prompt = ("%s -- %s "):format(title, message),
        default = default,
    }, function(value)
        if value == nil or value == "" then
            if on_cancel then on_cancel() end
            return
        end
        if on_submit then on_submit(value) end
    end)
end

return M
