local window = require("tamagotchi.window")
local assert = require("luassert")

-- minimal mock pet that implements the methods window.lua needs
local mock_pet = {
    get_name = function() return "Mock Name" end,
    get_sprite = function() return "mock_sprite" end,
    get_age = function() return 0 end,
    get_satiety = function() return 50 end,
    get_mood = function() return 50 end,
    update = function() end,
}

describe("window toggle functionality", function()
    it("should open a window when toggled the first time", function()
        local result = window.toggle(mock_pet)
        assert.is_table(result)
        assert.is_number(result.buf)
        assert.is_number(result.win)
    end)

    it("should close the window when toggled again", function()
        local result = window.toggle(mock_pet)
        assert.is_nil(result)
        assert.is_nil(window.current)
    end)
end)
