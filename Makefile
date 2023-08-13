MAKEFLAGS  := --no-print-directory
SRCPATH    := $(CURDIR)
BUILDPATH  ?= $(CURDIR)/build
MODPATH    := $(BUILDPATH)/Mods/Tech/DCT
VERSION    ?= $(shell git describe)
LUALIBSVER := 7
LUALIBSAR  := v$(LUALIBSVER).zip
LUALIBSURL := https://github.com/jtoppins/lua-libs/archive/$(LUALIBSAR)
LUALIBSDIR := lua-libs-$(LUALIBSVER)

.PHONY: check check-syntax tests build
check-syntax:
	luacheck -q hooks mission scripts src tests

tests:
	rm -f "$(SRCPATH)"/data/*.state
	@$(MAKE) -C tests

check: check-syntax tests

build:
	mkdir -p "$(BUILDPATH)"/Mods/Tech/DCT/lua
	cp -a "$(SRCPATH)"/src/dct.lua "$(SRCPATH)"/src/dct/ "$(BUILDPATH)"/Mods/Tech/DCT/lua
	sed -e "s:%VERSION%:$(VERSION):" "$(SRCPATH)"/entry.lua.tpl > \
		"$(BUILDPATH)"/Mods/Tech/DCT/entry.lua
	sed -e "s:%VERSION%:$(VERSION):" "$(SRCPATH)"/src/dct.lua > \
		"$(BUILDPATH)"/Mods/Tech/DCT/lua/dct.lua
	mkdir -p "$(BUILDPATH)"/Scripts/Hooks
	cp -a "$(SRCPATH)"/mission/* "$(BUILDPATH)"/Scripts/
	cp -a "$(SRCPATH)"/hooks/* "$(BUILDPATH)"/Scripts/Hooks/
	mkdir -p "$(BUILDPATH)"/Config/
	cp -a "$(SRCPATH)"/data/Config/dct.cfg "$(BUILDPATH)"/Config/dct.cfg
	mkdir -p "$(BUILDPATH)"/DCT/
	cp -a "$(SRCPATH)"/data/DCT/* "$(BUILDPATH)"/DCT/
	mkdir -p "$(BUILDPATH)"/Missions
	(mkdir -p "$(BUILDPATH)"/demomiz; \
		cd "$(BUILDPATH)"/demomiz; \
		cp -a "$(SRCPATH)"/data/mission/* .; \
		cp "$(SRCPATH)"/mission/* l10n/DEFAULT/; \
		zip -r "../Missions/dct-demo-mission.miz" .)
	cp "$(SRCPATH)"/README.md "$(BUILDPATH)"/
	mkdir -p "$(BUILDPATH)"/temp
	(cd "$(BUILDPATH)"/temp; \
		wget -nv "$(LUALIBSURL)" >/dev/null && \
		unzip "$(LUALIBSAR)" >/dev/null && \
		cp -a "$(LUALIBSDIR)"/src/libs* "$(BUILDPATH)"/Mods/Tech/DCT/lua)
	(cd "$(BUILDPATH)"; \
		zip -r "DCT-$(VERSION).zip" Config DCT Missions Mods Scripts README.md && \
		mv DCT-$(VERSION).zip ../)
	rm -rf "$(BUILDPATH)"
