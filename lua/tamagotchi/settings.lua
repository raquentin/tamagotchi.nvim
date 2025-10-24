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

-- terminal color names
local COLORS = {
    { name = "red", hl = "TamagotchiColorRed" },
    { name = "green", hl = "TamagotchiColorGreen" },
    { name = "yellow", hl = "TamagotchiColorYellow" },
    { name = "blue", hl = "TamagotchiColorBlue" },
    { name = "magenta", hl = "TamagotchiColorMagenta" },
    { name = "cyan", hl = "TamagotchiColorCyan" },
    { name = "white", hl = "TamagotchiColorWhite" },
}

function M.show_settings(pet)
    assert(pet, "pet is required")

    local session_duration = pet:get_session_duration()

    local lines = {}
    table.insert(lines, "")
    table.insert(lines, "  pet settings")
    table.insert(lines, "")
    table.insert(lines, "  critical stats:")
    table.insert(lines, string.format("    name: %s", pet.name or "unknown"))
    table.insert(lines, string.format("    age: %s", pet:get_age_formatted()))
    table.insert(
        lines,
        string.format("    mood: %d / 100", math.floor(pet:get_mood()))
    )
    table.insert(
        lines,
        string.format("    satiety: %d / 100", math.floor(pet:get_satiety()))
    )
    table.insert(lines, "")
    table.insert(
        lines,
        string.format("    session time: %s", format_duration(session_duration))
    )
    table.insert(lines, string.format("    times fed: %d", pet.times_fed or 0))
    table.insert(
        lines,
        string.format("    times played: %d", pet.times_played_with or 0)
    )
    table.insert(lines, "")
    table.insert(lines, "  actions:")
    table.insert(lines, "    [r] rename pet")
    table.insert(lines, "    [c] choose color theme")
    table.insert(lines, "")
    table.insert(lines, "  press any other key to close")

    -- create centered floating window
    local width = 50
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
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

    -- add color highlights: subheadings gray
    vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 3, 0, -1)
    vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 11, 0, -1)

    local function close_win()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- rename pet handler
    local function rename_pet()
        close_win()
        local dialogue = require("tamagotchi.dialogue")
        dialogue.input(
            "rename pet",
            "enter a new name for your pet:",
            pet.name,
            function(new_name)
                local old_name = pet.name
                local old_save_path = pet:get_save_path()

                pet:set_name(new_name)
                pet:save_on_vim_close()

                if
                    old_name ~= new_name
                    and vim.fn.filereadable(old_save_path) == 1
                then
                    vim.fn.delete(old_save_path)
                end

                vim.notify(
                    string.format(
                        "renamed pet from '%s' to '%s'!",
                        old_name,
                        new_name
                    ),
                    vim.log.levels.INFO
                )
            end,
            nil
        )
    end

    -- color selection handler
    local function choose_color()
        close_win()
        M.show_color_picker(pet)
    end

    -- set up key mappings
    vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
        noremap = true,
        silent = true,
        callback = rename_pet,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "R", "", {
        noremap = true,
        silent = true,
        callback = rename_pet,
    })

    vim.api.nvim_buf_set_keymap(buf, "n", "c", "", {
        noremap = true,
        silent = true,
        callback = choose_color,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "C", "", {
        noremap = true,
        silent = true,
        callback = choose_color,
    })

    -- close on any other key
    for _, key in ipairs({ "q", "Q", "<Esc>", "<CR>", "<Space>", "s", "S" }) do
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

function M.show_color_picker(pet)
    local lines = {}
    table.insert(lines, "")
    table.insert(lines, "  choose your color theme")
    table.insert(lines, "")

    for i, color in ipairs(COLORS) do
        local marker = "    "
        table.insert(
            lines,
            string.format("%s[%d] %s", marker, i, color.name)
        )
    end

    table.insert(lines, "")
    table.insert(lines, "  press number key or [esc] to cancel")

    local width = 50
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
        border = "rounded",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

    -- highlight title
    vim.api.nvim_buf_add_highlight(buf, -1, "Title", 1, 0, -1)

    -- highlight each color option with its color
    for i, color in ipairs(COLORS) do
        local line_idx = i + 2 -- offset by header lines
        vim.api.nvim_buf_add_highlight(buf, -1, color.hl, line_idx, 0, -1)
    end

    local function close_and_select(color_data)
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        if color_data then
            -- save the color to the pet
            pet.color_theme = color_data.name
            pet:save_on_vim_close()
            
            -- update the window to reflect the new color
            local window = require("tamagotchi.window")
            window.update_ui(pet, false)
            
            vim.notify(
                string.format("selected %s theme!", color_data.name),
                vim.log.levels.INFO
            )
        end
    end

    -- set up number key handlers
    for i, color in ipairs(COLORS) do
        vim.api.nvim_buf_set_keymap(buf, "n", tostring(i), "", {
            noremap = true,
            silent = true,
            callback = function() close_and_select(color) end,
        })
    end

    -- close on escape
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
        noremap = true,
        silent = true,
        callback = function() 
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end,
    })

    return win
end

return M

