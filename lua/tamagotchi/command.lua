-- `:Tamagotchi [subcommand]`.
--
-- v1 had no user command at all: the only way in was the <leader>tg mapping, so
-- if that key was already taken the plugin was simply unreachable.
local M = {}

local function pet() return require("tamagotchi").ensure_setup() end

local SUBCOMMANDS = {
    open = function() require("tamagotchi.window").open(pet()) end,
    close = function() require("tamagotchi.window").close(pet()) end,
    toggle = function() require("tamagotchi.window").toggle(pet()) end,
    menu = function()
        pet()
        require("tamagotchi.menu").open_pet_menu()
    end,
    settings = function() require("tamagotchi.settings").show_settings(pet()) end,
    reset = function() require("tamagotchi.window").reset_dialogue(pet()) end,
    health = function()
        pet()
        vim.cmd("checkhealth tamagotchi")
    end,
}

-- Interaction verbs are registered by actions.lua so this table stays the one
-- place that knows the command surface.
function M.register(name, fn) SUBCOMMANDS[name] = fn end

function M.names()
    local out = {}
    for name in pairs(SUBCOMMANDS) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

function M.dispatch(opts)
    local name = vim.trim(opts.args or "")
    if name == "" then name = "toggle" end

    local fn = SUBCOMMANDS[name]
    if not fn then
        vim.notify(
            ("tamagotchi: unknown subcommand '%s' (try: %s)"):format(
                name,
                table.concat(M.names(), ", ")
            ),
            vim.log.levels.ERROR
        )
        return
    end

    local ok, err = pcall(fn)
    if not ok then
        vim.notify("tamagotchi: " .. tostring(err), vim.log.levels.ERROR)
    end
end

function M.complete(arg_lead)
    return vim.tbl_filter(
        function(name) return name:find(arg_lead, 1, true) == 1 end,
        M.names()
    )
end

function M.setup()
    -- Registers feed/play/pet/clean/revive into SUBCOMMANDS.
    require("tamagotchi.actions").setup()

    vim.api.nvim_create_user_command("Tamagotchi", M.dispatch, {
        nargs = "?",
        complete = M.complete,
        desc = "Tamagotchi: toggle, menu, settings, reset, ...",
    })
end

return M
