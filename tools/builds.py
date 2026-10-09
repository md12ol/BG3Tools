"""Local build archive: every pak build_pak.py makes is kept, so an older build can be put back into the game.

  builds/<Mod>/<YYYY-MM-DD_HHMM>_<sha>[-dirty]/   dev builds (pak + package zip); the newest KEEP_DEV are kept
  builds/<Mod>/releases/<X.Y.Z>/                  a build of a clean commit tagged vX.Y.Z; kept forever

<sha> is the short HEAD of the mod's repository; -dirty means it had uncommitted changes. builds/ is gitignored.
dist/<Mod>.pak stays the current build that install_mods.py copies into the game.

  python tools/builds.py list [Mod]            list archived builds, newest first
  python tools/builds.py restore <Mod> <id>    copy that build's pak to dist/ and install it (install_mods.py);
                                               <id> = a dev folder name (or a unique prefix) or a release version
"""
import datetime
import os
import shutil
import subprocess
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_pak  # noqa: E402

BUILDS = os.path.join(build_pak.ROOT, "builds")
KEEP_DEV = 30


def _git(repo, *args):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else ""


def archive(mod, pak, package_dir=None):
    """Keep a copy of a fresh build; returns the archive folder."""
    repo = os.path.join(build_pak.DESKTOP, build_pak.PROJECT.get(mod, mod))
    sha = _git(repo, "rev-parse", "--short", "HEAD") or "nogit"
    dirty = bool(_git(repo, "status", "--porcelain", "--untracked-files=no"))
    tag = _git(repo, "describe", "--exact-match", "--tags", "--match", "v[0-9]*", "HEAD")
    if tag and not dirty:
        dst = os.path.join(BUILDS, mod, "releases", tag.lstrip("v"))
    else:
        stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M")
        dst = os.path.join(BUILDS, mod, "%s_%s%s" % (stamp, sha, "-dirty" if dirty else ""))
    os.makedirs(dst, exist_ok=True)
    shutil.copyfile(pak, os.path.join(dst, mod + ".pak"))
    if package_dir and os.path.isdir(package_dir):
        with zipfile.ZipFile(os.path.join(dst, "%s-%s.zip" % (mod, os.path.basename(dst))), "w",
                             zipfile.ZIP_DEFLATED) as z:
            for dp, _, fs in os.walk(package_dir):
                for f in fs:
                    z.write(os.path.join(dp, f), os.path.relpath(os.path.join(dp, f), package_dir))
    prune(mod)
    return dst


def dev_builds(mod):
    d = os.path.join(BUILDS, mod)
    if not os.path.isdir(d):
        return []
    return sorted((n for n in os.listdir(d) if n != "releases" and os.path.isdir(os.path.join(d, n))), reverse=True)


def releases(mod):
    d = os.path.join(BUILDS, mod, "releases")
    return sorted(os.listdir(d), reverse=True) if os.path.isdir(d) else []


def prune(mod):
    for old in dev_builds(mod)[KEEP_DEV:]:
        shutil.rmtree(os.path.join(BUILDS, mod, old), ignore_errors=True)


def mods():
    return sorted(os.listdir(BUILDS)) if os.path.isdir(BUILDS) else []


def list_builds(only=None):
    for mod in [only] if only else mods():
        print(mod)
        for v in releases(mod):
            print("  release  %s" % v)
        for n in dev_builds(mod):
            print("  dev      %s" % n)


def resolve(mod, ident):
    if ident.lstrip("v") in releases(mod):
        return os.path.join(BUILDS, mod, "releases", ident.lstrip("v"))
    hits = [n for n in dev_builds(mod) if n.startswith(ident)]
    if len(hits) != 1:
        raise SystemExit("%s: %d builds match %r (python tools/builds.py list %s)" % (mod, len(hits), ident, mod))
    return os.path.join(BUILDS, mod, hits[0])


def restore(mod, ident):
    src = os.path.join(resolve(mod, ident), mod + ".pak")
    dist = os.path.join(build_pak.ROOT, "dist", mod + ".pak")
    os.makedirs(os.path.dirname(dist), exist_ok=True)
    shutil.copyfile(src, dist)
    print("dist/%s.pak <- %s" % (mod, os.path.relpath(src, build_pak.ROOT)))
    return subprocess.call([sys.executable, os.path.join(build_pak.ROOT, "tools", "install_mods.py")])


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "list" and len(a) <= 2:
        list_builds(a[1] if len(a) == 2 else None)
    elif len(a) == 3 and a[0] == "restore":
        sys.exit(restore(a[1], a[2]))
    else:
        raise SystemExit(__doc__)
