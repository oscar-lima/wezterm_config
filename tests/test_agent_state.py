"""Exercise wezterm-agent-state terminal discovery without a controlling tty."""

import base64
import os
from pathlib import Path
import pty
import select
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "bin/wezterm-agent-state"


def read_terminal(master: int, timeout: float = 2.0) -> bytes:
    output = b""
    while True:
        ready, _, _ = select.select([master], [], [], timeout)
        if not ready:
            return output
        try:
            chunk = os.read(master, 4096)
        except OSError:
            return output
        if not chunk:
            return output
        output += chunk
        timeout = 0.2


def sequence(state: str) -> bytes:
    encoded = base64.b64encode(state.encode()).decode()
    return f"\033]1337;SetUserVar=agent_state={encoded}\007".encode()


class AgentStateTests(unittest.TestCase):
    def run_detached(self, state: str, pane: str = "7") -> tuple[int, bytes]:
        """Run the helper the way Claude Code runs hooks.

        The hook has no controlling terminal and its own stdio is redirected,
        so the helper must find the pseudo-terminal held by an ancestor. A
        Python intermediary keeps that terminal on its stdout while the helper
        itself only sees /dev/null.
        """
        master, slave = pty.openpty()
        env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
        if pane:
            env["WEZTERM_PANE"] = pane
        intermediary = (
            "import subprocess, sys\n"
            "sys.exit(subprocess.run(sys.argv[1:], stdin=subprocess.DEVNULL,"
            " stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode)"
        )
        try:
            process = subprocess.run(
                [sys.executable, "-c", intermediary, str(HELPER), state],
                stdin=subprocess.DEVNULL,
                stdout=slave,
                stderr=subprocess.DEVNULL,
                env=env,
                start_new_session=True,
                check=False,
                timeout=10,
            )
            output = read_terminal(master)
        finally:
            os.close(slave)
            os.close(master)
        return process.returncode, output

    def test_publishes_state_through_ancestor_terminal(self):
        returncode, output = self.run_detached("running")
        self.assertEqual(returncode, 0)
        self.assertEqual(output, sequence("running"))

    def test_clear_publishes_empty_state(self):
        _, output = self.run_detached("clear")
        self.assertEqual(output, sequence(""))

    def test_ignores_terminals_outside_wezterm(self):
        returncode, output = self.run_detached("running", pane="")
        self.assertEqual(returncode, 0)
        self.assertEqual(output, b"")

    def test_rejects_unknown_state(self):
        result = subprocess.run(
            [HELPER, "bogus"],
            stdin=subprocess.DEVNULL,
            capture_output=True,
            env={"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "WEZTERM_PANE": "1"},
            check=False,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn(b"usage", result.stderr)


if __name__ == "__main__":
    unittest.main()
