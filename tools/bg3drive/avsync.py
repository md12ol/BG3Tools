"""avsync.py <mp4>: measure the audio/video offset of a recording from sharp events (e.g. opening/closing the inventory:
the panel appears in the picture and a UI sound plays in the same frame). Prints the video event times (mean-luma jumps),
the audio event times (RMS onsets) and, for each video event, the nearest audio event: audio - video < 0 = audio ahead."""
import os, re, subprocess, sys

FF = os.path.join(os.environ["LOCALAPPDATA"], "Microsoft", "WinGet", "Packages",
                  "Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe", "ffmpeg-9.0.2-full_build", "bin", "ffmpeg.exe")
src = sys.argv[1]


def meta(filt, key, audio=False):
    args = [FF, "-hide_banner", "-loglevel", "error", "-i", src, "-an" if not audio else "-vn",
            "-af" if audio else "-vf", filt, "-f", "null", "-"]
    out = subprocess.run(args, capture_output=True, text=True).stderr + subprocess.run(args, capture_output=True, text=True).stdout
    return out


def series(filt, key, audio):
    args = [FF, "-hide_banner", "-loglevel", "error", "-i", src, "-vn" if audio else "-an",
            "-af" if audio else "-vf", filt + ",%smetadata=print:key=%s:file=-" % ("a" if audio else "", key), "-f", "null", "-"]
    txt = subprocess.run(args, capture_output=True, text=True).stdout
    pts, out = None, []
    for line in txt.splitlines():
        m = re.search(r"pts_time:([\d.]+)", line)
        if m:
            pts = float(m.group(1))
            continue
        if key in line and pts is not None:
            v = line.split("=", 1)[1]
            try:
                out.append((pts, float(v)))
            except ValueError:
                out.append((pts, -120.0))
    return out


v = series("scale=64:40,signalstats", "lavfi.signalstats.YAVG", False)
# --beep (synctap.ps1 markers): narrow band-pass at 1 kHz so the game's own sound does not mask the beep; 5 ms blocks
beep = "--beep" in sys.argv
af = ("bandpass=f=1000:width_type=q:w=8,bandpass=f=1000:width_type=q:w=8," if beep else "") + "asetnsamples=240,astats=metadata=1:reset=1"
a = series(af, "lavfi.astats.Overall.RMS_level", True)
ve = []
for i in range(1, len(v)):
    if abs(v[i][1] - v[i - 1][1]) > (0.5 if beep else 3) and (not ve or v[i][0] - ve[-1] > 1.0):
        ve.append(v[i][0])
ae = []
for i in range(60, len(a)):
    base = sorted(x[1] for x in a[i - 60:i])[30]
    if a[i][1] - base > 15 and a[i][1] > -60 and (not ae or a[i][0] - ae[-1] > 1.0):
        ae.append(a[i][0])
print("frames %d, audio blocks %d" % (len(v), len(a)))
print("video events", [round(x, 2) for x in ve])
print("audio events", [round(x, 2) for x in ae])
for t in ve:
    if ae:
        n = min(ae, key=lambda x: abs(x - t))
        print("  video %.2f -> nearest audio %.2f (audio - video = %+.2f s)" % (t, n, n - t))
