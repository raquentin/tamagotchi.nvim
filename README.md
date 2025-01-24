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
  window_toggle_keybind = "<leader>tg",
  tick_length_ms = 100,
  default_pet = "Lucy",
  pets = {
    {
      name = "Ilya",

      sprite_update_interval = 5,
      sprites = kitty_sprites,

      initial_mood = 95,
      initial_satiety = 95,
      decay_speed = 3,

      vim_events = {
        {
          name = "BufWritePost",
          mood_increment = 22,
          satiety_increment = 2,
        },
        {
          name = "TextYankPost",
          mood_increment = 0,
          satiety_increment = 13,
        },
      },
    },
  },
})
```

## Screenshot
![2025-01-19T00:05:57,318965100-05:00](https://github.com/user-attachments/assets/78a046eb-c9fe-4e70-8a83-f5f705810779)

## Native Pets

- Ilya: a cat
- Lucy: a star and mascot of the [Gleam programming language](https://gleam.run/)

## Contributing

Submit issues and PRs as you please.

If you have a more general question, start a [discussion](https://github.com/raquentin/tamagotchi.nvim/discussions).
