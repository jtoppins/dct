MAKEFLAGS  := --no-print-directory

PHONY := __all
__all:

unexport LC_ALL
unexport GREP_OPTIONS

this-makefile := $(lastword $(MAKEFILE_LIST))
srctree := $(realpath $(dir $(this-makefile)))

# Beautify output
# ----------------------------------------------------------------
# Build commands start with "cmd_". You can optionally define
# "quiet_cmd_*". If defined, the short log is printed. Otherwise, no log from
# that command is printed by default.
#
# e.g.)
#    quiet_cmd_install = INSTALL  $(SOURCE)
#          cmd_install = $(INSTALL) $(SOURCE) $(DEST)
#
# A simple variant is to prefix commands with $(Q) - that's useful
# for commands that shall be hidden in non-verbose mode.
#
#    $(Q)$(INSTALL) foo
#
# If BUILD_VERBOSE contains 1, the whole command is echoed.
# Use 'make V=1' to see the full commands

ifeq ("$(origin V)", "command line")
	BUILD_VERBOSE = $(V)
endif

quiet = quiet_
Q = @

ifneq ($(findstring 1, $(BUILD_VERBOSE)),)
	quiet =
	Q =
endif

# If the user is running make -s (silent mode), suppress echoing of
# commands
ifneq ($(findstring s,$(firstword -$(MAKEFLAGS))),)
quiet=silent_
override BUILD_VERBOSE :=
endif

export quiet Q BUILD_VERBOSE

cmd = $(if $(Q),@set -e; echo "$(quiet_cmd_$(1))"; $(cmd_$(1)),$(cmd_$(1)))

# prefix is used to change the install target
INSTALLPREFIX := $(if $(PREFIX), "$(PREFIX)"/,)
DCT_VERSION   ?= $(shell git describe)

# Make variables
INSTALL               = install
INSTALLFLAGS          = --compare
ZIP                   = zip
TAR                   = tar
SED                   = sed
LUA                   = lua5.1
LUACC                 = luac
LUACHECK              = luacheck
LUATESTS              = busted
PATCH                 = patch
PATCHFLAGS            = --ignore-whitespace -s -N -r -
TZ                    = "UTC 0"
MOD_INSTALL_PATH      := $(INSTALLPREFIX)Mods/tech/DCT
LUA_INSTALL_PATH      := $(MOD_INSTALL_PATH)/lua
CONFIG_INSTALL_PATH   := $(INSTALLPREFIX)Config
HOOKS_INSTALL_PATH    := $(INSTALLPREFIX)Scripts/Hooks
MISSION_INSTALL_PATH  := $(INSTALLPREFIX)Missions
DCT_DATA_ROOT         := $(srctree)/data
MISSIONSCRIPTING      = $(realpath $(GAMEROOT)/Scripts/MissionScripting.lua)
DCS_PATCHFILE         = $(srctree)/patches/dcs.patch

export PREFIX DCT_VERSION
export INSTALL INSTALLFLAGS ZIP TAR SED LUA LUACC LUACHECK LUABUSTED TZ
export MOD_INSTALL_PATH CONFIG_INSTALL_PATH HOOKS_INSTALL_PATH
export MISSION_INSTALL_PATH DCT_DATA_ROOT

generated_files := entry.lua src/dct.lua
rm-files := $(generated_files)
install-targets = dct_install

PHONY += all
__all: all

PHONY += all
all: generated

PHONY += generated
generated: $(generated_files)

quiet_cmd_dct_install = INSTALL DCT
      cmd_dct_install = \
		mkdir -p $(LUA_INSTALL_PATH); \
		mkdir -p $(CONFIG_INSTALL_PATH); \
		mkdir -p $(HOOKS_INSTALL_PATH); \
		cp -aL "$(srctree)"/src/* $(LUA_INSTALL_PATH); \
		cp -aL "$(srctree)"/hooks/* $(HOOKS_INSTALL_PATH); \
		$(INSTALL) $(INSTALLFLAGS) -m 644 -t $(MOD_INSTALL_PATH) \
			"$(srctree)"/entry.lua; \
		$(INSTALL) $(INSTALLFLAGS) --backup=numbered -m 644 \
			-t $(CONFIG_INSTALL_PATH) \
			"$(srctree)"/data/savedgames/Config/dct.cfg; \
		find $(INSTALLPREFIX) \( -name '*.lua.in' \) -type f -print \
			| xargs rm -rf

quiet_cmd_dct_remove = RM      DCT
      cmd_dct_remove = \
		rm -rf $(MOD_INSTALL_PATH); \
		rm -f $(HOOKS_INSTALL_PATH)/dct-*

_do_patch = $(PATCH) $(PATCHFLAGS) $(1) $(2) || true
patchfile = $(if $(Q),@set -e; echo "PATCH   $(shell basename $(1))"; \
	    $(call _do_patch,$(1),$(2)), $(call _do_patch,$(1),$(2)))

PHONY += dct_install demomiz_install install patch_game
dct_install: generated
	$(if $(PREFIX),$(call cmd,dct_install),$(error PREFIX not defined.))

patch_game:
ifeq ($(MISSIONSCRIPTING),)
	@echo "Due to permission errors you need to apply the following"
	@echo "patch manually to '<DCS_GAME_ROOT>/Scripts/MissionScripting.lua':"
	@cat $(DCS_PATCHFILE)
else
	$(if $(wildcard $(MISSIONSCRIPTING)),,$(error no GAMEROOT defined))
	$(call patchfile,$(MISSIONSCRIPTING),$(DCS_PATCHFILE))
endif

demomiz_install:
	$(error TODO: write me; install the demo mission that comes with DCT)

install-targets += patch_game
#install-targets += demomiz_install

install: $(install-targets)

PHONY += uninstall
uninstall:
	$(if $(PREFIX),$(call cmd,dct_remove),$(error PREFIX not defined.))

PHONY += check syntax tests
check: syntax tests

syntax:
	$(Q)$(LUACHECK) -q hooks src/dct* tests

rm-test-files := data/savedgames/*.state data/*.log
rm-files += $(rm-test-files)

tests: generated
	$(Q)rm -f $(rm-test-files)
	$(Q)(cd tests; busted)

PHONY += generated
generated: $(generated_files)

PHONY += clean distclean
distclean: clean
	$(Q)rm -f *.zip

clean:
	$(call cmd,rmfiles)

PHONY += help
help:
	@echo 'Targets:'
	@echo '  clean        - Remove all built artifacts'
	@echo '  distclean    - Remove packaged artifacts'
	@echo '  check        - Run all unit tests and syntax checks'
	@echo '  syntax       - Run luacheck lint checker'
	@echo '  tests        - Run unit tests'
	@echo '  install      - Install mod into the directory specified by'
	@echo '                 PREFIX'
	@echo '  uninstall    - Uninstall mod that was installed to PREFIX'
	@echo '  dist         - Build a releasable package, including docs'
	@echo ''
	@echo 'Variables:'
	@echo '  PREFIX       - the location where you want DCT installed'
	@echo ''
	@echo 'Example:'
	@echo '  make install PREFIX=/mnt/c/Users/userfoo/Saved\ Games/DCS'
	@echo ''
	@echo 'This will install DCT into "userfoo" saved games folder'

quiet_cmd_rmfiles = CLEAN  $(rm-files)
      cmd_rmfiles = rm -rf $(rm-files)

quiet_cmd_genfile = GEN    $@
      cmd_genfile = \
		$(SED) -e "s:%VERSION%:$(DCT_VERSION):" $< > $@

$(generated_files): %.lua: %.lua.in
	$(call cmd,genfile)

.PHONY: $(PHONY)
