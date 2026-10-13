"""Copy Baldur's Gate 3 saves into a separate test campaign, so the Load Game list shows them under their own entry.

  python tools/testing/testcampaign.py list [--root DIR]
        every campaign in the save folder: name, campaign id, number of saves, newest save
  python tools/testing/testcampaign.py copy SRC --campaign "Test Arena" --name "Act 2 end" [--root DIR] [--keep-time]
        copy the save folder SRC into a new save of campaign "Test Arena" (a folder name below the save folder or a path)
  python tools/testing/testcampaign.py verify LSV
        check a .lsv package: file list, checksum, metadata

The game groups saves by the campaign id in each save's metadata, not by folder, and names the campaign after the
party leader written next to it. `copy` writes a new save folder whose package carries:
  - campaign id   derived from the campaign name, so every copy into the same campaign joins the same entry;
  - leader name   the campaign name (the Load list shows it as the campaign's title);
  - game id       new and random for each copy;
  - save type     a manual save named --name (the package, its screenshot and SaveInfo.json all use that name);
  - save time     now (newest in the campaign), or the source's with --keep-time.
Everything else (the world, the story, the party) is copied byte for byte. The source folder is only read.
--root defaults to the game's Story save folder; the game must be closed or at the main menu to see a new save
(it reads the folder when the Load Game list opens).

Save package format (LSPK version 18): 40-byte header (magic, version, file list offset and size, flags, priority,
checksum, part count), file data from offset 40 with each file starting a multiple of 64 bytes after it (gaps filled
with 0xAD), then the file list (count, compressed size, LZ4 block of 272-byte entries). The checksum is the MD5 of
every file's uncompressed contents in the order they sit in the package, each byte of the digest plus one.
The metadata is meta.lsf (LSF version 7) in the package; its node MetaData holds GameSessionID (the campaign id),
GameID, LeaderName, SaveTime, SaveGameType (0 manual, 1 quick, 2 auto) and SaveGameID (-1 for manual saves).
Needs the lz4 and zstandard packages (pip install lz4 zstandard).
"""
import argparse
import hashlib
import json
import os
import re
import struct
import sys
import time
import uuid
import zlib

import lz4.block
import lz4.frame
import zstandard

STORY = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Larian Studios", "Baldur's Gate 3", "PlayerProfiles",
                     "Public", "Savegames", "Story")
# campaign ids are uuid5(CAMPAIGN_NS, campaign name): the same name always gives the same campaign
CAMPAIGN_NS = uuid.UUID("5b0a6f4e-3c1d-4e8a-9f27-6d2b1c0e7a41")
HEADER = struct.Struct("<4sIQIBB16sH")   # magic, version, list offset, list size, flags, priority, md5, parts
ENTRY = struct.Struct("<256sIHBBII")     # name, offset low/high, part, flags, size on disk, size
ALIGN = 64
PAD = b"\xad"
BAD_NAME = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


# ------------------------------------------------------------------------------------------------ LSPK packages
class Entry:
    def __init__(self, name, offset, flags, size_on_disk, size):
        self.name, self.offset, self.flags = name, offset, flags
        self.size_on_disk, self.size = size_on_disk, size


def _decompress(flags, data, size):
    method = flags & 0x0F
    if method == 0 or not data:
        return data
    if method == 1:
        return zlib.decompress(data)
    if method == 2:
        try:
            return lz4.block.decompress(data, uncompressed_size=size)
        except lz4.block.LZ4BlockError:
            return lz4.frame.decompress(data)
    if method == 3:
        return zstandard.ZstdDecompressor().decompress(data, max_output_size=max(size, 1))
    raise ValueError("unknown compression method %d" % method)


def _compress(flags, data):
    method = flags & 0x0F
    if method == 0:
        return data
    if method == 1:
        return zlib.compress(data)
    if method == 2:
        return lz4.block.compress(data, store_size=False)
    if method == 3:
        return zstandard.ZstdCompressor().compress(data)
    raise ValueError("unknown compression method %d" % method)


