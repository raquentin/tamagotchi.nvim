local render = require("tamagotchi.render")
local config = require("tamagotchi.config")
local assert = require("luassert")

local SPRITE_SETS =
    { "kitty", "lucy", "doggo", "bunny", "dragon", "bear", "po" }
local STATES = { "happy", "hungry", "neutral" }

-- Guards the two things that made the animation look broken: frames that were
-- different widths (so the sprite slid sideways as it played) and frames whose
-- body rows were byte-identical (so only the face appeared to move).
describe("sprite sets", function()
    before_each(function() config.setup() end)

    for _, name in ipairs(SPRITE_SETS) do
        describe(name, function()
            local set = require("tamagotchi.sprites." .. name)

            it("defines every state", function()
                for _, state in ipairs(STATES) do
                    assert.is_table(set[state], state .. " missing")
                    assert.is_true(#set[state] >= 2, state .. " needs frames")
                end
            end)

            it("normalizes to one size across every frame", function()
                local box = render.sprite_box(set)

                for _, state in ipairs(STATES) do
                    for i, frame in ipairs(set[state]) do
                        local lines = render.normalize_frame(frame, box)
                        assert.are.equal(
                            box.rows,
                            #lines,
                            ("%s %s frame %d row count"):format(name, state, i)
                        )
                        for _, line in ipairs(lines) do
                            assert.are.equal(
                                box.width,
                                render.display_width(line),
                                ("%s %s frame %d width"):format(name, state, i)
                            )
                        end
                    end
                end
            end)

            it("moves more than one row per state", function()
                local box = render.sprite_box(set)

                for _, state in ipairs(STATES) do
                    local frames = {}
                    for _, frame in ipairs(set[state]) do
                        frames[#frames + 1] = render.normalize_frame(frame, box)
                    end

                    local moving = 0
                    for row = 1, box.rows do
                        local seen, count = {}, 0
                        for _, f in ipairs(frames) do
                            if not seen[f[row]] then
                                seen[f[row]] = true
                                count = count + 1
                            end
                        end
                        if count > 1 then moving = moving + 1 end
                    end

                    assert.is_true(
                        moving >= 2,
                        ("%s %s animates only %d row(s); a face swap over a "):format(
                            name,
                            state,
                            moving
                        )
                            .. "frozen body does not read as alive"
                    )
                end
            end)

            it("has no blank trailing row", function()
                local box = render.sprite_box(set)
                local lines = render.normalize_frame(set.happy[1], box)
                assert.is_truthy(
                    lines[#lines]:find("%S"),
                    name .. " ends with an empty sprite row"
                )
            end)
        end)
    end

    it("is wired into config for every set that ships", function()
        local used = {}
        for _, pet in ipairs(config.values.pets) do
            used[tostring(pet.sprites)] = true
        end

        for _, name in ipairs(SPRITE_SETS) do
            local set = require("tamagotchi.sprites." .. name)
            assert.is_true(
                used[tostring(set)] or false,
                name .. " is not used by any pet"
            )
        end
    end)
end)
