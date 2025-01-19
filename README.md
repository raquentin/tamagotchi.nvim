# 🐱 tamagotchi.nvim

A configurable plugin for raising pets across Neovim sessions.

> [!WARNING]  
> This project is days old. The `.setup({` API will change often.

## Features
- Floating Window UI: Displays your pet with sprite animations, stats, and a colored bottom bar with interactive tabs.
- Customizable Behavior: Configure tick length, decay probabilities, and Vim events that affect your pet's mood and satiety.
- (soon) Multiple Pets: Manage a list of pets, select different ones from a menu, view more info, and reset as needed.
- Persistent State: Your pet's mood and satiety persist across Neovim sessions.

## Installation

#### vim-plug

```vim
Plug "raquentin/tamagotchi.nvim"
```

#### packer.nvim

```lua
use { "raquentin/tamagotchi.nvim", }
```

#### lazy.nvim

```lua
{ "raquentin/tamagotchi.nvim", }
```

## Configuration

```lua
```lua
require('tamagotchi').setup({
  window_toggle_keybind = "<leader>tg",  -- toggles the tamagotchi.nvim overlay
  tick_length_ms = 100,                  -- inverse of refresh rate (ms)
  default_pet = "Ilya",                  -- name of pet to load on startup

  -- define foreign pets here
  -- list of native pets: https://github.com/raquentin/tamagotchi.nvim?tab=readme-ov-file#native-pets
  pets = {
    {
      name = "Mitchell",
      initial_mood = 80,                -- mood the pet is born with
      initial_satiety = 80,             -- satiety the pet is born with
      sprite_update_interval = 5,       -- update sprite frame every n ticks
      mood_decay_probability = 0.02,    -- probability of mood decreasing by 1 on a given tick
      satiety_decay_probability = 0.02, -- probability of satiety decreasing by 1 on a given tick
      vim_events = {                    -- events affecting mood and satiety for this pet
        { name = "BufWritePost", mood_increment = 5, satiety_increment = 0 },
        { name = "TextYankPost", mood_increment = 0, satiety_increment = 2 },
      },
      sprites = {
        happy = { " ^_^ ", " (^-^) " },
        hungry = { " >_< ", " (U_U) " },
        neutral = { " -_- ", " (._.) " },
      },
    },
    -- additional pet definitions can be added here
    -- your config's pets list will be merged with the native one
  },
})
```
```

## Screenshot
![2025-01-19T00:05:57,318965100-05:00](https://github.com/user-attachments/assets/78a046eb-c9fe-4e70-8a83-f5f705810779)

## Contributing

Submit issues and PRs as you please.

If you have a more general question, start a [discussion](https://github.com/raquentin/tamagotchi.nvim/discussions).
