import hashlib
import pathlib
import sys

from cli_helpers.version import __version__


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else __version__
    root_dir = pathlib.Path(__file__).resolve().parent.parent
    exe_path = root_dir / "dist" / "cli-helpers.exe"
    sha = hashlib.sha256(exe_path.read_bytes()).hexdigest().upper()

    out_dir = root_dir / "dist" / "winget"
    out_dir.mkdir(parents=True, exist_ok=True)

    templates = [
        "alanlivio.clihelpers.yaml",
        "alanlivio.clihelpers.installer.yaml",
        "alanlivio.clihelpers.locale.en-US.yaml",
    ]

    for name in templates:
        src = root_dir / "packaging" / f"{name}.in"
        content = (
            src.read_text(encoding="utf-8")
            .replace("@VERSION@", version)
            .replace("@SHA256@", sha)
        )
        (out_dir / name).write_text(content, encoding="utf-8")


if __name__ == "__main__":
    main()
