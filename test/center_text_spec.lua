local assert = require("luassert")
local window = require("tamagotchi.window")

describe("center_text", function()
    it("truncates text when width is less than text length", function()
        local result = window.center_text("Hello", 3)
        assert.are.equal("Hel", result)
    end)

    it("returns the same text when width equals text length", function()
        local result = window.center_text("Hello", 5)
        assert.are.equal("Hello", result)
    end)

    it(
        "centers text correctly when width is greater than text length (even extra spaces)",
        function()
            local result = window.center_text("Hi", 6)
            assert.are.equal("  Hi  ", result)
        end
    )

    it(
        "centers text correctly when width is greater than text length (odd extra spaces)",
        function()
            local result = window.center_text("Hi", 7)
            assert.are.equal("  Hi   ", result)
        end
    )

    it("handles truncation when text is longer than width", function()
        local result = window.center_text("Hello World", 5)
        assert.are.equal("Hello", result)
    end)
end)
