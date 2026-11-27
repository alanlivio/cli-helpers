import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.request
from pathlib import Path

from PySide6.QtCore import QThread, Signal

from .version import __version__

ALLOWED_MY_HELPERS = ("my_declutter", "my_dotfiles", "my_software")


def _parse_version_tuple(ver_str):
    cleaned = re.sub(r"^v", "", (ver_str or "").strip(), flags=re.IGNORECASE)
    parts = []
    for token in cleaned.split("."):
        m = re.match(r"^(\d+)", token)
        if m:
            parts.append(int(m.group(1)))
        else:
            break
    return tuple(parts)


def cleanup_old_exe(exe_path=None):
    target = exe_path if exe_path is not None else (
        sys.executable if getattr(sys, "frozen", False) else None
    )
    if not target:
        return
    for suffix in (".old", ".new"):
        stale = f"{target}{suffix}"
        if os.path.exists(stale):
            try:
                os.remove(stale)
            except OSError:
                pass


def _file_sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest().lower()


def _default_local_exe_path(helpers_path=None):
    if getattr(sys, "frozen", False):
        return sys.executable
    candidates = []
    if helpers_path:
        candidates.append(
            os.path.join(helpers_path, "dist", "shell-profile-helpers.exe")
        )
    candidates.append(
        str(
            Path(__file__).resolve().parent.parent
            / "dist"
            / "shell-profile-helpers.exe"
        )
    )
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def check_exe_update(
    repo="alanlivio/shell-profile-helpers", current_version=None, exe_path=None
):
    cur = current_version if current_version is not None else __version__
    url = f"https://api.github.com/repos/{repo}/releases/latest"
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "shell-profile-helpers",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
        tag = data.get("tag_name", "")
        if not tag:
            return False, "", ""
        assets = data.get("assets") or []
        target_asset = None
        for asset in assets:
            if asset.get("name", "").lower() == "shell-profile-helpers.exe":
                target_asset = asset
                break
        if target_asset is None:
            for asset in assets:
                if asset.get("name", "").lower().endswith(".exe"):
                    target_asset = asset
                    break
        if target_asset is None:
            return False, tag, ""
        dl_url = target_asset.get("browser_download_url", "")
        if not dl_url:
            return False, tag, ""

        remote_ver = _parse_version_tuple(tag)
        local_ver = _parse_version_tuple(cur)
        if remote_ver < local_ver:
            return False, tag, ""
        if remote_ver > local_ver:
            return True, tag, dl_url

        digest = (target_asset.get("digest") or "").strip()
        remote_sha = (
            digest.split(":", 1)[1].strip().lower()
            if ":" in digest
            else digest.lower()
        )
        local_target = (
            exe_path if exe_path is not None else _default_local_exe_path()
        )
        if remote_sha and local_target and os.path.isfile(local_target):
            if _file_sha256(local_target) != remote_sha:
                return True, tag, dl_url
        return False, tag, ""
    except Exception:
        pass
    return False, "", ""


def apply_exe_update(download_url, exe_path=None):
    if exe_path is None and not getattr(sys, "frozen", False):
        raise RuntimeError(
            "In-place update only applies to standalone shell-profile-helpers.exe (currently running from Python source)."
        )
    target_exe = exe_path or sys.executable
    new_path = f"{target_exe}.new"
    old_path = f"{target_exe}.old"

    req = urllib.request.Request(
        download_url,
        headers={"User-Agent": "shell-profile-helpers"},
    )
    with urllib.request.urlopen(req, timeout=60) as resp, open(new_path, "wb") as dst:
        shutil.copyfileobj(resp, dst)

    if os.path.getsize(new_path) < 2:
        os.remove(new_path)
        raise RuntimeError("Downloaded executable is empty.")

    with open(new_path, "rb") as f:
        if f.read(2) != b"MZ":
            os.remove(new_path)
            raise RuntimeError("Downloaded file is not a valid Windows executable.")

    if os.path.exists(old_path):
        try:
            os.remove(old_path)
        except OSError:
            pass

    os.replace(target_exe, old_path)
    try:
        os.replace(new_path, target_exe)
    except Exception:
        if os.path.exists(old_path) and not os.path.exists(target_exe):
            os.replace(old_path, target_exe)
        raise
    return target_exe


class ExeUpdateWorker(QThread):
    output_line = Signal(str)
    finished = Signal(bool, str)

    def __init__(self, download_url, exe_path=None):
        super().__init__()
        self.download_url = download_url
        self.exe_path = exe_path or sys.executable

    def run(self):
        try:
            self.output_line.emit(f"Downloading update from {self.download_url}...")
            updated_path = apply_exe_update(self.download_url, self.exe_path)
            self.output_line.emit("Executable updated. Restarting...")
            self.finished.emit(True, updated_path)
        except Exception as e:
            self.output_line.emit(f"Update failed: {e}")
            self.finished.emit(False, str(e))


