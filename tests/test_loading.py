import unittest
import os
import glob
import subprocess

class TestScriptLoading(unittest.TestCase):
    def setUp(self):
        self.root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

    def test_bash_scripts_load(self):
        # Gather all bash scripts
        scripts = glob.glob(os.path.join(self.root_dir, 'os', '*.bash')) + \
                  glob.glob(os.path.join(self.root_dir, 'programs', '*.bash')) + \
                  [os.path.join(self.root_dir, 'init.sh')]
                  
        for script in scripts:
            with self.subTest(script=os.path.basename(script)):
                rel_path = os.path.relpath(script, self.root_dir).replace('\\', '/')
                # Parse the Bash script to ensure it's syntactically valid and loadable
                res = subprocess.run(["bash", "-n", rel_path], cwd=self.root_dir, capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, f"Failed to parse {script}:\n{res.stderr}")

    def test_powershell_scripts_load(self):
        # Gather all powershell scripts
        scripts = glob.glob(os.path.join(self.root_dir, 'os', '*.ps1')) + \
                  glob.glob(os.path.join(self.root_dir, 'programs', '*.ps1')) + \
                  [os.path.join(self.root_dir, 'init.ps1')]
                  
        for script in scripts:
            with self.subTest(script=os.path.basename(script)):
                # Parse the PowerShell script to ensure it's syntactically valid and loadable
                cmd = f"try {{ $errs = $null; [System.Management.Automation.Language.Parser]::ParseFile('{script}', [ref]$null, [ref]$errs); if ($errs.Count -gt 0) {{ $errs | ForEach-Object {{ Write-Error $_.Message }}; exit 1 }} }} catch {{ exit 1 }}"
                res = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, f"Failed to parse {script}:\n{res.stderr}")

if __name__ == '__main__':
    unittest.main()
