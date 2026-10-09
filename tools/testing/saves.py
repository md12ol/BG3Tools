"""List Baldur's Gate 3 saves the way the game's Load Game list shows them (newest first), to find a save by name.

  python tools/testing/saves.py                 every save, newest first: row in the load list, time, folder
  python tools/testing/saves.py QuickSave_12    only saves whose folder name contains the text (case-insensitive)

Loading itself is manual (main menu or Esc menu -> Load Game -> the row printed here). Read-only: never touches a save.
"""
import os
import sys
import time

ROOT = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Larian Studios", "Baldur's Gate 3", "PlayerProfiles")


def saves():
    out = []
    if not os.path.isdir(ROOT):
        return out
    for profile in os.listdir(ROOT):
        story = os.path.join(ROOT, profile, "Savegames", "Story")
        if os.path.isdir(story):
            for d in os.listdir(story):
                p = os.path.join(story, d)
                if os.path.isdir(p):
                    out.append((os.path.getmtime(p), profile, d))
    return sorted(out, reverse=True)


def main(argv):
    want = argv[0].lower() if argv else ""
    rows = saves()
    if not rows:
        print("no saves under %s" % ROOT)
        return 1
    shown = 0
    for i, (t, profile, d) in enumerate(rows):
        if want in d.lower():
            print("row %3d  %s  %s  %s" % (i, time.strftime("%Y-%m-%d %H:%M", time.localtime(t)), profile, d))
            shown += 1
    if not shown:
        print("no save folder contains %r" % argv[0])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
