"""Paketlenmiş görsellerle saha canlandırma önizlemesi (MP4).

Minibüs işçileri lojmandan getirir, işçiler toplanma noktasında buluşur,
sonra sondaj kulesine yürür; at kafaları pompalar, kule bloğu iner çıkar.
Kullanım: python preview.py [saha] [çıktı.mp4]
"""
import json
import math
import os
import subprocess
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
A = os.path.join(HERE, '..', '..', 'assets', 'game')
SITE = sys.argv[1] if len(sys.argv) > 1 else 'raman'
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, 'out', f'preview_{SITE}.mp4')
W, H, FPS, DUR = 720, 1280, 24, 14.0
S = 2.0  # arka plan büyütmesi (oyundaki gibi): 20 px/m

man = json.load(open(os.path.join(A, 'manifest.json')))
site = man['sites'][SITE]
bg = Image.open(os.path.join(A, site['file'])).convert('RGBA')
bg = bg.resize((int(bg.width * S), int(bg.height * S)), Image.LANCZOS)
SCREEN_PX_PER_M = site['pxPerM'] * S

_cache = {}


def frames(name, file=None):
    if (name, file) in _cache:
        return _cache[(name, file)]
    m = man[name]
    img = Image.open(os.path.join(A, file or m['file'])).convert('RGBA')
    fw, fh = m['frame']
    k = SCREEN_PX_PER_M / m['pxPerM']
    out = []
    cols = m['cols']; count = m.get('count', cols * m.get('rows', 1))
    for i in range(count):
        r, c = divmod(i, cols)
        f = img.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
        out.append(f.resize((max(1, int(fw * k)), max(1, int(fh * k))), Image.LANCZOS))
    _cache[(name, file)] = (out, k)
    return out, k


def P(p):
    return np.array(p, float) * S


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def dir_index(v, n):
    # Ekran vektörü → dünya açısı (zemin derinliği ekranda sin45 ile kısalır)
    ang = math.atan2(-v[1] / math.sin(math.radians(45)), v[0])
    return int(round(ang / (2 * math.pi / n))) % n


def path_pos(pts, t):
    """Çoklu çizgi üzerinde 0..1 konum + yön vektörü."""
    seg = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
    L = sum(seg); d = t * L
    for i, s in enumerate(seg):
        if d <= s or i == len(seg) - 1:
            k = 0 if s == 0 else min(d / s, 1)
            return pts[i] + (pts[i + 1] - pts[i]) * k, pts[i + 1] - pts[i]
        d -= s


parcels = [P(p) for p in site['parcels']]
road_end, gate, meeting = P(site['roadEnd']), P(site['gate']), P(site['meeting'])
pumps = {0: 0.0, 2: 0.35, 3: 0.6, 5: 0.15, 6: 0.8, 8: 0.45}
rig = 4
bus_stop = meeting + np.array([-120, 40])
bus_path = [road_end + np.array([0, 120]), road_end, gate, bus_stop]
crew = ['sondor', 'derikmen', 'isci', 'muhendis', 'mekanik', 'isci']
circle = [meeting + np.array([math.cos(a) * 70, math.sin(a) * 36]) for a in np.linspace(0, 2 * math.pi, len(crew), endpoint=False)]
rig_anchor = parcels[rig]
dm = man['derrick']
vdoor = rig_anchor + (np.array(dm['vdoor']) - np.array(dm['anchor'])) * (SCREEN_PX_PER_M / dm['pxPerM'])
work_spots = [vdoor + np.array([(i - 2.5) * 26, 20 + (i % 2) * 18]) for i in range(len(crew))]


def draw(canvas, img, pos, anchor_scaled, cam):
    x = int(pos[0] - anchor_scaled[0] - cam[0]); y = int(pos[1] - anchor_scaled[1] - cam[1])
    if x > W or y > H or x + img.width < 0 or y + img.height < 0:
        return
    canvas.alpha_composite(img, (max(x, 0), max(y, 0)), (max(-x, 0), max(-y, 0)))


