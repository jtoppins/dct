MAKEFLAGS = --no-print-directory

.PHONY: check
check:
	@$(MAKE) -C tests
