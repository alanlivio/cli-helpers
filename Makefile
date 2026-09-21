MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help

.PHONY: help deps test gui

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  test     Run tests" \
		"  gui      Run GUI tool"

test:
	python -m unittest discover -s tests

gui:
	powershell -ExecutionPolicy Bypass -File gui/gui.ps1