class HelperWorker(QThread):
    output_line = Signal(str)
    finished = Signal(int)

    def __init__(self, command, args, cwd=None):
        super().__init__()
        self.command = command
        self.args = args
        self.cwd = cwd
        self.process = None
        self._killed = False

    def kill(self):
        self._killed = True
        proc = self.process
        if proc and proc.poll() is None:
            if sys.platform == "win32":
                try:
                    subprocess.run(
                        ["taskkill", "/F", "/T", "/PID", str(proc.pid)],
                        capture_output=True,
                        creationflags=subprocess.CREATE_NO_WINDOW,
                        timeout=5,
                    )
                except Exception:
                    pass
            try:
                proc.kill()
            except Exception:
                pass
        if self.isRunning():
            self.terminate()
            self.wait(500)

    def run(self):
        try:
            cmd = [self.command] + self.args
            creation_flags = (
                subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            )
            self.process = subprocess.Popen(
                cmd,
                cwd=self.cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
                creationflags=creation_flags,
            )
            if self.process.stdout:
                try:
                    for line in iter(self.process.stdout.readline, ""):
                        if self._killed:
                            break
                        if line:
                            self.output_line.emit(line.rstrip("\r\n"))
                except Exception:
                    pass
                finally:
                    try:
                        self.process.stdout.close()
                    except Exception:
                        pass
            try:
                ret = self.process.wait()
            except Exception:
                ret = -1
            if self._killed:
                return
            self.finished.emit(ret)
        except Exception as e:
            if self._killed:
                return
            self.output_line.emit(f"Process error: {e}")
            self.finished.emit(-1)


def _default_helpers_path():
    user_profile = str(Path.home())
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        base_dir,
        os.path.join(user_profile, "src", "shell-profile-helpers"),
        os.path.join(user_profile, "src", "dotfiles", "shell-profile-helpers"),
        os.path.abspath(os.path.join(base_dir, "..")),
        os.path.abspath(os.path.join(base_dir, "..", "..")),
        os.path.join(user_profile, "src", "cli-helpers"),
    ]
    for p in candidates:
        if os.path.isdir(p) and (
            os.path.isfile(os.path.join(p, "init.ps1"))
            or os.path.isfile(os.path.join(p, "init.sh"))
        ):
            return p
    return None


def _default_dotfiles_path():
    user_profile = str(Path.home())
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(user_profile, "src", "dotfiles"),
        os.path.abspath(os.path.join(base_dir, "..")),
        os.path.abspath(os.path.join(base_dir, "..", "..")),
        os.path.abspath(os.path.join(base_dir, "..", "..", "..")),
    ]
    for p in candidates:
        if os.path.isdir(p) and (
            os.path.isfile(os.path.join(p, "init.ps1"))
            or os.path.isfile(os.path.join(p, "init.sh"))
        ):
            return p
    return None


def _detect_shell(shell_exe=None):
    if shell_exe:
        if (
            sys.platform != "win32"
            and shell_exe.lower().endswith(".exe")
            and not shutil.which(shell_exe)
        ):
            bash = shutil.which("bash") or "/bin/bash" or "bash"
            return bash, "bash"
        base = os.path.basename(shell_exe).lower()
        if "bash" in base or base in ("sh", "zsh"):
            return shell_exe, "bash"
        if "powershell" in base or "pwsh" in base:
            return shell_exe, "powershell"
        if sys.platform != "win32":
            return shell_exe, "bash"
        return shell_exe, "powershell"

    if sys.platform != "win32":
        bash = shutil.which("bash") or "/bin/bash" or "bash"
        return bash, "bash"

    ps = (
        shutil.which("pwsh.exe")
        or shutil.which("powershell.exe")
        or "powershell.exe"
    )
    return ps, "powershell"


