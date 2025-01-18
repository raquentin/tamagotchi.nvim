local M = {}

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

function M.open()
    M.current = create_floating_window()
    return M.current
end

function M.close()
    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        vim.api.nvim_win_close(M.current.win, true)
    end
    M.current = nil
end

function M.toggle()
    if M.current and vim.api.nvim_win_is_valid(M.current.win) then
        M.close()
        return nil
    else
        return M.open()
    end
end

return M
