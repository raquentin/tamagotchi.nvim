SHELL := bash
.RECIPEPREFIX := >
.ONESHELL:

LUA_DIRS := lua plugin

STYLUA ?= stylua
LUACHECK ?= luacheck

.PHONY: help lint format ci

help:
> echo "Targets:"
> echo "  make lint    # luacheck + stylua --check"
> echo "  make format  # stylua ."
> echo "  make ci      # lint"

lint:
> $(LUACHECK) $(LUA_DIRS)
> $(STYLUA) --check .

format:
> $(STYLUA) .

ci: lint
