MAKEFLAGS  := --no-print-directory
SRCPATH    := $(CURDIR)
BUILDPATH  ?= $(CURDIR)/build
VERSION    ?= $(shell git describe)
LUALIBSVER := 5
LUALIBSAR  := v$(LUALIBSVER).zip
LUALIBSURL := https://github.com/jtoppins/lua-libs/archive/$(LUALIBSAR)
LUALIBSDIR := lua-libs-$(LUALIBSVER)

.PHONY: check build
check:
	@$(MAKE) -C tests

build:
	mkdir -p $(BUILDPATH)/DCT/lua
	cp -a $(SRCPATH)/src/dct.lua $(SRCPATH)/src/dct/ $(BUILDPATH)/DCT/lua
	sed -e "s:%VERSION%:$(VERSION):" $(SRCPATH)/entry.lua.tpl > \
		$(BUILDPATH)/DCT/entry.lua
	sed -e "s:%VERSION%:$(VERSION):" $(SRCPATH)/src/dct.lua > \
		$(BUILDPATH)/DCT/lua/dct.lua
	cp -a $(SRCPATH)/mission $(BUILDPATH)/DCT/
	mkdir -p $(BUILDPATH)/HOOKS
	cp -a $(SRCPATH)/hooks/* $(BUILDPATH)/HOOKS/
	cp $(SRCPATH)/README.md $(BUILDPATH)/
	mkdir -p $(BUILDPATH)/temp
	(cd $(BUILDPATH)/temp; \
		wget -q $(LUALIBSURL) >/dev/null; \
		unzip $(LUALIBSAR) >/dev/null; \
		cp -a $(LUALIBSDIR)/src/libs* $(BUILDPATH)/DCT/lua)
	(cd $(BUILDPATH); \
		zip -r "DCT-$(VERSION).zip" HOOKS DCT README.md; \
		mv DCT-$(VERSION).zip ../)
	rm -rf $(BUILDPATH)
