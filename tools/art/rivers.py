"""Ana nehirlerin yatağı: vadi tabanını izleyen en düşük maliyetli yol."""
import numpy as np
from scipy import ndimage
from skimage.graph import route_through_array

import geo


def _cost(z):
    # Vadi tabanında ucuz, yamaçta çok pahalı: yol nehir yatağını izler.
    zs = ndimage.gaussian_filter(z, 1.2)
    rel = zs - ndimage.minimum_filter(zs, size=31)
    return 1 + (rel / 4.0) ** 2


def lowest_near(z, lat, lon, radius_px):
    H, W = z.shape
    u, v = geo.latlon_to_uv(lat, lon)
    r, c = int(v * H), int(u * W)
    r0, r1 = max(0, r - radius_px), min(H, r + radius_px)
    c0, c1 = max(0, c - radius_px), min(W, c + radius_px)
    sub = ndimage.gaussian_filter(z, 1.5)[r0:r1, c0:c1]
    rr, cc = np.unravel_index(np.argmin(sub), sub.shape)
    return r0 + rr, c0 + cc


def trace_px(z, anchors):
    """[(satır, sütun)] çapalarından geçen vadi tabanı yolu (z2 ızgarası)."""
    cost = _cost(z)
    path = []
    for a, b in zip(anchors, anchors[1:]):
        seg, _ = route_through_array(cost, a, b, fully_connected=True, geometric=True)
        path += seg if not path else seg[1:]
    return np.array(path)


# Çapalar z2 ızgarasında (satır, sütun): her sütundaki vadi tabanı minimumu
# (bkz. analiz). Dicle batıdan (510 m) doğuya (465 m) akar; Batman Çayı
# kuzeydoğudan şehrin batısına iner ve Dicle'ye karışır.
RIVERS = {
    'dicle': [(383, 0), (400, 60), (388, 120), (422, 180), (423, 240), (449, 300), (479, 360),
              (459, 420), (459, 480), (483, 540), (482, 600), (493, 660), (491, 720), (464, 780),
              (465, 840), (473, 900), (503, 940)],
    'batman_cayi': [(0, 205), (56, 180), (123, 120), (177, 60), (249, 8), (383, 0)],
}

if __name__ == '__main__':
    from PIL import Image, ImageDraw
    z = geo.downsample(geo.load_region(), 2)
    np.save('.dem/z2.npy', z)
    H, W = z.shape
    dy, dx = np.gradient(z, 60.0)
    slope = np.pi / 2 - np.arctan(np.hypot(dx, dy)); aspect = np.arctan2(-dx, dy)
    hs = np.sin(.8) * np.sin(slope) + np.cos(.8) * np.cos(slope) * np.cos(np.radians(315) - aspect)
    img = Image.fromarray((np.clip(hs, 0, 1) * 220).astype(np.uint8)).convert('RGB')
    d = ImageDraw.Draw(img)
    paths = {}
    for name, pts in RIVERS.items():
        p = trace_px(z, pts)
        paths[name] = p
        d.line([(int(c), int(r)) for r, c in p], fill=(40, 140, 255), width=3)
    np.save('.dem/rivers.npy', paths, allow_pickle=True)
    u, v = geo.latlon_to_uv(37.887, 41.132)
    d.ellipse([u * W - 6, v * H - 6, u * W + 6, v * H + 6], outline='red', width=3)
    img.save('/tmp/claude-0/-home-user-batmanpetrolcity/743883a6-2533-551b-ac51-591747c80ce2/scratchpad/rivers.png')
    print(z.shape)
