local menu = require("tamagotchi.menu")
local config = require("tamagotchi.config")
local assert = require("luassert")

-- The menu publishes its animation timer so this can be checked directly.
-- Walking every libuv handle with vim.uv.walk segfaults Neovim 0.10.
local function timer_released() return menu._active_timer == nil end

describe("menu window", function()
    before_each(function() config.setup() end)

    it("opens a scratch buffer and an animation timer", function()
        menu.open_pet_menu()

        assert.are.equal(
            "nofile",
            vim.bo[vim.api.nvim_get_current_buf()].buftype
        )
        assert.is_not_nil(menu._active_timer)

        vim.cmd("close")
        vim.wait(50)
    end)

    -- Every exit path must run the same teardown. v1 left the 1s timer running
    -- for the rest of the session when the menu was closed with :q.
    for _, how in ipairs({ "q", "<Esc>" }) do
        it(("closes on %s and releases its timer"):format(how), function()
            menu.open_pet_menu()
            local win = vim.api.nvim_get_current_win()

            local key = vim.api.nvim_replace_termcodes(how, true, false, true)
            vim.api.nvim_feedkeys(key, "x", false)
            vim.wait(100)

            assert.is_false(
                vim.api.nvim_win_is_valid(win),
                how .. " did not close the menu"
            )
            assert.is_true(timer_released(), how .. " leaked the timer")
        end)
    end

    it("releases its timer when closed with :q", function()
        menu.open_pet_menu()
        vim.cmd("close")
        vim.wait(100)

        assert.is_true(timer_released())
    end)

    -- v1 mapped all 52 letters to "append to query" after j/k/q were mapped,
    -- silently clobbering them.
    it("uses j and k to navigate, not to type", function()
        menu.open_pet_menu()
        local buf = vim.api.nvim_get_current_buf()

        local function text()
            return table.concat(
                vim.api.nvim_buf_get_lines(buf, 0, -1, false),
                "\n"
            )
        end

        local before = text()
        vim.api.nvim_feedkeys("j", "x", false)
        vim.wait(50)
        local after = text()

        assert.are_not.equal(before, after, "j did nothing")
        assert.is_nil(after:find("search: j"), "j typed into the search box")

        vim.api.nvim_feedkeys("k", "x", false)
        vim.wait(50)
        assert.are.equal(before, text())

        vim.cmd("close")
        vim.wait(50)
    end)

    -- Opt-in, so telescope / snacks / fzf-lua users get the picker they already
    -- configured instead of the builtin one.
    describe("picker = native", function()
        local select

        before_each(function()
            select = vim.ui.select
            config.setup({ picker = "native" })
        end)

        after_each(function() vim.ui.select = select end)

        it("hands the pet list to vim.ui.select", function()
            local got
            vim.ui.select = function(items, opts) got = { items, opts } end

            menu.open_pet_menu()

            assert.is_not_nil(got, "vim.ui.select was not called")
            assert.are.equal(#config.values.pets, #got[1])
            assert.are.equal(
                config.values.pets[1].name,
                got[2].format_item(got[1][1])
            )
            -- Nothing was drawn, so nothing can be left running.
            assert.is_true(timer_released())
        end)

        it("does nothing when the picker is cancelled", function()
            vim.ui.select = function(_, _, on_choice) on_choice(nil) end

            assert.has_no.errors(function() menu.open_pet_menu() end)
        end)
    end)
end)

describe("menu.fuzzy_match", function()
    it(
        "matches everything on an empty pattern",
        function() assert.is_true(menu.fuzzy_match("Sasha", "")) end
    )

    it("matches a subsequence", function()
        assert.is_true(menu.fuzzy_match("Sasha", "sh"))
        assert.is_true(menu.fuzzy_match("Dragon", "dgn"))
    end)

    it("ignores case in both directions", function()
        assert.is_true(menu.fuzzy_match("Sasha", "SAS"))
        assert.is_true(menu.fuzzy_match("SASHA", "sas"))
    end)

    it("rejects a non-subsequence", function()
        assert.is_false(menu.fuzzy_match("Sasha", "xyz"))
        assert.is_false(menu.fuzzy_match("Sasha", "ahs"))
    end)

    it(
        "rejects a pattern longer than the name",
        function() assert.is_false(menu.fuzzy_match("Po", "Polly")) end
    )

    -- The char-by-char loop is safe with these; a string.find "optimization"
    -- would not be.
    it("treats lua magic characters literally", function()
        assert.is_false(menu.fuzzy_match("Sasha", "."))
        assert.is_false(menu.fuzzy_match("Sasha", "%w"))
        assert.is_true(menu.fuzzy_match("a-b", "-"))
    end)
end)

-- v1 rendered only the first 8 pets but let the selection run to the end of the
-- list, so past row 8 the cursor became invisible while still moving.
describe("menu._scroll", function()
    local PAGE = 8

    it(
        "stays at the top when everything fits",
        function() assert.are.equal(1, menu._scroll(1, 3, PAGE, 5)) end
    )

    it(
        "does not scroll while the selection is on screen",
        function() assert.are.equal(1, menu._scroll(1, PAGE, PAGE, 20)) end
    )

    it(
        "scrolls down to keep the selection visible",
        function() assert.are.equal(2, menu._scroll(1, PAGE + 1, PAGE, 20)) end
    )

    it(
        "scrolls up when the selection moves above the viewport",
        function() assert.are.equal(3, menu._scroll(5, 3, PAGE, 20)) end
    )

    it(
        "clamps at the bottom of the list",
        function()
            assert.are.equal(20 - PAGE + 1, menu._scroll(1, 20, PAGE, 20))
        end
    )

    it(
        "never returns an offset below 1",
        function() assert.are.equal(1, menu._scroll(-5, 1, PAGE, 20)) end
    )

    it("keeps the selection inside the viewport for every index", function()
        local total, top = 20, 1
        for idx = 1, total do
            top = menu._scroll(top, idx, PAGE, total)
            assert.is_true(
                idx >= top and idx <= top + PAGE - 1,
                ("index %d fell outside the viewport at top %d"):format(
                    idx,
                    top
                )
            )
        end
    end)
end)
