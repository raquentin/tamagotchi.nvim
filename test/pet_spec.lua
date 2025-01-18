local Pet = require("tamagotchi.pet")
local assert = require("luassert")

describe("pet object", function()
    local pet

    before_each(function() pet = Pet:new() end)

    it("should initialize with default values", function()
        assert.are.equal(80, pet:get_satiety())
        assert.are.equal(80, pet:get_mood())
        local age = pet:get_age()
        assert.is_true(age >= 0 and age < 100) -- should take less than 100ms
    end)

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
