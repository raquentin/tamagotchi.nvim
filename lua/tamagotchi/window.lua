local M = {}

-- track current open window, timer
M.current = nil
M.refresh_timer = nil

local function ascii_bar(value, max, width)
    local filled = math.floor((value / max) * width)
    local unfilled = width - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", unfilled) .. "]"
end

-- center `text` within `width` by adding left/right padding.
-- if text is longer than width, it is truncated.
function M.center_text(text, width)
    if #text >= width then return text:sub(1, width) end
    local left_pad = math.floor((width - #text) / 2)
    local right_pad = width - #text - left_pad
    return string.rep(" ", left_pad) .. text .. string.rep(" ", right_pad)
end

-- builds the top layout (sprite left, attrs right)
local function build_top_lines(pet, width, height, sprite_override)
    local PAD = 1

    local content_height = height - PAD - 1
    local total_content_width = width - PAD

    -- break sprite into lines
    local sprite_text = sprite_override or pet:get_sprite()
    local sprite_lines = {}
    local sprite_width = 0
    for line in (sprite_text .. "\n"):gmatch("(.-)\n") do
        table.insert(sprite_lines, line)
        local line_length = #line
        if line_length > sprite_width then sprite_width = line_length end
    end
    sprite_width = sprite_width

    local right_block_width = total_content_width - sprite_width - PAD
    if right_block_width < 1 then right_block_width = 1 end

    -- prepare info lines
    local info_lines = {
        ("Name:    %s"):format(pet.name),
        ("Age:     %s"):format(pet:get_age_formatted()),
        ("Satiety: %s"):format(ascii_bar(pet:get_satiety(), 100, 10)),
        ("Mood:    %s"):format(ascii_bar(pet:get_mood(), 100, 10)),
    }

    local lines_count = math.max(#sprite_lines, #info_lines, content_height)

    local final_lines = {}
    final_lines[1] = string.rep(" ", width)

    -- main content
    for i = 1, lines_count do
        local sprite_str = sprite_lines[i] or ""
        sprite_str = M.center_text(sprite_str, sprite_width)

        local info_str = info_lines[i] or ""
        info_str = M.center_text(info_str, right_block_width)

        local combined = string.rep(" ", PAD)
            .. sprite_str
            .. string.rep(" ", PAD)
            .. info_str

        -- pad to right edge or clip off right edge
        if #combined < width then
            combined = combined .. string.rep(" ", width - #combined)
        elseif #combined > width then
            combined = combined:sub(1, width) -- truncate
        end

        final_lines[i + 1] = combined
    end

    return final_lines
end

-- build the bottom bar line as a single string, then highlight each tab segment
local function build_bottom_line(tabs, width)
    local segment_count = #tabs

    -- if no tabs, just blank
    if segment_count < 1 then return string.rep(" ", width) end

    -- each tab gets an equal portion of width
    local segment_width = math.floor(width / segment_count)
    local line_parts = {}
    local used_cols = 0

    for i, tab in ipairs(tabs) do
        local text = tab.label
        -- center text within segment:
        text = M.center_text(text, segment_width)

        line_parts[i] = text
        used_cols = used_cols + segment_width
    end

    -- leftover if width is not perfectly divisible by segment_count
    local leftover = width - used_cols
    if leftover > 0 then
        line_parts[#line_parts] = line_parts[#line_parts]
            .. string.rep(" ", leftover)
    end

    return table.concat(line_parts, "")
end

-- applies highlight groups for each tab segment in the bottom bar
local function highlight_bottom_bar(buf, line_num, tabs, width)
    local segment_count = #tabs
    if segment_count < 1 then return end

    local segment_width = math.floor(width / segment_count)
    local current_col = 0

    for i, tab in ipairs(tabs) do
        local start_col = current_col
        local end_col = current_col + segment_width
        -- leftover for uneven division
        if i == segment_count then end_col = width end

        vim.api.nvim_buf_add_highlight(
            buf,
            0, -- ns_id
            tab.hl_group,
            line_num,
            start_col,
            end_col
        )
        current_col = end_col
    end
end

local function build_final_lines(pet, width, height, sprite_override, tabs)
    local top_lines = build_top_lines(pet, width, height, sprite_override)

    local bottom_line = build_bottom_line(tabs, width)

    top_lines[#top_lines + 1] = bottom_line
    return top_lines
end

-- create the floating window (a scratch buffer)
local function create_floating_window()
    local width = math.floor(vim.o.columns * 0.4)
    local height = 7
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

    M.update_ui(pet, true)

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
function M.update_ui(pet, update_sprite)
    if not (M.current and vim.api.nvim_win_is_valid(M.current.win)) then
        return
    end

    local width = M.current.width
    local height = M.current.height

    if update_sprite then M.last_sprite = pet:get_sprite() end

    local final_lines =
        build_final_lines(pet, width, height, M.last_sprite or "", M.tabs)

    vim.api.nvim_buf_set_lines(M.current.buf, 0, -1, false, final_lines)

    local bottom_line_idx = #final_lines - 1
    highlight_bottom_bar(M.current.buf, bottom_line_idx, M.tabs, width)
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
    local sprite_interval = pet.sprite_update_interval

    -- start at interval so it prints on initial tick
    M.sprite_counter = sprite_interval
    M.last_sprite = ""

    if M.refresh_timer then
        M.refresh_timer:stop()
        M.refresh_timer:close()
        M.refresh_timer = nil
    end

    local config = require("tamagotchi.config").values

    M.refresh_timer = vim.loop.new_timer()
    M.refresh_timer:start(
        0,
        config.tick_length_ms,
        vim.schedule_wrap(function()
            pet:update()

            M.sprite_counter = (M.sprite_counter or 0) + 1
            local update_sprite = false
            if M.sprite_counter >= sprite_interval then
                M.sprite_counter = 0
                update_sprite = true
            end

            -- refresh UI if still open
            if M.current and vim.api.nvim_win_is_valid(M.current.win) then
                M.update_ui(pet, update_sprite)
            else
                -- stop timer if closed
                M.close()
            end
        end)
    )
end

M.tabs = {
    {
        label = "Pet [M]enu",
        hl_group = "TamagotchiTab1",
    },
    {
        label = "More [I]nfo",
        hl_group = "TamagotchiTab2",
    },
    {
        label = "[R]eset",
        hl_group = "TamagotchiTab3",
    },
}

-- draw the bottom tab bar
function M.draw_bottom_bar(buf, line_num, tabs)
    -- build the text line for all tabs
    local segments = {}
    for _, tab in ipairs(tabs) do
        -- e.g. "[P]Pet Select", then separate with " | "
        table.insert(segments, tab.label)
    end

    -- might want to add " | " between them:
    local line_text = table.concat(segments, " | ")

    -- set this line in the buffer
    vim.api.nvim_buf_set_lines(
        buf,
        line_num,
        line_num + 1,
        false,
        { line_text }
    )

    -- highlight each tab segment in the line
    local current_col = 0
    for i, tab in ipairs(tabs) do
        local segment_text = tab.label
        local segment_len = #segment_text

        -- highlight from current_col (inclusive) to current_col+segment_len (exclusive)
        vim.api.nvim_buf_add_highlight(
            buf,
            0, -- ns_id = 0 for the global namespace
            tab.hl_group,
            line_num,
            current_col,
            current_col + segment_len
        )

        current_col = current_col + segment_len

        -- add " | " if not last
        if i < #tabs then
            local separator_len = 3
            current_col = current_col + separator_len
        end
    end
end

return M
