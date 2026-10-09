"""Installs the project's mods into BG3 and enables them in the load order.

  1. copies dist/BuildAdvisor.pak and dist/LootAdvisor.pak (+ BG3_EXTRA_MODS, see build_pak.py) to
     %LOCALAPPDATA%\\Larian Studios\\Baldur's Gate 3\\Mods\\
  2. makes sure PlayerProfiles\\Public\\modsettings.lsx has a ModuleShortDesc entry for each mod (in MODS
     order). If the file also has a ModOrder node (pre-Patch-7 format), a
     matching <node id="Module"> entry is added there too. Existing entries are left alone, so running it again
     changes nothing. Before the first change of a run the old file is saved as modsettings.lsx.bak.

Mod identity (Folder, Name, UUID, Version64) is read from Mods/<Folder>/meta.lsx, so it stays in sync with the paks.
The game must be closed (it holds the paks open and rewrites modsettings.lsx when it exits).

Run:  python tools/install_mods.py            (build first: python tools/build_pak.py)
      python tools/install_mods.py --dry-run  (print what would change, touch nothing)
      python tools/install_mods.py --extra MyTestMod   (also install/enable extra mods, e.g. test mods)
      python tools/install_mods.py --remove MyTestMod  (disable a mod: drop its modsettings.lsx entries and
                                                                move its pak out of the game's Mods folder to dist/disabled/)
"""
import os
import re
import shutil
import subprocess
import sys

from build_pak import mod_src, MODS as BUILT   # <project>/Mods/<Folder> next to this repo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODS = list(BUILT)  # order = order in modsettings.lsx
BG3_DATA = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Larian Studios", "Baldur's Gate 3")
MODS_DIR = os.path.join(BG3_DATA, "Mods")
MODSETTINGS = os.path.join(BG3_DATA, "PlayerProfiles", "Public", "modsettings.lsx")

SHORT_DESC_RE = re.compile(r'[ \t]*<node id="ModuleShortDesc">.*?</node>[ \t]*\r?\n', re.S)
MODULE_RE = re.compile(r'[ \t]*<node id="Module">.*?</node>[ \t]*\r?\n', re.S)


def attr(block, name):
    m = re.search(r'<attribute id="%s" type="[^"]*" value="([^"]*)"' % re.escape(name), block)
    return m.group(1) if m else None


def set_attr(block, name, value):
    return re.sub(r'(<attribute id="%s" type="[^"]*" value=")[^"]*(")' % re.escape(name),
                  lambda m: m.group(1) + value + m.group(2), block)


def read_meta(folder):
    text = open(os.path.join(mod_src(folder), "meta.lsx"), encoding="utf-8-sig").read()
    info = {k: attr(text, k) for k in ("Folder", "Name", "UUID", "Version64")}
    missing = [k for k, v in info.items() if not v]
    if missing:
        raise SystemExit("meta.lsx of %s lacks %s" % (folder, ", ".join(missing)))
    return info


def patch_modsettings(text, metas):
    """Returns (new_text, list of change descriptions). Pure function (no I/O) so it can be tested on a copy."""
    changes = []
    for i, meta in enumerate(metas):
        uuid = meta["UUID"].lower()
        # --- Mods / ModuleShortDesc
        blocks = list(SHORT_DESC_RE.finditer(text))
        if not blocks:
            raise SystemExit("modsettings.lsx has no ModuleShortDesc node to copy the format from")
        if not any((attr(b.group(0), "UUID") or "").lower() == uuid for b in blocks):
            # insert after the previous mod of ours if present, else after the last entry
            anchor = blocks[-1]
            prev_uuids = [m["UUID"].lower() for m in metas[:i]]
            for b in blocks:
                if (attr(b.group(0), "UUID") or "").lower() in prev_uuids:
                    anchor = b
            node = anchor.group(0)
            for k, v in (("Folder", meta["Folder"]), ("Name", meta["Name"]), ("UUID", meta["UUID"]),
                         ("Version64", meta["Version64"]), ("MD5", ""), ("PublishHandle", "0")):
                node = set_attr(node, k, v)
            text = text[:anchor.end()] + node + text[anchor.end():]
            changes.append("Mods: added ModuleShortDesc %s (%s)" % (meta["Folder"], meta["UUID"]))
        else:
            # existing entry: keep its display Name in step with meta.lsx (e.g. "LootAdvisor" -> "Loot Advisor")
            for b in blocks:
                if (attr(b.group(0), "UUID") or "").lower() == uuid and attr(b.group(0), "Name") != meta["Name"]:
                    node = set_attr(b.group(0), "Name", meta["Name"])
                    text = text[:b.start()] + node + text[b.end():]
                    changes.append("Mods: renamed ModuleShortDesc %s to '%s'" % (meta["Folder"], meta["Name"]))
                    break
        # --- ModOrder / Module (only in files that have a ModOrder node)
        mo = re.search(r'<node id="ModOrder">\s*<children>(.*?)</children>', text, re.S)
        if mo:
            section_start = mo.start(1)
            mods = list(MODULE_RE.finditer(mo.group(1)))
            if not any((attr(m.group(0), "UUID") or "").lower() == uuid for m in mods):
                if mods:
                    anchor = mods[-1]
                    prev_uuids = [m["UUID"].lower() for m in metas[:i]]
                    for m in mods:
                        if (attr(m.group(0), "UUID") or "").lower() in prev_uuids:
                            anchor = m
                    node = set_attr(anchor.group(0), "UUID", meta["UUID"])
                    pos = section_start + anchor.end()
                else:
                    indent = re.search(r'\n([ \t]*)[^\n]*<node id="ModOrder">', text)
                    ind = (indent.group(1) if indent else "") + "        "
                    nl = "\r\n" if "\r\n" in text else "\n"
                    node = ('%s<node id="Module">%s%s    <attribute id="UUID" type="FixedString" value="%s"/>%s%s</node>%s'
                            % (ind, nl, ind, meta["UUID"], nl, ind, nl))
                    pos = section_start + len(mo.group(1).rstrip(" \t"))  # before the </children> indentation
                text = text[:pos] + node + text[pos:]
                changes.append("ModOrder: added Module %s (%s)" % (meta["Folder"], meta["UUID"]))
    return text, changes


