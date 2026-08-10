-- Pure layout helpers. Nothing here touches a buffer or a window, so it is all
-- unit-testable headlessly -- which matters because this is where the width
-- math lives, and getting that wrong is what makes sprites jitter.
--
-- Everything works in *display cells*, not bytes. Sprites use narrow multibyte
-- glyphs (•, ʕ, ᴥ, ʔ), so `#line` overcounts them by 2-3x.
local M = {}

-- Matches one UTF-8 character: a lead byte followed by its continuation bytes.
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

function M.display_width(s) return vim.fn.strdisplaywidth(s) end

function M.chars(s)
    local out = {}
    for c in s:gmatch(UTF8_CHAR) do
        out[#out + 1] = c
    end
    return out
end

-- Expand a string into one entry per display cell. A double-width glyph
-- occupies its first cell and leaves `false` in the cells it continues across,
-- which makes slicing by column a simple array index.
local function to_cells(line)
    local cells = {}
    for _, c in ipairs(M.chars(line)) do
        local w = M.display_width(c)
        cells[#cells + 1] = c
        for _ = 2, w do
            cells[#cells + 1] = false
        end
    end
    return cells
end

-- Rebuild a string from cells [from, to]. Cells past the end of the line, and
-- glyphs that would be sliced in half, become spaces -- so the result is always
-- exactly `to - from + 1` cells wide.
local function from_cells(cells, from, to)
    local out = {}
    local i = from
    while i <= to do
        local c = cells[i]
        if c == nil or c == false then
            -- Past end of line, or the tail of a glyph that began before `from`.
            out[#out + 1] = " "
            i = i + 1
        else
            local w = M.display_width(c)
            if i + w - 1 <= to then
                out[#out + 1] = c
                i = i + w
            else
                out[#out + 1] = " "
                i = i + 1
            end
        end
    end
    return table.concat(out)
end

M._to_cells = to_cells
M._from_cells = from_cells

-- Byte offset of a display column. Extmark columns are byte offsets while every
-- layout here is in cells, so any highlight over text that might contain a
-- multibyte glyph -- a sprite, or a user-chosen pet name -- has to convert.
function M.byte_offset(line, cell)
    if cell <= 0 then return 0 end
    return #from_cells(to_cells(line), 1, cell)
end

-- Truncate to `width` cells without splitting a character in half.
function M.truncate(text, width)
    if M.display_width(text) <= width then return text end
    return from_cells(to_cells(text), 1, width)
end

-- Center `text` within `width` cells. Truncates when it does not fit.
function M.center_text(text, width)
    assert(type(text) == "string", "text must be a string")
    assert(
        type(width) == "number" and width > 0,
        "width must be a positive number"
    )

    local w = M.display_width(text)
    if w >= width then return from_cells(to_cells(text), 1, width) end

    local left_pad = math.floor((width - w) / 2)
    local right_pad = width - w - left_pad
    return string.rep(" ", left_pad) .. text .. string.rep(" ", right_pad)
end

function M.ascii_bar(value, max, width)
    assert(value >= 0, "value must be non-negative")
    assert(max > 0, "max must be positive")
    assert(width > 0, "width must be positive")

    -- Stats are fractional internally; clamp so a value above max cannot
    -- produce a negative unfilled count.
    local filled = math.floor((math.min(value, max) / max) * width)
    return "["
        .. string.rep("#", filled)
        .. string.rep("-", width - filled)
        .. "]"
end

-- For the one cell straddling the fill boundary.
local EIGHTHS = { "▏", "▎", "▍", "▌", "▋", "▊", "▉" }

local FULL, EMPTY = "█", "░"

-- Stats are fractional and decay slowly -- at decay_speed 3 a 10-cell bar loses
-- one whole cell every ~3 minutes -- so without the partial cell the bar looks
-- frozen and then jumps. Returns the bar and the number of *filled* cells, which
-- the caller needs to highlight the filled and empty runs differently.
function M.stat_bar(value, max, width)
    assert(value >= 0, "value must be non-negative")
    assert(max > 0, "max must be positive")
    assert(width > 0, "width must be positive")

    local exact = (math.min(value, max) / max) * width
    local full = math.floor(exact)

    -- A stat pinned at max must not try to draw a partial cell past the end.
    if full >= width then return string.rep(FULL, width), width end

    local eighths = math.floor((exact - full) * 8)
    local partial = eighths > 0 and EIGHTHS[eighths] or nil

    local cells = string.rep(FULL, full)
        .. (partial or "")
        .. string.rep(EMPTY, width - full - (partial and 1 or 0))

    return cells, full + (partial and 1 or 0)
end

-- Highlight group for a bar at this fill fraction. Thresholds match the
-- statusline's, so a pet that reads "low" in one place reads low in the other.
function M.bar_hl(value, max)
    local pct = (max > 0) and (value / max) or 0
    if pct > 0.6 then return "TamagotchiBarHigh" end
    if pct > 0.25 then return "TamagotchiBarMed" end
    return "TamagotchiBarLow"
end

function M.split_lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

-- Column span (1-indexed, inclusive) of the non-blank content in one line,
-- or nil for a blank line.
local function content_span(line)
    local col, first, last = 1, nil, nil
    for _, c in ipairs(M.chars(line)) do
        local w = M.display_width(c)
        if c ~= " " and c ~= "\t" then
            if not first then first = col end
            last = col + w - 1
        end
        col = col + w
    end
    return first, last
end

M._content_span = content_span

-- The tightest box containing every frame of every state in a sprite set.
--
-- Computing this once per *set* rather than once per frame is what stops the
-- sprite sliding sideways as it animates: frames within a state have different
-- content widths, so a per-frame box re-centers the art on every tick.
function M.sprite_box(sprite_set)
    local left, right = math.huge, 0
    local top, bottom = math.huge, 0

    for _, frames in pairs(sprite_set) do
        if type(frames) == "table" then
            for _, frame in ipairs(frames) do
                if type(frame) == "string" then
                    for row, line in ipairs(M.split_lines(frame)) do
                        local first, last = content_span(line)
                        if first then
                            left = math.min(left, first)
                            right = math.max(right, last)
                            -- Row bounds come from content, not line count, so
                            -- the blank line a `[[ ... \n]]` literal leaves
                            -- behind does not become an empty sprite row.
                            top = math.min(top, row)
                            bottom = math.max(bottom, row)
                        end
                    end
                end
            end
        end
    end

    -- An all-blank sprite set still needs a usable box.
    if left == math.huge then
        left, right, top, bottom = 1, 1, 1, 1
    end

    return {
        left = left,
        right = right,
        top = top,
        width = right - left + 1,
        rows = bottom - top + 1,
    }
end

-- Slice one frame to `box`, padding with spaces so every line is exactly
-- box.width cells and there are exactly box.rows of them.
--
-- Content keeps its absolute column, so art stays put between frames.
function M.normalize_frame(frame, box)
    local lines = M.split_lines(frame)
    local out = {}

    for i = 1, box.rows do
        local line = lines[(box.top or 1) + i - 1] or ""
        out[i] = from_cells(to_cells(line), box.left, box.right)
    end

    return out, box.width, box.rows
end

-- Normalize a lone frame against its own bounds. Only for callers with no
-- sprite set to hand -- prefer sprite_box + normalize_frame, which is stable
-- across frames.
function M.normalize_sprite(frame)
    local box = M.sprite_box({ { frame } })
    return M.normalize_frame(frame, box)
end

-- Greedy word wrap to `width` cells. Words longer than the line get split
-- rather than overflowing.
function M.wrap(text, width)
    local lines = {}

    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        if paragraph == "" then
            lines[#lines + 1] = ""
        else
            local current = ""
            for word in paragraph:gmatch("%S+") do
                local candidate = current == "" and word
                    or (current .. " " .. word)
                if M.display_width(candidate) <= width then
                    current = candidate
                elseif current == "" then
                    -- Single word wider than the line: hard-split it.
                    local rest = word
                    while M.display_width(rest) > width do
                        local head = M.truncate(rest, width)
                        lines[#lines + 1] = head
                        rest = rest:sub(#head + 1)
                    end
                    current = rest
                else
                    lines[#lines + 1] = current
                    current = word
                end
            end
            if current ~= "" then lines[#lines + 1] = current end
        end
    end

    return lines
end

return M
