local kitty_sprites = require("tamagotchi.sprites.kitty")
local lucy_sprites = require("tamagotchi.sprites.lucy")
local doggo_sprites = require("tamagotchi.sprites.doggo")
local bunny_sprites = require("tamagotchi.sprites.bunny")
local dragon_sprites = require("tamagotchi.sprites.dragon")
local bear_sprites = require("tamagotchi.sprites.bear")
local po_sprites = require("tamagotchi.sprites.po")

local M = {}

M.defaults = {
    -- Set to false to bind nothing; :Tamagotchi always works regardless.
    window_toggle_keybind = "<leader>tg",

    -- How often the simulation advances while the window is open, and while it
    -- is not. Decay is elapsed-based, so the idle rate costs nothing in accuracy.
    tick_length_ms = 1000,
    idle_tick_ms = 60000,

    -- Upper bound on how much time away can be charged in one go, so coming
    -- back after a holiday does not instantly flatten the pet.
    max_offline_decay_seconds = 8 * 3600,

    -- Off by default, deliberately: turning permadeath on for everyone in an
    -- update would quietly kill pets people have kept for months. Opt in.
    stakes = false,
    sick_after_seconds = 6 * 3600,
    death_after_seconds = 24 * 3600,

    ui = {
        -- "auto" follows 'winborder' when the user has set it, else rounded.
        -- Any value nvim_open_win accepts also works here, including a table.
        border = "auto",

        -- Draw with ASCII instead of block glyphs, for terminals and fonts that
        -- render the Unicode ones badly.
        ascii = false,
    },

    -- "builtin" is the animated menu with sprite previews. "native" hands the
    -- pet list to vim.ui.select, so telescope / snacks / fzf-lua users get the
    -- picker they already configured.
    picker = "builtin",

    default_pet = "Sasha",
    pets = {
        {
            name = "Bunny",
            color_theme = "magenta",

            sprite_update_interval = 2,
            sprites = bunny_sprites,

            initial_mood = 75,
            initial_satiety = 65,
            decay_speed = 3,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 4,
                    satiety_increment = 6,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 5,
                    satiety_increment = 1,
                },
            },
        },

        {
            name = "Churro",
            color_theme = "yellow",

            sprite_update_interval = 2,
            sprites = doggo_sprites,

            initial_mood = 80,
            initial_satiety = 70,
            decay_speed = 2,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 6,
                    satiety_increment = 2,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 3,
                    satiety_increment = 3,
                },
            },
        },

        {
            name = "Dragon",
            color_theme = "green",

            sprite_update_interval = 3,
            sprites = dragon_sprites,

            initial_mood = 65,
            initial_satiety = 75,
            decay_speed = 1,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 2,
                    satiety_increment = 4,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 3,
                    satiety_increment = 3,
                },
            },
        },

        {
            name = "Lucy",
            color_theme = "red",

            sprite_update_interval = 3,
            sprites = lucy_sprites,

            initial_mood = 70,
            initial_satiety = 80,
            decay_speed = 3,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 3,
                    satiety_increment = 5,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 4,
                    satiety_increment = 2,
                },
            },
        },

        {
            name = "Grizz",
            color_theme = "white",

            sprite_update_interval = 3,
            sprites = bear_sprites,

            initial_mood = 70,
            initial_satiety = 60,
            decay_speed = 4,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 3,
                    satiety_increment = 7,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 2,
                    satiety_increment = 2,
                },
            },
        },

        {
            name = "Po",
            color_theme = "cyan",

            sprite_update_interval = 2,
            sprites = po_sprites,

            initial_mood = 80,
            initial_satiety = 70,
            decay_speed = 2,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 4,
                    satiety_increment = 4,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 3,
                    satiety_increment = 2,
                },
            },
        },

        {
            name = "Sasha",
            color_theme = "blue",

            sprite_update_interval = 2,
            sprites = kitty_sprites,

            initial_mood = 75,
            initial_satiety = 75,
            decay_speed = 2,

            vim_events = {
                {
                    name = "BufWritePost",
                    mood_increment = 5,
                    satiety_increment = 3,
                },
                {
                    name = "TextYankPost",
                    mood_increment = 2,
                    satiety_increment = 1,
                },
            },
        },
    },
}

M.values = {}

local function is_positive_integer(v)
    return type(v) == "number" and v >= 1 and v % 1 == 0
end

-- Validate a single vim event definition
local function validate_vim_event(event)
    assert(type(event) == "table", "vim event must be a table")
    assert(
        type(event.name) == "string" and #event.name > 0,
        "vim event must have a non-empty name"
    )
    assert(
        type(event.mood_increment) == "number",
        "mood_increment must be a number"
    )
    assert(
        type(event.satiety_increment) == "number",
        "satiety_increment must be a number"
    )
end

