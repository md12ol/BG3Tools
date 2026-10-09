"""Public text guard: public repos must not point at private or machine-local things.

What it flags (see PATTERNS): numbered references to private design notes, the private play-testing repo and the
private docs repo, assistant tooling and its working docs, local absolute paths, test-bot run names, and the names
of private saves / campaigns (kept here only as salted hashes, so the list itself reveals nothing). Normal words
("private", "session", "agent" in game text) are fine; only the specific patterns below match.

  python tools/public_text.py files [PATH ...]        tracked files of the current repo (default: all of them)
  python tools/public_text.py pr BASE HEAD            a pull request: PR_TITLE / PR_BODY (environment), every commit
                                                      message in BASE..HEAD and every file the range adds or changes
  python tools/public_text.py text < message.txt      any text on stdin (e.g. a commit message before committing)

Exit code 1 when anything matches. Extra names to hash can be listed one per line in the file named by the
PUBLIC_TEXT_NAMES environment variable (a local, untracked file).
"""
import hashlib
import os
import re
import subprocess
import sys

# (label, regex). Written so this file does not match itself (character classes break the literal words).
PATTERNS = [
    ("numbered design-note reference", r"\b[Dd]ecisions?[\s-]*#?\d+|\b[Dd]ec\.\s*\d+"),
    ("owner's decision wording", r"\b[Uu]ser(?:'s)?\s+(?:decisions?|choices?|chose|asked|approved|campaigns?)\b"
                                 r"|\b(?:approved|chosen|requested|asked)\s+by\s+the\s+user\b"),
    ("assistant tooling", r"[Cc][l]aude|BG3Mods-[c]laude"),
    ("private play-testing repo", r"(?i)\bau[t]opilot\b"),
    ("private working docs", r"(?i)\bhand-?o[f]fs?\b|\b(?:MOD|SHIP)_STA[T]US\b|RESEARCH_VERDIC[T]S|\bHELM_LO[G]\b"
                             r"|GENERAL_RUL[E]S|NAUTILOID_PLAYBOO[K]|\bPLA[N](?:\.md|\s+step)\b"
                             r"|\banalysis/[A-Z][A-Z0-9_]+\.md\b|_BEST_BUIL[D]\b"),
    ("assistant session / agent", r"\b[Ss]ession\s+\d+\b|\bmain\s+sessio[n]\b|\bsub-?agen[t]s?\b"
                                  r"|\b(?:extraction|mechanics|optimizer|packaging|research|shipped-page)\s+agen[t]s?\b"),
    ("local path", r"\b[A-Za-z]:[\\/]{1,2}User[s][\\/]|/[a-z]/User[s]/|\bDeskto[p][\\/]|AppData[\\/]Local[\\/]Tem[p]"),
    ("test-bot run", r"(?i)\bhelm[ _-]?(?:bot|attempts?)\b|\bhelmbo[t]\b|\battempts?\s+a\d{2,}\b"),
]
COMPILED = [(label, re.compile(rx)) for label, rx in PATTERNS]

# Matches that are fine anyway: (regex the matched text must equal, why). Keep this list short and explicit.
ALLOW = [
    (r"session 0", "Script Extender's own wording for the first load of a game session"),
]
ALLOW_RX = [re.compile(rx + r"\Z") for rx, _why in ALLOW]

# sha256("bg3pt:" + name)[:20] of private save / campaign / account names (lower case, words joined by one space)
SALT = "bg3pt:"
NAME_HASHES = {
    "7a3e495dd756a0323ce6", "704b628fef3cf495c6e0", "e4b512edf0f8251851c8", "421100c61440429aed36", "c591ce2298b13d627dd3",
}
WORD = re.compile(r"[a-z0-9]+")
BINARY_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".ico", ".pak", ".dds", ".glb", ".gr2", ".zip", ".exe",
              ".dll", ".mp4", ".wav", ".ttf", ".otf", ".woff", ".woff2", ".lsf", ".loca", ".bin"}


def name_hash(name):
    return hashlib.sha256((SALT + " ".join(WORD.findall(name.lower()))).encode()).hexdigest()[:20]


def load_names():
    hashes = set(NAME_HASHES)
    extra = os.environ.get("PUBLIC_TEXT_NAMES")
    if extra and os.path.isfile(extra):
        with open(extra, encoding="utf-8") as f:
            hashes |= {name_hash(line) for line in f if line.strip()}
    return hashes


def scan_text(text, where, names=None):
    """[(where, line_no, label, matched text)] for every hit in text."""
    names = load_names() if names is None else names
    hits = []
    for no, line in enumerate(text.splitlines(), 1):
        for label, rx in COMPILED:
            for m in rx.finditer(line):
                if not any(a.match(m.group(0)) for a in ALLOW_RX):
                    hits.append((where, no, label, m.group(0)))
        words = WORD.findall(line.lower())
        for n in (1, 2, 3):
            for i in range(len(words) - n + 1):
                if name_hash(" ".join(words[i:i + n])) in names:
                    hits.append((where, no, "private save / campaign name", "<name, %d word(s)>" % n))
    return hits


def read_text(path):
    if os.path.splitext(path)[1].lower() in BINARY_EXT:
        return None
    try:
        with open(path, "rb") as f:
            raw = f.read()
    except OSError:
        return None
    if b"\0" in raw[:8192]:
        return None
    return raw.decode("utf-8", errors="replace")


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True, encoding="utf-8").stdout


def scan_files(paths, names):
    hits = []
    for p in paths:
        text = read_text(p)
        if text is not None:
            hits += scan_text(text, p, names)
    return hits


def report(hits, what):
    for where, no, label, text in hits:
        print("%s:%d: %s: %r" % (where, no, label, text))
        if os.environ.get("GITHUB_ACTIONS") and os.path.exists(where):
            print("::error file=%s,line=%d::public text: %s (%s)" % (where, no, label, text))
    print("public text: %d hit(s) in %s" % (len(hits), what))
    return 1 if hits else 0


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    names = load_names()
    mode, args = argv[0], argv[1:]
    if mode == "files":
        paths = args or [p for p in git("ls-files", "-z").split("\0") if p]
        return report(scan_files(paths, names), "%d file(s)" % len(paths))
    if mode == "text":
        return report(scan_text(sys.stdin.read(), "<stdin>", names), "stdin")
    if mode == "pr" and len(args) == 2:
        base, head = args
        hits = []
        for key in ("PR_TITLE", "PR_BODY"):
            hits += scan_text(os.environ.get(key, ""), key, names)
        for sha in git("rev-list", "%s..%s" % (base, head)).split():
            hits += scan_text(git("log", "-1", "--format=%B", sha), "commit " + sha[:9], names)
        changed = [p for p in git("diff", "-z", "--name-only", "--diff-filter=ACMR", base + "..." + head).split("\0")
                   if p and os.path.isfile(p)]
        hits += scan_files(changed, names)
        return report(hits, "PR text, %s..%s commits and %d changed file(s)" % (base[:9], head[:9], len(changed)))
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
