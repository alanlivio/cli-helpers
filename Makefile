MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps run-gui gui publish-gui clean test icons docs

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps               Install dependencies" \
		"  run-gui            Run GUI application" \
		"  gui                Build standalone executable with PyInstaller" \
		"  publish-gui        Publish release to GitHub via gh" \
		"  clean              Clean build artifacts" \
		"  test               Run unit tests" \
		"  icons              Compile GUI icons" \
		"  docs               Compile D2 documentation diagrams"

deps:
	python -m pip install -e ".[dev]"

run-gui:
	python -m cli_helpers

clean:
	rm -rf dist build ./*.egg-info ./*.spec cli_helpers/resources/icon.ico cli_helpers/resources/icon.png cli_helpers/resources/icon.svg

D2 ?= d2

icons: cli_helpers/resources/icon.ico

cli_helpers/resources/icon.ico: cli_helpers/icon.d2
	$(D2) --pad 0 cli_helpers/icon.d2 cli_helpers/resources/icon.svg
	node -e "const fs=require('fs'),p='cli_helpers/resources/icon.svg';fs.writeFileSync(p,fs.readFileSync(p,'utf8').replace(/font-family: [^;]+;/, 'font-family: Consolas, monospace; font-weight: bold;'))"
	npx --yes sharp-cli -i cli_helpers/resources/icon.svg -o cli_helpers/resources/icon.png resize 256 256
	npx --yes icon-gen -i cli_helpers/resources/icon.svg -o cli_helpers/resources --ico --ico-name icon -r

docs:
	$(D2) --pad 0 docs/bash_flow.d2 docs/bash_flow.svg
	$(D2) --pad 0 docs/powershell_flow.d2 docs/powershell_flow.svg

gui: dist/cli-helpers.exe

dist/cli-helpers.exe: cli_helpers/resources/icon.ico $(wildcard cli_helpers/*.py) packaging/build_exe.py
	python packaging/build_exe.py

VERSION ?= $(shell python -c "from cli_helpers.version import __version__; print(__version__)")

publish-gui: dist/cli-helpers.exe
	@printf "SHA256 (exe): "
	sha256sum dist/cli-helpers.exe
	gh release upload v$(VERSION) dist/cli-helpers.exe --clobber || gh release create v$(VERSION) dist/cli-helpers.exe --generate-notes

test: cli_helpers/resources/icon.ico
	python -m unittest discover -s tests
