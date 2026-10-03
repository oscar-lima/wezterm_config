"""Offline tests of wezterm-xim-count (#302): grouping per client, notification hysteresis, log line."""

import datetime
import importlib.machinery
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
_loader = importlib.machinery.SourceFileLoader("wezterm_xim_count", str(ROOT / "bin/wezterm-xim-count"))
_spec = importlib.util.spec_from_loader("wezterm_xim_count", _loader)
count = importlib.util.module_from_spec(_spec)
_loader.exec_module(count)

MASK = 0x1FFFFF
NO_START = lambda pid: 7


class SummarizeTests(unittest.TestCase):
    def test_windows_are_grouped_by_client_base_and_wezterm_clients_summed(self):
        ids = [0x2E00000 + i for i in range(1, 6)] + [0x2000000 + 1, 0x2000000 + 2] + [0x3000001]
        names = {1: "wezterm-gui", 2: "ibus-x11", 3: "python"}
        pids = {0x2E00000: 1, 0x2000000: 2, 0x3000000: 3}
        summary = count.summarize(ids, MASK, pids, names=lambda pid: names[pid], starts=NO_START)
        self.assertEqual(summary["total"], 8)
        self.assertEqual(summary["wezterm"], 5)
        self.assertEqual([c["name"] for c in summary["clients"]], ["wezterm-gui", "ibus-x11", "python"])
        self.assertEqual(summary["clients"][0]["windows"], 5)

    def test_an_unnamed_client_is_not_counted_as_wezterm(self):
        summary = count.summarize([0x2E00001, 0x2E00002], MASK, {}, names=lambda pid: "", starts=NO_START)
        self.assertEqual(summary["wezterm"], 0)
        self.assertEqual(summary["clients"][0]["base"], "0x2e00000")

    def test_two_wezterm_processes_add_up(self):
        ids = [0x2E00001, 0x2E00002, 0x4800001]
        summary = count.summarize(ids, MASK, {0x2E00000: 10, 0x4800000: 11}, names=lambda pid: "wezterm-gui", starts=NO_START)
        self.assertEqual(summary["wezterm"], 3)


class UnknownTests(unittest.TestCase):
    def test_unreadable_window_list_makes_wezterm_unknown_not_zero(self):
        summary = count.summarize([0x2E00001, 0x2E00002], MASK, None, names=lambda pid: "", starts=NO_START)
        self.assertIsNone(summary["wezterm"])
        self.assertEqual(summary["total"], 2)
        self.assertIn("wezterm=UNKNOWN", count.log_line(summary, "timer", datetime.datetime(2026, 10, 3, 3, 30, 0)))

    def test_failed_measurement_logs_unknown_and_fails(self):
        import os, tempfile
        log = os.path.join(tempfile.mkdtemp(), "count.log")
        original = count.measure
        count.measure = lambda: (_ for _ in ()).throw(OSError("no X connection"))
        try:
            self.assertEqual(count.main(["--log", log]), 1)
        finally:
            count.measure = original
        self.assertIn("total=UNKNOWN wezterm=UNKNOWN error=no X connection", open(log).read())

    def test_no_wmctrl_is_none(self):
        original = count.subprocess.run
        count.subprocess.run = lambda *a, **k: (_ for _ in ()).throw(FileNotFoundError("wmctrl"))
        try:
            self.assertIsNone(count.window_pids(MASK))
        finally:
            count.subprocess.run = original


class GrowthTests(unittest.TestCase):
    def test_growth_alert_needs_a_known_previous_and_current_count(self):
        self.assertTrue(count.decide_growth(100, 250, 100))
        self.assertFalse(count.decide_growth(100, 200, 100))
        self.assertFalse(count.decide_growth(None, 900, 100))
        self.assertFalse(count.decide_growth(100, None, 100))


class WindowPidTests(unittest.TestCase):
    def test_wmctrl_listing_maps_windows_to_client_bases(self):
        listing = ("0x02e00003  0 207627        N/A [9/13] tab\n"
                   "0x0480001a  0 3874784 host Firefox title\n"
                   "0x01800006  0 0     host no pid\n")
        self.assertEqual(count.window_pids(MASK, listing), {0x2E00000: 207627, 0x4800000: 3874784})


class NotifyTests(unittest.TestCase):
    def test_notify_once_per_crossing_and_rearm_below_half(self):
        self.assertEqual(count.decide_notify(600, False, 500), (True, True))
        self.assertEqual(count.decide_notify(900, True, 500), (False, True))
        self.assertEqual(count.decide_notify(300, True, 500), (False, True))   # still above half: stays quiet
        self.assertEqual(count.decide_notify(200, True, 500), (False, False))  # re-armed
        self.assertEqual(count.decide_notify(400, False, 500), (False, False))


class LogTests(unittest.TestCase):
    def test_log_line_has_time_event_totals_and_top_clients(self):
        summary = {"total": 700, "wezterm": 640, "clients": [
            {"base": "0x2e00000", "windows": 640, "pid": 1, "start": 5, "name": "wezterm-gui"},
            {"base": "0x2000000", "windows": 50, "pid": 2, "start": 6, "name": "ibus-x11"},
            {"base": "0x3000000", "windows": 5, "pid": None, "name": ""}]}
        line = count.log_line(summary, "timer", datetime.datetime(2026, 10, 3, 3, 30, 0))
        self.assertEqual(line, "2026-10-03T03:30:00 event=timer total=700 wezterm=640 "
                               "top=wezterm-gui[1@5]=640,ibus-x11[2@6]=50,0x3000000=5")


if __name__ == "__main__":
    unittest.main()
