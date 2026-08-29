# wake_check.py — เทียบเสียงกับแม่แบบ "เฮ้ คอด" ของผู้ใช้ (MFCC + DTW) รันในเครื่อง ไม่ใช้เน็ต
#   daemon: อ่าน path wav จาก stdin ทีละบรรทัด พิมพ์คะแนนระยะห่าง (ต่ำ = เหมือน), 9999 = ใช้ไม่ได้
#   --calib: คำนวณ threshold จากระยะห่างระหว่างแม่แบบกันเอง
import glob
import os
import sys
import wave

import numpy as np
from python_speech_features import mfcc

WDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wake")


def feats(path):
    w = wave.open(path)
    d = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32)
    sr = w.getframerate()
    w.close()
    # ตัดหัวท้ายที่เงียบออก เหลือแต่ช่วงพูด
    e = np.abs(d)
    thr = max(300.0, e.max() * 0.12)
    idx = np.where(e > thr)[0]
    if len(idx) < sr // 20:  # สั้นกว่า 50ms = ไม่มีเสียงพูด
        return None
    pad = sr // 20
    d = d[max(0, idx[0] - pad) : idx[-1] + pad]
    m = mfcc(d, sr, numcep=13, nfft=2048)
    return (m - m.mean(0)) / (m.std(0) + 1e-9)


def dtw(a, b):
    n, m = len(a), len(b)
    D = np.full((n + 1, m + 1), np.inf)
    D[0, 0] = 0.0
    for i in range(1, n + 1):
        c = np.linalg.norm(b - a[i - 1], axis=1)
        row, prev = D[i], D[i - 1]
        for j in range(1, m + 1):
            row[j] = c[j - 1] + min(prev[j], row[j - 1], prev[j - 1])
    return D[n, m] / (n + m)


def templates():
    ts = []
    for f in sorted(glob.glob(os.path.join(WDIR, "wake*.wav"))):
        m = feats(f)
        if m is not None:
            ts.append(m)
    return ts


if "--calib" in sys.argv:
    ts = templates()
    if len(ts) < 2:
        print("ERR: need >=2 templates")
        sys.exit(1)
    ds = [dtw(ts[i], ts[j]) for i in range(len(ts)) for j in range(i + 1, len(ts))]
    # ponytail: threshold = ระยะไกลสุดระหว่างแม่แบบ x1.35 — ถ้าปลุกยาก/มั่ว ปรับตัวเลขใน wake\threshold.txt ตรง ๆ
    print(round(max(ds) * 1.35, 3))
    sys.exit(0)

TS = templates()
MAXLEN = max(len(t) for t in TS) * 2.5 if TS else 0

for line in sys.stdin:
    p = line.strip()
    if not p:
        print(flush=True)
        continue
    try:
        m = feats(p)
        if m is None or not TS or len(m) > MAXLEN:  # ยาวเกิน = ประโยคพูด ไม่ใช่คำปลุก
            print("9999", flush=True)
            continue
        print(round(min(dtw(m, t) for t in TS), 3), flush=True)
    except Exception:
        print("9999", flush=True)
