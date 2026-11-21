"""Batman semalarından Raman sırtına bakan panorama: oyunun arka planı.

Gerçek arazi (Copernicus DEM), fiziksel gökyüzü, derinliğe bağlı atmosfer
pusu; gün doğumu, gündüz, gün batımı ve gece için aynı kameradan render
edilir, oyun gerçek saate göre aralarında geçiş yapar.
Kullanım: python horizon.py [ön_ayar,...] [genişlik] [örnek]
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from PIL import Image

import scene_common as sc
import world_data as wd

KEYS = (sys.argv[1] if len(sys.argv) > 1 else 'safak,gunduz,aksam,gece').split(',')
WIDTH = int(sys.argv[2]) if len(sys.argv) > 2 else 960
SAMPLES = int(sys.argv[3]) if len(sys.argv) > 3 else 24
HEIGHT = int(WIDTH * 0.8)
OUT = os.path.join(os.path.dirname(__file__), 'out', 'horizon')
os.makedirs(OUT, exist_ok=True)

wd.EXAGGERATION = 2.4   # panoramada daha doğal, yine de dağlar okunur
_argv, sys.argv = sys.argv, sys.argv[:1]
import render_world as rw  # noqa: E402  (EXAGGERATION ayarlandıktan sonra)
sys.argv = _argv


CLAT = (wd.geo.LAT_N + wd.geo.LAT_S) / 2
CLON = (wd.geo.LON_W + wd.geo.LON_E) / 2
# Kamera: Batman'ın güneydoğusunda ovanın üstünde, ~300 m yükseklikte;
# doğu-kuzeydoğuya, Raman sırtına ve ardındaki Kozluk-Sason dağlarına bakar.
CAM_LATLON = (37.884, 41.282)   # Batı Raman tepesi
HEADING = 62
_u, _v = wd.geo.latlon_to_uv(*CAM_LATLON)
CAM_RC = (_v * 503, _u * 1132)
CAM_XY = ((CAM_LATLON[1] - CLON) * 87.8, (CAM_LATLON[0] - CLAT) * 111.2)


def build_far_terrain():
    """Uzak dağlar: 37-39 K / 41-43 D (Sason, Kozluk, Garzan, Süphan tarafı).
    Dünya eğriliği dahil; yakın ayrıntılı arazinin biraz altında kalır."""
    import geo
    import tifffile
    from scipy import ndimage

    f = 4
    rows = []
    for la in (38, 37):
        row = [tifffile.imread(geo.tile_path(la, lo)).astype(np.float32)[::f, ::f] for lo in (41, 42)]
        rows.append(np.concatenate(row, 1))
    z = np.concatenate(rows, 0)
    H, W = z.shape
    lat = 39 - (np.arange(H) + 0.5) / H * 2
    lon = 41 + (np.arange(W) + 0.5) / W * 2
    LON, LAT = np.meshgrid(lon, lat)
    xs = (LON - CLON) * 87.8; ys = (LAT - CLAT) * 111.2
    dist2 = (xs - CAM_XY[0]) ** 2 + (ys - CAM_XY[1]) ** 2
    zs = (z - rw.Z0) / 1000 * wd.EXAGGERATION - dist2 / (2 * 6371.0) - 0.02
    verts = np.column_stack([xs.ravel(), ys.ravel(), zs.ravel()]).astype(np.float32)
    rr, cc = np.mgrid[0:H - 1, 0:W - 1]
    i = (rr * W + cc).ravel()
    faces = np.column_stack([i, i + W, i + W + 1, i + 1]).astype(np.int32)
    me = bpy.data.meshes.new('uzak')
    me.vertices.add(len(verts)); me.vertices.foreach_set('co', verts.ravel())
    me.loops.add(faces.size); me.loops.foreach_set('vertex_index', faces.ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set('loop_start', np.arange(0, faces.size, 4, dtype=np.int32))
    me.polygons.foreach_set('loop_total', np.full(len(faces), 4, np.int32))
    uv = me.uv_layers.new(name='UV')
    uvs = np.column_stack([(cc.ravel() * 0 + 0)]) if False else None
    U = (np.arange(W)[None, :] / (W - 1)).repeat(H, 0).ravel(); V = (1 - np.arange(H)[:, None] / (H - 1)).repeat(W, 1).ravel()
    uv.data.foreach_set('uv', np.column_stack([U, V])[faces.ravel()].astype(np.float32).ravel())
    me.update(); me.validate()
    me.polygons.foreach_set('use_smooth', np.ones(len(faces), bool))
    ob = bpy.data.objects.new('uzak', me)
    bpy.context.scene.collection.objects.link(ob)
    # Renk: bozkır → meşe ormanı → kaya → kar (Kasım sonu kar çizgisi ~2700 m)
    zz = ndimage.gaussian_filter(z, 1)
    gy, gx = np.gradient(zz, 30.0 * f)
    slope = np.hypot(gx, gy)
    n = wd.fbm(z.shape, 21, base=12)
    steppe = np.array([0.46, 0.36, 0.21]); forest = np.array([0.17, 0.19, 0.09]); rock = np.array([0.42, 0.39, 0.35])
    snow = np.array([0.82, 0.84, 0.88])
    t_for = np.clip((zz - 1100) / 400, 0, 1) * np.clip((2300 - zz) / 400, 0, 1) * (0.5 + 0.5 * n)
    t_rock = np.clip((zz - 2000) / 500, 0, 1) + np.clip((slope - 0.45) / 0.3, 0, 1) * 0.6
    t_snow = np.clip((zz - 2700 + 250 * (n - 0.5)) / 250, 0, 1) * np.clip(1 - (slope - 0.7) / 0.4, 0.3, 1)
    col = steppe[None, None] * (0.85 + 0.3 * n[..., None])
    col = col * (1 - t_for[..., None]) + forest * t_for[..., None]
    col = col * (1 - np.clip(t_rock, 0, 1)[..., None]) + rock * np.clip(t_rock, 0, 1)[..., None]
    col = col * (1 - t_snow[..., None]) + snow * t_snow[..., None]
    rough = np.full(z.shape, 0.9, np.float32) - 0.3 * t_snow
    ob.data.materials.append(rw.terrain_material(col.astype(np.float32), rough.astype(np.float32)))
    return ob


def city_lights(on):
    """Gece: şehir binaları ve rafineri sıcak ışık yayar."""
    for m in bpy.data.materials:
        if m.name.startswith('bina_'):
            b = m.node_tree.nodes['Principled BSDF']
            b.inputs['Emission Color'].default_value = (1.0, 0.72, 0.38, 1)
            b.inputs['Emission Strength'].default_value = 1.6 if on else 0.0


def depth_pass(scene, path):
    """Kameraya uzaklık (km/80) → 16 bit gri görüntü; gökyüzü = 1."""
    m = bpy.data.materials.new('derinlik'); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial'); em = nt.nodes.new('ShaderNodeEmission')
    cd = nt.nodes.new('ShaderNodeCameraData'); div = nt.nodes.new('ShaderNodeMath'); div.operation = 'DIVIDE'
    div.inputs[1].default_value = 80.0
    nt.links.new(cd.outputs['View Distance'], div.inputs[0]); nt.links.new(div.outputs[0], em.inputs['Color'])
    nt.links.new(em.outputs[0], out.inputs['Surface'])
    vl = scene.view_layers[0]
    old_world, old_vt, old_look, old_exp = scene.world, scene.view_settings.view_transform, scene.view_settings.look, scene.view_settings.exposure
    w = bpy.data.worlds.new('beyaz'); w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (1, 1, 1, 1)
    scene.world = w; vl.material_override = m
    scene.view_settings.view_transform = 'Standard'; scene.view_settings.look = 'None'; scene.view_settings.exposure = 0
    scene.render.image_settings.color_depth = '16'
    s0 = scene.cycles.samples; scene.cycles.samples = 4; scene.cycles.use_denoising = False
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    vl.material_override = None; scene.world = old_world
    scene.view_settings.view_transform = old_vt; scene.view_settings.look = old_look; scene.view_settings.exposure = old_exp
    scene.render.image_settings.color_depth = '8'; scene.cycles.samples = s0; scene.cycles.use_denoising = True


def grade(img, sky, hr, key):
    """Sinematik renk: doygunluk + yumuşak kontrast, altın saatte ufuk
    parıltısı, gece serin ton, hafif vinyet."""
    h, w = img.shape[:2]
    lum = img.mean(-1, keepdims=True)
    sat = {'safak': 1.22, 'gunduz': 1.12, 'aksam': 1.25, 'gece': 1.05}[key]
    img = lum + (img - lum) * sat
    img = np.clip(img, 0, 1)
    img = img + 0.12 * (img - 0.5) * (1 - np.abs(img - 0.5) * 2)   # S-eğrisi
    yy = np.arange(h)[:, None, None].astype(np.float32)
    if key in ('safak', 'aksam'):
        glow_c = np.array([1.0, 0.55, 0.28]) if key == 'aksam' else np.array([1.0, 0.62, 0.35])
        g = np.exp(-((yy - hr) / (h * 0.16)) ** 2) * 0.22
        img = img * (1 - g) + glow_c * g
    if key == 'gece':
        img = img * np.array([0.9, 0.97, 1.12])
    xx = np.arange(w)[None, :, None].astype(np.float32)
    v = 1 - 0.28 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 2
    return np.clip(img * v, 0, 1)


def haze(beauty_path, depth_path, out_path, key):
    """Hava perspektifi: uzak dağlar ufuk rengine karışır (Batman'ın tozlu havası)."""
    b = np.asarray(Image.open(beauty_path).convert('RGB')).astype(np.float32) / 255
    d = np.asarray(Image.open(depth_path)).astype(np.float32)
    d = d / (65535 if d.max() > 255 else 255)
    if d.ndim == 3:
        d = d[..., 0]
    km = d * 80
    sky = d > 0.995
    # Ufuk rengi: gökyüzünün ufka en yakın bandı
    rows = np.where(sky.any(1))[0]
    hr = rows.max() if len(rows) else b.shape[0] // 3
    band = b[max(0, hr - 6):hr + 1][sky[max(0, hr - 6):hr + 1]]
    hz = band.mean(0) if len(band) else np.array([0.7, 0.6, 0.5])
    dens = {'safak': 0.022, 'gunduz': 0.014, 'aksam': 0.02, 'gece': 0.012}[key]
    f = (1 - np.exp(-km * dens))[..., None] * (~sky)[..., None] * 0.92
    out = b * (1 - f) + hz[None, None] * f
    out = grade(out, sky, hr, key)
    Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8)).save(out_path, quality=90)
    return int(hr)


