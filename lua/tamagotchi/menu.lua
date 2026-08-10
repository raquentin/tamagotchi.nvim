local render = require("tamagotchi.render")
local ui = require("tamagotchi.ui")
local window = require("tamagotchi.window")
local Pet = require("tamagotchi.pet")

local menu = {}

local NS = ui.namespace

local WIDTH = 50
local PAGE = 8 -- pet rows visible at once
local DIVIDER_COL = 20 -- cell column of the vertical rule
local HEIGHT = PAGE + 2 -- list rows, then the rule, then the prompt

local PANE_WIDTH = WIDTH - DIVIDER_COL - 1
local RULE_ROW = PAGE
local PROMPT_ROW = PAGE + 1

local function get_all_pets()
    return require("tamagotchi.config").values.pets or {}
end

local function glyphs()
    if ui.ascii() then
        return { vertical = "|", junction = "-", marker = "> ", enter = "enter" }
    end
    return { vertical = "│", junction = "┴", marker = "▌ ", enter = "⏎" }
end

-- Subsequence match, case-insensitive. Exported for testing.
function menu.fuzzy_match(str, pattern)
    if pattern == "" then return true end

    local pattern_idx = 1
    local pattern_len = #pattern
    local str_lower = str:lower()
    local pattern_lower = pattern:lower()

    for i = 1, #str_lower do
        if
            str_lower:sub(i, i) == pattern_lower:sub(pattern_idx, pattern_idx)
        then
            pattern_idx = pattern_idx + 1
            if pattern_idx > pattern_len then return true end
        end
    end

    return pattern_idx > pattern_len
end

-- Scroll offset keeping `idx` inside a `page`-row viewport.
--
-- v1 rendered only the first 8 pets but let the selection run to the end of the
-- list, so with more than 8 pets the cursor simply vanished while still moving.
-- Pure, so it is testable without a UI.
function menu._scroll(top, idx, page, total)
    if total <= page then return 1 end

    top = math.max(1, math.min(top or 1, total - page + 1))

    if idx < top then
        top = idx
    elseif idx > top + page - 1 then
        top = idx - page + 1
    end

    return math.max(1, math.min(top, total - page + 1))
end

-- Pad `text` out to `cells` display columns.
local function pad_to(text, cells)
    local w = render.display_width(text)
    if w >= cells then return render.truncate(text, cells) end
    return text .. string.rep(" ", cells - w)
end

-- Hand the pet list to whatever picker the user has configured. Opt-in via
-- `picker = "native"`; the builtin menu stays the default because no generic
-- picker can show the animated sprite preview, which is most of the point.
function menu.open_native_picker(active_pet)
    local pets = get_all_pets()

    vim.ui.select(pets, {
        prompt = "choose a pet",
        kind = "tamagotchi",
        format_item = function(def) return def.name end,
    }, function(choice)
        if not choice then return end
        menu.switch_to(choice, active_pet)
    end)
end

