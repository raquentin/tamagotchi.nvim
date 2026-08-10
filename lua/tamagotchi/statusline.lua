-- Statusline / winbar / tabline component.
--
-- The premise of this plugin is a pet living alongside you across sessions, but
-- without this the pet is invisible unless you open a modal float.
--
-- Statuslines re-evaluate on nearly every keystroke, so the string is built once
-- per tick and cached; `get()` is just a table lookup.
local M = {}

M._cache = nil

-- Nerd Font glyphs rather than emoji: emoji render at double width in some
-- terminals and not at all in others, and a statusline is the one place where a
-- glyph that measures wrong shifts everything after it. `satiety` is cutlery,
-- not a food item -- an icon for "has eaten" should not name a food.
local ICONS = {
    nerd = {
        alive = "\u{f1b0}", -- nf-fa-paw
        sick = "\u{f0c0a}", -- nf-md-emoticon_sick
        dead = "\u{f068c}", -- nf-md-skull
        mood = "\u{f004}", -- nf-fa-heart
        satiety = "\u{f0f5}", -- nf-fa-cutlery
    },
    ascii = {
        alive = ":3",
        sick = ":(",
        dead = "x_x",
        mood = "m",
        satiety = "s",
    },
}

local function icons(opts)
    if opts.ascii then return ICONS.ascii end
    return ICONS.nerd
end

-- Drop the cache so the next get() rebuilds. Called by the tick and by anything
-- that changes a stat out of band.
function M.invalidate() M._cache = nil end

function M.build(pet, opts)
    opts = opts or {}
    if not pet then return "" end

    local set = icons(opts)
    local state = pet:health_state()

    if state == "dead" then
        return ("%s %s"):format(set.dead, pet.name or "pet")
    end

    local face = (state == "sick") and set.sick or set.alive

    local parts = { face }
    if opts.name ~= false then parts[#parts + 1] = pet.name end
    -- Space between glyph and number: Nerd Font icons occupy one cell as far as
    -- the terminal is concerned but are drawn wider than one, so without it the
    -- icon paints over the first digit.
    parts[#parts + 1] = ("%s %d"):format(set.mood, math.floor(pet:get_mood()))
    parts[#parts + 1] = ("%s %d"):format(
        set.satiety,
        math.floor(pet:get_satiety())
    )

    return table.concat(parts, " ")
end

-- The cached string. Safe to call from a statusline expression.
--
--   vim.o.statusline = "%!v:lua.require'tamagotchi.statusline'.get()"
--   -- or, inside a Lua statusline builder:
--   require("tamagotchi.statusline").get({ ascii = true })
function M.get(opts)
    if M._cache then return M._cache end

    local ok, result = pcall(M.build, _G.tamagotchi_pet, opts)
    M._cache = ok and result or ""

    return M._cache
end

-- Same string wrapped in the pet's colour, for statuslines that render
-- highlight groups.
function M.get_colored(opts)
    local text = M.get(opts)
    if text == "" then return "" end

    local pet = _G.tamagotchi_pet
    local theme = pet and pet.color_theme
    if not theme then return text end

    local group = "TamagotchiColor" .. theme:sub(1, 1):upper() .. theme:sub(2)
    return ("%%#%s#%s%%*"):format(group, text)
end

return M
