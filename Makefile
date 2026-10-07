MAKEFLAGS += -s --no-print-directory
.DEFAULT_GOAL := help

GLOBAL_PYTHON ?= $(shell if [ -x /usr/bin/python3 ]; then echo /usr/bin/python3; else echo python3; fi)

.PHONY: help deps run gui build clean wheel install-global publish-pypi test

help:
	@printf "%s\n" \
		"Usage: make [target]" \
		"" \
		"Targets:" \
		"  deps            Install dependencies" \
		"  run             Run GUI application" \
		"  gui             Run GUI application" \
		"  build           Build wheel package" \
		"  clean           Clean build artifacts" \
		"  wheel           Build and check wheel" \
		"  install-global  Install built wheel globally" \
		"  publish-pypi    Publish wheel to PyPI" \
		"  test            Run unit tests"

deps:
	python -m pip install --upgrade pip
	pip install -e .[dev]

run:
	python -m cli_helpers

gui:
	python -m cli_helpers

clean:
	rm -rf dist build ./*.egg-info

build:
	python -m build --wheel

wheel: clean
	pip install -e .[dev]
	python -m build --wheel
	twine check dist/*

install-global: wheel
	$(GLOBAL_PYTHON) -m pip install --force-reinstall --break-system-packages dist/*.whl

publish-pypi: wheel
	twine upload dist/*

test:
	python -m unittest discover -s tests
