"""Rafineri, akaryakıt alım/dağıtım merkezi (pazarlamacı) ve işçi lojmanları.
Büyük tesisler: düşük ölçekte (PX metre başına piksel) tek kare render."""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
import numpy as np

import kit
import scene_common as sc

SAMPLES = int(os.environ.get('SAMPLES', 64))
WHICH = os.environ.get('WHICH', 'refinery,depot,camp').split(',')


def init_materials():
    global M
    M = dict(
        white=kit.mat_paint('beyaz', (0.80, 0.80, 0.77), 0.45, 0.02, 0.2, 0.5),
        silver=kit.mat_paint('gumus', (0.62, 0.63, 0.64), 0.3, 0.06, 0.8, 0.5),
        steel=kit.mat_paint('celik', (0.24, 0.27, 0.30), 0.5, 0.12, 0.4, 1.0),
        dark=kit.mat_paint('koyu', (0.08, 0.09, 0.10), 0.6, 0.05),
        red=kit.mat_paint('kirmizi', (0.55, 0.07, 0.04), 0.45, 0.06),
        yellow=kit.mat_paint('sari', (0.86, 0.56, 0.06), 0.42, 0.06),
        concrete=kit.mat_paint('beton', (0.46, 0.45, 0.42), 0.95, 0.03, 0.0, 0.3),
        asphalt=kit.mat_paint('asfalt', (0.12, 0.12, 0.12), 0.9, 0.1, 0.0, 0.4),
        green=kit.mat_paint('yesil', (0.10, 0.25, 0.16), 0.5, 0.05),
        blue=kit.mat_paint('mavi', (0.06, 0.18, 0.40), 0.4, 0.05),
        glass=kit.mat_plain('cam', (0.06, 0.10, 0.14), 0.06, 0.6),
        roof=kit.mat_paint('kiremit', (0.45, 0.17, 0.10), 0.8, 0.1, 0.0, 0.6),
        wall=kit.mat_paint('duvar', (0.74, 0.66, 0.52), 0.9, 0.08, 0.0, 0.5),
        tree=kit.mat_paint('agac', (0.10, 0.18, 0.06), 0.9, 0.3, 0.0, 2.0),
        trunk=kit.mat_plain('govde', (0.18, 0.12, 0.07), 0.9),
        flame=kit.mat_plain('alev', (1.0, 0.45, 0.08), 0.5, 0, (1.0, 0.42, 0.06), 18),
        lamp=kit.mat_plain('isik', (1.0, 0.8, 0.5), 0.5, 0, (1.0, 0.75, 0.4), 3),
    )


def ring_platforms(root, x, y, r, h, step, mat):
    z = step
    while z < h - 1:
        kit.cyl('platform', r + 0.9, 0.18, (x, y, z), mat, root, verts=32)
        z += step


def column(root, x, y, r, h, mat):
    kit.cyl('kolon', r, h, (x, y, h / 2), mat, root, verts=40)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, h), segments=32, ring_count=12)
    cap = bpy.context.active_object; cap.scale = (1, 1, 0.45); cap.data.materials.append(mat); kit._parent_keep(cap, root)
    ring_platforms(root, x, y, r, h, 7.0, M['yellow'])
    kit.rod('merdiven', (x + r + 0.5, y - 0.4, 0), (x + r + 0.5, y - 0.4, h), 0.12, M['yellow'], root, square=True)
    kit.rod('boru', (x - r - 0.6, y, 2), (x - r - 0.6, y, h * 0.9), 0.35, M['steel'], root)


def tank(root, x, y, r, h, mat, stairs=True):
    kit.cyl('tank', r, h, (x, y, h / 2), mat, root, verts=56)
    kit.cyl('tank_cati', r * 1.01, 0.4, (x, y, h - 0.1), M['silver'], root, verts=56)
    kit.cyl('tank_halka', r * 1.02, 0.5, (x, y, h * 0.5), M['steel'], root, verts=56)
    kit.cyl('havuz', r * 1.35, 0.25, (x, y, 0.12), M['concrete'], root, verts=56)
    if stairs:
        a0, a1 = math.radians(200), math.radians(320)
        p0 = (x + (r + 0.6) * math.cos(a0), y + (r + 0.6) * math.sin(a0), 0.3)
        p1 = (x + (r + 0.6) * math.cos(a1), y + (r + 0.6) * math.sin(a1), h)
        kit.rod('merdiven', p0, p1, 0.25, M['yellow'], root, square=True)


