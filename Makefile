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
	python -m gui

clean:
	rm -rf dist build ./*.egg-info ./*.spec gui/resources/icon.ico gui/resources/icon.png gui/resources/icon.svg

D2 ?= d2

icons: gui/resources/icon.ico

gui/resources/icon.ico: gui/icon.d2
	$(D2) --pad 0 gui/icon.d2 gui/resources/icon.svg
	node -e "const fs=require('fs'),p='gui/resources/icon.svg';let s=fs.readFileSync(p,'utf8').replace(/font-family: [^;]+;/,'font-family: Consolas, monospace; font-weight: 900;').replace(/x=.64. y=.[0-9.]+./,'x=\x220\x22 y=\x2219.5\x22 transform=\x22translate(64,64) scale(1.10,2.25)\x22');fs.writeFileSync(p,s);"
	npx --yes sharp-cli -i gui/resources/icon.svg -o gui/resources/icon.png resize 256 256
	npx --yes icon-gen -i gui/resources/icon.svg -o gui/resources --ico --ico-name icon -r

docs:
	$(D2) --pad 0 docs/bash_flow.d2 docs/bash_flow.svg
	$(D2) --pad 0 docs/powershell_flow.d2 docs/powershell_flow.svg

gui: dist/shell-profile-helpers.exe

dist/shell-profile-helpers.exe: gui/resources/icon.ico $(wildcard gui/*.py) packaging/build_exe.py
	python packaging/build_exe.py

VERSION ?= $(shell python -c "from gui.version import __version__; print(__version__)")

publish-gui: dist/shell-profile-helpers.exe
	@printf "SHA256 (exe): "
	sha256sum dist/shell-profile-helpers.exe
	gh release upload v$(VERSION) dist/shell-profile-helpers.exe --clobber || gh release create v$(VERSION) dist/shell-profile-helpers.exe --generate-notes

test: gui/resources/icon.ico
	python -m unittest discover -s tests
