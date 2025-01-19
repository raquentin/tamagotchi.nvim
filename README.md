# 🐱 tamagotchi.nvim

A configurable plugin for raising pets across Neovim sessions.

> [!WARNING]  
> This project is days old. The `.setup({` API will change often.

## Features
- Floating Window UI: Displays your pet with sprite animations, stats, and a colored bottom bar with interactive tabs.
- Customizable Behavior: Configure tick length, decay probabilities, and Vim events that affect your pet's mood and satiety.
- Multiple Pets: Manage a list of pets, select different ones from a menu, view more info, and reset as needed.
- Persistent State: Your pet's mood and satiety persist across Neovim sessions.
- Extensible Tabs: A bottom bar that you can configure to open menus, display info, and perform actions like reset.

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
require('tamagotchi').setup({
  keybind = "<leader>tg", -- toggles tamagotchi window
  tick_length_ms = 100, -- defines window refresh rate
  mood_decay_probability = 0.02, -- probability of mood decreasing by 1 on a given tick
  satiety_decay_probability = 0.02, -- probability of satiety decreasing by 1 on a given tick
  vim_events = {
    -- listen to buffer writes and update mood accordingly
    { name = "BufWritePost", mood_increment = 5, satiety_increment = 0 },
    -- listen to text yanks and update satiety accordingly
    { name = "TextYankPost", mood_increment = 0, satiety_increment = 2 },
  },
  default_pet = "Mitchell",
  pets = {
    {
      name = "Mitchell",
      initial_mood = 80, -- mood the pet is born with
      initial_satiety = 80, -- satiety the pet is born with
      sprite_update_interval = 5, -- only loop through the sprites every `n` ticks
      sprites = {
        happy = { " ^_^ ", " (^-^) " },
        hungry = { " >_< ", " (U_U) " },
        neutral = { " -_- ", " (._.) " },
      },
    },
    -- additional pet definitions...
  },
})
```

## Screenshot
![2025-01-19T00:05:57,318965100-05:00](https://github.com/user-attachments/assets/78a046eb-c9fe-4e70-8a83-f5f705810779)

## Contributing

Submit issues and PRs as you please.

If you have a more general question, start a [discussion](https://github.com/raquentin/tamagotchi.nvim/discussions).
