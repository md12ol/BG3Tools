"""Packs each mod folder under Mods/ into its own pak (Larian LSPK v18, the BG3 format):
    Mods/BuildAdvisor -> dist/BuildAdvisor.pak   (the build advisor)
    Mods/LootAdvisor  -> dist/LootAdvisor.pak    (best items per selected origin character: frames, markers, list)
Inside each pak the files keep their project paths (Mods/<Folder>/meta.lsx, Mods/<Folder>/ScriptExtender/...).

No dependencies: LZ4 blocks are written as literal-only sequences, which every LZ4 decoder accepts.
Run:  python tools/build_pak.py              (builds both)
      python tools/build_pak.py LootAdvisor  (builds only the named mod(s); any <repo>/Mods/<Mod> next to this repo)
More mods for the no-argument build: BG3_EXTRA_MODS=ModA,ModB (each found as <repo>/Mods/<Mod> next to this repo).
Output goes to dist/ (+ the install folder <project>/<Mod>/ of the public mods, see RELEASE / release_files.py) and
into the build archive builds/<Mod>/ (tools/builds.py: list, restore an older build); install with tools/install_mods.py.
(If the game or your mod manager rejects the pak, pack the Mods folder with LSLib/Divine or
BG3 Modder's Multitool instead - see README.)
"""
import os
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # this BG3Tools checkout (dist/ is here)
DESKTOP = os.path.dirname(ROOT)   # the folder that holds the side-by-side repos
EXTRA = [m for m in os.environ.get("BG3_EXTRA_MODS", "").split(",") if m.strip()]
MODS = ["BuildAdvisor", "LootAdvisor"] + [m.strip() for m in EXTRA]  # folder under Mods/ == pak name in dist/
# every mod lives in its own repo next to this one, as <project>/Mods/<Folder>/...
PROJECT = {"BuildAdvisor": "BuildAdvisor", "LootAdvisor": "LootAdvisor"}


def mod_src(mod):
    """Source folder of a mod: <project>/Mods/<mod> next to this repo (a mod missing from PROJECT is searched in
    every sibling folder, its own name first)."""
    projects = [PROJECT[mod]] if mod in PROJECT else [mod]
    siblings = sorted(d for d in os.listdir(DESKTOP) if os.path.isdir(os.path.join(DESKTOP, d)))
    projects += [p for p in dict.fromkeys(list(PROJECT.values()) + siblings) if p not in projects]
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


# Public mods ship an install folder at the repo root (<project>/<Mod>/: the pak, INSTALL.md, Handbook.html, Media/,
# and for Loot Advisor Page/), refreshed on every build so it never goes stale; see release_files.py.
# Mods/<Mod> stays the source.
RELEASE = ("BuildAdvisor", "LootAdvisor")


def release(mod, out):
    """Copy a freshly built pak (+ handbook, page, media) into its repo's install folder; returns the folder or None."""
    if mod not in RELEASE:
        return None
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import release_files
    return release_files.release(mod, out)


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
            print("Refreshed install folder %s" % rel)
        if not os.environ.get("CI"):   # local builds are archived (tools/builds.py); CI runners are throwaway
            import builds
            print("Archived to %s" % builds.archive(mod, out, os.path.dirname(rel) if rel else None))
        for name, data in files:
            print("  %-70s %6d" % (name, len(data)))
    sys.exit(0)
