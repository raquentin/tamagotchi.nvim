SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

# Only lua/ holds .lua files; plugin/ is a single lua-in-vim shim.
LUA_DIRS := lua plugin

STYLUA ?= stylua
LUACHECK ?= luacheck

# Pinned so a new stylua release cannot turn CI red with no repo change.
# Keep in sync with .github/workflows/ci.yml and flake.nix.
STYLUA_VERSION := 2.5.2

.PHONY: help lint luacheck format test test-deps ci

help:
	echo "Targets:"
	echo "  make lint       # luacheck + stylua --check"
	echo "  make format     # stylua ."
	echo "  make test       # run the busted specs in headless nvim"
	echo "  make test-deps  # install busted+luassert into ./.luarocks"
	echo "  make ci         # lint + test (exactly what CI runs)"

luacheck:
	$(LUACHECK) $(LUA_DIRS)

lint: luacheck
	$(STYLUA) --check .

format:
	$(STYLUA) .

test:
	./scripts/test.sh

# Only needed outside the nix dev shell, which already provides these.
test-deps:
	luarocks --tree .luarocks install busted
	luarocks --tree .luarocks install luassert

ci: lint test
