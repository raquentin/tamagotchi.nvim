local M = {}

-- track current open window, timer
M.current_window = nil
M.refresh_timer = nil
M.current_pet = nil

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
        if #line > sprite_width then sprite_width = #line end
    end

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
            combined = combined:sub(1, width)
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

    M.current_window = create_floating_window()

    local buf = M.current_window.buf

    vim.api.nvim_buf_set_keymap(buf, "n", "M", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function() require("tamagotchi.menu").open_pet_menu() end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "I", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function()
            require("tamagotchi.info").show_info(_G.tamagotchi_pet)
        end,
    })
    vim.api.nvim_buf_set_keymap(buf, "n", "R", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function()
            local dialogue = require("tamagotchi.dialogue")
            dialogue.choice(
                "Reset Options",
                "What would you like to reset?",
                "Reset Current Pet Only",
                "Reset All Pets (Delete All Saves)",
                function()
                    -- reset current pet only
                    dialogue.confirm(
                        "Reset Current Pet",
                        "Are you sure you want to reset "
                            .. (_G.tamagotchi_pet.name or "your pet")
                            .. "? This will reset all stats and age to initial values.",
                        function()
                            _G.tamagotchi_pet:reset()
                            _G.tamagotchi_pet:save_on_vim_close()
                            vim.notify(
                                "Pet has been reset!",
                                vim.log.levels.INFO
                            )
                        end,
                        nil
                    )
                end,
                function()
                    -- reset all pets (delete all save files)
                    dialogue.confirm(
                        "Reset All Pets",
                        "Are you ABSOLUTELY SURE you want to delete ALL pet save files? This cannot be undone!",
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
                                "Deleted "
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
    vim.api.nvim_buf_set_keymap(buf, "n", "N", "", {
        nowait = true,
        noremap = true,
        silent = true,
        callback = function()
            local dialogue = require("tamagotchi.dialogue")
            local current_pet = _G.tamagotchi_pet
            dialogue.input(
                "Rename Pet",
                "Enter a new name for your pet:",
                current_pet.name,
                function(new_name)
                    local old_name = current_pet.name
                    local old_save_path = current_pet:get_save_path()

                    current_pet:set_name(new_name)
                    current_pet:save_on_vim_close()

                    if
                        old_name ~= new_name
                        and vim.fn.filereadable(old_save_path) == 1
                    then
                        vim.fn.delete(old_save_path)
                    end

                    vim.notify(
                        string.format(
                            "Renamed pet from '%s' to '%s'!",
                            old_name,
                            new_name
                        ),
                        vim.log.levels.INFO
                    )
                end,
                nil
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

    local final_lines =
        build_final_lines(pet, width, height, M.last_sprite or "", M.tabs)

    vim.api.nvim_buf_set_lines(M.current_window.buf, 0, -1, false, final_lines)

    local bottom_line_idx = #final_lines - 1
    highlight_bottom_bar(M.current_window.buf, bottom_line_idx, M.tabs, width)
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
        label = "Pet [M]enu",
        hl_group = "TamagotchiTab1",
    },
    {
        label = "More [I]nfo",
        hl_group = "TamagotchiTab2",
    },
    {
        label = "Re[n]ame",
        hl_group = "TamagotchiTab3",
    },
    {
        label = "[R]eset",
        hl_group = "TamagotchiTab4",
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