def sphere_tank(root, x, y, r, mat):
    for k in range(8):
        a = k * math.pi / 4
        kit.rod('ayak', (x + r * 0.8 * math.cos(a), y + r * 0.8 * math.sin(a), 0), (x + r * 0.8 * math.cos(a), y + r * 0.8 * math.sin(a), r + 1.5), 0.35, M['steel'], root)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, r + 2.5), segments=40, ring_count=20)
    s = bpy.context.active_object; s.data.materials.append(mat); bpy.ops.object.shade_smooth(); kit._parent_keep(s, root)
    kit.cyl('kusak', r * 1.005, 0.4, (x, y, r + 2.5), M['steel'], root, verts=48)


def stack(root, x, y, r, h):
    kit.cyl('baca', r, h, (x, y, h / 2), M['white'], root, verts=28)
    for z in (h - 4, h - 12):
        kit.cyl('bant', r * 1.03, 3.0, (x, y, z), M['red'], root, verts=28)


def tree(root, x, y, s=1.0):
    kit.cyl('agac_govde', 0.25 * s, 3 * s, (x, y, 1.5 * s), M['trunk'], root, verts=8)
    bpy.ops.mesh.primitive_ico_sphere_add(radius=2.4 * s, location=(x, y, 4.2 * s), subdivisions=2)
    t = bpy.context.active_object; t.scale = (1, 1, 1.15); t.data.materials.append(M['tree']); kit._parent_keep(t, root)


def pipe_rack(root, x0, x1, y, h, n_pipes=6):
    for x in np.arange(x0, x1 + 0.1, 8):
        for yy in (y - 2, y + 2):
            kit.rod('rack_ayak', (x, yy, 0), (x, yy, h), 0.3, M['steel'], root, square=True)
        kit.rod('rack_kiris', (x, y - 2.2, h), (x, y + 2.2, h), 0.3, M['steel'], root, square=True)
    for i in range(n_pipes):
        yy = y - 1.8 + i * 3.6 / (n_pipes - 1)
        mat = [M['silver'], M['steel'], M['yellow'], M['silver'], M['green'], M['steel']][i % 6]
        kit.rod('boru', (x0, yy, h + 0.45), (x1, yy, h + 0.45), 0.32, mat, root)


def refinery():
    root = kit.empty('kok')
    kit.box('saha', (150, 110, 0.3), (0, 0, 0.15), M['concrete'], root, bevel=0.5)
    for (x, y, w, d) in [(0, -50, 150, 6), (-70, 0, 6, 110), (20, 0, 4, 100)]:
        kit.box('yol', (w, d, 0.05), (x, y, 0.32), M['asphalt'], root, bevel=0)
    # Ham petrol damıtma ünitesi
    column(root, -20, 12, 3.2, 52, M['silver'])
    column(root, -8, 14, 2.4, 38, M['silver'])
    column(root, 2, 16, 1.8, 30, M['white'])
    kit.box('firin', (16, 10, 14), (-26, -8, 7), M['steel'], root, bevel=0.3)
    kit.box('firin_ust', (16.5, 10.5, 1.0), (-26, -8, 14.2), M['dark'], root, bevel=0.1)
    stack(root, -32, -8, 1.6, 60)
    stack(root, -21, -8, 1.3, 48)
    # Boru köprüsü
    pipe_rack(root, -60, 40, 0, 7)
    kit.box('kompresor', (12, 8, 6), (10, -14, 3), M['blue'], root, bevel=0.3)
    # Soğutma kulesi
    for i in range(4):
        kit.box('sogutma', (9, 9, 9), (-55 + i * 9.5, 30, 4.5), M['concrete'], root, bevel=0.2)
        kit.cyl('fan', 3.4, 1.2, (-55 + i * 9.5, 30, 9.6), M['steel'], root, verts=24)
    # Depolama tankları ve LPG küreleri
    for (x, y, r, h) in [(34, 26, 11, 15), (58, 26, 11, 15), (34, -6, 9, 13), (58, -6, 9, 13), (34, -32, 8, 12), (58, -32, 8, 12)]:
        tank(root, x, y, r, h, M['white'])
    sphere_tank(root, -50, -28, 7, M['white'])
    sphere_tank(root, -32, -32, 7, M['white'])
    # Meşale (flare) ve alevi
    kit.rod('mesale', (66, 46, 0), (66, 46, 64), 0.9, M['steel'], root)
    for k in range(3):
        a = k * 2 * math.pi / 3
        kit.rod('gergi', (66, 46, 50), (66 + 14 * math.cos(a), 46 + 14 * math.sin(a), 0), 0.08, M['dark'], root, verts=6)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=2.0, location=(66, 46, 67), segments=16, ring_count=10)
    f = bpy.context.active_object; f.scale = (0.8, 0.8, 2.0); f.data.materials.append(M['flame']); kit._parent_keep(f, root)
    # Yönetim binası ve tanker dolum peronu
    kit.box('bina', (24, 12, 9), (-50, -45, 4.5), M['wall'], root, bevel=0.2)
    for i in range(6):
        kit.box('pencere', (2.6, 0.1, 1.6), (-60 + i * 4, -51.05, 5.5), M['glass'], root, bevel=0)
    kit.box('dolum_cati', (26, 12, 0.6), (5, -40, 7), M['white'], root, bevel=0.1)
    for x in (-7, 1, 9, 17):
        for y in (-45, -35):
            kit.rod('dolum_ayak', (x, y, 0), (x, y, 7), 0.25, M['steel'], root, square=True)
    for k in range(6):
        tree(root, -70 + k * 9, -55, 1.0)
    return root


