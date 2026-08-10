local tamagotchi = require("tamagotchi")
local command = require("tamagotchi.command")
local tick = require("tamagotchi.tick")
local store = require("tamagotchi.store")
local assert = require("luassert")

local function autocmd_count(group)
    local ok, list = pcall(vim.api.nvim_get_autocmds, { group = group })
    return ok and #list or 0
end

describe("setup", function()
    after_each(function() tamagotchi.teardown() end)

    it("creates a pet and starts the simulation", function()
        tamagotchi.setup()
        assert.is_not_nil(_G.tamagotchi_pet)
        assert.is_true(tick.is_running())
    end)

    it("marks itself as done", function()
        tamagotchi.setup()
        assert.is_true(tamagotchi._did_setup)
    end)

    -- v1 ran setup() from plugin/ at load time and again when the user called
    -- it, ending up with two pets, two keymaps and two timers.
    it("is idempotent", function()
        tamagotchi.setup()
        local before = autocmd_count("TamagotchiEvents")

        tamagotchi.setup()

        assert.are.equal(before, autocmd_count("TamagotchiEvents"))
        assert.is_true(tick.is_running())
    end)

    it("teardown removes the keymap, autocmds and timer", function()
        tamagotchi.setup({ window_toggle_keybind = "<leader>zz" })
        tamagotchi.teardown()

        assert.is_false(tick.is_running())
        assert.is_false(tamagotchi._did_setup)
        assert.are.equal(0, autocmd_count("TamagotchiEvents"))

        for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
            assert.are_not.equal("Toggle tamagotchi", map.desc)
        end
    end)

    it("binds the configured keymap", function()
        tamagotchi.setup({ window_toggle_keybind = "<leader>zz" })

        local found = false
        for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
            if map.desc == "Toggle tamagotchi" then found = true end
        end
        assert.is_true(found)
    end)

    it("binds nothing when the keybind is disabled", function()
        tamagotchi.setup({ window_toggle_keybind = false })

        for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
            assert.are_not.equal("Toggle tamagotchi", map.desc)
        end
    end)

    describe("bind_pet", function()
        -- v1 registered vim_events once from the initial pet, so switching pets
        -- left the previous pet's event list and increments installed.
        it("re-registers autocmds for the new pet", function()
            tamagotchi.setup()

            local Pet = require("tamagotchi.pet")
            tamagotchi.bind_pet(Pet.from_def({
                name = "Solo",
                sprites = {
                    happy = { "a" },
                    hungry = { "b" },
                    neutral = { "c" },
                },
                vim_events = {
                    {
                        name = "BufWritePost",
                        mood_increment = 1,
                        satiety_increment = 1,
                    },
                },
            }))

            assert.are.equal("Solo", _G.tamagotchi_pet.name)
            assert.are.equal(1, autocmd_count("TamagotchiEvents"))
        end)

        it("clears autocmds for a pet with no events", function()
            tamagotchi.setup()
            tamagotchi.bind_pet({ name = "Eventless" })
            assert.are.equal(0, autocmd_count("TamagotchiEvents"))
        end)
    end)

    describe("persistence across sessions", function()
        -- The bug this guards: v1 saved to one path and loaded from another, so
        -- a pet's state never survived a restart.
        it("resumes the pet that was active last", function()
            tamagotchi.setup()
            -- End the session before writing, the way VimLeavePre would;
            -- otherwise the next setup()'s teardown saves the *current* pet and
            -- repoints state.json at it.
            tamagotchi.teardown()

            local Pet = require("tamagotchi.pet")
            local lucy = Pet.from_def({ name = "Lucy" })
            lucy:set_mood(37)
            store.save_pet(lucy)

            tamagotchi.setup()

            assert.are.equal("Lucy", _G.tamagotchi_pet.name)
            -- Loading charges decay for the elapsed second or two.
            assert.is_true(math.abs(_G.tamagotchi_pet:get_mood() - 37) < 1)
        end)
    end)
end)

describe(":Tamagotchi", function()
    it("exposes the documented subcommands", function()
        local names = command.names()
        for _, expected in ipairs({
            "toggle",
            "open",
            "close",
            "menu",
            "settings",
            "reset",
            "feed",
            "play",
            "pet",
            "clean",
            "revive",
        }) do
            assert.is_true(
                vim.tbl_contains(names, expected),
                "missing subcommand: " .. expected
            )
        end
    end)

    it(
        "completes on a prefix",
        function() assert.are.same({ "feed" }, command.complete("fe")) end
    )

    it(
        "returns nothing for an unmatched prefix",
        function() assert.are.same({}, command.complete("zzz")) end
    )

    -- An unknown subcommand should say so, not throw a stack trace at the user.
    it("reports an unknown subcommand without erroring", function()
        local notified
        local original = vim.notify
        vim.notify = function(msg) notified = msg end

        assert.has_no.errors(
            function() command.dispatch({ args = "definitely-not-real" }) end
        )

        vim.notify = original
        assert.is_truthy(notified:find("unknown subcommand"))
    end)
end)
