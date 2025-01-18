local M = {}

-- track current open window
M.current = nil

local function ascii_bar(value, max, width)
    local filled = math.floor((value / max) * width)
    local unfilled = width - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", unfilled) .. "]"
end

-- builds the horizontal layout
local function build_ui_lines(pet)
    local lines = {}
    lines[1] = string.format(
        "%-20s  Name: %s (Age: %.1fs)",
        pet:get_sprite(),
        pet:get_name(),
        pet:get_age() / 1000.0
    )
    lines[2] = string.format(
        "%-20s  Satiety: %s",
        "",
        ascii_bar(pet:get_satiety(), 100, 10)
    )
    lines[3] = string.format(
        "%-20s  Mood:    %s",
        "",
        ascii_bar(pet:get_mood(), 100, 10)
    )

    return lines
end

-- create the floating window (a scratch buffer)
local function create_floating_window()
    local width = math.floor(vim.o.columns * 0.5)
    local height = math.floor(vim.o.lines * 0.3)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)

    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    return { buf = buf, win = win }
end

function M.open(pet)
    if not pet then
        vim.notify("No pet provided!", vim.log.levels.ERROR)
        return nil
    end

    -- close open window if exists
    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        vim.api.nvim_win_close(M.current.win, true)
        M.current = nil
    end

    M.current = create_floating_window()
    M.update_ui(pet)
    return M.current
end

-- update the buffer lines for the currently open window
function M.update_ui(pet)
    if not M.current or not vim.api.nvim_win_is_valid(M.current.win) then
        return
    end

    local lines = build_ui_lines(pet)
    vim.api.nvim_buf_set_lines(M.current.buf, 0, -1, false, lines)
end

function M.close()
    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        vim.api.nvim_win_close(M.current.win, true)
    end
    M.current = nil
end

function M.toggle(pet)
    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        M.close()
        return nil
    else
        return M.open(pet)
    end
end

return M
