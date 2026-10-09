"""Tests for tools/public_text.py: every bad sample must be flagged, every good sample must pass.
Bad samples are assembled from pieces so this file itself stays clean.   python tools/test_public_text.py"""
import os
import subprocess
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import public_text as pt  # noqa: E402

BAD = [
    "contested owners: active party only (" + "deci" + "sion 63)",
    "see " + "dec" + ". 66",
    "# the " + "deci" + "sion-63 fix: owners come from the active party",
    "user " + "deci" + "sion 2026-10-09: every item gets its condition",
    "shared folder: a link to ../." + "cla" + "ude",
    "moved to the private " + "Auto" + "pilot mod",
    "read the " + "HAND" + "OFF first",
    "merged by the main " + "session",
    "C:" + "\\Users\\someone\\Desk" + "top\\mods",
    "/c/" + "Users/someone/mods",
    "recorded in helm " + "attempt 164",
]
GOOD = [
    "Owners are chosen among the active party.",
    "The private play-testing tools are not part of this repository.",
    "IMGUI is ready once the client has finished loading the session.",
    "Speedy Reply: found on a dead caravan agent.",
    "Install the pre-push hook (see CONTRIBUTING).",
    "A decision tree picks the best item; see the Decisions section.",
]


class PublicText(unittest.TestCase):
    def test_bad_samples_fail(self):
        for s in BAD:
            self.assertTrue(pt.scan_text(s, "sample", names=set()), "not flagged: %r" % s)

    def test_good_samples_pass(self):
        for s in GOOD:
            self.assertEqual(pt.scan_text(s, "sample", names=set()), [], "flagged: %r" % s)

    def test_hashed_names(self):
        names = {pt.name_hash("Example Campaign")}
        self.assertTrue(pt.scan_text("loaded the example  CAMPAIGN save", "s", names=names))
        self.assertEqual(pt.scan_text("an example of a campaign", "s", names=names), [])

    def test_cli_exit_codes(self):
        run = [sys.executable, os.path.join(HERE, "public_text.py"), "text"]
        bad = subprocess.run(run, input=BAD[0], capture_output=True, text=True)
        good = subprocess.run(run, input=GOOD[0], capture_output=True, text=True)
        self.assertEqual((bad.returncode, good.returncode), (1, 0), bad.stdout + good.stdout)


if __name__ == "__main__":
    unittest.main()
