"""Saha görünümü arka planı: dağ tepesinde düzlenmiş sondaj pedi.

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
PX = 10                 # px/m (oyunda 2x büyütülür)
SPAN = 190.0            # m: render edilen alan
PAD = 116.0             # m: düzlenmiş ped kenarı
SPACING = 36.0          # m: kuyu aralığı
GRID = 300


def site_heights(key, seed):
    """Sahanın çevresindeki gerçek eğim + prosedürel ayrıntı (m)."""
    z = geo.load_region()
    r2, c2 = wd.POI[key]
    H, W = z.shape
    r, c = r2 * H / 504, c2 * W / 1133
    # DEM ~24 m/px: SPAN alanını kapsayan ~10x10 örnek, kübik büyütme
    half = SPAN / 2 / 24.5 + 2
    sub = z[int(r - half):int(r + half) + 1, int(c - half):int(c + half) + 1]
    big = ndimage.zoom(sub, GRID / sub.shape[0] * 1.0, order=3)[:GRID, :GRID]
    big = big - big[GRID // 2, GRID // 2]
    # Dağ tepesi hissi: kenarlara doğru belirgin iniş
    yy, xx = (np.mgrid[0:GRID, 0:GRID] - GRID / 2) / (GRID / 2)
    d = np.hypot(xx, yy)
    big = np.clip(big, -25, 25)
    base = big * 0.8 - 14.0 * np.clip(d - 0.62, 0, None) ** 1.5
    rng = np.random.default_rng(seed)
    detail = sum(ndimage.zoom(rng.normal(0, 1, (n, n)), GRID / n, order=3)[:GRID, :GRID] * a
                 for n, a in ((8, 2.2), (20, 0.9), (60, 0.25)))
    hgt = base + detail
    # Ped: ortada düz bir platform, kenarlarda yumuşak şev
    m = SPAN / GRID
    px_ = np.abs(xx * SPAN / 2); py_ = np.abs(yy * SPAN / 2)
    inside = np.clip((PAD / 2 + 6 - np.maximum(px_, py_)) / 6, 0, 1)
    pad_h = float(np.median(hgt[np.maximum(px_, py_) < PAD / 2]))
    hgt = hgt * (1 - inside) + pad_h * inside
    return hgt - pad_h, inside


def albedo(hgt, inside, seed, tone):
    rng = np.random.default_rng(seed)
    N = 1600
    h = ndimage.zoom(hgt, N / GRID, order=1)
    ins = np.clip(ndimage.zoom(inside, N / GRID, order=1), 0, 1)
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

    # Giriş yolu: güney kenarından pede inen stabilize yol
    road_x = 8 * np.sin(yy / 30)
    road = np.clip((5.5 - np.abs(xx - road_x)) / 1.5, 0, 1) * (yy < -PAD / 2 + 3)
    road_col = np.array([0.24, 0.22, 0.19]) * (0.9 + 0.15 * n3[..., None])
    col = col * (1 - road[..., None]) + road_col * road[..., None]
    # Kuyu başlarında petrol/çamur lekeleri ve sıkıştırılmış zemin
    for i in range(3):
        for j in range(3):
            cx, cy = (i - 1) * SPACING, (j - 1) * SPACING
            d = np.hypot(xx - cx, (yy - cy) * 1.3)
            stain = np.clip(1 - d / (6 + 4 * n2), 0, 1) ** 0.9 * 0.75
            col = col * (1 - stain[..., None]) + np.array([0.06, 0.05, 0.04]) * stain[..., None]
            sq = np.clip(1 - np.maximum(np.abs(xx - cx), np.abs(yy - cy)) / 9.0, 0, 1) ** 0.25
            col = col * (1 - 0.1 * sq[..., None])
    return np.clip(col, 0, 1)[::-1].astype(np.float32)  # satır 0 = kuzey


def build(key, seed, tone):
    hgt, inside = site_heights(key, seed)
    xs = np.linspace(-SPAN / 2, SPAN / 2, GRID)
    X, Y = np.meshgrid(xs, xs)  # Y: güney(-)→kuzey(+)
    verts = np.column_stack([X.ravel(), Y.ravel(), hgt.ravel()]).astype(np.float32)
    rr, cc = np.mgrid[0:GRID - 1, 0:GRID - 1]
    i = (rr * GRID + cc).ravel()
    faces = np.column_stack([i, i + 1, i + GRID + 1, i + GRID]).astype(np.int32)
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
    col = albedo(hgt, inside, seed, tone)
    srgb = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.power(col, 1 / 2.4) - 0.055)
    path = os.path.join(kit.OUT, f'_site_{key}.png')
    Image.fromarray((srgb * 255).astype(np.uint8)).save(path)
    m = bpy.data.materials.new('zemin'); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes['Principled BSDF']
    ti = nt.nodes.new('ShaderNodeTexImage'); ti.image = bpy.data.images.load(path)
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
        return max(abs(x), abs(y)) > PAD / 2 + margin

    for _ in range(260):
        x, y = rng.uniform(-SPAN / 2, SPAN / 2, 2)
        if not outside(x, y):
            continue
        s = rng.uniform(0.4, 1.8)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=s, subdivisions=1, location=(x, y, height_at(x, y) + s * 0.25))
        o = bpy.context.active_object; o.scale = (1, rng.uniform(0.6, 1.2), rng.uniform(0.4, 0.7))
        o.rotation_euler = (0, 0, rng.uniform(0, 6.28)); o.data.materials.append(rock_m)
    for _ in range(420):
        x, y = rng.uniform(-SPAN / 2, SPAN / 2, 2)
        if not outside(x, y, 2):
            continue
        s = rng.uniform(0.5, 1.2)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=s, subdivisions=2, location=(x, y, height_at(x, y) + s * 0.4))
        o = bpy.context.active_object; o.scale = (1, 1, 0.7); o.data.materials.append(bush_m)
    for _ in range(26):
        x, y = rng.uniform(-SPAN / 2, SPAN / 2, 2)
        if not outside(x, y, 10):
            continue
        g = height_at(x, y); s = rng.uniform(0.8, 1.3)
        kit.cyl('mese_govde', 0.3 * s, 3 * s, (x, y, g + 1.5 * s), trunk_m, None, verts=8)
        bpy.ops.mesh.primitive_ico_sphere_add(radius=3.0 * s, subdivisions=2, location=(x, y, g + 4.2 * s))
        o = bpy.context.active_object; o.scale = (1, 1, 0.8); o.data.materials.append(tree_m)
    # Kuyu yerlerinde beton kuyu bodrumu (cellar) ve kazık işaretleri
    cel_m = kit.mat_paint('beton', (0.47, 0.46, 0.43), 0.95, 0.05, 0.0, 1)
    for i in range(3):
        for j in range(3):
            kit.box('bodrum', (2.4, 2.4, 0.25), ((i - 1) * SPACING, (j - 1) * SPACING, 0.12), cel_m, None, bevel=0.05)
    return hgt


def main():
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector

    tones = {'raman': (0.50, 0.38, 0.22), 'bati_raman': (0.54, 0.42, 0.25), 'garzan': (0.46, 0.38, 0.28)}
    for k, key in enumerate(SITES):
        scene = sc.reset(samples=SAMPLES, transparent=False)
        kit._mats.clear()
        kit.PX_PER_M = PX
        hgt = build(key, 100 + k * 7, tones.get(key, (0.5, 0.4, 0.24)))
        lo = (-SPAN / 2 + 6, -SPAN / 2 + 6, max(float(hgt.min()), -12.0)); hi = (SPAN / 2 - 6, SPAN / 2 - 6, 6.0)
        cam, res, _ = kit.frame_camera(scene, lo, hi, pad=-4)
        scene.render.filepath = os.path.join(kit.OUT, 'site', f'{key}.png')
        os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
        bpy.ops.render.render(write_still=True)

        def px(p):
            co = world_to_camera_view(scene, cam, Vector(p))
            return [round(co.x * res[0], 1), round((1 - co.y) * res[1], 1)]

        meta = {
            'size': res, 'pxPerM': PX,
            # Parsel sırası: oyundaki 3x3 ızgara (soldan sağa, üstten alta)
            'parcels': [px(((i - 1) * SPACING, (1 - j) * SPACING, 0.25)) for j in range(3) for i in range(3)],
            'gate': px((8 * math.sin(-PAD / 60), -PAD / 2 - 2, 0)),
            'roadEnd': px((8 * math.sin(-SPAN / 60), -SPAN / 2 + 8, float(hgt[0, GRID // 2]))),
            'meeting': px((0, -PAD / 2 + 10, 0)),
        }
        with open(os.path.join(kit.OUT, 'site', f'{key}.json'), 'w') as fh:
            json.dump(meta, fh)
        print('ok', key, meta['size'], 'zmin', float(hgt.min()), 'zmax', float(hgt.max()))


main()
