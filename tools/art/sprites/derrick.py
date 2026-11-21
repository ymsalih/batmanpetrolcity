"""Kara sondaj kulesi (direk tipi). Statik gövde + hareketli makara bloğu
katmanı (ayrı, küçük kareler: telefon belleği için).

Ölçüler (m): sondaj platformu 5 m yükseklikte, direk 24 m, derikmen
platformu (monkeyboard) ~17 m'de.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
from mathutils import Vector

import kit
import scene_common as sc

SAMPLES = int(os.environ.get('SAMPLES', 64))
BLOCK_FRAMES = int(os.environ.get('FRAMES', 12))
YAW = math.radians(float(os.environ.get('YAW', 18)))
FLOOR = 5.0
MAST_H = 24.0


def init_materials():
    global red, white, steel, dark, concrete, blue, yellow, glass, cable, chrome, mud, wood, orange
    red = kit.mat_paint('kule_kirmizi', (0.50, 0.07, 0.04), rough=0.45, rust=0.12, scale=1.2)
    white = kit.mat_paint('beyaz', (0.80, 0.80, 0.76), rough=0.5, rust=0.08, scale=1.0)
    steel = kit.mat_paint('celik', (0.22, 0.25, 0.28), rough=0.5, rust=0.12, scale=1.5)
    dark = kit.mat_paint('koyu', (0.08, 0.09, 0.10), rough=0.6, rust=0.06)
    concrete = kit.mat_paint('beton', (0.50, 0.48, 0.44), rough=0.95, rust=0.12, metallic=0.0, scale=2)
    blue = kit.mat_paint('mavi', (0.05, 0.16, 0.36), rough=0.45, rust=0.08)
    yellow = kit.mat_paint('sari', (0.86, 0.56, 0.06), rough=0.42, rust=0.08)
    orange = kit.mat_paint('turuncu', (0.80, 0.30, 0.04), rough=0.45, rust=0.08)
    glass = kit.mat_plain('cam', (0.15, 0.22, 0.28), 0.08, 0.6)
    cable = kit.mat_plain('halat', (0.05, 0.05, 0.05), 0.35, 0.8)
    chrome = kit.mat_plain('krom', (0.8, 0.8, 0.8), 0.15, 1.0)
    mud = kit.mat_plain('camur', (0.16, 0.12, 0.08), 0.25)
    wood = kit.mat_plain('ahsap', (0.36, 0.24, 0.13), 0.85)


def lattice(root, p_bl, size_b, size_t, h, z0, step, mat, r_leg=0.12, r_brace=0.05):
    """Konik kafes kule: 4 bacak, yatay kuşaklar, X çaprazlar."""
    cx, cy = p_bl

    def corner(i, z):
        k = (z - z0) / h
        s = size_b + (size_t - size_b) * k
        dx = (-1, 1, 1, -1)[i] * s / 2; dy = (-1, -1, 1, 1)[i] * s / 2
        return Vector((cx + dx, cy + dy, z))

    for i in range(4):
        kit.rod('bacak', corner(i, z0), corner(i, z0 + h), r_leg, mat, root, square=True)
    n = int(h / step)
    for k in range(n + 1):
        z = z0 + k * step
        for i in range(4):
            kit.rod('kusak', corner(i, z), corner((i + 1) % 4, z), r_brace, mat, root, square=True)
        if k < n:
            z2 = z + step
            for i in range(4):
                j = (i + 1) % 4
                kit.rod('capraz', corner(i, z), corner(j, z2), r_brace * 0.8, mat, root, square=True)
                kit.rod('capraz', corner(j, z), corner(i, z2), r_brace * 0.8, mat, root, square=True)


def container(root, name, size, loc, mat, windows=0, door=False):
    ob = kit.box(name, size, loc, mat, root, bevel=0.06)
    sx, sy, sz = size
    # Oluklu sac görünümü: ince dikey nervürler
    for i in range(int(sx / 0.35)):
        x = loc[0] - sx / 2 + 0.2 + i * 0.35
        kit.box('nervur', (0.05, 0.02, sz * 0.9), (x, loc[1] - sy / 2 - 0.01, loc[2]), mat, root, bevel=0)
    for w in range(windows):
        x = loc[0] - sx / 2 + (w + 1) * sx / (windows + 1)
        kit.box('pencere', (0.9, 0.04, 0.6), (x, loc[1] - sy / 2 - 0.03, loc[2] + 0.25), glass, root, bevel=0.02)
    if door:
        kit.box('kapi', (0.8, 0.04, 1.9), (loc[0] + sx / 2 - 0.7, loc[1] - sy / 2 - 0.03, loc[2] - sz / 2 + 1.0), dark, root)
    return ob


def build():
    root = kit.empty('kok')
    # Saha zemini: sıkıştırılmış çakıl ped + beton temeller
    kit.box('ped', (30, 22, 0.15), (1.5, 1.0, 0.075), kit.mat_paint('cakil', (0.48, 0.43, 0.36), 0.95, 0.2, 0, 8), root, bevel=0.1)
    for x in (-3.2, 3.2):
        kit.box('temel', (1.6, 9.5, 0.4), (x, 0, 0.35), concrete, root, bevel=0.05)

    # Alt yapı (substructure): kafes kutu
    for x in (-3.2, 3.2):
        for y in (-4.2, 4.2):
            kit.rod('ayak', (x, y, 0.5), (x, y, FLOOR), 0.22, red, root, square=True)
        kit.rod('kiris', (x, -4.2, FLOOR), (x, 4.2, FLOOR), 0.25, red, root, square=True)
        kit.rod('kiris', (x, -4.2, 0.6), (x, 4.2, 0.6), 0.2, red, root, square=True)
        for y0, y1 in ((-4.2, 0), (0, 4.2)):
            kit.rod('capraz', (x, y0, 0.6), (x, y1, FLOOR), 0.09, red, root, square=True)
            kit.rod('capraz', (x, y1, 0.6), (x, y0, FLOOR), 0.09, red, root, square=True)
    for y in (-4.2, 4.2):
        kit.rod('kiris', (-3.2, y, FLOOR), (3.2, y, FLOOR), 0.22, red, root, square=True)
    # Sondaj platformu (drill floor)
    kit.box('platform', (8.6, 10.0, 0.3), (0, 0, FLOOR + 0.15), steel, root, bevel=0.05)
    # Platform korkulukları
    for (x0, y0), (x1, y1) in [((-4.3, -5), (4.3, -5)), ((4.3, -5), (4.3, 5)), ((-4.3, 5), (4.3, 5))]:
        for h in (0.55, 1.1):
            kit.rod('korkuluk', (x0, y0, FLOOR + 0.3 + h), (x1, y1, FLOOR + 0.3 + h), 0.03, yellow, root)
        n = int(math.hypot(x1 - x0, y1 - y0) / 1.2)
        for i in range(n + 1):
            x, y = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
            kit.rod('dikme', (x, y, FLOOR + 0.3), (x, y, FLOOR + 1.4), 0.035, yellow, root)
    # Döner masa ve rotary
    kit.cyl('doner_masa', 0.75, 0.35, (0, 0, FLOOR + 0.45), dark, root)
    kit.cyl('kuyu_agzi', 0.25, 0.4, (0, 0, FLOOR + 0.5), chrome, root)
    # BOP yığını (platform altında, kuyu başında)
    for z, r in ((1.2, 0.7), (2.1, 0.75), (3.0, 0.65), (3.8, 0.5)):
        kit.cyl('bop', r, 0.75, (0, 0, z), red if z < 3.5 else steel, root)

    # Direk (mast): konik kafes
    lattice(root, (0, 0), 3.4, 1.2, MAST_H, FLOOR + 0.3, 2.0, white, r_leg=0.16, r_brace=0.055)
    # Kırmızı-beyaz uyarı bantları (üst bölüm)
    lattice(root, (0, 0), 1.2 + (3.4 - 1.2) * 0.12, 1.2, MAST_H * 0.12, FLOOR + 0.3 + MAST_H * 0.88, 1.4, red, r_leg=0.17, r_brace=0.06)
    top = FLOOR + 0.3 + MAST_H
    kit.box('tepe_makarasi', (2.2, 2.2, 1.1), (0, 0, top + 0.55), steel, root, bevel=0.08)
    for y in (-0.5, 0, 0.5):
        kit.cyl('makara', 0.55, 0.15, (0, y, top + 0.6), dark, root, rot=(math.pi / 2, 0, 0))
    kit.rod('paratoner', (0, 0, top + 1.1), (0, 0, top + 2.6), 0.04, dark, root)
    kit.cyl('lamba', 0.18, 0.2, (0, 0, top + 2.6), kit.mat_plain('ikaz', (1, 0.15, 0.05), 0.4, 0, (1, 0.1, 0.02), 6), root)
    # Derikmen platformu (monkeyboard) ~17 m
    mb = FLOOR + 17.0
    kit.box('monkeyboard', (2.8, 3.6, 0.15), (0, -2.0, mb), steel, root)
    for x in (-1.4, 1.4):
        kit.rod('mb_korkuluk', (x, -3.8, mb + 1.0), (x, -0.4, mb + 1.0), 0.03, yellow, root)
    kit.rod('mb_korkuluk', (-1.4, -3.8, mb + 1.0), (1.4, -3.8, mb + 1.0), 0.03, yellow, root)
    for x in (-1.4, 1.4):
        kit.rod('mb_dikme', (x, -3.8, mb), (x, -3.8, mb + 1.0), 0.03, yellow, root)
    # Direkte dizili borular (stand'lar) — derikmenin dizdiği borular
    for i in range(10):
        x = -1.0 + i * 0.22
        kit.rod('boru_stand', (x, -1.1, FLOOR + 0.4), (x * 0.85, -1.6, mb + 0.6), 0.06, steel, root, verts=10)
    # Direk merdiveni
    kit.rod('merdiven', (1.75, 1.75, FLOOR + 0.3), (0.6, 0.6, top), 0.035, yellow, root)
    kit.rod('merdiven', (1.95, 1.55, FLOOR + 0.3), (0.8, 0.4, top), 0.035, yellow, root)

    # Vinç tamburu (drawworks) ve sondajcı kabini (doghouse)
    kit.box('vinc', (3.4, 2.0, 1.6), (0, 3.3, FLOOR + 1.1), blue, root, bevel=0.1)
    kit.cyl('tambur', 0.6, 2.4, (0, 3.3, FLOOR + 1.6), dark, root, rot=(0, math.pi / 2, 0))
    container(root, 'kabin', (6.0, 2.6, 2.6), (6.0, 2.0, FLOOR + 1.6), white, windows=2, door=True)
    kit.box('kabin_ayak', (5.8, 2.4, FLOOR + 0.3), (6.0, 2.0, (FLOOR + 0.3) / 2), red, root, bevel=0.03)
    # V kapısı rampası + boru sehpası + borular
    kit.rod('rampa', (0, -5.0, FLOOR + 0.2), (0, -13.5, 1.0), 0.6, steel, root, square=True)
    for x in (-1.5, 1.5):
        kit.box('sehpa', (0.3, 9.0, 0.9), (x, -17.0, 0.6), steel, root)
    for k in range(18):
        x = -1.3 + (k % 6) * 0.5; z = 1.2 + (k // 6) * 0.42
        kit.cyl('boru', 0.2, 9.5, (x, -17.0, z), steel if k % 3 else orange, root, rot=(math.pi / 2, 0, 0), verts=14)
    # Çamur tankları, sallanan elek, pompa, jeneratörler
    for i in range(3):
        container(root, 'camur_tanki', (3.2, 9.0, 2.4), (-8.5 - i * 3.4, 2.0, 1.35), orange)
        kit.box('camur', (2.8, 8.6, 0.05), (-8.5 - i * 3.4, 2.0, 2.58), mud, root, bevel=0)
    kit.box('elek', (2.2, 2.6, 1.4), (-6.0, 3.0, 3.2), steel, root)
    kit.rod('donus_hatti', (-3.0, 2.0, FLOOR), (-6.0, 3.0, 3.6), 0.15, steel, root)
    container(root, 'pompa', (6.5, 3.0, 2.4), (-9.5, -5.5, 1.35), blue)
    for i, x in enumerate((7.0, 11.0)):
        container(root, 'jenerator', (3.6, 2.6, 2.6), (x, -6.0, 1.45), kit.mat_paint('yesil', (0.08, 0.28, 0.16), 0.5, 0.08))
        kit.cyl('egzoz', 0.15, 1.2, (x + 1.2, -6.0, 3.3), dark, root)
    # Su tankı
    kit.cyl('su_tanki', 1.4, 7.0, (12.0, 3.5, 1.5), white, root, rot=(math.pi / 2, 0, 0))
    # Gergi halatları
    for gx, gy in ((-14, -12), (14, -12), (-14, 12), (14, 12)):
        kit.rod('gergi', (gx * 0.12, gy * 0.12, FLOOR + MAST_H * 0.7), (gx, gy, 0.2), 0.02, cable, root, verts=6)
        kit.box('ankraj', (0.6, 0.6, 0.3), (gx, gy, 0.15), concrete, root)
    return root


def build_block(root):
    """Hareketli makara bloğu, kanca ve sondaj halatları."""
    g = kit.empty('blok', (0, 0, 0), root)
    kit.box('makara_blok', (1.0, 0.8, 1.6), (0, 0, 0), yellow, g, bevel=0.1)
    kit.cyl('kanca', 0.2, 0.9, (0, 0, -1.2), dark, g)
    kit.box('top_drive', (1.2, 1.0, 1.4), (0, 0, -2.3), orange, g, bevel=0.1)
    kit.cyl('kelly', 0.12, 3.0, (0, 0, -4.4), chrome, g)
    lines = [kit.cyl('sondaj_halati', 0.025, 1.0, (0, 0, 0), cable, None, verts=6) for _ in range(4)]
    for ln in lines:
        ln.rotation_mode = 'QUATERNION'
        ln.parent = root
    return g, lines


def place_block(g, lines, z):
    g.location = (0, 0, z)
    top = FLOOR + 0.3 + MAST_H
    for i, ln in enumerate(lines):
        x = -0.3 + i * 0.2
        p1, p2 = Vector((x, 0, top)), Vector((x * 0.7, 0, z + 0.8))
        d = p2 - p1
        ln.location = (p1 + p2) / 2
        ln.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
        ln.scale = (1, 1, d.length)


def main():
    scene = sc.reset(samples=SAMPLES)
    kit._mats.clear()
    init_materials()
    kit.shadow_catcher(80)
    root = build()
    g, lines = build_block(root)
    root.rotation_euler = (0, 0, YAW)
    place_block(g, lines, FLOOR + 14)
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'golge_yakalayici']
    lo, hi = kit.world_bounds(objs)
    lo[2] = 0
    cam, res, _ = kit.frame_camera(scene, lo, hi, pad=1.5)
    out_dir = os.path.join(kit.OUT, 'derrick')
    os.makedirs(out_dir, exist_ok=True)

    # 1) Statik gövde (blok ve halatlar gizli)
    for o in [g, *g.children_recursive, *lines]:
        o.hide_render = True
    scene.render.filepath = os.path.join(out_dir, 'base.png')
    bpy.ops.render.render(write_still=True)

    # 2) Blok katmanı: gövde "holdout" (önündeki parçalar bloğu örter, gölge yok)
    for o in [g, *g.children_recursive, *lines]:
        o.hide_render = False
    holdout = bpy.data.materials.new('holdout'); holdout.use_nodes = True
    nt = holdout.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); ho = nt.nodes.new('ShaderNodeHoldout')
    nt.links.new(ho.outputs[0], out.inputs['Surface'])
    moving = set([g, *g.children_recursive, *lines])
    for o in objs:
        if o not in moving:
            o.data.materials.clear(); o.data.materials.append(holdout)
            o.visible_shadow = False
    bpy.data.objects['golge_yakalayici'].hide_render = True
    zs = []
    for f in range(BLOCK_FRAMES):
        k = 0.5 - 0.5 * math.cos(2 * math.pi * f / BLOCK_FRAMES)
        z = FLOOR + 9.0 + k * 11.0  # blok 14 m - 25 m arası iner/çıkar
        zs.append(z)
        place_block(g, lines, z)
        scene.render.filepath = os.path.join(out_dir, f'block{f:02d}.png')
        bpy.ops.render.render(write_still=True)
    meta = {
        'size': res, 'pxPerM': kit.PX_PER_M, 'blockFrames': BLOCK_FRAMES,
        'anchor': kit.anchor_px(scene, cam, root.matrix_world @ Vector((0, 0, 0))),
        'monkeyboard': kit.anchor_px(scene, cam, root.matrix_world @ Vector((0, -2.0, FLOOR + 17.0))),
        'floor': kit.anchor_px(scene, cam, root.matrix_world @ Vector((0, -3.5, FLOOR + 0.3))),
        'vdoor': kit.anchor_px(scene, cam, root.matrix_world @ Vector((0, -13.5, 0.5))),
    }
    with open(os.path.join(out_dir, 'meta.json'), 'w') as fh:
        json.dump(meta, fh)
    print('ok', meta)


main()
