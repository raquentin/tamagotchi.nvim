local window = require("tamagotchi.window")
local assert = require("luassert")

describe("window toggle functionality", function()
    it("should open a window when toggled the first time", function()
        local result = window.toggle()
        assert.is_table(result)
        assert.is_number(result.buf)
        assert.is_number(result.win)
    end)

    it("should close the window when toggled again", function()
        local result = window.toggle()
        assert.is_nil(result)
        assert.is_nil(window.current)
    end)
end)
