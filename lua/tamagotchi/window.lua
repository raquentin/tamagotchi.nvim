local M = {}

-- track current open window, timer
M.current_window = nil
M.refresh_timer = nil
M.current_pet = nil

-- color theme mapping to highlight groups
local COLOR_THEME_MAP = {
    red = "TamagotchiColorRed",
    green = "TamagotchiColorGreen",
    yellow = "TamagotchiColorYellow",
    blue = "TamagotchiColorBlue",
    magenta = "TamagotchiColorMagenta",
    cyan = "TamagotchiColorCyan",
    white = "TamagotchiColorWhite",
}

-- get tabs with dynamic colors based on pet's color theme
local function get_tabs(pet)
    local base_hl = "TamagotchiTab1"
    if pet and pet.color_theme and COLOR_THEME_MAP[pet.color_theme] then
        base_hl = COLOR_THEME_MAP[pet.color_theme]
    end
    
    return {
        {
            label = "pet [m]enu",
            hl_group = base_hl,
        },
        {
            label = "[s]ettings",
            hl_group = base_hl,
        },
        {
            label = "[r]eset",
            hl_group = base_hl,
        },
    }
end

local function ascii_bar(value, max, width)
    assert(value >= 0, "value must be non-negative")
    assert(max > 0, "max must be positive")
    assert(width > 0, "width must be positive")

    local filled = math.floor((value / max) * width)
    local unfilled = width - filled
    return "[" .. string.rep("#", filled) .. string.rep("-", unfilled) .. "]"
end

