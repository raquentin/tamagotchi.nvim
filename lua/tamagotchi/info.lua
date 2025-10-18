local M = {}

local function format_duration(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

function M.show_info(pet)
    assert(pet, "pet is required")

    local session_duration = pet:get_session_duration()

    local lines = {
        "╔════════════════════════════════════════╗",
        "║         Pet Session Statistics         ║",
        "╠════════════════════════════════════════╣",
        string.format("║ Name: %-32s ║", pet.name or "Unknown"),
        string.format("║ Age: %-33s ║", pet:get_age_formatted()),
        "╠════════════════════════════════════════╣",
        string.format(
            "║ Current Mood: %-24d ║",
            math.floor(pet:get_mood())
        ),
        string.format(
            "║ Current Satiety: %-21d ║",
            math.floor(pet:get_satiety())
        ),
        "╠════════════════════════════════════════╣",
        string.format(
            "║ Session Duration: %-20s ║",
            format_duration(session_duration)
        ),
        string.format("║ Total Events: %-24d ║", pet.total_vim_events or 0),
        string.format("║ Times Fed: %-27d ║", pet.times_fed or 0),
        string.format(
            "║ Times Played With: %-19d ║",
            pet.times_played_with or 0
        ),
        string.format(
            "║ Total Mood Gained: %-19d ║",
            math.floor(pet.total_mood_gained or 0)
        ),
        string.format(
            "║ Total Satiety Gained: %-16d ║",
            math.floor(pet.total_satiety_gained or 0)
        ),
        "╠════════════════════════════════════════╣",
        string.format("║ Decay Speed: %-25d ║", pet.decay_speed or 0),
        string.format(
            "║ Birth Time: %-26s ║",
            pet.birth_time
                    and pet.birth_time > 0
                    and os.date("%Y-%m-%d %H:%M:%S", pet.birth_time / 1000)
                or "Unknown"
        ),
        "╚════════════════════════════════════════╝",
        "",
        "Press any key to close",
    }

    -- Create a centered floating window
    local width = 44
    local height = #lines
    local buf = vim.api.nvim_create_buf(false, true)

    local ui = vim.api.nvim_list_uis()[1]
    local win_width = ui.width
    local win_height = ui.height

    local opts = {
        relative = "editor",
        width = width,
        height = height,
        row = math.floor((win_height - height) / 2),
        col = math.floor((win_width - width) / 2),
        style = "minimal",
        border = "none",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

    -- Close on any key
    vim.api.nvim_buf_set_keymap(
        buf,
        "n",
        "<Esc>",
        "<cmd>close<CR>",
        { noremap = true, silent = true }
    )
    for _, key in ipairs({ "q", "i", "I", "<CR>", "<Space>" }) do
        vim.api.nvim_buf_set_keymap(
            buf,
            "n",
            key,
            "<cmd>close<CR>",
            { noremap = true, silent = true }
        )
    end

    return win
end

return M
