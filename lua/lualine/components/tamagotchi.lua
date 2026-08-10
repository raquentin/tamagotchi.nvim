-- lualine component, so `{ "tamagotchi" }` works with no glue code:
--
--   require("lualine").setup({
--     sections = { lualine_x = { "tamagotchi" } },
--   })
--
-- Options are passed through to tamagotchi.statusline.get, e.g.
--   { "tamagotchi", ascii = true, name = false }
local ok, lualine_component = pcall(require, "lualine.component")
if not ok then return {} end

local Component = lualine_component:extend()

function Component:init(options)
    Component.super.init(self, options)
    self.tamagotchi_opts = {
        ascii = options.ascii,
        name = options.name,
    }
end

function Component:update_status()
    return require("tamagotchi.statusline").get(self.tamagotchi_opts)
end

return Component
