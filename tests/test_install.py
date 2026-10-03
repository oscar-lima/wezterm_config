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
            opencode_plugins = base / "opencode-plugins"
            data = base / "data"
            systemd = base / "systemd user"
            desktop = data / "applications/org.wezfurlong.wezterm.desktop"
            desktop.parent.mkdir(parents=True)
            original = "[Desktop Entry]\nName=Previous launcher\n"
            desktop.write_text(original)
            opencode_original = "export const Previous = async () => ({})\n"
            opencode_plugins.mkdir(parents=True)
            (opencode_plugins / "opencode-agent-state.js").write_text(opencode_original)
            command = [str(ROOT / "install.sh"), "--config-dir", config.name,
                       "--bin-dir", str(helpers),
                       "--systemd-dir", str(systemd),
                       "--opencode-plugins-dir", str(opencode_plugins)]
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
            self.assertTrue(os.access(helpers / "wezterm-xim-count", os.X_OK))
            for unit in ("wezterm-xim-count.service",):
                text = (systemd / unit).read_text()
                self.assertNotIn("@BIN_DIR@", text)
                self.assertIn(f"ExecStart={helpers}/wezterm-xim-count", text)
            self.assertTrue((systemd / "wezterm-xim-count.timer").exists())
            self.assertEqual(len(list(systemd.glob("*.backup-*"))), 2)   # the second run backed up the first
            opencode_plugin = opencode_plugins / "opencode-agent-state.js"
            self.assertEqual(
                (ROOT / "integrations/opencode-agent-state.js").read_bytes(),
                opencode_plugin.read_bytes())
            self.assertIn(opencode_original, [p.read_text() for p in
                          opencode_plugins.glob("*.backup-*")])
            self.assertEqual(len(list(opencode_plugins.glob("*.backup-*"))), 2)
            if shutil.which("desktop-file-validate"):
                subprocess.run(["desktop-file-validate", str(desktop)], check=True,
                               capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
