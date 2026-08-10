# README demo. Run it through scripts/record-demo.sh, which points the XDG
# directories at a throwaway save, provisions the fonts and exports $DEMO_DIR
# and $REPO_ROOT.
#
#   ./scripts/record-demo.sh
#
# Sleep after every keypress that opens or closes a float: <Esc> followed
# immediately by a letter arrives as a meta key, and the pet menu needs a moment
# to draw its first preview frame.

Output media/demo.gif

Require nvim

Set Shell "bash"
Set FontFamily "JetBrains Mono"
Set FontSize 16
Set Width 1000
Set Height 620
Set Padding 18
Set Framerate 20
Set TypingSpeed 70ms
Set Theme "Catppuccin Mocha"

# Boot Neovim off-camera, so the clip opens on the editor.
Hide
Type "cd $DEMO_DIR && clear" Enter
Type "nvim -u $REPO_ROOT/scripts/demo/init.lua tamagotchi.lua" Enter
Sleep 4s
Show

# The statusline component: the pet is there before any window is.
Sleep 2500ms

# <leader>tg toggles the float. Sasha is hungry -- the satiety bar is red.
Space
Type "tg"
Sleep 3s

# The four interactions. Each flashes the stat it moved, in green.
Type "f"
Sleep 3s
Type "p"
Sleep 3s
Type "t"
Sleep 2500ms
Type "c"
Sleep 2500ms

# Every float in the plugin answers `?`.
Type "?"
Sleep 3s
Type "q"
Sleep 1500ms

# The pet menu, with animated previews of the other pets.
Type "m"
Sleep 2500ms
Type "j"
Sleep 1500ms
Type "j"
Sleep 1500ms
Type "j"
Sleep 1500ms

# `/` filters the list; picking Sasha again reopens the pet window.
#
# The first <Esc> is the search box's own mapping, which only hands focus back
# to the list -- the second is what actually leaves insert mode. Pressing <CR>
# from inside the box instead would pick the pet while still in insert mode, and
# every keystroke after that lands in a nomodifiable buffer and is swallowed.
Type "/"
Sleep 800ms
Type "sa"
Sleep 2s
Escape
Sleep 800ms
Escape
Sleep 800ms
Enter
Sleep 2500ms

# Settings: stats, rename, colour theme, and the reset that is deliberately
# not one keystroke from the main window.
Type "s"
Sleep 3s
Type "c"
Sleep 2s
# Red. The themes are highlight links, so which ones read as a change depends on
# the colorscheme: under Mocha `red` is #f38ba8 against Sasha's #89b4fa, while
# `green` links to `DiffAdd`, which is background-only here and would tint
# nothing at all.
Type "1"
Sleep 3s

# Back to Sasha's own blue.
Type "s"
Sleep 1200ms
Type "c"
Sleep 1200ms
Type "4"
Sleep 2500ms

# Close the float; the pet keeps living in the statusline.
Type "q"
Sleep 2s

# vim_events: yanking and writing feed the pet while you work.
Type "yyp"
Sleep 1500ms
Type ":w"
Enter
Sleep 3s

Space
Type "tg"
Sleep 3500ms

Hide
Type "q"
Sleep 500ms
