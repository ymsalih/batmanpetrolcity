"""Render çıktılarını oyunun kullanacağı biçime getirir (assets/game/):
kırpılmış sprite sayfaları (WebP), saha arka planları ve 512 px'lik
harita karoları (JPEG), hepsi tek bir manifest.json ile."""
import json
import math
import os
import re

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'out')
SP = os.path.join(SRC, 'sprites')
DST = os.path.join(HERE, '..', '..', 'assets', 'game')
TILE = 512
BG = (34, 28, 23)  # harita dışı: koyu toprak tonu

# Oyundaki ekip rolleri ve baret renkleri (lib/config/game_config.dart ile aynı)
ROLES = {
    'muhendis': 0xFFFFFF, 'sondor': 0xF5C542, 'derikmen': 0xE0E0E0, 'jeolog': 0x3D8BC9, 'pompaci': 0xF07A2A,
    'mekanik': 0x3FAE5A, 'sofor': 0x8E5BC2, 'tuccar': 0x2B2622, 'isci': 0xD64541,
}

manifest = {}


def load(p):
    return np.asarray(Image.open(p).convert('RGBA')).astype(np.float32) / 255


def feather(a, frac=0.06):
    """Gölgeler kare kenarında keskin kesilmesin: kenarlara doğru şeffaflaştır."""
    h, w = a.shape[:2]
    fy, fx = max(2, int(h * frac)), max(2, int(w * frac))
    ry = np.clip(np.minimum(np.arange(h), h - 1 - np.arange(h)) / fy, 0, 1)
    rx = np.clip(np.minimum(np.arange(w), w - 1 - np.arange(w)) / fx, 0, 1)
    m = np.outer(ry * ry * (3 - 2 * ry), rx * rx * (3 - 2 * rx))
    a = a.copy()
    a[..., 3] *= m
    return a


def bbox(arrs, thr=0.02):
    m = np.zeros(arrs[0].shape[:2], bool)
    for a in arrs:
        m |= a[..., 3] > thr
    ys, xs = np.where(m)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def save_webp(arr, path, q=90):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')
    img.save(path, 'WEBP', quality=q, method=6)
    return os.path.getsize(path)


