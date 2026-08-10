local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")
local config = require("tamagotchi.config")
local assert = require("luassert")

local function mark_groups()
    local groups = {}
    for _, mark in
        ipairs(
            vim.api.nvim_buf_get_extmarks(
                window.current_window.buf,
                window.namespace,
                0,
                -1,
                { details = true }
            )
        )
    do
        groups[mark[4].hl_group] = true
    end
    return groups
end

describe("window module", function()
    before_each(function() config.setup() end)

    after_each(function()
        if window.is_open() then window.close(nil) end
        window.current_pet = nil
    end)

    describe("center_text", function()
        it("validates text is a string", function()
            assert.has_error(
                function() window.center_text(123, 10) end,
                "text must be a string"
            )
        end)

        it("validates width is a positive number", function()
            assert.has_error(
                function() window.center_text("test", "not a number") end,
                "width must be a positive number"
            )
        end)

        it("validates width is positive", function()
            assert.has_error(
                function() window.center_text("test", 0) end,
                "width must be a positive number"
            )
        end)

        it(
            "truncates text when width is less than text length",
            function() assert.are.equal("Hel", window.center_text("Hello", 3)) end
        )

        it(
            "returns the same text when width equals text length",
            function() assert.are.equal("Hello", window.center_text("Hello", 5)) end
        )

        it(
            "centers with even extra space",
            function() assert.are.equal("  Hi  ", window.center_text("Hi", 6)) end
        )

        it(
            "centers with odd extra space",
            function() assert.are.equal("  Hi   ", window.center_text("Hi", 7)) end
        )

        it(
            "handles empty string",
            function() assert.are.equal("     ", window.center_text("", 5)) end
        )
    end)

    describe("get_current_pet", function()
        it("returns nil when no pet is open", function()
            window.current_pet = nil
            assert.is_nil(window.get_current_pet())
        end)
    end)

    describe("open", function()
        it("requires a pet", function()
            assert.has_error(function() window.open(nil) end, "pet is required")
        end)

        it("requires a table", function()
            assert.has_error(
                function() window.open("not a pet") end,
                "pet must be a table"
            )
        end)

        it("requires the pet interface", function()
            assert.has_error(
                function() window.open({}) end,
                "pet must have get_mood method"
            )
        end)
    end)

    describe("open and close", function()
        local pet

        before_each(function() pet = Pet.from_def({ name = "Sasha" }) end)

        it("opens and reports open", function()
            window.open(pet)
            assert.is_true(window.is_open())
            assert.are.equal(pet, window.get_current_pet())
        end)

        -- The name labels the window, so it lives in the border title; the body
        -- is left to the two things that change fast enough to watch.
        it("titles the float with the pet's name", function()
            window.open(pet)

            local text = ""
            for _, chunk in ipairs(window.title_chunks(pet)) do
                text = text .. chunk[1]
            end

            assert.is_truthy(text:find("Sasha", 1, true))
        end)

        it("renders both stat bars", function()
            window.open(pet)
            local lines = vim.api.nvim_buf_get_lines(
                window.current_window.buf,
                0,
                -1,
                false
            )
            local text = table.concat(lines, "\n")

            assert.is_truthy(text:find("satiety", 1, true))
            assert.is_truthy(text:find("mood", 1, true))
            assert.is_truthy(text:find("█", 1, true))
        end)

        -- Every native pet ships with a colour, so the sprite is tinted with no
        -- trip through the settings screen.
        it("colors the sprite with the pet's theme", function()
            window.open(Pet.from_def({ name = "Lucy" }))
            assert.is_true(mark_groups()["TamagotchiColorRed"] or false)
        end)

        -- One setting governs the whole plugin's look, for terminals and fonts
        -- that render the block glyphs badly.
        it("draws ASCII bars when ui.ascii is set", function()
            config.setup({ ui = { ascii = true } })
            window.open(pet)

            local text = table.concat(
                vim.api.nvim_buf_get_lines(
                    window.current_window.buf,
                    0,
                    -1,
                    false
                ),
                "\n"
            )

            assert.is_truthy(text:find("[", 1, true))
            assert.is_nil(text:find("█", 1, true))
            assert.is_nil(text:find("─", 1, true))
            assert.is_nil(text:find("·", 1, true))
        end)

        it("pads every line to the window width", function()
            window.open(pet)
            local width = window.current_window.width
            for _, line in
                ipairs(
                    vim.api.nvim_buf_get_lines(
                        window.current_window.buf,
                        0,
                        -1,
                        false
                    )
                )
            do
                assert.are.equal(width, vim.fn.strdisplaywidth(line))
            end
        end)

        it("closes and clears its state", function()
            window.open(pet)
            window.close(pet)

            assert.is_false(window.is_open())
            assert.is_nil(window.current_window)
            -- v1 never cleared this, so the menu could deref a stale pet.
            assert.is_nil(window.current_pet)
        end)

        it("toggles", function()
            window.toggle(pet)
            assert.is_true(window.is_open())
            window.toggle(pet)
            assert.is_false(window.is_open())
        end)

        -- v1 re-added highlights every tick into namespace 0, which cannot be
        -- cleared, so extmarks grew for as long as the window stayed open.
        it("does not accumulate extmarks across redraws", function()
            pet.color_theme = "red"
            window.open(pet)

            local buf = window.current_window.buf
            local function marks()
                return #vim.api.nvim_buf_get_extmarks(
                    buf,
                    window.namespace,
                    0,
                    -1,
                    {}
                )
            end

            local first = marks()
            for _ = 1, 20 do
                window.update_ui(pet, true)
            end

            assert.are.equal(first, marks())
        end)
    end)

    -- The bars are the only thing on screen that moves on its own, and at rest
    -- they say how full a stat is, not which way it is heading.
    describe("stat trends", function()
        before_each(function() window.reset_trends() end)

        it(
            "does not flash the first time it sees a stat",
            function() assert.is_nil(window.trend("mood", 50, 0)) end
        )

        it("flashes up when a stat rises", function()
            window.trend("mood", 50, 0)
            assert.are.equal("up", window.trend("mood", 65, 100))
        end)

        it("holds the flash, then lets it expire", function()
            window.trend("mood", 50, 0)
            window.trend("mood", 65, 100)

            assert.are.equal("up", window.trend("mood", 65, 1000))
            assert.is_nil(window.trend("mood", 65, 9000))
        end)

        -- Decay is fractional and never stops, so a bar that reddened on any
        -- decrease at all would simply be red forever.
        it("ignores a drop smaller than a whole point", function()
            window.trend("satiety", 50, 0)
            assert.is_nil(window.trend("satiety", 49.6, 1000))
        end)

        it("flashes down once a whole point has gone", function()
            window.trend("satiety", 50, 0)
            window.trend("satiety", 49.6, 1000)
            assert.are.equal("down", window.trend("satiety", 48.9, 2000))
        end)

        it("tracks each stat on its own", function()
            window.trend("mood", 50, 0)
            window.trend("satiety", 50, 0)

            assert.are.equal("up", window.trend("mood", 70, 100))
            assert.is_nil(window.trend("satiety", 50, 100))
        end)

        it("marks a resting stat as flat", function()
            local pet = Pet.from_def({ name = "Sasha" })
            window.open(pet)

            local groups = mark_groups()
            assert.is_true(groups["TamagotchiTrendFlat"] or false)
            assert.is_nil(groups["TamagotchiTrendUp"])
            assert.is_nil(groups["TamagotchiTrendDown"])
        end)

        it("lights up the stat an interaction just moved", function()
            local pet = Pet.from_def({ name = "Sasha" })
            pet:set_satiety(40)
            window.open(pet)

            pet:set_satiety(70)
            window.update_ui(pet, false)

            local lines = vim.api.nvim_buf_get_lines(
                window.current_window.buf,
                0,
                -1,
                false
            )
            assert.is_truthy(
                table.concat(lines, "\n"):find("▲", 1, true),
                "no up marker in the window"
            )
            assert.is_true(mark_groups()["TamagotchiTrendUp"] or false)
        end)
    end)

    -- Without a row in the window the verbs exist only as :Tamagotchi
    -- subcommands, which means nobody discovers them.
    describe("action row", function()
        local function action_line(pet)
            window.open(pet)
            local lines = vim.api.nvim_buf_get_lines(
                window.current_window.buf,
                0,
                -1,
                false
            )
            return lines[#lines]
        end

        it("offers every verb", function()
            local row = action_line(Pet.from_def({ name = "Sasha" }))
            for _, label in ipairs({ "f feed", "p play", "t pet", "c clean" }) do
                assert.is_truthy(
                    row:find(label, 1, true),
                    "action row is missing " .. label
                )
            end
        end)

        -- Navigation moved to the border footer, so the action row is the last
        -- body line, set off by a rule drawn in the border's own glyph.
        it("sits on the last line, under a rule", function()
            local pet = Pet.from_def({ name = "Sasha" })
            window.open(pet)

            local lines = vim.api.nvim_buf_get_lines(
                window.current_window.buf,
                0,
                -1,
                false
            )
            assert.is_truthy(lines[#lines]:find("f feed", 1, true))
            assert.are.equal(window.current_window.rule, lines[#lines - 1])
        end)

        it("binds a key for each verb", function()
            local pet = Pet.from_def({ name = "Sasha" })
            window.open(pet)

            local bound = {}
            for _, m in
                ipairs(
                    vim.api.nvim_buf_get_keymap(window.current_window.buf, "n")
                )
            do
                bound[m.lhs] = true
            end

            for _, action in ipairs(window.ACTIONS) do
                assert.is_true(
                    bound[action.key] or false,
                    "no mapping for " .. action.label
                )
            end
        end)

        it("actually performs the interaction", function()
            local pet = Pet.from_def({ name = "Sasha" })
            _G.tamagotchi_pet = pet
            pet:set_satiety(40)
            window.open(pet)

            vim.api.nvim_feedkeys("f", "x", false)
            vim.wait(50)

            assert.is_true(pet:get_satiety() > 40)
            assert.are.equal(1, pet.times_fed)
        end)

        it("offers revive instead once the pet has died", function()
            config.setup({ stakes = true })

            local pet = Pet.from_def({ name = "Sasha" })
            pet.low_since = os.time() - 30 * 3600
            pet:apply_decay()

            local row = action_line(pet)
            assert.is_truthy(row:find("R revive", 1, true))
            assert.is_nil(row:find("f feed", 1, true))
        end)
    end)

    -- Reset can delete every save file, so it belongs behind the settings
    -- screen rather than one keystroke from the main window.
    describe("reset placement", function()
        it("is not in the nav footer", function()
            local footer = window.footer_text()

            assert.is_truthy(footer:find("m menu", 1, true))
            assert.is_truthy(footer:find("s settings", 1, true))
            assert.is_nil(footer:find("eset", 1, true))
        end)

        it("is not bound to r in the pet window", function()
            local pet = Pet.from_def({ name = "Sasha" })
            window.open(pet)

            for _, m in
                ipairs(
                    vim.api.nvim_buf_get_keymap(window.current_window.buf, "n")
                )
            do
                assert.are_not.equal("r", m.lhs)
            end
        end)

        it("is offered by the settings screen", function()
            local settings = require("tamagotchi.settings")
            local lines = settings.build_lines(Pet.from_def({ name = "Sasha" }))
            assert.is_not_nil(
                settings._index_of(lines, "^%s*x%s+reset"),
                "settings screen does not offer reset"
            )
        end)

        -- Still reachable explicitly, for anyone who does want it.
        it(
            "is still available as a subcommand",
            function()
                assert.is_true(
                    vim.tbl_contains(
                        require("tamagotchi.command").names(),
                        "reset"
                    )
                )
            end
        )
    end)

    describe("on_tick", function()
        it("is a no-op with no window open", function()
            local pet = Pet.from_def({ name = "Sasha" })
            assert.has_no.errors(function() window.on_tick(pet, true) end)
        end)
    end)
end)
