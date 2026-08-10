local config = require("tamagotchi.config")
local Pet = require("tamagotchi.pet")
local assert = require("luassert")

describe("window_toggle_keybind configuration", function()
    it("should use default config when no user config is provided", function()
        config.setup()
        assert.are.equal("<leader>tg", config.values.window_toggle_keybind)
    end)

    it("should override default config with user values", function()
        config.setup({ window_toggle_keybind = "<leader>xx" })
        assert.are.equal("<leader>xx", config.values.window_toggle_keybind)
    end)

    it("allows disabling the keybind entirely", function()
        config.setup({ window_toggle_keybind = false })
        assert.is_false(config.values.window_toggle_keybind)
    end)
end)

describe("configuration with multiple pets", function()
    before_each(function() config.setup() end)

    it("ships the documented native pets", function()
        local names = {}
        for _, pet in ipairs(config.values.pets) do
            names[#names + 1] = pet.name
        end

        for _, expected in ipairs({
            "Bunny",
            "Churro",
            "Dragon",
            "Grizz",
            "Lucy",
            "Po",
            "Sasha",
        }) do
            assert.is_true(
                vim.tbl_contains(names, expected),
                "missing native pet: " .. expected
            )
        end
    end)

    it(
        "sorts pets by name",
        function() assert.are.equal("Bunny", config.values.pets[1].name) end
    )

    it("gives every native pet sprites", function()
        for _, pet in ipairs(config.values.pets) do
            assert.is_table(pet.sprites, pet.name .. " has no sprites")
            assert.is_true(#pet.sprites.happy > 0, pet.name .. " has no frames")
        end
    end)

    it("appends user pets rather than merging them into defaults", function()
        local before = #config.defaults.pets

        config.setup({
            pets = {
                {
                    name = "Custom",
                    sprites = {
                        happy = { "a" },
                        hungry = { "b" },
                        neutral = { "c" },
                    },
                },
            },
        })

        assert.are.equal(before + 1, #config.values.pets)

        -- tbl_deep_extend merges lists index-wise, which would have overwritten
        -- fields of the first default pet instead of adding a new one.
        for _, pet in ipairs(config.values.pets) do
            if pet.name == "Bunny" then
                assert.are_not.equal("Custom", pet.name)
            end
        end
    end)

    it("rejects two pets whose names collide on disk", function()
        assert.has_error(
            function()
                config.setup({
                    pets = {
                        {
                            name = "Sasha",
                            sprites = {
                                happy = { "a" },
                                hungry = {},
                                neutral = {},
                            },
                        },
                    },
                })
            end
        )
    end)
end)

-- v1 inserted M.defaults.pets[i] directly into config.values.pets, and Pet:new
-- then adopted that very table -- so live pet state leaked into the defaults and
-- survived across setup() calls.
describe("config is not mutated by pet construction", function()
    before_each(function() config.setup() end)

    local function def_named(name)
        for _, pet in ipairs(config.values.pets) do
            if pet.name == name then return pet end
        end
    end

    it("does not hand out the module-level default tables", function()
        for i, pet in ipairs(config.defaults.pets) do
            for _, live in ipairs(config.values.pets) do
                if live.name == pet.name then
                    assert.are_not.equal(
                        config.defaults.pets[i],
                        live,
                        "config.values.pets aliases config.defaults.pets"
                    )
                end
            end
        end
    end)

    it("leaves no runtime state on the defaults", function()
        for _, pet in ipairs(config.defaults.pets) do
            assert.is_nil(pet.native)
            assert.is_nil(pet.mood)
            assert.is_nil(pet.birth_time)
        end
    end)

    it("returns a distinct object for each construction", function()
        local def = def_named("Sasha")
        assert.are_not.equal(Pet:new(def), Pet:new(def))
    end)

    it("does not write pet state back onto the definition", function()
        local def = def_named("Sasha")
        local pet = Pet:new(def)
        pet:set_mood(3)

        assert.is_nil(def.mood)
        assert.is_nil(def.birth_time)
    end)

    -- This is what made the menu's "start new life" silently keep the old life.
    it("starts a fresh pet at its initial stats", function()
        local def = def_named("Sasha")

        local first = Pet:new(def)
        first:set_mood(5)

        local second = Pet:new(def)
        assert.are.equal(def.initial_mood, second:get_mood())
    end)

    it("does not accumulate across repeated setup() calls", function()
        local count = #config.values.pets
        config.setup()
        assert.are.equal(count, #config.values.pets)
    end)
end)