class Package:
    """An LSPK v18 package read whole into memory (saves are tens of MB)."""

    def __init__(self, path):
        with open(path, "rb") as f:
            self.blob = f.read()
        magic, ver, lo, ls, self.flags, self.priority, self.md5, parts = HEADER.unpack_from(self.blob, 0)
        if magic != b"LSPK" or ver != 18:
            raise ValueError("%s: not an LSPK version 18 package" % path)
        if parts != 1:
            raise ValueError("%s: packages split in %d parts are not supported" % (path, parts))
        count, csize = struct.unpack_from("<II", self.blob, lo)
        raw = lz4.block.decompress(self.blob[lo + 8:lo + 8 + csize], uncompressed_size=count * ENTRY.size)
        self.entries = []
        for i in range(count):
            name, off1, off2, _part, flags, sod, size = ENTRY.unpack_from(raw, i * ENTRY.size)
            self.entries.append(Entry(name.split(b"\0", 1)[0].decode("utf-8"), off1 | off2 << 32, flags, sod, size))
        self.list_end = lo + ls

    def raw(self, e):
        return self.blob[e.offset:e.offset + e.size_on_disk]

    def read(self, e):
        return _decompress(e.flags, self.raw(e), e.size)

    def entry(self, name):
        for e in self.entries:
            if e.name == name:
                return e
        raise KeyError(name)

    def checksum(self):
        """The header checksum this package's contents should carry."""
        h = hashlib.md5()
        for e in sorted(self.entries, key=lambda x: x.offset):
            h.update(self.read(e))
        return bytes((b + 1) & 0xFF for b in h.digest())


def write_package(path, files, flags=0, priority=0, list_order=None):
    """files: [(name, entry flags, stored bytes, uncompressed bytes)] in data order. list_order: indices into files
    in the order the file list names them (default: data order); the game's saves list files in another order."""
    out = bytearray(HEADER.size)
    md5 = hashlib.md5()
    rows = []
    for name, eflags, stored, plain in files:
        out += PAD * (-(len(out) - HEADER.size) % ALIGN)
        off = len(out)
        out += stored
        md5.update(plain)
        size = len(plain) if eflags & 0x0F else 0
        rows.append(ENTRY.pack(name.encode("utf-8"), off & 0xFFFFFFFF, off >> 32, 0, eflags, len(stored), size))
    out += PAD * (-(len(out) - HEADER.size) % ALIGN)
    lo = len(out)
    table = b"".join(rows[i] for i in (range(len(rows)) if list_order is None else list_order))
    packed = lz4.block.compress(table, store_size=False)
    out += struct.pack("<II", len(files), len(packed)) + packed
    digest = bytes((b + 1) & 0xFF for b in md5.digest())
    HEADER.pack_into(out, 0, b"LSPK", 18, lo, len(out) - lo, flags, priority, digest, 1)
    with open(path, "xb") as f:
        f.write(out)


# ------------------------------------------------------------------------------------------------ meta.lsf
_STRINGS = {20, 21, 22, 23, 29, 30}
_SCALARS = {1: "<B", 2: "<h", 3: "<H", 4: "<i", 5: "<I", 6: "<f", 7: "<d", 19: "<?", 24: "<Q", 26: "<q", 27: "<b",
            32: "<q"}


def _section(blob, off, usize, dsize, cflags, chunked):
    if dsize == 0:
        return blob[off:off + usize], off + usize
    raw = blob[off:off + dsize]
    method = cflags & 0x0F
    if method == 2:
        data = lz4.frame.decompress(raw) if chunked else lz4.block.decompress(raw, uncompressed_size=usize)
    else:
        data = _decompress(cflags, raw, usize)
    return data, off + dsize


def _pack_section(data, cflags, chunked):
    """(bytes on disk, size on disk field) of one section, compressed like the source file."""
    method = cflags & 0x0F
    if method == 0 or not data:
        return data, 0
    if method == 2:
        disk = lz4.frame.compress(data) if chunked else lz4.block.compress(data, store_size=False)
    else:
        disk = _compress(cflags, data)
    return disk, len(disk)


