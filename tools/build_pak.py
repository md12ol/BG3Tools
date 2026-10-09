"""Packs each mod folder under Mods/ into its own pak (Larian LSPK v18, the BG3 format):
    Mods/BuildAdvisor -> dist/BuildAdvisor.pak   (the build advisor)
    Mods/Autopilot    -> dist/Autopilot.pak      (automated play-testing tools, separate mod)
    Mods/LootAdvisor  -> dist/LootAdvisor.pak    (best items per selected origin character: frames, markers, list)
Inside each pak the files keep their project paths (Mods/<Folder>/meta.lsx, Mods/<Folder>/ScriptExtender/...).

No dependencies: LZ4 blocks are written as literal-only sequences, which every LZ4 decoder accepts.
Run:  python tools/build_pak.py              (builds both)
      python tools/build_pak.py Autopilot    (builds only the named mod(s))
Output goes to dist/ (+ a copy in <project>/<Mod>/ for the public mods, see RELEASE); install with
tools/install_mods.py.
(If the game or your mod manager rejects the pak, pack the Mods folder with LSLib/Divine or
BG3 Modder's Multitool instead - see README.)
"""
import os
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # Desktop/BG3Mods/BG3Tools (dist/ is here)
DESKTOP = os.path.dirname(ROOT)
MODS = ["BuildAdvisor", "Autopilot", "LootAdvisor"]  # folder under Mods/ == pak name in dist/
# Restructure 2026-10: every mod lives in its own Desktop project folder as <project>/Mods/<Folder>/...
PROJECT = {"BuildAdvisor": "BuildAdvisor", "Autopilot": "Autopilot", "LootAdvisor": "LootAdvisor",
           "LootAdvisorSpike": "LootAdvisor"}


def mod_src(mod):
    """Source folder of a mod: Desktop/<project>/Mods/<mod> (a mod missing from PROJECT is searched in all)."""
    projects = [PROJECT[mod]] if mod in PROJECT else []
    projects += [p for p in dict.fromkeys(PROJECT.values()) if p not in projects]
    for p in projects:
        src = os.path.join(DESKTOP, p, "Mods", mod)
        if os.path.isfile(os.path.join(src, "meta.lsx")):
            return src
    return os.path.join(DESKTOP, projects[0], "Mods", mod)

SIGNATURE = b"LSPK"
VERSION = 18
ENTRY_SIZE = 272
FLAG_LZ4_DEFAULT = 0x02 | 0x40  # CompressionMethod.LZ4 | MaxCompress (same as the game's own paks)


def lz4_literal_block(data: bytes) -> bytes:
    n = len(data)
    out = bytearray()
    out.append(min(n, 15) << 4)
    if n >= 15:
        rem = n - 15
        while rem >= 255:
            out.append(255)
            rem -= 255
        out.append(rem)
    out += data
    return bytes(out)


def lz4_decode(src: bytes, size: int) -> bytes:
    out, i = bytearray(), 0
    while i < len(src):
        tok = src[i]; i += 1
        lit = tok >> 4
        if lit == 15:
            while True:
                b = src[i]; i += 1; lit += b
                if b != 255: break
        out += src[i:i + lit]; i += lit
        if i >= len(src): break
        off = src[i] | (src[i + 1] << 8); i += 2
        ml = tok & 15
        if ml == 15:
            while True:
                b = src[i]; i += 1; ml += b
                if b != 255: break
        ml += 4
        for _ in range(ml): out.append(out[-off])
    assert len(out) == size, (len(out), size)
    return bytes(out)


# developer notes kept next to a mod's files (e.g. Mods/BuildAdvisor/HIGHLIGHT_STATUS.md) never ship
SKIP_EXT = (".md",)


def collect(src):
    files = []
    for dirpath, _, names in os.walk(src):
        for n in sorted(names):
            if n.lower().endswith(SKIP_EXT):
                continue
            full = os.path.join(dirpath, n)
            rel = os.path.relpath(full, os.path.dirname(os.path.dirname(src))).replace("\\", "/")  # Mods/<Folder>/...
            files.append((rel, open(full, "rb").read()))
    return sorted(files)


def build(mod):
    src = mod_src(mod)
    if not os.path.isfile(os.path.join(src, "meta.lsx")):
        raise SystemExit("missing %s" % os.path.join(src, "meta.lsx"))
    out = os.path.join(ROOT, "dist", mod + ".pak")
    files = collect(src)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    header_size = 4 + struct.calcsize("<IQIBB16sH")
    with open(out, "wb") as f:
        f.write(b"\0" * header_size)
        entries = []
        for name, data in files:
            pad = (-f.tell()) % 64
            f.write(b"\0" * pad)
            offset = f.tell()
            comp = lz4_literal_block(data)
            f.write(comp)
            nb = name.encode("utf-8")
            assert len(nb) < 256, name
            entries.append(struct.pack("<256sIHBBII", nb, offset & 0xFFFFFFFF, offset >> 32, 0,
                                       FLAG_LZ4_DEFAULT, len(comp), len(data)))
        list_raw = b"".join(entries)
        list_comp = lz4_literal_block(list_raw)
        list_offset = f.tell()
        f.write(struct.pack("<II", len(files), len(list_comp)))
        f.write(list_comp)
        list_size = f.tell() - list_offset
        f.seek(0)
        f.write(SIGNATURE)
        f.write(struct.pack("<IQIBB16sH", VERSION, list_offset, list_size, 0, 0, b"\0" * 16, 1))
    return out, files


# Public mods ship their built pak in an install folder at the repo root (<project>/<Mod>/<Mod>.pak, next to
# INSTALL.md), refreshed on every build so it never goes stale. Mods/<Mod> stays the source.
RELEASE = ("BuildAdvisor", "LootAdvisor")


def release(mod, out):
    """Copy a freshly built pak into its repo's install folder; returns the path, or None for mods without one."""
    if mod not in RELEASE:
        return None
    dst_dir = os.path.join(DESKTOP, PROJECT[mod], mod)
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, mod + ".pak")
    shutil.copyfile(out, dst)
    return dst


def verify(out, expected):
    blob = open(out, "rb").read()
    assert blob[:4] == SIGNATURE
    ver, lo, ls, _, _, _, parts = struct.unpack_from("<IQIBB16sH", blob, 4)
    assert ver == VERSION and parts == 1
    n, csize = struct.unpack_from("<II", blob, lo)
    assert ls == 8 + csize
    raw = lz4_decode(blob[lo + 8: lo + 8 + csize], n * ENTRY_SIZE)
    got = {}
    for i in range(n):
        name, o1, o2, part, flags, disk, size = struct.unpack_from("<256sIHBBII", raw, i * ENTRY_SIZE)
        off = o1 | (o2 << 32)
        got[name.rstrip(b"\0").decode()] = lz4_decode(blob[off:off + disk], size)
    assert got == dict(expected), "round-trip mismatch"
    return n


if __name__ == "__main__":
    for mod in sys.argv[1:] or MODS:
        out, files = build(mod)
        n = verify(out, files)
        print("Wrote %s (%d files, %d bytes) - round-trip verified" % (out, n, os.path.getsize(out)))
        rel = release(mod, out)
        if rel:
            print("Copied to install folder %s" % rel)
        for name, data in files:
            print("  %-70s %6d" % (name, len(data)))
    sys.exit(0)
