import io
import json
import os
import sys
import re
import signal
import subprocess
from enum import Enum
from pathlib import Path

os.environ.setdefault(
    "QT_LOGGING_RULES",
    "qt.qpa.fonts.warning=false;qt.text.font.warning=false;fluentqt.typography.warning=false;*.debug=false",
)

from PySide6.QtCore import (
    Qt,
    QTimer,
    qInstallMessageHandler,
    QSettings,
)
from PySide6.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QSizePolicy,
    QLabel,
    QPlainTextEdit,
)
from PySide6.QtGui import QFont, QPalette, QColor, QIcon

import fluentqt


def get_resource_dir() -> Path:
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        return Path(sys._MEIPASS) / "cli_helpers" / "resources"
    return Path(__file__).resolve().parent / "resources"


def get_app_icon() -> QIcon:
    res_dir = get_resource_dir()
    for name in ("icon.ico", "icon.png", "icon.svg"):
        p = res_dir / name
        if p.is_file():
            icon = QIcon(str(p))
            if not icon.isNull():
                return icon
    return QIcon()


class Theme:
    DARK = fluentqt.Theme.Dark
    LIGHT = fluentqt.Theme.Light


def setTheme(theme):
    if theme == Theme.DARK or theme == "dark":
        fluentqt.setTheme(fluentqt.Theme.Dark)
    elif theme == Theme.LIGHT or theme == "light":
        fluentqt.setTheme(fluentqt.Theme.Light)
    else:
        fluentqt.setTheme(theme)


class FluentIcon:
    SYNC = "\ue72c"
    DELETE = "\ue74d"
    PLAY = "\ue768"


class PushButton(fluentqt.Button):
    def __init__(self, text="", parent=None, icon=None):
        super().__init__(text, parent)
        if icon is not None:
            self.setIconGlyph(icon, 16)


class PrimaryPushButton(fluentqt.Button):
    def __init__(self, text="", parent=None, icon=None):
        super().__init__(text, parent, fluentStyle=fluentqt.Button.ButtonStyle.Accent)
        if icon is not None:
            self.setIconGlyph(icon, 16)


class CardWidget(fluentqt.Card):
    pass


class SubtitleLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setStyleSheet("font-size: 16px; font-weight: 600; color: #ffffff;")


class BodyLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setStyleSheet("font-size: 13px; color: #e0e0e0;")


class CaptionLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setStyleSheet("font-size: 12px; color: #8a8a8a;")

    def setTextColor(self, *args):
        pass


class ComboBox(fluentqt.ComboBox):
    def addItem(self, *args, **kwargs):
        was_empty = self.count() == 0
        super().addItem(*args, **kwargs)
        if was_empty and self.count() > 0 and self.currentIndex() == -1:
            self.setCurrentIndex(0)

    def addItems(self, *args, **kwargs):
        was_empty = self.count() == 0
        super().addItems(*args, **kwargs)
        if was_empty and self.count() > 0 and self.currentIndex() == -1:
            self.setCurrentIndex(0)


class LineEdit(fluentqt.LineEdit):
    pass


class TextEdit(QPlainTextEdit):
    def append(self, message):
        self.appendPlainText(message)
        sb = self.verticalScrollBar()
        if sb:
            sb.setValue(sb.maximum())


class IndeterminateProgressBar(fluentqt.ProgressBar):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setIsIndeterminate(True)
        self.setFixedHeight(4)

    def start(self):
        self.setIsIndeterminate(True)

    def stop(self):
        pass


class InfoLevel(Enum):
    INFO = "info"
    SUCCESS = "success"
    WARNING = "warning"
    ERROR = "error"


class InfoBadge(QLabel):
    def __init__(self, text="Checking...", parent=None):
        super().__init__(text, parent)
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setLevel(InfoLevel.INFO)

    def text(self):
        return super().text()

    def setText(self, text):
        super().setText(text)

    def setLevel(self, level):
        self.level = level
        if level == InfoLevel.SUCCESS:
            bg, fg = "#107c41", "#ffffff"
        elif level == InfoLevel.WARNING:
            bg, fg = "#ca5010", "#ffffff"
        elif level == InfoLevel.ERROR:
            bg, fg = "#a80000", "#ffffff"
        else:
            bg, fg = "#3b3a39", "#d0d0d0"
        self.setStyleSheet(f"""
            QLabel {{
                background-color: {bg};
                color: {fg};
                border-radius: 4px;
                padding: 2px 8px;
                font-size: 11px;
                font-weight: 500;
            }}
        """)

    @classmethod
    def info(cls, text=""):
        badge = cls(text)
        badge.setLevel(InfoLevel.INFO)
        return badge


class TitleLabel:
    def __init__(self, label_widget, wrapper):
        self._lbl = label_widget
        self._wrapper = wrapper

    def text(self):
        if self._lbl and hasattr(self._lbl, "text"):
            return self._lbl.text()
        return self._wrapper._title


class TitleBarWrapper:
    def __init__(self, tb, title="CLI Helpers", label_widget=None):
        self._tb = tb
        self._title = title
        self._label = label_widget
        self.titleLabel = TitleLabel(label_widget, self)

    def setTitle(self, title):
        self._title = title
        if self._label and hasattr(self._label, "setText"):
            self._label.setText(title)
        if self._tb and hasattr(self._tb, "setWindowTitle"):
            self._tb.setWindowTitle(title)

    def raise_(self):
        if self._tb and hasattr(self._tb, "raise_"):
            self._tb.raise_()


def _handle_exception(exctype, value, tb):
    if issubclass(exctype, KeyboardInterrupt):
        QApplication.quit()
        sys.exit(0)
    sys.__excepthook__(exctype, value, tb)


