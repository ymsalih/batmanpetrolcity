"""Paketlenmiş görsellerden tanıtım panoları (katalog + etiketli harita)."""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

A = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'game')
OUT = sys.argv[1]
man = json.load(open(os.path.join(A, 'manifest.json')))
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
f_big = ImageFont.truetype(FONT, 34); f = ImageFont.truetype(FONT, 22); f_s = ImageFont.truetype(FONT, 17)
BG = (24, 20, 17); GROUND = (150, 120, 84)


def frame(name, i=0, file=None):
    m = man[name]
    im = Image.open(os.path.join(A, file or m['file'])).convert('RGBA')
    fw, fh = m['frame']; r, c = divmod(i, m['cols'])
    return im.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))


def tile(img, scale, label, w=None, h=None):
    img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    w = w or img.width + 24; h = h or img.height + 54
    t = Image.new('RGBA', (w, h), (*GROUND, 255))
    t.alpha_composite(img, ((w - img.width) // 2, max(0, h - 40 - img.height)))
    d = ImageDraw.Draw(t)
    d.rectangle([0, h - 34, w, h], fill=(0, 0, 0, 150))
    d.text((10, h - 30), label, font=f_s, fill=(255, 225, 160))
    return t


rows = []
pj = [tile(frame('pumpjack', i), 0.62, f'At kafası  kare {i + 1}/24', 210, 210) for i in (0, 4, 8, 12, 16, 20)]
rows.append(('At kafası: gerçek dört-çubuk mekanizmalı 24 karelik pompa turu', pj))
d = frame('derrick'); blk = frame('derrick_block', 3)
off = man['derrick_block']['offset']; d.alpha_composite(blk, tuple(off))
rows.append(('Sondaj kulesi, tesisler', [tile(d, 0.42, 'Sondaj kulesi (derikmen platformlu)'),
                                       tile(frame('refinery'), 0.36, 'Batman rafinerisi'),
                                       tile(frame('depot'), 0.5, 'Akaryakıt alım merkezi (pazarlamacı)'),
                                       tile(frame('camp'), 0.42, 'İşçi lojmanları')]))
rows.append(('Ham petrol tankeri ve personel minibüsü: 16 yön',
             [tile(frame('tanker', i), 0.5, f'Tanker yön {i}', 220, 200) for i in (0, 2, 4, 6, 10)] +
             [tile(frame('minibus', i), 0.8, f'Minibüs yön {i}', 190, 200) for i in (0, 5, 12)]))
wm = man['worker']
roles = {'muhendis': 'Mühendis', 'sondor': 'Sondör', 'derikmen': 'Derikmen', 'jeolog': 'Jeolog',
         'pompaci': 'Pompacı', 'mekanik': 'Makinist', 'sofor': 'Şoför', 'tuccar': 'Tüccar', 'isci': 'İşçi'}
rows.append(('İşçiler: 9 rol, baret rengi göreve göre, 8 yönde yürüme',
             [tile(frame('worker', 6 * wm['cols'] + (k * 3) % 8, f'sprites/worker_{r}.webp'), 1.2, n, 136, 210)
              for k, (r, n) in enumerate(roles.items())]))

W = max(sum(t.width for t in ts) + 12 * (len(ts) + 1) for _, ts in rows)
H = sum(max(t.height for t in ts) + 70 for _, ts in rows) + 90
board = Image.new('RGBA', (W, H), (*BG, 255))
dr = ImageDraw.Draw(board)
dr.text((16, 20), 'Batman Petrol Ağası — üretilen oyun görselleri', font=f_big, fill=(255, 205, 110))
y = 80
for title, ts in rows:
    dr.text((16, y), title, font=f, fill=(235, 225, 210))
    y += 36; x = 12
    for t in ts:
        board.alpha_composite(t, (x, y)); x += t.width + 12
    y += max(t.height for t in ts) + 34
board.convert('RGB').save(os.path.join(OUT, 'katalog.jpg'), quality=88)

# Etiketli dünya haritası
w = man['world']
im = Image.open(os.path.join(A, w['overview'])).convert('RGBA')
k = im.width / w['size'][0]
ov = Image.new('RGBA', im.size, (0, 0, 0, 0)); d2 = ImageDraw.Draw(ov)
for r in w['roads']:
    d2.line([(x * k, y * k) for x, y in r['px']], fill=(255, 210, 120, 200), width=2)
names = {'sehir': 'Batman', 'rafineri': 'Rafineri', 'lojman': 'Lojmanlar', 'pazarlama': 'Pazarlamacı',
         'bati_raman': 'Batı Raman', 'raman': 'Raman', 'garzan': 'Garzan'}
for key, p in w['poi'].items():
    x, y = p['px'][0] * k, p['px'][1] * k
    d2.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 120, 40, 255), outline=(255, 255, 255, 255), width=2)
    lbl = names.get(key, key) + (f"  {p['elevM']} m" if key in ('bati_raman', 'raman', 'garzan') else '')
    tb = d2.textbbox((0, 0), lbl, font=f_s)
    off = {'lojman': -26, 'sehir': -28, 'rafineri': 4}.get(key, 10)
    if key == 'rafineri':
        x += 6
    d2.rounded_rectangle([x + 10, y + off - 2, x + 18 + tb[2], y + off + tb[3] + 4], 6, fill=(0, 0, 0, 170))
    d2.text((x + 14, y + off), lbl, font=f_s, fill=(255, 235, 200))
for nm, (x, y) in {'Dicle': (0.25, 0.83), 'Batman Çayı': (0.06, 0.22)}.items():
    d2.text((x * im.width, y * im.height), nm, font=f_s, fill=(150, 220, 255))
im.alpha_composite(ov)
im.convert('RGB').save(os.path.join(OUT, 'harita.jpg'), quality=88)
print('ok')
