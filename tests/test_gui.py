import os
import sys
import unittest
from pathlib import Path

os.environ["QT_QPA_PLATFORM"] = "offscreen"

from PyQt5.QtWidgets import QApplication

root_dir = Path(__file__).resolve().parent.parent
if str(root_dir) not in sys.path:
    sys.path.insert(0, str(root_dir))

from cli_helpers.gui import (
    MainWindow,
    CommandWorker,
    StatusCheckWorker,
    TaskLoaderWorker,
)


class TestGui(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QApplication.instance() or QApplication([])

    def setUp(self):
        self.window = MainWindow()

    def tearDown(self):
        self.window.clear_recent_tasks()
        self.window.close()

    def test_window_properties(self):
        self.assertEqual(self.window.windowTitle(), "cli-helpers GUI")
        self.assertEqual(self.window.title_bar.titleLabel.text(), "cli-helpers GUI")
        self.assertEqual(self.window.setup_title.text(), "Setup")
        self.assertEqual(self.window.tasks_title.text(), "Run")
        self.assertEqual(self.window.output_title.text(), "Output log")

    def test_path_discovery(self):
        ps = self.window.get_powershell_executable()
        self.assertTrue(bool(ps))

        helpers_path = self.window.get_cli_helpers_path()
        self.assertIsNotNone(helpers_path)
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
            "dotfiles_installed": True,
            "dotfiles_user": "testuser",
        }
        self.window._on_status_ready(mock_info)
        self.assertEqual(self.window.git_badge.text(), "Installed")
        self.assertEqual(self.window.helpers_badge.text(), "Installed")
        self.assertEqual(self.window.dotfiles_badge.text(), "Installed")
        self.assertEqual(self.window.btn_install_helpers.text(), "Update helpers")
        self.assertEqual(self.window.btn_clone_dotfiles.text(), "Update dotfiles")
        self.assertEqual(self.window.tb_username.text(), "testuser")

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
        self.window.execute_task = executed.append

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
        worker = CommandWorker(sys.executable, ["-c", "print('worker_test_line')"])
        received_lines = []
        exit_codes = []

        worker.output_line.connect(received_lines.append)
        worker.finished.connect(exit_codes.append)

        worker.start()
        worker.wait(5000)
        self.app.processEvents()

        self.assertIn("worker_test_line", received_lines)
        self.assertEqual(exit_codes, [0])


if __name__ == "__main__":
    unittest.main()
