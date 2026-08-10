local statusline = require("tamagotchi.statusline")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

describe("statusline", function()
    local pet

    before_each(function()
        config.setup()
        pet = Pet.from_def({ name = "Sasha" })
        pet:set_mood(78)
        pet:set_satiety(64)
        statusline.invalidate()
    end)

    it("shows the name and both stats", function()
        local out = statusline.build(pet, {})
        assert.is_truthy(out:find("Sasha", 1, true))
        assert.is_truthy(out:find("78", 1, true))
        assert.is_truthy(out:find("64", 1, true))
    end)

    it("floors fractional stats", function()
        pet:set_mood(78.9)
        assert.is_truthy(statusline.build(pet, {}):find("78", 1, true))
        assert.is_nil(statusline.build(pet, {}):find("78.9", 1, true))
    end)

    it("offers an ascii-only variant", function()
        local out = statusline.build(pet, { ascii = true })
        assert.are.equal(#out, vim.fn.strdisplaywidth(out))
    end)

    it("can omit the name", function()
        local out = statusline.build(pet, { name = false })
        assert.is_nil(out:find("Sasha", 1, true))
        assert.is_truthy(out:find("78", 1, true))
    end)

    it(
        "returns an empty string with no pet",
        function() assert.are.equal("", statusline.build(nil, {})) end
    )

    describe("caching", function()
        -- Statuslines re-evaluate on nearly every keystroke, so get() must not
        -- rebuild each time.
        it("does not rebuild until invalidated", function()
            _G.tamagotchi_pet = pet
            local first = statusline.get()

            pet:set_mood(1)
            assert.are.equal(first, statusline.get())

            statusline.invalidate()
            assert.are_not.equal(first, statusline.get())
        end)

        it("never throws from a statusline expression", function()
            _G.tamagotchi_pet = { broken = true }
            statusline.invalidate()
            assert.has_no.errors(function() statusline.get() end)
            assert.are.equal("", statusline.get())
        end)
    end)

    describe("with stakes enabled", function()
        before_each(function() config.setup({ stakes = true }) end)

        it("marks a sick pet", function()
            pet.low_since = os.time() - 7 * 3600
            pet:set_satiety(2)
            local out = statusline.build(pet, { ascii = true })
            assert.is_truthy(out:find(":(", 1, true))
        end)

        it("shows only a marker and the name when dead", function()
            pet.low_since = os.time() - 25 * 3600
            local out = statusline.build(pet, { ascii = true })
            assert.is_truthy(out:find("x_x", 1, true))
            assert.is_nil(out:find("78", 1, true))
        end)
    end)
end)
