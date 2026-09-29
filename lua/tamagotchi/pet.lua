local render = require("tamagotchi.render")

local Pet = {}
Pet.__index = Pet

Pet.MIN_STAT = 1
Pet.MAX_STAT = 100

-- Bumped when the on-disk shape changes. v1 files have no version field.
Pet.SCHEMA_VERSION = 2

-- Points lost per second. These are the v1 numbers unchanged: they used to be
-- "probability of losing 1 point on a 1s tick", whose expected value is already
-- points-per-second, so switching from a coin flip to rate x elapsed leaves the
-- average decay identical.
local DECAY_RATES = {
    [0] = { mood = 0.0, satiety = 0.0 },
    [1] = { mood = 0.01, satiety = 0.01 },
    [2] = { mood = 0.03, satiety = 0.03 },
    [3] = { mood = 0.05, satiety = 0.05 },
    [4] = { mood = 0.08, satiety = 0.08 },
    [5] = { mood = 0.12, satiety = 0.12 },
    [6] = { mood = 0.20, satiety = 0.20 },
}

local DEFAULT_DECAY_SPEED = 3
local DEFAULT_SPRITE_INTERVAL = 5

-- Copied from a config pet definition.
local DEF_FIELDS = {
    "name",
    "sprites",
    "vim_events",
    "sprite_update_interval",
    "initial_mood",
    "initial_satiety",
    "decay_speed",
    "native",
}

-- Persisted to disk, and the allowlist `to_table` serializes.
--
-- Deliberately excludes `sprites` and `vim_events`: v1 wrote the whole sprite
-- table into every save (tens of KB of ASCII art), and worse, on load the
-- constructor then saw `sprites` already set and skipped re-resolving it from
-- config -- so sprite improvements shipped in an upgrade never reached an
-- existing pet.
--
-- Also excludes `session_start_time`, which must be per-session; v1 round-tripped
-- it, so the settings screen reported the save file's lifetime as session time.
local SAVE_FIELDS = {
    "name",
    "mood",
    "satiety",
    "birth_time",
    "last_decay_time",
    "last_seen_time",
    "color_theme",
    "decay_speed",
    "initial_mood",
    "initial_satiety",
    "sprite_update_interval",
    "total_vim_events",
    "total_mood_gained",
    "total_satiety_gained",
    "times_fed",
    "times_played_with",
    "times_petted",
    "times_cleaned",
    "last_interaction",
    "interaction_streak",
    "low_since",
    "died_at",
    "schema_version",
    -- Bumped on every write, so an instance can tell another one saved since.
    "rev",
}

Pet.DEF_FIELDS = DEF_FIELDS
Pet.SAVE_FIELDS = SAVE_FIELDS

local function clamp(value)
    return math.max(Pet.MIN_STAT, math.min(Pet.MAX_STAT, value))
end

local function find_pet_def_by_name(name)
    local config = require("tamagotchi.config").values
    if not name or not config.pets then return nil end

    for _, pet_def in ipairs(config.pets) do
        if pet_def.name == name then return pet_def end
    end

    return nil
end

-- Counters that simply start at zero.
local ZERO_FIELDS = {
    "total_vim_events",
    "total_mood_gained",
    "total_satiety_gained",
    "times_fed",
    "times_played_with",
    "times_petted",
    "times_cleaned",
}

Pet.COUNTER_FIELDS = ZERO_FIELDS

-- Timestamps that default to "now" when absent.
local NOW_FIELDS = { "birth_time", "last_decay_time", "last_seen_time" }

