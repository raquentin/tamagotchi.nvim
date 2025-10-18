" link to existing highlight groups that respect the user's theme
highlight! default link TamagotchiTab1 PmenuSel
highlight! default link TamagotchiTab2 Visual
highlight! default link TamagotchiTab3 DiffChange
highlight! default link TamagotchiTab4 DiffDelete

if exists('g:loaded_tamagotchi')
  finish
endif
let g:loaded_tamagotchi = 1

lua require('tamagotchi').setup()
