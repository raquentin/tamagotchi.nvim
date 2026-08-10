#!/usr/bin/env bash
# Run the busted specs inside headless Neovim, so specs get a real `vim` global.
#
# This is what vusted does under the hood. We do it ourselves because vusted
# pulls in luasystem, which needs librt and so will not install on NixOS --
# and the dev shell is the primary way to work on this repo.
#
# Requires: nvim on PATH, and busted + luassert reachable via LUA_PATH.
# The nix dev shell provides both; see `make test-deps` for the non-nix path.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v nvim >/dev/null 2>&1; then
    echo "error: nvim not found on PATH" >&2
    exit 1
fi

# A locally installed rock tree (`make test-deps`) takes precedence, then
# whatever the environment already provides (nix dev shell, CI luarocks).
if [ -d .luarocks ]; then
    LUA_PATH=".luarocks/share/lua/5.1/?.lua;.luarocks/share/lua/5.1/?/init.lua;${LUA_PATH:-;}"
    LUA_CPATH=".luarocks/lib/lua/5.1/?.so;${LUA_CPATH:-;}"
    export LUA_PATH LUA_CPATH
fi

# The nix wrappers around busted bake their dependency paths into the launcher
# script rather than exporting them, so lift them back out when we find one.
if [ -z "${LUA_PATH:-}" ] && command -v busted >/dev/null 2>&1; then
    busted_bin="$(command -v busted)"
    if head -1 "$busted_bin" | grep -q '^#! */nix/store'; then
        LUA_PATH="$(sed -n "s/^LUA_PATH='\(.*\)'\$LUA_PATH\$/\1/p" "$busted_bin" | paste -sd';' -);;"
        LUA_CPATH="$(sed -n "s/^LUA_CPATH='\(.*\)'\$LUA_CPATH\$/\1/p" "$busted_bin" | paste -sd';' -);;"
        export LUA_PATH LUA_CPATH
    fi
fi

# Default to the whole suite; otherwise run just the spec files given as args.
if [ "$#" -gt 0 ]; then
    specs=("$@")
else
    mapfile -t specs < <(find test -name '*_spec.lua' | sort)
fi

if [ "${#specs[@]}" -eq 0 ]; then
    echo "error: no spec files found under test/" >&2
    exit 1
fi

printf 'running %d spec file(s)\n' "${#specs[@]}"

# Specs read and write through stdpath("data"). Point that at a throwaway
# directory so a test run can never touch a real pet's save file.
TEST_DATA_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DATA_DIR"' EXIT
export XDG_DATA_HOME="$TEST_DATA_DIR"

lua_specs=$(printf "'%s'," "${specs[@]}")

# `--clean` keeps a developer's own config out of the run. Prepending to rtp
# makes `require("tamagotchi.*")` resolve against this checkout rather than an
# installed copy of the plugin.
#
# Not exec'd, so the EXIT trap above still gets to remove the temp data dir.
nvim --headless --clean -n \
    --cmd "set rtp^=$PWD" \
    -c "lua _G.arg = {${lua_specs}}; require('busted.runner')({ standalone = false })" \
    -c "qa!"