function menu.open_pet_menu()
    local active_pet = _G.tamagotchi_pet
    if window.is_open() then window.close(window.get_current_pet()) end

    local pets_list = get_all_pets()
    if #pets_list == 0 then
        vim.notify("no pets found!", vim.log.levels.WARN)
        return
    end

    if require("tamagotchi.config").values.picker == "native" then
        return menu.open_native_picker(active_pet)
    end

    local g = glyphs()

    local state = {
        pets = pets_list,
        filtered_pets = pets_list,
        selected_idx = 1,
        win_top = 1,
        query = "",
        preview_pet = nil,
        animation_timer = nil,
    }

    local input = nil

    -- One idempotent teardown for every exit path.
    --
    -- v1 stopped and closed the animation timer without nil-ing it, then
    -- returned early on an empty filter while leaving the window open -- so the
    -- next <CR> called :stop() on a closed handle and libuv aborted. And with no
    -- WinClosed hook, quitting the menu with :q orphaned a 1s timer for the rest
    -- of the session.
    local closed = false
    local function release()
        if closed then return end
        closed = true

        if state.animation_timer then
            if not state.animation_timer:is_closing() then
                state.animation_timer:stop()
                state.animation_timer:close()
            end
            state.animation_timer = nil
        end
        -- Mirrored on the module so a test can assert the timer was released
        -- without walking every libuv handle in the process.
        menu._active_timer = nil

        if input then input.close() end
    end

    local handle = ui.open({
        width = WIDTH,
        height = HEIGHT,
        title = ui.chunks({ { "choose a pet", "TamagotchiTitle" } }),
        footer = ui.key_chunks({
            { key = "j/k", label = "move" },
            { key = "/", label = "search" },
            { key = g.enter, label = "pick" },
            { key = "q", label = "close" },
        }),
        filetype = "tamagotchi-menu",
        zindex = 100,
        -- Bound below, so <Esc> can back out of the search box first.
        close_keys = {},
        on_close = release,
    })

    local function close_menu()
        release()
        handle.close()
    end

    local function update_preview()
        local def = state.filtered_pets[state.selected_idx]
        if not def then
            state.preview_pet = nil
            return
        end
        if state.preview_pet and state.preview_pet.name == def.name then
            return
        end
        state.preview_pet = Pet.from_def(def)
    end

    local function preview_lines()
        local pane = {}
        for i = 1, PAGE do
            pane[i] = string.rep(" ", PANE_WIDTH)
        end

        if not state.preview_pet then return pane end

        local box = state.preview_pet:sprite_box()
        local frame =
            render.normalize_frame(state.preview_pet:peek_sprite(), box)
        local offset = math.floor((PAGE - box.rows) / 2)

        for i, sprite_line in ipairs(frame) do
            local row = offset + i
            if pane[row] then
                pane[row] = render.center_text(sprite_line, PANE_WIDTH)
            end
        end

        return pane
    end

    local function build_lines()
        local total = #state.filtered_pets
        state.win_top =
            menu._scroll(state.win_top, state.selected_idx, PAGE, total)

        local pane = preview_lines()
        local lines = {}

        for row = 1, PAGE do
            local idx = state.win_top + row - 1
            local def = state.filtered_pets[idx]

            local left
            if def then
                local marker = (idx == state.selected_idx) and g.marker or "  "
                left = pad_to(marker .. def.name, DIVIDER_COL)
            else
                left = string.rep(" ", DIVIDER_COL)
            end

            lines[row] = left .. g.vertical .. pane[row]
        end

        lines[RULE_ROW + 1] = string.rep(
            ui.rule_char(handle.border),
            DIVIDER_COL
        ) .. g.junction .. string.rep(
            ui.rule_char(handle.border),
            PANE_WIDTH
        )

        lines[PROMPT_ROW + 1] = pad_to("/ " .. state.query, WIDTH)

        return lines
    end

    local function render_menu()
        if not handle.is_valid() then return end

        local lines = build_lines()
        handle.set_lines(lines)

        local buf = handle.buf
        vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)

        local function mark(row, from, to, group)
            vim.api.nvim_buf_set_extmark(buf, NS, row, from, {
                end_col = to,
                hl_group = group,
            })
        end

        -- The divider and rule, so the two panes read as one frame. Names can
        -- contain multibyte glyphs, so the divider's byte column is not simply
        -- DIVIDER_COL.
        for row = 0, PAGE - 1 do
            local col = render.byte_offset(lines[row + 1], DIVIDER_COL)
            mark(row, col, col + #g.vertical, "TamagotchiRule")
        end
        mark(RULE_ROW, 0, #lines[RULE_ROW + 1], "TamagotchiRule")

        mark(PROMPT_ROW, 0, 1, "TamagotchiKey")

        -- A full-width bar across the list column only. It stops at the divider
        -- so it cannot paint over the preview, which belongs to the selection
        -- rather than competing with it.
        local total = #state.filtered_pets
        local sel_row = state.selected_idx - state.win_top
        if total > 0 and sel_row >= 0 and sel_row < PAGE then
            mark(
                sel_row,
                0,
                render.byte_offset(lines[sel_row + 1], DIVIDER_COL),
                "TamagotchiSelection"
            )
        end
    end

    local function update_filter()
        state.filtered_pets = {}
        for _, pet in ipairs(state.pets) do
            if menu.fuzzy_match(pet.name, state.query) then
                state.filtered_pets[#state.filtered_pets + 1] = pet
            end
        end

        state.selected_idx =
            math.max(1, math.min(state.selected_idx, #state.filtered_pets))
        state.win_top = 1

        update_preview()
        render_menu()
    end

    local function move(delta)
        local total = #state.filtered_pets
        if total == 0 then return end
        state.selected_idx =
            math.max(1, math.min(state.selected_idx + delta, total))
        update_preview()
        render_menu()
    end

    local function select_pet()
        -- Check before tearing anything down, so an empty filter leaves a
        -- working menu rather than a window with a dead timer behind it.
        local chosen_def = state.filtered_pets[state.selected_idx]
        if not chosen_def then return end

        close_menu()
        menu.switch_to(chosen_def, active_pet)
    end

    -- A real one-line input buffer, entered in insert mode, overlaying the
    -- prompt row so the text does not jump when it opens.
    --
    -- v1 mapped all 52 letters in normal mode to "append to query" -- after
    -- j/k/q/i had already been mapped, silently clobbering them -- and still
    -- could not handle paste, <C-w> or multibyte input.
    local function open_search()
        if input and input.is_valid() then
            vim.api.nvim_set_current_win(input.win)
            vim.cmd("startinsert!")
            return
        end

        input = ui.open({
            lines = { state.query },
            relative = "win",
            win = handle.win,
            row = PROMPT_ROW,
            col = 2,
            width = WIDTH - 2,
            height = 1,
            border = "none",
            zindex = 150,
            modifiable = true,
            filetype = "tamagotchi-menu",
            close_keys = {},
        })

        local input_buf = input.buf

        vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
            buffer = input_buf,
            callback = function()
                state.query = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1]
                    or ""
                update_filter()
            end,
        })

        local function leave_search()
            if input then input.close() end
            input = nil
            if handle.is_valid() then
                vim.api.nvim_set_current_win(handle.win)
            end
        end

        for _, mode in ipairs({ "n", "i" }) do
            local function imap(key, fn)
                vim.keymap.set(mode, key, fn, { buffer = input_buf })
            end

            imap("<Esc>", leave_search)
            imap("<CR>", function()
                leave_search()
                select_pet()
            end)
            imap("<C-n>", function() move(1) end)
            imap("<C-p>", function() move(-1) end)
            imap("<Down>", function() move(1) end)
            imap("<Up>", function() move(-1) end)
        end

        vim.cmd("startinsert!")
    end

    handle.map({ "j", "<Down>", "<C-n>" }, function() move(1) end)
    handle.map({ "k", "<Up>", "<C-p>" }, function() move(-1) end)
    handle.map({ "g" }, function() move(-#state.filtered_pets) end)
    handle.map({ "G" }, function() move(#state.filtered_pets) end)
    handle.map({ "<CR>" }, select_pet)
    handle.map({ "q", "<Esc>", "<C-c>" }, close_menu)
    handle.map({ "/", "i" }, open_search)

    state.animation_timer = vim.uv.new_timer()
    menu._active_timer = state.animation_timer
    state.animation_timer:start(
        1000,
        1000,
        vim.schedule_wrap(function()
            if closed or not handle.is_valid() then
                close_menu()
                return
            end
            if state.preview_pet then
                state.preview_pet:get_sprite()
                render_menu()
            end
        end)
    )

    update_preview()
    render_menu()
end

-- Adopt `chosen_def` as the active pet, asking first whether to carry progress
-- over or start that pet's own life.
function menu.switch_to(chosen_def, active_pet)
    local store = require("tamagotchi.store")
    local tamagotchi = require("tamagotchi")

    local function activate(pet)
        -- Rebinds vim_events too: v1 left the previous pet's event list
        -- installed after a switch.
        tamagotchi.bind_pet(pet)
        store.save_pet(pet)
        window.open(pet)
    end

    if active_pet and active_pet.name == chosen_def.name then
        window.open(active_pet)
        return
    end

    local function start_own_life()
        if active_pet then store.save_pet(active_pet) end

        local pet = store.load_pet(chosen_def.name) or Pet.from_def(chosen_def)

        vim.notify(
            "started caring for " .. pet.name .. "!",
            vim.log.levels.INFO
        )
        activate(pet)
    end

    if not active_pet then
        start_own_life()
        return
    end

    require("tamagotchi.dialogue").choice(
        "switch pet: " .. chosen_def.name,
        ("you currently have %s. would you like to transfer progress "):format(
            active_pet.name
        )
            .. "(just change appearance) or start a new pet life?\n\n"
            .. "note: you'll be caring for both pets independently.",
        "transfer progress",
        "start new life",
        function()
            local pet = Pet.from_def(chosen_def)
            active_pet:transfer_stats_to(pet)
            vim.notify(
                "transferred progress to " .. pet.name .. "!",
                vim.log.levels.INFO
            )
            activate(pet)
        end,
        start_own_life
    )
end

return menu
