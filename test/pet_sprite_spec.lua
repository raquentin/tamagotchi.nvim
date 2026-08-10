local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("pet sprite selection", function()
    local test_pet_def

    before_each(function()
        config.setup({
            pets = {
                {
                    name = "Test Pet",
                    sprites = {
                        happy = { ":)", ":-D" },
                        hungry = { ":(", ":'(" },
                        neutral = { ":|", "-_-" },
                    },
                },
            },
        })

        -- find the pet definition for "Test Pet" in the configuration
        for _, pet_def in ipairs(config.values.pets) do
            if pet_def.name == "Test Pet" then
                test_pet_def = pet_def
                break
            end
        end
        assert.is_not_nil(test_pet_def)
    end)

    it("should return happy sprite if mood > 70", function()
        local pet = Pet:new({
            mood = 80,
            satiety = 80,
            sprites = test_pet_def.sprites,
        })
        local sprite = pet:get_sprite()
        assert.is_true(sprite == ":)" or sprite == ":-D")
    end)

    it("should return neutral sprite if satiety > 70 and mood <= 70", function()
        local pet = Pet:new({
            mood = 50,
            satiety = 80,
            sprites = test_pet_def.sprites,
        })
        local sprite = pet:get_sprite()
        assert.is_true(sprite == ":|" or sprite == "-_-")
    end)

    it("should return hungry sprite if satiety is low", function()
        local pet = Pet:new({
            mood = 80,
            satiety = 50,
            sprites = test_pet_def.sprites,
        })
        local sprite = pet:get_sprite()
        assert.are.equal(":(", sprite)
    end)
end)

describe("pet sprite cycling and state reset", function()
    local test_pet_def

    before_each(function()
        config.setup({
            pets = {
                {
                    name = "Test Pet",
                    sprites = {
                        happy = { "happy1", "happy2" },
                        hungry = { "hungry1", "hungry2" },
                        neutral = { "neutral1", "neutral2" },
                    },
                },
            },
        })

        -- find the pet definition for "Test Pet"
        for _, pet_def in ipairs(config.values.pets) do
            if pet_def.name == "Test Pet" then
                test_pet_def = pet_def
                break
            end
        end
        assert.is_not_nil(test_pet_def)
    end)

    it("should cycle through happy sprites when mood > 70", function()
        local pet = Pet:new({
            mood = 80,
            satiety = 80,
            sprites = test_pet_def.sprites,
        })

        -- initialize last_state to force reset on first get_sprite
        pet.last_state = nil
        pet.sprite_indices.happy = 1

        local first_sprite = pet:get_sprite()
        local second_sprite = pet:get_sprite()

        assert.are_not.equal(first_sprite, second_sprite)
        assert.are.equal("happy2", second_sprite)
    end)

    it("should reset sprite index on state change", function()
        local pet = Pet:new({
            mood = 80,
            satiety = 80,
            sprites = test_pet_def.sprites,
        })
        pet.last_state = nil

        -- cycle once to be in happy state
        pet:get_sprite()

        -- change state: lower mood to switch sprite set
        pet.mood = 50
        local neutral_sprite = pet:get_sprite()

        -- after state change, sprite index for 'neutral' should reset to first sprite
        assert.are.equal("neutral1", neutral_sprite)
    end)
end)