def render_frame(t):
    # Kamera: girişten pedin ortasına süzülür, sonra hafifçe kuleye yaklaşır
    c0 = gate + np.array([0, -200]); c1 = (parcels[4] + parcels[7]) / 2
    cam_c = c0 + (c1 - c0) * ease(t / 7.0)
    cam = cam_c - np.array([W / 2, H / 2])
    cam = np.clip(cam, [0, 0], [bg.width - W, bg.height - H])
    canvas = bg.crop((int(cam[0]), int(cam[1]), int(cam[0]) + W, int(cam[1]) + H)).copy()
    items = []  # (zemin_y, çizim)

    pj, k = frames('pumpjack')
    for i, ph in pumps.items():
        f = pj[int(((t / 3.2) + ph) * len(pj)) % len(pj)]
        items.append((parcels[i][1], f, parcels[i], np.array(man['pumpjack']['anchor']) * k))
    dimg, k = frames('derrick')
    items.append((rig_anchor[1], dimg[0], rig_anchor, np.array(dm['anchor']) * k))
    blk, kb = frames('derrick_block')
    bf = blk[int(t / 6.0 * len(blk)) % len(blk)]
    off = np.array(man['derrick_block']['offset']) * kb
    items.append((rig_anchor[1] + 0.5, bf, rig_anchor, np.array(dm['anchor']) * k - off))

    # Tanker: pedin sağ altında dolum bekliyor
    tk, k = frames('tanker')
    tpos = parcels[8] + np.array([120, 90])
    items.append((tpos[1], tk[8], tpos, np.array(man['tanker']['anchor']) * k))

    # Minibüs: yol boyunca gelir (0-4 sn), durur
    mb, k = frames('minibus')
    bt = ease(t / 4.0)
    bpos, bdir = path_pos(bus_path, bt)
    if t > 4.0:
        bdir = bus_path[-1] - bus_path[-2]
    items.append((bpos[1], mb[dir_index(bdir, 16)], bpos, np.array(man['minibus']['anchor']) * k))

    # İşçiler: 4.3 sn'de inerler, toplanırlar, 9 sn'de kuleye yürürler
    wm = man['worker']
    for i, role in enumerate(crew):
        t0 = 4.3 + i * 0.25
        if t < t0:
            continue
        sheet, k = frames('worker', f'sprites/worker_{role}.webp')
        start = bus_stop + np.array([30, 10])
        if t < 7.2:
            u = ease((t - t0) / (7.2 - t0)); a, b = start, circle[i]
        elif t < 9.0:
            u = 1.0; a, b = circle[i], circle[i]
        else:
            u = ease((t - 9.0) / 3.5); a, b = circle[i], work_spots[i]
        pos = a + (b - a) * u
        moving = 0 < u < 1 and np.linalg.norm(b - a) > 1
        v = (b - a) if moving else (meeting - pos if t < 9.0 else rig_anchor - pos)
        d8 = dir_index(v, 8)
        fr = int(t * 10) % wm['walkFrames'] if moving else wm['idleFrame']
        items.append((pos[1], sheet[d8 * wm['cols'] + fr], pos, np.array(wm['anchor']) * k))

    for _, img, pos, anc in sorted(items, key=lambda x: x[0]):
        draw(canvas, img, pos, anc, cam)
    return canvas.convert('RGB')


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    p = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                          '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20',
                          '-movflags', '+faststart', OUT], stdin=subprocess.PIPE)
    n = int(DUR * FPS)
    for i in range(n):
        p.stdin.write(np.asarray(render_frame(i / FPS)).tobytes())
    p.stdin.close(); p.wait()
    render_frame(10.5).save(OUT.replace('.mp4', '.jpg'), quality=88)
    print('ok', OUT)


if __name__ == '__main__':
    main()
