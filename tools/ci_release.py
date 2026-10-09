"""CI and release checks for the public mods' player packages (<project>/dist/<Mod>/: pak, INSTALL.md, ...).

  python tools/ci_release.py check <Mod>                 build the pak (round trip verified) and the package into the
                                                         mod repo's dist/, zip it as dist/<Mod>-dev.zip and check the
                                                         zip both ways against INSTALL.md (every listed file is in it,
                                                         every file in it is named in INSTALL.md)
  python tools/ci_release.py stamp <Mod> <X.Y.Z>         write the version into the mod's meta.lsx (Version64)
  python tools/ci_release.py zip <Mod> <X.Y.Z> <pkg> <out>  zip the package folder <pkg> as <out>/<Mod>-<X.Y.Z>.zip
                                                         and check it against INSTALL.md the same way

Never touches the game or its folders. Paths come from build_pak.py (sibling repos under one parent folder).
"""
import os
import re
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pak  # noqa: E402

PUBLIC = build_pak.RELEASE


def listed_files(install_md):
    """Relative paths INSTALL.md says the folder holds: backticked names in the intro and in a section whose heading
    contains "in this folder"; bullets under a "`Dir/` holds:" line are inside Dir/. A name ending in / is a folder."""
    out = ["INSTALL.md"]
    section, prefix = "", ""
    for line in open(install_md, encoding="utf-8"):
        if line.startswith("## "):
            section, prefix = line[3:].strip().lower(), ""
            continue
        if line.startswith("# ") or (section and "in this folder" not in section):
            continue
        m = re.match(r"\s*`([^`]+/)`\s+holds:", line)
        if m:
            prefix = m.group(1)
            continue
        bullet = re.match(r"\s*- |\s{2,}\S", line)
        if not bullet:
            prefix = ""
        if line.lstrip().startswith("|"):
            cells = line.strip().strip("|").split("|")
            tokens = re.findall(r"`([^`]+)`", cells[0])
        else:
            tokens = re.findall(r"`([^`]+)`", line)
        for t in tokens:
            if "%" in t or ":" in t or " " in t or not (t.endswith("/") or re.search(r"\.\w+$", t)):
                continue
            out.append(prefix + t if bullet and prefix and "/" not in t else t)
    return list(dict.fromkeys(out))


def missing_in(names, present):
    """names: listed paths; present: set of relative file paths (forward slashes)."""
    miss = []
    for n in names:
        if n.endswith("/"):
            if not any(p.startswith(n) for p in present):
                miss.append(n)
        elif n not in present:
            miss.append(n)
    return miss


def folder_files(d):
    return {os.path.relpath(os.path.join(dp, f), d).replace("\\", "/") for dp, _, fs in os.walk(d) for f in fs}


def unlisted(present, install_md):
    """Files of the package that INSTALL.md does not name (by file name)."""
    text = open(install_md, encoding="utf-8").read()
    return sorted(p for p in present if os.path.basename(p) not in text)


def check_zip(path, install_md):
    """Number of problems: files INSTALL.md lists that the zip lacks, and files in the zip INSTALL.md does not name."""
    present = set(zipfile.ZipFile(path).namelist())
    names = listed_files(install_md)
    miss = missing_in(names, present)
    extra = unlisted(present, install_md)
    for m in miss:
        print("MISSING in %s: %s" % (os.path.basename(path), m))
    for e in extra:
        print("NOT IN INSTALL.md: %s (in %s)" % (e, os.path.basename(path)))
    print("%s: %d files, INSTALL.md lists %d entries, %d missing, %d not listed"
          % (path, len(present), len(names), len(miss), len(extra)))
    return len(miss) + len(extra)


def check(mod):
    import release_files
    out, files = build_pak.build(mod)
    build_pak.verify(out, files)
    print("%s: pak round trip verified (%d files)" % (mod, len(files)))
    d = release_files.release(mod, out)
    md = os.path.join(d, "INSTALL.md")
    if not os.path.isfile(md):
        print("MISSING: %s" % md)
        return 1
    print("%s: INSTALL.md lists %s" % (mod, ", ".join(listed_files(md))))
    return make_zip(mod, "dev", d, os.path.dirname(d))


def version64(ver):
    m = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?", ver)
    if not m:
        raise SystemExit("version must be X.Y.Z, got %r" % ver)
    major, minor, rev, build = (int(x or 0) for x in m.groups())
    # BG3 packs a version as major:9 bits | minor:8 | revision:16 | build:31 (LSLib PackedVersion)
    return (major << 55) | (minor << 47) | (rev << 31) | build


def stamp(mod, ver):
    meta = os.path.join(build_pak.mod_src(mod), "meta.lsx")
    s = open(meta, encoding="utf-8").read()
    v = version64(ver)
    s2, n = re.subn(r'(<attribute id="Version64" type="int64" value=")\d+(")', r"\g<1>%d\g<2>" % v, s)
    if n == 0:
        raise SystemExit("no Version64 attribute in %s" % meta)
    with open(meta, "w", encoding="utf-8", newline="") as f:
        f.write(s2)
    print("%s: Version64 = %d (%s) in %d place(s)" % (mod, v, ver, n))
    return 0


def make_zip(mod, ver, d, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "%s-%s.zip" % (mod, ver.lstrip("v")))
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in sorted(folder_files(d)):
            z.write(os.path.join(d, rel), rel)
    return check_zip(path, os.path.join(d, "INSTALL.md"))


if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == "check" and a[1] in PUBLIC:
        sys.exit(1 if check(a[1]) else 0)
    if len(a) == 3 and a[0] == "stamp":
        sys.exit(stamp(a[1], a[2]))
    if len(a) == 5 and a[0] == "zip":
        sys.exit(1 if make_zip(a[1], a[2], a[3], a[4]) else 0)
    raise SystemExit(__doc__)
