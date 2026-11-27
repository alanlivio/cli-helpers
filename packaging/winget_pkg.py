import hashlib
import pathlib
import sys

ROOT_DIR = pathlib.Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from gui.version import __version__


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else __version__
    root_dir = pathlib.Path(__file__).resolve().parent.parent
    exe_path = root_dir / "dist" / "shell-profile-helpers.exe"
    sha = hashlib.sha256(exe_path.read_bytes()).hexdigest().upper()

    out_dir = root_dir / "dist" / "winget"
    out_dir.mkdir(parents=True, exist_ok=True)

    templates = [
        "alanlivio.shellprofilehelpers.yaml",
        "alanlivio.shellprofilehelpers.installer.yaml",
        "alanlivio.shellprofilehelpers.locale.en-US.yaml",
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
