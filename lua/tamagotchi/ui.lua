-- The one place a float gets opened.
--
-- v1 hand-rolled nvim_open_win in four modules with duplicated centering math
-- and two different border styles, and none of them set 'winhighlight' -- so
-- every float rendered on `Normal` instead of `NormalFloat` and did not read as
-- a float at all. Nothing here knows about pets; it is window plumbing.
local render = require("tamagotchi.render")

local M = {}

local NS = vim.api.nvim_create_namespace("tamagotchi")

M.namespace = NS

local DEFAULT_BORDER = "rounded"

local WINHL = table.concat({
    "NormalFloat:TamagotchiNormal",
    "FloatBorder:TamagotchiBorder",
    "FloatTitle:TamagotchiTitle",
    "FloatFooter:TamagotchiFooter",
}, ",")

local function ui_config()
    local ok, config = pcall(require, "tamagotchi.config")
    if not ok then return {} end
    return (config.values and config.values.ui) or {}
end

-- Matches the statusline's `ascii` opt, so one setting governs the whole
-- plugin's look.
function M.ascii() return ui_config().ascii == true end

-- Border precedence: an explicit argument, then `ui.border`, then the user's
-- 'winborder', then rounded.
--
-- 'winborder' only exists on 0.11+ and reading an unknown option raises, so the
-- lookup has to be guarded -- the plugin still supports 0.10. Defaulting to
-- rounded rather than 'winborder's own empty default means 0.11 users who never
-- set it still get a bordered float.
function M.resolve_border(explicit)
    local configured = explicit
    if configured == nil then configured = ui_config().border end
    if configured ~= nil and configured ~= "auto" then return configured end

    local ok, winborder = pcall(function() return vim.o.winborder end)
    if ok and type(winborder) == "string" and winborder ~= "" then
        return winborder
    end

    return DEFAULT_BORDER
end

local function has_border(border)
    return border ~= nil and border ~= "none" and border ~= ""
end

M.has_border = has_border

local RULE_CHARS = {
    rounded = "─",
    single = "─",
    double = "═",
    solid = " ",
    shadow = "─",
}

-- The horizontal glyph matching a border style, so an inner divider line reads
-- as part of the same box rather than as a stray dash.
function M.rule_char(border)
    if M.ascii() then return "-" end

    if type(border) == "table" then
        -- An 8-element border lists corners and edges from the top-left; a
        -- shorter one repeats. Element 2 is the top edge in the long form.
        local top = border[2] or border[1]
        if type(top) == "table" then top = top[1] end
        if type(top) == "string" and top ~= "" and top ~= " " then
            return top
        end
        return "─"
    end

    return RULE_CHARS[border] or "─"
end