def build_helper_command(
    helper_name,
    shell_exe=None,
    helpers_path=None,
    dotfiles_path=None,
):
    if helper_name not in ALLOWED_MY_HELPERS:
        raise ValueError(f"Helper is not allowed: {helper_name}")

    shell_cmd, shell_type = _detect_shell(shell_exe)
    if helpers_path is None:
        helpers_path = _default_helpers_path()
    if dotfiles_path is None:
        dotfiles_path = _default_dotfiles_path()

    if shell_type == "bash":
        parts = []
        if helpers_path:
            init_sh = os.path.join(helpers_path, "init.sh")
            if os.path.isfile(init_sh):
                parts.append(f'[ -f "{init_sh}" ] && . "{init_sh}";')
        if dotfiles_path:
            init_sh = os.path.join(dotfiles_path, "init.sh")
            if os.path.isfile(init_sh):
                parts.append(f'[ -f "{init_sh}" ] && . "{init_sh}";')
        parts.append(helper_name)
        return shell_cmd, ["-c", " ".join(parts)]
    else:
        parts = []
        if helpers_path:
            init_ps1 = os.path.join(helpers_path, "init.ps1")
            if os.path.isfile(init_ps1):
                parts.append(
                    f"if (Test-Path '{init_ps1}') {{ . '{init_ps1}' }};"
                )
        if dotfiles_path:
            init_ps1 = os.path.join(dotfiles_path, "init.ps1")
            if os.path.isfile(init_ps1):
                parts.append(
                    f"if (Test-Path '{init_ps1}') {{ . '{init_ps1}' }};"
                )
        parts.append(f"& {helper_name}")
        full_script = " ".join(parts)
        escaped_script = full_script.replace('"', '`"')
        return shell_cmd, [
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            escaped_script,
        ]


def get_git_executable():
    cmd = shutil.which("git")
    if cmd:
        return cmd
    if sys.platform == "win32":
        candidates = [
            os.path.join(
                os.environ.get("LOCALAPPDATA", ""),
                "Programs",
                "Git",
                "cmd",
                "git.exe",
            ),
            os.path.join(
                os.environ.get("ProgramFiles", r"C:\Program Files"),
                "Git",
                "cmd",
                "git.exe",
            ),
            os.path.join(
                os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
                "Git",
                "cmd",
                "git.exe",
            ),
            os.path.join(
                os.environ.get("LOCALAPPDATA", ""),
                "Programs",
                "Git",
                "bin",
                "git.exe",
            ),
            os.path.join(
                os.environ.get("ProgramFiles", r"C:\Program Files"),
                "Git",
                "bin",
                "git.exe",
            ),
        ]
        for c in candidates:
            if c and os.path.isfile(c):
                cmd_dir = os.path.dirname(c)
                current_paths = os.environ.get("PATH", "").split(os.pathsep)
                if cmd_dir not in current_paths:
                    os.environ["PATH"] = (
                        cmd_dir + os.pathsep + os.environ.get("PATH", "")
                    )
                return c

    return "git"


