import io
import os
import sys
import re
import signal
import subprocess
from pathlib import Path

os.environ.setdefault(
    "QT_LOGGING_RULES",
    "qt.qpa.fonts.warning=false;qt.text.font.warning=false;*.debug=false",
)

try:
    import PyQt5

    _qt5_fonts = os.path.join(
        os.path.dirname(PyQt5.__file__), "Qt5", "lib", "fonts"
    )
    os.makedirs(_qt5_fonts, exist_ok=True)
except Exception:
    pass

from PyQt5.QtCore import (
    Qt,
    QThread,
    pyqtSignal,
    QTimer,
    qInstallMessageHandler,
)
from PyQt5.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QSizePolicy,
)
from PyQt5.QtGui import QFont, QPalette, QColor

_stdout = sys.stdout
_stderr = sys.stderr
try:
    sys.stdout = io.StringIO()
    sys.stderr = io.StringIO()
    from qframelesswindow import FramelessWindow
    from qfluentwidgets import (
        MSFluentTitleBar,
        setTheme,
        Theme,
        FluentIcon,
        CardWidget,
        SubtitleLabel,
        BodyLabel,
        CaptionLabel,
        PushButton,
        PrimaryPushButton,
        ComboBox,
        LineEdit,
        TextEdit,
        IndeterminateProgressBar,
        InfoBadge,
        InfoLevel,
    )
finally:
    sys.stdout = _stdout
    sys.stderr = _stderr


def _handle_exception(exctype, value, tb):
    if issubclass(exctype, KeyboardInterrupt):
        QApplication.quit()
        sys.exit(0)
    sys.__excepthook__(exctype, value, tb)


sys.excepthook = _handle_exception


def _qt_message_handler(mode, context, message):
    if "Cannot find font directory" in message or "Qt no longer ships fonts" in message:
        return


qInstallMessageHandler(_qt_message_handler)



class CommandWorker(QThread):
    output_line = pyqtSignal(str)
    finished = pyqtSignal(int)

    def __init__(self, command, args, cwd=None):
        super().__init__()
        self.command = command
        self.args = args
        self.cwd = cwd

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
            if process.stdout:
                for line in iter(process.stdout.readline, ""):
                    if line:
                        self.output_line.emit(line.rstrip("\r\n"))
                process.stdout.close()
            ret = process.wait()
            self.finished.emit(ret)
        except Exception as e:
            self.output_line.emit(f"Process error: {e}")
            self.finished.emit(-1)


class TaskLoaderWorker(QThread):
    tasks_loaded = pyqtSignal(list)
    output_message = pyqtSignal(str)

    def __init__(self, powershell_exe, script_command):
        super().__init__()
        self.powershell_exe = powershell_exe
        self.script_command = script_command

    def run(self):
        try:
            creation_flags = (
                subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            )
            escaped_cmd = self.script_command.replace('"', '`"')
            res = subprocess.run(
                [
                    self.powershell_exe,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-Command",
                    escaped_cmd,
                ],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=creation_flags,
            )
            tasks = []
            if res.returncode == 0 and res.stdout:
                for line in res.stdout.splitlines():
                    trimmed = line.strip()
                    if trimmed:
                        tasks.append(trimmed)
            self.tasks_loaded.emit(tasks)
        except Exception as e:
            self.output_message.emit(f"Task discovery error: {e}")
            self.tasks_loaded.emit([])