-- Chunks for a border title or footer, padded a space at each end so the text
-- does not butt up against the corners.
function M.chunks(parts)
    local out = {}
    for _, part in ipairs(parts) do
        if part[1] ~= nil and part[1] ~= "" then
            out[#out + 1] = { part[1], part[2] or "TamagotchiTitle" }
        end
    end
    if #out == 0 then return nil end

    out[1] = { " " .. out[1][1], out[1][2] }
    out[#out] = { out[#out][1] .. " ", out[#out][2] }

    return out
end

function M.key_chunks(entries, separator)
    separator = separator or (M.ascii() and " | " or " · ")

    local parts = {}
    for i, entry in ipairs(entries) do
        if i > 1 then parts[#parts + 1] = { separator, "TamagotchiMuted" } end
        parts[#parts + 1] = { entry.key, "TamagotchiKey" }
        parts[#parts + 1] = { " " .. entry.label, "TamagotchiFooter" }
    end

    return M.chunks(parts)
end

-- Plain-text rendering of what key_chunks draws, so the footer is assertable
-- without reading window config back out of Neovim.
function M.key_text(entries, separator)
    separator = separator or (M.ascii() and " | " or " · ")

    local parts = {}
    for _, entry in ipairs(entries) do
        parts[#parts + 1] = entry.key .. " " .. entry.label
    end

    return table.concat(parts, separator)
end

-- Pad every line out to the window width, so a background highlight covers the
-- whole float rather than stopping at the end of each line's text.
local function pad_lines(lines, width)
    local out = {}
    for i, line in ipairs(lines) do
        local w = render.display_width(line)
        out[i] = (w >= width) and render.truncate(line, width)
            or (line .. string.rep(" ", width - w))
    end
    return out
end

local function centered_position(width, height)
    local ui = vim.api.nvim_list_uis()[1]
        or { width = vim.o.columns, height = vim.o.lines }

    return math.max(0, math.floor((ui.height - height) / 2) - 1),
        math.max(0, math.floor((ui.width - width) / 2))
end

local function measure(opts, lines)
    local width = opts.width
    if not width then
        width = 1
        for _, line in ipairs(lines) do
            width = math.max(width, render.display_width(line))
        end
    end

    return width, opts.height or math.max(1, #lines)
end

local function create_buf(opts)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    if opts.filetype then vim.bo[buf].filetype = opts.filetype end
    return buf
end

local function build_win_config(opts, width, height, border)
    local row, col = centered_position(width, height)

    local config = {
        relative = opts.relative or "editor",
        win = opts.win,
        width = width,
        height = height,
        row = opts.row or row,
        col = opts.col or col,
        style = "minimal",
        border = border,
        zindex = opts.zindex,
    }

    -- Neovim rejects a title on a borderless window rather than ignoring it.
    if not has_border(border) then return config end

    if opts.title then
        config.title = opts.title
        config.title_pos = opts.title_pos or "center"
    end
    if opts.footer then
        config.footer = opts.footer
        config.footer_pos = opts.footer_pos or "center"
    end

    return config
end

local function make_handle(opts, buf, win, width, height, border)
    local pad = opts.modifiable ~= true

    local handle = {
        buf = buf,
        win = win,
        width = width,
        height = height,
        border = border,
        rule = string.rep(M.rule_char(border), width),
    }

    local closed = false

    function handle.is_valid()
        return not closed and vim.api.nvim_win_is_valid(win)
    end

    -- Idempotent, and the single teardown for every exit path -- keymap, :q,
    -- <C-w>c, or the buffer being wiped out from under us. v1 only the menu had
    -- this hook, so quitting the pet float with :q never saved the pet and left
    -- the tick running at animation speed.
    function handle.close()
        if closed then return end
        closed = true

        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end

        if opts.on_close then opts.on_close() end
    end

    function handle.set_lines(new_lines)
        if not handle.is_valid() then return end
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(
            buf,
            0,
            -1,
            false,
            pad and pad_lines(new_lines, width) or new_lines
        )
        vim.bo[buf].modifiable = opts.modifiable == true
    end

    -- Read-modify-write rather than a partial config: passing `relative` without
    -- row/col would recentre the window, and omitting it is not accepted for a
    -- float on every supported version.
    local function set_border_text(field, value)
        if not handle.is_valid() or not has_border(border) then return end

        local current = vim.api.nvim_win_get_config(win)
        current[field] = value
        current[field .. "_pos"] = current[field .. "_pos"] or "center"
        pcall(vim.api.nvim_win_set_config, win, current)
    end

    -- Cached: the title carries the age, so this is called on every tick and
    -- almost never actually differs.
    local last = {}
    local function set_cached(field, value)
        local key = vim.inspect(value)
        if last[field] == key then return end
        last[field] = key
        set_border_text(field, value)
    end

    function handle.set_title(value) set_cached("title", value) end
    function handle.set_footer(value) set_cached("footer", value) end

    function handle.map(keys, fn)
        for _, key in ipairs(keys) do
            vim.keymap.set("n", key, fn, {
                buffer = buf,
                nowait = true,
                silent = true,
            })
        end
    end

    handle.map(opts.close_keys or { "q", "<Esc>", "<C-c>" }, handle.close)

    if opts.help then
        handle.map({ "?" }, function() M.help(opts.help, handle) end)
    end

    vim.api.nvim_create_autocmd({ "WinClosed", "BufWipeout" }, {
        buffer = buf,
        once = true,
        callback = handle.close,
    })

    return handle
end

--- Open a float.
---
--- opts:
---   lines        initial buffer contents
---   width/height defaults to the widest line and the line count
---   title/footer chunk lists (see M.chunks); ignored when there is no border
---   border       explicit border, else resolved from config/'winborder'
---   relative/win/row/col  position overrides for child windows
---   enter        focus the new window (default true)
---   zindex       stacking order; dialogues sit above menus
---   filetype     buffer filetype, for user autocmds
---   modifiable   leave the buffer writable (the menu's search input needs this)
---   close_keys   keys bound to close (default q / <Esc> / <C-c>)
---   help         entries for the `?` overlay
---   on_close     called once, however the window is disposed of
---
--- Returns a handle with close/is_valid/set_lines/set_title/set_footer/map.
function M.open(opts)
    local lines = opts.lines or {}
    local width, height = measure(opts, lines)
    local border = M.resolve_border(opts.border)

    local buf = create_buf(opts)
    local win = vim.api.nvim_open_win(
        buf,
        opts.enter ~= false,
        build_win_config(opts, width, height, border)
    )

    vim.wo[win].winhighlight = WINHL
    vim.wo[win].wrap = false
    vim.wo[win].cursorline = false

    -- A writable buffer is user text -- the menu's search box -- so padding it
    -- would put trailing spaces into whatever the user typed.
    local pad = opts.modifiable ~= true

    if #lines > 0 then
        vim.api.nvim_buf_set_lines(
            buf,
            0,
            -1,
            false,
            pad and pad_lines(lines, width) or lines
        )
    end
    vim.bo[buf].modifiable = opts.modifiable == true

    return make_handle(opts, buf, win, width, height, border)
end

-- The `?` overlay. Every float advertises it in the footer, so the interaction
-- verbs are discoverable without reading the README.
function M.help(entries, parent)
    local key_width = 0
    for _, entry in ipairs(entries) do
        key_width = math.max(key_width, render.display_width(entry.key))
    end

    local lines = { "" }
    for _, entry in ipairs(entries) do
        lines[#lines + 1] = ("  %s%s   %s"):format(
            entry.key,
            string.rep(" ", key_width - render.display_width(entry.key)),
            entry.label
        )
    end
    lines[#lines + 1] = ""

    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, render.display_width(line) + 2)
    end

    return M.open({
        lines = lines,
        width = math.max(width, 24),
        title = M.chunks({ { "keys", "TamagotchiTitle" } }),
        filetype = "tamagotchi-help",
        -- Above whatever opened it, including a dialogue.
        zindex = 300,
        on_close = function()
            if parent and parent.is_valid() then
                pcall(vim.api.nvim_set_current_win, parent.win)
            end
        end,
    })
end

return M
