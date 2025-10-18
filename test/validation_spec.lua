local config = require("tamagotchi.config")
local Pet = require("tamagotchi.pet")
local assert = require("luassert")

describe("input validation", function()
    before_each(function() config.setup() end)

    describe("Pet setters", function()
        local pet

        before_each(
            function()
                pet = Pet:new({ name = "TestPet", mood = 50, satiety = 50 })
            end
        )

        it("set_name validates string type", function()
            assert.has_error(
                function() pet:set_name(123) end,
                "name must be a string"
            )
        end)

        it("set_name validates non-empty string", function()
            assert.has_error(
                function() pet:set_name("") end,
                "name cannot be empty"
            )
        end)

        it("set_mood validates number type", function()
            assert.has_error(
                function() pet:set_mood("not a number") end,
                "mood must be a number"
            )
        end)

        it("set_satiety validates number type", function()
            assert.has_error(
                function() pet:set_satiety("not a number") end,
                "satiety must be a number"
            )
        end)

        it("increase_mood validates number type", function()
            assert.has_error(
                function() pet:increase_mood("not a number") end,
                "amount must be a number"
            )
        end)

        it("increase_mood validates non-negative", function()
            assert.has_error(
                function() pet:increase_mood(-5) end,
                "amount must be non-negative"
            )
        end)

        it("increase_satiety validates number type", function()
            assert.has_error(
                function() pet:increase_satiety("not a number") end,
                "amount must be a number"
            )
        end)

        it("increase_satiety validates non-negative", function()
            assert.has_error(
                function() pet:increase_satiety(-5) end,
                "amount must be non-negative"
            )
        end)
    end)

    describe("Config validation", function()
        it("validates pet name is present", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            { sprites = {}, vim_events = {} },
                        },
                    })
                end
            )
        end)

        it("validates pet name is non-empty", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            { name = "", sprites = {}, vim_events = {} },
                        },
                    })
                end
            )
        end)

        it("validates vim_events is a table when provided", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            { name = "TestPet", vim_events = "not a table" },
                        },
                    })
                end
            )
        end)

        it("validates vim event has name", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            {
                                name = "TestPet",
                                vim_events = {
                                    {
                                        mood_increment = 10,
                                        satiety_increment = 5,
                                    },
                                },
                            },
                        },
                    })
                end
            )
        end)

        it("validates vim event has mood_increment", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            {
                                name = "TestPet",
                                vim_events = {
                                    {
                                        name = "BufWritePost",
                                        satiety_increment = 5,
                                    },
                                },
                            },
                        },
                    })
                end
            )
        end)

        it("validates vim event has satiety_increment", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            {
                                name = "TestPet",
                                vim_events = {
                                    {
                                        name = "BufWritePost",
                                        mood_increment = 10,
                                    },
                                },
                            },
                        },
                    })
                end
            )
        end)

        it("validates initial_mood range when provided", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            { name = "TestPet", initial_mood = 150 },
                        },
                    })
                end
            )
        end)

        it("validates initial_satiety range when provided", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            { name = "TestPet", initial_satiety = 0 },
                        },
                    })
                end
            )
        end)

        it("validates decay_speed range when provided", function()
            assert.has_error(
                function()
                    config.setup({
                        pets = {
                            { name = "TestPet", decay_speed = 10 },
                        },
                    })
                end
            )
        end)

        it("accepts valid pet configuration", function()
            assert.has_no.errors(
                function()
                    config.setup({
                        pets = {
                            {
                                name = "ValidPet",
                                initial_mood = 80,
                                initial_satiety = 80,
                                decay_speed = 3,
                                vim_events = {
                                    {
                                        name = "BufWritePost",
                                        mood_increment = 10,
                                        satiety_increment = 5,
                                    },
                                },
                            },
                        },
                    })
                end
            )
        end)
    end)
end)
