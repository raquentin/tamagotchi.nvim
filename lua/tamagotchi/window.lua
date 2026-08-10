local render = require("tamagotchi.render")
local ui = require("tamagotchi.ui")

local M = {}

M.current_window = nil
M.current_pet = nil

-- One owned namespace, so highlights can actually be cleared. v1 wrote into
-- ns_id 0 and never cleared anything, while update_ui re-applied highlights
-- every second -- extmarks grew without bound for as long as the float stayed
-- open.
local NS = ui.namespace

M.namespace = NS

local COLOR_THEME_MAP = {
    red = "TamagotchiColorRed",
    green = "TamagotchiColorGreen",
    yellow = "TamagotchiColorYellow",
    blue = "TamagotchiColorBlue",
    magenta = "TamagotchiColorMagenta",
    cyan = "TamagotchiColorCyan",
    white = "TamagotchiColorWhite",
}

local MIN_GAP = 3
local MIN_WIDTH = 40
local BAR_WIDTH = 10
local LABEL_WIDTH = 7

local function theme_hl(pet)
    if pet and pet.color_theme and COLOR_THEME_MAP[pet.color_theme] then
        return COLOR_THEME_MAP[pet.color_theme]
    end
    return "TamagotchiLabel"
end

-- The interaction verbs. Without a row for these they exist only as
-- :Tamagotchi subcommands, which means nobody finds them.
local ACTIONS = {
    { key = "f", label = "feed", verb = "feed" },
    { key = "p", label = "play", verb = "play" },
    { key = "t", label = "pet", verb = "pet" },
    { key = "c", label = "clean", verb = "clean" },
}

local REVIVE = { key = "R", label = "revive", verb = "revive" }

-- Reset deliberately lives behind the settings screen rather than in this
-- footer: it can delete every save, which is not a thing to put one keystroke
-- away from the main window.
local NAV = {
    { key = "m", label = "menu" },
    { key = "s", label = "settings" },
    { key = "?", label = "help" },
}

M.ACTIONS = ACTIONS
M.NAV = NAV

-- Kept on the module because the restored window_spec covers it.
M.center_text = render.center_text

local function get_actions(pet)
    -- Nothing to do for a dead pet but bring it back.
    if pet and pet.is_dead and pet:is_dead() then return { REVIVE } end
    return ACTIONS
end

local function separator() return ui.ascii() and " - " or " · " end

local function health_state(pet)
    if not pet or type(pet.health_state) ~= "function" then return "alive" end
    local ok, state = pcall(pet.health_state, pet)
    return ok and state or "alive"
end