def depot():
    root = kit.empty('kok')
    kit.box('saha', (70, 50, 0.3), (0, 0, 0.15), M['concrete'], root, bevel=0.4)
    for (x, y, r, h) in [(-20, 10, 7, 10), (-4, 10, 7, 10), (12, 10, 6, 9)]:
        tank(root, x, y, r, h, M['white'])
    kit.box('peron_cati', (22, 10, 0.5), (8, -12, 6), M['red'], root, bevel=0.1)
    for x in (-2, 8, 18):
        for y in (-16, -8):
            kit.rod('peron_ayak', (x, y, 0), (x, y, 6), 0.22, M['steel'], root, square=True)
    kit.box('ofis', (14, 9, 6), (-22, -14, 3), M['wall'], root, bevel=0.2)
    kit.box('ofis_cati', (14.6, 9.6, 0.4), (-22, -14, 6.2), M['red'], root, bevel=0.1)
    for i in range(3):
        kit.box('pencere', (2.2, 0.1, 1.4), (-26 + i * 4, -18.55, 3.5), M['glass'], root, bevel=0)
    kit.rod('direk', (28, -20, 0), (28, -20, 14), 0.25, M['steel'], root)
    kit.box('tabela', (8, 0.5, 3), (28, -20, 15.5), M['blue'], root, bevel=0.1)
    for k in range(5):
        tree(root, -32 + k * 6, 22, 0.8)
    return root


def camp():
    """İşçi lojmanları: kiremit çatılı bloklar, ağaçlar, servis otoparkı."""
    root = kit.empty('kok')
    kit.box('saha', (80, 60, 0.3), (0, 0, 0.15), kit.mat_paint('cim', (0.22, 0.28, 0.10), 0.95, 0.4, 0, 1.5), root, bevel=0.4)
    kit.box('otopark', (30, 14, 0.06), (20, -20, 0.33), M['asphalt'], root, bevel=0)
    for i in range(3):
        for j in range(2):
            x, y = -26 + i * 18, 12 - j * 22
            kit.box('blok', (14, 9, 7), (x, y, 3.5), M['wall'], root, bevel=0.15)
            bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=9.0, depth=3.0, location=(x, y, 8.5), rotation=(0, 0, math.pi / 4))
            r = bpy.context.active_object; r.scale = (1.1, 0.75, 1); r.data.materials.append(M['roof']); kit._parent_keep(r, root)
            for k in range(3):
                for fl in (2.0, 5.0):
                    kit.box('pencere', (1.8, 0.1, 1.2), (x - 4 + k * 4, y - 4.55, fl), M['glass'], root, bevel=0)
    for k in range(14):
        tree(root, -38 + (k % 7) * 12, 26 if k < 7 else -28, 0.9)
    kit.rod('bayrak_diregi', (34, 20, 0), (34, 20, 14), 0.12, M['silver'], root)
    return root


def render(name, builder, px):
    scene = sc.reset(samples=SAMPLES)
    kit._mats.clear()
    init_materials()
    kit.PX_PER_M = px
    kit.shadow_catcher(400)
    root = builder()
    root.rotation_euler = (0, 0, math.radians(12))
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'golge_yakalayici']
    lo, hi = kit.world_bounds(objs)
    lo[2] = 0
    cam, res, _ = kit.frame_camera(scene, lo, hi, pad=6)
    out_dir = os.path.join(kit.OUT, name)
    os.makedirs(out_dir, exist_ok=True)
    scene.render.filepath = os.path.join(out_dir, 'base.png')
    bpy.ops.render.render(write_still=True)
    meta = {'size': res, 'pxPerM': px, 'anchor': kit.anchor_px(scene, cam, (0, 0, 0))}
    with open(os.path.join(out_dir, 'meta.json'), 'w') as fh:
        json.dump(meta, fh)
    print('ok', name, meta)


if 'refinery' in WHICH:
    render('refinery', refinery, 6)
if 'depot' in WHICH:
    render('depot', depot, 8)
if 'camp' in WHICH:
    render('camp', camp, 8)
