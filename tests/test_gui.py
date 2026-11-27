import os
import sys
import unittest
from unittest.mock import patch
from pathlib import Path

os.environ["QT_QPA_PLATFORM"] = "offscreen"

from PySide6.QtWidgets import QApplication

root_dir = Path(__file__).resolve().parent.parent
if str(root_dir) not in sys.path:
    sys.path.insert(0, str(root_dir))

from gui.gui import (
    ALLOWED_MY_HELPERS,
    MainWindow,
    HelperWorker,
    StatusCheckWorker,
    build_helper_command,
    InfoLevel,
    INSTALL_GIT,
    INSTALL_WINGET,
)


class TestGui(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.window = MainWindow(refresh=False)

    def tearDown(self):
        self.window.close()
        for worker in [
            getattr(self.window, "_active_worker", None),
            getattr(self.window, "_status_worker", None),
            getattr(self.window, "_exe_update_worker", None),
        ]:
            if worker and worker.isRunning():
                worker.wait(100)
        self.window.deleteLater()
        self.app.processEvents()
        self.window = None

    def test_window_properties(self):
        self.assertEqual(self.window.windowTitle(), "Shell Profile Helpers")
        self.assertEqual(
            self.window.title_bar.titleLabel.text(), "Shell Profile Helpers"
        )
        if self.window.title_bar_container is not None:
            self.assertGreaterEqual(
                self.window.title_bar_container.width(),
                self.window.title_bar_container.sizeHint().width(),
            )
        self.assertEqual(self.window.setup_title.text(), "Setup")
        self.assertEqual(self.window.tasks_title.text(), "My helpers")
        self.assertEqual(self.window.output_title.text(), "Output log")
        self.assertEqual(self.window.btn_my_declutter.text(), "my_declutter")
        self.assertEqual(self.window.btn_my_dotfiles.text(), "my_dotfiles")
        self.assertEqual(self.window.btn_my_software.text(), "my_software")
        self.assertFalse(hasattr(self.window, "btn_refresh_all"))
        self.assertFalse(hasattr(self.window, "btn_clear_output"))
        self.assertFalse(hasattr(self.window, "task_selector"))
        self.assertGreaterEqual(self.window.minimumWidth(), 700)
        self.assertGreaterEqual(self.window.minimumHeight(), 480)
        self.assertFalse(hasattr(self.window, "my_task_selector"))
        self.assertFalse(hasattr(self.window, "btn_reload_tasks"))
        self.assertEqual(self.window.winget_label.text(), "WinGet:")
        self.assertEqual(self.window.btn_install_winget.text(), "Install WinGet")
        self.assertFalse(hasattr(self.window, "app_badge"))
        self.assertFalse(hasattr(self.window, "winget_badge"))
        self.assertFalse(hasattr(self.window, "git_badge"))
        self.assertFalse(hasattr(self.window, "helpers_badge"))
        self.assertFalse(hasattr(self.window, "dotfiles_badge"))
        self.assertEqual(
            self.window.helpers_label.text(), "~/src/shell-profile-helpers:"
        )
        self.assertEqual(self.window.helpers_github_prefix.text(), "github.com/")
        self.assertEqual(self.window.tb_helpers_user.placeholderText(), "USER")
        self.assertEqual(
            self.window.helpers_repo_suffix.text(), "/shell-profile-helpers"
        )
        self.assertEqual(self.window.dotfiles_label.text(), "~/src/dotfiles:")
        self.assertEqual(self.window.github_prefix_label.text(), "github.com/")
        self.assertEqual(self.window.tb_username.placeholderText(), "USER")
        self.assertEqual(self.window.dotfiles_repo_suffix.text(), "/dotfiles")
        self.assertFalse(self.window.windowIcon().isNull())
        self.window.show()
        self.app.processEvents()
        self.assertEqual(
            self.window.helpers_github_prefix.x(),
            self.window.github_prefix_label.x(),
        )
        self.assertEqual(
            self.window.tb_helpers_user.x(),
            self.window.tb_username.x(),
        )
        self.assertEqual(
            self.window.helpers_repo_suffix.x(),
            self.window.dotfiles_repo_suffix.x(),
        )

    def test_path_discovery(self):
        ps = self.window.get_powershell_executable()
        self.assertTrue(bool(ps))

        helpers_path = self.window.get_helpers_path()
        self.assertIsNotNone(helpers_path)
        assert helpers_path is not None
        self.assertTrue(os.path.isdir(helpers_path))
        self.assertTrue(os.path.isfile(os.path.join(helpers_path, "init.ps1")))

    def test_output_box_operations(self):
        self.window.clear_output()
        self.assertEqual(self.window.output_box.toPlainText().strip(), "")

        self.window.add_output("Test message 1")
        self.assertIn("Test message 1", self.window.output_box.toPlainText())

        self.window.add_output("Test message 2")
        self.assertIn("Test message 2", self.window.output_box.toPlainText())

        self.window.clear_output()
        self.assertEqual(self.window.output_box.toPlainText().strip(), "")

    def test_set_busy_state(self):
        self.window._helpers_ready = True
        self.window.set_busy(True, "Working...")
        self.assertEqual(self.window.status_label.text(), "Working...")
        self.assertFalse(self.window.btn_install_winget.isEnabled())
        self.assertFalse(self.window.btn_install_git.isEnabled())
        self.assertFalse(self.window.btn_my_declutter.isEnabled())
        self.assertFalse(self.window.btn_my_dotfiles.isEnabled())
        self.assertFalse(self.window.btn_my_software.isEnabled())

        self.window.set_busy(False, "Done")
        self.assertEqual(self.window.status_label.text(), "Done")
        self.assertTrue(self.window.btn_my_declutter.isEnabled())
        self.assertTrue(self.window.btn_my_dotfiles.isEnabled())
        self.assertTrue(self.window.btn_my_software.isEnabled())

    def test_status_ready_callback(self):
        mock_info = {
            "winget_installed": True,
            "winget_version": "v1.29.380",
            "git_installed": True,
            "git_version": "v2.55.0",
            "helpers_installed": True,
            "helpers_user": "helperuser",
            "dotfiles_installed": True,
            "dotfiles_user": "testuser",
        }
        self.window._on_status_ready(mock_info)
        self.assertEqual(self.window.btn_install_winget.text(), "v1.29.380")
        self.assertFalse(self.window.btn_install_winget.isEnabled())
        self.assertEqual(self.window.btn_install_git.text(), "v2.55.0")
        self.assertFalse(self.window.btn_install_git.isEnabled())
        self.assertEqual(self.window.btn_install_helpers.text(), "Updated")
        self.assertEqual(self.window.btn_clone_dotfiles.text(), "Updated")
        self.assertEqual(self.window.tb_helpers_user.text(), "helperuser")
        self.assertEqual(self.window.tb_username.text(), "testuser")
        self.assertFalse(self.window.btn_install_helpers.isEnabled())
        self.assertFalse(self.window.btn_clone_dotfiles.isEnabled())

    def test_status_not_updated(self):
        mock_info = {
            "git_installed": True,
            "git_version": "v2.55.0",
            "helpers_installed": True,
            "helpers_updated": False,
            "helpers_user": "helperuser",
            "dotfiles_installed": True,
            "dotfiles_updated": False,
            "dotfiles_user": "testuser",
        }
        self.window._on_status_ready(mock_info)
        self.assertEqual(self.window.btn_install_helpers.text(), "Update")
        self.assertTrue(self.window.btn_install_helpers.isEnabled())
        self.assertEqual(self.window.btn_clone_dotfiles.text(), "Update")
        self.assertTrue(self.window.btn_clone_dotfiles.isEnabled())

    def test_status_not_installed(self):
        mock_info = {
            "winget_installed": False,
            "git_installed": False,
            "helpers_installed": False,
            "dotfiles_installed": False,
        }
        self.window._on_status_ready(mock_info)
        self.assertEqual(self.window.btn_install_winget.text(), "Install WinGet")
        self.assertTrue(self.window.btn_install_winget.isEnabled())
        self.assertEqual(self.window.btn_install_git.text(), "Install Git")
        self.assertTrue(self.window.btn_install_git.isEnabled())
        self.assertEqual(self.window.btn_install_helpers.text(), "Clone")
        self.assertEqual(self.window.btn_clone_dotfiles.text(), "Clone")
        self.assertFalse(self.window.btn_install_helpers.isEnabled())
        self.assertFalse(self.window.btn_clone_dotfiles.isEnabled())
        self.assertFalse(self.window.btn_my_declutter.isEnabled())
        self.assertFalse(self.window.btn_my_dotfiles.isEnabled())
        self.assertFalse(self.window.btn_my_software.isEnabled())

    def test_my_helper_buttons_delegation_and_restriction(self):
        self.assertEqual(
            ALLOWED_MY_HELPERS, ("my_declutter", "my_dotfiles", "my_software")
        )
        executed = []
        with patch.object(
            self.window, "execute_task", side_effect=executed.append
        ):
            self.window.btn_my_declutter.click()
            self.window.btn_my_dotfiles.click()
            self.window.btn_my_software.click()
            self.assertEqual(
                executed, ["my_declutter", "my_dotfiles", "my_software"]
            )

        self.window.clear_output()
        self.window.execute_task("win_other_helper")
        self.assertIsNone(self.window._active_worker)
        self.assertIn(
            "Helper is disabled: win_other_helper",
            self.window.output_box.toPlainText(),
        )

        self.window.add_output("previous stale log line")
        with patch.object(self.window, "set_busy"), patch(
            "gui.gui.HelperWorker"
        ) as mock_worker_cls:
            self.window.execute_task("my_dotfiles")
            mock_worker_cls.return_value.start.assert_called_once()
        log_text = self.window.output_box.toPlainText()
        self.assertNotIn("previous stale log line", log_text)
        self.assertIn(">>> Running my_dotfiles...", log_text)

    def test_command_worker_execution(self):
        worker = HelperWorker(sys.executable, ["-c", "print('worker_test_line')"])
        received_lines = []
        exit_codes = []

        worker.output_line.connect(received_lines.append)
        worker.finished.connect(exit_codes.append)

        worker.start()
        worker.wait(5000)
        self.app.processEvents()

        self.assertIn("worker_test_line", received_lines)
        self.assertEqual(exit_codes, [0])

    def test_build_helper_command(self):
        for helper in ("my_declutter", "my_dotfiles", "my_software"):
            bash_cmd, bash_args = build_helper_command(helper, shell_exe="bash")
            self.assertEqual(bash_cmd, "bash")
            self.assertEqual(bash_args[0], "-c")
            self.assertTrue(bash_args[1].endswith(helper))

            ps_cmd, ps_args = build_helper_command(
                helper, shell_exe="powershell.exe"
            )
            self.assertEqual(ps_cmd, "powershell.exe")
            self.assertIn("-Command", ps_args)
            self.assertTrue(ps_args[-1].endswith(f"& {helper}"))

        with self.assertRaises(ValueError):
            build_helper_command("win_task", shell_exe="powershell.exe")

    def test_icon_loading(self):
        from gui.gui import get_app_icon
        icon = get_app_icon()
        self.assertFalse(icon.isNull())

    def test_install_winget_delegation(self):
        called_args = []
        with patch.object(
            self.window, "run_worker_command", side_effect=lambda *args, **kwargs: called_args.append((args, kwargs))
        ):
            with patch("sys.platform", "win32"):
                self.window.install_winget()
                self.assertEqual(len(called_args), 1)
                cmd_args, kwargs = called_args[0]
                self.assertTrue(cmd_args[0].lower().endswith(("powershell.exe", "pwsh.exe", "powershell", "pwsh")))
                self.assertEqual(cmd_args[1][-1], INSTALL_WINGET)
                self.assertIn("Installing WinGet...", kwargs.get("status_msg", ""))
                self.assertIn("WinGet installation completed.", kwargs.get("on_success_msg", ""))

    def test_install_git_delegation(self):
        called_args = []
        with patch.object(
            self.window, "run_worker_command", side_effect=lambda *args, **kwargs: called_args.append((args, kwargs))
        ):
            with patch("sys.platform", "win32"):
                self.window.install_git()
                self.assertEqual(len(called_args), 1)
                cmd_args, kwargs = called_args[0]
                self.assertTrue(cmd_args[0].lower().endswith(("powershell.exe", "pwsh.exe", "powershell", "pwsh")))
                self.assertEqual(cmd_args[1][-1], INSTALL_GIT)
                self.assertIn("Installing Git...", kwargs.get("status_msg", ""))
                self.assertIn("Git installation completed.", kwargs.get("on_success_msg", ""))
                cb = kwargs.get("on_finished_callback")
                self.assertIsNotNone(cb)
                with patch.object(self.window, "check_git_installed", return_value=(True, "v2.55.0")):
                    cb(0)
                    self.assertEqual(self.window.btn_install_git.text(), "v2.55.0")
                    self.assertFalse(self.window.btn_install_git.isEnabled())
                    self.assertTrue(self.window.btn_install_helpers.isEnabled())
                    self.assertTrue(self.window.btn_clone_dotfiles.isEnabled())

    def test_status_check_worker_winget_field(self):
        worker = StatusCheckWorker(None, None)
        status_results = []
        worker.status_ready.connect(status_results.append)
        worker.start()
        worker.wait(5000)
        self.app.processEvents()
        self.assertEqual(len(status_results), 1)
        self.assertIn("winget_installed", status_results[0])
        self.assertIn("winget_version", status_results[0])

    def test_clone_buttons_disabled_initially(self):
        new_win = MainWindow(refresh=False)
        try:
            self.assertFalse(new_win.btn_install_helpers.isEnabled())
            self.assertFalse(new_win.btn_clone_dotfiles.isEnabled())
        finally:
            new_win.close()

    def test_check_git_installed(self):
        with patch.object(self.window, "get_git_executable", return_value="git"):
            with patch("subprocess.run") as mock_run:
                mock_run.return_value.returncode = 0
                mock_run.return_value.stdout = "git version 2.50.0.windows.1"
                installed, version = self.window.check_git_installed()
                self.assertTrue(installed)
                self.assertEqual(version, "v2.50.0.windows.1")

                mock_run.return_value.returncode = 1
                mock_run.return_value.stdout = ""
                installed, version = self.window.check_git_installed()
                self.assertFalse(installed)
                self.assertEqual(version, "")

    def test_kill_workers_and_close_event(self):
        worker = HelperWorker(sys.executable, ["-c", "import time; time.sleep(10)"])
        worker.start()
        self.window._active_worker = worker
        self.assertTrue(worker.isRunning())
        self.window.close()
        self.assertFalse(worker.isRunning())

    def test_helper_worker_kill(self):
        worker = HelperWorker(sys.executable, ["-c", "import time; time.sleep(10)"])
        worker.start()
        for _ in range(50):
            if worker.process is not None:
                break
            self.app.processEvents()
            worker.wait(20)
        self.assertTrue(worker.isRunning())
        worker.kill()
        self.assertFalse(worker.isRunning())

    def test_scroll_area_prevents_squashing_on_small_height(self):
        self.assertTrue(hasattr(self.window, "scroll_area"))
        self.assertTrue(self.window.scroll_area.widgetResizable())
        self.window.show()
        self.window.resize(720, 280)
        self.app.processEvents()
        scroll_content = self.window.scroll_area.widget()
        self.assertIsNotNone(scroll_content)
        self.assertGreaterEqual(scroll_content.height(), 400)

    def test_update_helpers_and_dotfiles_use_git_pull_ff(self):
        called = []
        with patch.object(
            self.window,
            "run_worker_command",
            side_effect=lambda *args, **kwargs: called.append(args),
        ), patch.object(self.window, "get_git_executable", return_value="git"):
            with patch.object(
                self.window,
                "get_helpers_path",
                return_value="/tmp/shell-profile-helpers",
            ):
                self.window.install_or_update_helpers()
            with patch.object(
                self.window, "get_dotfiles_path", return_value="/tmp/dotfiles"
            ):
                self.window.clone_or_update_dotfiles()

        self.assertEqual(
            called[0],
            (
                "git",
                ["-C", "/tmp/shell-profile-helpers", "pull", "--ff", "origin", "main"],
            ),
        )
        self.assertEqual(
            called[1],
            ("git", ["-C", "/tmp/dotfiles", "pull", "--ff", "origin", "main"]),
        )

    def test_exe_self_update_check_and_swap(self):
        import hashlib
        import io
        import json
        import tempfile
        from gui.workers import (
            check_exe_update,
            apply_exe_update,
            cleanup_old_exe,
        )

        payload = json.dumps(
            {
                "tag_name": "v9.9.9",
                "assets": [
                    {
                        "name": "shell-profile-helpers.exe",
                        "browser_download_url": "https://example.com/shell-profile-helpers.exe",
                    }
                ],
            }
        ).encode("utf-8")

        class DummyResp(io.BytesIO):
            def __enter__(self):
                return self

            def __exit__(self, *args):
                self.close()

        with patch(
            "urllib.request.urlopen", side_effect=lambda *a, **kw: DummyResp(payload)
        ):
            has_upd, ver, url = check_exe_update(current_version="0.1.0")
            self.assertTrue(has_upd)
            self.assertEqual(ver, "v9.9.9")
            self.assertEqual(url, "https://example.com/shell-profile-helpers.exe")

            no_upd, _, _ = check_exe_update(current_version="9.9.9")
            self.assertFalse(no_upd)

        with tempfile.TemporaryDirectory() as tmpdir:
            fake_exe = os.path.join(tmpdir, "shell-profile-helpers.exe")
            with open(fake_exe, "wb") as f:
                f.write(b"MZoldbinary")

            old_hash = hashlib.sha256(b"MZoldbinary").hexdigest()
            new_hash = hashlib.sha256(b"MZnewbinary").hexdigest()

            same_ver_same_hash = json.dumps(
                {
                    "tag_name": "v0.1.0",
                    "assets": [
                        {
                            "name": "shell-profile-helpers.exe",
                            "digest": f"sha256:{old_hash}",
                            "browser_download_url": "https://example.com/shell-profile-helpers.exe",
                        }
                    ],
                }
            ).encode("utf-8")
            with patch(
                "urllib.request.urlopen",
                side_effect=lambda *a, **kw: DummyResp(same_ver_same_hash),
            ):
                self.assertFalse(
                    check_exe_update(current_version="0.1.0", exe_path=fake_exe)[0]
                )

            same_ver_diff_hash = json.dumps(
                {
                    "tag_name": "v0.1.0",
                    "assets": [
                        {
                            "name": "shell-profile-helpers.exe",
                            "digest": f"sha256:{new_hash}",
                            "browser_download_url": "https://example.com/shell-profile-helpers.exe",
                        }
                    ],
                }
            ).encode("utf-8")
            with patch(
                "urllib.request.urlopen",
                side_effect=lambda *a, **kw: DummyResp(same_ver_diff_hash),
            ):
                has_upd, ver, url = check_exe_update(
                    current_version="0.1.0", exe_path=fake_exe
                )
                self.assertTrue(has_upd)
                self.assertEqual(ver, "v0.1.0")
                self.assertEqual(url, "https://example.com/shell-profile-helpers.exe")

            with patch(
                "urllib.request.urlopen", return_value=DummyResp(b"MZnewbinary")
            ):
                updated = apply_exe_update(
                    "https://example.com/shell-profile-helpers.exe", exe_path=fake_exe
                )
                self.assertEqual(updated, fake_exe)
                with open(fake_exe, "rb") as f:
                    self.assertEqual(f.read(), b"MZnewbinary")
                self.assertTrue(os.path.exists(f"{fake_exe}.old"))

            cleanup_old_exe(fake_exe)
            self.assertFalse(os.path.exists(f"{fake_exe}.old"))

        self.window._on_status_ready(
            {
                "git_installed": True,
                "helpers_installed": True,
                "dotfiles_installed": True,
                "dotfiles_user": "u",
                "exe_version": "v0.1.0",
                "exe_update_available": True,
                "exe_latest_version": "v0.1.0",
                "exe_download_url": "https://example.com/shell-profile-helpers.exe",
            }
        )
        self.assertEqual(self.window.btn_update_exe.text(), "Update (v0.1.0)")
        self.assertTrue(self.window.btn_update_exe.isEnabled())

        self.window._on_status_ready(
            {
                "git_installed": True,
                "helpers_installed": True,
                "dotfiles_installed": True,
                "dotfiles_user": "u",
                "exe_version": "v0.1.0",
                "exe_update_available": True,
                "exe_latest_version": "v0.2.0",
                "exe_download_url": "https://example.com/shell-profile-helpers.exe",
            }
        )
        self.assertEqual(self.window.app_label.text(), "Shell Profile Helpers:")
        self.assertEqual(self.window.btn_update_exe.text(), "Update -> v0.2.0")
        self.assertTrue(self.window.btn_update_exe.isEnabled())


if __name__ == "__main__":
    unittest.main()

