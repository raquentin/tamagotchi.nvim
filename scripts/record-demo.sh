#!/usr/bin/env bash
# Record media/demo.gif from scripts/demo.tape.
#
# The recording runs against a throwaway XDG_DATA_HOME, so it neither reads nor
# writes a real pet, and every run starts from the same seeded state.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

DEMO_DIR="${TMPDIR:-/tmp}/tamagotchi-demo"
export DEMO_DIR

rm -rf "$DEMO_DIR"
mkdir -p "$DEMO_DIR"

# The buffer visible behind the float, which is also a working install snippet.
cp "$REPO_ROOT/scripts/demo/plugins.lua" "$DEMO_DIR/tamagotchi.lua"

export XDG_DATA_HOME="$DEMO_DIR/data"
export XDG_STATE_HOME="$DEMO_DIR/state"
export XDG_CACHE_HOME="$DEMO_DIR/cache"

# VHS renders through a headless browser, which sees only the fonts fontconfig
# can find. With no monospace font installed it silently falls back to a
# proportional one and the whole UI comes out ragged, so put the two the tape
# asks for where fontconfig looks: $XDG_DATA_HOME/fonts, which is inside the
# throwaway directory and leaves the machine's own font setup alone.
if ! fc-list : family | grep -qi "JetBrains Mono"; then
    mkdir -p "$XDG_DATA_HOME/fonts"
    for font in jetbrains-mono noto-fonts-color-emoji; do
        store_path="$(nix build --no-link --print-out-paths "nixpkgs#$font")"
        find "$store_path" \( -name '*.ttf' -o -name '*.otf' \) \
            -exec ln -sf {} "$XDG_DATA_HOME/fonts/" \;
    done
fi

# The colorscheme, fetched the same way, so the recording does not depend on
# whatever is installed for the person running it.
CATPPUCCIN="$(nix build --no-link --print-out-paths nixpkgs#vimPlugins.catppuccin-nvim)"
export CATPPUCCIN

mkdir -p "$REPO_ROOT/media"
cd "$REPO_ROOT"

if command -v vhs >/dev/null 2>&1; then
    vhs scripts/demo.tape
else
    nix run nixpkgs#vhs -- scripts/demo.tape
fi

echo "wrote $REPO_ROOT/media/demo.gif"
