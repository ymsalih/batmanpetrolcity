"""Tüm render'larda ortak kamera ve ışık: harita ile sprite'lar aynı açıdan,
aynı güneşle çizilir; böylece sprite'lar haritaya kusursuz oturur."""
import math

import bpy

# Kamera güneyden kuzeye, 45° aşağı bakar (ortografik, perspektifsiz).
CAM_TILT = math.radians(45)
# Güneş batı-güneybatıda, ufkun 32° üstünde: ikindi ışığı, uzun gölgeler.
SUN_ROT = (math.radians(58), 0.0, math.radians(-70))
SUN_COLOR = (1.0, 0.86, 0.70)
SUN_STRENGTH = 4.2
SKY_COLOR = (0.42, 0.55, 0.78)
SKY_STRENGTH = 0.55


def reset(samples=64, transparent=True):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.cycles.max_bounces = 6
    s.render.film_transparent = transparent
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'AgX'
    try:
        s.view_settings.look = 'AgX - Medium High Contrast'
    except TypeError:
        pass
    world = bpy.data.worlds.new('dunya')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (*SKY_COLOR, 1)
    bg.inputs[1].default_value = SKY_STRENGTH
    s.world = world
    sun = bpy.data.lights.new('gunes', 'SUN')
    sun.energy = SUN_STRENGTH
    sun.color = SUN_COLOR
    sun.angle = math.radians(1.2)
    so = bpy.data.objects.new('gunes', sun)
    so.rotation_euler = SUN_ROT
    s.collection.objects.link(so)
    return s


def ortho_camera(scene, center, ortho_scale, res_x, res_y, distance=200.0):
    cam = bpy.data.cameras.new('kamera')
    cam.type = 'ORTHO'
    cam.ortho_scale = ortho_scale
    cam.clip_end = distance * 4
    co = bpy.data.objects.new('kamera', cam)
    cx, cy, cz = center
    co.location = (cx, cy - distance * math.sin(CAM_TILT), cz + distance * math.cos(CAM_TILT))
    co.rotation_euler = (CAM_TILT, 0, 0)
    scene.collection.objects.link(co)
    scene.camera = co
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    return co


def principled(name, color, roughness=0.6, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = roughness
    b.inputs['Metallic'].default_value = metallic
    return m
