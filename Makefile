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

.PHONY: help deps run gui build package clean test  icons

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps     Install dependencies" \
		"  run      Run GUI application" \
		"  gui      Run GUI application" \
		"  build    Build standalone executable with PyInstaller" \
		"  package  Package standalone executable for WinGet release" \
		"  clean    Clean build artifacts" \
		"  test     Run unit tests"

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

package: build
	tar -a -c -f dist/cli-helpers-windows-x64.zip -C dist cli-helpers.exe
	@printf "Package built: dist/cli-helpers-windows-x64.zip\n"
	@printf "SHA256: "
	sha256sum dist/cli-helpers-windows-x64.zip

test: icons
	python -m unittest discover -s tests