class StatusCheckWorker(QThread):
    status_ready = Signal(dict)

    def __init__(self, helpers_path, dotfiles_path):
        super().__init__()
        self.helpers_path = helpers_path
        self.dotfiles_path = dotfiles_path
        self._killed = False

    def kill(self):
        self._killed = True
        if self.isRunning():
            self.terminate()
            self.wait(500)

    def _is_repo_updated(self, repo_path, creation_flags, git_cmd=None):
        if not repo_path or not os.path.isdir(repo_path):
            return True
        cmd_exe = git_cmd or get_git_executable()
        try:
            subprocess.run(
                [cmd_exe, "-C", repo_path, "fetch", "origin", "main"],
                capture_output=True,
                timeout=4,
                creationflags=creation_flags,
            )
        except Exception:
            pass

        for ref in ["HEAD..@{u}", "HEAD..origin/main"]:
            try:
                res = subprocess.run(
                    [cmd_exe, "-C", repo_path, "rev-list", "--count", ref],
                    capture_output=True,
                    text=True,
                    timeout=2,
                    creationflags=creation_flags,
                )
                if res.returncode == 0 and res.stdout.strip().isdigit():
                    count = int(res.stdout.strip())
                    if count > 0:
                        return False
            except Exception:
                pass
        return True

    def run(self):
        user_profile = str(Path.home())
        result = {
            "winget_installed": False,
            "winget_version": "",
            "git_installed": False,
            "git_version": "",
            "helpers_installed": bool(
                self.helpers_path
                and (
                    os.path.isfile(os.path.join(self.helpers_path, "init.ps1"))
                    or os.path.isfile(os.path.join(self.helpers_path, "init.sh"))
                )
            ),
            "helpers_updated": True,
            "helpers_path": self.helpers_path
            or os.path.join(user_profile, "src", "shell-profile-helpers"),
            "helpers_user": "",
            "dotfiles_installed": bool(
                self.dotfiles_path
                and (
                    os.path.isfile(os.path.join(self.dotfiles_path, "init.ps1"))
                    or os.path.isfile(os.path.join(self.dotfiles_path, "init.sh"))
                )
            ),
            "dotfiles_updated": True,
            "dotfiles_path": self.dotfiles_path or os.path.join(user_profile, "src", "dotfiles"),
            "dotfiles_user": "",
        }

        creation_flags = (
            subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        )
        winget_cmd = shutil.which("winget")
        if not winget_cmd and sys.platform == "win32":
            local_appdata = os.environ.get("LOCALAPPDATA", "")
            if local_appdata:
                candidate = os.path.join(
                    local_appdata, "Microsoft", "WindowsApps", "winget.exe"
                )
                if os.path.isfile(candidate):
                    winget_cmd = candidate
        if not winget_cmd:
            winget_cmd = "winget"

        try:
            res = subprocess.run(
                [winget_cmd, "--version"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=creation_flags,
            )
            if res.returncode == 0 and res.stdout:
                result["winget_installed"] = True
                raw = res.stdout.strip()
                result["winget_version"] = raw if raw.startswith("v") else f"v{raw}"
        except Exception:
            pass

        git_cmd = get_git_executable()
        try:
            res = subprocess.run(
                [git_cmd, "--version"],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=creation_flags,
            )
            if res.returncode == 0 and res.stdout:
                result["git_installed"] = True
                raw = res.stdout.strip()
                result["git_version"] = re.sub(
                    r"^git version\s*", "v", raw, flags=re.IGNORECASE
                )
        except Exception:
            pass

        if self.helpers_path and os.path.isdir(self.helpers_path):
            try:
                res = subprocess.run(
                    [
                        git_cmd,
                        "-C",
                        self.helpers_path,
                        "config",
                        "--get",
                        "remote.origin.url",
                    ],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    creationflags=creation_flags,
                )
                if res.returncode == 0 and res.stdout:
                    match = re.search(r"github\.com[:/]([^/]+)", res.stdout)
                    if match:
                        result["helpers_user"] = match.group(1).replace(
                            ".git", ""
                        ).strip()
            except Exception:
                pass

        if not result["helpers_user"]:
            result["helpers_user"] = "alanlivio"

        if self.dotfiles_path and os.path.isdir(self.dotfiles_path):
            try:
                res = subprocess.run(
                    [
                        git_cmd,
                        "-C",
                        self.dotfiles_path,
                        "config",
                        "--get",
                        "remote.origin.url",
                    ],
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    creationflags=creation_flags,
                )
                if res.returncode == 0 and res.stdout:
                    match = re.search(r"github\.com[:/]([^/]+)", res.stdout)
                    if match:
                        result["dotfiles_user"] = match.group(1).replace(
                            ".git", ""
                        ).strip()
            except Exception:
                pass

            if not result["dotfiles_user"]:
                gitconfig_path = os.path.join(self.dotfiles_path, ".gitconfig")
                if os.path.isfile(gitconfig_path):
                    try:
                        res = subprocess.run(
                            [
                                git_cmd,
                                "config",
                                "--file",
                                gitconfig_path,
                                "--get",
                                "github.user",
                            ],
                            capture_output=True,
                            text=True,
                            encoding="utf-8",
                            errors="replace",
                            creationflags=creation_flags,
                        )
                        if (
                            res.returncode == 0
                            and res.stdout
                            and "error:" not in res.stdout
                        ):
                            result["dotfiles_user"] = res.stdout.strip()
                    except Exception:
                        pass

        if result["helpers_installed"]:
            result["helpers_updated"] = self._is_repo_updated(
                self.helpers_path, creation_flags, git_cmd=git_cmd
            )

        if result["dotfiles_installed"]:
            result["dotfiles_updated"] = self._is_repo_updated(
                self.dotfiles_path, creation_flags, git_cmd=git_cmd
            )

        result["exe_version"] = f"v{__version__.lstrip('v')}"
        result["exe_update_available"] = False
        result["exe_latest_version"] = ""
        result["exe_download_url"] = ""
        if self.helpers_path or self.dotfiles_path or getattr(sys, "frozen", False):
            repo_owner = result["helpers_user"] or "alanlivio"
            local_exe = _default_local_exe_path(self.helpers_path)
            has_upd, latest_ver, dl_url = check_exe_update(
                f"{repo_owner}/shell-profile-helpers", exe_path=local_exe
            )
            result["exe_update_available"] = has_upd
            result["exe_latest_version"] = latest_ver
            result["exe_download_url"] = dl_url

        if not self._killed:
            self.status_ready.emit(result)


__all__ = [
    "ALLOWED_MY_HELPERS",
    "HelperWorker",
    "StatusCheckWorker",
    "ExeUpdateWorker",
    "build_helper_command",
    "get_git_executable",
    "check_exe_update",
    "apply_exe_update",
    "cleanup_old_exe",
]