class Lsf:
    """Just enough of an LSF v6/v7 resource to read and rewrite the scalar and string attributes of meta.lsf."""
    META = struct.Struct("<10IBBHI")

    def __init__(self, blob):
        if blob[:4] != b"LSOF":
            raise ValueError("meta.lsf is not an LSF resource")
        self.version, self.engine = struct.unpack_from("<Iq", blob, 4)
        if self.version not in (6, 7):
            raise ValueError("LSF version %d is not supported" % self.version)
        m = self.META.unpack_from(blob, 16)
        (s_u, s_d, k_u, k_d, n_u, n_d, a_u, a_d, v_u, v_d, self.cflags, self.u2, self.u3, self.mformat) = m
        off = 16 + self.META.size
        sections = []
        for usize, dsize, chunked in ((s_u, s_d, False), (n_u, n_d, True), (a_u, a_d, True), (v_u, v_d, True),
                                      (k_u, k_d, True)):
            start = off
            data, off = _section(blob, off, usize, dsize, self.cflags, chunked)
            sections.append((data, blob[start:off], dsize))
        self.sections = sections
        names = []
        strings = sections[0][0]
        (buckets,) = struct.unpack_from("<I", strings, 0)
        pos = 4
        for _ in range(buckets):
            (cnt,) = struct.unpack_from("<H", strings, pos)
            pos += 2
            chain = []
            for _ in range(cnt):
                (ln,) = struct.unpack_from("<H", strings, pos)
                chain.append(strings[pos + 2:pos + 2 + ln].decode("utf-8"))
                pos += 2 + ln
            names.append(chain)
        attrs, values = sections[2][0], sections[3][0]
        self.attrs = []   # [name, type id, value bytes, extra] in attribute order
        if self.mformat == 1:
            for h, tl, nxt, voff in struct.iter_unpack("<IIiI", attrs):
                self.attrs.append([names[h >> 16][h & 0xFFFF], tl & 0x3F, values[voff:voff + (tl >> 6)], (h, nxt)])
        else:
            voff = 0
            for h, tl, node in struct.iter_unpack("<IIi", attrs):
                ln = tl >> 6
                self.attrs.append([names[h >> 16][h & 0xFFFF], tl & 0x3F, values[voff:voff + ln], (h, node)])
                voff += ln

    def _find(self, name):
        found = [a for a in self.attrs if a[0] == name]
        if len(found) != 1:
            raise ValueError("meta.lsf has %d attributes named %s, expected one" % (len(found), name))
        return found[0]

    def get(self, name):
        _n, tid, data, _x = self._find(name)
        if tid in _STRINGS:
            return data.split(b"\0", 1)[0].decode("utf-8")
        if tid in _SCALARS:
            return struct.unpack(_SCALARS[tid], data)[0]
        raise ValueError("%s: attribute type %d is not readable here" % (name, tid))

    def values(self, names):
        out = {}
        for n in names:
            try:
                out[n] = self.get(n)
            except ValueError:
                out[n] = None
        return out

    def set(self, name, value):
        a = self._find(name)
        tid = a[1]
        if tid in _STRINGS:
            a[2] = str(value).encode("utf-8") + b"\0"
        elif tid in _SCALARS:
            a[2] = struct.pack(_SCALARS[tid], value)
        else:
            raise ValueError("%s: attribute type %d is not writable here" % (name, tid))

    def dump(self):
        attrs, values = bytearray(), bytearray()
        for _name, tid, data, (h, x) in self.attrs:
            tl = tid | len(data) << 6
            attrs += struct.pack("<IIiI", h, tl, x, len(values)) if self.mformat == 1 else struct.pack("<IIi", h, tl, x)
            values += data
        parts = []
        for i, (data, disk, dsize) in enumerate(self.sections):
            if i in (2, 3):
                data = bytes(attrs if i == 2 else values)
                disk, dsize = _pack_section(data, self.cflags, True)
            parts.append((data, disk, dsize))
        (s, n, a, v, k) = parts
        meta = self.META.pack(len(s[0]), s[2], len(k[0]), k[2], len(n[0]), n[2], len(a[0]), a[2], len(v[0]), v[2],
                              self.cflags, self.u2, self.u3, self.mformat)
        return b"LSOF" + struct.pack("<Iq", self.version, self.engine) + meta + s[1] + n[1] + a[1] + v[1] + k[1]


# ------------------------------------------------------------------------------------------------ saves
def campaign_id(name):
    return str(uuid.uuid5(CAMPAIGN_NS, name))


def folder_number(t):
    """The number in a save folder's name the way the game makes it: minute, day, year-1900, hour, month-1, second
    of the UTC save time, without padding. The game does not read it back; it only keeps folder names unique."""
    g = time.gmtime(t)
    return "%d%d%d%d%d%d" % (g.tm_min, g.tm_mday, g.tm_year - 1900, g.tm_hour, g.tm_mon - 1, g.tm_sec)


def find_lsv(folder):
    lsv = [f for f in os.listdir(folder) if f.lower().endswith(".lsv")]
    if len(lsv) != 1:
        raise ValueError("%s: expected one .lsv, found %d" % (folder, len(lsv)))
    return os.path.join(folder, lsv[0])


def read_meta(lsv):
    p = Package(lsv)
    return Lsf(p.read(p.entry("meta.lsf"))).values(
        ["GameSessionID", "GameID", "LeaderName", "SaveTime", "SaveGameType", "SaveGameID", "Level"])


