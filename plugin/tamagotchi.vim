highlight! default TamagotchiTab1 guifg=#ffffff guibg=DarkCyan
highlight! default TamagotchiTab2 guifg=#ffffff guibg=DarkBlue
highlight! default TamagotchiTab3 guifg=#ffffff guibg=DarkRed

if exists('g:loaded_tamagotchi')
  finish
endif
let g:loaded_tamagotchi = 1

lua require('tamagotchi').setup()
