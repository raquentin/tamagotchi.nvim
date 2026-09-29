local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("pet initialization", function()
    local pet
    before_each(function()
        config.setup()
        pet = Pet:new({ satiety = 80, mood = 80 })
    end)

    it("should initialize with default values", function()
        assert.are.equal(80, pet:get_satiety())
        assert.are.equal(80, pet:get_mood())
        assert.are.equal(0, pet:get_age())
    end)

    it(
        "stamps the current schema version",
        function() assert.are.equal(Pet.SCHEMA_VERSION, pet.schema_version) end
    )

    -- Epoch seconds now, not vim.loop.now() milliseconds.
    it("uses wall-clock timestamps", function()
        assert.is_true(math.abs(pet.birth_time - os.time()) <= 2)
        assert.is_true(math.abs(pet.last_decay_time - os.time()) <= 2)
    end)
end)

describe("pet constructor", function()
    before_each(function() config.setup() end)

    it("assigns sprites from config when the name is known", function()
        local pet = Pet:new({ name = "Sasha" })
        assert.is_not_nil(pet.sprites)
        assert.is_table(pet.sprites.happy)
        assert.is_true(#pet.sprites.happy > 0)
    end)

    it("inherits vim_events from config too", function()
        local pet = Pet:new({ name = "Sasha" })
        assert.is_table(pet.vim_events)
        assert.is_true(#pet.vim_events > 0)
    end)

    it("warns and uses empty sprites for an unknown name", function()
        local original = vim.notify
        local messages = {}
        vim.notify = function(msg, level)
            table.insert(messages, { msg = msg, level = level })
        end

        local pet = Pet:new({ name = "UnknownPet" })

        vim.notify = original

        assert.are.equal(0, #pet.sprites.happy)
        assert.are.equal(0, #pet.sprites.hungry)
        assert.are.equal(0, #pet.sprites.neutral)
        assert.are.equal(1, #messages)
        assert.are.equal(
            "pet 'UnknownPet' has no sprites! using empty sprite sets.",
            messages[1].msg
        )
        assert.are.equal(vim.log.levels.DEBUG, messages[1].level)
    end)
end)

describe("pet object", function()
    local pet
    before_each(function()
        config.setup()
        pet = Pet:new()
    end)

    it("should allow updating satiety within bounds", function()
        pet:set_satiety(80)
        assert.are.equal(80, pet:get_satiety())

        pet:set_satiety(150)
        assert.are.equal(100, pet:get_satiety())

        pet:set_satiety(-20)
        assert.are.equal(1, pet:get_satiety())
    end)

    it("should allow updating mood within bounds", function()
        pet:set_mood(90)
        assert.are.equal(90, pet:get_mood())

        pet:set_mood(200)
        assert.are.equal(100, pet:get_mood())

        pet:set_mood(0)
        assert.are.equal(1, pet:get_mood())
    end)

    it("ages with wall-clock time", function()
        pet.birth_time = os.time() - 90
        assert.are.equal(90, pet:get_age())
    end)

    it("never reports a negative age", function()
        pet.birth_time = os.time() + 500
        assert.are.equal("0sec", pet:get_age_formatted())
    end)
end)

describe("pet attribute increase", function()
    local pet
    before_each(function()
        config.setup()
        pet = Pet:new({ satiety = 50, mood = 50 })
    end)

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

    -- These are what :Tamagotchi feed/play count; a vim event must not.
    it("does not touch the interaction counters", function()
        pet:increase_mood(10)
        pet:increase_satiety(10)
        assert.are.equal(0, pet.times_fed)
        assert.are.equal(0, pet.times_played_with)
    end)
end)

describe("get_age_formatted", function()
    local pet
    local NOW = 1800000000

    before_each(function()
        config.setup()
        pet = Pet:new()
    end)

    local function at(seconds)
        pet.birth_time = NOW - seconds
        return pet:get_age_formatted(NOW)
    end

    it("formats seconds", function() assert.are.equal("45sec", at(45)) end)

    it("formats minutes", function() assert.are.equal("2min 5sec", at(125)) end)

    it(
        "formats hours",
        function() assert.are.equal("1hr 1min 5sec", at(3665)) end
    )

    it(
        "formats days",
        function() assert.are.equal("1day 0hr 0min 0sec", at(86400)) end
    )

    it(
        "formats years",
        function() assert.are.equal("1yr 0day 0hr 0min 0sec", at(365 * 86400)) end
    )

    it("omits leading zero units", function()
        assert.are.equal("5sec", at(5))
        assert.is_nil(at(5):find("min"))
    end)
end)

describe("pet reset", function()
    before_each(function() config.setup() end)

    it("returns every counter and stat to its starting value", function()
        local pet = Pet.from_def({ name = "Sasha" })
        pet:set_mood(5)
        pet.times_fed = 9
        pet.low_since = os.time()

        pet:reset()

        assert.are.equal(pet.initial_mood, pet:get_mood())
        assert.are.equal(0, pet.times_fed)
        assert.is_nil(pet.low_since)
        assert.is_true(math.abs(pet.birth_time - os.time()) <= 2)
    end)

    -- Clearing the field outright would leave a reset pet grey, since every
    -- native pet ships with a colour.
    it("returns the colour to the pet's default", function()
        local pet = Pet.from_def({ name = "Lucy" })
        pet.color_theme = "cyan"

        pet:reset()

        assert.are.equal("red", pet.color_theme)
    end)
end)

describe("pet colour", function()
    before_each(function() config.setup() end)

    it(
        "comes from the definition",
        function()
            assert.are.equal("red", Pet.from_def({ name = "Lucy" }).color_theme)
        end
    )

    -- Colours resolve from config the same way sprites do, so a save written
    -- before the defaults existed still gets one.
    it("reaches a save that predates the defaults", function()
        local pet = Pet:new({ name = "Lucy", mood = 40 })
        assert.are.equal("red", pet.color_theme)
    end)

    it("does not override one the user picked", function()
        local pet = Pet:new({ name = "Lucy", color_theme = "blue" })
        assert.are.equal("blue", pet.color_theme)
    end)

    it("is a known theme on every native pet", function()
        local themes = {}
        for _, color in ipairs(require("tamagotchi.settings").COLORS) do
            themes[color.name] = true
        end

        for _, def in ipairs(config.values.pets) do
            assert.is_true(
                themes[def.color_theme] or false,
                ("%s has no valid color_theme (%s)"):format(
                    def.name,
                    tostring(def.color_theme)
                )
            )
        end
    end)
end)

describe("transfer_stats_to", function()
    before_each(function() config.setup() end)

    it("carries progress to a different pet", function()
        local from = Pet.from_def({ name = "Sasha" })
        from:set_mood(42)
        from.times_fed = 7
        from.birth_time = os.time() - 5000

        local to = Pet.from_def({ name = "Lucy" })
        from:transfer_stats_to(to)

        assert.are.equal(42, to:get_mood())
        assert.are.equal(7, to.times_fed)
        assert.are.equal(from.birth_time, to.birth_time)
        assert.are.equal("Lucy", to.name)
    end)

    it("carries every interaction counter and cooldown", function()
        local from = Pet.from_def({ name = "Sasha" })
        from.times_petted = 3
        from.times_cleaned = 2
        from.last_interaction = { feed = 123 }
        from.interaction_streak = { feed = 1 }

        local to = Pet.from_def({ name = "Lucy" })
        from:transfer_stats_to(to)

        assert.are.equal(3, to.times_petted)
        assert.are.equal(2, to.times_cleaned)
        assert.are.same({ feed = 123 }, to.last_interaction)
        assert.are.same({ feed = 1 }, to.interaction_streak)
        assert.are_not.equal(from.last_interaction, to.last_interaction)
    end)

    it("does not reset the illness clock", function()
        config.setup({ stakes = true })
        local from = Pet.from_def({ name = "Sasha" })
        from:set_mood(5)
        from.low_since = os.time() - 7 * 3600
        assert.are.equal("sick", from:health_state())

        local to = Pet.from_def({ name = "Lucy" })
        from:transfer_stats_to(to)

        assert.are.equal("sick", to:health_state())
    end)

    it("keeps a dead pet dead", function()
        config.setup({ stakes = true })
        local from = Pet.from_def({ name = "Sasha" })
        from.died_at = os.time() - 60

        local to = Pet.from_def({ name = "Lucy" })
        from:transfer_stats_to(to)

        assert.is_true(to:is_dead())
    end)
end)
