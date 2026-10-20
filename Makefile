MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))
ifeq ($(OS),Windows_NT)
  SH := $(shell where sh 2>nul)
  ifeq ($(SH),)
    SH := $(shell git --exec-path 2>nul)/../../../bin/sh.exe
  endif
  ifneq ($(wildcard $(SH)),)
    SHELL := $(SH)
  endif
endif

.PHONY: help deps run gui build release-windows clean test icons

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps             Install dependencies" \
		"  run              Run GUI application" \
		"  gui              Run GUI application" \
		"  build            Build standalone executable with PyInstaller" \
		"  release-windows  Package and publish Windows release to GitHub via gh" \
		"  clean            Clean build artifacts" \
		"  test             Run unit tests"

deps:
	python -m pip install -e ".[dev]"

run:
	python -m cli_helpers

gui:
	python -m cli_helpers

clean:
	rm -rf dist build ./*.egg-info ./*.spec cli_helpers/resources

D2 ?= d2

icons:
	mkdir -p cli_helpers/resources
	$(D2) --pad 0 cli_helpers/icon.d2 cli_helpers/resources/icon.svg
	node -e "const fs=require('fs'),p='cli_helpers/resources/icon.svg';fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/font-family: [^;]+;/, 'font-family: Consolas, monospace; font-weight: bold;'))"
	npx --yes sharp-cli -i cli_helpers/resources/icon.svg -o cli_helpers/resources/icon.png resize 256 256
	npx --yes icon-gen -i cli_helpers/resources/icon.svg -o cli_helpers/resources --ico --ico-name icon -r

build: icons
	pyinstaller --noconfirm --clean --onefile --windowed --paths . --collect-all fluentqt --collect-data cli_helpers --icon "cli_helpers/resources/icon.ico" --version-file version_info.txt --name cli-helpers cli_helpers/__main__.py

VERSION ?= $(shell python -c "from cli_helpers.version import __version__; print(__version__)")

release-windows: build
	@printf "SHA256: "
	sha256sum dist/cli-helpers.exe
	gh release upload v$(VERSION) dist/cli-helpers.exe --clobber || gh release create v$(VERSION) dist/cli-helpers.exe --generate-notes

test: icons
	python -m unittest discover -s tests
