"""Sprite modelleme yardımcıları: kutu, silindir, iki nokta arası kiriş,
boyalı/paslı metal malzemeler ve ortak sprite render'ı."""
import math
import os

import bpy
import numpy as np
from mathutils import Matrix, Vector

import scene_common as sc

# Tüm saha sprite'larında aynı ölçek: metre başına piksel.
PX_PER_M = 24
OUT = os.path.join(os.path.dirname(__file__), 'out', 'sprites')
os.makedirs(OUT, exist_ok=True)

_mats = {}


def mat_paint(name, color, rough=0.45, rust=0.0, metallic=0.25, scale=6.0):
    """Boyalı metal; [rust] > 0 ise gürültüyle pas lekeleri ve kir eklenir."""
    key = (name, color, rough, rust)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    b.inputs['Metallic'].default_value = metallic
    b.inputs['Roughness'].default_value = rough
    if rust <= 0:
        b.inputs['Base Color'].default_value = (*color, 1)
    else:
        tc = nt.nodes.new('ShaderNodeTexCoord')
        n = nt.nodes.new('ShaderNodeTexNoise')
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = 10
        n.inputs['Roughness'].default_value = 0.65
        nt.links.new(tc.outputs['Object'], n.inputs['Vector'])
        ramp = nt.nodes.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].position = 0.62 - rust * 0.25
        ramp.color_ramp.elements[1].position = 0.70 - rust * 0.2
        nt.links.new(n.outputs['Fac'], ramp.inputs['Fac'])
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
        mix.inputs[6].default_value = (*color, 1)
        mix.inputs[7].default_value = (0.24, 0.11, 0.05, 1)
        nt.links.new(ramp.outputs['Color'], mix.inputs['Factor'])
        nt.links.new(mix.outputs[2], b.inputs['Base Color'])
        rr = nt.nodes.new('ShaderNodeMapRange')
        rr.inputs['To Min'].default_value = rough
        rr.inputs['To Max'].default_value = 0.9
        nt.links.new(ramp.outputs['Color'], rr.inputs['Value'])
        nt.links.new(rr.outputs['Result'], b.inputs['Roughness'])
    _mats[key] = m
    return m


def mat_plain(name, color, rough=0.8, metallic=0.0, emission=None, strength=0.0):
    key = (name, color, rough, metallic, emission)
    if key in _mats:
        return _mats[key]
    m = sc.principled(name, color, rough, metallic)
    if emission:
        b = m.node_tree.nodes['Principled BSDF']
        b.inputs['Emission Color'].default_value = (*emission, 1)
        b.inputs['Emission Strength'].default_value = strength
    _mats[key] = m
    return m


def _link(ob, parent=None, mat=None, bevel=0.0):
    bpy.context.scene.collection.objects.link(ob) if ob.name not in bpy.context.scene.collection.objects else None
    if mat:
        ob.data.materials.append(mat)
    if parent:
        ob.parent = parent
    if bevel > 0:
        md = ob.modifiers.new('bevel', 'BEVEL')
        md.width = bevel
        md.segments = 2
        md.limit_method = 'ANGLE'
    return ob


def box(name, size, loc, mat=None, parent=None, rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        ob.data.materials.append(mat)
    if parent:
        _parent_keep(ob, parent)
    if bevel:
        md = ob.modifiers.new('bevel', 'BEVEL'); md.width = bevel; md.segments = 2
    return ob


def cyl(name, r, depth, loc, mat=None, parent=None, rot=(0, 0, 0), verts=32, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    ob = bpy.context.active_object
    ob.name = name
    if smooth:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    if mat:
        ob.data.materials.append(mat)
    if parent:
        _parent_keep(ob, parent)
    return ob


def rod(name, p1, p2, r, mat=None, parent=None, verts=16, square=False):
    """p1'den p2'ye uzanan silindir (veya kare profil)."""
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    mid = (p1 + p2) / 2
    if square:
        ob = box(name, (r * 2, r * 2, d.length), mid, mat, None, bevel=min(0.015, r * 0.3))
    else:
        ob = cyl(name, r, d.length, mid, mat, None, verts=verts)
    ob.rotation_mode = 'QUATERNION'
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    if parent:
        _parent_keep(ob, parent)
    return ob


def empty(name, loc=(0, 0, 0), parent=None):
    ob = bpy.data.objects.new(name, None)
    ob.location = loc
    bpy.context.scene.collection.objects.link(ob)
    if parent:
        # Konum dünya koordinatıdır: üst nesneye bağlarken yerinde kalsın.
        _parent_keep(ob, parent)
    return ob


def _parent_keep(ob, parent):
    bpy.context.view_layer.update()
    mw = ob.matrix_world.copy()
    ob.parent = parent
    ob.matrix_parent_inverse = parent.matrix_world.inverted()
    ob.matrix_world = mw


def shadow_catcher(size=60):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    p = bpy.context.active_object
    p.name = 'golge_yakalayici'
    p.is_shadow_catcher = True
    return p


def frame_camera(scene, bounds_min, bounds_max, pad=0.6):
    """Nesnenin sınırlarını kapsayan ortografik kamera; ölçek PX_PER_M sabit."""
    import scene_common as sc2
    corners = [Vector((x, y, z)) for x in (bounds_min[0], bounds_max[0]) for y in (bounds_min[1], bounds_max[1])
               for z in (bounds_min[2], bounds_max[2])]
    t = sc2.CAM_TILT
    right = Vector((1, 0, 0)); up = Vector((0, math.cos(t), math.sin(t)))
    xs = [c.dot(right) for c in corners]; ys = [c.dot(up) for c in corners]
    w = max(xs) - min(xs) + pad * 2; h = max(ys) - min(ys) + pad * 2
    cx = (max(xs) + min(xs)) / 2; cy = (max(ys) + min(ys)) / 2
    res_x = int(math.ceil(w * PX_PER_M / 2) * 2); res_y = int(math.ceil(h * PX_PER_M / 2) * 2)
    center = right * cx + up * cy
    cam = sc2.ortho_camera(scene, tuple(center), res_x / PX_PER_M, res_x, res_y, distance=80)
    if res_y > res_x:
        cam.data.sensor_fit = 'VERTICAL'
        cam.data.ortho_scale = res_y / PX_PER_M
    return cam, (res_x, res_y), (cx, cy)


def world_bounds(objs):
    bpy.context.view_layer.update()
    pts = []
    for o in objs:
        if o.type != 'MESH':
            continue
        pts += [o.matrix_world @ Vector(c) for c in o.bound_box]
    a = np.array(pts)
    return a.min(0), a.max(0)


def anchor_px(scene, cam, p):
    """Bir dünya noktasının sprite içindeki piksel konumu (zemin çapası)."""
    from bpy_extras.object_utils import world_to_camera_view
    co = world_to_camera_view(scene, cam, Vector(p))
    return [round(co.x * scene.render.resolution_x, 1), round((1 - co.y) * scene.render.resolution_y, 1)]
