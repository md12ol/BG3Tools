"""Offline tests of testcampaign.py on synthetic save packages (no game, no real saves).

    python tools/testing/test_testcampaign.py        (needs pip install lz4 zstandard)
"""
import hashlib
import json
import os
import shutil
import struct
import sys
import tempfile
import unittest

import lz4.block
import lz4.frame

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import testcampaign as tc  # noqa: E402

ATTRS = [  # (name, type id, value) of the MetaData node, in a save's order
    ("Level", 22, "SCL_Main_A"), ("TimeStamp", 5, 4242), ("SaveGameID", 4, 7), ("GameSessionID", 22, "c" * 36),
    ("GameID", 22, "g" * 36), ("Modded", 19, False), ("LeaderName", 23, "Tester"), ("SaveGameType", 1, 1),
    ("SaveTime", 24, 1784838539),
]
CHILD_ATTRS = [("Modded", 4, 0), ("Slot", 2, 1)]   # a second node, with a name the MetaData node also uses


def _value(tid, v):
    if tid in tc._STRINGS:
        return v.encode("utf-8") + b"\0"
    return struct.pack(tc._SCALARS[tid], v)


def make_lsf(mformat=0, compressed=True):
    """An LSF v7 resource shaped like a save's meta.lsf: region MetaData > node MetaData (ATTRS) > node ClientData."""
    names = []

    def ref(n):
        if n not in names:
            names.append(n)
        return names.index(n)   # one bucket: (bucket 0 << 16) | index

    nodes = [("MetaData", -1, []), ("MetaData", 0, ATTRS), ("ClientData", 1, CHILD_ATTRS)]
    nb, ab, vb = bytearray(), bytearray(), bytearray()
    count = 0
    for i, (name, parent, attrs) in enumerate(nodes):
        first = count if attrs else -1
        for j, (an, tid, v) in enumerate(attrs):
            data = _value(tid, v)
            tl = tid | len(data) << 6
            if mformat == 1:
                ab += struct.pack("<IIiI", ref(an), tl, count + 1 if j + 1 < len(attrs) else -1, len(vb))
            else:
                ab += struct.pack("<IIi", ref(an), tl, i)
            vb += data
            count += 1
        sib = -1
        if mformat == 1:
            nb += struct.pack("<Iiii", ref(name), parent, sib, first)
        else:
            nb += struct.pack("<Iii", ref(name), first, parent)
    strings = struct.pack("<IH", 1, len(names)) + b"".join(struct.pack("<H", len(n)) + n.encode() for n in names)
    sections = [bytes(strings), bytes(nb), bytes(ab), bytes(vb), b""]
    cflags = 0x22 if compressed else 0
    disk = []
    for i, s in enumerate(sections):
        if not compressed or not s:
            disk.append((s, 0))
        else:
            d = lz4.block.compress(s, store_size=False) if i == 0 else lz4.frame.compress(s)
            disk.append((d, len(d)))
    (s, n, a, v, k) = zip(sections, disk)
    meta = struct.pack("<10IBBHI", len(s[0]), s[1][1], len(k[0]), k[1][1], len(n[0]), n[1][1], len(a[0]), a[1][1],
                       len(v[0]), v[1][1], cflags, 0, 0, mformat)
    return b"LSOF" + struct.pack("<Iq", 7, 145241087982699196) + meta + b"".join(d for _s, (d, _n) in
                                                                                   zip(sections, disk))


SAVEINFO = ('{\n   "Current Level" : "SCL_Main_A",\n   "Game Version" : "4.1.1.1",\n'
            '   "Save Name" : "QuickSave_7"\n}').encode("utf-8")


def make_save(root, folder, stem="QuickSave_7", mformat=0, compressed=True):
    """A save folder with an LSPK package whose file list order differs from its data order, like the game's."""
    plain = [("Globals.lsf", os.urandom(5000)), ("meta.lsf", make_lsf(mformat, compressed)),
             (stem + ".WebP", b"RIFF" + os.urandom(300)), ("SaveInfo.json", SAVEINFO),
             ("StorySave.bin", os.urandom(70000) * 2)]
    files = [(n, 0x23, tc._compress(0x23, d), d) for n, d in plain]
    path = os.path.join(root, folder)
    os.makedirs(path)
    tc.write_package(os.path.join(path, stem + ".lsv"), files, list_order=[2, 1, 4, 0, 3])
    with open(os.path.join(path, stem + ".WebP"), "wb") as f:
        f.write(b"RIFF outside")
    return path


def tree_digest(path):
    h = hashlib.md5()
    for f in sorted(os.listdir(path)):
        with open(os.path.join(path, f), "rb") as g:
            h.update(f.encode() + g.read())
    return h.hexdigest()


