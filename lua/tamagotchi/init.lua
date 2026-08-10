local config = require("tamagotchi.config")

local M = {}

M._did_setup = false
M._keybind = nil

local EVENTS_AUGROUP = "TamagotchiEvents"
local LIFECYCLE_AUGROUP = "TamagotchiLifecycle"

local MIN_NVIM = "nvim-0.10"

-- Point the plugin at a pet and (re)install that pet's vim_events.
--
-- v1 registered these once in setup() from the initial pet, so switching pets
-- in the menu left the previous pet's event list and increments installed.
function M.bind_pet(pet)
    _G.tamagotchi_pet = pet

    -- One group for all events, so this single call is the whole teardown.
    local group = vim.api.nvim_create_augroup(EVENTS_AUGROUP, { clear = true })
    if not pet or not pet.vim_events then return end

    for _, evt in ipairs(pet.vim_events) do
        vim.api.nvim_create_autocmd(evt.name, {
            pattern = "*",
            group = group,
            callback = function()
                require("tamagotchi.event_handler").on_event(
                    evt.name,
                    evt.mood_increment,
                    evt.satiety_increment
                )
            end,
        })
    end
end

function M.teardown()
    pcall(require("tamagotchi.tick").stop)

    local window = package.loaded["tamagotchi.window"]
    if window then pcall(window.close, _G.tamagotchi_pet) end

    pcall(vim.api.nvim_create_augroup, EVENTS_AUGROUP, { clear = true })
    pcall(vim.api.nvim_create_augroup, LIFECYCLE_AUGROUP, { clear = true })

    if M._keybind then
        pcall(vim.keymap.del, "n", M._keybind)
        M._keybind = nil
    end

    M._did_setup = false
end

function M.setup(user_config)
    if vim.fn.has(MIN_NVIM) == 0 then
        vim.notify(
            "tamagotchi.nvim requires Neovim 0.10 or newer",
            vim.log.levels.ERROR
        )
        return
    end

    -- Idempotent: plugin/tamagotchi.lua may have already run a default setup,
    -- and a user re-sourcing their config should not accumulate a second pet,
    -- keymap and timer the way v1 did.
    if M._did_setup then M.teardown() end

    config.setup(user_config)

    local store = require("tamagotchi.store")
    store.migrate_legacy()

    M.bind_pet(store.resolve_startup_pet())

    local keybind = config.values.window_toggle_keybind
    if keybind then
        vim.keymap.set(
            "n",
            keybind,
            function() require("tamagotchi.window").toggle(_G.tamagotchi_pet) end,
            { silent = true, desc = "Toggle tamagotchi" }
        )
        M._keybind = keybind
    end

    vim.api.nvim_create_autocmd("VimLeavePre", {
        pattern = "*",
        group = vim.api.nvim_create_augroup(
            LIFECYCLE_AUGROUP,
            { clear = true }
        ),
        callback = function()
            if _G.tamagotchi_pet then
                require("tamagotchi.store").save_pet(_G.tamagotchi_pet)
            end
        end,
    })

    require("tamagotchi.tick").start()
    require("tamagotchi.statusline").invalidate()

    -- Present even when the user loads the plugin without going through
    -- plugin/tamagotchi.lua (lazy loaders, tests).
    if vim.fn.exists(":Tamagotchi") == 0 then
        require("tamagotchi.command").setup()
    end

    M._did_setup = true
end

-- Called by every :Tamagotchi handler, so the command works for users who
-- never wrote a setup{} call and before VimEnter has fired.
function M.ensure_setup()
    if not M._did_setup then M.setup() end
    return _G.tamagotchi_pet
end

return M
