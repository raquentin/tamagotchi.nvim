if exists('g:loaded_tamagotchi')
  finish
endif
let g:loaded_tamagotchi = 1

lua require('tamagotchi').setup()
