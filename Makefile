SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

# Only lua/ holds .lua files; plugin/ is a single lua-in-vim shim.
LUA_DIRS := lua plugin test scripts

STYLUA ?= stylua
LUACHECK ?= luacheck

.PHONY: help lint luacheck format test test-deps ci demo

help:
	echo "Targets:"
	echo "  make lint       # luacheck + stylua --check"
	echo "  make format     # stylua ."
	echo "  make test       # run the busted specs in headless nvim"
	echo "  make test-deps  # install busted+luassert into ./.luarocks"
	echo "  make ci         # lint + test (exactly what CI runs)"
	echo "  make demo       # re-record media/demo.gif with vhs"

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

demo:
	./scripts/record-demo.sh
