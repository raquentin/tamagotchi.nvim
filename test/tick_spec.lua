local tick = require("tamagotchi.tick")
local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("tick", function()
    before_each(function()
        config.setup()
        tick.stop()
        window.current_window = nil
        _G.tamagotchi_pet = Pet.from_def({ name = "Sasha" })
    end)

    after_each(function() tick.stop() end)

    it("starts and reports running", function()
        tick.start()
        assert.is_true(tick.is_running())
    end)

    it("stop is idempotent", function()
        tick.start()
        tick.stop()
        tick.stop()
        assert.is_false(tick.is_running())
    end)

    it("start twice does not leak the first timer", function()
        tick.start()
        local first = tick.timer
        tick.start()
        assert.are_not.equal(first, tick.timer)
        assert.is_true(first:is_closing())
    end)

    -- The exact v1 startup bug: setup() started the loop with no window open,
    -- the first tick fired immediately, took the "window is gone" branch, and
    -- stopped the very timer that drives the simulation.
    it("keeps running when a tick fires with no window open", function()
        tick.start()
        assert.is_false(window.is_open())

        tick.force()

        assert.is_true(
            tick.is_running(),
            "a windowless tick killed the simulation"
        )
    end)

    it("advances decay with no window open", function()
        local pet = _G.tamagotchi_pet
        pet:set_mood(100)
        pet.last_decay_time = os.time() - 200

        tick.force()

        assert.is_true(pet:get_mood() < 100)
    end)

    it("tolerates having no pet at all", function()
        _G.tamagotchi_pet = nil
        assert.has_no.errors(function() tick.force() end)
    end)

    describe("adaptive period", function()
        it(
            "idles slowly when no window is open",
            function()
                assert.are.equal(config.values.idle_tick_ms, tick.period_ms())
            end
        )

        it("uses the animation rate while a window is open", function()
            config.setup({ tick_length_ms = 250, idle_tick_ms = 9000 })
            assert.are.equal(9000, tick.period_ms())

            -- Pretend a window is open without drawing one.
            window.current_window =
                { win = vim.api.nvim_get_current_win(), buf = 0, width = 40 }
            assert.are.equal(250, tick.period_ms())

            window.current_window = nil
        end)

        it("retime is a no-op when the period is unchanged", function()
            tick.start()
            local timer = tick.timer
            tick.retime()
            assert.are.equal(timer, tick.timer)
        end)

        it("retime on a stopped tick does not start one", function()
            tick.stop()
            tick.retime()
            assert.is_false(tick.is_running())
        end)
    end)
end)