class StatusCheckWorker(QThread):
    status_ready = pyqtSignal(dict)

    def __init__(self, helpers_path, dotfiles_path):
        super().__init__()
        self.helpers_path = helpers_path
        self.dotfiles_path = dotfiles_path

    def run(self):
        result = {
            "git_installed": False,
            "git_version": "",
            "helpers_installed": bool(
                self.helpers_path
                and os.path.isfile(os.path.join(self.helpers_path, "init.ps1"))
            ),
            "dotfiles_installed": bool(
                self.dotfiles_path
                and os.path.isfile(os.path.join(self.dotfiles_path, "init.ps1"))
            ),
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

        self.status_ready.emit(result)


class MainWindow(FramelessWindow):
    def __init__(self):
        super().__init__()
        self.resize(620, 820)

        self._active_worker = None
        self._cached_ps_exe = None

        palette = self.palette()
        palette.setColor(QPalette.Window, QColor("#202020"))
        self.setPalette(palette)

        self.title_bar = MSFluentTitleBar(self)
        self.setTitleBar(self.title_bar)
        self.setWindowTitle("cli-helpers GUI")
        self.title_bar.setTitle("cli-helpers GUI")

        if sys.platform == "win32":
            try:
                from qframelesswindow.windows import win_utils
                if win_utils.isGreaterEqualWin11():
                    self.windowEffect.setMicaEffect(int(self.winId()), isDarkMode=True)
                    self.setStyleSheet("""
                        MainWindow {
                            background: transparent;
                        }
                        #rootWidget {
                            background: transparent;
                        }
                    """)
                else:
                    self.setStyleSheet("""
                        MainWindow {
                            background-color: #202020;
                        }
                        #rootWidget {
                            background: transparent;
                        }
                    """)
            except Exception:
                self.setStyleSheet("""
                    MainWindow {
                        background-color: #202020;
                    }
                    #rootWidget {
                        background: transparent;
                    }
                """)
        else:
            self.setStyleSheet("""
                MainWindow {
                    background-color: #202020;
                }
                #rootWidget {
                    background: transparent;
                }
            """)

        self._init_ui()
        self._center_window()
        self.refresh_all()

    def _center_window(self):
        screen = QApplication.primaryScreen()
        if screen:
            geo = screen.availableGeometry()
            x = max(0, (geo.width() - self.width()) // 2)
            y = max(0, (geo.height() - self.height()) // 2)
            self.move(x, y)

    def _init_ui(self):
        root_widget = QWidget(self)
        root_widget.setObjectName("rootWidget")
        root_layout = QVBoxLayout(root_widget)
        root_layout.setContentsMargins(24, 8, 24, 20)
        root_layout.setSpacing(14)

        setup_card = CardWidget(self)
        setup_layout = QVBoxLayout(setup_card)
        setup_layout.setContentsMargins(16, 14, 16, 14)
        setup_layout.setSpacing(10)

        setup_header = QHBoxLayout()
        self.setup_title = SubtitleLabel("Setup")
        self.btn_refresh_all = PushButton("Refresh All", self, FluentIcon.SYNC)
        self.btn_refresh_all.clicked.connect(self.refresh_all)
        setup_header.addWidget(self.setup_title)
        setup_header.addStretch()
        setup_header.addWidget(self.btn_refresh_all)
        setup_layout.addLayout(setup_header)

        git_row = QHBoxLayout()
        git_label = BodyLabel("Git:")
        git_label.setFixedWidth(100)
        self.git_badge = InfoBadge.info("Checking...")
        self.btn_install_git = PushButton("Install Git")
        self.btn_install_git.setFixedWidth(135)
        self.btn_install_git.clicked.connect(self.install_git)
        git_row.addWidget(git_label)
        git_row.addWidget(self.git_badge)
        git_row.addStretch()
        git_row.addWidget(self.btn_install_git)
        setup_layout.addLayout(git_row)

        helpers_row = QHBoxLayout()
        helpers_label = BodyLabel("cli-helpers:")
        helpers_label.setFixedWidth(100)
        self.helpers_badge = InfoBadge.info("Checking...")
        self.btn_install_helpers = PushButton("Install helpers")
        self.btn_install_helpers.setFixedWidth(135)
        self.btn_install_helpers.clicked.connect(self.install_or_update_helpers)
        helpers_row.addWidget(helpers_label)
        helpers_row.addWidget(self.helpers_badge)
        helpers_row.addStretch()
        helpers_row.addWidget(self.btn_install_helpers)
        setup_layout.addLayout(helpers_row)

        dotfiles_row = QHBoxLayout()
        dotfiles_label = BodyLabel("dotfiles:")
        dotfiles_label.setFixedWidth(100)
        self.dotfiles_badge = InfoBadge.info("Checking...")
        self.tb_username = LineEdit()
        self.tb_username.setPlaceholderText("GitHub username")
        self.tb_username.setFixedWidth(140)
        self.btn_clone_dotfiles = PushButton("Download dotfiles")
        self.btn_clone_dotfiles.setFixedWidth(135)
        self.btn_clone_dotfiles.clicked.connect(self.clone_or_update_dotfiles)
        dotfiles_row.addWidget(dotfiles_label)
        dotfiles_row.addWidget(self.dotfiles_badge)
        dotfiles_row.addStretch()
        dotfiles_row.addWidget(self.tb_username)
        dotfiles_row.addWidget(self.btn_clone_dotfiles)
        setup_layout.addLayout(dotfiles_row)

        root_layout.addWidget(setup_card)

        tasks_card = CardWidget(self)
        tasks_layout = QVBoxLayout(tasks_card)
        tasks_layout.setContentsMargins(16, 14, 16, 14)
        tasks_layout.setSpacing(10)

        tasks_header = QHBoxLayout()
        self.tasks_title = SubtitleLabel("Automation Tasks")
        self.btn_reload_tasks = PushButton("Reload Tasks", self, FluentIcon.SYNC)
        self.btn_reload_tasks.clicked.connect(self.initialize_tasks)
        tasks_header.addWidget(self.tasks_title)
        tasks_header.addStretch()
        tasks_header.addWidget(self.btn_reload_tasks)
        tasks_layout.addLayout(tasks_header)

        task_selector_row = QHBoxLayout()
        self.task_selector = ComboBox()
        self.task_selector.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Fixed
        )
        self.btn_run_task = PrimaryPushButton("Run Task", self, FluentIcon.PLAY)
        self.btn_run_task.setFixedWidth(135)
        self.btn_run_task.clicked.connect(self.run_task)
        task_selector_row.addWidget(self.task_selector)
        task_selector_row.addWidget(self.btn_run_task)
        tasks_layout.addLayout(task_selector_row)

        root_layout.addWidget(tasks_card)

        output_card = CardWidget(self)
        output_layout = QVBoxLayout(output_card)
        output_layout.setContentsMargins(16, 14, 16, 14)
        output_layout.setSpacing(10)

        output_header = QHBoxLayout()
        self.output_title = SubtitleLabel("Output log")
        self.btn_clear_output = PushButton("Clear", self, FluentIcon.DELETE)
        self.btn_clear_output.clicked.connect(self.clear_output)
        output_header.addWidget(self.output_title)
        output_header.addStretch()
        output_header.addWidget(self.btn_clear_output)
        output_layout.addLayout(output_header)

        self.output_box = TextEdit()
        self.output_box.setReadOnly(True)
        mono_font = QFont("Consolas")
        mono_font.setStyleHint(QFont.Monospace)
        mono_font.setPointSize(9)
        self.output_box.setFont(mono_font)
        self.output_box.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Expanding
        )
        self.output_box.setStyleSheet("""
            TextEdit {
                background-color: rgba(0, 0, 0, 0.35);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 6px;
                color: #e0e0e0;
            }
        """)
        output_layout.addWidget(self.output_box)

        root_layout.addWidget(output_card, 1)

        footer_layout = QVBoxLayout()
        footer_layout.setSpacing(4)
        self.progress_bar = IndeterminateProgressBar(self)
        self.progress_bar.setVisible(False)
        self.status_label = CaptionLabel("Ready")
        self.status_label.setTextColor("#8a8a8a", "#8a8a8a")
        footer_layout.addWidget(self.progress_bar)
        footer_layout.addWidget(self.status_label)
        root_layout.addLayout(footer_layout)

        self.setLayout(QVBoxLayout(self))
        self.layout().setContentsMargins(0, 48, 0, 0)
        self.layout().addWidget(root_widget)
        self.titleBar.raise_()

    def set_busy(self, busy, status=None):
        self.progress_bar.setVisible(busy)
        if busy:
            self.progress_bar.start()
        else:
            self.progress_bar.stop()

        self.btn_refresh_all.setEnabled(not busy)
        self.btn_reload_tasks.setEnabled(not busy)
        self.btn_install_git.setEnabled(
            not busy and self.git_badge.text() == "Not installed"
        )
        self.btn_install_helpers.setEnabled(not busy)
        self.btn_clone_dotfiles.setEnabled(not busy)
        self.btn_run_task.setEnabled(
            not busy and self.task_selector.count() > 0
        )

        if status:
            self.status_label.setText(status)

    def add_output(self, message):
        if not message:
            return
        self.output_box.append(message)
        scroll_bar = self.output_box.verticalScrollBar()
        if scroll_bar:
            scroll_bar.setValue(scroll_bar.maximum())

    def clear_output(self):
        self.output_box.clear()

    def get_powershell_executable(self):
        if self._cached_ps_exe:
            return self._cached_ps_exe

        path_env = os.environ.get("PATH", "")
        search_paths = path_env.split(os.pathsep)

        for directory in search_paths:
            candidate = os.path.join(directory, "pwsh.exe")
            if os.path.isfile(candidate):
                self._cached_ps_exe = candidate
                return candidate

        system_dir = os.environ.get("SystemRoot", r"C:\Windows")
        win_ps = os.path.join(
            system_dir, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"
        )
        if os.path.isfile(win_ps):
            self._cached_ps_exe = win_ps
            return win_ps

        self._cached_ps_exe = "powershell.exe"
        return self._cached_ps_exe

    def get_cli_helpers_path(self):
        user_profile = str(Path.home())
        base_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            os.path.join(user_profile, "src", "cli-helpers"),
            os.path.join(user_profile, "src", "dotfiles", "cli-helpers"),
            os.path.abspath(os.path.join(base_dir, "..")),
            os.path.abspath(os.path.join(base_dir, "..", "..")),
        ]
        for p in candidates:
            if os.path.isdir(p) and os.path.isfile(os.path.join(p, "init.ps1")):
                return p
        return None

    def get_dotfiles_path(self):
        user_profile = str(Path.home())
        base_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            os.path.join(user_profile, "src", "dotfiles"),
            os.path.abspath(os.path.join(base_dir, "..", "..")),
            os.path.abspath(os.path.join(base_dir, "..", "..", "..")),
        ]
        for p in candidates:
            if os.path.isdir(p) and os.path.isfile(os.path.join(p, "init.ps1")):
                return p
        return None

    def update_setup_status(self):
        helpers_path = self.get_cli_helpers_path()
        dotfiles_path = self.get_dotfiles_path()

        self._status_worker = StatusCheckWorker(helpers_path, dotfiles_path)
        self._status_worker.status_ready.connect(self._on_status_ready)
        self._status_worker.start()

    def _on_status_ready(self, info):
        if info["git_installed"]:
            self.git_badge.setText("Installed")
            if info.get("git_version"):
                self.git_badge.setToolTip(info["git_version"])
            self.git_badge.setLevel(InfoLevel.SUCCESS)
            self.btn_install_git.setEnabled(False)
        else:
            self.git_badge.setText("Not installed")
            self.git_badge.setLevel(InfoLevel.WARNING)
            self.btn_install_git.setEnabled(True)

        if info["helpers_installed"]:
            self.helpers_badge.setText("Installed")
            self.helpers_badge.setLevel(InfoLevel.SUCCESS)
            self.btn_install_helpers.setText("Update helpers")
        else:
            self.helpers_badge.setText("Not installed")
            self.helpers_badge.setLevel(InfoLevel.WARNING)
            self.btn_install_helpers.setText("Install helpers")

        if info["dotfiles_installed"]:
            self.dotfiles_badge.setText("Installed")
            self.dotfiles_badge.setLevel(InfoLevel.SUCCESS)
            self.btn_clone_dotfiles.setText("Update dotfiles")
            if info["dotfiles_user"] and not self.tb_username.text().strip():
                self.tb_username.setText(info["dotfiles_user"])
        else:
            self.dotfiles_badge.setText("Not installed")
            self.dotfiles_badge.setLevel(InfoLevel.WARNING)
            self.btn_clone_dotfiles.setText("Download dotfiles")

    def initialize_tasks(self):
        self.set_busy(True, "Loading profile tasks...")
        helpers_path = self.get_cli_helpers_path()
        dotfiles_path = self.get_dotfiles_path()

        script_parts = []
        if helpers_path:
            init_helpers = os.path.join(helpers_path, "init.ps1")
            if os.path.isfile(init_helpers):
                script_parts.append(
                    f"if (Test-Path '{init_helpers}') {{ . '{init_helpers}' }};"
                )

        if dotfiles_path:
            init_dotfiles = os.path.join(dotfiles_path, "init.ps1")
            if os.path.isfile(init_dotfiles):
                script_parts.append(
                    f"if (Test-Path '{init_dotfiles}') {{ . '{init_dotfiles}' }};"
                )

        script_parts.append(
            "Get-Command -CommandType Function, Alias | Where-Object { $_.Name -match '^(win_|ubu_|my_)' } | Select-Object -ExpandProperty Name | Sort-Object -Unique"
        )
        full_script = " ".join(script_parts)

        ps_exe = self.get_powershell_executable()
        self._task_worker = TaskLoaderWorker(ps_exe, full_script)
        self._task_worker.tasks_loaded.connect(self._on_tasks_loaded)
        self._task_worker.output_message.connect(self.add_output)
        self._task_worker.start()

    def _on_tasks_loaded(self, tasks):
        self.task_selector.clear()
        if tasks:
            self.task_selector.addItems(tasks)
            self.task_selector.setCurrentIndex(0)
            self.btn_run_task.setEnabled(True)
        else:
            self.btn_run_task.setEnabled(False)

        self.add_output(f"Loaded {len(tasks)} profile tasks.")
        self.set_busy(False, "Ready")

    def refresh_all(self):
        self.set_busy(True, "Refreshing status and tasks...")
        self.update_setup_status()
        self.initialize_tasks()

    def run_worker_command(self, cmd, args, cwd=None, status_msg=None, on_success_msg=None):
        self.set_busy(True, status_msg or "Executing command...")
        self._active_worker = CommandWorker(cmd, args, cwd)
        self._active_worker.output_line.connect(self.add_output)

        def on_finished(exit_code):
            if exit_code == 0:
                self.add_output(on_success_msg or "Command completed.")
                self.set_busy(False, "Command finished.")
            else:
                self.add_output(f"Command failed with exit code {exit_code}")
                self.set_busy(False, "Command failed.")
            self.refresh_all()

        self._active_worker.finished.connect(on_finished)
        self._active_worker.start()

    def install_git(self):
        self.add_output("Starting Git installation via winget...")
        args = [
            "install",
            "--id",
            "Git.Git",
            "-e",
            "--source",
            "winget",
            "--accept-package-agreements",
            "--accept-source-agreements",
        ]
        self.run_worker_command(
            "winget",
            args,
            status_msg="Installing Git...",
            on_success_msg="Git installation completed.",
        )

    def install_or_update_helpers(self):
        helpers_path = self.get_cli_helpers_path()
        if helpers_path:
            self.add_output(f"Updating cli-helpers at {helpers_path}...")
            self.run_worker_command(
                "git",
                ["-C", helpers_path, "pull", "origin", "main"],
                status_msg="Updating cli-helpers...",
                on_success_msg="cli-helpers updated.",
            )
        else:
            user_profile = str(Path.home())
            target_dir = os.path.join(user_profile, "src", "cli-helpers")
            parent_dir = os.path.join(user_profile, "src")
            os.makedirs(parent_dir, exist_ok=True)
            self.add_output(f"Cloning cli-helpers into {target_dir}...")
            self.run_worker_command(
                "git",
                [
                    "clone",
                    "https://github.com/alanlivio/cli-helpers.git",
                    target_dir,
                ],
                status_msg="Installing cli-helpers...",
                on_success_msg="cli-helpers installed.",
            )

    def clone_or_update_dotfiles(self):
        dotfiles_path = self.get_dotfiles_path()
        username = self.tb_username.text().strip()

        if not dotfiles_path and not username:
            self.add_output(
                "Validation error: Please enter a GitHub username to download dotfiles."
            )
            self.status_label.setText("Username required.")
            return

        if dotfiles_path:
            self.add_output(f"Updating dotfiles at {dotfiles_path}...")
            self.run_worker_command(
                "git",
                ["-C", dotfiles_path, "pull", "origin", "main"],
                status_msg="Updating dotfiles...",
                on_success_msg="dotfiles updated.",
            )
        else:
            user_profile = str(Path.home())
            target_dir = os.path.join(user_profile, "src", "dotfiles")
            parent_dir = os.path.join(user_profile, "src")
            os.makedirs(parent_dir, exist_ok=True)
            self.add_output(f"Downloading {username}/dotfiles to {target_dir}...")
            self.run_worker_command(
                "git",
                [
                    "clone",
                    f"https://github.com/{username}/dotfiles.git",
                    target_dir,
                ],
                status_msg=f"Downloading {username}/dotfiles...",
                on_success_msg=f"dotfiles installed at {target_dir}",
            )

    def run_task(self):
        selected_task = self.task_selector.currentText().strip()
        if not selected_task:
            return

        self.add_output(f">>> Running {selected_task}...")
        helpers_path = self.get_cli_helpers_path()
        dotfiles_path = self.get_dotfiles_path()

        script_parts = []
        if helpers_path:
            init_helpers = os.path.join(helpers_path, "init.ps1")
            if os.path.isfile(init_helpers):
                script_parts.append(
                    f"if (Test-Path '{init_helpers}') {{ . '{init_helpers}' }};"
                )

        if dotfiles_path:
            init_dotfiles = os.path.join(dotfiles_path, "init.ps1")
            if os.path.isfile(init_dotfiles):
                script_parts.append(
                    f"if (Test-Path '{init_dotfiles}') {{ . '{init_dotfiles}' }};"
                )

        script_parts.append(f"& {selected_task}")
        full_script = " ".join(script_parts)
        escaped_script = full_script.replace('"', '`"')

        ps_exe = self.get_powershell_executable()
        args = [
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            escaped_script,
        ]

        self.set_busy(True, f"Executing: {selected_task}...")
        self._active_worker = CommandWorker(ps_exe, args)
        self._active_worker.output_line.connect(self.add_output)

        def on_task_finished(exit_code):
            if exit_code == 0:
                self.add_output(f">>> Completed {selected_task}")
                self.set_busy(False, f"Finished: {selected_task}")
            else:
                self.add_output(
                    f">>> Task finished with exit code {exit_code}"
                )
                self.set_busy(False, f"Failed: {selected_task}")

        self._active_worker.finished.connect(on_task_finished)
        self._active_worker.start()


    def closeEvent(self, event):
        if self._active_worker and self._active_worker.isRunning():
            self._active_worker.terminate()
            self._active_worker.wait(500)
        super().closeEvent(event)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.titleBar.raise_()


if __name__ == "__main__":
    signal.signal(signal.SIGINT, lambda *_: QApplication.quit())
    app = QApplication(sys.argv)

    timer = QTimer()
    timer.timeout.connect(lambda: None)
    timer.start(200)

    setTheme(Theme.DARK)
    window = MainWindow()
    window.show()

    try:
        sys.exit(app.exec_())
    except KeyboardInterrupt:
        sys.exit(0)
