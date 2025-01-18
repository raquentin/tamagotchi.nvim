local M = {}

-- value: the current stat (0 to 100)
-- max: the maximum (often 100)
-- width: how many characters the bar should be in total
local function ascii_bar(value, max, width)
    local filled = math.floor((value / max) * width)
    local unfilled = width - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", unfilled) .. "]"
end

-- builds the horizontal layout
local function build_ui_lines(pet)
    local sprite = pet:get_sprite() or ""
    local age_seconds = pet:get_age() / 1000.0
    local name_line = ("Name: %s  (Age: %.1fs)"):format(pet.name, age_seconds)

    local satiety_bar = ascii_bar(pet:get_satiety(), 100, 10)

    local happiness_bar = ascii_bar(pet:get_happiness(), 100, 10)

    -- You can add more or fewer lines as you like:
    -- We'll pad lines so sprite stays on left, text on right.
    -- For simplicity, let's do a short sprite on the first line, then text on the same line.
    -- Additional lines can follow, showing bars, etc.
    local lines = {}

    -- First line: sprite on the left, name/age on the right
    -- We'll assume the sprite is short (one line).
    -- You can add spacing or center them differently as you expand the UI.
    lines[1] = string.format("%-20s  %s", sprite, name_line)

    -- Second line: label + satiety bar on the right
    lines[2] = string.format("%-20s  Satiety:    %s", "", satiety_bar)

    -- Third line: label + happiness bar on the right
    lines[3] = string.format("%-20s  Happiness:  %s", "", happiness_bar)

    return lines
end

-- track current open window
M.current = nil

-- create the floating window (a scratch buffer)
-- TODO: configurable size
local function create_floating_window()
    local width = math.floor(vim.o.columns * 0.5)
    local height = math.floor(vim.o.lines * 0.3)
    local row = math.floor((vim.o.lines - height) / 2) - 1
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
        return
    end

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
