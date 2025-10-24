local M = {}

-- Show a yes/no confirmation dialogue
function M.confirm(title, message, on_yes, on_no)
    local lines = {}
    local title_line_idx = 1
    table.insert(lines, "")
    table.insert(lines, "  " .. title)
    table.insert(lines, "")

    -- wrap message into multiple lines if needed
    local max_width = 46
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
                table.insert(lines, "  " .. current_line)
            end
            current_line = word
        end
    end
    if current_line ~= "" then
        table.insert(lines, "  " .. current_line)
    end

    table.insert(lines, "")
    local options_line_idx = #lines
    table.insert(lines, "  [y]es    [n]o")
    table.insert(lines, "")

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

    -- add highlights: options in gray
    vim.api.nvim_buf_add_highlight(buf, -1, "Comment", options_line_idx, 0, -1)

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
    local title_line_idx = 1
    table.insert(lines, "")
    table.insert(lines, "  " .. title)
    table.insert(lines, "")

    -- split message by newlines first
    local paragraphs = {}
    for paragraph in (message .. "\n"):gmatch("(.-)\n") do
        table.insert(paragraphs, paragraph)
    end

    local note_lines = {}
    -- wrap each paragraph into multiple lines
    local max_width = 56
    for _, para in ipairs(paragraphs) do
        if para ~= "" then
            local words = {}
            for word in para:gmatch("%S+") do
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
                        local line_text = "  " .. current_line
                        table.insert(lines, line_text)
                        -- track if this line starts with "note:"
                        if current_line:match("^note:") then
                            table.insert(note_lines, #lines - 1)
                        end
                    end
                    current_line = word
                end
            end
            if current_line ~= "" then
                local line_text = "  " .. current_line
                table.insert(lines, line_text)
                -- track if this line starts with "note:"
                if current_line:match("^note:") then
                    table.insert(note_lines, #lines - 1)
                end
            end
        else
            table.insert(lines, "")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "  [1] " .. option1)
    table.insert(lines, "  [2] " .. option2)
    table.insert(lines, "")
    table.insert(lines, "  press [esc] to cancel")
    table.insert(lines, "")

    local width = 60
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

    -- add highlights: "note:" lines in gray
    for _, line_idx in ipairs(note_lines) do
        vim.api.nvim_buf_add_highlight(buf, -1, "Comment", line_idx, 0, -1)
    end

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
    table.insert(lines, "")
    table.insert(lines, "  " .. title)
    table.insert(lines, "")

    -- wrap message into multiple lines if needed
    local max_width = 46
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
                table.insert(lines, "  " .. current_line)
            end
            current_line = word
        end
    end
    if current_line ~= "" then
        table.insert(lines, "  " .. current_line)
    end

    table.insert(lines, "")
    table.insert(lines, "  press [enter] to confirm, [esc] to cancel")
    table.insert(lines, "")

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
