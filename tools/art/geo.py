"""Batman bölgesinin gerçek arazi verisi (Copernicus DEM 30 m) yardımcıları.

Veri: Copernicus DEM GLO-30, © DLR e.V. 2010-2014 ve © Airbus Defence and
Space GmbH 2014-2018, Avrupa Birliği Copernicus Programı altında sağlanmıştır.
"""
import os
import urllib.request

import numpy as np
import tifffile

CACHE = os.environ.get('DEM_CACHE', os.path.join(os.path.dirname(__file__), '.dem'))

# Oyun dünyasının sınırları (enlem/boylam). Batman şehri, Raman ve Garzan
# sırtları ve Dicle vadisi bu alanda.
LAT_N, LAT_S = 37.99, 37.71
LON_W, LON_E = 41.03, 41.66


def tile_path(lat, lon):
    name = f'Copernicus_DSM_COG_10_N{lat:02d}_00_E{lon:03d}_00_DEM'
    path = os.path.join(CACHE, name + '.tif')
    if not os.path.exists(path):
        os.makedirs(CACHE, exist_ok=True)
        url = f'https://copernicus-dem-30m.s3.amazonaws.com/{name}/{name}.tif'
        urllib.request.urlretrieve(url, path)
    return path


def load_region():
    """Dünya alanının yükseklik dizisi (metre), satır 0 = kuzey."""
    a = tifffile.imread(tile_path(37, 41)).astype(np.float32)
    h, w = a.shape
    r0, r1 = int((38 - LAT_N) * h), int((38 - LAT_S) * h)
    c0, c1 = int((LON_W - 41) * w), int((LON_E - 41) * w)
    return a[r0:r1, c0:c1]


def downsample(a, f):
    h, w = (a.shape[0] // f) * f, (a.shape[1] // f) * f
    return a[:h, :w].reshape(h // f, f, w // f, f).mean(axis=(1, 3))


def fill_depressions(z, eps=1e-3):
    """Priority-flood: kenardan içe doğru çukurları doldurur, her hücrenin
    denize (kenara) kesintisiz bir iniş yolu olur."""
    import heapq

    h, w = z.shape
    out = z.astype(np.float64).copy()
    seen = np.zeros((h, w), bool)
    pq = []
    for r in range(h):
        for c in (0, w - 1):
            heapq.heappush(pq, (out[r, c], r, c)); seen[r, c] = True
    for c in range(1, w - 1):
        for r in (0, h - 1):
            heapq.heappush(pq, (out[r, c], r, c)); seen[r, c] = True
    while pq:
        v, r, c = heapq.heappop(pq)
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                rr, cc = r + dr, c + dc
                if (dr or dc) and 0 <= rr < h and 0 <= cc < w and not seen[rr, cc]:
                    seen[rr, cc] = True
                    if out[rr, cc] <= v:
                        out[rr, cc] = v + eps
                    heapq.heappush(pq, (out[rr, cc], rr, cc))
    return out


def flow_accumulation(z):
    """D8 akış birikimi: nehir yataklarını bulur."""
    h, w = z.shape
    order = np.argsort(z, axis=None)[::-1]
    acc = np.ones(h * w, dtype=np.float64)
    zf = z.ravel()
    offs = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
    for idx in order:
        r, c = divmod(int(idx), w)
        best, bi = 0.0, -1
        for dr, dc in offs:
            rr, cc = r + dr, c + dc
            if 0 <= rr < h and 0 <= cc < w:
                drop = (zf[idx] - zf[rr * w + cc]) / (1.414 if dr and dc else 1.0)
                if drop > best:
                    best, bi = drop, rr * w + cc
        if bi >= 0:
            acc[bi] += acc[idx]
    return acc.reshape(h, w)


def latlon_to_uv(lat, lon):
    """0..1 doku koordinatı (u: batı→doğu, v: kuzey→güney)."""
    return (lon - LON_W) / (LON_E - LON_W), (LAT_N - lat) / (LAT_N - LAT_S)
