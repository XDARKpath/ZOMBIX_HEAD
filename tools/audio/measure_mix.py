# Misura il mix registrato da tests/audio_mix.gd: volume e picco di ogni scena, stacchi e buchi nella musica.
#   blender -b -P tools/audio/measure_mix.py -- <mix.wav> <log del test>
import sys
import aud
import numpy as np

wav, log = sys.argv[sys.argv.index("--") + 1:][:2]
s = aud.Sound(wav)
rate = int(s.specs[0])
d = s.data()
x = d.mean(axis=1) if d.ndim > 1 else d
marks = []
for line in open(log, encoding="utf-8", errors="ignore"):
    p = line.split()
    if len(p) == 3 and p[0] == "T":
        marks.append((p[1], float(p[2])))
print("durata", round(x.size / rate, 1), "picco assoluto", round(float(np.abs(d).max()), 3), "campioni saturi", int((np.abs(d) >= 0.999).sum()))
for (name, a), (_, b) in zip(marks, marks[1:]):
    seg = x[int(a * rate): int(b * rate)]
    if seg.size == 0:
        continue
    win = max(1, int(rate * 0.05))
    n = seg.size // win
    env = np.sqrt((seg[: n * win].reshape(n, win) ** 2).mean(axis=1))
    print("%-30s rms %6.1f  max50ms %6.1f  picco %5.2f" % (name, 20 * np.log10(max(float(np.sqrt((seg ** 2).mean())), 1e-6)), 20 * np.log10(max(float(env.max()), 1e-6)), float(np.abs(seg).max())))
print("FINE")
