local ui = require("tamagotchi.ui")

local M = {}

local NS = ui.namespace

local WIDTH = 46

local function format_duration(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)

    if hours > 0 then
        return string.format("%dh %dm %ds", hours, minutes, secs)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

local COLORS = {
    { name = "red", hl = "TamagotchiColorRed" },
    { name = "green", hl = "TamagotchiColorGreen" },
    { name = "yellow", hl = "TamagotchiColorYellow" },
    { name = "blue", hl = "TamagotchiColorBlue" },
    { name = "magenta", hl = "TamagotchiColorMagenta" },
    { name = "cyan", hl = "TamagotchiColorCyan" },
    { name = "white", hl = "TamagotchiColorWhite" },
}

M.COLORS = COLORS

-- `x`, not `r`: rename already owns `r`, and reset is the one action here that
-- can destroy data, so it should not sit under a finger.
local ACTIONS = {
    { key = "r", label = "rename pet" },
    { key = "c", label = "choose color theme" },
    { key = "x", label = "reset pet" },
}

M.ACTIONS = ACTIONS

-- Keys sit at a fixed indent so the highlighter can find them by column rather
-- than by parsing the rendered line back apart.
local KEY_COL = 4

local function action_line(action)
    return ("%s%s   %s"):format(
        string.rep(" ", KEY_COL),
        action.key,
        action.label
    )
end

local function stat_line(label, value)
    return ("    %-10s%s"):format(label, value)
end

-- Locate a line by content rather than by a hard-coded index. v1 highlighted
-- line 11 ("times played") where it meant line 13 ("actions:"), and any edit to
-- the block above would have shifted it again.
local function index_of(lines, pattern)
    for i, line in ipairs(lines) do
        if line:match(pattern) then return i - 1 end
    end
    return nil
end

M._index_of = index_of

-- Split out so it can be tested without opening a window.
function M.build_lines(pet)
    local lines = {
        "",
        "  stats",
        stat_line("name", pet.name or "unknown"),
        stat_line("age", pet:get_age_formatted()),
        stat_line("mood", ("%d / 100"):format(math.floor(pet:get_mood()))),
        stat_line(
            "satiety",
            ("%d / 100"):format(math.floor(pet:get_satiety()))
        ),
        stat_line("session", format_duration(pet:get_session_duration())),
        stat_line("fed", tostring(pet.times_fed or 0)),
        stat_line("played", tostring(pet.times_played_with or 0)),
        "",
        "  actions",
    }

    for _, action in ipairs(ACTIONS) do
        lines[#lines + 1] = action_line(action)
    end

    lines[#lines + 1] = ""

    return lines
end

local function highlight(handle, lines)
    local buf = handle.buf

    local function mark(row, from, to, group)
        if not row then return end
        vim.api.nvim_buf_set_extmark(buf, NS, row, from, {
            end_col = to,
            hl_group = group,
        })
    end

    for _, pattern in ipairs({ "^%s*stats$", "^%s*actions$" }) do
        local row = index_of(lines, pattern)
        if row then mark(row, 0, #lines[row + 1], "TamagotchiMuted") end
    end

    -- Stat labels are dimmed so the values read first.
    for i, line in ipairs(lines) do
        if line:match("^    %S") and not line:match("^    %S   ") then
            mark(i - 1, 4, 14, "TamagotchiMuted")
        end
    end

    for _, action in ipairs(ACTIONS) do
        local row = index_of(lines, "^" .. vim.pesc(action_line(action)) .. "$")
        if row then
            mark(row, KEY_COL, KEY_COL + #action.key, "TamagotchiKey")
        end
    end
end

function M.show_settings(pet)
    assert(pet, "pet is required")

    local lines = M.build_lines(pet)

    local handle = ui.open({
        lines = lines,
        width = WIDTH,
        title = ui.chunks({ { "settings", "TamagotchiTitle" } }),
        footer = ui.key_chunks({ { key = "q", label = "close" } }),
        filetype = "tamagotchi-settings",
        close_keys = { "q", "Q", "<Esc>", "<C-c>", "<CR>", "<Space>", "s", "S" },
    })

    highlight(handle, lines)

    local function rename_pet()
        handle.close()

        require("tamagotchi.dialogue").input(
            "rename pet",
            "enter a new name for your pet:",
            pet.name,
            function(new_name)
                local store = require("tamagotchi.store")
                local old_name = pet.name

                -- Reject an unusable name before touching anything on disk.
                local ok, err = pcall(store.slug, new_name)
                if not ok then
                    vim.notify(
                        "tamagotchi: " .. tostring(err),
                        vim.log.levels.ERROR
                    )
                    return
                end

                pet:set_name(new_name)
                store.save_pet(pet)

                -- save_pet also repoints state.json at the new name, so the
                -- rename survives a restart; v1 left the pointer behind and a
                -- renamed pet came back as a different one.
                if old_name and old_name ~= new_name then
                    store.delete_pet(old_name)
                end

                require("tamagotchi.window").update_ui(pet, false)

                vim.notify(
                    ("renamed pet from '%s' to '%s'!"):format(
                        old_name,
                        new_name
                    ),
                    vim.log.levels.INFO
                )
            end,
            nil
        )
    end

    handle.map({ "r", "R" }, rename_pet)
    handle.map({ "c", "C" }, function()
        handle.close()
        M.show_color_picker(pet)
    end)
    handle.map({ "x", "X" }, function()
        handle.close()
        require("tamagotchi.window").reset_dialogue(pet)
    end)

    return handle.win
end

function M.show_color_picker(pet)
    local lines = { "" }

    for i, color in ipairs(COLORS) do
        lines[#lines + 1] = ("    %d   %s"):format(i, color.name)
    end

    lines[#lines + 1] = ""

    local handle = ui.open({
        lines = lines,
        width = 32,
        title = ui.chunks({ { "color theme", "TamagotchiTitle" } }),
        footer = ui.key_chunks({ { key = "esc", label = "cancel" } }),
        filetype = "tamagotchi-settings",
    })

    for i, color in ipairs(COLORS) do
        vim.api.nvim_buf_set_extmark(handle.buf, NS, i, KEY_COL, {
            end_col = KEY_COL + 1,
            hl_group = "TamagotchiKey",
        })
        vim.api.nvim_buf_set_extmark(handle.buf, NS, i, KEY_COL + 4, {
            end_col = KEY_COL + 4 + #color.name,
            hl_group = color.hl,
        })
    end

    local function select(color_data)
        handle.close()

        if not color_data then return end

        pet.color_theme = color_data.name
        require("tamagotchi.store").save_pet(pet)
        require("tamagotchi.window").update_ui(pet, false)

        vim.notify(
            ("selected %s theme!"):format(color_data.name),
            vim.log.levels.INFO
        )
    end

    for i, color in ipairs(COLORS) do
        handle.map({ tostring(i) }, function() select(color) end)
    end

    return handle.win
end

return M
