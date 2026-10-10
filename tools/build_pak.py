"""Packs each mod into its own pak (Larian LSPK v18, the BG3 format):
    <project>/BuildAdvisor/{Mods,Public,Localization} -> BuildAdvisor/dist/BuildAdvisor.pak   (the build advisor)
    <project>/LootAdvisor/{Mods,Public,Localization}  -> LootAdvisor/dist/LootAdvisor.pak     (best items per origin)
A mod's source sits in its repo as <Mod>/Mods/<Mod>/meta.lsx (+ <Mod>/Public, <Mod>/Localization when it has them),
the layout of other BG3 mod repositories. Inside the pak the files keep their paths below <Mod>/ (Mods/<Mod>/meta.lsx,
Mods/<Mod>/ScriptExtender/...). A mod still in the older layout <project>/Mods/<Mod> is found too (only Mods/<Mod> is
packed then).

No dependencies: LZ4 blocks are written as literal-only sequences, which every LZ4 decoder accepts.
Run:  python tools/build_pak.py              (builds both)
      python tools/build_pak.py LootAdvisor  (builds only the named mod(s), from any repo next to this one)
More mods for the no-argument build: BG3_EXTRA_MODS=ModA,ModB (each found in a repo next to this one).
Output goes to the mod repo's dist/ (gitignored): dist/<Mod>.pak and, for the public mods, the player package
dist/<Mod>/ (pak, INSTALL.md, Handbook.html, Media/, Loot Advisor's Page/; see release_files.py). Local builds are also
archived to builds/<Mod>/ here (tools/builds.py: list, restore an older build); install with tools/install_mods.py.
(If the game or your mod manager rejects the pak, pack the mod folder with LSLib/Divine or
BG3 Modder's Multitool instead - see README.)
"""
import os
import shutil
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # this BG3Tools checkout (builds/ is here)
DESKTOP = os.path.dirname(ROOT)   # the folder that holds the side-by-side repos
EXTRA = [m for m in os.environ.get("BG3_EXTRA_MODS", "").split(",") if m.strip()]
MODS = ["BuildAdvisor", "LootAdvisor"] + [m.strip() for m in EXTRA]  # folder under Mods/ == pak name in dist/
# every mod lives in its own repo next to this one
PROJECT = {"BuildAdvisor": "BuildAdvisor", "LootAdvisor": "LootAdvisor"}
# the top-level folders of a mod project that go into the pak
GAME_DIRS = ("Mods", "Public", "Localization")


def locate(mod):
    """(project folder, mod root, legacy) of a mod. The mod root holds Mods/<mod>/meta.lsx: <project>/<mod>/, or
    <project>/ itself in the older layout (legacy=True). A mod missing from PROJECT is searched in every sibling
    folder, its own name first."""
    projects = [PROJECT[mod]] if mod in PROJECT else [mod]
    siblings = sorted(d for d in os.listdir(DESKTOP) if os.path.isdir(os.path.join(DESKTOP, d)))
    projects += [p for p in dict.fromkeys(list(PROJECT.values()) + siblings) if p not in projects]
    for p in projects:
        proj = os.path.join(DESKTOP, p)
        for root, legacy in ((os.path.join(proj, mod), False), (proj, True)):
            if os.path.isfile(os.path.join(root, "Mods", mod, "meta.lsx")):
                return proj, root, legacy
    proj = os.path.join(DESKTOP, projects[0])
    return proj, os.path.join(proj, mod), False


def mod_src(mod):
    """The mod's Mods/<mod> folder (meta.lsx, ScriptExtender/, ...)."""
    return os.path.join(locate(mod)[1], "Mods", mod)


def dist_dir(mod):
    """Where builds of this mod go: dist/ in its own repo (gitignored)."""
    return os.path.join(locate(mod)[0], "dist")

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


def collect(mod):
    """(path in the pak, bytes) of every file the pak holds, sorted by path."""
    _, root, legacy = locate(mod)
    tops = [os.path.join(root, "Mods", mod)] if legacy else [os.path.join(root, d) for d in GAME_DIRS]
    files = []
    for top in tops:
        for dirpath, _, names in os.walk(top):
            for n in sorted(names):
                if n.lower().endswith(SKIP_EXT):
                    continue
                full = os.path.join(dirpath, n)
                rel = os.path.relpath(full, root).replace("\\", "/")   # Mods/<mod>/..., Public/<mod>/...
                files.append((rel, open(full, "rb").read()))
    return sorted(files)


def build(mod):
    src = mod_src(mod)
    if not os.path.isfile(os.path.join(src, "meta.lsx")):
        raise SystemExit("missing %s" % os.path.join(src, "meta.lsx"))
    out = os.path.join(dist_dir(mod), mod + ".pak")
    files = collect(mod)
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


# Public mods get a player package next to the pak (dist/<Mod>/: the pak, INSTALL.md, Handbook.html, Media/, and for
# Loot Advisor Page/), rebuilt on every build; CI zips the same folder for a release. See release_files.py.
RELEASE = ("BuildAdvisor", "LootAdvisor")


def release(mod, out):
    """Assemble the player package of a public mod around a freshly built pak; returns the folder or None."""
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
            print("Player package %s" % rel)
        if not os.environ.get("CI"):   # local builds are archived (tools/builds.py); CI runners are throwaway
            import builds
            print("Archived to %s" % builds.archive(mod, out, rel))
        for name, data in files:
            print("  %-70s %6d" % (name, len(data)))
    sys.exit(0)
