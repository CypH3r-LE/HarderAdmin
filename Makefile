SHELL := /bin/bash

SCRIPTS := harderadmin.sh install.sh uninstall.sh \
           $(wildcard lib/*.sh lib/checks/*.sh modules/*.sh tasks/*/*.sh)

.PHONY: help lint syntax check install uninstall audit

help:
	@echo "make lint       ShellCheck all scripts"
	@echo "make syntax     bash -n all scripts"
	@echo "make check      syntax + lint"
	@echo "make install    install to /opt/harderadmin (root)"
	@echo "make uninstall  remove /opt/harderadmin (root)"
	@echo "make audit      run a read-only audit from this checkout (root)"

syntax:
	@for f in $(SCRIPTS); do bash -n "$$f" || exit 1; done
	@echo "syntax ok"

lint:
	shellcheck -x -s bash -S style $(SCRIPTS)

check: syntax lint

install:
	./install.sh

uninstall:
	./uninstall.sh

audit:
	./harderadmin.sh --audit