-- Sprites and events always come from config, never from a save file, so a
-- plugin upgrade that improves the art reaches existing pets.
local function resolve_from_config(p)
    local pet_def = p.name and find_pet_def_by_name(p.name)
    if pet_def then
        p.sprites = p.sprites or pet_def.sprites
        p.vim_events = p.vim_events or pet_def.vim_events

        -- A pet's colour is part of its art, so a save written before the
        -- defaults existed still picks one up. A colour the user chose in
        -- settings is already non-nil here, and wins.
        if p.color_theme == nil then p.color_theme = pet_def.color_theme end
    end

    if p.sprites then return end

    vim.notify(
        string.format(
            "pet '%s' has no sprites! using empty sprite sets.",
            p.name or "unknown"
        ),
        vim.log.levels.DEBUG
    )
    p.sprites = { happy = {}, hungry = {}, neutral = {} }
end

local function apply_decay_rates(p, config)
    if p.decay_speed == nil then p.decay_speed = DEFAULT_DECAY_SPEED end

    local rates = DECAY_RATES[p.decay_speed] or DECAY_RATES[DEFAULT_DECAY_SPEED]
    p.mood_decay_rate = rates.mood
    p.satiety_decay_rate = rates.satiety
    p.max_offline_decay_seconds = config.max_offline_decay_seconds or (8 * 3600)
end

local function apply_defaults(p, config)
    p.initial_mood = p.initial_mood or 80
    p.initial_satiety = p.initial_satiety or 80
    p.mood = p.mood or p.initial_mood
    p.satiety = p.satiety or p.initial_satiety

    p.sprite_update_interval = p.sprite_update_interval
        or DEFAULT_SPRITE_INTERVAL

    apply_decay_rates(p, config)

    local now = os.time()
    for _, k in ipairs(NOW_FIELDS) do
        p[k] = p[k] or now
    end
    for _, k in ipairs(ZERO_FIELDS) do
        p[k] = p[k] or 0
    end

    p.last_interaction = p.last_interaction or {}
    p.interaction_streak = p.interaction_streak or {}

    -- Always fresh: this measures the current editing session, not the save.
    p.session_start_time = now
end

function Pet:new(o)
    o = o or {}

    -- A fresh table, never `o` itself. v1 called setmetatable(o, self) where `o`
    -- *was* config.values.pets[i], which turned the config definition into the
    -- live pet: two Pet:new calls on one def returned the same object, and
    -- "start new life" silently inherited the previous life's stats.
    local p = setmetatable({}, Pet)

    for _, k in ipairs(DEF_FIELDS) do
        p[k] = o[k]
    end
    for _, k in ipairs(SAVE_FIELDS) do
        if o[k] ~= nil then p[k] = o[k] end
    end

    if not p.name then
        vim.notify("pet created without a name!", vim.log.levels.DEBUG)
    end

    resolve_from_config(p)
    apply_defaults(p, require("tamagotchi.config").values)

    p.schema_version = Pet.SCHEMA_VERSION

    -- Per-instance animation cursor; never shared, never persisted.
    p.sprite_indices = { happy = 1, hungry = 1, neutral = 1 }
    p.last_state = nil

    -- Stat changes since the last save that did not come from decay, so a save
    -- that finds another instance's write can replay them on top of it.
    p.pending = { mood = 0, satiety = 0 }

    return p
end

-- Build a pet from a config definition. Same as `new`, but says what it means.
function Pet.from_def(def, overrides)
    local seed = {}
    for k, v in pairs(def or {}) do
        seed[k] = v
    end
    for k, v in pairs(overrides or {}) do
        seed[k] = v
    end
    return Pet:new(seed)
end