def main():
    scene = sc.reset(samples=SAMPLES, transparent=False)
    z2 = rw.z2
    terrain = rw.build_terrain(rw.z_full, 1)
    roads = wd.road_paths(z2)
    col, rough, tshape = wd.albedo(rw.z_full, 8192)
    wd.paint_roads(col, rough, roads, tshape)
    terrain.data.materials.append(rw.terrain_material(col, rough))
    rw.build_city(z2, None)
    build_far_terrain()
    H, W = z2.shape
    cam = bpy.data.cameras.new('panorama'); cam.lens = 46; cam.clip_end = 600
    co = bpy.data.objects.new('panorama', cam)
    r, c = int(CAM_RC[0]), int(CAM_RC[1])
    x0, y0, g0 = rw.to_world(r, c, H, W, z2[r, c])
    co.location = (x0, y0, g0 + 0.18 * wd.EXAGGERATION)
    co.rotation_euler = (math.radians(88.2), 0, -math.radians(HEADING))
    scene.collection.objects.link(co); scene.camera = co
    scene.render.resolution_x, scene.render.resolution_y = WIDTH, HEIGHT
    depth = os.path.join(OUT, '_depth.png')
    depth_pass(scene, depth)
    info = {}
    for key in KEYS:
        L = sc.apply_lighting(scene, key)
        city_lights(L.get('night', False))
        raw = os.path.join(OUT, f'_raw_{key}.png')
        scene.render.filepath = raw
        bpy.ops.render.render(write_still=True)
        info[key] = {'horizonRow': haze(raw, depth, os.path.join(OUT, f'{key}.jpg'), key)}
        print('ok', key)
    with open(os.path.join(OUT, 'horizon.json'), 'w') as fh:
        json.dump({'size': [WIDTH, HEIGHT], 'heading': HEADING, 'camLatLon': CAM_LATLON, **info}, fh)


main()