def remove_from_modsettings(text, folder):
    """Drops the ModuleShortDesc / ModOrder Module entries of the mod with this Folder (matched by its UUID)."""
    uuid = None
    for b in SHORT_DESC_RE.finditer(text):
        if attr(b.group(0), "Folder") == folder:
            uuid = (attr(b.group(0), "UUID") or "").lower()
    if not uuid:
        return text, []
    changes = []
    for rx in (SHORT_DESC_RE, MODULE_RE):
        for b in list(rx.finditer(text))[::-1]:
            if (attr(b.group(0), "UUID") or "").lower() == uuid:
                text = text[:b.start()] + text[b.end():]
                changes.append("removed %s entry of %s" % ("Module" if rx is MODULE_RE else "ModuleShortDesc", folder))
    return text, changes


def game_running():
    try:
        out = subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    except OSError:
        return False
    return "bg3_dx11.exe" in out or "bg3.exe" in out


def main():
    args = sys.argv[1:]
    dry = "--dry-run" in args
    mods = MODS + [args[i + 1] for i, a in enumerate(args[:-1]) if a == "--extra"]
    removes = [args[i + 1] for i, a in enumerate(args[:-1]) if a == "--remove"]
    mods = [m for m in mods if m not in removes]
    if game_running():
        raise SystemExit("BG3 is running - quit it from its menu first (the paks are in use and the game rewrites "
                         "modsettings.lsx on exit).")
    metas = [read_meta(f) for f in mods]

    for f in mods:
        src = os.path.join(ROOT, "dist", f + ".pak")
        if not os.path.isfile(src):
            raise SystemExit("missing %s - run python tools/build_pak.py first" % src)
        dst = os.path.join(MODS_DIR, f + ".pak")
        print(("would copy" if dry else "copy") + " %s -> %s" % (src, dst))
        if not dry:
            os.makedirs(MODS_DIR, exist_ok=True)
            shutil.copyfile(src, dst)

    raw = open(MODSETTINGS, "rb").read()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    new, changes = patch_modsettings(text, metas)
    for f in removes:
        new, ch = remove_from_modsettings(new, f)
        changes += ch
        pak = os.path.join(MODS_DIR, f + ".pak")
        if os.path.isfile(pak):
            dst = os.path.join(ROOT, "dist", "disabled", f + ".pak")
            print(("would move" if dry else "move") + " %s -> %s" % (pak, dst))
            if not dry:
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                shutil.move(pak, dst)
    if not changes:
        print("modsettings.lsx already lists %s - unchanged" % ", ".join(mods))
        return
    for c in changes:
        print(("would change: " if dry else "modsettings.lsx: ") + c)
    if dry:
        return
    shutil.copyfile(MODSETTINGS, MODSETTINGS + ".bak")
    print("backup: %s.bak" % MODSETTINGS)
    with open(MODSETTINGS, "wb") as f:
        f.write((b"\xef\xbb\xbf" if bom else b"") + new.encode("utf-8"))
    print("wrote %s" % MODSETTINGS)


if __name__ == "__main__":
    main()