class TestCampaign(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.src = make_save(self.root, "Tester-1234__QuickSave_7")

    def tearDown(self):
        shutil.rmtree(self.root)

    def test_package_round_trip(self):
        p = tc.Package(tc.find_lsv(self.src))
        self.assertEqual([e.name for e in p.entries],
                         ["QuickSave_7.WebP", "meta.lsf", "StorySave.bin", "Globals.lsf", "SaveInfo.json"])
        self.assertEqual(p.md5, p.checksum())
        self.assertTrue(all((e.offset - tc.HEADER.size) % tc.ALIGN == 0 for e in p.entries))
        self.assertEqual(p.read(p.entry("SaveInfo.json")), SAVEINFO)

    def test_copy(self):
        before = tree_digest(self.src)
        dest = tc.copy_save(self.src, self.root, "Test Arena", "Act 2 end", now=1784838539)
        self.assertEqual(tree_digest(self.src), before, "the source changed")
        self.assertEqual(os.path.basename(dest), "Test Arena-282312620659__Act 2 end")
        self.assertEqual(sorted(os.listdir(dest)), ["Act 2 end.WebP", "Act 2 end.lsv"])
        old, new = tc.Package(tc.find_lsv(self.src)), tc.Package(os.path.join(dest, "Act 2 end.lsv"))
        self.assertEqual(new.md5, new.checksum())
        self.assertEqual([e.name for e in new.entries],
                         ["Act 2 end.WebP", "meta.lsf", "StorySave.bin", "Globals.lsf", "SaveInfo.json"])
        for name in ("Globals.lsf", "StorySave.bin"):
            self.assertEqual(new.raw(new.entry(name)), old.raw(old.entry(name)))
        self.assertEqual(new.read(new.entry("Act 2 end.WebP")), old.read(old.entry("QuickSave_7.WebP")))
        info = json.loads(new.read(new.entry("SaveInfo.json")))
        self.assertEqual(info["Save Name"], "Act 2 end")
        self.assertEqual(info["Current Level"], "SCL_Main_A")
        m = tc.read_meta(os.path.join(dest, "Act 2 end.lsv"))
        self.assertEqual(m["GameSessionID"], tc.campaign_id("Test Arena"))
        self.assertEqual(m["LeaderName"], "Test Arena")
        self.assertEqual((m["SaveTime"], m["SaveGameType"], m["SaveGameID"]), (1784838539, 0, -1))
        self.assertNotEqual(m["GameID"], "g" * 36)
        self.assertEqual(m["Level"], "SCL_Main_A")
        meta = tc.Lsf(new.read(new.entry("meta.lsf")))
        self.assertEqual([a[0] for a in meta.attrs], [a[0] for a in ATTRS + CHILD_ATTRS])
        self.assertEqual(meta.get("TimeStamp"), 4242)
        self.assertEqual(struct.unpack("<h", [a for a in meta.attrs if a[0] == "Slot"][0][2])[0], 1)

    def test_same_campaign_groups(self):
        a = tc.copy_save(self.src, self.root, "Test Arena", "one", now=1000000000)
        b = tc.copy_save(self.src, self.root, "Test Arena", "two", now=1000000001)
        c = tc.copy_save(self.src, self.root, "Other", "three", now=1000000002)
        ma, mb, mc = (tc.read_meta(tc.find_lsv(d)) for d in (a, b, c))
        self.assertEqual(ma["GameSessionID"], mb["GameSessionID"])
        self.assertNotEqual(ma["GameSessionID"], mc["GameSessionID"])
        self.assertNotEqual(ma["GameID"], mb["GameID"])
        groups = tc.campaigns(self.root)
        self.assertEqual(len(groups[tc.campaign_id("Test Arena")]["saves"]), 2)
        self.assertEqual(groups["c" * 36]["names"], {"Tester"})

    def test_keep_time(self):
        dest = tc.copy_save(self.src, self.root, "Test Arena", "kept", keep_time=True)
        self.assertEqual(tc.read_meta(tc.find_lsv(dest))["SaveTime"], 1784838539)
        self.assertIn("-282312620659__", dest)

    def test_extended_and_uncompressed_metadata(self):
        for i, (mformat, compressed) in enumerate(((1, True), (0, False), (1, False))):
            src = make_save(self.root, "Tester-%d__x" % i, "x", mformat, compressed)
            dest = tc.copy_save(src, self.root, "Test Arena", "v%d" % i, now=1000000000 + i)
            m = tc.read_meta(tc.find_lsv(dest))
            self.assertEqual((m["LeaderName"], m["SaveTime"], m["Level"]), ("Test Arena", 1000000000 + i, "SCL_Main_A"))

    def test_refusals(self):
        for campaign, name in (("Bad/Name", "ok"), ("ok", "a:b"), ("", "ok"), ("ok", "end."), ("a__b", "ok")):
            with self.assertRaises(ValueError):
                tc.copy_save(self.src, self.root, campaign, name)
        tc.copy_save(self.src, self.root, "Test Arena", "dup", now=1000000000)
        with self.assertRaises(ValueError):
            tc.copy_save(self.src, self.root, "Test Arena", "dup", now=1000000000)
        lsv = tc.find_lsv(self.src)
        with open(lsv, "r+b") as f:
            f.seek(22)
            f.write(b"\0" * 16)
        with self.assertRaises(ValueError):
            tc.copy_save(self.src, self.root, "Test Arena", "damaged", now=1000000005)
        self.assertFalse(any("damaged" in d for d in os.listdir(self.root)))

    def test_folder_number(self):
        self.assertEqual(tc.folder_number(1784838539), "282312620659")   # 2026-07-23 20:28:59 UTC


if __name__ == "__main__":
    unittest.main()
