import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

from PySide6.QtCore import QThread, Signal


class HelperWorker(QThread):
    output_line = Signal(str)
    output_message = Signal(str)
    helpers_loaded = Signal(list)
    tasks_loaded = helpers_loaded
    finished = Signal(int)

    def __init__(
        self, command, args, cwd=None, parse_helpers=False, parse_tasks=False
    ):
        super().__init__()
        self.command = command
        self.args = args
        self.cwd = cwd
        self.parse_helpers = parse_helpers or parse_tasks
        self.parse_tasks = self.parse_helpers

    def run(self):
        try:
            cmd = [self.command] + self.args
            creation_flags = (
                subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            )
            process = subprocess.Popen(
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
            collected_helpers = []
            if process.stdout:
                for line in iter(process.stdout.readline, ""):
                    if line:
                        trimmed = line.rstrip("\r\n")
                        if self.parse_helpers:
                            stripped = trimmed.strip()
                            if stripped:
                                collected_helpers.append(stripped)
                        else:
                            self.output_line.emit(trimmed)
                process.stdout.close()
            ret = process.wait()
            if self.parse_helpers:
                self.helpers_loaded.emit(collected_helpers)
            self.finished.emit(ret)
        except Exception as e:
            if self.parse_helpers:
                self.output_message.emit(f"Helper discovery error: {e}")
                self.helpers_loaded.emit([])
            else:
                self.output_line.emit(f"Process error: {e}")
            self.finished.emit(-1)


class HelperDiscoveryWorker(HelperWorker):
    def __init__(
        self,
        shell_exe=None,
        script_command=None,
        helpers_path=None,
        dotfiles_path=None,
        powershell_exe=None,
    ):
        target_shell = shell_exe or powershell_exe
        shell_cmd, shell_type = self._detect_shell(target_shell)

        if script_command is not None:
            if shell_type == "bash" and (
                "Get-Command" in script_command or "Test-Path" in script_command
            ):
                script_command = None
            elif shell_type == "powershell" and "compgen" in script_command:
                script_command = None

        if script_command is None:
            script_command = self._build_discovery_script(
                shell_type, helpers_path, dotfiles_path
            )

        if shell_type == "bash":
            args = ["-c", script_command]
        else:
            escaped_cmd = script_command.replace('"', '`"')
            args = [
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-Command",
                escaped_cmd,
            ]

        super().__init__(shell_cmd, args, parse_helpers=True)
        self.shell_cmd = shell_cmd
        self.shell_type = shell_type

    @staticmethod
    def _default_helpers_path():
        user_profile = str(Path.home())
        base_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            base_dir,
            os.path.join(user_profile, "src", "cli-helpers"),
            os.path.join(user_profile, "src", "dotfiles", "cli-helpers"),
            os.path.abspath(os.path.join(base_dir, "..")),
            os.path.abspath(os.path.join(base_dir, "..", "..")),
        ]
        for p in candidates:
            if os.path.isdir(p) and (
                os.path.isfile(os.path.join(p, "init.ps1"))
                or os.path.isfile(os.path.join(p, "init.sh"))
            ):
                return p
        return None

    @staticmethod
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

    @staticmethod
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

    @classmethod
    def _build_discovery_script(
        cls, shell_type, helpers_path=None, dotfiles_path=None
    ):
        if helpers_path is None:
            helpers_path = cls._default_helpers_path()
        if dotfiles_path is None:
            dotfiles_path = cls._default_dotfiles_path()

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
            parts.append(
                "compgen -A function -A alias | grep -E '^(win_|ubu_|my_)' | sort -u"
            )
            return " ".join(parts)
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
            parts.append(
                "Get-Command -CommandType Function, Alias | Where-Object { $_.Name -match '^(win_|ubu_|my_)' } | Select-Object -ExpandProperty Name | Sort-Object -Unique"
            )
            return " ".join(parts)


def build_helper_command(
    helper_name,
    shell_exe=None,
    helpers_path=None,
    dotfiles_path=None,
):
    shell_cmd, shell_type = HelperDiscoveryWorker._detect_shell(shell_exe)
    if helpers_path is None:
        helpers_path = HelperDiscoveryWorker._default_helpers_path()
    if dotfiles_path is None:
        dotfiles_path = HelperDiscoveryWorker._default_dotfiles_path()

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


class StatusCheckWorker(QThread):
    status_ready = Signal(dict)

    def __init__(self, helpers_path, dotfiles_path):
        super().__init__()
        self.helpers_path = helpers_path
        self.dotfiles_path = dotfiles_path

    def _is_repo_updated(self, repo_path, creation_flags):
        if not repo_path or not os.path.isdir(repo_path):
            return True
        try:
            subprocess.run(
                ["git", "-C", repo_path, "fetch", "origin", "main"],
                capture_output=True,
                timeout=4,
                creationflags=creation_flags,
            )
        except Exception:
            pass

        for ref in ["HEAD..@{u}", "HEAD..origin/main"]:
            try:
                res = subprocess.run(
                    ["git", "-C", repo_path, "rev-list", "--count", ref],
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
            "helpers_path": self.helpers_path or os.path.join(user_profile, "src", "cli-helpers"),
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
        try:
            res = subprocess.run(
                ["git", "--version"],
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
                        "git",
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
                        "git",
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
                                "git",
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
                self.helpers_path, creation_flags
            )

        if result["dotfiles_installed"]:
            result["dotfiles_updated"] = self._is_repo_updated(
                self.dotfiles_path, creation_flags
            )

        self.status_ready.emit(result)


__all__ = [
    "HelperWorker",
    "HelperDiscoveryWorker",
    "StatusCheckWorker",
    "build_helper_command",
]
