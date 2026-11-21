"""Gerçek arazi verisinden oyun dünyası haritasını render eder.

Kullanım: python render_world.py [genişlik] [örnek]
Çıktı: out/world.png ve out/world.json (önemli noktalar, yollar, nehirler;
piksel koordinatında).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
from scipy import ndimage

import geo
import scene_common as sc
import world_data as wd

WIDTH = int(sys.argv[1]) if len(sys.argv) > 1 else 1536
SAMPLES = int(sys.argv[2]) if len(sys.argv) > 2 else 24
OUT = os.path.join(os.path.dirname(__file__), 'out')
os.makedirs(OUT, exist_ok=True)

z_full = geo.load_region()
z2 = np.load('.dem/z2.npy') if os.path.exists('.dem/z2.npy') else geo.downsample(z_full, 2)
Z0 = 420.0


def to_world(r, c, H, W, elev):
    x = (c / (W - 1) - 0.5) * wd.KM_X
    y = (0.5 - r / (H - 1)) * wd.KM_Y
    return x, y, (elev - Z0) / 1000 * wd.EXAGGERATION


def build_terrain(z, step):
    zz = z[::step, ::step]
    H, W = zz.shape
    rr, cc = np.mgrid[0:H, 0:W]
    xs = (cc / (W - 1) - 0.5) * wd.KM_X
    ys = (0.5 - rr / (H - 1)) * wd.KM_Y
    zs = (zz - Z0) / 1000 * wd.EXAGGERATION
    verts = np.column_stack([xs.ravel(), ys.ravel(), zs.ravel()]).astype(np.float32)
    i = (rr[:-1, :-1] * W + cc[:-1, :-1]).ravel()
    # Saat yönünün tersi (yukarıdan bakınca): normaller yukarı baksın.
    faces = np.column_stack([i, i + W, i + W + 1, i + 1]).astype(np.int32)
    me = bpy.data.meshes.new('arazi')
    me.vertices.add(len(verts)); me.vertices.foreach_set('co', verts.ravel())
    me.loops.add(faces.size); me.loops.foreach_set('vertex_index', faces.ravel())
    me.polygons.add(len(faces))
    me.polygons.foreach_set('loop_start', np.arange(0, faces.size, 4, dtype=np.int32))
    me.polygons.foreach_set('loop_total', np.full(len(faces), 4, np.int32))
    uv = me.uv_layers.new(name='UV')
    u = (cc / (W - 1)).ravel(); v = (1 - rr / (H - 1)).ravel()
    uvs = np.column_stack([u, v])[faces.ravel()].astype(np.float32)
    uv.data.foreach_set('uv', uvs.ravel())
    me.update(); me.validate()
    me.polygons.foreach_set('use_smooth', np.ones(len(faces), bool))
    ob = bpy.data.objects.new('arazi', me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def image_from_array(name, arr):
    """Diziyi PNG olarak yazıp Blender'a yükler (bellekte üretilen görüntüleri
    Cycles render'da siyah okuyor)."""
    from PIL import Image

    path = os.path.join(OUT, f'_{name}.png')
    if name.endswith('rough'):
        Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(path)
    else:
        srgb = np.where(arr <= 0.0031308, arr * 12.92, 1.055 * np.power(np.clip(arr, 0, 1), 1 / 2.4) - 0.055)
        Image.fromarray((np.clip(srgb, 0, 1) * 255).astype(np.uint8)).save(path)
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = 'Non-Color' if name.endswith('rough') else 'sRGB'
    return img


def terrain_material(col, rough):
    m = bpy.data.materials.new('zemin')
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes['Principled BSDF']
    ti = nt.nodes.new('ShaderNodeTexImage'); ti.image = image_from_array('zemin_renk', col)
    tr = nt.nodes.new('ShaderNodeTexImage'); tr.image = image_from_array('zemin_rough', rough)
    nt.links.new(ti.outputs['Color'], b.inputs['Base Color'])
    nt.links.new(tr.outputs['Color'], b.inputs['Roughness'])
    b.inputs['Specular IOR Level'].default_value = 0.35
    return m


