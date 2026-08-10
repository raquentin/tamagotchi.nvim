local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

-- v1 persisted vim.loop.now() -- monotonic milliseconds since boot -- as if it
-- were wall-clock, then compared it against a fresh process's clock.
describe("v1 save migration", function()
    before_each(function() config.setup() end)

    local function v1_save(overrides)
        local data = {
            name = "Lucy",
            mood = 63,
            satiety = 58,
            birth_time = 120000, -- uv.now() values: small, boot-relative
            last_vim_close_time = 7320000,
            last_window_close_time = 7300000,
            session_start_time = 120000,
            decay_speed = 3,
            initial_mood = 70,
            initial_satiety = 80,
            mood_decay_probability = 0.05,
            native = true,
            sprites = { happy = { "STALE" }, hungry = {}, neutral = {} },
        }
        for k, v in pairs(overrides or {}) do
            data[k] = v
        end
        return data
    end

    it("stamps the current schema version", function()
        local out = Pet.migrate(v1_save())
        assert.are.equal(Pet.SCHEMA_VERSION, out.schema_version)
    end)

    it("passes an already-migrated save through untouched", function()
        local v2 =
            { name = "Lucy", mood = 42, schema_version = Pet.SCHEMA_VERSION }
        local out = Pet.migrate(v2)
        assert.are.equal(42, out.mood)
        assert.are.equal(v2, out)
    end)

    -- The exact regression: elapsed went negative, and the raw write at
    -- pet.lua:304 subtracted a negative, inflating mood without bound.
    it("never inflates mood when loading a v1 save", function()
        local pet = Pet:new(Pet.migrate(v1_save()))
        pet:apply_decay()
        assert.is_true(pet:get_mood() <= 63)
        assert.is_true(pet:get_mood() >= Pet.MIN_STAT)
    end)

    it("clamps stats a v1 bug pushed out of range", function()
        local out = Pet.migrate(v1_save({ mood = 400, satiety = -80 }))
        assert.are.equal(Pet.MAX_STAT, out.mood)
        assert.are.equal(Pet.MIN_STAT, out.satiety)
    end)

    -- birth_time and last_vim_close_time came off the same monotonic clock, so
    -- their difference is a real duration even though neither value is.
    it("salvages age from the monotonic delta", function()
        local out = Pet.migrate(v1_save())
        local age = os.time() - out.birth_time
        assert.is_true(math.abs(age - 7200) <= 2) -- (7320000-120000)/1000
    end)

    it("rejects a salvaged age beyond 90 days", function()
        local out = Pet.migrate(v1_save({
            birth_time = 0,
            last_vim_close_time = 200 * 86400 * 1000,
        }))
        assert.is_true(os.time() - out.birth_time < 60)
    end)

    it("rejects a negative salvaged age", function()
        local out = Pet.migrate(
            v1_save({ birth_time = 900000, last_vim_close_time = 1000 })
        )
        assert.is_true(os.time() - out.birth_time < 60)
    end)

    it("keeps a birth_time that is already a plausible epoch", function()
        local epoch = os.time() - 5000
        local out = Pet.migrate(v1_save({ birth_time = epoch }))
        assert.are.equal(epoch, out.birth_time)
    end)

    it("rejects a birth_time from the future", function()
        local out = Pet.migrate(v1_save({ birth_time = os.time() + 90000 }))
        assert.is_true(out.birth_time <= os.time())
    end)

    it("never charges retroactive decay across the migration", function()
        local out = Pet.migrate(v1_save())
        assert.is_true(math.abs(out.last_decay_time - os.time()) <= 2)
    end)

    it("drops v1 fields that must come from config", function()
        local out = Pet.migrate(v1_save())
        assert.is_nil(out.sprites)
        assert.is_nil(out.vim_events)
        assert.is_nil(out.native)
        assert.is_nil(out.mood_decay_probability)
        assert.is_nil(out.last_vim_close_time)
        assert.is_nil(out.last_window_close_time)
    end)

    -- v1 round-tripped session_start_time, so "session time" reported the age
    -- of the save file instead of the current session.
    it("does not carry session_start_time across a load", function()
        local out = Pet.migrate(v1_save())
        assert.is_nil(out.session_start_time)

        local pet = Pet:new(out)
        assert.is_true(pet:get_session_duration() < 5)
    end)

    it("preserves counters", function()
        local out =
            Pet.migrate(v1_save({ times_fed = 12, total_vim_events = 210 }))
        assert.are.equal(12, out.times_fed)
        assert.are.equal(210, out.total_vim_events)
    end)

    it(
        "resolves sprites from config rather than the stale saved copy",
        function()
            local pet = Pet:new(Pet.migrate(v1_save()))
            assert.are_not.equal("STALE", pet.sprites.happy[1])
        end
    )
end)
