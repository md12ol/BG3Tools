"""findrow.py SHOT TEMPLATE: find the save-list row matching TEMPLATE (a grey crop of the row's name text) in the
screenshot SHOT (2560x1600 capture of the 1389x868 frame). Prints the frame y of the row centre and the score, or
"none". Used by loadsave.sh instead of computing the row from the save folders (the game caches its list)."""
import sys
import numpy as np
from PIL import Image
S = 2560 / 1389
shot = np.asarray(Image.open(sys.argv[1]).convert("L")).astype(float)
tpl = np.asarray(Image.open(sys.argv[2]).convert("L")).astype(float)
th, tw = tpl.shape
x0 = int(118 * S)                      # left edge of the name text column
t = (tpl - tpl.mean()) / (tpl.std() + 1e-6)
best, by = -1, None
for y in range(int(150 * S), int(760 * S) - th):
    win = shot[y:y + th, x0:x0 + tw]
    w = (win - win.mean()) / (win.std() + 1e-6)
    sc = float((w * t).mean())
    if sc > best:
        best, by = sc, y
if best < 0.6:
    print("none %.2f" % best)
else:
    print("%d %.2f" % (round((by + th / 2) / S), best))
