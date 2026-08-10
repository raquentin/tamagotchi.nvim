local ui = require("tamagotchi.ui")
local config = require("tamagotchi.config")
local render = require("tamagotchi.render")
local assert = require("luassert")

describe("ui", function()
    local opened = {}

    local function open(opts)
        local handle = ui.open(opts)
        opened[#opened + 1] = handle
        return handle
    end

    before_each(function() config.setup() end)

    after_each(function()
        for _, handle in ipairs(opened) do
            pcall(handle.close)
        end
        opened = {}
        vim.o.winborder = ""
    end)

    describe("resolve_border", function()
        it("prefers an explicit argument", function()
            config.setup({ ui = { border = "double" } })
            assert.are.equal("single", ui.resolve_border("single"))
        end)

        it("then the configured border", function()
            config.setup({ ui = { border = "double" } })
            assert.are.equal("double", ui.resolve_border())
        end)

        -- "auto" is the default, so a user who has already set 'winborder'
        -- gets floats that match the rest of their editor.
        it("then 'winborder' when the border is auto", function()
            if not pcall(function() return vim.o.winborder end) then
                return -- 0.10 has no 'winborder'
            end

            vim.o.winborder = "solid"
            assert.are.equal("solid", ui.resolve_border())
        end)

        it(
            "falls back to rounded",
            function() assert.are.equal("rounded", ui.resolve_border()) end
        )

        it("accepts a table border", function()
            local border = { "+", "-", "+", "|", "+", "-", "+", "|" }
            assert.are.same(border, ui.resolve_border(border))
        end)
    end)

    describe("rule_char", function()
        it("matches the border style", function()
            assert.are.equal("─", ui.rule_char("rounded"))
            assert.are.equal("═", ui.rule_char("double"))
        end)

        it(
            "reads the top edge out of a table border",
            function()
                assert.are.equal(
                    "=",
                    ui.rule_char({ "+", "=", "+", "|", "+", "=", "+", "|" })
                )
            end
        )

        it("is ASCII when the plugin is", function()
            config.setup({ ui = { ascii = true } })
            assert.are.equal("-", ui.rule_char("double"))
        end)
    end)

    describe("chunks", function()
        it("pads the ends so text clears the corners", function()
            local chunks = ui.chunks({ { "hi", "TamagotchiTitle" } })
            assert.are.same({ { " hi ", "TamagotchiTitle" } }, chunks)
        end)

        it("drops empty parts", function()
            local chunks =
                ui.chunks({ { "", "X" }, { "a", "X" }, { nil, "X" } })
            assert.are.equal(1, #chunks)
            assert.are.equal(" a ", chunks[1][1])
        end)

        -- A borderless window rejects a title outright, so callers need a nil
        -- rather than an empty chunk list.
        it(
            "is nil when nothing survives",
            function() assert.is_nil(ui.chunks({ { "" } })) end
        )
    end)

    describe("key_chunks", function()
        it("highlights keys apart from their labels", function()
            local chunks =
                ui.key_chunks({ { key = "q", label = "close" } }, " · ")
            assert.are.same({
                { " q", "TamagotchiKey" },
                { " close ", "TamagotchiFooter" },
            }, chunks)
        end)

        it("matches what key_text renders", function()
            local entries =
                { { key = "j", label = "down" }, { key = "k", label = "up" } }

            local text = ""
            for _, chunk in ipairs(ui.key_chunks(entries, " · ")) do
                text = text .. chunk[1]
            end

            assert.are.equal(ui.key_text(entries, " · "), vim.trim(text))
        end)
    end)

    describe("open", function()
        it("sizes itself to its lines by default", function()
            local handle = open({ lines = { "hello", "hi" } })
            assert.are.equal(5, handle.width)
            assert.are.equal(2, handle.height)
        end)

        -- Without this a background highlight stops at the end of each line's
        -- text instead of covering the float.
        it("pads every line to the window width", function()
            local handle = open({ lines = { "hello", "hi" }, width = 12 })

            for _, line in
                ipairs(vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false))
            do
                assert.are.equal(12, render.display_width(line))
            end
        end)

        it("truncates a line wider than the window", function()
            local handle = open({ lines = { "hello there" }, width = 5 })
            assert.are.equal(
                "hello",
                vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false)[1]
            )
        end)

        -- The search box is user text; padding it would append spaces to
        -- whatever was typed.
        it("leaves a modifiable buffer unpadded", function()
            local handle =
                open({ lines = { "hi" }, width = 12, modifiable = true })

            assert.are.equal(
                "hi",
                vim.api.nvim_buf_get_lines(handle.buf, 0, -1, false)[1]
            )
            assert.is_true(vim.bo[handle.buf].modifiable)
        end)

        it("renders floats on the plugin's own highlight groups", function()
            local handle = open({ lines = { "hi" } })
            assert.is_truthy(
                vim.wo[handle.win].winhighlight:find(
                    "NormalFloat:TamagotchiNormal",
                    1,
                    true
                )
            )
        end)

        it("carries a rule spanning its width", function()
            local handle = open({ lines = { "hi" }, width = 8 })
            assert.are.equal(("─"):rep(8), handle.rule)
        end)

        it("does not set a title on a borderless window", function()
            local handle = open({
                lines = { "hi" },
                border = "none",
                title = ui.chunks({ { "nope" } }),
            })

            local win_config = vim.api.nvim_win_get_config(handle.win)
            assert.is_falsy(win_config.title)
        end)
    end)

    describe("close", function()
        it("runs on_close exactly once", function()
            local calls = 0
            local handle = open({
                lines = { "hi" },
                on_close = function() calls = calls + 1 end,
            })

            handle.close()
            handle.close()

            assert.are.equal(1, calls)
            assert.is_false(handle.is_valid())
        end)

        -- v1 only ran teardown from its own keymap, so quitting a float with
        -- :q skipped the save and left the tick at animation speed.
        it("runs on_close when the window goes away by itself", function()
            local closed = false
            local handle = open({
                lines = { "hi" },
                on_close = function() closed = true end,
            })

            vim.api.nvim_win_close(handle.win, true)
            vim.wait(50, function() return closed end)

            assert.is_true(closed)
        end)

        for _, key in ipairs({ "q", "<Esc>" }) do
            it(("closes on %s by default"):format(key), function()
                local handle = open({ lines = { "hi" } })

                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes(key, true, false, true),
                    "x",
                    false
                )
                vim.wait(50, function() return not handle.is_valid() end)

                assert.is_false(handle.is_valid())
            end)
        end

        it("binds nothing when close_keys is empty", function()
            local handle = open({ lines = { "hi" }, close_keys = {} })

            for _, m in ipairs(vim.api.nvim_buf_get_keymap(handle.buf, "n")) do
                assert.are_not.equal("q", m.lhs)
            end
        end)
    end)

    describe("help", function()
        it("lists every entry and returns focus on close", function()
            local parent = open({ lines = { "hi" } })
            local help = ui.help({ { key = "f", label = "feed" } }, parent)
            opened[#opened + 1] = help

            local text = table.concat(
                vim.api.nvim_buf_get_lines(help.buf, 0, -1, false),
                "\n"
            )
            assert.is_truthy(text:find("f", 1, true))
            assert.is_truthy(text:find("feed", 1, true))

            help.close()
            assert.are.equal(parent.win, vim.api.nvim_get_current_win())
        end)
    end)
end)
