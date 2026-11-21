"""Gerçekçi at kafası (API tipi kiriş pompası), 24 karelik pompa turu.

Gerçek ölçüler (m): kiriş ~7.5, şahmerdan yüksekliği 5.4, krank yarıçapı
0.95. Kiriş açısı dört-çubuk mekanizmasından (krank-biyel-kiriş) hesaplanır;
at başı yayı pivot merkezli olduğundan cilalı çubuk dikey iner.
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

FRAMES = int(os.environ.get('FRAMES', 24))
SAMPLES = int(os.environ.get('SAMPLES', 48))
YAW = math.radians(float(os.environ.get('YAW', -24)))

O = Vector((0, 0, 5.4))        # kiriş pivotu (şahmerdan yatağı)
LF = 4.25                      # pivot → at başı yüzü
A = 3.0                        # pivot → denge (equalizer) yatağı
C = Vector((3.0, 0, 2.55))     # krank mili
R = 0.95                       # krank yarıçapı (biyel pimi)
P = (O.z - C.z)                # biyel uzunluğu
SIDE = 0.74                    # krank kollarının yan mesafesi
WELL_X = -LF

def init_materials():
    global steel, steel_dark, yellow, concrete, red, rubber, chrome, cable, motor_green
    steel = kit.mat_paint('celik', (0.22, 0.26, 0.29), rough=0.5, rust=0.12, scale=1.5)
    steel_dark = kit.mat_paint('koyu_celik', (0.10, 0.11, 0.12), rough=0.55, rust=0.08, scale=1.5)
    yellow = kit.mat_paint('sari', (0.86, 0.56, 0.06), rough=0.42, rust=0.1, scale=1.2)
    concrete = kit.mat_paint('beton', (0.50, 0.48, 0.44), rough=0.95, rust=0.15, metallic=0.0, scale=3)
    red = kit.mat_paint('kirmizi', (0.62, 0.06, 0.04), rough=0.4)
    rubber = kit.mat_plain('kaucuk', (0.02, 0.02, 0.02), 0.7)
    chrome = kit.mat_plain('krom', (0.85, 0.85, 0.85), 0.12, 1.0)
    cable = kit.mat_plain('halat', (0.05, 0.05, 0.05), 0.35, 0.8)
    motor_green = kit.mat_paint('motor', (0.08, 0.22, 0.16), rough=0.45, rust=0.1)


def circle_intersection(c0, r0, c1, r1):
    d = (c1 - c0).length
    a = (r0 * r0 - r1 * r1 + d * d) / (2 * d)
    h = math.sqrt(max(0.0, r0 * r0 - a * a))
    m = c0 + (c1 - c0) * (a / d)
    perp = Vector((-(c1 - c0).z, 0, (c1 - c0).x)) / d
    return m + perp * h, m - perp * h


def kinematics(t):
    th = -2 * math.pi * t + math.pi / 2
    pin = C + Vector((math.cos(th), 0, math.sin(th))) * R
    e1, e2 = circle_intersection(O, A, pin, P)
    e = e1 if e1.x > e2.x else e2
    phi = math.atan2(e.z - O.z, e.x - O.x)
    return th, pin, e, phi


def build():
    root = kit.empty('kok')
    # Beton kaide ve kuyu başı kaidesi
    kit.box('kaide', (10.6, 3.2, 0.32), (0.4, 0, 0.16), concrete, root, bevel=0.06)
    kit.box('kuyu_kaide', (1.8, 1.8, 0.2), (WELL_X, 0, 0.42), concrete, root, bevel=0.05)
    # Çelik kızaklar (I-profil)
    for y in (-0.75, 0.75):
        kit.box('kizak', (8.0, 0.22, 0.34), (0.9, y, 0.49), steel_dark, root)
        kit.box('kizak_ust', (8.0, 0.36, 0.05), (0.9, y, 0.66), steel_dark, root)
    for x in (-1.6, 0.4, 2.2, 4.0):
        kit.box('travers', (0.18, 1.7, 0.18), (x, 0, 0.6), steel_dark, root)

    # Şahmerdan direği (A-çerçeve): 4 bacak + çaprazlar
    top = O + Vector((0, 0, -0.25))
    legs = [(-1.5, -1.05), (-1.5, 1.05), (1.25, -1.05), (1.25, 1.05)]
    for lx, ly in legs:
        kit.rod('bacak', (lx, ly * 1.0, 0.68), (top.x + lx * 0.06, ly * 0.32, top.z), 0.11, steel, root, square=True)
    for ly in (-1, 1):
        kit.rod('capraz', (-1.35, ly * 0.95, 1.2), (1.1, ly * 0.95 * 0.6, 3.6), 0.05, steel, root, square=True)
        kit.rod('capraz', (1.1, ly * 0.95, 1.2), (-1.0, ly * 0.95 * 0.6, 3.6), 0.05, steel, root, square=True)
        kit.rod('yatay', (-1.25, ly * 0.86, 2.4), (1.05, ly * 0.86, 2.4), 0.05, steel, root, square=True)
    kit.box('yatak', (0.7, 0.9, 0.35), (0, 0, top.z), steel_dark, root)
    # Merdiven (arka bacakta)
    for s in (-0.2, 0.2):
        kit.rod('merdiven', (1.45, 1.15 + s * 0.2, 0.68), (0.35, 0.55 + s * 0.2, 4.9), 0.025, yellow, root)
    for i in range(12):
        k = (i + 1) / 13
        p = Vector((1.45, 1.15, 0.68)).lerp(Vector((0.35, 0.55, 4.9)), k)
        kit.rod('basamak', (p.x, p.y - 0.06, p.z), (p.x, p.y + 0.06, p.z), 0.018, yellow, root)

    # Redüktör (dişli kutusu) ve kaidesi
    kit.box('redüktör_kaide', (1.9, 1.3, 0.5), (C.x, 0, 0.92), steel_dark, root)
    gb = kit.box('redüktör', (1.6, 1.05, 1.05), (C.x, 0, C.z - 0.5), steel, root, bevel=0.08)
    kit.cyl('redüktör_kapak', 0.62, 1.12, (C.x, 0, C.z - 0.15), steel, root, rot=(math.pi / 2, 0, 0))
    kit.cyl('mil', 0.13, 2.0, (C.x, 0, C.z), chrome, root, rot=(math.pi / 2, 0, 0))
    # Motor, kayış muhafazası, fren kolu
    kit.box('motor_ray', (1.6, 0.9, 0.12), (5.2, 0.15, 0.75), steel_dark, root)
    kit.cyl('motor', 0.42, 1.0, (5.25, 0.15, 1.25), motor_green, root, rot=(math.pi / 2, 0, 0))
    for k in range(8):
        kit.box('motor_kanat', (0.9, 0.04, 0.05), (5.25, 0.15 - 0.45 + k * 0.13, 1.68), motor_green, root, bevel=0)
    kit.box('motor_kutu', (0.35, 0.3, 0.3), (5.3, 0.6, 1.7), motor_green, root)
    guard = kit.box('kayis_muhafaza', (2.7, 0.18, 0.95), (4.25, -0.78, 1.55), yellow, root, rot=(0, math.radians(-8), 0), bevel=0.15)
    kit.rod('fren_kolu', (2.1, -0.95, 0.7), (1.8, -0.95, 1.9), 0.035, red, root)
    kit.cyl('fren_topuz', 0.07, 0.1, (1.8, -0.95, 1.95), rubber, root)

    # Krank kolları ve karşı ağırlıklar (dönen grup)
    crank = kit.empty('krank', tuple(C), root)
    for s in (-1, 1):
        y = s * SIDE
        kit.box('krank_kol', (2.0, 0.14, 0.42), (C.x + 0.45, y, C.z), steel, crank, bevel=0.04)
        build_counterweight(crank, y + s * 0.13, s)
        kit.cyl('pim', 0.09, 0.32, (C.x + R, y, C.z), chrome, crank, rot=(math.pi / 2, 0, 0))

    # Kiriş grubu (pivot etrafında döner)
    beam = kit.empty('kiris', tuple(O), root)
    kit.box('kiris_govde', (7.4, 0.12, 0.5), (O.x - 0.55, 0, O.z), steel, beam)
    for z in (0.25, -0.25):
        kit.box('kiris_flans', (7.4, 0.38, 0.06), (O.x - 0.55, 0, O.z + z), steel, beam)
    kit.box('denge_yatagi', (0.45, 1.75, 0.3), (O.x + A, 0, O.z - 0.25), steel_dark, beam)
    kit.cyl('denge_mili', 0.08, 1.9, (O.x + A, 0, O.z - 0.32), chrome, beam, rot=(math.pi / 2, 0, 0))
    # At başı: pivot merkezli yay yüzü
    build_horsehead(beam)

    # Biyel kolları (her karede konumlanır)
    pitmans = [kit.cyl('biyel', 0.075, 1.0, (0, 0, 0), steel, None, verts=12) for _ in (0, 1)]
    for p in pitmans:
        p.rotation_mode = 'QUATERNION'
        p.parent = root

    # Kuyu başı (christmas tree)
    wh = Vector((WELL_X, 0, 0.52))
    kit.cyl('muhafaza', 0.24, 0.3, (wh.x, 0, wh.z + 0.15), steel_dark, root)
    kit.cyl('flans', 0.33, 0.08, (wh.x, 0, wh.z + 0.32), steel, root)
    kit.cyl('govde', 0.14, 0.7, (wh.x, 0, wh.z + 0.7), red, root)
    kit.cyl('flans2', 0.26, 0.07, (wh.x, 0, wh.z + 1.05), steel, root)
    kit.cyl('salmastra', 0.11, 0.25, (wh.x, 0, wh.z + 1.2), steel_dark, root)
    for s in (-1, 1):
        kit.rod('kanat', (wh.x, 0, wh.z + 0.65), (wh.x, s * 0.75, wh.z + 0.65), 0.075, red, root)
        kit.cyl('vana_teker', 0.17, 0.04, (wh.x, s * 0.45, wh.z + 0.92), red, root)
        kit.rod('vana_mil', (wh.x, s * 0.45, wh.z + 0.65), (wh.x, s * 0.45, wh.z + 0.92), 0.02, steel, root)
    kit.rod('akis_hatti', (wh.x, 0.75, wh.z + 0.65), (wh.x + 2.0, 1.6, 0.25), 0.07, steel_dark, root)
    kit.cyl('manometre', 0.09, 0.04, (wh.x + 0.18, -0.2, wh.z + 0.95), kit.mat_plain('kadran', (0.9, 0.9, 0.85), 0.3),
            root, rot=(math.pi / 2, 0, 0))

    # Taşıyıcı çubuk + halatlar + cilalı çubuk (her karede)
    carrier = kit.box('tasiyici', (0.22, 0.75, 0.12), (WELL_X, 0, 3.0), steel_dark, root)
    wires = [kit.cyl('halat', 0.018, 1.0, (0, 0, 0), cable, None, verts=8) for _ in (0, 1)]
    prod = kit.cyl('cilali_cubuk', 0.035, 1.0, (0, 0, 0), chrome, None, verts=12)
    for w in wires + [prod]:
        w.rotation_mode = 'QUATERNION'
        w.parent = root

    # Güvenlik korkuluğu (krank çevresi)
    rail_pts = [(1.85, -1.45), (6.0, -1.45), (6.0, 1.45), (1.85, 1.45)]
    for (x0, y0), (x1, y1) in zip(rail_pts, rail_pts[1:] + rail_pts[:1]):
        if (x0, y0) == (1.85, 1.45):
            continue
        for h in (0.75, 1.3):
            kit.rod('korkuluk', (x0, y0, h), (x1, y1, h), 0.03, yellow, root)
        n = max(1, int(math.hypot(x1 - x0, y1 - y0) / 1.0))
        for i in range(n + 1):
            x, y = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
            kit.rod('dikme', (x, y, 0.32), (x, y, 1.32), 0.035, yellow, root)
    return dict(root=root, crank=crank, beam=beam, pitmans=pitmans, carrier=carrier, wires=wires, prod=prod)


def build_counterweight(crank, y, s):
    """Dilim (sektör) biçimli dökme karşı ağırlık, krank kolunun dış ucunda."""
    import bmesh

    bm = bmesh.new()
    r0, r1, half = 0.75, 1.75, math.radians(26)
    prof = []
    for i in range(9):
        a = -half + 2 * half * i / 8
        prof.append((C.x + r1 * math.cos(a), C.z + r1 * math.sin(a)))
    prof += [(C.x + r0 * math.cos(half), C.z + r0 * math.sin(half)), (C.x + r0 * math.cos(-half), C.z + r0 * math.sin(-half))][::-1][::-1]
    prof = prof[:9] + [(C.x + r0 * math.cos(half), C.z + r0 * math.sin(half)), (C.x + r0 * math.cos(-half), C.z + r0 * math.sin(-half))]
    k = len(prof)
    for yy in (y - 0.11, y + 0.11):
        vs = [bm.verts.new((x, yy, z)) for x, z in prof]
        bm.faces.new(vs)
    bm.verts.ensure_lookup_table()
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new([bm.verts[i], bm.verts[j], bm.verts[k + j], bm.verts[k + i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new('agirlik')
    bm.to_mesh(me)
    ob = bpy.data.objects.new('agirlik', me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(steel_dark)
    md = ob.modifiers.new('bevel', 'BEVEL'); md.width = 0.04; md.segments = 2
    kit._parent_keep(ob, crank)


def build_horsehead(beam):
    import bmesh

    me = bpy.data.meshes.new('at_basi')
    bm = bmesh.new()
    span = math.radians(19)
    n = 18
    pts = []
    for i in range(n + 1):
        a = math.pi - span + 2 * span * i / n
        pts.append((O.x + LF * math.cos(a), O.z + LF * math.sin(a)))
    # Arka kısım kirişe bağlanır
    back = [(O.x - 2.9, O.z - 0.5), (O.x - 2.9, O.z + 0.55)]
    poly = pts + back[::-1][::-1]
    poly = pts + [back[1], back[0]] if False else pts + [(O.x - 2.9, O.z + 0.6), (O.x - 2.9, O.z - 0.55)]
    # Yay üstten alta, sonra kirişe dönen arka kenar (alt → üst): kendini kesmez.
    poly = pts + [(O.x - 2.75, O.z - 0.55), (O.x - 2.75, O.z + 0.6)]
    for y in (-0.26, 0.26):
        vs = [bm.verts.new((x, y, z)) for x, z in poly]
        bm.faces.new(vs if y > 0 else vs[::-1])
    bm.verts.ensure_lookup_table()
    k = len(poly)
    for i in range(k):
        j = (i + 1) % k
        bm.faces.new([bm.verts[i], bm.verts[j], bm.verts[k + j], bm.verts[k + i]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    ob = bpy.data.objects.new('at_basi', me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(yellow)
    md = ob.modifiers.new('bevel', 'BEVEL'); md.width = 0.04; md.segments = 2
    kit._parent_keep(ob, beam)
    # Yay yüzündeki halat oluğu (koyu şerit)
    for y in (-0.12, 0.12):
        for i in range(n):
            a0 = math.pi - span + 2 * span * i / n; a1 = a0 + 2 * span / n
            p0 = (O.x + (LF + 0.01) * math.cos(a0), y, O.z + (LF + 0.01) * math.sin(a0))
            p1 = (O.x + (LF + 0.01) * math.cos(a1), y, O.z + (LF + 0.01) * math.sin(a1))
            kit.rod('oluk', p0, p1, 0.03, cable, beam, verts=6)


def place_rod(ob, p1, p2):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    ob.location = (p1 + p2) / 2
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.scale = (1, 1, d.length)


def pose(parts, t, phi0):
    th, pin, e, phi = kinematics(t)
    parts['crank'].rotation_euler = (0, -(th - math.pi / 2), 0)
    parts['beam'].rotation_euler = (0, -phi, 0)
    for s, p in zip((-1, 1), parts['pitmans']):
        place_rod(p, (pin.x, s * SIDE, pin.z), (e.x, s * SIDE * 0.95, e.z - 0.05))
    # At başı yayından inen halat: çubuk dikey iner, yer değiştirme = yay uzunluğu
    cz = 2.9 - LF * (phi - phi0)
    parts['carrier'].location = (WELL_X, 0, cz)
    for s, w in zip((-1, 1), parts['wires']):
        place_rod(w, (WELL_X - 0.02, s * 0.12, O.z), (WELL_X, s * 0.12, cz + 0.05))
    place_rod(parts['prod'], (WELL_X, 0, cz + 0.4), (WELL_X, 0, 1.75))


def main():
    scene = sc.reset(samples=SAMPLES)
    kit._mats.clear()
    init_materials()
    kit.shadow_catcher()
    parts = build()
    parts['root'].rotation_euler = (0, 0, YAW)
    phis = [kinematics(i / 36)[3] for i in range(36)]
    phi0 = sum(phis) / len(phis)
    # Kamerayı tüm tur boyunca kapsayacak şekilde ayarla
    pose(parts, 0.0, phi0)
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'golge_yakalayici']
    lo, hi = kit.world_bounds(objs)
    lo[2] = 0; hi[2] += 1.4
    lo[0] -= 0.5; hi[0] += 0.5
    cam, res, _ = kit.frame_camera(scene, lo, hi, pad=1.0)
    out_dir = os.path.join(kit.OUT, 'pumpjack')
    os.makedirs(out_dir, exist_ok=True)
    for f in range(FRAMES):
        pose(parts, f / FRAMES, phi0)
        scene.render.filepath = os.path.join(out_dir, f'f{f:02d}.png')
        bpy.ops.render.render(write_still=True)
    meta = {
        'frames': FRAMES, 'size': res, 'pxPerM': kit.PX_PER_M,
        'anchor': kit.anchor_px(scene, cam, (0.4, 0, 0)),
        'wellhead': kit.anchor_px(scene, cam, parts['root'].matrix_world @ Vector((WELL_X, 0, 0.5))),
    }
    with open(os.path.join(out_dir, 'meta.json'), 'w') as fh:
        json.dump(meta, fh)
    print('ok', meta)


main()
