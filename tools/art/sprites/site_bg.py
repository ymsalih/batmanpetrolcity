"""Saha görünümü arka planı: dağda birbirinden ayrı kuyu pedleri.

Her kuyunun kendi düzlenmiş pedi var (kendi kotunda, kazı-dolgu şevli);
pedler eğimi az yerlerden geçen toprak yollarla birbirine ve güneydeki
toplanma alanına bağlanır. Yerleşim her sahada farklıdır.

Genel eğim sahanın gerçek konumundaki arazi verisinden (DEM) gelir; ince
ayrıntı (kaya, çalı, çakıl) prosedüreldir. 3x3 kuyu yeri, giriş yolu ve
işçilerin toplanacağı nokta piksel koordinatıyla dışa aktarılır.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import numpy as np
from scipy import ndimage

import geo
import kit
import scene_common as sc
import world_data as wd

SAMPLES = int(os.environ.get('SAMPLES', 48))
SITES = os.environ.get('SITES', 'raman,bati_raman,garzan').split(',')
PX = 7                  # px/m (oyunda yakınlaştırılır)
SPAN = 300.0            # m: render edilen alan
PAD_W, PAD_D = 34.0, 28.0   # m: her kuyunun kendi pedi
YARD = (0.0, -98.0)    # toplanma alanı (servis aracı, işçilerin buluştuğu yer)
GRID = 420


def layout(seed):
    """9 kuyu yeri: birbirinden ~60 m uzak, tepenin çevresine dağılmış."""
    rng = np.random.default_rng(seed)
    pts = []
    tries = 0
    min_d = 64.0
    while len(pts) < 9:
        tries += 1
        if tries % 4000 == 0:  # yer kalmadıysa aralığı biraz daralt
            min_d -= 3.0
        a = rng.uniform(0, 2 * np.pi); r = 115 * np.sqrt(rng.uniform(0.04, 1))
        x, y = r * np.cos(a), r * np.sin(a) * 0.9 + 8
        if abs(x) > SPAN / 2 - 30 or abs(y) > SPAN / 2 - 30 or y < YARD[1] + 40:
            continue
        if all(np.hypot(x - px, y - py) > min_d for px, py, _ in pts):
            pts.append((x, y, rng.uniform(-0.45, 0.45)))
    # Oyundaki parsel sırası: kuzeyden güneye, batıdan doğuya (okuma sırası)
    pts.sort(key=lambda p: (-round(p[1] / 40), p[0]))
    return pts


def rect_dist(xx, yy, cx, cy, ang, w, d):
    """Döndürülmüş dikdörtgene işaretli uzaklık (içeride negatif)."""
    ca, sa = np.cos(ang), np.sin(ang)
    u = (xx - cx) * ca + (yy - cy) * sa
    v = -(xx - cx) * sa + (yy - cy) * ca
    qx, qy = np.abs(u) - w / 2, np.abs(v) - d / 2
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0)


def site_heights(key, seed):
    """Gerçek eğim + prosedürel ayrıntı; pedler, avlu ve yollar düzlenir."""
    from skimage.graph import route_through_array

    z = geo.load_region()
    r2, c2 = wd.POI[key]
    H, W = z.shape
    r, c = r2 * H / 504, c2 * W / 1133
    half = SPAN / 2 / 24.5 + 2
    sub = z[int(r - half):int(r + half) + 1, int(c - half):int(c + half) + 1]
    big = ndimage.zoom(sub, (GRID / sub.shape[0], GRID / sub.shape[1]), order=3)
    big = np.pad(big, ((0, max(0, GRID - big.shape[0])), (0, max(0, GRID - big.shape[1]))), mode='edge')[:GRID, :GRID]
    big = np.clip(big - big[GRID // 2, GRID // 2], -40, 40)
    xs = np.linspace(-SPAN / 2, SPAN / 2, GRID)
    xx, yy = np.meshgrid(xs, xs)
    d = np.hypot(xx, yy) / (SPAN / 2)
    rng = np.random.default_rng(seed)
    detail = sum(ndimage.zoom(rng.normal(0, 1, (n, n)), GRID / n, order=3)[:GRID, :GRID] * a
                 for n, a in ((6, 6.0), (14, 2.2), (40, 0.7), (110, 0.2)))
    hgt = big * 0.9 + detail - 18.0 * np.clip(d - 0.5, 0, None) ** 1.4

    wells = layout(seed)
    flat = np.zeros_like(hgt)       # 1: düzlenmiş zemin (ped/avlu)
    pads = []
    for (cx, cy, ang) in wells + [(YARD[0], YARD[1], 0.0)]:
        is_yard = (cx, cy) == YARD
        w, dd = (40.0, 26.0) if is_yard else (PAD_W, PAD_D)
        sd = rect_dist(xx, yy, cx, cy, ang, w, dd)
        ci, cj = int((cy + SPAN / 2) / SPAN * (GRID - 1)), int((cx + SPAN / 2) / SPAN * (GRID - 1))
        level = float(np.median(hgt[max(0, ci - 3):ci + 4, max(0, cj - 3):cj + 4]))
        blend = np.clip(1 - sd / 7.0, 0, 1)          # 7 m kazı-dolgu şevi
        blend = blend * blend * (3 - 2 * blend)
        hgt = hgt * (1 - blend) + level * blend
        flat = np.maximum(flat, np.clip(-sd / 1.5 + 1, 0, 1))
        pads.append((cx, cy, ang, level, is_yard))

    # Toprak yollar: avludan her pede, eğimi en az yoldan (ağaç yapısı)
    gy, gx = np.gradient(ndimage.gaussian_filter(hgt, 2), SPAN / GRID)
    cost = 1 + (np.hypot(gx, gy) * 12) ** 2
    def idx(x, y):
        return (int((y + SPAN / 2) / SPAN * (GRID - 1)), int((x + SPAN / 2) / SPAN * (GRID - 1)))
    order = sorted(range(9), key=lambda i: np.hypot(wells[i][0] - YARD[0], wells[i][1] - YARD[1]))
    connected = [(YARD[0], YARD[1])]
    tracks = []
    for i in order:
        wx, wy, _ = wells[i]
        near = min(connected, key=lambda p: np.hypot(p[0] - wx, p[1] - wy))
        path, _ = route_through_array(cost, idx(*near), idx(wx, wy), fully_connected=True, geometric=True)
        p = np.array(path, float)
        if len(p) > 9:
            p = ndimage.gaussian_filter1d(p, 3, axis=0, mode='nearest')
        pts = np.column_stack([p[:, 1] / (GRID - 1) * SPAN - SPAN / 2, p[:, 0] / (GRID - 1) * SPAN - SPAN / 2])
        tracks.append(pts)
        connected += [tuple(q) for q in pts[:: max(1, len(pts) // 6)]] + [(wx, wy)]
    # Ana giriş yolu: güney kenarından avluya
    ent = np.array([(8 * np.sin(t / 25), t) for t in np.linspace(-SPAN / 2, YARD[1], 30)])
    tracks.append(ent)

    # Yol bandını hafifçe düzle (enine eğim azalır)
    tm = np.zeros_like(hgt, bool)
    for t in tracks:
        q = np.concatenate([np.linspace(t[k], t[k + 1], 4, endpoint=False) for k in range(len(t) - 1)])
        ii = ((q[:, 1] + SPAN / 2) / SPAN * (GRID - 1)).astype(int).clip(0, GRID - 1)
        jj = ((q[:, 0] + SPAN / 2) / SPAN * (GRID - 1)).astype(int).clip(0, GRID - 1)
        tm[ii, jj] = True
    td = ndimage.distance_transform_edt(~tm) * SPAN / GRID
    tb = np.clip(1 - td / 6.0, 0, 1)
    hgt = hgt * (1 - tb * (1 - flat)) + ndimage.gaussian_filter(hgt, 4) * tb * (1 - flat)
    hgt = hgt - pads[-1][3]   # avlu kotu = 0
    return hgt, flat, tb, wells, pads, tracks


def albedo(hgt, flat, trackband, wells, seed, tone):
    rng = np.random.default_rng(seed)
    N = 1600
    h = ndimage.zoom(hgt, N / GRID, order=1)
    ins = np.clip(ndimage.zoom(flat, N / GRID, order=1), 0, 1)
    trk = np.clip(ndimage.zoom(trackband, N / GRID, order=1), 0, 1)
    gy, gx = np.gradient(h, SPAN / N)
    slope = np.hypot(gx, gy)
    n1 = wd.fbm((N, N), seed, base=6); n2 = wd.fbm((N, N), seed + 1, base=40); n3 = wd.fbm((N, N), seed + 2, base=160)
    yy, xx = np.mgrid[0:N, 0:N] / N * SPAN - SPAN / 2   # yy: güney(-) → kuzey(+)

    # Bozkır: altın sarısı kuru ot + kızıl toprak lekeleri
    soil = np.array(tone) * 0.78 * (0.8 + 0.35 * n1[..., None])
    grass = np.array([0.34, 0.27, 0.11])
    dry = np.array([0.34, 0.24, 0.13])
    col = soil * (1 - 0.5 * n2[..., None]) + grass * 0.5 * n2[..., None]
    col = col * (1 - 0.3 * (n3[..., None] > 0.6)) + dry * 0.3 * (n3[..., None] > 0.6)
    rock = np.array([0.40, 0.37, 0.32])
    st = np.clip((slope - 0.3) / 0.4, 0, 1)[..., None]
    col = col * (1 - st) + rock * (0.8 + 0.3 * n3[..., None]) * st

    # Çakıl ped: sıcak gri-bej, ince taneli doku, lastik izleri
    gravel = np.array([0.30, 0.28, 0.24]) * (0.86 + 0.2 * n3[..., None]) * (0.93 + 0.12 * n2[..., None])
    tracks = np.zeros((N, N), np.float32)
    for k in range(7):
        a = rng.uniform(0, np.pi); ox = rng.uniform(-40, 40); oy = rng.uniform(-40, 40)
        dist = np.abs((xx - ox) * np.sin(a) - (yy - oy) * np.cos(a))
        tracks += np.clip(1 - np.abs(dist - 1.1) / 0.35, 0, 1) * 0.5
    gravel = gravel * (1 - 0.18 * np.clip(tracks, 0, 1)[..., None])
    col = col * (1 - ins[..., None]) + gravel * ins[..., None]
    # Ped kenarında toprak set (şev): koyu halka
    rim = np.clip(ins * (1 - ins) * 4, 0, 1)
    col = col * (1 - 0.25 * rim[..., None])

    # Toprak yollar: koyu, sıkışmış toprak; ortası tekerlek izli
    road = np.clip((trk - 0.45) / 0.2, 0, 1) * (1 - ins)
    road_col = np.array([0.26, 0.22, 0.17]) * (0.9 + 0.15 * n3[..., None])
    col = col * (1 - road[..., None]) + road_col * road[..., None]
    # Kuyu başlarında petrol/çamur lekeleri
    for cx, cy, _ in wells:
        d = np.hypot(xx - cx, (yy - cy) * 1.3)
        stain = np.clip(1 - d / (5 + 3 * n2), 0, 1) ** 0.9 * 0.7
        col = col * (1 - stain[..., None]) + np.array([0.06, 0.05, 0.04]) * stain[..., None]
    return np.clip(col, 0, 1)[::-1].astype(np.float32)  # satır 0 = kuzey


def build(key, seed, tone):
    hgt, flat, trackband, wells, pads, tracks = site_heights(key, seed)
    # Kadraj kenarında arazi bitmesin: her yöne aynalanarak uzatılır.
    EXT = 90
    hx = np.pad(hgt, EXT, mode='reflect')
    G = GRID + 2 * EXT
    step = SPAN / (GRID - 1)
    xs = (np.arange(G) - EXT) * step - SPAN / 2
    X, Y = np.meshgrid(xs, xs)  # Y: güney(-)→kuzey(+)
    verts = np.column_stack([X.ravel(), Y.ravel(), hx.ravel()]).astype(np.float32)
    rr, cc = np.mgrid[0:G - 1, 0:G - 1]
    i = (rr * G + cc).ravel()
    faces = np.column_stack([i, i + 1, i + G + 1, i + G]).astype(np.int32)
    me = bpy.data.meshes.new('arazi')
    me.vertices.add(len(verts)); me.vertices.foreach_set('co', verts.ravel())
    me.loops.add(faces.size); me.loops.foreach_set('vertex_index', faces.ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set('loop_start', np.arange(0, faces.size, 4, dtype=np.int32))
    me.polygons.foreach_set('loop_total', np.full(len(faces), 4, np.int32))
    uv = me.uv_layers.new(name='UV')
    U = (X.ravel() + SPAN / 2) / SPAN; V = (Y.ravel() + SPAN / 2) / SPAN
    uv.data.foreach_set('uv', np.column_stack([U, V])[faces.ravel()].astype(np.float32).ravel())
    me.update(); me.validate()
    me.polygons.foreach_set('use_smooth', np.ones(len(faces), bool))
    ob = bpy.data.objects.new('arazi', me)
    bpy.context.scene.collection.objects.link(ob)
    from PIL import Image
    col = albedo(hgt, flat, trackband, wells, seed, tone)
    srgb = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.power(col, 1 / 2.4) - 0.055)
    path = os.path.join(kit.OUT, f'_site_{key}.png')
    Image.fromarray((srgb * 255).astype(np.uint8)).save(path)
    m = bpy.data.materials.new('zemin'); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    ti = nt.nodes.new('ShaderNodeTexImage'); ti.image = bpy.data.images.load(path)
    ti.extension = 'MIRROR'
    nt.links.new(ti.outputs['Color'], b.inputs['Base Color'])
    b.inputs['Roughness'].default_value = 0.95
    ob.data.materials.append(m)

    # Kayalar ve çalılar (ped dışında), birkaç meşe ağacı
    rng = np.random.default_rng(seed + 9)
    rock_m = kit.mat_paint('kaya', (0.50, 0.47, 0.41), 0.9, 0.15, 0.0, 2)
    bush_m = kit.mat_paint('cali', (0.16, 0.20, 0.07), 0.95, 0.4, 0.0, 3)
    tree_m = kit.mat_paint('mese', (0.12, 0.18, 0.06), 0.95, 0.35, 0.0, 2)
    trunk_m = kit.mat_plain('govde', (0.2, 0.13, 0.08), 0.9)

    def height_at(x, y):
        c = int((x + SPAN / 2) / SPAN * (GRID - 1)); r = int((y + SPAN / 2) / SPAN * (GRID - 1))
        return float(hgt[min(max(r, 0), GRID - 1), min(max(c, 0), GRID - 1)])

    def outside(x, y, margin=4):
        i = int((y + SPAN / 2) / SPAN * (GRID - 1)); j = int((x + SPAN / 2) / SPAN * (GRID - 1))
        i, j = min(max(i, 0), GRID - 1), min(max(j, 0), GRID - 1)
        if flat[i, j] > 0.01 or trackband[i, j] > 0.2:
            return False
        return all(np.hypot(x - cx, y - cy) > max(PAD_W, PAD_D) / 2 + margin for cx, cy, *_ in pads)

    for _ in range(620):
        x, y = rng.uniform(-SPAN / 2 + 14, SPAN / 2 - 14, 2)
        if not outside(x, y):
            continue
        s = rng.uniform(0.4, 1.8)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=s, subdivisions=1, location=(x, y, height_at(x, y) + s * 0.25))
        o = bpy.context.active_object; o.scale = (1, rng.uniform(0.6, 1.2), rng.uniform(0.4, 0.7))
        o.rotation_euler = (0, 0, rng.uniform(0, 6.28)); o.data.materials.append(rock_m)
    for _ in range(1000):
        x, y = rng.uniform(-SPAN / 2 + 14, SPAN / 2 - 14, 2)
        if not outside(x, y, 2):
            continue
        s = rng.uniform(0.5, 1.2)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=s, subdivisions=2, location=(x, y, height_at(x, y) + s * 0.4))
        o = bpy.context.active_object; o.scale = (1, 1, 0.7); o.data.materials.append(bush_m)
    for _ in range(60):
        x, y = rng.uniform(-SPAN / 2 + 14, SPAN / 2 - 14, 2)
        if not outside(x, y, 10):
            continue
        g = height_at(x, y); s = rng.uniform(0.8, 1.3)
        kit.cyl('mese_govde', 0.3 * s, 3 * s, (x, y, g + 1.5 * s), trunk_m, None, verts=8)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=3.0 * s, subdivisions=2, location=(x, y, g + 4.2 * s))
        o = bpy.context.active_object; o.scale = (1, 1, 0.8); o.data.materials.append(tree_m)
    # Her pedde beton kuyu bodrumu (cellar)
    cel_m = kit.mat_paint('beton', (0.47, 0.46, 0.43), 0.95, 0.05, 0.0, 1)
    for cx, cy, ang, level, is_yard in pads:
        if not is_yard:
            kit.box('bodrum', (2.4, 2.4, 0.25), (cx, cy, level - pads[-1][3] + 0.12), cel_m, None,
                    rot=(0, 0, ang), bevel=0.05)
    return hgt, wells, pads, tracks


def main():
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    tones = {'raman': (0.50, 0.38, 0.22), 'bati_raman': (0.54, 0.42, 0.25), 'garzan': (0.46, 0.38, 0.28)}
    for k, key in enumerate(SITES):
        scene = sc.reset(samples=SAMPLES, transparent=False)
        kit._mats.clear()
        kit.PX_PER_M = PX
        hgt, wells, pads, tracks = build(key, 100 + k * 7, tones.get(key, (0.5, 0.4, 0.24)))
        y0 = pads[-1][3]
        lo = (-SPAN / 2 + 8, -SPAN / 2 + 8, max(float(hgt.min()), -20.0)); hi = (SPAN / 2 - 8, SPAN / 2 - 8, 10.0)
        cam, res, _ = kit.frame_camera(scene, lo, hi, pad=-17)
        scene.render.filepath = os.path.join(kit.OUT, 'site', f'{key}.png')
        os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
        bpy.ops.render.render(write_still=True)

        def px(p):
            co = world_to_camera_view(scene, cam, Vector(p))
            return [round(co.x * res[0], 1), round((1 - co.y) * res[1], 1)]

        def ground(x, y):
            i = int((y + SPAN / 2) / SPAN * (GRID - 1)); j = int((x + SPAN / 2) / SPAN * (GRID - 1))
            return float(hgt[min(max(i, 0), GRID - 1), min(max(j, 0), GRID - 1)])

        meta = {
            'size': res, 'pxPerM': PX,
            # Her kuyunun kendi pedi: merkez (piksel), dönüş açısı ve kotu (m)
            'parcels': [px((cx, cy, lvl - y0 + 0.25)) for cx, cy, ang, lvl, yard in pads if not yard],
            'pads': [{'px': px((cx, cy, lvl - y0)), 'angle': round(ang, 3), 'levelM': round(lvl - y0, 1)}
                     for cx, cy, ang, lvl, yard in pads if not yard],
            'tracks': [[px((x, y, ground(x, y))) for x, y in t[::3]] for t in tracks],
            'gate': px((8 * math.sin(YARD[1] / 25), YARD[1] - 14, ground(0, YARD[1] - 14))),
            'roadEnd': px((8 * math.sin(-SPAN / 2 / 25 + 0.3), -SPAN / 2 + 14, ground(0, -SPAN / 2 + 14))),
            'meeting': px((YARD[0], YARD[1] + 4, 0.0)),
        }
        with open(os.path.join(kit.OUT, 'site', f'{key}.json'), 'w') as fh:
            json.dump(meta, fh)
        print('ok', key, meta['size'], 'zmin', float(hgt.min()), 'zmax', float(hgt.max()))


main()