-- center `text` within `width` by adding left/right padding.
-- if text is longer than width, it is truncated.
function M.center_text(text, width)
    assert(type(text) == "string", "text must be a string")
    assert(
        type(width) == "number" and width > 0,
        "width must be a positive number"
    )

    if #text >= width then return text:sub(1, width) end
    local left_pad = math.floor((width - #text) / 2)
    local right_pad = width - #text - left_pad
    return string.rep(" ", left_pad) .. text .. string.rep(" ", right_pad)
end

-- builds the top layout (sprite left, attrs right)
-- normalize sprite to rectangular bounding box, trimming whitespace
local function normalize_sprite(sprite_text)
    local lines = {}
    
    for line in (sprite_text .. "\n"):gmatch("(.-)\n") do
        table.insert(lines, line)
    end
    
    -- find the actual content bounds (trim leading/trailing whitespace)
    local min_start = math.huge
    local max_end = 0
    
    for _, line in ipairs(lines) do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" then
            -- find where non-whitespace starts and ends
            local start_pos = line:find("%S")
            local end_pos = line:find("%s*$") - 1
            if start_pos then
                min_start = math.min(min_start, start_pos)
                max_end = math.max(max_end, end_pos)
            end
        end
    end
    
    -- if no content found, fallback to original behavior
    if min_start == math.huge then
        min_start = 1
        max_end = 0
        for _, line in ipairs(lines) do
            max_end = math.max(max_end, #line)
        end
    end
    
    local content_width = max_end - min_start + 1
    
    -- extract and normalize the actual content
    local normalized = {}
    for _, line in ipairs(lines) do
        local content = ""
        if #line >= min_start then
            content = line:sub(min_start, math.min(#line, max_end))
        end
        -- pad to content_width
        if #content < content_width then
            local padding_needed = content_width - #content
            local left_pad = math.floor(padding_needed / 2)
            local right_pad = padding_needed - left_pad
            content = string.rep(" ", left_pad) .. content .. string.rep(" ", right_pad)
        end
        table.insert(normalized, content)
    end
    
    return normalized, content_width, #normalized
end

local function build_top_lines(pet, width, height, sprite_override)
    -- normalize sprite to rectangular box
    local sprite_text = sprite_override or pet:get_sprite()
    local sprite_lines, sprite_width, sprite_height = normalize_sprite(sprite_text)

    -- prepare info lines
    local info_lines = {
        ("name:    %s"):format(pet.name),
        ("age:     %s"):format(pet:get_age_formatted()),
        ("satiety: %s"):format(ascii_bar(pet:get_satiety(), 100, 10)),
        ("mood:    %s"):format(ascii_bar(pet:get_mood(), 100, 10)),
    }
    local info_height = #info_lines
    local info_width = 0
    for _, line in ipairs(info_lines) do
        if #line > info_width then info_width = #line end
    end

    -- calculate content dimensions
    local content_height = math.max(sprite_height, info_height)
    
    -- calculate the gap between sprite and stats to center them with equal padding
    -- total_content_width = left_pad + sprite_width + gap + info_width + right_pad
    -- we want: left_pad = right_pad
    local min_gap = 3
    local available_space = width - sprite_width - info_width
    local gap = math.max(min_gap, math.floor(available_space / 3))
    
    -- calculate padding to ensure left_pad == right_pad
    local total_padding = width - sprite_width - gap - info_width
    local left_pad = math.floor(total_padding / 2)
    local right_pad = total_padding - left_pad
    
    local final_lines = {}
    
    -- add 1 empty line at top
    table.insert(final_lines, string.rep(" ", width))
    
    -- build content lines (sprite and stats vertically aligned to top)
    for i = 1, content_height do
        local line = string.rep(" ", left_pad)
        
        -- add sprite content (or blank if outside sprite bounds)
        if i <= sprite_height then
            line = line .. sprite_lines[i]
        else
            line = line .. string.rep(" ", sprite_width)
        end
        
        -- add gap between sprite and stats
        line = line .. string.rep(" ", gap)
        
        -- add info content (or blank if outside info bounds)
        if i <= info_height then
            line = line .. info_lines[i]
        else
            line = line .. string.rep(" ", info_width)
        end
        
        -- add right padding (ensures exact equal padding)
        line = line .. string.rep(" ", right_pad)
        
        table.insert(final_lines, line)
    end
    
    -- add 1 empty line after content
    table.insert(final_lines, string.rep(" ", width))

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

-- highlight the sprite with the pet's color theme
local function highlight_sprite(buf, pet, sprite_text, width)
    if not pet or not pet.color_theme then return end
    
    local color_hl = COLOR_THEME_MAP[pet.color_theme]
    if not color_hl then return end
    
    -- normalize sprite to get dimensions
    local sprite_lines, sprite_width, sprite_height = normalize_sprite(sprite_text)
    
    -- calculate left padding (same logic as build_top_lines)
    local info_width = 30
    local min_gap = 3
    local available_space = width - sprite_width - info_width
    local gap = math.max(min_gap, math.floor(available_space / 3))
    local left_pad = math.floor((width - sprite_width - gap - info_width) / 2)
    
    -- sprite starts at line 1 (after the top empty line at line 0)
    for i = 1, sprite_height do
        local buffer_line_idx = i -- line 1, 2, 3, etc
        local start_col = left_pad
        local end_col = left_pad + sprite_width
        
        vim.api.nvim_buf_add_highlight(
            buf,
            0,
            color_hl,
            buffer_line_idx,
            start_col,
            end_col
        )
    end
end

local function build_final_lines(pet, width, height, sprite_override, tabs)
    local top_lines = build_top_lines(pet, width, height, sprite_override)

    local bottom_line = build_bottom_line(tabs, width)

    top_lines[#top_lines + 1] = bottom_line
    return top_lines
end

-- calculate optimal window dimensions based on pet sprite
local function calculate_window_dimensions(pet)
    -- get sprite dimensions
    local sprite_text = pet:get_sprite()
    local _, sprite_width, sprite_height = normalize_sprite(sprite_text)
    
    -- info section dimensions
    local info_height = 4 -- we have 4 info lines
    local info_width = 30 -- approximate, "satiety: [##########]" is ~22 chars
    
    -- calculate content dimensions
    local content_height = math.max(sprite_height, info_height)
    
    -- calculate minimum width needed for content with equal padding
    local min_gap = 3
    local min_width = sprite_width + min_gap + info_width + 10 -- 10 for side padding
    
    -- vertical layout: 1 empty + content + 1 empty + 1 tab bar
    local total_height = 1 + content_height + 1 + 1
    
    -- ensure minimum dimensions
    local width = math.max(min_width, 40)
    local height = total_height
    
    return width, height
end

-- create the floating window (a scratch buffer)
local function create_floating_window(pet)
    local width, height = calculate_window_dimensions(pet)
    
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
        border = "single",
    }

    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_win_set_option(win, "wrap", false)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)

    return { buf = buf, win = win, width = width, height = height }
end

function M.get_current_pet() return M.current_pet end

function M.open(pet)
    assert(pet, "pet is required")
    assert(type(pet) == "table", "pet must be a table")
    assert(type(pet.get_mood) == "function", "pet must have get_mood method")
    assert(
        type(pet.get_satiety) == "function",
        "pet must have get_satiety method"
    )
    assert(
        type(pet.get_sprite) == "function",
        "pet must have get_sprite method"
    )

    M.current_pet = pet

    -- Apply retroactive decay since last window close
    local elapsed_ms = vim.loop.now() - pet.last_window_close_time
    local elapsed_seconds = elapsed_ms / 1000

    -- Calculate expected decay (cap at 10 minutes for window toggles)
    local max_window_decay_time = 600 -- 10 minutes
    local effective_time = math.min(elapsed_seconds, max_window_decay_time)

    local mood_decay = pet.mood_decay_probability * effective_time
    local satiety_decay = pet.satiety_decay_probability * effective_time

    pet:set_mood(pet:get_mood() - mood_decay)
    pet:set_satiety(pet:get_satiety() - satiety_decay)

    -- close open window if exists
    if M.current_window and vim.api.nvim_win_is_valid(M.current_window.win) then
        vim.api.nvim_win_close(M.current_window.win, true)
        M.current_window = nil
    end

    M.current_window = create_floating_window(pet)

    local buf = M.current_window.buf

    vim.api.nvim_buf_set_keymap(buf, "n", "m", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function() require("tamagotchi.menu").open_pet_menu() end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "M", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function() require("tamagotchi.menu").open_pet_menu() end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "s", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function()
            require("tamagotchi.settings").show_settings(_G.tamagotchi_pet)
        end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "S", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function()
            require("tamagotchi.settings").show_settings(_G.tamagotchi_pet)
        end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "r", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function()
            local dialogue = require("tamagotchi.dialogue")
            dialogue.choice(
                "reset options",
                "what would you like to reset?",
                "reset current pet only",
                "reset all pets (delete all saves)",
                function()
                    -- reset current pet only
                    dialogue.confirm(
                        "reset current pet",
                        "are you sure you want to reset "
                            .. (_G.tamagotchi_pet.name or "your pet")
                            .. "? this will reset all stats and age to initial values.",
                        function()
                            _G.tamagotchi_pet:reset()
                            _G.tamagotchi_pet:save_on_vim_close()
                            vim.notify(
                                "pet has been reset!",
                                vim.log.levels.INFO
                            )
                        end,
                        nil
                    )
                end,
                function()
                    -- reset all pets (delete all save files)
                    dialogue.confirm(
                        "reset all pets",
                        "are you ABSOLUTELY SURE you want to delete ALL pet save files? this cannot be undone!",
                        function()
                            local data_dir = vim.fn.stdpath("data")
                            local config = require("tamagotchi.config").values
                            local deleted_count = 0

                            -- delete all pet-specific save files
                            for _, pet_def in ipairs(config.pets) do
                                local save_path = data_dir
                                    .. "/tamagotchi_"
                                    .. pet_def.name
                                    .. ".json"
                                if vim.fn.filereadable(save_path) == 1 then
                                    vim.fn.delete(save_path)
                                    deleted_count = deleted_count + 1
                                end
                            end

                            -- delete generic save file
                            local generic_save = data_dir .. "/tamagotchi.json"
                            if vim.fn.filereadable(generic_save) == 1 then
                                vim.fn.delete(generic_save)
                                deleted_count = deleted_count + 1
                            end

                            -- reset current pet
                            _G.tamagotchi_pet:reset()
                            _G.tamagotchi_pet:save_on_vim_close()

                            vim.notify(
                                "deleted "
                                    .. deleted_count
                                    .. " save file(s) and reset current pet!",
                                vim.log.levels.WARN
                            )
                        end,
                        nil
                    )
                end
            )
        end,
    })
    M.update_ui(pet, true)
    M.start_refresh_loop(pet)
    return M.current_window
end

function M.close(pet)
    if M.refresh_timer then
        M.refresh_timer:stop()
        M.refresh_timer:close()
        M.refresh_timer = nil
    end

    if pet then pet:save_on_window_close() end

    if M.current_window and vim.api.nvim_win_is_valid(M.current_window.win) then
        vim.api.nvim_win_close(M.current_window.win, true)
    end
    M.current_window = nil
end

-- update the buffer lines for the currently open window
function M.update_ui(pet, update_sprite)
    if
        not (
            M.current_window and vim.api.nvim_win_is_valid(M.current_window.win)
        )
    then
        return
    end

    local width = M.current_window.width
    local height = M.current_window.height

    if update_sprite then M.last_sprite = pet:get_sprite() end

    local tabs = get_tabs(pet)
    local sprite_to_use = M.last_sprite or ""
    local final_lines =
        build_final_lines(pet, width, height, sprite_to_use, tabs)

    vim.api.nvim_buf_set_lines(M.current_window.buf, 0, -1, false, final_lines)

    -- highlight the sprite with the pet's color
    highlight_sprite(M.current_window.buf, pet, sprite_to_use, width)
    
    local bottom_line_idx = #final_lines - 1
    highlight_bottom_bar(M.current_window.buf, bottom_line_idx, tabs, width)
end

function M.toggle(pet)
    if M.current_window and vim.api.nvim_win_is_valid(M.current_window.win) then
        M.close(pet)
        return nil
    else
        return M.open(pet)
    end
end

function M.start_refresh_loop(pet)
    assert(pet, "pet is required for refresh loop")
    assert(
        type(pet.sprite_update_interval) == "number",
        "pet must have sprite_update_interval"
    )

    local sprite_interval = pet.sprite_update_interval

    -- Start at interval so it prints on initial tick
    M.sprite_counter = sprite_interval
    M.last_sprite = ""

    -- Stop existing timer if any
    if M.refresh_timer then
        M.refresh_timer:stop()
        M.refresh_timer:close()
        M.refresh_timer = nil
    end

    local config = require("tamagotchi.config").values
    assert(config.tick_length_ms, "tick_length_ms not found in config")

    M.refresh_timer = vim.loop.new_timer()
    M.refresh_timer:start(
        0,
        config.tick_length_ms,
        vim.schedule_wrap(function()
            -- Update pet state
            if pet and pet.update then pet:update() end

            M.sprite_counter = (M.sprite_counter or 0) + 1
            local update_sprite = false
            if M.sprite_counter >= sprite_interval then
                M.sprite_counter = 0
                update_sprite = true
            end

            -- Refresh UI if still open
            if
                M.current_window
                and vim.api.nvim_win_is_valid(M.current_window.win)
            then
                M.update_ui(pet, update_sprite)
            else
                -- Stop timer if window was closed
                M.close(pet)
            end
        end)
    )
end

M.tabs = {
    {
        label = "pet [m]enu",
        hl_group = "TamagotchiTab1",
    },
    {
        label = "[s]ettings",
        hl_group = "TamagotchiTab2",
    },
    {
        label = "[r]eset",
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
