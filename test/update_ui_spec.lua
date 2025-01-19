local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("update_ui with sprite flag", function()
    local original_win_is_valid

    before_each(function()
        config.setup({
            pets = {
                {
                    name = "TestPet",
                    sprite_update_interval = 20,
                    sprites = {
                        happy = { ":)", ":-D" },
                        hungry = { ":(" },
                        neutral = { ":|" },
                    },
                },
            },
        })
        _G.tamagotchi_pet = Pet:new(config.values.pets[1])
        window.current = { buf = 1, win = 1, width = 80, height = 24 }

        -- stub buffer_set_lines to do nothing during tests
        vim.api.nvim_buf_set_lines = function() end

        -- stub vim.api.nvim_win_is_valid to always return true for our test
        original_win_is_valid = vim.api.nvim_win_is_valid
        vim.api.nvim_win_is_valid = function() return true end
    end)

    after_each(function()
        -- Restore original function after each test
        vim.api.nvim_win_is_valid = original_win_is_valid
    end)

    it("should update sprite on flag true", function()
        local pet = _G.tamagotchi_pet
        window.last_sprite = "old_sprite"
        window.update_ui(pet, true)
        assert.are_not.equal("old_sprite", window.last_sprite)
    end)

    it("should not update sprite on flag false", function()
        local pet = _G.tamagotchi_pet
        window.last_sprite = "old_sprite"
        window.update_ui(pet, false)
        assert.are.equal("old_sprite", window.last_sprite)
    end)
end)
