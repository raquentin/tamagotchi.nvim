local Pet = require("tamagotchi.pet")
local assert = require("luassert")

describe("pet object", function()
    local pet

    before_each(function() pet = Pet:new() end)

    it("should initialize with default values", function()
        assert.are.equal(50, pet:get_hunger())
        assert.are.equal(50, pet:get_happiness())
        assert.are.equal(0, pet:get_age())
    end)

    it("should allow updating hunger within bounds", function()
        pet:set_hunger(80)
        assert.are.equal(80, pet:get_hunger())

        pet:set_hunger(150) -- above max
        assert.are.equal(100, pet:get_hunger())

        pet:set_hunger(-20) -- below min
        assert.are.equal(1, pet:get_hunger())
    end)

    it("should allow updating happiness within bounds", function()
        pet:set_happiness(90)
        assert.are.equal(90, pet:get_happiness())

        pet:set_happiness(200) -- above max
        assert.are.equal(100, pet:get_happiness())

        pet:set_happiness(0) -- below min
        assert.are.equal(1, pet:get_happiness())
    end)

    it("should allow updating age within bounds", function()
        pet:set_age(90)
        assert.are.equal(90, pet:get_age())

        pet:set_age(-1) -- below min
        assert.are.equal(0, pet:get_age())
    end)
end)
