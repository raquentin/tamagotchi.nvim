local actions = require("tamagotchi.actions")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("interaction verbs", function()
    local T0 = 1800000000
    local pet

    before_each(function()
        config.setup()
        pet = Pet.from_def({ name = "Sasha" })
        pet:set_mood(50)
        pet:set_satiety(50)
        pet.last_decay_time = T0
    end)

    it("feeding raises satiety", function()
        local ok = actions.interact(pet, "feed", T0)
        assert.is_true(ok)
        assert.is_true(pet:get_satiety() > 50)
    end)

    it("playing raises mood but costs satiety", function()
        actions.interact(pet, "play", T0)
        assert.is_true(pet:get_mood() > 50)
        assert.is_true(pet:get_satiety() < 50)
    end)

    it(
        "rejects an unknown verb",
        function() assert.is_false(actions.interact(pet, "juggle", T0)) end
    )

    it(
        "rejects a nil pet",
        function() assert.is_false(actions.interact(nil, "feed", T0)) end
    )

    -- v1 bumped times_fed inside increase_satiety and times_played_with inside
    -- increase_mood, so every BufWritePost incremented both.
    it("counts each verb separately", function()
        actions.interact(pet, "feed", T0)
        assert.are.equal(1, pet.times_fed)
        assert.are.equal(0, pet.times_played_with)

        actions.interact(pet, "play", T0)
        assert.are.equal(1, pet.times_fed)
        assert.are.equal(1, pet.times_played_with)
    end)

    describe("cooldowns", function()
        it("blocks a repeat inside the cooldown", function()
            assert.is_true(actions.interact(pet, "feed", T0))
            local ok, msg = actions.interact(pet, "feed", T0 + 10)
            assert.is_false(ok)
            assert.is_truthy(msg:find("not hungry"))
        end)

        it("allows a repeat once the cooldown passes", function()
            actions.interact(pet, "feed", T0)
            assert.is_true(actions.interact(pet, "feed", T0 + 301))
        end)

        it("does not count a blocked attempt", function()
            actions.interact(pet, "feed", T0)
            actions.interact(pet, "feed", T0 + 10)
            assert.are.equal(1, pet.times_fed)
        end)

        it("tracks cooldowns per verb", function()
            actions.interact(pet, "feed", T0)
            assert.is_true(actions.interact(pet, "play", T0))
        end)

        -- Persisted as epoch seconds, so a restart cannot reset a cooldown.
        it("survives a save and load round trip", function()
            actions.interact(pet, "feed", T0)
            local reloaded = Pet:new(pet:to_table())
            assert.are.equal(T0, reloaded.last_interaction.feed)
        end)
    end)

    describe("diminishing returns", function()
        it(
            "gives full effect on the first use",
            function() assert.are.equal(1, actions.scale_for(0)) end
        )

        it("shrinks with each repeat", function()
            assert.is_true(actions.scale_for(1) < actions.scale_for(0))
            assert.is_true(actions.scale_for(2) < actions.scale_for(1))
        end)

        it(
            "never falls to zero",
            function() assert.is_true(actions.scale_for(50) > 0) end
        )

        it("means repeated feeding cannot pin satiety at max", function()
            pet:set_satiety(50)
            local t = T0
            for _ = 1, 3 do
                actions.interact(pet, "feed", t)
                t = t + 301
            end
            assert.is_true(pet:get_satiety() < Pet.MAX_STAT)
        end)

        it("resets after a long enough gap", function()
            actions.interact(pet, "feed", T0)
            actions.interact(pet, "feed", T0 + 301)
            assert.are.equal(1, pet.interaction_streak.feed)

            actions.interact(pet, "feed", T0 + 301 + 5000)
            assert.are.equal(0, pet.interaction_streak.feed)
        end)
    end)

    describe("with stakes enabled", function()
        before_each(function() config.setup({ stakes = true }) end)

        it("refuses to interact with a dead pet", function()
            pet.low_since = T0 - 48 * 3600
            local ok, msg = actions.interact(pet, "feed", T0)
            assert.is_false(ok)
            assert.is_truthy(msg:find("revive"))
        end)

        it("clears the illness clock when the pet recovers", function()
            pet:set_satiety(5)
            pet.low_since = T0 - 100

            actions.interact(pet, "feed", T0)

            assert.is_nil(pet.low_since)
        end)
    end)
end)