-- Name and age live in the border rather than in the body: they are labels for
-- the window, and moving them out leaves the body to the two things that
-- actually change fast enough to watch.
function M.title_chunks(pet)
    local state = health_state(pet)

    local name_hl, suffix = "TamagotchiTitle", nil
    if state == "sick" then
        name_hl, suffix = "TamagotchiSick", "sick"
    elseif state == "dead" then
        name_hl, suffix = "TamagotchiDead", "R.I.P."
    end

    local parts = {
        { pet.name or "pet", name_hl },
        { separator(), "TamagotchiMuted" },
        { pet:get_age_formatted(), "TamagotchiMuted" },
    }

    if suffix then
        parts[#parts + 1] = { separator(), "TamagotchiMuted" }
        parts[#parts + 1] = { suffix, name_hl }
    end

    return ui.chunks(parts)
end

function M.footer_text() return ui.key_text(NAV, separator()) end

local function help_entries(pet)
    local entries = {}
    for _, action in ipairs(get_actions(pet)) do
        entries[#entries + 1] = { key = action.key, label = action.label }
    end
    for _, nav in ipairs(NAV) do
        entries[#entries + 1] = nav
    end
    entries[#entries + 1] = { key = "q", label = "close" }
    return entries
end

-- Decay is continuous -- 0.05 points a second by default -- so "lower than last
-- frame" is true every tick and would paint the bar red permanently. A whole
-- point is the smallest change a bar can draw, so that is what counts as a
-- fall: one pulse every 20s or so while idling down, immediately when something
-- takes a chunk out of a stat.
local FLASH_MS = 2000
local DROP_POINTS = 1

local TREND_HL = {
    up = "TamagotchiTrendUp",
    down = "TamagotchiTrendDown",
}

local function trend_marker(dir)
    if ui.ascii() then return ({ up = "^", down = "v" })[dir] or "." end
    return ({ up = "▲", down = "▼" })[dir] or "·"
end

-- Reset whenever a float opens, so switching pets or reopening the window does
-- not flash a change the user never saw happen.
local trends = {}

function M.reset_trends() trends = {} end

--- Direction to light `key` up in, or nil once the flash has expired.
---
--- `now` is milliseconds from any monotonic source; the caller passes
--- vim.uv.now() and the specs pass their own, so this stays testable without
--- waiting out a real two seconds.
function M.trend(key, value, now)
    local t = trends[key]

    if not t then
        trends[key] = { value = value, dir = nil, at = nil }
        return nil
    end

    if value > t.value then
        t.value, t.dir, t.at = value, "up", now
    elseif value <= t.value - DROP_POINTS then
        t.value, t.dir, t.at = value, "down", now
    end

    if t.dir and (now - t.at) <= FLASH_MS then return t.dir end
    return nil
end

-- Cell spans come back measured off the rendered text rather than recomputed,
-- so the highlighter cannot drift out of sync with the layout.
local function stat_row(label, value, dir)
    local prefix = ("%-" .. LABEL_WIDTH .. "s "):format(label)
    local bar, filled, bar_from

    if ui.ascii() then
        bar = render.ascii_bar(value, 100, BAR_WIDTH)
        filled = math.floor((math.min(value, 100) / 100) * BAR_WIDTH)
        -- Skip the opening bracket.
        bar_from = render.display_width(prefix) + 1
    else
        bar, filled = render.stat_bar(value, 100, BAR_WIDTH)
        bar_from = render.display_width(prefix)
    end

    local head = prefix .. bar .. " "
    local text = head .. trend_marker(dir)

    return {
        text = text,
        bar_from = bar_from,
        filled = filled,
        width = BAR_WIDTH,
        value = value,
        dir = dir,
        marker_from = render.display_width(head),
        marker_to = render.display_width(text),
    }
end

local function stat_rows(pet, now)
    now = now or vim.uv.now()

    return {
        stat_row("mood", pet:get_mood(), M.trend("mood", pet:get_mood(), now)),
        stat_row(
            "satiety",
            pet:get_satiety(),
            M.trend("satiety", pet:get_satiety(), now)
        ),
    }
end

-- The horizontal layout, computed once and reused by both the line builder and
-- the highlighter -- v1 duplicated this arithmetic in two places that had to
-- stay in sync by hand.
--
-- All widths are display cells: pet names are user-supplied and sprites use
-- multibyte glyphs, so byte lengths would misplace both padding and highlights.
local function layout(pet, width)
    local box = pet:sprite_box()
    local rows = stat_rows(pet)

    local info_width = 0
    for _, row in ipairs(rows) do
        info_width = math.max(info_width, render.display_width(row.text))
    end

    local available = width - box.width - info_width
    local gap = math.max(MIN_GAP, math.floor(available / 3))

    local total_padding = width - box.width - gap - info_width
    local left_pad = math.max(0, math.floor(total_padding / 2))
    local right_pad = math.max(0, total_padding - left_pad)

    local content_height = math.max(box.rows, #rows)

    return {
        box = box,
        rows = rows,
        info_width = info_width,
        gap = gap,
        left_pad = left_pad,
        right_pad = right_pad,
        content_height = content_height,
        -- Both blocks sit centred against the taller of the two, so a 5-row
        -- sprite does not leave the stats stuck to the ceiling.
        sprite_offset = math.floor((content_height - box.rows) / 2),
        info_offset = math.floor((content_height - #rows) / 2),
    }
end

local function build_top_lines(pet, width, sprite_text, l)
    local sprite_lines = render.normalize_frame(sprite_text or "", l.box)
    local blank_sprite = string.rep(" ", l.box.width)

    local lines = { string.rep(" ", width) }

    for i = 1, l.content_height do
        local parts = { string.rep(" ", l.left_pad) }

        parts[#parts + 1] = sprite_lines[i - l.sprite_offset] or blank_sprite
        parts[#parts + 1] = string.rep(" ", l.gap)

        local row = l.rows[i - l.info_offset]
        local text = row and row.text or ""
        parts[#parts + 1] = text
            .. string.rep(" ", l.info_width - render.display_width(text))

        parts[#parts + 1] = string.rep(" ", l.right_pad)
        lines[#lines + 1] = table.concat(parts)
    end

    lines[#lines + 1] = string.rep(" ", width)
    return lines
end

-- One row of evenly divided, centred `key label` pairs. The cell spans of each
-- half come back too, so the key can be highlighted apart from its label --
-- which is what makes the row read as keys rather than as decoration.
local function build_action_line(actions, width)
    if #actions == 0 then return string.rep(" ", width), {} end

    local segment_width = math.floor(width / #actions)
    local parts, spans = {}, {}
    local cell = 0

    for i, action in ipairs(actions) do
        local text = action.key .. " " .. action.label
        local text_width = math.min(segment_width, render.display_width(text))
        local key_width = render.display_width(action.key)
        local lead = math.max(0, math.floor((segment_width - text_width) / 2))

        parts[i] = render.center_text(text, segment_width)
        spans[i] = {
            key_from = cell + lead,
            key_to = cell + lead + key_width,
            label_from = math.min(
                cell + lead + key_width + 1,
                cell + text_width
            ),
            label_to = cell + text_width,
        }

        cell = cell + segment_width
    end

    local leftover = width - segment_width * #actions
    if leftover > 0 then
        parts[#parts] = parts[#parts] .. string.rep(" ", leftover)
    end

    return table.concat(parts), spans
end

local byte_offset_of_cell = render.byte_offset

local function hl(buf, lines, row, from_cell, to_cell, group)
    if not group or to_cell <= from_cell then return end

    local line = lines[row + 1]
    if not line then return end

    vim.api.nvim_buf_set_extmark(
        buf,
        NS,
        row,
        byte_offset_of_cell(line, from_cell),
        {
            end_col = byte_offset_of_cell(line, to_cell),
            hl_group = group,
        }
    )
end

local function sprite_row_visible(i, l)
    return i > l.sprite_offset and i <= l.sprite_offset + l.box.rows
end

-- At rest a bar reads as its level, so a starving pet looks starving. While a
-- stat is moving the trend colour takes over label, bar and marker together:
-- the label is normally grey, so it is what reads as a change even on a bar
-- that was already that colour.
local function highlight_stat(buf, lines, row, stat, info_start)
    local trend_hl = stat.dir and TREND_HL[stat.dir]

    hl(
        buf,
        lines,
        row,
        info_start,
        info_start + LABEL_WIDTH,
        trend_hl or "TamagotchiMuted"
    )

    local bar_start = info_start + stat.bar_from
    hl(
        buf,
        lines,
        row,
        bar_start,
        bar_start + stat.filled,
        trend_hl or render.bar_hl(stat.value, 100)
    )
    hl(
        buf,
        lines,
        row,
        bar_start + stat.filled,
        bar_start + stat.width,
        "TamagotchiBarEmpty"
    )

    hl(
        buf,
        lines,
        row,
        info_start + stat.marker_from,
        info_start + stat.marker_to,
        trend_hl or "TamagotchiTrendFlat"
    )
end

local function highlight_body(buf, lines, pet, l)
    local color_hl = pet.color_theme and COLOR_THEME_MAP[pet.color_theme]

    -- Row 0 is the blank top line, so content starts at row 1.
    for i = 1, l.content_height do
        local row = i

        if color_hl and sprite_row_visible(i, l) then
            hl(buf, lines, row, l.left_pad, l.left_pad + l.box.width, color_hl)
        end

        local stat = l.rows[i - l.info_offset]
        if stat then
            highlight_stat(
                buf,
                lines,
                row,
                stat,
                l.left_pad + l.box.width + l.gap
            )
        end
    end
end

local function highlight_actions(buf, lines, row, spans, group)
    for _, span in ipairs(spans) do
        hl(buf, lines, row, span.key_from, span.key_to, "TamagotchiKey")
        hl(buf, lines, row, span.label_from, span.label_to, group)
    end
end

-- Size from the sprite set's bounding box rather than a live frame.
--
-- v1 called pet:get_sprite() here, which advances the animation index -- so
-- measuring consumed a frame and measured a frame other than the one drawn.
local function calculate_window_dimensions(pet)
    local l = layout(pet, MIN_WIDTH)

    -- 1 blank + content + 1 blank + rule + action row
    local height = 1 + l.content_height + 1 + 2
    local width = math.max(l.box.width + MIN_GAP + l.info_width + 10, MIN_WIDTH)

    return width, height
end

function M.get_current_pet() return M.current_pet end

-- Checks the window id rather than calling the handle's own is_valid, so a
-- stubbed window (the tick's period tests use one) does not have to reimplement
-- the whole handle interface.
function M.is_open()
    local handle = M.current_window
    return handle ~= nil
        and handle.win ~= nil
        and vim.api.nvim_win_is_valid(handle.win)
end

-- The single teardown, however the float is disposed of. v1 only saved when the
-- user pressed `q`; closing with :q dropped the session's progress on the floor
-- and left the tick running at animation speed.
local function on_window_closed()
    local pet = M.current_pet

    M.current_window = nil
    M.current_pet = nil

    if pet then pcall(require("tamagotchi.store").save_pet, pet) end
    pcall(require("tamagotchi.tick").retime)
end

-- The reset flow, exposed so `:Tamagotchi reset` and the settings screen share
-- it.
function M.reset_dialogue(pet)
    local dialogue = require("tamagotchi.dialogue")
    local store = require("tamagotchi.store")

    pet = pet or _G.tamagotchi_pet
    if not pet then return end

    dialogue.choice(
        "reset options",
        "what would you like to reset?",
        "reset current pet only",
        "reset all pets (delete all saves)",
        function()
            dialogue.confirm(
                "reset current pet",
                "are you sure you want to reset "
                    .. (pet.name or "your pet")
                    .. "? this will reset all stats and age to initial values.",
                function()
                    pet:reset()
                    store.save_pet(pet)
                    M.update_ui(pet, false)
                    vim.notify("pet has been reset!", vim.log.levels.INFO)
                end,
                nil
            )
        end,
        function()
            dialogue.confirm(
                "reset all pets",
                "are you ABSOLUTELY SURE you want to delete ALL pet save files? this cannot be undone!",
                function()
                    -- Glob the save directory rather than walking config: v1
                    -- rebuilt paths from config.pets, so it missed renamed pets
                    -- and pets the user had since removed from their config.
                    local deleted = store.delete_all_pets()

                    pet:reset()
                    store.save_pet(pet)
                    M.update_ui(pet, false)

                    vim.notify(
                        ("deleted %d save file(s) and reset current pet!"):format(
                            deleted
                        ),
                        vim.log.levels.WARN
                    )
                end,
                nil
            )
        end
    )
end

function M.open(pet)
    assert(pet, "pet is required")
    assert(type(pet) == "table", "pet must be a table")
    assert(type(pet.get_mood) == "function", "pet must have get_mood method")
    assert(
        type(pet.get_satiety) == "function",
        "pet must have get_satiety method"
    )
    assert(
        type(pet.get_sprite) == "function",
        "pet must have get_sprite method"
    )

    -- Dispose of any existing float first, so its on_close does not clear the
    -- pet we are about to install.
    if M.current_window then M.current_window.close() end

    M.current_pet = pet

    -- Nothing has moved yet, so opening never opens on a flash.
    M.reset_trends()

    -- No retroactive decay here. Decay is charged by elapsed wall time in
    -- Pet:apply_decay, which the tick already drives; v1 also charged it on
    -- every window open, double-counting the same seconds.
    pet:apply_decay()

    local width, height = calculate_window_dimensions(pet)

    M.current_window = ui.open({
        width = width,
        height = height,
        title = M.title_chunks(pet),
        footer = ui.key_chunks(NAV, separator()),
        filetype = "tamagotchi",
        help = help_entries(pet),
        on_close = on_window_closed,
    })

    local handle = M.current_window

    handle.map(
        { "m", "M" },
        function() require("tamagotchi.menu").open_pet_menu() end
    )
    handle.map(
        { "s", "S" },
        function() require("tamagotchi.settings").show_settings(M.current_pet) end
    )

    -- Bound unconditionally, not from get_actions(pet): the row swaps to
    -- `R revive` when the pet dies, and rebinding on every state change would
    -- leave the previous state's keys behind.
    local actions = require("tamagotchi.actions")
    for _, action in ipairs(ACTIONS) do
        handle.map(
            { action.key },
            function() actions.run(action.verb, M.current_pet) end
        )
    end
    handle.map({ "R" }, function() actions.revive(M.current_pet) end)

    M.update_ui(pet, true)

    -- Animation wants a faster tick than the idle loop runs at.
    require("tamagotchi.tick").retime()

    return M.current_window
end

function M.close(pet)
    if M.current_window then
        -- on_window_closed saves whatever is current and clears both fields.
        M.current_window.close()
    else
        M.current_pet = nil
        if pet then pcall(require("tamagotchi.store").save_pet, pet) end
    end
end

function M.update_ui(pet, update_sprite)
    if not M.is_open() then return end

    local tick = require("tamagotchi.tick")
    local handle = M.current_window
    local width = handle.width
    local buf = handle.buf

    if update_sprite or tick.last_sprite == "" then
        tick.last_sprite = pet:get_sprite()
    end

    local l = layout(pet, width)
    local lines = build_top_lines(pet, width, tick.last_sprite or "", l)

    lines[#lines + 1] = handle.rule
    local action_line, spans = build_action_line(get_actions(pet), width)
    lines[#lines + 1] = action_line

    handle.set_lines(lines)

    -- The age ticks over in the title; both setters no-op when unchanged.
    handle.set_title(M.title_chunks(pet))

    vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
    highlight_body(buf, lines, pet, l)
    hl(buf, lines, #lines - 2, 0, width, "TamagotchiRule")
    highlight_actions(buf, lines, #lines - 1, spans, theme_hl(pet))
end

-- Called by the tick. A no-op when there is nothing on screen, so the tick can
-- keep running with no window open.
function M.on_tick(pet, update_sprite)
    if not M.is_open() then return end
    M.update_ui(pet, update_sprite)
end

function M.toggle(pet)
    if M.is_open() then
        M.close(pet)
        return nil
    end
    return M.open(pet)
end

return M
