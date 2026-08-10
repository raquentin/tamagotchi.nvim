local render = require("tamagotchi.render")
local assert = require("luassert")

describe("render", function()
    describe("ascii_bar", function()
        it(
            "renders an empty bar",
            function()
                assert.are.equal("[----------]", render.ascii_bar(0, 100, 10))
            end
        )

        it(
            "renders a half bar",
            function()
                assert.are.equal("[#####-----]", render.ascii_bar(50, 100, 10))
            end
        )

        it(
            "renders a full bar",
            function()
                assert.are.equal("[##########]", render.ascii_bar(100, 100, 10))
            end
        )

        -- Stats are fractional now, so the bar has to cope with 49.7.
        it(
            "floors a fractional value",
            function()
                assert.are.equal(
                    "[####------]",
                    render.ascii_bar(49.7, 100, 10)
                )
            end
        )

        it(
            "clamps a value above max instead of going negative",
            function()
                assert.are.equal("[##########]", render.ascii_bar(140, 100, 10))
            end
        )

        it("validates its arguments", function()
            assert.has_error(function() render.ascii_bar(-1, 100, 10) end)
            assert.has_error(function() render.ascii_bar(1, 0, 10) end)
            assert.has_error(function() render.ascii_bar(1, 100, 0) end)
        end)
    end)

    describe("stat_bar", function()
        it("renders an empty bar", function()
            local bar, filled = render.stat_bar(0, 100, 10)
            assert.are.equal(("░"):rep(10), bar)
            assert.are.equal(0, filled)
        end)

        it("renders a full bar", function()
            local bar, filled = render.stat_bar(100, 100, 10)
            assert.are.equal(("█"):rep(10), bar)
            assert.are.equal(10, filled)
        end)

        -- The whole point of the block bar: a slowly decaying stat has to move
        -- between whole cells rather than sit frozen and then jump.
        it("draws the boundary cell as a partial block", function()
            local bar, filled = render.stat_bar(55, 100, 10)
            assert.are.equal("█████▌░░░░", bar)
            assert.are.equal(6, filled)
        end)

        it("never draws a partial cell past the end", function()
            local bar, filled = render.stat_bar(140, 100, 10)
            assert.are.equal(("█"):rep(10), bar)
            assert.are.equal(10, filled)
        end)

        it("is always the requested width in cells", function()
            for value = 0, 100 do
                assert.are.equal(
                    10,
                    render.display_width((render.stat_bar(value, 100, 10)))
                )
            end
        end)

        it("validates its arguments", function()
            assert.has_error(function() render.stat_bar(-1, 100, 10) end)
            assert.has_error(function() render.stat_bar(1, 0, 10) end)
            assert.has_error(function() render.stat_bar(1, 100, 0) end)
        end)
    end)

    describe("bar_hl", function()
        it("grades a bar by how full it is", function()
            assert.are.equal("TamagotchiBarHigh", render.bar_hl(80, 100))
            assert.are.equal("TamagotchiBarMed", render.bar_hl(40, 100))
            assert.are.equal("TamagotchiBarLow", render.bar_hl(10, 100))
        end)

        it(
            "does not divide by a zero max",
            function() assert.are.equal("TamagotchiBarLow", render.bar_hl(5, 0)) end
        )
    end)

    -- Extmark columns are byte offsets while every layout is in cells, so a
    -- multibyte name or sprite would misplace highlights without this.
    describe("byte_offset", function()
        it(
            "is the cell count for ASCII",
            function() assert.are.equal(3, render.byte_offset("hello", 3)) end
        )

        it("counts bytes, not cells, past a multibyte glyph", function()
            assert.are.equal(#"█", render.byte_offset("█░", 1))
            assert.are.equal(#"█░", render.byte_offset("█░", 2))
        end)

        it(
            "clamps at zero",
            function() assert.are.equal(0, render.byte_offset("hello", 0)) end
        )
    end)

    describe("center_text", function()
        it(
            "centers with even padding",
            function() assert.are.equal("  Hi  ", render.center_text("Hi", 6)) end
        )

        it(
            "puts the extra space on the right when padding is odd",
            function() assert.are.equal("  Hi   ", render.center_text("Hi", 7)) end
        )

        it(
            "truncates when the text does not fit",
            function() assert.are.equal("Hel", render.center_text("Hello", 3)) end
        )

        it(
            "pads an empty string to full width",
            function() assert.are.equal("     ", render.center_text("", 5)) end
        )

        -- Pet names are user-supplied and flow straight into the info block.
        it("measures a multibyte name in cells, not bytes", function()
            local out = render.center_text("ねこ", 10)
            assert.are.equal(10, render.display_width(out))
        end)

        it("never splits a character in half when truncating", function()
            local out = render.center_text("日本語ねこ", 6)
            assert.are.equal(6, render.display_width(out))
            assert.are.equal("日本語", out)
        end)
    end)

    describe("sprite_box", function()
        local set = {
            happy = { "\n  ab  \n  cd  \n", "\n xyz  \n  q   \n" },
            neutral = { "\n  m   \n  n   \n" },
        }

        it("spans every frame of every state", function()
            local box = render.sprite_box(set)
            assert.are.equal(2, box.left)
            assert.are.equal(4, box.right)
            assert.are.equal(3, box.width)
        end)

        -- The trailing newline in a [[ ... \n]] literal used to become a blank
        -- sprite row; kitty shipped with one.
        it("ignores rows that hold no content", function()
            local box = render.sprite_box({ happy = { "\n ab \n\n   \n" } })
            assert.are.equal(1, box.rows)
        end)

        it("survives an empty sprite set", function()
            local box = render.sprite_box({})
            assert.is_true(box.width >= 1)
        end)
    end)

    describe("normalize_frame", function()
        it("pads every frame of a set to one identical size", function()
            local set =
                { happy = { "\n  ab  \n  cd  \n", "\n xyz  \n  q   \n" } }
            local box = render.sprite_box(set)

            for _, frame in ipairs(set.happy) do
                local lines = render.normalize_frame(frame, box)
                assert.are.equal(box.rows, #lines)
                for _, line in ipairs(lines) do
                    assert.are.equal(box.width, render.display_width(line))
                end
            end
        end)

        it("keeps content at its original column", function()
            local box = { left = 1, right = 6, top = 1, width = 6, rows = 1 }
            assert.are.equal("  ab  ", render.normalize_frame("  ab  ", box)[1])
        end)
    end)

    describe("wrap", function()
        it("breaks on word boundaries", function()
            local lines = render.wrap("the quick brown fox", 10)
            assert.are.equal("the quick", lines[1])
            assert.are.equal("brown fox", lines[2])
        end)

        it(
            "keeps short text on one line",
            function() assert.are.same({ "hello" }, render.wrap("hello", 20)) end
        )

        it("hard-splits a word wider than the line", function()
            local lines = render.wrap("supercalifragilistic", 8)
            for _, line in ipairs(lines) do
                assert.is_true(render.display_width(line) <= 8)
            end
        end)

        it(
            "preserves paragraph breaks",
            function()
                assert.are.same({ "a", "", "b" }, render.wrap("a\n\nb", 10))
            end
        )
    end)
end)
