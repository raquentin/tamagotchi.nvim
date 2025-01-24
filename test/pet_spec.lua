local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("pet initialization", function()
    local pet
    before_each(function()
        config.setup() -- Initialize configuration with defaults
        pet = Pet:new({ satiety = 80, mood = 80 })
    end)

    it("should initialize with default values", function()
        assert.are.equal(80, pet:get_satiety())
        assert.are.equal(80, pet:get_mood())
        local age = pet:get_age()
        assert.is_true(age >= 0 and age < 100) -- should take less than 100ms
    end)
end)

describe("pet constructor", function()
    before_each(function()
        -- initialize configuration with default pets
        config.setup()
    end)

    it(
        "assigns sprites based on pet name without warning when sprites are defined",
        function()
            -- create a pet with a name that has sprites defined in config
            local pet = Pet:new({ name = "Ilya" })

            -- check that sprites are correctly assigned
            assert.is_not_nil(pet.sprites)
            assert.is_table(pet.sprites.happy)
            assert.are.equal(2, #pet.sprites.happy)
        end
    )

    it(
        "assigns empty sprites and warns when pet name has no sprites defined",
        function()
            -- capture the original vim.notify function
            local original_notify = vim.notify
            local notify_messages = {}
            vim.notify = function(msg, level)
                table.insert(notify_messages, { msg = msg, level = level })
            end

            -- create a pet with a name that has no sprites defined in config
            local pet = Pet:new({ name = "UnknownPet" })

            -- check that sprites are empty
            assert.is_table(pet.sprites)
            assert.are.equal(0, #pet.sprites.happy)
            assert.are.equal(0, #pet.sprites.hungry)
            assert.are.equal(0, #pet.sprites.neutral)

            assert.are.equal(1, #notify_messages)
            assert.are.equal(
                "Pet UnknownPet has no sprites and no default sprites found! Using empty sprite sets.",
                notify_messages[1].msg
            )
            assert.are.equal(vim.log.levels.DEBUG, notify_messages[1].level)

            -- restore the original vim.notify function
            vim.notify = original_notify
        end
    )
end)

describe("pet object", function()
    local pet

    before_each(function() pet = Pet:new() end)

    it("should allow updating satiety within bounds", function()
        pet:set_satiety(80)
        assert.are.equal(80, pet:get_satiety())

        pet:set_satiety(150) -- above max
        assert.are.equal(100, pet:get_satiety())

        pet:set_satiety(-20) -- below min
        assert.are.equal(1, pet:get_satiety())
    end)

    it("should allow updating mood within bounds", function()
        pet:set_mood(90)
        assert.are.equal(90, pet:get_mood())

        pet:set_mood(200) -- above max
        assert.are.equal(100, pet:get_mood())

        pet:set_mood(0) -- below min
        assert.are.equal(1, pet:get_mood())
    end)

    it("should calculate increasing age over time", function()
        local initial_age = pet:get_age()
        pet.birth_time = pet.birth_time
        local new_age = pet:get_age()
        assert.is_true(new_age >= initial_age)
    end)
end)

describe("pet attribute increase", function()
    local pet
    before_each(function() pet = Pet:new({ satiety = 50, mood = 50 }) end)

    it("should increase mood", function()
        pet:increase_mood(10)
        assert.are.equal(60, pet:get_mood())
    end)

    it("should not exceed 100 mood", function()
        pet:set_mood(95)
        pet:increase_mood(10)
        assert.are.equal(100, pet:get_mood())
    end)

    it("should increase satiety", function()
        pet:increase_satiety(5)
        assert.are.equal(55, pet:get_satiety())
    end)

    it("should not exceed 100 satiety", function()
        pet:set_satiety(98)
        pet:increase_satiety(5)
        assert.are.equal(100, pet:get_satiety())
    end)
end)

describe("pet update randomness", function()
    local pet
    before_each(function()
        -- Initialize configuration with defaults
        config.setup()

        math.randomseed(123)
        pet = Pet:new()
    end)

    it("should not increase attributes during update", function()
        local initial_satiety = pet:get_satiety()
        local initial_mood = pet:get_mood()
        pet:update()
        assert.is_true(pet:get_satiety() <= initial_satiety)
        assert.is_true(pet:get_mood() <= initial_mood)
    end)
end)
describe("pet age formatting", function()
    local current_time

    before_each(function() current_time = vim.loop.now() end)

    it("formats only seconds when less than a minute has passed", function()
        local pet = Pet:new({ birth_time = current_time - (30 * 1000) })
        local formatted = pet:get_age_formatted()
        assert.are.equal("30sec", formatted)
    end)

    it(
        "formats minutes and seconds when less than an hour has passed",
        function()
            local pet =
                Pet:new({ birth_time = current_time - ((2 * 60 + 15) * 1000) })
            local formatted = pet:get_age_formatted()
            -- Since hours is 0, it should omit hour part: "2min 15sec"
            assert.are.equal("2min 15sec", formatted)
        end
    )

    it("formats hours, minutes and seconds correctly", function()
        local pet = Pet:new({ birth_time = current_time - (3661 * 1000) })
        local formatted = pet:get_age_formatted()
        assert.are.equal("1hr 1min 1sec", formatted)
    end)

    it("omits leading zeros for hours if zero", function()
        local pet =
            Pet:new({ birth_time = current_time - ((59 * 60 + 30) * 1000) })
        local formatted = pet:get_age_formatted()
        assert.are.equal("59min 30sec", formatted)
    end)

    it("formats days, hours, minutes and seconds correctly", function()
        local seconds = (1 * 24 * 3600) + (2 * 3600) + (3 * 60) + 4
        local pet = Pet:new({ birth_time = current_time - (seconds * 1000) })
        local formatted = pet:get_age_formatted()
        assert.are.equal("1day 2hr 3min 4sec", formatted)
    end)

    it("formats years, days, hours, minutes and seconds correctly", function()
        local seconds = (2 * 365 * 24 * 3600)
            + (5 * 24 * 3600)
            + (3 * 3600)
            + (10 * 60)
            + 20
        local pet = Pet:new({ birth_time = current_time - (seconds * 1000) })
        local formatted = pet:get_age_formatted()
        assert.are.equal("2yr 5day 3hr 10min 20sec", formatted)
    end)

    it("omits all larger units if they are zero", function()
        local pet = Pet:new({ birth_time = current_time })
        local formatted = pet:get_age_formatted()
        assert.are.equal("0sec", formatted)
    end)
end)
