"""Check desktop launcher installation without modifying the user's config."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux desktop launcher")
class InstallTests(unittest.TestCase):
    def test_custom_destination_and_launcher_backup(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            config = base / "config with spaces"
            helpers = base / "bin"
            data = base / "data"
            desktop = data / "applications/org.wezfurlong.wezterm.desktop"
            desktop.parent.mkdir(parents=True)
            original = "[Desktop Entry]\nName=Previous launcher\n"
            desktop.write_text(original)
            command = [str(ROOT / "install.sh"), "--config-dir", config.name,
                       "--bin-dir", str(helpers)]
            environment = {**os.environ, "XDG_DATA_HOME": str(data)}

            for _ in range(2):
                subprocess.run(command, cwd=base, env=environment, check=True,
                               capture_output=True, text=True)

            self.assertIn(
                f'Exec=wezterm --config-file "{config}/wezterm.lua" '
                'start --always-new-process --cwd .\n', desktop.read_text())
            self.assertIn(original, [p.read_text() for p in
                          desktop.parent.glob("*.backup-*")])
            self.assertEqual(len(list(desktop.parent.glob("*.backup-*"))), 2)
            for source in [ROOT / "wezterm.lua", *ROOT.glob("features/*.lua")]:
                self.assertEqual(source.read_bytes(),
                                 (config / source.relative_to(ROOT)).read_bytes())
            self.assertTrue(os.access(helpers / "wezterm-agent-state", os.X_OK))
            if shutil.which("desktop-file-validate"):
                subprocess.run(["desktop-file-validate", str(desktop)], check=True,
                               capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
