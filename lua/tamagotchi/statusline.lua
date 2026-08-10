-- Statusline / winbar / tabline component.
--
-- The premise of this plugin is a pet living alongside you across sessions, but
-- without this the pet is invisible unless you open a modal float.
--
-- Statuslines re-evaluate on nearly every keystroke, so the string is built once
-- per tick and cached; `get()` is just a table lookup.
local M = {}

M._cache = nil

local ICONS = {
    unicode = {
        alive = "🐱",
        sick = "🤒",
        dead = "💀",
        mood = "♥",
        satiety = "🍖",
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
    return ICONS.unicode
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
    parts[#parts + 1] = ("%s%d"):format(set.mood, math.floor(pet:get_mood()))
    parts[#parts + 1] = ("%s%d"):format(
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
