local menu = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")

-- TODO: animate sprite in right pane
local sprite_timer = nil

local function get_all_pets()
    local config = require("tamagotchi.config").values
    return config.pets or {}
end

-- custom previewer that draws the sprite in the preview buffer
local function make_pet_previewer()
    return previewers.new_buffer_previewer({
        define_preview = function(self, entry, status)
            local bufnr = self.state.bufnr
            vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

            -- entry.value is whichever item is under cursor in the results
            local pet_def = entry.value
            local pet_obj = Pet:new({
                name = pet_def.name,
                sprites = pet_def.sprites or {},
                mood = 80, -- or load from disk if you want
                satiety = 80, -- ...
            })

            -- grab the current sprite frame text
            local sprite = pet_obj:get_sprite()

            -- set lines in preview buffer
            local sprite_lines = {}
            for line in (sprite .. "\n"):gmatch("(.-)\n") do
                table.insert(sprite_lines, line)
            end

            -- clear old lines and set new lines
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, sprite_lines)

            vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
        end,
    })
end

function menu.open_pet_menu()
    -- 1) Close the main tamagotchi window if open
    local current_pet = window.get_current_pet() -- Implement `get_current_pet()` appropriately
    if current_pet then window.close(current_pet) end

    -- 2) Gather the list of pets
    local pets_list = get_all_pets()
    if #pets_list == 0 then
        vim.notify("No pets found!", vim.log.levels.WARN)
        return
    end

    -- 3) Define the telescope picker with horizontal layout
    pickers
        .new({
            prompt_title = "Select a Pet",
            finder = finders.new_table({
                results = pets_list,
                entry_maker = function(pet_def)
                    return {
                        value = pet_def,
                        display = pet_def.name,
                        ordinal = pet_def.name, -- for fuzzy searching by name
                    }
                end,
            }),
            previewer = make_pet_previewer(),

            sorter = conf.generic_sorter(),
            layout_strategy = "horizontal",
            layout_config = {
                width = 0.5,
                height = 0.5,
                preview_width = 0.35,
                prompt_position = "bottom",
                horizontal = {
                    mirror = false, -- Preview on the right
                },
            },
            preview_cutoff = 0, -- Always show preview regardless of window size
            attach_mappings = function(prompt_bufnr, map)
                -- When user confirms ( <CR> ), pick that pet
                local actions = require("telescope.actions")
                local action_state = require("telescope.actions.state")

                local select_pet = function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)

                    if not selection then return end

                    local chosen_pet_def = selection.value
                    local current_pet = _G.tamagotchi_pet

                    -- If selecting the same pet, just reopen
                    if
                        current_pet
                        and current_pet.name == chosen_pet_def.name
                    then
                        window.open(current_pet)
                        return
                    end

                    -- If we have a current pet, ask what to do
                    if current_pet then
                        local dialogue = require("tamagotchi.dialogue")
                        dialogue.choice(
                            "Switch Pet: " .. chosen_pet_def.name,
                            string.format(
                                "You currently have %s. Would you like to transfer progress (just change appearance) or start a new pet life? Note: Starting a new pet means you'll have both pets to care for.",
                                current_pet.name
                            ),
                            "Transfer Progress",
                            "Start New Life",
                            function()
                                -- Transfer progress option
                                local new_pet = Pet:new(chosen_pet_def)
                                current_pet:transfer_stats_to(new_pet)
                                _G.tamagotchi_pet = new_pet
                                new_pet:save_on_vim_close()
                                vim.notify(
                                    "Transferred progress to "
                                        .. new_pet.name
                                        .. "!",
                                    vim.log.levels.INFO
                                )
                                window.open(new_pet)
                            end,
                            function()
                                -- Start new life option
                                -- Save current pet
                                current_pet:save_on_vim_close()

                                -- Try to load existing save for new pet, or create fresh
                                local save_path = vim.fn.stdpath("data")
                                    .. "/tamagotchi_"
                                    .. chosen_pet_def.name
                                    .. ".json"
                                local loaded_pet =
                                    Pet.load_on_vim_open(save_path)

                                local new_pet
                                if
                                    loaded_pet
                                    and loaded_pet.name
                                        == chosen_pet_def.name
                                then
                                    new_pet = loaded_pet
                                else
                                    new_pet = Pet:new(chosen_pet_def)
                                end

                                _G.tamagotchi_pet = new_pet
                                vim.notify(
                                    "Started caring for " .. new_pet.name .. "!",
                                    vim.log.levels.INFO
                                )
                                window.open(new_pet)
                            end
                        )
                    else
                        -- No current pet, just load or create
                        local save_path = vim.fn.stdpath("data")
                            .. "/tamagotchi_"
                            .. chosen_pet_def.name
                            .. ".json"
                        local loaded_pet = Pet.load_on_vim_open(save_path)

                        local chosen_pet
                        if
                            loaded_pet
                            and loaded_pet.name == chosen_pet_def.name
                        then
                            chosen_pet = loaded_pet
                        else
                            chosen_pet = Pet:new(chosen_pet_def)
                        end

                        _G.tamagotchi_pet = chosen_pet
                        window.open(chosen_pet)
                    end
                end

                map("i", "<CR>", function() select_pet() end)
                map("n", "<CR>", function() select_pet() end)

                return true
            end,
        })
        :find()
end
return menu
