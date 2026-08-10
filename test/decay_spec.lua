local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

-- Decay is the property the whole time model rests on. v1 applied it in three
-- places with three different caps and floors, over overlapping wall time.
describe("decay", function()
    local T0 = 1800000000 -- fixed epoch, so nothing here depends on the clock

    local function pet_at(mood, satiety, speed)
        local pet = Pet:new({
            name = "Decay Test",
            sprites = { happy = { "h" }, hungry = { "u" }, neutral = { "n" } },
            mood = mood,
            satiety = satiety,
            decay_speed = speed or 3,
        })
        pet.last_decay_time = T0
        return pet
    end

    before_each(function() config.setup() end)

    it("charges rate x elapsed", function()
        local pet = pet_at(100, 100, 3) -- 0.05 points/sec
        pet:apply_decay(T0 + 100)
        assert.are.equal(95, pet:get_mood())
        assert.are.equal(95, pet:get_satiety())
    end)

    it("decay_speed 0 decays nothing", function()
        local pet = pet_at(100, 100, 0)
        pet:apply_decay(T0 + 100000)
        assert.are.equal(100, pet:get_mood())
    end)

    -- The property that lets load, tick and window-open all call apply_decay
    -- without double-charging.
    it("is idempotent: a second call at the same instant is a no-op", function()
        local pet = pet_at(100, 100)
        pet:apply_decay(T0 + 100)
        local after_first = pet:get_mood()
        pet:apply_decay(T0 + 100)
        assert.are.equal(after_first, pet:get_mood())
    end)

    it("splitting an interval costs the same as one call", function()
        local whole = pet_at(100, 100)
        whole:apply_decay(T0 + 300)

        local split = pet_at(100, 100)
        for _, t in ipairs({ 50, 120, 200, 300 }) do
            split:apply_decay(T0 + t)
        end

        assert.are.equal(whole:get_mood(), split:get_mood())
        assert.are.equal(whole:get_satiety(), split:get_satiety())
    end)

    it("a backwards clock never increases a stat", function()
        local pet = pet_at(50, 50)
        pet:apply_decay(T0 - 5000) -- NTP step backwards
        assert.are.equal(50, pet:get_mood())
        assert.are.equal(50, pet:get_satiety())
    end)

    it("advances last_decay_time even when elapsed is not positive", function()
        local pet = pet_at(50, 50)
        pet:apply_decay(T0 - 5000)
        assert.are.equal(T0 - 5000, pet.last_decay_time)
    end)

    it("caps how much time away can be charged at once", function()
        config.setup({ max_offline_decay_seconds = 60 })
        local pet = pet_at(100, 100, 3)

        pet:apply_decay(T0 + 86400) -- a day away
        assert.are.equal(97, pet:get_mood()) -- only 60s charged
    end)

    -- The anti-triple-count invariant: without this, a long absence is charged
    -- the cap once per tick, forever.
    it("advances last_decay_time fully even when the cap bites", function()
        config.setup({ max_offline_decay_seconds = 60 })
        local pet = pet_at(100, 100, 3)

        pet:apply_decay(T0 + 86400)
        assert.are.equal(T0 + 86400, pet.last_decay_time)

        local after_cap = pet:get_mood()
        pet:apply_decay(T0 + 86400)
        assert.are.equal(after_cap, pet:get_mood())
    end)

    it("floors at MIN_STAT, never below", function()
        local pet = pet_at(100, 100, 6)
        pet:apply_decay(T0 + 1000000)
        assert.are.equal(Pet.MIN_STAT, pet:get_mood())
        assert.are.equal(Pet.MIN_STAT, pet:get_satiety())
    end)

    -- v1's raw write bypassed the setter and could push stats past 100.
    it("never pushes a stat above MAX_STAT", function()
        local pet = pet_at(100, 100)
        pet:apply_decay(T0 + 10)
        assert.is_true(pet:get_mood() <= Pet.MAX_STAT)
    end)

    it("keeps stats fractional so slow decay still accumulates", function()
        local pet = pet_at(100, 100, 1) -- 0.01/sec
        pet:apply_decay(T0 + 1)
        assert.are.equal(99.99, pet:get_mood())
    end)

    it("update() is still an alias for apply_decay", function()
        local pet = pet_at(100, 100)
        pet:update(T0 + 100)
        assert.are.equal(95, pet:get_mood())
    end)

    it("never increases a stat during a normal update", function()
        local pet = pet_at(60, 60)
        local mood, satiety = pet:get_mood(), pet:get_satiety()
        pet:update(T0 + 10)
        assert.is_true(pet:get_mood() <= mood)
        assert.is_true(pet:get_satiety() <= satiety)
    end)
end)
