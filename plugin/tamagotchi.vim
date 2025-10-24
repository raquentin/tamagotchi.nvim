" link to existing highlight groups that respect the user's theme
" tab highlights - using more colorful options
highlight! default link TamagotchiTab1 DiffAdd
highlight! default link TamagotchiTab2 DiffChange
highlight! default link TamagotchiTab3 DiffDelete

" color picker highlights - using terminal colors
highlight! default link TamagotchiColorRed ErrorMsg
highlight! default link TamagotchiColorGreen DiffAdd
highlight! default link TamagotchiColorYellow WarningMsg
highlight! default link TamagotchiColorBlue Function
highlight! default link TamagotchiColorMagenta Constant
highlight! default link TamagotchiColorCyan Type
highlight! default link TamagotchiColorWhite Normal

if exists('g:loaded_tamagotchi')
  finish
endif
let g:loaded_tamagotchi = 1

lua require('tamagotchi').setup()
