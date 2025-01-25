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
                width = 0.4, -- 40% of screen width
                height = 7, -- 7 rows
                preview_width = 0.3, -- 30% of the Telescope window width for preview
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
                    -- Re-open the main Tamagotchi window with that pet
                    local chosen_pet = Pet:new({
                        name = chosen_pet_def.name,
                        sprites = chosen_pet_def.sprites,
                        -- Restore mood/satiety from saved data, etc.
                    })
                    window.open(chosen_pet)
                end

                map("i", "<CR>", function() select_pet() end)
                map("n", "<CR>", function() select_pet() end)

                return true
            end,
        })
        :find()
end
return menu
