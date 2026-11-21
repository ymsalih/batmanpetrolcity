"""Oyun dünyasının coğrafi verisi: önemli noktalar, yollar ve zemin dokusu."""
import numpy as np
from scipy import ndimage
from scipy.spatial import cKDTree
from skimage.graph import route_through_array

import geo
import rivers

# Dünya boyutu (km): boylam derecesi 37.85°K'de ~87.8 km, enlem ~111.2 km.
KM_X = (geo.LON_E - geo.LON_W) * 87.8
KM_Y = (geo.LAT_N - geo.LAT_S) * 111.2
EXAGGERATION = 3.2  # dikey abartı: rölyef oyunda okunur olsun

# Önemli noktalar: z2 ızgarasında (satır, sütun). Batman şehir merkezi gerçek
# koordinattan (37.887 K, 41.132 D); sahalar sırtlar üzerinde yaklaşık konumda.
def _px(lat, lon, H=504, W=1133):
    u, v = geo.latlon_to_uv(lat, lon)
    return int(v * H), int(u * W)


CITY = _px(37.887, 41.132)
POI = {
    'sehir': CITY,
    'rafineri': (CITY[0] + 14, CITY[1] + 36),    # şehrin doğu ucu
    'lojman': (CITY[0] - 26, CITY[1] + 6),       # işçi lojmanları (kuzey)
    'pazarlama': (CITY[0] + 22, CITY[1] - 30),   # akaryakıt dağıtım / alıcı (güneybatı)
    # Sahalar sırt tepelerinde (arazi analiziyle bulunan zirveler).
    'bati_raman': (187, 459),   # 980 m, 37.886 K 41.285 D
    'raman': (263, 581),        # 1002 m, 37.844 K 41.353 D
    'garzan': (214, 1033),      # 1233 m, 37.871 K 41.604 D
}
SITES = ['bati_raman', 'raman', 'garzan']

# Yol ağı: (başlangıç, bitiş, tür)
ROADS = [
    ('lojman', 'sehir', 'asfalt'),
    ('pazarlama', 'sehir', 'asfalt'),
    ('sehir', 'rafineri', 'asfalt'),
    ('rafineri', 'bati_raman', 'stabilize'),
    ('bati_raman', 'raman', 'stabilize'),
    ('raman', 'garzan', 'stabilize'),
]


def road_paths(z):
    """Eğimi az olan yerlerden geçen gerçekçi yollar (z2 ızgarası)."""
    zs = ndimage.gaussian_filter(z, 1.0)
    gy, gx = np.gradient(zs, 60.0)
    slope = np.hypot(gx, gy)
    water = river_mask(z.shape, width=1.5) > 0.5
    cost = 1 + (slope * 25) ** 2 + water * 200
    out = []
    for a, b, kind in ROADS:
        path, _ = route_through_array(cost, POI[a], POI[b], fully_connected=True, geometric=True)
        p = np.array(path, float)
        # Basamaklı ızgara yolunu yumuşat
        if len(p) > 7:
            p = ndimage.uniform_filter1d(p, 7, axis=0, mode='nearest')
        out.append((a, b, kind, p))
    return out


_RIVER_CACHE = {}


def river_paths(z):
    if 'p' not in _RIVER_CACHE:
        out = {}
        for k, v in rivers.RIVERS.items():
            p = np.array(rivers.trace_px(z, v), float)
            # Izgara basamaklarını yumuşat: doğal kıvrımlar
            p = ndimage.gaussian_filter1d(p, 3.0, axis=0, mode='nearest')
            out[k] = p
        _RIVER_CACHE['p'] = out
    return _RIVER_CACHE['p']


def river_mask(shape, width=1.0, scale=1.0, z=None):
    """Nehir yataklarının yumuşak maskesi (0..1), verilen çözünürlükte."""
    z = z if z is not None else np.load('.dem/z2.npy')
    m = np.zeros(shape, np.float32)
    for name, p in river_paths(z).items():
        w = width * (1.6 if name == 'dicle' else 0.9)
        q = np.array(p, float) * scale
        # Sık örnekle: dokuda kesintisiz çizgi
        q = np.concatenate([np.linspace(q[i], q[i + 1], max(2, int(np.hypot(*(q[i + 1] - q[i]))) + 1), endpoint=False)
                            for i in range(len(q) - 1)])
        pts = q.astype(int)
        pts[:, 0] = pts[:, 0].clip(0, shape[0] - 1); pts[:, 1] = pts[:, 1].clip(0, shape[1] - 1)
        mm = np.zeros(shape, bool); mm[pts[:, 0], pts[:, 1]] = True
        d = ndimage.distance_transform_edt(~mm)
        m = np.maximum(m, np.clip(1.5 - d / (w * scale), 0, 1))
    return m


