MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help
$(if $(filter Windows_NT,$(OS)),$(if $(shell where printf 2>nul),,$(error coreutils is not installed. Please run: winget install coreutils)))

.PHONY: help deps run gui build winget-pkg winget-submit release clean test icons

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps           Install dependencies" \
		"  run            Run GUI application" \
		"  gui            Run GUI application" \
		"  build          Build standalone executable with PyInstaller" \
		"  winget-pkg     Generate and validate Winget manifest" \
		"  winget-submit  Submit package manifest to winget-pkgs via wingetcreate" \
		"  release        Publish release and Winget manifest to GitHub via gh" \
		"  clean          Clean build artifacts" \
		"  test           Run unit tests"

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
	pyinstaller --noconfirm --clean --onefile --windowed --paths . --collect-all fluentqt --collect-all cli_helpers --add-data "cli_helpers/resources:cli_helpers/resources" --icon "cli_helpers/resources/icon.ico" --version-file version_info.txt --name cli-helpers cli_helpers/__main__.py

VERSION ?= $(shell python -c "from cli_helpers.version import __version__; print(__version__)")

winget-pkg: build
	mkdir -p dist/winget
	SHA256=$$(sha256sum dist/cli-helpers.exe | cut -b 1-64 | tr 'a-z' 'A-Z'); \
	sed -e "s/@VERSION@/$(VERSION)/g" packaging/alanlivio.clihelpers.yaml.in > dist/winget/alanlivio.clihelpers.yaml; \
	sed -e "s/@VERSION@/$(VERSION)/g" -e "s/@SHA256@/$$SHA256/g" packaging/alanlivio.clihelpers.installer.yaml.in > dist/winget/alanlivio.clihelpers.installer.yaml; \
	sed -e "s/@VERSION@/$(VERSION)/g" packaging/alanlivio.clihelpers.locale.en-US.yaml.in > dist/winget/alanlivio.clihelpers.locale.en-US.yaml
	winget validate dist/winget

winget-submit: winget-pkg
	TOKEN=$$(gh auth token 2>/dev/null || echo ""); \
	if [ -n "$$TOKEN" ]; then \
		wingetcreate submit dist/winget --prtitle "New package: alanlivio.clihelpers version $(VERSION)" --token "$$TOKEN"; \
	else \
		wingetcreate submit dist/winget --prtitle "New package: alanlivio.clihelpers version $(VERSION)"; \
	fi

release: winget-pkg
	@printf "SHA256 (exe): "
	sha256sum dist/cli-helpers.exe
	gh release upload v$(VERSION) dist/cli-helpers.exe dist/winget/* --clobber || gh release create v$(VERSION) dist/cli-helpers.exe dist/winget/* --generate-notes

test: icons
	python -m unittest discover -s tests
