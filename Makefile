MAKEFLAGS = --no-print-directory

LUA_PATH := $(CURDIR)/src/?.lua;$(CURDIR)/../lua-libs/src/?.lua;;
export LUA_PATH

.PHONY: check
check:
	@$(MAKE) -C tests
