local event_handler = require("tamagotchi.event_handler")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("event_handler", function()
    before_each(function() config.setup() end)

    after_each(function() _G.tamagotchi_pet = nil end)

    describe("on_event validation", function()
        it("should validate event_name is a string", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            assert.has_error(
                function() event_handler.on_event(123, 10, 10) end,
                "event_name must be a string"
            )
        end)

        it("should validate mood_inc is a number", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            assert.has_error(
                function()
                    event_handler.on_event("TestEvent", "not a number", 10)
                end,
                "mood_inc must be a number"
            )
        end)

        it("should validate sat_inc is a number", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            assert.has_error(
                function()
                    event_handler.on_event("TestEvent", 10, "not a number")
                end,
                "sat_inc must be a number"
            )
        end)
    end)

    describe("on_event behavior", function()
        it("should handle missing pet gracefully", function()
            _G.tamagotchi_pet = nil
            -- Should not error
            assert.has_no.errors(
                function() event_handler.on_event("TestEvent", 10, 10) end
            )
        end)

        it("should increase mood when mood_inc is positive", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            local initial_mood = _G.tamagotchi_pet:get_mood()

            event_handler.on_event("TestEvent", 10, 0)

            assert.are.equal(initial_mood + 10, _G.tamagotchi_pet:get_mood())
        end)

        it("should increase satiety when sat_inc is positive", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            local initial_satiety = _G.tamagotchi_pet:get_satiety()

            event_handler.on_event("TestEvent", 0, 15)

            assert.are.equal(
                initial_satiety + 15,
                _G.tamagotchi_pet:get_satiety()
            )
        end)

        it("should handle both mood and satiety increments", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            local initial_mood = _G.tamagotchi_pet:get_mood()
            local initial_satiety = _G.tamagotchi_pet:get_satiety()

            event_handler.on_event("TestEvent", 10, 20)

            assert.are.equal(initial_mood + 10, _G.tamagotchi_pet:get_mood())
            assert.are.equal(
                initial_satiety + 20,
                _G.tamagotchi_pet:get_satiety()
            )
        end)

        it("should decrease mood when mood_inc is negative", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            local initial_mood = _G.tamagotchi_pet:get_mood()

            event_handler.on_event("TestEvent", -5, 0)

            assert.are.equal(initial_mood - 5, _G.tamagotchi_pet:get_mood())
        end)

        it("should decrease satiety when sat_inc is negative", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            local initial_satiety = _G.tamagotchi_pet:get_satiety()

            event_handler.on_event("TestEvent", 0, -10)

            assert.are.equal(
                initial_satiety - 10,
                _G.tamagotchi_pet:get_satiety()
            )
        end)

        it("should respect mood bounds (max 100)", function()
            _G.tamagotchi_pet = Pet:new({ mood = 95, satiety = 50 })

            event_handler.on_event("TestEvent", 20, 0)

            assert.are.equal(100, _G.tamagotchi_pet:get_mood())
        end)

        it("should respect mood bounds (min 1)", function()
            _G.tamagotchi_pet = Pet:new({ mood = 5, satiety = 50 })

            event_handler.on_event("TestEvent", -10, 0)

            assert.are.equal(1, _G.tamagotchi_pet:get_mood())
        end)

        it("should respect satiety bounds (max 100)", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 98 })

            event_handler.on_event("TestEvent", 0, 10)

            assert.are.equal(100, _G.tamagotchi_pet:get_satiety())
        end)

        it("should respect satiety bounds (min 1)", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 3 })

            event_handler.on_event("TestEvent", 0, -10)

            assert.are.equal(1, _G.tamagotchi_pet:get_satiety())
        end)

        it("should do nothing when both increments are 0", function()
            _G.tamagotchi_pet = Pet:new({ mood = 50, satiety = 50 })
            local initial_mood = _G.tamagotchi_pet:get_mood()
            local initial_satiety = _G.tamagotchi_pet:get_satiety()

            event_handler.on_event("TestEvent", 0, 0)

            assert.are.equal(initial_mood, _G.tamagotchi_pet:get_mood())
            assert.are.equal(initial_satiety, _G.tamagotchi_pet:get_satiety())
        end)
    end)
end)
