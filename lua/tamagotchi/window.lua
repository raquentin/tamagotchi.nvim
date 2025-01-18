local M = {}

-- track current open window, timer
M.current = nil
M.refresh_timer = nil

local function ascii_bar(value, max, width)
    local filled = math.floor((value / max) * width)
    local unfilled = width - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", unfilled) .. "]"
end

-- builds the horizontal layout
local function build_ui_lines(pet, width, height)
    -- break sprite into lines if applicable
    local sprite_text = pet:get_sprite() or ""
    local sprite_lines = {}
    for line in (sprite_text .. "\n"):gmatch("(.-)\n") do
        table.insert(sprite_lines, line)
    end

    -- build the right div (age, name, attrs)
    local right_lines = {
        ("Name:    %s"):format(pet.name),
        ("Age:     %.1fs"):format(pet:get_age() / 1000.0),
        ("Satiety: %s"):format(ascii_bar(pet:get_satiety(), 100, 10)),
        ("Mood:    %s"):format(ascii_bar(pet:get_mood(), 100, 10)),
    }

    local lines_count = math.max(#sprite_lines, #right_lines, height)

    local left_width = math.floor(width / 2)
    local final_lines = {}

    for i = 1, lines_count do
        local left_str = sprite_lines[i] or ""

        -- if the sprite is wider than left_width, truncate it
        if #left_str > left_width then
            left_str = left_str:sub(1, left_width)
        end

        -- pad the sprite line on the right with spaces to maintain the left width
        if #left_str < left_width then
            left_str = left_str .. string.rep(" ", left_width - #left_str)
        end

        local right_str = right_lines[i] or ""

        -- combine them
        final_lines[i] = left_str .. right_str
    end

    return final_lines
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
    vim.api.nvim_win_set_option(win, "wrap", false)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)

    return { buf = buf, win = win, width = width, height = height }
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
    M.start_refresh_loop(pet)
    return M.current
end

function M.close()
    if M.refresh_timer then
        M.refresh_timer:stop()
        M.refresh_timer:close()
        M.refresh_timer = nil
    end

    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        vim.api.nvim_win_close(M.current.win, true)
    end
    M.current = nil
end

-- update the buffer lines for the currently open window
function M.update_ui(pet)
    if not M.current or not vim.api.nvim_win_is_valid(M.current.win) then
        return
    end
    local width = M.current.width
    local height = M.current.height

    local lines = build_ui_lines(pet, width, height)
    vim.api.nvim_buf_set_lines(M.current.buf, 0, -1, false, lines)
end

function M.toggle(pet)
    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        M.close()
        return nil
    else
        return M.open(pet)
    end
end

function M.start_refresh_loop(pet)
    if M.refresh_timer then
        M.refresh_timer:stop()
        M.refresh_timer:close()
        M.refresh_timer = nil
    end

    M.refresh_timer = vim.loop.new_timer()
    M.refresh_timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            -- TODO: untrivialize this
            pet:update()

            -- refresh UI if still open
            if M.current and vim.api.nvim_win_is_valid(M.current.win) then
                M.update_ui(pet)
            else
                -- stop timer if closed
                M.close()
            end
        end)
    )
end

return M
