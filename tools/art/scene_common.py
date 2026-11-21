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


# ---------------------------------------------------------------------------
# Gün içi ışık ön ayarları (Batman, ~37.9° K). Azimut pusula açısı (0 = kuzey,
# 90 = doğu); gökyüzü fiziksel atmosfer simülasyonuyla (çoklu saçılma).
LIGHTING = {
    'safak': dict(az=96, el=3.5, sun=(1.0, 0.52, 0.28), strength=2.6, sky=0.10, exposure=0.35),
    'gunduz': dict(az=215, el=46, sun=(1.0, 0.95, 0.88), strength=3.4, sky=0.10, exposure=-1.25),
    'aksam': dict(az=262, el=2.8, sun=(1.0, 0.45, 0.22), strength=2.8, sky=0.10, exposure=0.4),
    'gece': dict(az=140, el=38, sun=(0.55, 0.66, 1.0), strength=0.22, sky=0.0, exposure=1.1, night=True),
}


def sun_vector(az_deg, el_deg):
    from mathutils import Vector

    a, e = math.radians(az_deg), math.radians(el_deg)
    return Vector((math.sin(a) * math.cos(e), math.cos(a) * math.cos(e), math.sin(e)))


def apply_lighting(scene, key):
    """Güneş lambası + fiziksel gökyüzü; gece için ay ışığı, alacakaranlık
    gökyüzü ve yıldızlar."""
    from mathutils import Vector

    L = LIGHTING[key]
    for ob in list(scene.collection.objects):
        if ob.type == 'LIGHT':
            bpy.data.objects.remove(ob)
    sun = bpy.data.lights.new('gunes', 'SUN')
    sun.energy = L['strength']; sun.color = L['sun']; sun.angle = math.radians(0.6 if L.get('night') else 1.2)
    so = bpy.data.objects.new('gunes', sun)
    so.rotation_mode = 'QUATERNION'
    so.rotation_quaternion = Vector((0, 0, -1)).rotation_difference(-sun_vector(L['az'], L['el']))
    scene.collection.objects.link(so)

    world = bpy.data.worlds.new('dunya_' + key)
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes['Background']
    sky = nt.nodes.new('ShaderNodeTexSky')
    sky.sky_type = 'MULTIPLE_SCATTERING'
    sky.sun_disc = True
    sky.sun_size = math.radians(0.8)
    sky.sun_intensity = 0.35
    if L.get('night'):
        # Mavi saat sonrası: güneş ufkun altında, çok sönük gök + yıldızlar
        sky.sun_elevation = math.radians(-7)
        sky.sun_rotation = math.radians(290)
        sky.sun_disc = False
        vor = nt.nodes.new('ShaderNodeTexVoronoi'); vor.inputs['Scale'].default_value = 420
        vor.feature = 'F1'
        rng = nt.nodes.new('ShaderNodeMapRange')
        rng.inputs['From Min'].default_value = 0.0; rng.inputs['From Max'].default_value = 0.035
        rng.inputs['To Min'].default_value = 1.0; rng.inputs['To Max'].default_value = 0.0
        nt.links.new(vor.outputs['Distance'], rng.inputs['Value'])
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'; mix.blend_type = 'ADD'
        nt.links.new(rng.outputs['Result'], mix.inputs['Factor'])
        nt.links.new(sky.outputs['Color'], mix.inputs[6])
        mix.inputs[7].default_value = (0.9, 0.92, 1.0, 1)
        nt.links.new(mix.outputs[2], bg.inputs['Color'])
        bg.inputs['Strength'].default_value = 0.9
    else:
        sky.sun_elevation = math.radians(L['el'])
        sky.sun_rotation = math.radians(L['az'])
        nt.links.new(sky.outputs['Color'], bg.inputs['Color'])
        bg.inputs['Strength'].default_value = L['sky']
    scene.world = world
    scene.view_settings.exposure = L['exposure']
    return L
