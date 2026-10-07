import io
import json
import os
import shutil
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
    QTimer,
    qInstallMessageHandler,
    QSettings,
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



from .workers import (
    HelperWorker,
    HelperDiscoveryWorker,
    StatusCheckWorker,
    build_helper_command,
)


class MainWindow(FramelessWindow):
    def __init__(self, refresh=True):
        super().__init__()
        self.resize(720, 800)

        self._active_worker = None
        self._status_worker = None
        self._helper_worker = None
        self._task_worker = None
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
        if refresh:
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
        self.git_label = BodyLabel("Git:")
        self.git_label.setFixedWidth(135)
        self.git_badge = InfoBadge.info("Checking...")
        self.btn_install_git = PushButton("Install Git")
        self.btn_install_git.setFixedWidth(125)
        self.btn_install_git.clicked.connect(self.install_git)
        git_row.addWidget(self.git_label)
        git_row.addWidget(self.git_badge)
        git_row.addStretch()
        git_row.addWidget(self.btn_install_git)
        setup_layout.addLayout(git_row)

        helpers_row = QHBoxLayout()
        self.helpers_label = BodyLabel("~/src/cli-helpers:")
        self.helpers_label.setFixedWidth(135)
        self.helpers_label.setToolTip("Local path: ~/src/cli-helpers")
        self.helpers_badge = InfoBadge.info("Checking...")
        self.helpers_github_prefix = CaptionLabel("github.com/")
        self.tb_helpers_user = LineEdit()
        self.tb_helpers_user.setPlaceholderText("USER")
        self.tb_helpers_user.setFixedWidth(100)
        self.tb_helpers_user.setToolTip("cli-helpers will be downloaded from https://github.com/<USER>/cli-helpers")
        self.helpers_repo_suffix = CaptionLabel("/cli-helpers")
        self.btn_install_helpers = PushButton("Install helpers")
        self.btn_install_helpers.setFixedWidth(125)
        self.btn_install_helpers.clicked.connect(self.install_or_update_helpers)
        helpers_row.addWidget(self.helpers_label)
        helpers_row.addWidget(self.helpers_badge)
        helpers_row.addStretch()
        helpers_row.addWidget(self.helpers_github_prefix)
        helpers_row.addWidget(self.tb_helpers_user)
        helpers_row.addWidget(self.helpers_repo_suffix)
        helpers_row.addWidget(self.btn_install_helpers)
        setup_layout.addLayout(helpers_row)

        dotfiles_row = QHBoxLayout()
        self.dotfiles_label = BodyLabel("~/src/dotfiles:")
        self.dotfiles_label.setFixedWidth(135)
        self.dotfiles_label.setToolTip("Local path: ~/src/dotfiles")
        self.dotfiles_badge = InfoBadge.info("Checking...")
        self.github_prefix_label = CaptionLabel("github.com/")
        self.tb_username = LineEdit()
        self.tb_username.setPlaceholderText("USER")
        self.tb_username.setFixedWidth(100)
        self.tb_username.setToolTip("Dotfiles will be downloaded from https://github.com/<USER>/dotfiles")
        self.dotfiles_repo_suffix = CaptionLabel("/dotfiles")
        self.btn_clone_dotfiles = PushButton("Download dotfiles")
        self.btn_clone_dotfiles.setFixedWidth(125)
        self.btn_clone_dotfiles.clicked.connect(self.clone_or_update_dotfiles)
        dotfiles_row.addWidget(self.dotfiles_label)
        dotfiles_row.addWidget(self.dotfiles_badge)
        dotfiles_row.addStretch()
        dotfiles_row.addWidget(self.github_prefix_label)
        dotfiles_row.addWidget(self.tb_username)
        dotfiles_row.addWidget(self.dotfiles_repo_suffix)
        dotfiles_row.addWidget(self.btn_clone_dotfiles)
        setup_layout.addLayout(dotfiles_row)

        root_layout.addWidget(setup_card)

        tasks_card = CardWidget(self)
        tasks_layout = QVBoxLayout(tasks_card)
        tasks_layout.setContentsMargins(16, 14, 16, 14)
        tasks_layout.setSpacing(10)

        tasks_header = QHBoxLayout()
        self.tasks_title = SubtitleLabel("Run")
        self.btn_clear_recent = PushButton("Clear Recent", self, FluentIcon.DELETE)
        self.btn_clear_recent.clicked.connect(self.clear_recent_tasks)
        self.btn_reload_tasks = PushButton("Reload Tasks", self, FluentIcon.SYNC)
        self.btn_reload_tasks.clicked.connect(self.initialize_tasks)
        tasks_header.addWidget(self.tasks_title)
        tasks_header.addStretch()
        tasks_header.addWidget(self.btn_clear_recent)
        tasks_header.addWidget(self.btn_reload_tasks)
        tasks_layout.addLayout(tasks_header)

        my_row = QHBoxLayout()
        my_label = BodyLabel("My helpers:")
        my_label.setFixedWidth(100)
        self.my_task_selector = ComboBox()
        self.my_task_selector.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Fixed
        )
        self.my_task_selector.setPlaceholderText("No my_ helpers found")
        self.btn_run_my_task = PushButton("Run", self, FluentIcon.PLAY)
        self.btn_run_my_task.setFixedWidth(135)
        self.btn_run_my_task.clicked.connect(self.run_my_task)
        my_row.addWidget(my_label)
        my_row.addWidget(self.my_task_selector)
        my_row.addWidget(self.btn_run_my_task)
        tasks_layout.addLayout(my_row)

        recent_row = QHBoxLayout()
        recent_label = BodyLabel("Recent:")
        recent_label.setFixedWidth(100)
        self.recent_task_selector = ComboBox()
        self.recent_task_selector.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Fixed
        )
        self.recent_task_selector.setPlaceholderText("No recent tasks")
        self.btn_run_recent_task = PushButton("Run", self, FluentIcon.PLAY)
        self.btn_run_recent_task.setFixedWidth(135)
        self.btn_run_recent_task.clicked.connect(self.run_recent_task)
        recent_row.addWidget(recent_label)
        recent_row.addWidget(self.recent_task_selector)
        recent_row.addWidget(self.btn_run_recent_task)
        tasks_layout.addLayout(recent_row)

        task_selector_row = QHBoxLayout()
        task_label = BodyLabel("All tasks:")
        task_label.setFixedWidth(100)
        self.task_selector = ComboBox()
        self.task_selector.setSizePolicy(
            QSizePolicy.Expanding, QSizePolicy.Fixed
        )
        self.btn_run_task = PrimaryPushButton("Run Task", self, FluentIcon.PLAY)
        self.btn_run_task.setFixedWidth(135)
        self.btn_run_task.clicked.connect(self.run_task)
        task_selector_row.addWidget(task_label)
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
        self.status_label.setTextColor(QColor("#8a8a8a"), QColor("#8a8a8a"))
        footer_layout.addWidget(self.progress_bar)
        footer_layout.addWidget(self.status_label)
        root_layout.addLayout(footer_layout)

        main_layout = QVBoxLayout(self)
        self.setLayout(main_layout)
        main_layout.setContentsMargins(0, 48, 0, 0)
        main_layout.addWidget(root_widget)
        self.titleBar.raise_()
        self._update_recent_selector()

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
        self.btn_run_my_task.setEnabled(
            not busy and self.my_task_selector.count() > 0
        )
        self.btn_run_recent_task.setEnabled(
            not busy and self.recent_task_selector.count() > 0
        )
        self.btn_clear_recent.setEnabled(
            not busy and self.recent_task_selector.count() > 0
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

    def get_shell_executable(self):
        if sys.platform != "win32":
            return shutil.which("bash") or "/bin/bash" or "bash"
        return self.get_powershell_executable()

    def get_cli_helpers_path(self):
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

    def get_dotfiles_path(self):
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
            if info.get("helpers_updated", True):
                self.helpers_badge.setText("Installed")
                self.helpers_badge.setLevel(InfoLevel.SUCCESS)
            else:
                self.helpers_badge.setText("Not updated")
                self.helpers_badge.setLevel(InfoLevel.WARNING)
            self.btn_install_helpers.setText("Update helpers")
            if info.get("helpers_user") and not self.tb_helpers_user.text().strip():
                self.tb_helpers_user.setText(info["helpers_user"])
        else:
            self.helpers_badge.setText("Not installed")
            self.helpers_badge.setLevel(InfoLevel.ERROR)
            self.btn_install_helpers.setText("Install helpers")
            if not self.tb_helpers_user.text().strip():
                self.tb_helpers_user.setText(info.get("helpers_user", "alanlivio"))

        if info["dotfiles_installed"]:
            if info.get("dotfiles_updated", True):
                self.dotfiles_badge.setText("Installed")
                self.dotfiles_badge.setLevel(InfoLevel.SUCCESS)
            else:
                self.dotfiles_badge.setText("Not updated")
                self.dotfiles_badge.setLevel(InfoLevel.WARNING)
            self.btn_clone_dotfiles.setText("Update dotfiles")
            if info["dotfiles_user"] and not self.tb_username.text().strip():
                self.tb_username.setText(info["dotfiles_user"])
        else:
            self.dotfiles_badge.setText("Not installed")
            self.dotfiles_badge.setLevel(InfoLevel.ERROR)
            self.btn_clone_dotfiles.setText("Download dotfiles")

        if info.get("helpers_path"):
            self.helpers_label.setToolTip(f"Local path: {info['helpers_path']}")
            self.helpers_badge.setToolTip(f"Local path: {info['helpers_path']}")

        if info.get("dotfiles_path"):
            self.dotfiles_label.setToolTip(f"Local path: {info['dotfiles_path']}")
            self.dotfiles_badge.setToolTip(f"Local path: {info['dotfiles_path']}")

    def initialize_tasks(self):
        self.set_busy(True, "Loading profile tasks...")
        helpers_path = self.get_cli_helpers_path()
        dotfiles_path = self.get_dotfiles_path()
        shell_exe = self.get_shell_executable()
        self._helper_worker = HelperDiscoveryWorker(
            shell_exe=shell_exe,
            helpers_path=helpers_path,
            dotfiles_path=dotfiles_path,
        )
        self._task_worker = self._helper_worker
        self._helper_worker.helpers_loaded.connect(self._on_tasks_loaded)
        self._helper_worker.output_message.connect(self.add_output)
        self._helper_worker.start()

    def _on_tasks_loaded(self, tasks):
        self.task_selector.clear()
        if tasks:
            self.task_selector.addItems(tasks)
            self.task_selector.setCurrentIndex(0)
            self.btn_run_task.setEnabled(True)
        else:
            self.btn_run_task.setEnabled(False)

        my_tasks = [t for t in tasks if t.startswith("my_")]
        self.my_task_selector.clear()
        if my_tasks:
            self.my_task_selector.addItems(my_tasks)
            self.my_task_selector.setCurrentIndex(0)
            self.btn_run_my_task.setEnabled(True)
        else:
            self.btn_run_my_task.setEnabled(False)

        self.add_output(f"Loaded {len(tasks)} profile tasks ({len(my_tasks)} my_ helpers).")
        self.set_busy(False, "Ready")

    def refresh_all(self):
        self.set_busy(True, "Refreshing status and tasks...")
        self.update_setup_status()
        self.initialize_tasks()

    def run_worker_command(self, cmd, args, cwd=None, status_msg=None, on_success_msg=None):
        self.set_busy(True, status_msg or "Executing command...")
        self._active_worker = HelperWorker(cmd, args, cwd)
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
        username = (
            self.tb_helpers_user.text().strip()
            if hasattr(self, "tb_helpers_user")
            else ""
        )
        if not username:
            username = "alanlivio"
        username = re.sub(r"^(https?://)?github\.com/", "", username).strip("/")
        username = re.sub(r"/cli-helpers(\.git)?$", "", username)

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
            self.add_output(f"Cloning {username}/cli-helpers into {target_dir}...")
            self.run_worker_command(
                "git",
                [
                    "clone",
                    f"https://github.com/{username}/cli-helpers.git",
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
            username = re.sub(r"^(https?://)?github\.com/", "", username).strip("/")
            username = re.sub(r"/dotfiles(\.git)?$", "", username)
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

    def _load_recent_tasks(self):
        try:
            settings = QSettings("cli-helpers", "gui")
            val = settings.value("recent_tasks", "[]")
            if isinstance(val, str):
                tasks = json.loads(val)
            elif isinstance(val, list):
                tasks = val
            else:
                tasks = []
            return [t for t in tasks if isinstance(t, str) and t.strip()]
        except Exception:
            return []

    def _save_recent_tasks(self, tasks):
        try:
            settings = QSettings("cli-helpers", "gui")
            settings.setValue("recent_tasks", json.dumps(tasks))
        except Exception:
            pass

    def add_recent_task(self, task_name):
        if not task_name:
            return
        tasks = self._load_recent_tasks()
        if task_name in tasks:
            tasks.remove(task_name)
        tasks.insert(0, task_name)
        tasks = tasks[:15]
        self._save_recent_tasks(tasks)
        self._update_recent_selector(tasks)

    def clear_recent_tasks(self):
        self._save_recent_tasks([])
        self._update_recent_selector([])

    def _update_recent_selector(self, tasks=None):
        if tasks is None:
            tasks = self._load_recent_tasks()
        self.recent_task_selector.clear()
        if tasks:
            self.recent_task_selector.addItems(tasks)
            self.recent_task_selector.setCurrentIndex(0)
            is_busy = bool(
                hasattr(self, "progress_bar") and self.progress_bar.isVisible()
            )
            self.btn_run_recent_task.setEnabled(not is_busy)
            self.btn_clear_recent.setEnabled(not is_busy)
        else:
            self.btn_run_recent_task.setEnabled(False)
            self.btn_clear_recent.setEnabled(False)

    def run_task(self):
        selected_task = self.task_selector.currentText().strip()
        self.execute_task(selected_task)

    def run_my_task(self):
        selected_task = self.my_task_selector.currentText().strip()
        self.execute_task(selected_task)

    def run_recent_task(self):
        selected_task = self.recent_task_selector.currentText().strip()
        self.execute_task(selected_task)

    def execute_task(self, selected_task):
        if not selected_task:
            return

        self.add_recent_task(selected_task)

        self.add_output(f">>> Running {selected_task}...")
        helpers_path = self.get_cli_helpers_path()
        dotfiles_path = self.get_dotfiles_path()
        shell_exe = self.get_shell_executable()

        cmd, args = build_helper_command(
            selected_task,
            shell_exe=shell_exe,
            helpers_path=helpers_path,
            dotfiles_path=dotfiles_path,
        )

        self.set_busy(True, f"Executing: {selected_task}...")
        self._active_worker = HelperWorker(cmd, args)
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


    def closeEvent(self, a0):
        for worker in [
            self._active_worker,
            self._status_worker,
            self._helper_worker,
            self._task_worker,
        ]:
            if worker and worker.isRunning():
                worker.wait(100)
        super().closeEvent(a0)

    def resizeEvent(self, e):
        super().resizeEvent(e)
        self.titleBar.raise_()


def main():
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


if __name__ == "__main__":
    main()
