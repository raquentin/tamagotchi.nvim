# 🐱 tamagotchi.nvim

is a configurable plugin for raising pets across Neovim sessions.

https://github.com/user-attachments/assets/8462955d-ad6c-4499-9d9f-8265ba00fd0f

## Features
- Floating Window UI: Displays your pet with sprite animations, stats, and a colored bottom bar with interactive tabs.
- Customizable Behavior: Configure tick length, decay probabilities, and Vim events that affect your pet's mood and satiety.
- Multiple Pets: Manage a list of pets, select different ones from a menu, view more info, and reset as needed.
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
require('tamagotchi').setup({
  window_toggle_keybind = "<leader>tg",
  tick_length_ms = 1000, -- 1 second per tick
  default_pet = "Lucy",
  pets = {
    {
      name = "Ilya",

      sprite_update_interval = 5,
      sprites = kitty_sprites,

      initial_mood = 75,
      initial_satiety = 75,
      decay_speed = 2, -- 0-6 scale (0=none, 6=extreme)

      vim_events = {
        {
          name = "BufWritePost",
          mood_increment = 5,
          satiety_increment = 3,
        },
        {
          name = "TextYankPost",
          mood_increment = 2,
          satiety_increment = 1,
        },
      },
    },
  },
})
```

## Native Pets

- **Kitty**: a cat (moderate decay, balanced)
- **Lucy**: a star and mascot of the [Gleam programming language](https://gleam.run/) (faster decay, food-focused)
- **Churro**: a dog (moderate decay, mood-focused)
- **Bunny**: a bunny (active, high satiety needs)
- **Dragon**: a dragon (slow decay, hardy)
- **Grizz**: a bear (moderate decay, very hungry)

<img width="905" height="519" alt="Screenshot 2025-10-17 at 11 10 15 PM" src="https://github.com/user-attachments/assets/fddf828d-2c86-49c2-a157-49bcac81467f" />

## Contributing

Submit issues and PRs as you please. If you have a more general question, start a [discussion](https://github.com/raquentin/tamagotchi.nvim/discussions).