sys.excepthook = _handle_exception


def _qt_message_handler(mode, context, message):
    if (
        "Cannot find font directory" in message
        or "Qt no longer ships fonts" in message
        or "initializeResources requires a QGuiApplication instance" in message
    ):
        return


qInstallMessageHandler(_qt_message_handler)


from .workers import (
    HelperWorker,
    HelperDiscoveryWorker,
    StatusCheckWorker,
    build_helper_command,
)


class MainWindow(fluentqt.Window):
    def __init__(self, refresh=True):
        if QApplication.instance():
            fluentqt.initialize_resources()
        super().__init__()
        self.resize(720, 800)

        self._active_worker = None
        self._status_worker = None
        self._helper_worker = None
        self._task_worker = None
        self._cached_ps_exe = None

        setTheme(Theme.DARK)
        self.setWindowTitle("CLI Helpers")

        self.native_title_bar = self.titleBar()
        self.title_bar_container = None
        self.title_label_widget = None
        self.title_icon_widget = None

        icon = get_app_icon()
        if not icon.isNull():
            self.setWindowIcon(icon)
            if self.native_title_bar and hasattr(self.native_title_bar, "setWindowIcon"):
                self.native_title_bar.setWindowIcon(icon)

        if self.native_title_bar:
            self.native_title_bar.setWindowTitle("CLI Helpers")
            self.title_bar_container = QWidget(self.native_title_bar)
            self.title_bar_container.setAttribute(Qt.WA_TransparentForMouseEvents)
            self.title_bar_container.move(14, 0)
            self.title_bar_container.setFixedHeight(36)

            tb_layout = QHBoxLayout(self.title_bar_container)
            tb_layout.setContentsMargins(0, 0, 0, 0)
            tb_layout.setSpacing(8)
            tb_layout.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)

            if not icon.isNull():
                self.title_icon_widget = QLabel(self.title_bar_container)
                self.title_icon_widget.setAttribute(Qt.WA_TransparentForMouseEvents)
                self.title_icon_widget.setPixmap(icon.pixmap(16, 16))
                tb_layout.addWidget(self.title_icon_widget)

            self.title_label_widget = QLabel("CLI Helpers", self.title_bar_container)
            self.title_label_widget.setAttribute(Qt.WA_TransparentForMouseEvents)
            self.title_label_widget.setStyleSheet("font-size: 12px; font-weight: 500; color: #ffffff;")
            tb_layout.addWidget(self.title_label_widget)

        self.title_bar = TitleBarWrapper(self.native_title_bar, "CLI Helpers", self.title_label_widget)

        if sys.platform == "win32":
            try:
                self.setBackdropEffect(fluentqt.BackdropEffect.Mica)
            except Exception:
                pass

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
        self.btn_install_helpers = PushButton("Clone helpers")
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
        self.btn_clone_dotfiles = PushButton("Clone dotfiles")
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
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
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
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
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
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed
        )
        self.btn_run_task = PushButton("Run Task", self, FluentIcon.PLAY)
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
        mono_font.setStyleHint(QFont.StyleHint.Monospace)
        mono_font.setPointSize(9)
        self.output_box.setFont(mono_font)
        self.output_box.setSizePolicy(
            QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding
        )
        self.output_box.setStyleSheet("""
            QPlainTextEdit {
                background-color: rgba(0, 0, 0, 0.35);
                border: 1px solid rgba(255, 255, 255, 0.08);
                border-radius: 6px;
                color: #e0e0e0;
                padding: 8px;
            }
            QScrollBar:vertical {
                background: transparent;
                width: 8px;
                margin: 2px 0 2px 0;
            }
            QScrollBar::handle:vertical {
                background: rgba(255, 255, 255, 0.2);
                min-height: 20px;
                border-radius: 4px;
            }
            QScrollBar::handle:vertical:hover {
                background: rgba(255, 255, 255, 0.35);
            }
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
                height: 0px;
            }
        """)
        output_layout.addWidget(self.output_box, 1)

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

        self.setContentWidget(root_widget)
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
            self.btn_install_helpers.setText("Clone helpers")
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
            self.btn_clone_dotfiles.setText("Clone dotfiles")

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
                status_msg="Cloning cli-helpers...",
                on_success_msg="cli-helpers cloned.",
            )

    def clone_or_update_dotfiles(self):
        dotfiles_path = self.get_dotfiles_path()
        username = self.tb_username.text().strip()

        if not dotfiles_path and not username:
            self.add_output(
                "Validation error: Please enter a GitHub username to clone dotfiles."
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
            self.add_output(f"Cloning {username}/dotfiles into {target_dir}...")
            self.run_worker_command(
                "git",
                [
                    "clone",
                    f"https://github.com/{username}/dotfiles.git",
                    target_dir,
                ],
                status_msg=f"Cloning {username}/dotfiles...",
                on_success_msg=f"dotfiles cloned at {target_dir}",
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
        if hasattr(self, "title_bar") and hasattr(self.title_bar, "raise_"):
            self.title_bar.raise_()


def main():
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("alanlivio.clihelpers.gui")
        except Exception:
            pass

    fluentqt.prepare_high_dpi_application()
    signal.signal(signal.SIGINT, lambda *_: QApplication.quit())
    app = QApplication(sys.argv)
    app.setApplicationName("CLI Helpers")
    app.setApplicationDisplayName("CLI Helpers")
    icon = get_app_icon()
    if not icon.isNull():
        app.setWindowIcon(icon)
    fluentqt.initialize_resources()

    timer = QTimer()
    timer.timeout.connect(lambda: None)
    timer.start(200)

    setTheme(Theme.DARK)
    window = MainWindow()
    window.show()

    try:
        sys.exit(app.exec())
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()
