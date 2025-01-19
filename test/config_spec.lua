local config = require("tamagotchi.config")
local assert = require("luassert")
local kitty_sprites = require("tamagotchi.sprites.kitty")

describe("keybind configuration", function()
    it("should use default config when no user config is provided", function()
        config.setup()
        assert.are.equal("<leader>tg", config.values.keybind)
    end)

    it("should override default config with user values", function()
        config.setup({ keybind = "<leader>xx" })
        assert.are.equal("<leader>xx", config.values.keybind)
    end)
end)

describe("configuration with multiple pets", function()
    it("should have a default list of pets", function()
        config.setup()
        assert.is_table(config.values.pets)
        assert.is_true(#config.values.pets >= 1)
        local first_pet = config.values.pets[1]
        assert.are.equal("Kitty", first_pet.name)
        assert.is_table(first_pet.sprites)
    end)

    it("should merge user and native pets, then sort", function()
        local user_pets = {
            {
                name = "Spike",
                tick_length_ms = 100,
                sprite_update_interval = 5,
                sprites = {
                    happy = { ">:)", ">:-)" },
                    hungry = { ">:(", ">:'(" },
                    neutral = { ">:|", ">-_|" },
                },
                native = false,
            },
            {
                name = "Fluffy",
                tick_length_ms = 100,
                sprite_update_interval = 5,
                sprites = {
                    happy = { ":)", ":-D" },
                    hungry = { ":(", ":'(" },
                    neutral = { ":|", "-_-" },
                },
                native = false,
            },
        }
        config.setup({ pets = user_pets })

        local expected_pets = {
            {
                name = "Fluffy",
                tick_length_ms = 100,
                sprite_update_interval = 5,
                sprites = {
                    happy = { ":)", ":-D" },
                    hungry = { ":(", ":'(" },
                    neutral = { ":|", "-_-" },
                },
                native = false,
            },
            {
                name = "Kitty",
                tick_length_ms = 100,
                sprite_update_interval = 5,
                sprites = kitty_sprites,
                mood_decay_probability = 0.02,
                satiety_decay_probability = 0.02,
                initial_mood = 80,
                initial_satiety = 80,
                native = true,
            },
            {
                name = "Spike",
                tick_length_ms = 100,
                sprite_update_interval = 5,
                sprites = {
                    happy = { ">:)", ">:-)" },
                    hungry = { ">:(", ">:'(" },
                    neutral = { ">:|", ">-_|" },
                },
                native = false,
            },
        }

        assert.are.same(expected_pets, config.values.pets)
    end)
end)
