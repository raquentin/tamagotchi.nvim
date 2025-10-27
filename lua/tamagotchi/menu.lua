local menu = {}

local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")

local function get_all_pets()
    local config = require("tamagotchi.config").values
    return config.pets or {}
end

local function fuzzy_match(str, pattern)
    if pattern == "" then return true end
    
    local pattern_idx = 1
    local pattern_len = #pattern
    local str_lower = str:lower()
    local pattern_lower = pattern:lower()
    
    for i = 1, #str_lower do
        if str_lower:sub(i, i) == pattern_lower:sub(pattern_idx, pattern_idx) then
            pattern_idx = pattern_idx + 1
            if pattern_idx > pattern_len then
                return true
            end
        end
    end
    
    return pattern_idx > pattern_len
end

function menu.open_pet_menu()
    local current_pet = window.get_current_pet()
    if current_pet then window.close(current_pet) end

    local pets_list = get_all_pets()
    if #pets_list == 0 then
        vim.notify("no pets found!", vim.log.levels.WARN)
        return
    end

    local state = {
        pets = pets_list,
        filtered_pets = pets_list,
        selected_idx = 1,
        query = "",
        preview_pet = nil,
        preview_frame = 1,
        animation_timer = nil,
    }

    local width = 50
    local height = 16
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
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    
    -- render function
    local function render()
        local lines = {}
        
        -- title
        table.insert(lines, "  select a pet")
        table.insert(lines, "")
        
        -- pet list (left side, takes ~25 chars)
        local list_start = #lines
        local visible_count = math.min(8, #state.filtered_pets)
        
        for i = 1, visible_count do
            local pet = state.filtered_pets[i]
            local marker = (i == state.selected_idx) and "> " or "  "
            table.insert(lines, marker .. pet.name)
        end
        
        while #lines < list_start + 8 do
            table.insert(lines, "")
        end
        
        if state.preview_pet then
            local sprite = state.preview_pet:get_sprite()
            local sprite_lines = {}
            for line in (sprite .. "\n"):gmatch("(.-)\n") do
                table.insert(sprite_lines, line)
            end
            
            -- overlay sprite on right side of list lines
            local sprite_offset = 22
            for i, sprite_line in ipairs(sprite_lines) do
                local list_line_idx = list_start + i
                if list_line_idx <= #lines then
                    local current_line = lines[list_line_idx]
                    if #current_line < sprite_offset then
                        current_line = current_line .. string.rep(" ", sprite_offset - #current_line)
                    end
                    lines[list_line_idx] = current_line .. sprite_line
                end
            end
        end
        
        table.insert(lines, "")
        table.insert(lines, string.rep("─", width - 2))
        table.insert(lines, "  search: " .. state.query .. "▊")
        table.insert(lines, "")
        table.insert(lines, "  [↑↓] nav  [enter] select  [esc] cancel")
        
        vim.api.nvim_buf_set_option(buf, "modifiable", true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, "modifiable", false)
        
        vim.api.nvim_buf_add_highlight(buf, -1, "Comment", 0, 0, -1)
        if state.selected_idx > 0 and state.selected_idx <= visible_count then
            vim.api.nvim_buf_add_highlight(
                buf,
                -1,
                "Visual",
                list_start + state.selected_idx - 1,
                0,
                -1
            )
        end
        
        if state.preview_pet and state.preview_pet.color_theme then
            local color_map = {
                red = "TamagotchiColorRed",
                green = "TamagotchiColorGreen",
                yellow = "TamagotchiColorYellow",
                blue = "TamagotchiColorBlue",
                magenta = "TamagotchiColorMagenta",
                cyan = "TamagotchiColorCyan",
                white = "TamagotchiColorWhite",
            }
            local color_hl = color_map[state.preview_pet.color_theme]
            if color_hl then
                local sprite = state.preview_pet:get_sprite()
                local sprite_lines = {}
                for line in (sprite .. "\n"):gmatch("(.-)\n") do
                    table.insert(sprite_lines, line)
                end
                
                local sprite_offset = 22
                for i, sprite_line in ipairs(sprite_lines) do
                    if sprite_line ~= "" then
                        local line_idx = list_start + i - 1
                        vim.api.nvim_buf_add_highlight(
                            buf,
                            -1,
                            color_hl,
                            line_idx,
                            sprite_offset,
                            sprite_offset + #sprite_line
                        )
                    end
                end
            end
        end
        
        vim.api.nvim_buf_add_highlight(buf, -1, "Comment", #lines - 1, 0, -1)
    end
    
    -- update preview pet
    local function update_preview()
        if #state.filtered_pets > 0 and state.selected_idx <= #state.filtered_pets then
            local pet_def = state.filtered_pets[state.selected_idx]
            state.preview_pet = Pet:new({
                name = pet_def.name,
                sprites = pet_def.sprites or {},
                sprite_update_interval = pet_def.sprite_update_interval or 2,
                mood = 80,
                satiety = 80,
            })
        else
            state.preview_pet = nil
        end
    end
    
    local function update_filter()
        state.filtered_pets = {}
        for _, pet in ipairs(state.pets) do
            if fuzzy_match(pet.name, state.query) then
                table.insert(state.filtered_pets, pet)
            end
        end
        
        if state.selected_idx > #state.filtered_pets then
            state.selected_idx = math.max(1, #state.filtered_pets)
        end
        
        update_preview()
        render()
    end
    
    state.animation_timer = vim.loop.new_timer()
    state.animation_timer:start(0, 1000, vim.schedule_wrap(function()
        if state.preview_pet and vim.api.nvim_win_is_valid(win) then
            state.preview_pet:get_sprite()
            render()
        end
    end))
    
    local function select_pet()
        if state.animation_timer then
            state.animation_timer:stop()
            state.animation_timer:close()
        end
        
        if #state.filtered_pets == 0 then return end
        
        local chosen_pet_def = state.filtered_pets[state.selected_idx]
        vim.api.nvim_win_close(win, true)
        
        local active_pet = _G.tamagotchi_pet

        if active_pet and active_pet.name == chosen_pet_def.name then
                        window.open(active_pet)
                        return
                    end

                    if active_pet then
                        local dialogue = require("tamagotchi.dialogue")
                        dialogue.choice(
                "switch pet: " .. chosen_pet_def.name,
                            string.format(
                    "you currently have %s. would you like to transfer progress "
                        .. "(just change appearance) or start a new pet life?\n\n"
                        .. "note: you'll be caring for both pets independently.",
                                active_pet.name
                            ),
                "transfer progress",
                "start new life",
                            function()
                                local new_pet = Pet:new(chosen_pet_def)
                                current_pet:transfer_stats_to(new_pet)
                                _G.tamagotchi_pet = new_pet
                                new_pet:save_on_vim_close()
                                vim.notify(
                        "transferred progress to " .. new_pet.name .. "!",
                                    vim.log.levels.INFO
                                )
                                window.open(new_pet)
                            end,
                            function()
                                current_pet:save_on_vim_close()

                                local save_path = vim.fn.stdpath("data")
                                    .. "/tamagotchi_"
                                    .. chosen_pet_def.name
                                    .. ".json"
                    local loaded_pet = Pet.load_on_vim_open(save_path)

                                local new_pet
                    if loaded_pet and loaded_pet.name == chosen_pet_def.name then
                                    new_pet = loaded_pet
                                else
                                    new_pet = Pet:new(chosen_pet_def)
                                end

                                _G.tamagotchi_pet = new_pet
                                vim.notify(
                        "started caring for " .. new_pet.name .. "!",
                                    vim.log.levels.INFO
                                )
                                window.open(new_pet)
                            end
                        )
                    else
                        local save_path = vim.fn.stdpath("data")
                            .. "/tamagotchi_"
                            .. chosen_pet_def.name
                            .. ".json"
                        local loaded_pet = Pet.load_on_vim_open(save_path)

                        local chosen_pet
            if loaded_pet and loaded_pet.name == chosen_pet_def.name then
                            chosen_pet = loaded_pet
                        else
                            chosen_pet = Pet:new(chosen_pet_def)
                        end

                        _G.tamagotchi_pet = chosen_pet
                        window.open(chosen_pet)
                end
            end

    local function cancel()
        if state.animation_timer then
            state.animation_timer:stop()
            state.animation_timer:close()
        end
        vim.api.nvim_win_close(win, true)
    end
    
    vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "", {
        noremap = true,
        silent = true,
        callback = function()
            if state.selected_idx > 1 then
                state.selected_idx = state.selected_idx - 1
                update_preview()
                render()
            end
        end,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "", {
        noremap = true,
        silent = true,
        callback = function()
            if state.selected_idx < #state.filtered_pets then
                state.selected_idx = state.selected_idx + 1
                update_preview()
                render()
            end
        end,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
        noremap = true,
        silent = true,
        callback = function()
            if state.selected_idx > 1 then
                state.selected_idx = state.selected_idx - 1
                update_preview()
                render()
            end
        end,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "j", "", {
        noremap = true,
        silent = true,
        callback = function()
            if state.selected_idx < #state.filtered_pets then
                state.selected_idx = state.selected_idx + 1
                update_preview()
                render()
            end
        end,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
        noremap = true,
        silent = true,
        callback = select_pet,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
        noremap = true,
        silent = true,
        callback = cancel,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = cancel,
    })
    
    vim.api.nvim_buf_set_keymap(buf, "n", "i", "", {
        noremap = true,
        silent = true,
        callback = function()
            vim.ui.input({
                prompt = "search: ",
                default = state.query,
            }, function(input)
                if input then
                    state.query = input
                    update_filter()
                end
            end)
        end,
    })
    
    for char in ("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"):gmatch(".") do
        vim.api.nvim_buf_set_keymap(buf, "n", char, "", {
            noremap = true,
            silent = true,
            callback = function()
                state.query = state.query .. char
                update_filter()
            end,
        })
    end
    
    -- backspace
    vim.api.nvim_buf_set_keymap(buf, "n", "<BS>", "", {
        noremap = true,
        silent = true,
        callback = function()
            if #state.query > 0 then
                state.query = state.query:sub(1, -2)
                update_filter()
            end
        end,
    })
    
    update_preview()
    render()
end

return menu
