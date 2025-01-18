local config = require("tamagotchi.config")
local assert = require("luassert")

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
        assert.are.equal("Tamagotchi", first_pet.name)
        assert.is_table(first_pet.sprites)
    end)

    it("should allow user-defined pets to override defaults", function()
        local user_pets = {
            {
                name = "Fluffy",
                sprites = {
                    happy = { ":)", ":-D" },
                    hungry = { ":(", ":'(" },
                    neutral = { ":|", "-_-" },
                },
            },
            {
                name = "Spike",
                sprites = {
                    happy = { ">:)", ">:-)" },
                    hungry = { ">:(", ">:'(" },
                    neutral = { ">:|", ">-_|" },
                },
            },
        }
        config.setup({ pets = user_pets })

        -- TODO: not redefine here
        -- TODO: alphabetize pets everywhere
        local expected_pets = {
            {
                name = "Tamagotchi",
                sprites = {
                    happy = { " ^_^ ", " (^-^) " },
                    hungry = { " >_< ", " (U_U) " },
                    neutral = { " -_- ", " (._.) " },
                },
            },
            {
                name = "Fluffy",
                sprites = {
                    happy = { ":)", ":-D" },
                    hungry = { ":(", ":'(" },
                    neutral = { ":|", "-_-" },
                },
            },
            {
                name = "Spike",
                sprites = {
                    happy = { ">:)", ">:-)" },
                    hungry = { ">:(", ">:'(" },
                    neutral = { ">:|", ">-_|" },
                },
            },
        }

        assert.are.same(expected_pets, config.values.pets)
    end)
end)
