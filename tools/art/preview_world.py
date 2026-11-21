"""Dünya haritası canlandırma önizlemesi: tesisler yerinde, tankerler gerçek
yollarda sahalardan rafineriye gidip gelir, kamera haritada gezinir."""
import json
import math
import os
import subprocess

import numpy as np
from PIL import Image

import preview as pv  # yardımcılar (sprite kesme, yön)

HERE = os.path.dirname(os.path.abspath(__file__))
A = pv.A
OUT = os.path.join(HERE, 'out', 'preview_world.mp4')
W, H, FPS, DUR = 720, 1280, 24, 16.0
man = pv.man
wm = man['world']
img = Image.open(os.path.join(A, 'world', 'overview.jpg'))  # yalnız boyut için
TILE = wm['tile']
full = Image.new('RGB', tuple(wm['size']))
for ty in range(wm['rows']):
    for tx in range(wm['cols']):
        full.paste(Image.open(os.path.join(A, wm['tilePattern'].format(x=tx, y=ty))), (tx * TILE, ty * TILE))
full = full.convert('RGBA')

_sc = {}


def sprite(name, scale, file=None, idx=0):
    key = (name, scale, file, idx)
    if key not in _sc:
        m = man[name]
        im = Image.open(os.path.join(A, file or m['file'])).convert('RGBA')
        fw, fh = m['frame']; r, c = divmod(idx, m['cols'])
        f = im.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
        _sc[key] = (f.resize((max(1, int(fw * scale)), max(1, int(fh * scale))), Image.LANCZOS),
                    np.array(m['anchor']) * scale)
    return _sc[key]


poi = {k: np.array(v['px'], float) for k, v in wm['poi'].items()}
roads = {(r['from'], r['to']): np.array(r['px'], float) for r in wm['roads']}


def route(*keys):
    pts = []
    for a, b in zip(keys, keys[1:]):
        seg = roads.get((a, b))
        seg = seg if seg is not None else roads[(b, a)][::-1]
        pts += list(seg if not pts else seg[1:])
    return np.array(pts)


truck_routes = [route('rafineri', 'bati_raman', 'raman'), route('rafineri', 'bati_raman'),
                route('rafineri', 'bati_raman', 'raman', 'garzan'), route('pazarlama', 'sehir', 'rafineri')]
bus_route = route('lojman', 'sehir', 'rafineri', 'bati_raman', 'raman')


def render_frame(t):
    path = [poi['lojman'] + [80, 120], poi['rafineri'] + [200, 60], poi['bati_raman'], poi['raman'], poi['garzan'] - [150, 0]]
    u = pv.ease(t / DUR) * (len(path) - 1)
    i = min(int(u), len(path) - 2)
    cc = path[i] + (path[i + 1] - path[i]) * pv.ease(u - i)
    cam = np.clip(cc - [W / 2, H / 2], [0, 0], [full.width - W, full.height - H])
    canvas = full.crop((int(cam[0]), int(cam[1]), int(cam[0]) + W, int(cam[1]) + H)).copy()
    items = []
    for name, key, sc in (('refinery', 'rafineri', 0.26), ('depot', 'pazarlama', 0.24), ('camp', 'lojman', 0.22)):
        im, anc = sprite(name, sc)
        items.append((poi[key][1], im, poi[key], anc))
    for s, key in enumerate(('bati_raman', 'raman', 'garzan')):
        n = len(man['pumpjack'] and range(man['pumpjack']['count']))
        for j, off in enumerate(((-38, -8), (30, -14), (-6, 22), (44, 18))):
            fr = int((t / 3.2 + j * 0.3 + s * 0.1) * n) % n
            im, anc = sprite('pumpjack', 0.32, idx=fr)
            p = poi[key] + off
            items.append((p[1], im, p, anc))
        im, anc = sprite('derrick', 0.16)
        p = poi[key] + (-70, 30)
        items.append((p[1], im, p, anc))
    for j, r in enumerate(truck_routes + [bus_route]):
        bus = j == len(truck_routes)
        period = 26.0 + j * 5
        ph = ((t + j * 7.3) / period) % 1.0
        k = ph * 2 if ph < 0.5 else (1 - ph) * 2   # git-gel
        pos, d = pv.path_pos(r, k)
        if ph >= 0.5:
            d = -d
        name = 'minibus' if bus else 'tanker'
        im, anc = sprite(name, 0.26 if bus else 0.2, idx=pv.dir_index(d, 16))
        items.append((pos[1], im, pos, anc))
    for _, im, p, anc in sorted(items, key=lambda x: x[0]):
        pv.draw(canvas, im, p, anc, cam)
    return canvas.convert('RGB')


if __name__ == '__main__':
    pv.W, pv.H = W, H
    pr = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                           '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '21',
                           '-movflags', '+faststart', OUT], stdin=subprocess.PIPE)
    for i in range(int(DUR * FPS)):
        pr.stdin.write(np.asarray(render_frame(i / FPS)).tobytes())
    pr.stdin.close(); pr.wait()
    render_frame(4.0).save(OUT.replace('.mp4', '.jpg'), quality=88)
    print('ok', OUT)
