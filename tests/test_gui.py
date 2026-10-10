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

from cli_helpers.gui import (
    MainWindow,
    HelperWorker,
    StatusCheckWorker,
    HelperDiscoveryWorker,
    build_helper_command,
    InfoLevel,
)


class TestGui(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.window = MainWindow(refresh=False)

    def tearDown(self):
        self.window.clear_recent_tasks()
        self.window.close()
        for worker in [
            getattr(self.window, "_active_worker", None),
            getattr(self.window, "_status_worker", None),
            getattr(self.window, "_helper_worker", None),
            getattr(self.window, "_task_worker", None),
        ]:
            if worker and worker.isRunning():
                worker.wait(100)
        self.app.processEvents()

    def test_window_properties(self):
        self.assertEqual(self.window.windowTitle(), "CLI Helpers")
        self.assertEqual(self.window.title_bar.titleLabel.text(), "CLI Helpers")
        self.assertEqual(self.window.setup_title.text(), "Setup")
        self.assertEqual(self.window.tasks_title.text(), "Run")
        self.assertEqual(self.window.output_title.text(), "Output log")
        self.assertEqual(self.window.helpers_label.text(), "~/src/cli-helpers:")
        self.assertEqual(self.window.helpers_github_prefix.text(), "github.com/")
        self.assertEqual(self.window.tb_helpers_user.placeholderText(), "USER")
        self.assertEqual(self.window.helpers_repo_suffix.text(), "/cli-helpers")
        self.assertEqual(self.window.dotfiles_label.text(), "~/src/dotfiles:")
        self.assertEqual(self.window.github_prefix_label.text(), "github.com/")
        self.assertEqual(self.window.tb_username.placeholderText(), "USER")
        self.assertEqual(self.window.dotfiles_repo_suffix.text(), "/dotfiles")
        self.assertFalse(self.window.windowIcon().isNull())

    def test_path_discovery(self):
        ps = self.window.get_powershell_executable()
        self.assertTrue(bool(ps))

        helpers_path = self.window.get_cli_helpers_path()
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
        self.window.set_busy(True, "Working...")
        self.assertEqual(self.window.status_label.text(), "Working...")
        self.assertFalse(self.window.btn_refresh_all.isEnabled())
        self.assertFalse(self.window.btn_reload_tasks.isEnabled())
        self.assertFalse(self.window.btn_run_my_task.isEnabled())
        self.assertFalse(self.window.btn_run_recent_task.isEnabled())

        self.window.set_busy(False, "Done")
        self.assertEqual(self.window.status_label.text(), "Done")
        self.assertTrue(self.window.btn_refresh_all.isEnabled())
        self.assertTrue(self.window.btn_reload_tasks.isEnabled())

    def test_status_ready_callback(self):
        mock_info = {
            "git_installed": True,
            "git_version": "v2.55.0",
            "helpers_installed": True,
            "helpers_user": "helperuser",
            "dotfiles_installed": True,
            "dotfiles_user": "testuser",
        }
        self.window._on_status_ready(mock_info)
        self.assertEqual(self.window.git_badge.text(), "Installed")
        self.assertEqual(self.window.helpers_badge.text(), "Installed")
        self.assertEqual(self.window.helpers_badge.level, InfoLevel.SUCCESS)
        self.assertEqual(self.window.dotfiles_badge.text(), "Installed")
        self.assertEqual(self.window.dotfiles_badge.level, InfoLevel.SUCCESS)
        self.assertEqual(self.window.btn_install_helpers.text(), "Update helpers")
        self.assertEqual(self.window.btn_clone_dotfiles.text(), "Update dotfiles")
        self.assertEqual(self.window.tb_helpers_user.text(), "helperuser")
        self.assertEqual(self.window.tb_username.text(), "testuser")

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
        self.assertEqual(self.window.helpers_badge.text(), "Not updated")
        self.assertEqual(self.window.helpers_badge.level, InfoLevel.WARNING)
        self.assertEqual(self.window.dotfiles_badge.text(), "Not updated")
        self.assertEqual(self.window.dotfiles_badge.level, InfoLevel.WARNING)

    def test_status_not_installed(self):
        mock_info = {
            "git_installed": False,
            "helpers_installed": False,
            "dotfiles_installed": False,
        }
        self.window._on_status_ready(mock_info)
        self.assertEqual(self.window.helpers_badge.text(), "Not installed")
        self.assertEqual(self.window.helpers_badge.level, InfoLevel.ERROR)
        self.assertEqual(self.window.btn_install_helpers.text(), "Clone helpers")
        self.assertEqual(self.window.dotfiles_badge.text(), "Not installed")
        self.assertEqual(self.window.dotfiles_badge.level, InfoLevel.ERROR)
        self.assertEqual(self.window.btn_clone_dotfiles.text(), "Clone dotfiles")

    def test_tasks_loaded_callback(self):
        tasks = ["win_task_a", "ubu_task_b", "my_task_c"]
        self.window._on_tasks_loaded(tasks)
        self.assertEqual(self.window.task_selector.count(), 3)
        self.assertEqual(self.window.task_selector.itemText(0), "win_task_a")
        self.assertTrue(self.window.btn_run_task.isEnabled())

        self.assertEqual(self.window.my_task_selector.count(), 1)
        self.assertEqual(self.window.my_task_selector.itemText(0), "my_task_c")
        self.assertTrue(self.window.btn_run_my_task.isEnabled())

        self.window._on_tasks_loaded([])
        self.assertEqual(self.window.task_selector.count(), 0)
        self.assertFalse(self.window.btn_run_task.isEnabled())
        self.assertEqual(self.window.my_task_selector.count(), 0)
        self.assertFalse(self.window.btn_run_my_task.isEnabled())

    def test_recent_tasks(self):
        self.window.clear_recent_tasks()
        self.assertEqual(self.window.recent_task_selector.count(), 0)
        self.assertFalse(self.window.btn_run_recent_task.isEnabled())

        self.window.add_recent_task("my_task_1")
        self.assertEqual(self.window.recent_task_selector.count(), 1)
        self.assertEqual(self.window.recent_task_selector.currentText(), "my_task_1")
        self.assertTrue(self.window.btn_run_recent_task.isEnabled())

        self.window.add_recent_task("win_task_2")
        self.assertEqual(self.window.recent_task_selector.count(), 2)
        self.assertEqual(self.window.recent_task_selector.itemText(0), "win_task_2")
        self.assertEqual(self.window.recent_task_selector.itemText(1), "my_task_1")

        self.window.add_recent_task("my_task_1")
        self.assertEqual(self.window.recent_task_selector.count(), 2)
        self.assertEqual(self.window.recent_task_selector.itemText(0), "my_task_1")
        self.assertEqual(self.window.recent_task_selector.itemText(1), "win_task_2")

        self.window.clear_recent_tasks()
        self.assertEqual(self.window.recent_task_selector.count(), 0)
        self.assertFalse(self.window.btn_run_recent_task.isEnabled())

    def test_run_methods_delegation(self):
        executed = []
        with patch.object(
            self.window, "execute_task", side_effect=executed.append
        ):
            self.window.task_selector.addItem("win_test")
            self.window.run_task()
            self.assertEqual(executed, ["win_test"])

            self.window.my_task_selector.addItem("my_test")
            self.window.run_my_task()
            self.assertEqual(executed, ["win_test", "my_test"])

            self.window.recent_task_selector.addItem("recent_test")
            self.window.run_recent_task()
            self.assertEqual(executed, ["win_test", "my_test", "recent_test"])

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

    def test_command_worker_parse_tasks(self):
        worker = HelperWorker(
            sys.executable,
            ["-c", "print('win_foo\\nmy_bar')"],
            parse_helpers=True,
        )
        loaded = []
        worker.helpers_loaded.connect(loaded.append)
        worker.start()
        worker.wait(5000)
        self.app.processEvents()
        self.assertEqual(loaded, [["win_foo", "my_bar"]])

    def test_task_loader_worker_powershell(self):
        worker = HelperDiscoveryWorker(shell_exe="powershell.exe")
        self.assertEqual(worker.shell_type, "powershell")
        self.assertIn("-NoProfile", worker.args)
        self.assertIn("-ExecutionPolicy", worker.args)
        self.assertIn("-Command", worker.args)
        self.assertTrue(any("Get-Command" in arg for arg in worker.args))

    def test_task_loader_worker_bash(self):
        worker = HelperDiscoveryWorker(shell_exe="bash")
        self.assertEqual(worker.shell_type, "bash")
        self.assertEqual(worker.args[0], "-c")
        self.assertTrue(any("compgen" in arg for arg in worker.args))

    def test_task_loader_worker_custom_script(self):
        worker_bash = HelperDiscoveryWorker("bash", "echo custom_task")
        self.assertEqual(worker_bash.shell_type, "bash")
        self.assertEqual(worker_bash.args, ["-c", "echo custom_task"])

        worker_ps = HelperDiscoveryWorker("powershell.exe", 'Write-Host "test"')
        self.assertEqual(worker_ps.shell_type, "powershell")
        self.assertIn('Write-Host `"test`"', worker_ps.args[-1])

    def test_build_helper_command(self):
        bash_cmd, bash_args = build_helper_command("my_task", shell_exe="bash")
        self.assertEqual(bash_cmd, "bash")
        self.assertEqual(bash_args[0], "-c")
        self.assertTrue(bash_args[1].endswith("my_task"))

        ps_cmd, ps_args = build_helper_command("win_task", shell_exe="powershell.exe")
        self.assertEqual(ps_cmd, "powershell.exe")
        self.assertIn("-Command", ps_args)
        self.assertTrue(ps_args[-1].endswith("& win_task"))

    def test_icon_loading(self):
        from cli_helpers.gui import get_app_icon
        icon = get_app_icon()
        self.assertFalse(icon.isNull())


if __name__ == "__main__":
    unittest.main()

