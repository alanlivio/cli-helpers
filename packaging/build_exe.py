import pathlib
import sys
import fluentqt
import PyInstaller.__main__
from PyInstaller.utils.hooks.qt import pyside6_library_info

ALLOWED_PLUGINS = ("platforms", "styles", "imageformats")
EXCLUDED_MODULES = [
    "PySide6.QtNetwork",
    "PySide6.QtOpenGL",
    "PySide6.QtOpenGLWidgets",
    "PySide6.QtSvg",
    "_hashlib",
    "ssl",
    "_ssl",
    "decimal",
    "_decimal",
    "lzma",
    "_lzma",
    "bz2",
    "_bz2",
]


def configure_qt_hooks():
    pyside6_library_info.collect_extra_binaries = lambda: []
    for mapping in (
        pyside6_library_info.python_modules,
        pyside6_library_info.shared_libraries,
    ):
        for info in mapping.values():
            info.translations = []
            if info.plugins:
                info.plugins = [p for p in info.plugins if p in ALLOWED_PLUGINS]

    orig_collect_plugins = pyside6_library_info.collect_plugins

    def collect_plugins(plugin_type):
        bins = orig_collect_plugins(plugin_type)
        if sys.platform == "win32" and plugin_type == "platforms":
            return [b for b in bins if "qwindows" in b[0].lower()]
        if plugin_type == "imageformats":
            return [b for b in bins if "qico" in b[0].lower()]
        return bins

    pyside6_library_info.collect_plugins = collect_plugins


def main():
    root_dir = pathlib.Path(__file__).resolve().parent.parent
    fluentqt_dir = pathlib.Path(fluentqt.__file__).resolve().parent
    configure_qt_hooks()

    args = [
        "--noconfirm",
        "--clean",
        "--onefile",
        "--windowed",
        "--paths",
        str(root_dir),
        "--add-data",
        f"{root_dir / 'cli_helpers' / 'resources' / 'icon.ico'}:cli_helpers/resources",
        "--add-data",
        f"{fluentqt_dir / '_icon_aliases.json'}:fluentqt",
        "--icon",
        str(root_dir / "cli_helpers" / "resources" / "icon.ico"),
        "--name",
        "cli-helpers",
    ]

    version_file = root_dir / "version_info.txt"
    if version_file.is_file():
        args.extend(["--version-file", str(version_file)])

    for mod in EXCLUDED_MODULES:
        args.extend(["--exclude-module", mod])

    args.append(str(root_dir / "cli_helpers" / "__main__.py"))
    PyInstaller.__main__.run(args)


if __name__ == "__main__":
    main()
