MAKEFLAGS  := --no-print-directory
SRCPATH    := $(CURDIR)
BUILDPATH  ?= $(CURDIR)/build
MODPATH    := $(BUILDPATH)/Mods/Tech/DCT
VERSION    ?= $(shell git describe)

.PHONY: check check-syntax tests build
help:
	@echo 'Targets:'
	@echo '  check        - Run all unit tests and syntax checks'
	@echo '  check-syntax - Run luacheck lint checker'
	@echo '  tests        - Run unit tests'
	@echo '  build        - Build a releasable package, including docs'

clean:
	rm -rf $(BUILDPATH)

check-syntax:
	luacheck -q hooks scripts src/dct* tests

tests:
	rm -f "$(SRCPATH)"/data/*.state
	rm -f "$(SRCPATH)"/data/*.log
	@$(MAKE) -C tests

check: check-syntax tests

build-clean:
	rm -rf "$(BUILDPATH)"

build-setup: build-clean
	mkdir -p "$(MODPATH)"

build-src: build-setup
	cp -aL "$(SRCPATH)"/data/savedgames/Mods/Tech/DCT/lua \
		"$(MODPATH)"
	sed -e "s:%VERSION%:$(VERSION):" "$(SRCPATH)"/entry.lua.tpl > \
		"$(MODPATH)"/entry.lua
	sed -e "s:%VERSION%:$(VERSION):" "$(SRCPATH)"/src/dct.lua > \
		"$(MODPATH)"/lua/dct.lua
	mkdir -p "$(BUILDPATH)"/Scripts/Hooks
	cp -a "$(SRCPATH)"/hooks/* "$(BUILDPATH)"/Scripts/Hooks/
	mkdir -p "$(BUILDPATH)"/Config/
	cp -a "$(SRCPATH)"/data/savedgames/Config/dct.cfg \
		"$(BUILDPATH)"/Config/dct.cfg

build-demo: build-setup
	mkdir -p "$(BUILDPATH)"/DCT/
	cp -a "$(SRCPATH)"/data/savedgames/DCT/* "$(BUILDPATH)"/DCT/
	mkdir -p "$(BUILDPATH)"/Missions
	(mkdir -p "$(BUILDPATH)"/demomiz; \
		cd "$(BUILDPATH)"/demomiz; \
		cp -a "$(SRCPATH)"/data/mission/* .; \
		zip -r "../Missions/dct-demo-mission.miz" .)
	rm -rf "$(BUILDPATH)"/demomiz

build: build-src build-demo
	cp "$(SRCPATH)"/README.md "$(BUILDPATH)"/
	(cd "$(BUILDPATH)"; \
		zip -r "DCT-$(VERSION).zip" . && \
		mv DCT-$(VERSION).zip ../)
