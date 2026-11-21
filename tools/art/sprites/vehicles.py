"""Ham petrol tankeri (çekici + tanker dorsesi) ve personel minibüsü.
Yollarda her yöne dönebilmeleri için 16 açıdan render edilir."""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy
from mathutils import Vector

import kit
import scene_common as sc

SAMPLES = int(os.environ.get('SAMPLES', 48))
DIRS = int(os.environ.get('DIRS', 16))
WHICH = os.environ.get('WHICH', 'tanker,minibus').split(',')


def init_materials():
    global white, tank, stripe, dark, glass, tire, hub, chrome, red, amber, blue_stripe
    white = kit.mat_paint('beyaz', (0.82, 0.82, 0.80), rough=0.3, rust=0.04, metallic=0.1)
    tank = kit.mat_paint('tank', (0.72, 0.73, 0.74), rough=0.22, rust=0.05, metallic=0.85, scale=0.8)
    stripe = kit.mat_paint('serit', (0.70, 0.08, 0.04), rough=0.35)
    blue_stripe = kit.mat_paint('mavi_serit', (0.04, 0.18, 0.45), rough=0.35)
    dark = kit.mat_paint('sasi', (0.06, 0.06, 0.07), rough=0.6, rust=0.05)
    glass = kit.mat_plain('cam', (0.05, 0.08, 0.10), 0.05, 0.7)
    tire = kit.mat_plain('lastik', (0.025, 0.025, 0.025), 0.85)
    hub = kit.mat_plain('jant', (0.6, 0.6, 0.6), 0.3, 1.0)
    chrome = kit.mat_plain('krom', (0.85, 0.85, 0.85), 0.1, 1.0)
    red = kit.mat_plain('stop', (0.6, 0.02, 0.02), 0.3, 0, (1, 0.05, 0.02), 1.5)
    amber = kit.mat_plain('far', (0.9, 0.85, 0.7), 0.2, 0, (1, 0.9, 0.7), 1.0)


def wheel(root, x, y, r=0.52, w=0.32, double=False):
    for k in ([0, 0.34] if double else [0]):
        yy = y + (k if y > 0 else -k)
        kit.cyl('teker', r, w, (x, yy, r), tire, root, rot=(math.pi / 2, 0, 0), verts=24)
        kit.cyl('jant', r * 0.55, w + 0.02, (x, yy, r), hub, root, rot=(math.pi / 2, 0, 0), verts=16)


def tanker():
    root = kit.empty('kok')
    # Çekici (öne bakan kabin, +x yönü ileri)
    kit.box('sasi', (15.5, 1.0, 0.3), (0.0, 0, 0.95), dark, root)
    cab = kit.box('kabin', (2.2, 2.45, 2.5), (6.6, 0, 2.35), white, root, bevel=0.18)
    kit.box('on_cam', (0.05, 2.1, 1.0), (7.72, 0, 2.85), glass, root, bevel=0.02)
    for s in (-1, 1):
        kit.box('yan_cam', (1.0, 0.04, 0.8), (6.9, s * 1.235, 2.9), glass, root, bevel=0.02)
        kit.box('ayna', (0.08, 0.1, 0.5), (7.6, s * 1.45, 2.8), dark, root)
        kit.box('far', (0.05, 0.4, 0.2), (7.72, s * 0.85, 1.45), amber, root, bevel=0)
    kit.box('tampon', (0.3, 2.45, 0.4), (7.7, 0, 1.2), dark, root, bevel=0.05)
    kit.box('kabin_serit', (2.21, 2.46, 0.18), (6.6, 0, 1.9), stripe, root, bevel=0.05)
    kit.box('spoyler', (1.6, 2.3, 0.6), (6.3, 0, 3.85), white, root, bevel=0.2)
    kit.cyl('egzoz', 0.08, 1.8, (5.35, 1.0, 3.2), chrome, root)
    kit.box('yakit_depo', (1.4, 0.5, 0.6), (4.8, -1.0, 1.1), chrome, root, bevel=0.15)
    wheel(root, 6.5, -1.05); wheel(root, 6.5, 1.05)
    wheel(root, 4.0, -1.05, double=True); wheel(root, 4.0, 1.05, double=True)
    # Tanker dorsesi: eliptik kesitli tank
    t = kit.cyl('tank', 1.25, 10.8, (-1.6, 0, 2.55), tank, root, rot=(0, math.pi / 2, 0), verts=48)
    t.scale = (1.0, 1.05, 0.95)
    for x in (-7.0, 3.8):
        kit.cyl('tank_kapak', 1.2, 0.25, (x, 0, 2.55), tank, root, rot=(0, math.pi / 2, 0), verts=48)
    for x in (-5.5, -3.5, -1.5, 0.5, 2.5):
        kit.cyl('cember', 1.29, 0.12, (x, 0, 2.55), dark, root, rot=(0, math.pi / 2, 0), verts=48)
    kit.box('yurume_yolu', (9.5, 0.6, 0.06), (-1.6, 0, 3.82), dark, root)
    for x in (-5.0, -1.6, 1.8):
        kit.cyl('dom', 0.35, 0.2, (x, 0, 3.85), tank, root)
    kit.box('tank_serit', (10.8, 2.62, 0.22), (-1.6, 0, 2.2), stripe, root, bevel=0)
    for s in (-1, 1):
        kit.box('camurluk', (2.4, 0.4, 0.15), (-5.6, s * 1.05, 1.45), dark, root)
        kit.box('stop', (0.05, 0.3, 0.15), (-7.15, s * 1.0, 1.25), red, root, bevel=0)
    for x in (-6.1, -5.0, -3.9):
        wheel(root, x, -1.05, double=True); wheel(root, x, 1.05, double=True)
    kit.box('vana_kutusu', (1.0, 0.6, 0.5), (-1.6, -1.2, 1.25), dark, root)
    return root


