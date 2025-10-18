local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("window module", function()
    before_each(function() config.setup() end)

    describe("center_text", function()
        it("validates text is a string", function()
            assert.has_error(
                function() window.center_text(123, 10) end,
                "text must be a string"
            )
        end)

        it("validates width is a positive number", function()
            assert.has_error(
                function() window.center_text("test", "not a number") end,
                "width must be a positive number"
            )
        end)

        it("validates width is positive", function()
            assert.has_error(
                function() window.center_text("test", 0) end,
                "width must be a positive number"
            )
        end)

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

        it("handles empty string", function()
            local result = window.center_text("", 5)
            assert.are.equal("     ", result)
        end)
    end)

    describe("get_current_pet", function()
        it("returns nil when no pet is open", function()
            window.current_pet = nil
            assert.is_nil(window.get_current_pet())
        end)

        it("returns the current pet when set", function()
            local pet = Pet:new({ name = "TestPet", mood = 50, satiety = 50 })
            window.current_pet = pet
            assert.are.equal(pet, window.get_current_pet())
        end)
    end)

    describe("open", function()
        it("validates pet is provided", function()
            assert.has_error(function() window.open(nil) end, "pet is required")
        end)

        it("validates pet is a table", function()
            assert.has_error(
                function() window.open("not a pet") end,
                "pet must be a table"
            )
        end)

        it("validates pet has required methods", function()
            assert.has_error(function() window.open({}) end)
        end)
    end)

    describe("close", function()
        it("handles closing when no window is open", function()
            window.current_window = nil
            assert.has_no.errors(function() window.close(nil) end)
        end)

        it("stops the refresh timer if it exists", function()
            -- Create a dummy timer
            window.refresh_timer = vim.loop.new_timer()
            window.refresh_timer:start(1000, 0, function() end)

            window.close(nil)

            assert.is_nil(window.refresh_timer)
        end)
    end)

    describe("toggle", function()
        after_each(function()
            -- Clean up any open windows
            if
                window.current_window
                and vim.api.nvim_win_is_valid(window.current_window.win)
            then
                window.close(nil)
            end
        end)

        it("opens window when closed", function()
            window.current_window = nil
            local pet = Pet:new({ name = "TestPet", mood = 80, satiety = 80 })

            local result = window.toggle(pet)

            assert.is_not_nil(result)
            assert.is_not_nil(window.current_window)

            -- Clean up
            window.close(pet)
        end)

        it("closes window when open", function()
            local pet = Pet:new({ name = "TestPet", mood = 80, satiety = 80 })
            window.open(pet)

            local result = window.toggle(pet)

            assert.is_nil(result)
            assert.is_nil(window.current_window)
        end)
    end)
end)
