MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help

.PHONY: help deps run test

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps     Install dependencies" \
		"  run      Run GUI application" \
		"  test     Run unit tests"

deps:
	python -m pip install --upgrade pip
	pip install PyQt5 PyQt-Fluent-Widgets pyinstaller


run:
	python gui.py

test:
	python -m unittest discover -s ../tests