def minibus():
    root = kit.empty('kok')
    body = kit.box('govde', (6.2, 2.05, 2.35), (0, 0, 1.6), white, root, bevel=0.28)
    kit.box('on', (0.9, 2.0, 1.1), (3.15, 0, 1.0), white, root, bevel=0.3)
    kit.box('on_cam', (0.6, 1.9, 0.9), (2.95, 0, 2.15), glass, root, rot=(0, math.radians(-28), 0), bevel=0.05)
    for s in (-1, 1):
        kit.box('cam_bandi', (5.0, 0.04, 0.75), (-0.3, s * 1.03, 2.2), glass, root, bevel=0.03)
        kit.box('serit', (6.0, 0.04, 0.2), (0, s * 1.035, 1.45), blue_stripe, root, bevel=0)
        kit.box('far', (0.05, 0.35, 0.18), (3.6, s * 0.7, 1.1), amber, root, bevel=0)
        kit.box('stop', (0.05, 0.25, 0.4), (-3.12, s * 0.85, 1.4), red, root, bevel=0)
        kit.box('ayna', (0.1, 0.12, 0.3), (2.7, s * 1.2, 2.2), dark, root)
    kit.box('tampon', (0.25, 2.05, 0.3), (3.55, 0, 0.6), dark, root, bevel=0.08)
    kit.box('arka_tampon', (0.25, 2.05, 0.3), (-3.15, 0, 0.6), dark, root, bevel=0.08)
    kit.box('tavan_rafi', (3.5, 1.6, 0.08), (-0.5, 0, 2.85), dark, root)
    kit.cyl('tepe_lambasi', 0.16, 0.14, (0.8, 0, 2.86), kit.mat_plain('ikaz', (1, 0.6, 0.05), 0.3, 0, (1, 0.5, 0.02), 4), root)
    for x in (2.2, -2.0):
        wheel(root, x, -0.95, r=0.38, w=0.24); wheel(root, x, 0.95, r=0.38, w=0.24)
    return root


def render_dirs(name, builder):
    scene = sc.reset(samples=SAMPLES)
    kit._mats.clear()
    init_materials()
    kit.shadow_catcher(40)
    root = builder()
    objs = [o for o in bpy.data.objects if o.type == 'MESH' and o.name != 'golge_yakalayici']
    # Tüm yönleri kapsayan kare çerçeve
    lo, hi = kit.world_bounds(objs)
    rad = max(abs(lo[0]), abs(hi[0]), abs(lo[1]), abs(hi[1]))
    cam, res, _ = kit.frame_camera(scene, (-rad, -rad, 0), (rad, rad, hi[2]), pad=0.8)
    out_dir = os.path.join(kit.OUT, name)
    os.makedirs(out_dir, exist_ok=True)
    for d in range(DIRS):
        # Yön 0 = ekranda sağa (doğu), saat yönünün tersine artar.
        root.rotation_euler = (0, 0, 2 * math.pi * d / DIRS)
        scene.render.filepath = os.path.join(out_dir, f'd{d:02d}.png')
        bpy.ops.render.render(write_still=True)
    meta = {'dirs': DIRS, 'size': res, 'pxPerM': kit.PX_PER_M, 'anchor': kit.anchor_px(scene, cam, (0, 0, 0)),
            'dir0': 'east', 'order': 'counterclockwise'}
    with open(os.path.join(out_dir, 'meta.json'), 'w') as fh:
        json.dump(meta, fh)
    print('ok', name, meta)


if 'tanker' in WHICH:
    render_dirs('tanker', tanker)
if 'minibus' in WHICH:
    render_dirs('minibus', minibus)
