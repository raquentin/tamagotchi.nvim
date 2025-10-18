local M = {}

-- Show a yes/no confirmation dialogue
function M.confirm(title, message, on_yes, on_no)
    local lines = {}
    table.insert(lines, "╔" .. string.rep("═", 50) .. "╗")
    table.insert(
        lines,
        "║ " .. title .. string.rep(" ", 49 - #title) .. "║"
    )
    table.insert(lines, "╠" .. string.rep("═", 50) .. "╣")

    -- Wrap message into multiple lines if needed
    local max_width = 48
    local words = {}
    for word in message:gmatch("%S+") do
        table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
        if #current_line + #word + 1 <= max_width then
            current_line = current_line
                .. (current_line == "" and "" or " ")
                .. word
        else
            if current_line ~= "" then
                table.insert(
                    lines,
                    "║ "
                        .. current_line
                        .. string.rep(" ", max_width - #current_line)
                        .. " ║"
                )
            end
            current_line = word
        end
    end
    if current_line ~= "" then
        table.insert(
            lines,
            "║ "
                .. current_line
                .. string.rep(" ", max_width - #current_line)
                .. " ║"
        )
    end

    table.insert(lines, "╠" .. string.rep("═", 50) .. "╣")
    table.insert(lines, "║" .. string.rep(" ", 50) .. "║")
    table.insert(
        lines,
        "║     [Y]es              [N]o                      ║"
    )
    table.insert(lines, "╚" .. string.rep("═", 50) .. "╝")

    local width = 52
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

    -- Set up key mappings
    local function close_and_call(callback)
        vim.api.nvim_win_close(win, true)
        if callback then callback() end
    end

    vim.api.nvim_buf_set_keymap(buf, "n", "y", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_yes) end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "Y", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_yes) end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "n", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_no) end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "N", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_no) end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_no) end,
    })

    return win
end

-- Show a choice dialogue with custom options
function M.choice(title, message, option1, option2, on_option1, on_option2)
    local lines = {}
    table.insert(lines, "╔" .. string.rep("═", 60) .. "╗")
    table.insert(
        lines,
        "║ " .. title .. string.rep(" ", 59 - #title) .. "║"
    )
    table.insert(lines, "╠" .. string.rep("═", 60) .. "╣")

    -- Wrap message into multiple lines
    local max_width = 58
    local words = {}
    for word in message:gmatch("%S+") do
        table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
        if #current_line + #word + 1 <= max_width then
            current_line = current_line
                .. (current_line == "" and "" or " ")
                .. word
        else
            if current_line ~= "" then
                table.insert(
                    lines,
                    "║ "
                        .. current_line
                        .. string.rep(" ", max_width - #current_line)
                        .. " ║"
                )
            end
            current_line = word
        end
    end
    if current_line ~= "" then
        table.insert(
            lines,
            "║ "
                .. current_line
                .. string.rep(" ", max_width - #current_line)
                .. " ║"
        )
    end

    table.insert(lines, "╠" .. string.rep("═", 60) .. "╣")
    table.insert(lines, "║" .. string.rep(" ", 60) .. "║")

    -- Format options
    local opt1_text = string.format("[1] %s", option1)
    local opt2_text = string.format("[2] %s", option2)
    local padding = 60 - #opt1_text - #opt2_text - 2
    table.insert(
        lines,
        "║ " .. opt1_text .. string.rep(" ", padding) .. opt2_text .. " ║"
    )

    table.insert(lines, "║" .. string.rep(" ", 60) .. "║")
    table.insert(
        lines,
        "║ Press [Esc] to cancel" .. string.rep(" ", 38) .. "║"
    )
    table.insert(lines, "╚" .. string.rep("═", 60) .. "╝")

    local width = 62
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

    local function close_and_call(callback)
        vim.api.nvim_win_close(win, true)
        if callback then callback() end
    end

    vim.api.nvim_buf_set_keymap(buf, "n", "1", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_option1) end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "2", "", {
        noremap = true,
        silent = true,
        callback = function() close_and_call(on_option2) end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
        noremap = true,
        silent = true,
        callback = function() vim.api.nvim_win_close(win, true) end,
    })

    return win
end

-- Show an input dialogue to get text from user
function M.input(title, message, default_value, on_submit, on_cancel)
    default_value = default_value or ""

    local lines = {}
    table.insert(lines, "╔" .. string.rep("═", 50) .. "╗")
    table.insert(
        lines,
        "║ " .. title .. string.rep(" ", 49 - #title) .. "║"
    )
    table.insert(lines, "╠" .. string.rep("═", 50) .. "╣")

    -- Wrap message into multiple lines if needed
    local max_width = 48
    local words = {}
    for word in message:gmatch("%S+") do
        table.insert(words, word)
    end

    local current_line = ""
    for _, word in ipairs(words) do
        if #current_line + #word + 1 <= max_width then
            current_line = current_line
                .. (current_line == "" and "" or " ")
                .. word
        else
            if current_line ~= "" then
                table.insert(
                    lines,
                    "║ "
                        .. current_line
                        .. string.rep(" ", max_width - #current_line)
                        .. " ║"
                )
            end
            current_line = word
        end
    end
    if current_line ~= "" then
        table.insert(
            lines,
            "║ "
                .. current_line
                .. string.rep(" ", max_width - #current_line)
                .. " ║"
        )
    end

    table.insert(lines, "╠" .. string.rep("═", 50) .. "╣")
    table.insert(lines, "║" .. string.rep(" ", 50) .. "║")
    table.insert(
        lines,
        "║ Press [Enter] to confirm, [Esc] to cancel       ║"
    )
    table.insert(lines, "╚" .. string.rep("═", 50) .. "╝")

    local width = 52
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

    -- Use vim.ui.input for getting text input
    vim.schedule(function()
        vim.api.nvim_win_close(win, true)
        vim.ui.input({
            prompt = title .. ": ",
            default = default_value,
        }, function(input)
            if input and #input > 0 then
                if on_submit then on_submit(input) end
            else
                if on_cancel then on_cancel() end
            end
        end)
    end)

    return win
end

return M