def build_city(z, roads_mask_fn):
    """Batman şehri: sokak ızgarasına dizili, gölge veren küçük binalar."""
    rng = np.random.default_rng(11)
    H, W = z.shape
    cr, cc = wd.CITY
    verts, faces, mats = [], [], []
    ang = math.radians(-12)
    ca, sa = math.cos(ang), math.sin(ang)
    block = 0.10  # km (sokak aralığı)
    street = 0.018
    rm = wd.river_mask(z.shape, width=3.0, z=z)
    for gi in range(-38, 39):
        for gj in range(-30, 31):
            lx, ly = gi * block, gj * block
            # Şehir biçimi: düzensiz elips; merkez yoğun ve yüksek, kenarlar seyrek
            rad = math.hypot(lx / 3.6, ly / 2.8)
            edge = 1 + 0.18 * math.sin(gi * 0.6 + gj * 0.35) + 0.1 * math.cos(gj * 0.9)
            if rad > edge or (rad > 0.7 and rng.random() < (rad - 0.7) * 1.6):
                continue
            # Ana caddeler: birkaç blok genişliğinde boşluk
            if gi % 9 == 0 or gj % 7 == 0:
                continue
            # Blok içi: kenarlara dizili binalar (avlulu Anadolu şehir dokusu)
            inner = block - street
            n = 3 if rad > 0.6 else 4
            slots = [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1)][: n + (2 if rad < 0.35 else 0)]
            for sx, sy in slots:
                bw = rng.uniform(0.026, 0.042) if sx else rng.uniform(0.02, 0.03)
                bd = rng.uniform(0.024, 0.036)
                ox = sx * (inner / 2 - bw / 2); oy = sy * (inner / 2 - bd / 2)
                floors = int(rng.integers(4, 11)) if rad < 0.35 else int(rng.integers(2, 6)) if rad < 0.7 else int(rng.integers(1, 3))
                bh = floors * 0.003 * wd.EXAGGERATION
                px_, py_ = lx + ox, ly + oy
                wx = px_ * ca - py_ * sa; wy = px_ * sa + py_ * ca
                rr_ = cr - wy / wd.KM_Y * (H - 1); cc_ = cc + wx / wd.KM_X * (W - 1)
                if not (0 <= rr_ < H and 0 <= cc_ < W) or rm[int(rr_), int(cc_)] > 0.2:
                    continue
                x, y, gz = to_world(rr_, cc_, H, W, z[int(rr_), int(cc_)])
                hx, hy = bw / 2, bd / 2
                cs = [(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)]
                cs = [(x + u * ca - v * sa, y + u * sa + v * ca) for u, v in cs]
                base = len(verts)
                verts += [(cx_, cy_, gz - 0.01) for cx_, cy_ in cs] + [(cx_, cy_, gz + bh) for cx_, cy_ in cs]
                faces += [(base + 4, base + 5, base + 6, base + 7), (base, base + 1, base + 5, base + 4),
                          (base + 1, base + 2, base + 6, base + 5), (base + 2, base + 3, base + 7, base + 6),
                          (base + 3, base, base + 4, base + 7)]
                roof = int(rng.choice([0, 0, 1, 1, 2, 3]))
                mats += [roof, 1, 1, 1, 1]
    me = bpy.data.meshes.new('sehir')
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new('sehir', me)
    for name, col in [('beyaz', (0.72, 0.70, 0.64)), ('krem', (0.66, 0.58, 0.45)), ('kiremit', (0.48, 0.20, 0.12)),
                      ('gri', (0.45, 0.45, 0.44))]:
        ob.data.materials.append(sc.principled('bina_' + name, col, 0.8))
    me.polygons.foreach_set('material_index', np.array(mats, np.int32))
    bpy.context.scene.collection.objects.link(ob)
    print('bina', len(verts) // 8)


def project(scene, cam, pts_world):
    out = []
    rx, ry = scene.render.resolution_x, scene.render.resolution_y
    for p in pts_world:
        co = world_to_camera_view(scene, cam, Vector(p))
        out.append((round(co.x * rx, 1), round((1 - co.y) * ry, 1)))
    return out


def main():
    scene = sc.reset(samples=SAMPLES)
    H, W = z2.shape
    step = 1 if WIDTH >= 4096 else 2
    zmesh = ndimage.zoom(z_full, (H / z_full.shape[0], W / z_full.shape[1]), order=1) if step else z2
    terrain = build_terrain(z2 if WIDTH < 4096 else z_full, 1 if WIDTH >= 4096 else 1)
    roads = wd.road_paths(z2)
    col, rough, tshape = wd.albedo(z_full, min(8192, WIDTH))
    wd.paint_roads(col, rough, roads, tshape)
    terrain.data.materials.append(terrain_material(col, rough))
    build_city(z2, None)

    zr = (z2.max() - Z0) / 1000 * wd.EXAGGERATION
    vert_extent = wd.KM_Y * math.sin(sc.CAM_TILT) + zr * math.cos(sc.CAM_TILT)
    res_y = int(WIDTH * (vert_extent + 0.4) / wd.KM_X)
    cam = sc.ortho_camera(scene, (0, 0, zr * 0.35), wd.KM_X, WIDTH, res_y)
    crop = os.environ.get('CROP')  # "x0,y0,x1,y1" (0..1): hızlı önizleme için bölge render'ı
    if crop:
        x0, y0, x1, y1 = map(float, crop.split(','))
        scene.render.use_border = True; scene.render.use_crop_to_border = True
        scene.render.border_min_x, scene.render.border_max_x = x0, x1
        scene.render.border_min_y, scene.render.border_max_y = 1 - y1, 1 - y0
        scene.render.filepath = os.path.join(OUT, 'world_crop.png')
        bpy.ops.render.render(write_still=True)
        print('ok crop')
        return
    scene.render.filepath = os.path.join(OUT, 'world.png')
    bpy.ops.render.render(write_still=True)

    def elev(r, c):
        return z2[int(min(max(r, 0), H - 1)), int(min(max(c, 0), W - 1))]

    data = {
        'size': [WIDTH, res_y],
        'kmPerPx': wd.KM_X / WIDTH,
        'source': 'Copernicus DEM GLO-30 (© DLR, © Airbus DS; AB Copernicus Programı)',
        'poi': {}, 'roads': [], 'rivers': {},
    }
    for k, (r, c) in wd.POI.items():
        x, y, zz = to_world(r, c, H, W, elev(r, c))
        data['poi'][k] = {'px': project(scene, cam, [(x, y, zz)])[0], 'elevM': round(float(elev(r, c)))}
    for a, b, kind, p in roads:
        pts = [to_world(r, c, H, W, elev(r, c)) for r, c in p[::3]]
        data['roads'].append({'from': a, 'to': b, 'kind': kind, 'px': project(scene, cam, pts)})
    for name, p in wd.river_paths(z2).items():
        pts = [to_world(r, c, H, W, elev(r, c)) for r, c in p[::4]]
        data['rivers'][name] = project(scene, cam, pts)
    with open(os.path.join(OUT, 'world.json'), 'w') as f:
        json.dump(data, f, ensure_ascii=False)
    print('ok', WIDTH, res_y)


if __name__ == '__main__':
    main()
