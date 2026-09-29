-- `:checkhealth tamagotchi`.
--
-- Reports the things that have historically gone wrong silently: an unwritable
-- data directory, a save that never loads, a `default_pet` that does not name a
-- real pet, a keybind another plugin already took.
local M = {}

local health = vim.health

local function check_version()
    health.start("neovim")

    if vim.fn.has("nvim-0.10") == 1 then
        health.ok("neovim " .. tostring(vim.version()))
    else
        health.error("neovim 0.10 or newer is required", {
            "tamagotchi.nvim uses vim.uv and vim.fs.joinpath, added in 0.10.",
        })
    end
end

local function check_setup()
    health.start("setup")

    local tamagotchi = require("tamagotchi")

    if not tamagotchi._did_setup then
        health.warn("setup() has not run yet", {
            "It runs automatically on VimEnter, so this is expected only if you",
            "are checking health very early in startup.",
        })
        return false
    end

    health.ok("setup() has run")

    if _G.tamagotchi_pet then
        local pet = _G.tamagotchi_pet
        health.ok(
            ("active pet: %s (mood %d, satiety %d, age %s)"):format(
                pet.name or "unnamed",
                math.floor(pet:get_mood()),
                math.floor(pet:get_satiety()),
                pet:get_age_formatted()
            )
        )
        if pet:health_state() ~= "alive" then
            health.warn(("pet is %s"):format(pet:health_state()))
        end
    else
        health.error("no active pet")
    end

    return true
end

local function check_storage()
    health.start("storage")

    local store = require("tamagotchi.store")
    local root = store.root()

    -- Actually write, rather than trusting the mode bits.
    vim.fn.mkdir(root, "p")
    local probe = vim.fs.joinpath(root, ".health-probe")
    local wrote = pcall(vim.fn.writefile, { "ok" }, probe)

    if wrote and vim.fn.filereadable(probe) == 1 then
        health.ok("data directory is writable: " .. root)
        vim.fn.delete(probe)
    else
        health.error("cannot write to " .. root, {
            "Check permissions on " .. vim.fn.stdpath("data"),
        })
    end

    local saved = store.list_saved_pets()
    if #saved == 0 then
        health.info("no pets saved yet")
    else
        health.ok(("%d pet save(s) in %s"):format(#saved, store.pets_dir()))
    end

    local state = store.read_state()
    if state.last_active_pet then
        health.ok("last active pet: " .. state.last_active_pet)
    else
        health.info("no last-active pet recorded")
    end

    -- Surface the v1 -> v2 migration, since it is the reason saves work at all.
    local legacy =
        vim.fn.glob(vim.fn.stdpath("data") .. "/tamagotchi_*.json", false, true)
    if #legacy > 0 then
        if state.legacy_migrated then
            health.info(
                ("%d pre-v2 save file(s) were migrated and left in place"):format(
                    #legacy
                ),
                { "They are no longer read, and can be deleted." }
            )
        else
            health.warn(
                ("%d pre-v2 save file(s) not yet migrated"):format(#legacy)
            )
        end
    end
end

local function check_config()
    health.start("configuration")

    local config = require("tamagotchi.config").values
    local pets = config.pets or {}

    if #pets == 0 then
        health.error("no pets configured")
        return
    end
    health.ok(("%d pet(s) configured"):format(#pets))

    health.ok("default_pet: " .. config.default_pet)

    -- Empty sprite sets render as a blank pet, which looks like a broken window.
    for _, pet in ipairs(pets) do
        local empty = {}
        for _, state in ipairs({ "happy", "hungry", "neutral" }) do
            local frames = pet.sprites and pet.sprites[state]
            if not frames or #frames == 0 then empty[#empty + 1] = state end
        end
        if #empty > 0 then
            health.warn(
                ("pet '%s' has no frames for: %s"):format(
                    pet.name,
                    table.concat(empty, ", ")
                )
            )
        end
    end

    if config.stakes then
        health.info("stakes enabled: pets can get sick and die")
    else
        health.info("stakes disabled (default): pets cannot die")
    end

    health.info("picker: " .. config.picker)
end

local function check_keymap()
    health.start("keymap")

    local config = require("tamagotchi.config").values
    local keybind = config.window_toggle_keybind

    if not keybind then
        health.info("window_toggle_keybind is disabled; use :Tamagotchi")
        return
    end

    local found = false
    for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
        if map.lhs == vim.keycode(keybind) or map.lhs == keybind then
            found = true
            if map.desc == "Toggle tamagotchi" then
                health.ok(("%s is mapped to tamagotchi"):format(keybind))
            else
                health.warn(
                    ("%s is mapped to something else: %s"):format(
                        keybind,
                        map.desc or map.rhs or "?"
                    ),
                    { "Use :Tamagotchi, or set window_toggle_keybind." }
                )
            end
            break
        end
    end

    if not found then health.warn(("%s is not mapped"):format(keybind)) end
end

local function check_tick()
    health.start("simulation")

    local tick = require("tamagotchi.tick")

    if tick.is_running() then
        health.ok(("tick running every %dms"):format(tick.period_ms()))
    else
        health.error("tick is not running", {
            "The pet will not age or decay. Try :Tamagotchi to re-initialise.",
        })
    end
end

function M.check()
    check_version()
    local ready = check_setup()
    check_storage()
    check_config()
    check_keymap()
    if ready then check_tick() end
end

return M
