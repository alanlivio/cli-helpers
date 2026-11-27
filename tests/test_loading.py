import glob
import os
import platform
import shutil
import subprocess
import unittest


def _get_bash_executable():
    if platform.system() != "Windows":
        return shutil.which("bash")
    bash = shutil.which("bash")
    if not bash:
        return None
    try:
        res = subprocess.run(
            [bash, "--version"], capture_output=True, text=True, timeout=5
        )
        return bash if res.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


def _get_powershell_executable():
    ps = shutil.which("powershell.exe") or shutil.which("pwsh") or shutil.which("powershell")
    if not ps:
        return None
    try:
        res = subprocess.run(
            [ps, "-NoProfile", "-Command", "exit 0"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        return ps if res.returncode == 0 else None
    except (OSError, subprocess.TimeoutExpired):
        return None


class TestScriptLoading(unittest.TestCase):
    def setUp(self):
        self.root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    def test_bash_scripts_load(self):
        bash = _get_bash_executable()
        if bash is None:
            self.skipTest("bash not available on this platform")

        scripts = (
            glob.glob(os.path.join(self.root_dir, "os", "*.sh"))
            + glob.glob(os.path.join(self.root_dir, "programs", "*.sh"))
            + glob.glob(os.path.join(self.root_dir, "*.sh"))
            + glob.glob(os.path.join(self.root_dir, "packaging", "*.plugin.bash"))
        )
        self.assertGreater(len(scripts), 0)

        for script in scripts:
            with self.subTest(script=os.path.basename(script)):
                rel_path = os.path.relpath(script, self.root_dir).replace("\\", "/")
                res = subprocess.run(
                    [bash, "-n", rel_path],
                    cwd=self.root_dir,
                    capture_output=True,
                    text=True,
                )
                output = (res.stdout + res.stderr).strip()
                self.assertEqual(
                    res.returncode,
                    0,
                    f"Failed to parse {script}:\n{output}",
                )

    def test_powershell_scripts_load(self):
        ps = _get_powershell_executable()
        if ps is None:
            self.skipTest("powershell.exe not available on this platform")

        scripts = (
            glob.glob(os.path.join(self.root_dir, "os", "*.ps1"))
            + glob.glob(os.path.join(self.root_dir, "programs", "*.ps1"))
            + glob.glob(os.path.join(self.root_dir, "*.ps1"))
        )
        self.assertGreater(len(scripts), 0)

        joined = ",".join(f"'{s}'" for s in scripts)
        cmd = (
            f"$failed = @(); foreach ($f in @({joined})) {{ "
            f"$errs = $null; "
            f"[void][System.Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$errs); "
            f"if ($errs.Count -gt 0) {{ $failed += \"$f : $($errs | Out-String)\" }} "
            f"}}; if ($failed.Count -gt 0) {{ $failed | Write-Error; exit 1 }}"
        )
        res = subprocess.run(
            [ps, "-NoProfile", "-NonInteractive", "-Command", cmd],
            capture_output=True,
            text=True,
        )
        self.assertEqual(
            res.returncode, 0, f"Failed to parse PowerShell scripts:\n{res.stderr}"
        )


if __name__ == "__main__":
    unittest.main()