def fbm(shape, seed, octaves=6, base=8):
    """Çok oktavlı değer gürültüsü (0..1)."""
    rng = np.random.default_rng(seed)
    out = np.zeros(shape, np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        n = base * 2 ** o
        g = rng.random((max(2, int(n * shape[0] / shape[1])) + 1, n + 1)).astype(np.float32)
        out += amp * ndimage.zoom(g, (shape[0] / g.shape[0], shape[1] / g.shape[1]), order=3)[: shape[0], : shape[1]]
        tot += amp; amp *= 0.55
    out /= tot
    return (out - out.min()) / (out.max() - out.min())


def albedo(z_full, tex_w):
    """Zemin rengi (lineer RGB) ve pürüzlülük haritası."""
    H0, W0 = z_full.shape
    tex_h = int(tex_w * H0 / W0)
    zf = ndimage.zoom(z_full, (tex_h / H0, tex_w / W0), order=1)
    zs = ndimage.gaussian_filter(zf, 2)
    px_m = KM_X * 1000 / tex_w
    gy, gx = np.gradient(zs, px_m)
    slope = np.hypot(gx, gy)
    rel = zs - ndimage.uniform_filter(zs, size=max(3, int(1500 / px_m)))  # sırt(+)/vadi(-)
    zn = (zs - zs.min()) / (zs.max() - zs.min())
    n1, n2, n3 = fbm(zs.shape, 1), fbm(zs.shape, 2, base=32), fbm(zs.shape, 3, base=4)

    # Temel: altın sarısı bozkır ile kırmızımsı toprak arası
    steppe = np.array([0.50, 0.38, 0.20]); soil = np.array([0.42, 0.27, 0.15]); pale = np.array([0.60, 0.50, 0.33])
    col = steppe[None, None] * (1 - n3[..., None]) + soil[None, None] * n3[..., None]
    col = col * (1 - 0.35 * n2[..., None]) + pale[None, None] * (0.35 * n2[..., None])

    # Dik yamaç: kireçtaşı (açık gri-krem), erozyon çizgileri
    rock = np.array([0.54, 0.48, 0.39])
    steep = np.clip((slope - 0.16) / 0.35, 0, 1) * (0.45 + 0.4 * n1)
    col = col * (1 - steep[..., None]) + rock[None, None] * steep[..., None]

    # Sırt üstlerinde seyrek meşe çalılığı (koyu yeşil benekler)
    rng = np.random.default_rng(5)
    scrub = (rng.random(zs.shape) < 0.035 * np.clip(rel / 40 + 0.3, 0, 1) * np.clip(1 - steep, 0, 1)).astype(np.float32)
    scrub = ndimage.gaussian_filter(scrub, 0.8) * 2.2
    col = col * (1 - np.clip(scrub, 0, 0.8)[..., None]) + np.array([0.10, 0.13, 0.05])[None, None] * np.clip(scrub, 0, 0.8)[..., None]

    # Ova tarlaları: düz ve alçak yerlerde Voronoi parselleri
    flat = np.clip(1 - slope / 0.06, 0, 1) * np.clip(1 - (zn - 0.12) / 0.25, 0, 1)
    k = 2600
    pts = np.column_stack([rng.random(k) * tex_h, rng.random(k) * tex_w])
    yy, xx = np.mgrid[0:tex_h, 0:tex_w].astype(np.float32)
    # Parseller tarım yönünde biraz uzar
    _, cell = cKDTree(pts * [1.0, 0.55]).query(np.column_stack([yy.ravel(), xx.ravel() * 0.55]), workers=-1)
    cell = cell.reshape(tex_h, tex_w)
    palette = np.array([
        [0.56, 0.46, 0.26], [0.48, 0.36, 0.20], [0.36, 0.38, 0.16], [0.30, 0.34, 0.12],
        [0.62, 0.52, 0.30], [0.44, 0.30, 0.18], [0.52, 0.44, 0.24],
    ])
    fieldcol = palette[rng.integers(0, len(palette), k)][cell]
    # Sürüm izleri
    ang = rng.random(k)[cell] * np.pi
    stripes = 0.5 + 0.5 * np.sin((xx * np.cos(ang) + yy * np.sin(ang)) * 1.6)
    fieldcol = fieldcol * (0.92 + 0.08 * stripes[..., None])
    edge = ndimage.morphological_gradient(cell, size=2) > 0
    fieldcol[edge] *= 0.82
    fmask = (flat * (n1 > 0.35))[..., None]
    col = col * (1 - fmask) + fieldcol * fmask

    # Nehir kıyısı ağaçlık ve su
    scale = tex_w / 1133
    rm_wide = river_mask(zs.shape, width=7, scale=scale)
    rm = river_mask(zs.shape, width=1.1, scale=scale)
    trees = np.clip(rm_wide * (0.5 + n2), 0, 1)
    col = col * (1 - 0.75 * trees[..., None]) + np.array([0.09, 0.15, 0.05])[None, None] * 0.75 * trees[..., None]
    water = np.array([0.04, 0.10, 0.10])
    col = col * (1 - rm[..., None]) + water[None, None] * rm[..., None]
    rough = np.clip(0.92 - 0.8 * rm, 0.06, 1)

    # Şehir dokusu ve sahaların düzlenmiş çakıl alanları
    yy2, xx2 = yy / (tex_h - 1) * 503, xx / (tex_w - 1) * 1132   # z2 ızgarasına
    cr, cc = CITY
    city = np.clip(1.15 - np.hypot((xx2 - cc) / 40, (yy2 - cr) / 34) - 0.25 * n2, 0, 1) ** 0.7
    urban = np.array([0.50, 0.47, 0.42]) * (0.85 + 0.3 * n2[..., None])
    col = col * (1 - city[..., None] * 0.85) + urban * city[..., None] * 0.85
    for key, radius, tone in [('bati_raman', 7, (0.60, 0.55, 0.46)), ('raman', 7, (0.60, 0.55, 0.46)),
                              ('garzan', 7, (0.60, 0.55, 0.46)), ('rafineri', 9, (0.46, 0.45, 0.43)),
                              ('lojman', 4, (0.52, 0.49, 0.44)), ('pazarlama', 4, (0.48, 0.46, 0.43))]:
        r0, c0 = POI[key]
        d = np.hypot(xx2 - c0, (yy2 - r0) * 1.0)
        pad = np.clip((radius - d) / 1.5, 0, 1) * (0.85 + 0.15 * n2)
        col = col * (1 - pad[..., None]) + np.array(tone) * pad[..., None]
    return np.clip(col, 0, 1).astype(np.float32), rough.astype(np.float32), (tex_h, tex_w)


def paint_roads(col, rough, roads, tex_shape):
    """Yolları dokuya işler: asfalt koyu gri, stabilize açık toz rengi."""
    tex_h, tex_w = tex_shape
    scale = tex_w / 1133
    for a, b, kind, p in roads:
        mm = np.zeros(tex_shape, bool)
        q = p * scale
        # Yoğun örnekle
        seg = np.concatenate([np.linspace(q[i], q[i + 1], 6, endpoint=False) for i in range(len(q) - 1)])
        seg = seg.astype(int)
        seg[:, 0] = seg[:, 0].clip(0, tex_h - 1); seg[:, 1] = seg[:, 1].clip(0, tex_w - 1)
        mm[seg[:, 0], seg[:, 1]] = True
        d = ndimage.distance_transform_edt(~mm)
        w = 3.2 if kind == 'asfalt' else 2.4
        m = np.clip(w - d, 0, 1)[..., None]
        shoulder = np.clip(w + 2.5 - d, 0, 1)[..., None] - m
        c = np.array([0.10, 0.10, 0.10]) if kind == 'asfalt' else np.array([0.66, 0.58, 0.45])
        col[:] = col * (1 - shoulder * 0.35) + np.array([0.6, 0.53, 0.42]) * shoulder * 0.35
        col[:] = col * (1 - m) + c * m
        if kind == 'asfalt':
            rough[:] = rough * (1 - m[..., 0]) + 0.55 * m[..., 0]
