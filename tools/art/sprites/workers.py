"""Saha işçisi: tulum, reflektör şeritler, iş botu, baret.
8 yön x (8 yürüme karesi + 1 duruş). Baret beyaz render edilir; ayrıca bir
baret maskesi alınır ve paketlemede her rolün rengine boyanır."""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import bpy

import kit
import scene_common as sc

SAMPLES = int(os.environ.get('SAMPLES', 32))
DIRS = 8
WALK = 8
PX = 48  # işçiler daha net olsun diye iki kat çözünürlük


def init_materials():
    global coverall, band, boots, skin, helmet, glove, hair
    coverall = kit.mat_paint('tulum', (0.05, 0.10, 0.24), rough=0.85, rust=0.1, metallic=0.0, scale=3)
    band = kit.mat_plain('reflektor', (0.85, 0.85, 0.8), 0.25, 0.6)
    boots = kit.mat_plain('bot', (0.07, 0.05, 0.03), 0.6)
    skin = kit.mat_plain('ten', (0.55, 0.36, 0.25), 0.55)
    helmet = kit.mat_plain('baret', (0.9, 0.9, 0.88), 0.3)
    glove = kit.mat_plain('eldiven', (0.75, 0.6, 0.2), 0.8)
    hair = kit.mat_plain('sac', (0.05, 0.04, 0.03), 0.7)


def build():
    root = kit.empty('kok')
    hips = {}
    for s in (-1, 1):
        hip = kit.empty('kalca', (0, s * 0.11, 0.93), root)
        kit.cyl('uyluk', 0.085, 0.46, (0, s * 0.11, 0.70), coverall, hip, verts=12)
        knee = kit.empty('diz', (0, s * 0.11, 0.47), hip)
        kit.cyl('baldir', 0.075, 0.42, (0, s * 0.11, 0.27), coverall, knee, verts=12)
        kit.box('bant', (0.17, 0.17, 0.05), (0, s * 0.11, 0.33), band, knee, bevel=0)
        kit.box('bot', (0.28, 0.13, 0.11), (0.05, s * 0.11, 0.055), boots, knee, bevel=0.03)
        hips[s] = (hip, knee)
    torso = kit.box('govde', (0.26, 0.42, 0.58), (0, 0, 1.22), coverall, root, bevel=0.07)
    kit.box('gogus_bandi', (0.27, 0.43, 0.05), (0, 0, 1.32), band, root, bevel=0)
    kit.box('bel', (0.27, 0.43, 0.06), (0, 0, 0.98), kit.mat_plain('kemer', (0.03, 0.03, 0.03), 0.6), root, bevel=0)
    arms = {}
    for s in (-1, 1):
        sh = kit.empty('omuz', (0, s * 0.26, 1.46), root)
        kit.cyl('kol', 0.06, 0.32, (0, s * 0.27, 1.29), coverall, sh, verts=10)
        el = kit.empty('dirsek', (0, s * 0.27, 1.13), sh)
        kit.cyl('onkol', 0.055, 0.28, (0, s * 0.27, 0.99), coverall, el, verts=10)
        kit.cyl('el', 0.05, 0.1, (0, s * 0.27, 0.82), glove, el, verts=10)
        arms[s] = (sh, el)
    kit.cyl('boyun', 0.05, 0.1, (0, 0, 1.55), skin, root, verts=10)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=(0.01, 0, 1.65), segments=20, ring_count=12)
    head = bpy.context.active_object; head.data.materials.append(skin); bpy.ops.object.shade_smooth(); kit._parent_keep(head, root)
    kit.box('biyik', (0.02, 0.08, 0.02), (0.11, 0, 1.61), hair, root, bevel=0)
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.135, location=(0, 0, 1.70), segments=24, ring_count=12)
    hat = bpy.context.active_object; hat.scale = (1.08, 1.0, 0.8)
    hat.data.materials.append(helmet); bpy.ops.object.shade_smooth(); kit._parent_keep(hat, root)
    brim = kit.cyl('siperlik', 0.17, 0.02, (0.03, 0, 1.69), helmet, root, verts=24)
    brim.scale = (1.15, 1.0, 1.0)
    return root, hips, arms, [hat, brim]


def pose(hips, arms, phase, walking):
    a = math.sin(2 * math.pi * phase) if walking else 0.0
    for s in (-1, 1):
        hip, knee = hips[s]
        swing = s * a * math.radians(28)
        hip.rotation_euler = (0, swing, 0)
        bend = max(0.0, -s * math.cos(2 * math.pi * phase)) * math.radians(35) if walking else 0.0
        knee.rotation_euler = (0, bend, 0)
        sh, el = arms[s]
        sh.rotation_euler = (0, -swing * 0.8, 0)
        el.rotation_euler = (0, -math.radians(15) if walking else -math.radians(5), 0)


def main():
    scene = sc.reset(samples=SAMPLES)
    kit._mats.clear()
    init_materials()
    kit.PX_PER_M = PX
    catcher = kit.shadow_catcher(10)
    root, hips, arms, hat_parts = build()
    cam, res, _ = kit.frame_camera(scene, (-0.9, -0.9, 0), (0.9, 0.9, 1.9), pad=0.15)
    out_dir = os.path.join(kit.OUT, 'worker')
    os.makedirs(out_dir, exist_ok=True)

    def render_all(prefix):
        for d in range(DIRS):
            root.rotation_euler = (0, 0, 2 * math.pi * d / DIRS)
            for f in range(WALK + 1):
                walking = f < WALK
                pose(hips, arms, f / WALK, walking)
                scene.render.filepath = os.path.join(out_dir, f'{prefix}_d{d}_f{f}.png')
                bpy.ops.render.render(write_still=True)

    render_all('base')
    # Baret maskesi: baret parlak beyaz, diğer her şey holdout (örtme korunur)
    holdout = bpy.data.materials.new('holdout'); holdout.use_nodes = True
    nt = holdout.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); h = nt.nodes.new('ShaderNodeHoldout')
    nt.links.new(h.outputs[0], o.inputs['Surface'])
    em = bpy.data.materials.new('maske'); em.use_nodes = True
    nt = em.node_tree; nt.nodes.clear()
    o = nt.nodes.new('ShaderNodeOutputMaterial'); e = nt.nodes.new('ShaderNodeEmission')
    e.inputs['Strength'].default_value = 1.0
    nt.links.new(e.outputs[0], o.inputs['Surface'])
    for ob in bpy.data.objects:
        if ob.type != 'MESH' or ob == catcher:
            continue
        ob.data.materials.clear()
        ob.data.materials.append(em if ob in hat_parts else holdout)
    catcher.hide_render = True
    scene.cycles.samples = 8
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    render_all('mask')
    meta = {'dirs': DIRS, 'walkFrames': WALK, 'idleFrame': WALK, 'size': res, 'pxPerM': PX,
            'anchor': kit.anchor_px(scene, cam, (0, 0, 0)), 'dir0': 'east', 'order': 'counterclockwise'}
    with open(os.path.join(out_dir, 'meta.json'), 'w') as fh:
        json.dump(meta, fh)
    print('ok', meta)


main()
