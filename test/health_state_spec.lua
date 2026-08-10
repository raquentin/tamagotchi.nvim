local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("illness and death", function()
    local T0 = 1800000000
    local pet

    local function fresh()
        local p = Pet.from_def({ name = "Sasha" })
        p.last_decay_time = T0
        return p
    end

    describe("with stakes disabled (the default)", function()
        before_each(function()
            config.setup()
            pet = fresh()
        end)

        it(
            "is off unless asked for",
            function() assert.is_false(config.values.stakes) end
        )

        -- Turning permadeath on for everyone in an update would quietly kill
        -- pets people have kept for months.
        it("never kills a pet, however long it is neglected", function()
            pet:set_mood(1)
            pet:set_satiety(1)
            pet.low_since = T0 - 365 * 86400

            assert.are.equal("alive", pet:health_state(T0))
        end)
    end)

    describe("with stakes enabled", function()
        before_each(function()
            config.setup({ stakes = true })
            pet = fresh()
        end)

        it(
            "is alive while stats are healthy",
            function() assert.are.equal("alive", pet:health_state(T0)) end
        )

        it("is alive before the illness threshold", function()
            pet.low_since = T0 - 3600
            assert.are.equal("alive", pet:health_state(T0))
        end)

        it("sickens after the illness threshold", function()
            pet.low_since = T0 - 7 * 3600
            assert.are.equal("sick", pet:health_state(T0))
        end)

        it("dies after the death threshold", function()
            pet.low_since = T0 - 25 * 3600
            assert.are.equal("dead", pet:health_state(T0))
        end)

        it("honours configured thresholds", function()
            config.setup({
                stakes = true,
                sick_after_seconds = 10,
                death_after_seconds = 20,
            })
            pet.low_since = T0 - 15
            assert.are.equal("sick", pet:health_state(T0))
        end)

        describe("the neglect clock", function()
            it("starts when a stat bottoms out", function()
                pet:set_satiety(Pet.LOW_STAT)
                pet:apply_decay(T0 + 1)
                assert.is_not_nil(pet.low_since)
            end)

            it("does not start while stats are healthy", function()
                pet:apply_decay(T0 + 1)
                assert.is_nil(pet.low_since)
            end)

            -- Elapsed-based, so it behaves the same whether Neovim stayed open.
            it("clears as soon as the pet recovers", function()
                pet:set_satiety(Pet.LOW_STAT)
                pet:apply_decay(T0 + 1)
                assert.is_not_nil(pet.low_since)

                pet:set_satiety(80)
                pet:set_mood(80)
                pet:apply_decay(T0 + 2)
                assert.is_nil(pet.low_since)
            end)
        end)

        it("stops decaying once dead", function()
            pet.low_since = T0 - 25 * 3600
            pet:set_mood(50)

            pet:apply_decay(T0 + 100000)

            assert.are.equal(50, pet:get_mood())
        end)

        it("records the time of death", function()
            pet.low_since = T0 - 25 * 3600
            pet:apply_decay(T0 + 1)
            assert.is_not_nil(pet.died_at)
        end)

        it("stays dead across a save and load", function()
            pet.low_since = T0 - 25 * 3600
            pet:apply_decay(T0 + 1)

            local reloaded = Pet:new(pet:to_table())
            assert.are.equal("dead", reloaded:health_state(T0 + 2))
        end)

        it("shows a distinct sprite when dead", function()
            pet.low_since = T0 - 25 * 3600
            pet:apply_decay(T0 + 1)
            assert.is_truthy(pet:peek_sprite():find("R.I.P", 1, true))
        end)

        -- No built-in set defines sick/dead frames, and no user set will.
        it("falls back to shared frames for sick and dead", function()
            assert.is_true(#pet:frames_for("sick") > 0)
            assert.is_true(#pet:frames_for("dead") > 0)
        end)

        describe("revive", function()
            before_each(function()
                pet.low_since = T0 - 25 * 3600
                pet:apply_decay(T0 + 1)
            end)

            it("brings the pet back", function()
                pet:revive(T0 + 2)
                assert.are.equal("alive", pet:health_state(T0 + 2))
            end)

            it("restores initial stats and clears the clock", function()
                pet:revive(T0 + 2)
                assert.are.equal(pet.initial_mood, pet:get_mood())
                assert.is_nil(pet.low_since)
                assert.is_nil(pet.died_at)
            end)

            it("resumes decaying", function()
                pet:revive(T0 + 2)
                pet:apply_decay(T0 + 202)
                assert.is_true(pet:get_mood() < pet.initial_mood)
            end)
        end)
    end)
end)