function Pet:set_name(value)
    assert(type(value) == "string", "name must be a string")
    assert(#value > 0, "name cannot be empty")
    self.name = value
end

function Pet:get_name() return self.name end

function Pet:get_satiety() return self.satiety end

function Pet:set_satiety(value)
    assert(type(value) == "number", "satiety must be a number")
    local before = self.satiety
    self.satiety = clamp(value)
    self.pending.satiety = self.pending.satiety + self.satiety - before
end

function Pet:get_mood() return self.mood end

function Pet:set_mood(value)
    assert(type(value) == "number", "mood must be a number")
    local before = self.mood
    self.mood = clamp(value)
    self.pending.mood = self.pending.mood + self.mood - before
end

function Pet:get_age(now) return (now or os.time()) - self.birth_time end

function Pet:get_age_formatted(now)
    local elapsed = math.max(0, math.floor(self:get_age(now)))

    local years = math.floor(elapsed / (365 * 24 * 3600))
    elapsed = elapsed - years * 365 * 24 * 3600
    local days = math.floor(elapsed / (24 * 3600))
    elapsed = elapsed - days * 24 * 3600
    local hours = math.floor(elapsed / 3600)
    elapsed = elapsed - hours * 3600
    local minutes = math.floor(elapsed / 60)
    local seconds = elapsed - minutes * 60

    local parts = {}
    local started = false

    if years > 0 then
        started = true
        table.insert(parts, years .. "yr")
    end
    if started or days > 0 then
        started = true
        table.insert(parts, days .. "day")
    end
    if started or hours > 0 then
        started = true
        table.insert(parts, hours .. "hr")
    end
    if started or minutes > 0 then table.insert(parts, minutes .. "min") end

    table.insert(parts, seconds .. "sec")

    return table.concat(parts, " ")
end

-- Serialize only the allowlisted fields.
function Pet:to_table()
    local t = {}
    for _, k in ipairs(SAVE_FIELDS) do
        if self[k] ~= nil then t[k] = self[k] end
    end
    return t
end

-- Charge the pet for wall-clock time since it was last charged.
--
-- Idempotent over wall time: calling this twice in the same second is a no-op,
-- and N calls across an interval cost exactly what one call at the end would.
-- That property is why v1's three separate retroactive-decay approximations
-- (on load, on window open, and per tick, each with its own cap and floor)
-- collapse into this single method.
-- Stats at or below this count as neglect, and start the illness clock.
Pet.LOW_STAT = 10

function Pet:is_neglected()
    return self.mood <= Pet.LOW_STAT or self.satiety <= Pet.LOW_STAT
end

-- "alive" | "sick" | "dead", derived from how long the pet has been neglected.
--
-- Elapsed-based rather than tick-counted, so it behaves the same whether you
-- left Neovim running or closed it. Returns "alive" unless `stakes` is enabled.
function Pet:health_state(now)
    local config = require("tamagotchi.config").values
    if not config.stakes then return "alive" end

    if self.died_at then return "dead" end
    if not self.low_since then return "alive" end

    local neglected_for = (now or os.time()) - self.low_since

    if neglected_for >= (config.death_after_seconds or 24 * 3600) then
        return "dead"
    end
    if neglected_for >= (config.sick_after_seconds or 6 * 3600) then
        return "sick"
    end
    return "alive"
end

function Pet:is_dead() return self:health_state() == "dead" end

function Pet:apply_decay(now)
    now = now or os.time()
    local elapsed = now - (self.last_decay_time or now)

    -- Advance unconditionally, including when the cap below bites. Otherwise a
    -- week away is charged the cap, then charged it again on the next tick.
    self.last_decay_time = now

    if elapsed <= 0 then return 0, 0 end

    -- A dead pet stops decaying; there is nothing left to lose.
    if self:health_state(now) == "dead" then
        self.died_at = self.died_at or now
        return 0, 0
    end

    local effective = math.min(elapsed, self.max_offline_decay_seconds)
    local mood_lost = self.mood_decay_rate * effective
    local satiety_lost = self.satiety_decay_rate * effective

    -- Not the setters: decay is recomputed from last_decay_time on merge, so
    -- it must not count as a pending change.
    self.mood = clamp(self.mood - mood_lost)
    self.satiety = clamp(self.satiety - satiety_lost)

    -- Track when neglect began, and clear it the moment either stat recovers,
    -- so a fed pet resets its illness clock rather than carrying it forever.
    if self:is_neglected() then
        self.low_since = self.low_since or now
    else
        self.low_since = nil
    end

    return mood_lost, satiety_lost
end

-- Bring a dead pet back, resetting stats and the illness clock.
function Pet:revive(now)
    now = now or os.time()
    self.died_at = nil
    self.low_since = nil
    self:set_mood(self.initial_mood)
    self:set_satiety(self.initial_satiety)
    self.last_decay_time = now
end

-- Kept for the tick loop and for callers that predate apply_decay.
function Pet:update(now) return self:apply_decay(now) end

function Pet:increase_mood(amount)
    amount = amount or 1
    assert(type(amount) == "number", "amount must be a number")
    assert(amount >= 0, "amount must be non-negative")
    self:set_mood(self.mood + amount)
    self.total_mood_gained = (self.total_mood_gained or 0) + amount
end

function Pet:increase_satiety(amount)
    amount = amount or 1
    assert(type(amount) == "number", "amount must be a number")
    assert(amount >= 0, "amount must be non-negative")
    self:set_satiety(self.satiety + amount)
    self.total_satiety_gained = (self.total_satiety_gained or 0) + amount
end

function Pet:record_event()
    self.total_vim_events = (self.total_vim_events or 0) + 1
end

function Pet:get_session_duration(now)
    now = now or os.time()
    return now - (self.session_start_time or now)
end

function Pet:reset(now)
    now = now or os.time()

    self.mood = self.initial_mood
    self.satiety = self.initial_satiety
    self.birth_time = now
    self.session_start_time = now
    self.last_decay_time = now
    self.last_seen_time = now

    for _, k in ipairs(ZERO_FIELDS) do
        self[k] = 0
    end

    self.last_interaction = {}
    self.interaction_streak = {}
    self.low_since = nil
    self.died_at = nil

    self.sprite_indices = { happy = 1, hungry = 1, neutral = 1 }
    self.last_state = nil

    -- Back to the definition's colour, not to no colour: every native pet has
    -- one, so clearing the field outright would leave a reset pet grey.
    local pet_def = self.name and find_pet_def_by_name(self.name)
    self.color_theme = pet_def and pet_def.color_theme or nil
end

function Pet:transfer_stats_to(target_pet)
    target_pet.mood = self.mood
    target_pet.satiety = self.satiety
    target_pet.birth_time = self.birth_time
    target_pet.session_start_time = self.session_start_time
    target_pet.last_decay_time = self.last_decay_time
    target_pet.last_seen_time = self.last_seen_time

    target_pet.total_vim_events = self.total_vim_events
    target_pet.total_mood_gained = self.total_mood_gained
    target_pet.total_satiety_gained = self.total_satiety_gained
    target_pet.times_fed = self.times_fed
    target_pet.times_played_with = self.times_played_with
    target_pet.times_petted = self.times_petted
    target_pet.times_cleaned = self.times_cleaned

    target_pet.last_interaction = vim.deepcopy(self.last_interaction)
    target_pet.interaction_streak = vim.deepcopy(self.interaction_streak)

    -- The illness clock travels too, or switching appearance would be a way
    -- to cheat death under `stakes`.
    target_pet.low_since = self.low_since
    target_pet.died_at = self.died_at
end

local function determine_state(pet)
    -- Only reachable with `stakes` enabled; health_state returns "alive" otherwise.
    local health = pet:health_state()
    if health ~= "alive" then return health end

    if pet.satiety < 70 then
        return "hungry"
    elseif pet.mood > 70 then
        return "happy"
    else
        return "neutral"
    end
end

Pet.determine_state = determine_state

-- Frames for `state`, falling back to the shared sick/dead art for sprite sets
-- that do not define their own -- which is all user-authored ones.
function Pet:frames_for(state)
    local frames = self.sprites[state]
    if frames and #frames > 0 then return frames end

    if state == "sick" or state == "dead" then
        return require("tamagotchi.sprites.states")[state]
    end

    return frames or {}
end

-- The frame that would be shown next, without advancing the animation.
--
-- Window sizing used to call get_sprite(), whose index bump meant measuring
-- consumed a frame and measured a different frame than the one drawn.
function Pet:peek_sprite()
    local state = determine_state(self)
    local sprite_list = self:frames_for(state)
    if #sprite_list == 0 then return "" end

    local idx = self.sprite_indices[state] or 1
    return sprite_list[idx] or sprite_list[1]
end

function Pet:get_sprite()
    local state = determine_state(self)

    if not self.last_state or self.last_state ~= state then
        self.last_state = state
        self.sprite_indices[state] = 1
    end

    local sprite_list = self:frames_for(state)
    if #sprite_list == 0 then return "" end

    local idx = self.sprite_indices[state] or 1
    local sprite = sprite_list[idx] or sprite_list[1]

    self.sprite_indices[state] = (idx % #sprite_list) + 1

    return sprite
end

-- One bounding box covering every state this pet can display, cached per
-- instance. Sizing every frame to this is what keeps the art from sliding
-- sideways as it animates, and keeps the window from resizing on a state change.
function Pet:sprite_box()
    if self._sprite_box then return self._sprite_box end

    local all = {}
    for state, frames in pairs(self.sprites or {}) do
        all[state] = frames
    end

    -- Include the shared fallbacks only when they could actually be shown.
    if require("tamagotchi.config").values.stakes then
        for _, state in ipairs({ "sick", "dead" }) do
            all[state] = self:frames_for(state)
        end
    end

    self._sprite_box = render.sprite_box(all)
    return self._sprite_box
end

-- Convert a v1 save (or an unversioned table) into the v2 shape.
function Pet.migrate(data)
    if type(data) ~= "table" then return nil end
    if data.schema_version == Pet.SCHEMA_VERSION then return data end

    local now = os.time()

    -- v1 persisted vim.loop.now() -- monotonic milliseconds since boot -- then
    -- compared it against a fresh process's clock. Epoch seconds are bounded on
    -- both sides, so a magnitude test separates the two except for saves written
    -- when uptime happened to be around 20 days.
    local EPOCH_FLOOR = 1735689600 -- 2025-01-01, before this plugin existed
    local function plausible_epoch(ts)
        return type(ts) == "number" and ts >= EPOCH_FLOOR and ts <= now + 86400 -- tolerate a day of clock skew
    end

    -- birth_time and last_vim_close_time came off the same monotonic clock, so
    -- their difference is a valid duration even though neither value is. That
    -- recovers exactly as much history as v1 was actually tracking.
    local age = 0
    local birth, closed = data.birth_time, data.last_vim_close_time
    if
        type(birth) == "number"
        and type(closed) == "number"
        and closed >= birth
    then
        local seconds = (closed - birth) / 1000
        if seconds >= 0 and seconds <= 90 * 86400 then
            age = math.floor(seconds)
        end
    end
    data.birth_time = plausible_epoch(birth) and birth or (now - age)

    -- Never charge retroactive decay across a migration.
    data.last_decay_time = now
    data.last_seen_time = now
    data.session_start_time = nil
    data.last_vim_close_time = nil
    data.last_window_close_time = nil

    -- v1 raw-wrote `pet.mood = math.max(10, pet.mood - decay)`, bypassing the
    -- setter's upper clamp, so a negative elapsed inflated stats without bound.
    data.mood = clamp(tonumber(data.mood) or tonumber(data.initial_mood) or 80)
    data.satiety =
        clamp(tonumber(data.satiety) or tonumber(data.initial_satiety) or 80)

    -- Stale copies of things that must come from config, not from disk.
    data.sprites = nil
    data.vim_events = nil
    data.native = nil
    data.mood_decay_probability = nil
    data.satiety_decay_probability = nil
    data.tick_length_ms = nil

    data.schema_version = Pet.SCHEMA_VERSION
    return data
end

return Pet
