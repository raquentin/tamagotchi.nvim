-- The simulation clock, deliberately separate from the UI.
--
-- v1 owned this inside window.lua, where a single timer both advanced the pet
-- and redrew the float -- so its "the float is gone" branch stopped the timer.
-- Since setup() started the loop with no window open and a 0ms first tick, the
-- simulation was dead before the user ever saw it, and decay only ever ran
-- while the float happened to be visible.
local M = {}

M.timer = nil
M.sprite_counter = 0
M.autosave_counter = 0
M.last_sprite = ""

-- Ticks between autosaves. v1 only saved on VimLeavePre, so a crash or a
-- `kill -9` silently discarded the whole session.
M.autosave_every = 60

-- Current period, so retime() can avoid pointlessly restarting the timer.
M._period_ms = nil

local function config() return require("tamagotchi.config").values end

local function window_is_open()
    local window = package.loaded["tamagotchi.window"]
    return window ~= nil and window.is_open()
end

-- Animation needs 1Hz, but decay does not: it is a function of elapsed wall
-- time, so a coarse tick costs exactly the same as a fine one. Idling at 60s
-- keeps the plugin from waking the editor every second to do nothing.
function M.period_ms()
    local values = config()
    if window_is_open() then return values.tick_length_ms or 1000 end
    return values.idle_tick_ms or 60000
end

function M.is_running() return M.timer ~= nil and not M.timer:is_closing() end

function M.tick()
    local pet = _G.tamagotchi_pet
    if not pet then return end

    pet:apply_decay()

    M.sprite_counter = M.sprite_counter + 1
    local advance = M.sprite_counter >= (pet.sprite_update_interval or 5)
    if advance then M.sprite_counter = 0 end

    local window = package.loaded["tamagotchi.window"]
    if window then window.on_tick(pet, advance) end

    -- Statuslines redraw far more often than once a second, so the component
    -- string is rebuilt here rather than on every redraw.
    local statusline = package.loaded["tamagotchi.statusline"]
    if statusline then statusline.invalidate() end

    M.autosave_counter = M.autosave_counter + 1
    if M.autosave_counter >= M.autosave_every then
        M.autosave_counter = 0
        require("tamagotchi.store").save_pet(pet)
    end
end

-- Run one tick immediately, outside the timer. Used by tests and by :Tamagotchi.
function M.force() M.tick() end

function M.stop()
    if M.timer then
        if not M.timer:is_closing() then
            M.timer:stop()
            M.timer:close()
        end
        M.timer = nil
    end
    M._period_ms = nil
end

function M.start()
    M.stop()

    local period = M.period_ms()
    M._period_ms = period

    M.timer = vim.uv.new_timer()
    -- First fire after one full period, not immediately: a 0ms first tick is
    -- what made v1's loop self-destruct before setup() had finished.
    M.timer:start(period, period, vim.schedule_wrap(function() M.tick() end))
end

-- Re-arm at the period the current window state calls for. No-op if unchanged.
function M.retime()
    if not M.is_running() then return end

    local period = M.period_ms()
    if period == M._period_ms then return end

    M._period_ms = period
    M.timer:stop()
    M.timer:start(period, period, vim.schedule_wrap(function() M.tick() end))
end

return M