-- Validate a pet definition
local function validate_pet(pet)
    assert(type(pet) == "table", "pet must be a table")
    assert(
        type(pet.name) == "string" and #pet.name > 0,
        "pet must have a non-empty name"
    )

    if pet.sprites then
        assert(type(pet.sprites) == "table", "sprites must be a table")
    end

    if pet.vim_events then
        assert(type(pet.vim_events) == "table", "vim_events must be a table")
        for i, event in ipairs(pet.vim_events) do
            local ok, err = pcall(validate_vim_event, event)
            if not ok then
                error(
                    string.format(
                        "Invalid vim_event at index %d for pet '%s': %s",
                        i,
                        pet.name,
                        err
                    )
                )
            end
        end
    end

    if pet.initial_mood then
        assert(
            type(pet.initial_mood) == "number",
            "initial_mood must be a number"
        )
        assert(
            pet.initial_mood >= 1 and pet.initial_mood <= 100,
            "initial_mood must be between 1 and 100"
        )
    end

    if pet.initial_satiety then
        assert(
            type(pet.initial_satiety) == "number",
            "initial_satiety must be a number"
        )
        assert(
            pet.initial_satiety >= 1 and pet.initial_satiety <= 100,
            "initial_satiety must be between 1 and 100"
        )
    end

    if pet.decay_speed then
        assert(
            type(pet.decay_speed) == "number",
            "decay_speed must be a number"
        )
        assert(
            pet.decay_speed >= 0 and pet.decay_speed <= 6,
            "decay_speed must be between 0 and 6"
        )
        -- The rates are a lookup table, so 2.5 would silently fall back to 3.
        assert(pet.decay_speed % 1 == 0, "decay_speed must be a whole number")
    end

    if pet.sprite_update_interval then
        assert(
            is_positive_integer(pet.sprite_update_interval),
            "sprite_update_interval must be a positive whole number"
        )
    end
end

-- Top-level options. Pet definitions are checked separately by validate_pet.
local function validate_options(opts)
    for key in pairs(opts) do
        if M.defaults[key] == nil then
            vim.notify(
                ("tamagotchi: unknown option '%s' is ignored"):format(key),
                vim.log.levels.WARN
            )
        end
    end

    local keybind = opts.window_toggle_keybind
    assert(
        keybind == false or (type(keybind) == "string" and #keybind > 0),
        "window_toggle_keybind must be a non-empty string or false"
    )

    -- A 0ms repeat makes libuv fire once and stop, which kills the simulation.
    assert(
        is_positive_integer(opts.tick_length_ms),
        "tick_length_ms must be a positive whole number"
    )
    assert(
        is_positive_integer(opts.idle_tick_ms),
        "idle_tick_ms must be a positive whole number"
    )

    for _, key in ipairs({
        "max_offline_decay_seconds",
        "sick_after_seconds",
        "death_after_seconds",
    }) do
        assert(
            type(opts[key]) == "number" and opts[key] >= 0,
            key .. " must be a non-negative number"
        )
    end
    assert(
        opts.sick_after_seconds <= opts.death_after_seconds,
        "sick_after_seconds must not exceed death_after_seconds"
    )

    assert(type(opts.stakes) == "boolean", "stakes must be a boolean")

    assert(type(opts.ui) == "table", "ui must be a table")
    local border = opts.ui.border
    assert(
        type(border) == "string" or type(border) == "table",
        "ui.border must be a string or a table"
    )
    assert(type(opts.ui.ascii) == "boolean", "ui.ascii must be a boolean")

    assert(
        opts.picker == "builtin" or opts.picker == "native",
        'picker must be "builtin" or "native"'
    )
end

local function shallow_copy(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end

-- Two pets whose names slug to the same token would share a save file and
-- silently clobber each other. Case-insensitive, because macOS folds case.
local function assert_unique_names(pets)
    local store = require("tamagotchi.store")
    local seen = {}

    for _, pet in ipairs(pets) do
        local key = store.slug(pet.name):lower()
        assert(
            not seen[key],
            ("duplicate pet name '%s' (conflicts with '%s')"):format(
                pet.name,
                seen[key]
            )
        )
        seen[key] = pet.name
    end
end

function M.setup(user_config)
    user_config = user_config or {}

    assert(
        M.defaults.pets,
        "M.defaults.pets is nil. Ensure pets are defined in defaults."
    )

    -- `pets` is a list, and tbl_deep_extend merges lists index-wise -- so a user
    -- supplying one pet would overwrite fields of the first default pet rather
    -- than adding to the roster. Merge the scalar options only, and assemble
    -- the roster by hand below.
    local default_opts, user_opts =
        shallow_copy(M.defaults), shallow_copy(user_config)
    default_opts.pets, user_opts.pets = nil, nil
    local combined = vim.tbl_deep_extend("force", {}, default_opts, user_opts)
    validate_options(combined)

    -- Copies, never the originals. v1 inserted M.defaults.pets[i] directly, and
    -- Pet:new then adopted that very table as the live pet -- so a pet's runtime
    -- mood and birth_time ended up on the module-level defaults, surviving into
    -- the next setup() call. `sprites` and `vim_events` are shared by reference
    -- on purpose: large, and never mutated.
    local all_pets = {}

    for _, pet in ipairs(M.defaults.pets) do
        local copy = shallow_copy(pet)
        copy.native = true
        validate_pet(copy)
        table.insert(all_pets, copy)
    end

    for _, pet in ipairs(user_config.pets or {}) do
        local copy = shallow_copy(pet)
        copy.native = false
        validate_pet(copy)
        table.insert(all_pets, copy)
    end

    assert_unique_names(all_pets)
    table.sort(all_pets, function(a, b) return a.name < b.name end)

    local default_pet = combined.default_pet
    assert(
        vim.iter(all_pets):any(function(p) return p.name == default_pet end),
        ("default_pet '%s' does not match any configured pet"):format(
            tostring(default_pet)
        )
    )

    combined.pets = all_pets
    M.values = combined
end

return M