def sheet(frames, cols):
    h, w = frames[0].shape[:2]
    rows = math.ceil(len(frames) / cols)
    out = np.zeros((rows * h, cols * w, 4), np.float32)
    for i, f in enumerate(frames):
        r, c = divmod(i, cols)
        out[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    return out


def shift(p, box):
    return [round(p[0] - box[0], 1), round(p[1] - box[1], 1)]


def pack_frames(name, files, cols, meta, extra_points=(), q=90):
    frames = [feather(load(f)) for f in files]
    box = bbox(frames)
    frames = [f[box[1]:box[3], box[0]:box[2]] for f in frames]
    size = save_webp(sheet(frames, cols), os.path.join(DST, 'sprites', f'{name}.webp'), q)
    entry = {
        'file': f'sprites/{name}.webp', 'frame': [box[2] - box[0], box[3] - box[1]], 'cols': cols,
        'count': len(frames), 'pxPerM': meta['pxPerM'], 'anchor': shift(meta['anchor'], box),
    }
    for k in extra_points:
        entry[k] = shift(meta[k], box)
    manifest[name] = entry
    print(f'{name}: {entry["frame"]} x{len(frames)}  {size // 1024} KB')
    return box


def pack_single(name, path, meta, extra_points=(), q=90):
    a = feather(load(path))
    box = bbox([a])
    a = a[box[1]:box[3], box[0]:box[2]]
    size = save_webp(a, os.path.join(DST, 'sprites', f'{name}.webp'), q)
    entry = {'file': f'sprites/{name}.webp', 'frame': [box[2] - box[0], box[3] - box[1]], 'cols': 1, 'count': 1,
             'pxPerM': meta['pxPerM'], 'anchor': shift(meta['anchor'], box)}
    for k in extra_points:
        entry[k] = shift(meta[k], box)
    manifest[name] = entry
    print(f'{name}: {entry["frame"]}  {size // 1024} KB')
    return box


def meta(name):
    with open(os.path.join(SP, name, 'meta.json')) as f:
        return json.load(f)


def pack_sprites():
    m = meta('pumpjack')
    pack_frames('pumpjack', [os.path.join(SP, 'pumpjack', f'f{i:02d}.png') for i in range(m['frames'])], 6, m,
                ['wellhead'])
    m = meta('derrick')
    box = pack_single('derrick', os.path.join(SP, 'derrick', 'base.png'), m, ['monkeyboard', 'floor', 'vdoor'])
    blocks = [load(os.path.join(SP, 'derrick', f'block{i:02d}.png')) for i in range(m['blockFrames'])]
    bb = bbox(blocks)
    blocks = [b[bb[1]:bb[3], bb[0]:bb[2]] for b in blocks]
    size = save_webp(sheet(blocks, 6), os.path.join(DST, 'sprites', 'derrick_block.webp'))
    manifest['derrick_block'] = {'file': 'sprites/derrick_block.webp', 'frame': [bb[2] - bb[0], bb[3] - bb[1]],
                                 'cols': 6, 'count': len(blocks), 'pxPerM': m['pxPerM'],
                                 # Gövde sprite'ına göre konum (sol üst köşe)
                                 'offset': [bb[0] - box[0], bb[1] - box[1]]}
    print(f'derrick_block: {manifest["derrick_block"]["frame"]} x{len(blocks)}  {size // 1024} KB')
    for v in ('tanker', 'minibus'):
        m = meta(v)
        pack_frames(v, [os.path.join(SP, v, f'd{i:02d}.png') for i in range(m['dirs'])], 4, m)
        manifest[v].update({'dirs': m['dirs'], 'dir0': m['dir0'], 'order': m['order']})
    # İşçiler: rol başına baret rengi boyanmış sayfa
    m = meta('worker')
    n = m['walkFrames'] + 1
    files = [(d, f) for d in range(m['dirs']) for f in range(n)]
    base = [load(os.path.join(SP, 'worker', f'base_d{d}_f{f}.png')) for d, f in files]
    mask = [load(os.path.join(SP, 'worker', f'mask_d{d}_f{f}.png')) for d, f in files]
    box = bbox(base)
    for role, hexc in ROLES.items():
        tint = np.array([(hexc >> 16) & 255, (hexc >> 8) & 255, hexc & 255], np.float32) / 255
        tint_lin = tint ** 2.2
        frames = []
        for b, k in zip(base, mask):
            mk = np.clip(k[..., 3] * k[..., :3].max(-1), 0, 1)[..., None]
            out = b.copy()
            # Beyaz baretin ışığını koru, rengi role göre çarp
            # Beyaz baretin gölgelemesini koru, rengi role göre çarp (lineer ışıkta)
            shade = b[..., :3] ** 2.2
            out[..., :3] = b[..., :3] * (1 - mk) + ((shade * (0.06 + 0.94 * tint_lin)) ** (1 / 2.2)) * mk
            frames.append(out[box[1]:box[3], box[0]:box[2]])
        size = save_webp(sheet(frames, n), os.path.join(DST, 'sprites', f'worker_{role}.webp'))
    manifest['worker'] = {'file': 'sprites/worker_{role}.webp', 'frame': [box[2] - box[0], box[3] - box[1]],
                          'cols': n, 'rows': m['dirs'], 'walkFrames': m['walkFrames'], 'idleFrame': m['idleFrame'],
                          'pxPerM': m['pxPerM'], 'anchor': shift(m['anchor'], box), 'dir0': m['dir0'],
                          'order': m['order'], 'roles': list(ROLES)}
    print(f'worker x{len(ROLES)}: {manifest["worker"]["frame"]}  {size // 1024} KB/rol')
    for f in ('refinery', 'depot', 'camp'):
        pack_single(f, os.path.join(SP, f, 'base.png'), meta(f))


def pack_sites():
    d = os.path.join(SP, 'site')
    manifest['sites'] = {}
    for fn in sorted(os.listdir(d)):
        mm = re.match(r'(\w+)\.json$', fn)
        if not mm:
            continue
        key = mm.group(1)
        with open(os.path.join(d, fn)) as f:
            m = json.load(f)
        img = Image.open(os.path.join(d, f'{key}.png')).convert('RGB')
        path = os.path.join(DST, 'sites', f'{key}.jpg')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path, 'JPEG', quality=84, optimize=True, progressive=True)
        m['file'] = f'sites/{key}.jpg'
        manifest['sites'][key] = m
        print(f'site {key}: {m["size"]}  {os.path.getsize(path) // 1024} KB')


def pack_world():
    src = Image.open(os.path.join(SRC, 'world.png')).convert('RGBA')
    bg = Image.new('RGBA', src.size, (*BG, 255))
    bg.alpha_composite(src)
    img = bg.convert('RGB')
    W, H = img.size
    tdir = os.path.join(DST, 'world')
    os.makedirs(tdir, exist_ok=True)
    total = 0
    for ty in range(math.ceil(H / TILE)):
        for tx in range(math.ceil(W / TILE)):
            t = img.crop((tx * TILE, ty * TILE, min(W, (tx + 1) * TILE), min(H, (ty + 1) * TILE)))
            p = os.path.join(tdir, f't_{tx}_{ty}.jpg')
            t.save(p, 'JPEG', quality=80, optimize=True, progressive=True)
            total += os.path.getsize(p)
    lo = img.resize((1536, round(1536 * H / W)), Image.LANCZOS)
    lo.save(os.path.join(tdir, 'overview.jpg'), 'JPEG', quality=82, optimize=True)
    with open(os.path.join(SRC, 'world.json')) as f:
        w = json.load(f)
    w.update({'tile': TILE, 'cols': math.ceil(W / TILE), 'rows': math.ceil(H / TILE),
              'tilePattern': 'world/t_{x}_{y}.jpg', 'overview': 'world/overview.jpg', 'background': list(BG)})
    manifest['world'] = w
    print(f'world: {W}x{H}, {w["cols"]}x{w["rows"]} karo, {total // 1024} KB')


if __name__ == '__main__':
    import sys
    parts = sys.argv[1:] or ['world', 'sprites', 'sites']
    mf = os.path.join(DST, 'manifest.json')
    if os.path.exists(mf):
        with open(mf) as f:
            manifest.update(json.load(f))
    if 'world' in parts:
        pack_world()
    if 'sprites' in parts:
        pack_sprites()
    if 'sites' in parts:
        pack_sites()
    os.makedirs(DST, exist_ok=True)
    with open(mf, 'w') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)
    print('manifest:', mf)