def copy_save(src, root, campaign, name, keep_time=False, now=None):
    """Writes the copy and returns its folder. src is only read."""
    for label, text in (("campaign", campaign), ("name", name)):
        if not text.strip() or BAD_NAME.search(text) or text != text.strip() or text.endswith("."):
            raise ValueError("--%s %r is not usable in a file name" % (label, text))
    if "__" in campaign:
        raise ValueError("--campaign may not contain '__' (it separates the folder name's parts)")
    src_lsv = find_lsv(src)
    pkg = Package(src_lsv)
    if pkg.md5 != pkg.checksum():
        raise ValueError("%s: checksum does not match its contents; not copying a damaged save" % src_lsv)
    old_stem = os.path.splitext(os.path.basename(src_lsv))[0]
    meta = Lsf(pkg.read(pkg.entry("meta.lsf")))
    t = meta.get("SaveTime") if keep_time else int(now if now is not None else time.time())
    meta.set("GameSessionID", campaign_id(campaign))
    meta.set("GameID", str(uuid.uuid4()))
    meta.set("LeaderName", campaign)
    meta.set("SaveTime", t)
    meta.set("SaveGameType", 0)
    meta.set("SaveGameID", -1)
    files = []
    data_order = sorted(pkg.entries, key=lambda x: x.offset)
    for e in data_order:
        ename = e.name
        if e.name == "meta.lsf":
            plain = meta.dump()
        elif e.name == "SaveInfo.json":
            text = pkg.read(e).decode("utf-8")
            text, n = re.subn(r'("Save Name"\s*:\s*)"(?:[^"\\]|\\.)*"',
                              lambda m: m.group(1) + json.dumps(name, ensure_ascii=False), text)
            if n != 1:
                raise ValueError("SaveInfo.json: no single \"Save Name\" field")
            plain = text.encode("utf-8")
        else:
            if e.name == old_stem + ".WebP":
                ename = name + ".WebP"
            files.append((ename, e.flags, pkg.raw(e), pkg.read(e)))
            continue
        files.append((ename, e.flags, _compress(e.flags, plain), plain))
    list_order = [data_order.index(e) for e in pkg.entries]
    dest = os.path.join(root, "%s-%s__%s" % (campaign, folder_number(t), name))
    if os.path.exists(dest):
        raise ValueError("%s already exists" % dest)
    os.makedirs(dest)
    try:
        lsv = os.path.join(dest, name + ".lsv")
        write_package(lsv, files, pkg.flags, pkg.priority, list_order)
        webp = os.path.join(src, old_stem + ".WebP")
        if os.path.isfile(webp):
            with open(webp, "rb") as f, open(os.path.join(dest, name + ".WebP"), "xb") as g:
                g.write(f.read())
        os.utime(lsv, (t, t))
    except BaseException:
        for f in os.listdir(dest):
            os.remove(os.path.join(dest, f))
        os.rmdir(dest)
        raise
    return dest


def campaigns(root):
    groups = {}
    for d in sorted(os.listdir(root)):
        folder = os.path.join(root, d)
        if not os.path.isdir(folder):
            continue
        try:
            m = read_meta(find_lsv(folder))
        except (ValueError, KeyError, OSError, struct.error) as ex:
            print("skipped %s: %s" % (d, ex), file=sys.stderr)
            continue
        g = groups.setdefault(m["GameSessionID"], {"names": set(), "saves": []})
        g["names"].add(m["LeaderName"])
        g["saves"].append((m["SaveTime"] or 0, d, m["Level"]))
    return groups


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("list", help="campaigns in the save folder")
    p.add_argument("--root", default=STORY)
    p = sub.add_parser("copy", help="copy a save into a test campaign")
    p.add_argument("src")
    p.add_argument("--campaign", required=True)
    p.add_argument("--name", required=True)
    p.add_argument("--root", default=STORY, help="save folder to write into (default: the game's Story folder)")
    p.add_argument("--keep-time", action="store_true", help="keep the source's save time instead of now")
    p = sub.add_parser("verify", help="check a .lsv package")
    p.add_argument("lsv")
    a = ap.parse_args(argv)
    if a.cmd == "list":
        groups = campaigns(a.root)
        rows = sorted(groups.items(), key=lambda kv: -max(s[0] for s in kv[1]["saves"]))
        for cid, g in rows:
            newest = max(g["saves"])
            print("%-30s %s  %3d saves  newest %s  %s" % (" / ".join(sorted(n or "?" for n in g["names"])), cid,
                  len(g["saves"]), time.strftime("%Y-%m-%d %H:%M", time.localtime(newest[0])), newest[1]))
        return 0
    if a.cmd == "copy":
        src = a.src if os.path.isdir(a.src) else os.path.join(a.root, a.src)
        if not os.path.isdir(src):
            print("no save folder %s" % a.src, file=sys.stderr)
            return 1
        dest = copy_save(src, a.root, a.campaign, a.name, keep_time=a.keep_time)
        print("wrote %s (campaign id %s)" % (dest, campaign_id(a.campaign)))
        return 0
    pkg = Package(a.lsv)
    ok = pkg.md5 == pkg.checksum()
    for e in pkg.entries:
        print("%10d  %#04x  %s" % (e.size or e.size_on_disk, e.flags, e.name))
    print("checksum %s" % ("ok" if ok else "WRONG (header %s, contents %s)" % (pkg.md5.hex(), pkg.checksum().hex())))
    print(json.dumps(read_meta(a.lsv), indent=1))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
