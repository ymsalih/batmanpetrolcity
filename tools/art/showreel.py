"""Yapılan işlerin tanıtım videosu (dikey 720x1280, 24 fps).
Kullanım: python showreel.py <uygulama_kaydı.webm> <çıktı.mp4>"""
import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
A = os.path.join(ROOT, 'assets', 'game')
REC, OUT = sys.argv[1], sys.argv[2]
W, H, FPS = 720, 1280, 24
FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FR = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
GOLD = (255, 200, 105)

enc = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}',
                        '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '21',
                        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', OUT], stdin=subprocess.PIPE)


def emit(img):
    enc.stdin.write(np.asarray(img.convert('RGB')).tobytes())


def font(size, bold=True):
    return ImageFont.truetype(FB if bold else FR, size)


def wrap(text, fnt, width, draw):
    words, lines, cur = text.split(), [], ''
    for w in words:
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=fnt) > width and cur:
            lines.append(cur); cur = w
        else:
            cur = t
    return lines + ([cur] if cur else [])


def caption(img, title, sub=None, alpha=1.0):
    """Alt bilgi bandı: altın başlık + açıklama."""
    img = img.convert('RGBA')
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(ov)
    ft, fs = font(34), font(24, False)
    lines = wrap(sub, fs, W - 80, d) if sub else []
    h = 70 + 34 * len(lines)
    for i in range(h + 60):
        a = int(210 * min(1, i / 60) * alpha)
        d.line([(0, H - h - 60 + i), (W, H - h - 60 + i)], fill=(8, 6, 5, a))
    d.text((40, H - h - 10), title, font=ft, fill=(*GOLD, int(255 * alpha)))
    for i, ln in enumerate(lines):
        d.text((40, H - h + 38 + i * 34), ln, font=fs, fill=(240, 232, 220, int(255 * alpha)))
    img.alpha_composite(ov)
    return img


_bg = None


def card(num, title, sub, secs=2.2):
    global _bg
    if _bg is None:
        im = Image.open(os.path.join(A, 'horizon', 'aksam.jpg')).convert('RGB')
        im = im.crop(((im.width - int(im.height * W / H)) // 2, 0, (im.width + int(im.height * W / H)) // 2, im.height))
        _bg = Image.blend(im.resize((W, H)).filter(ImageFilter.GaussianBlur(14)), Image.new('RGB', (W, H), (10, 8, 6)), 0.55)
    n = int(secs * FPS)
    for i in range(n):
        t = i / n
        a = min(1, t * 4, (1 - t) * 4)
        img = _bg.copy().convert('RGBA'); d = ImageDraw.Draw(img)
        y = H * 0.40 - 20 * (1 - min(1, t * 3))
        if num:
            d.text((60, y - 70), num, font=font(30), fill=(*GOLD, int(200 * a)))
        for k, ln in enumerate(wrap(title, font(52), W - 120, d)):
            d.text((60, y + k * 64), ln, font=font(52), fill=(255, 245, 230, int(255 * a)))
        yy = y + 64 * len(wrap(title, font(52), W - 120, d)) + 24
        for k, ln in enumerate(wrap(sub, font(27, False), W - 120, d)):
            d.text((60, yy + k * 38), ln, font=font(27, False), fill=(225, 215, 200, int(255 * a)))
        d.line([(60, y - 18), (60 + 120 * min(1, t * 3), y - 18)], fill=(*GOLD, int(255 * a)), width=4)
        emit(Image.alpha_composite(Image.new('RGBA', (W, H), (0, 0, 0, 255)), img) if a < 1 else img)


def video_frames(path, start=0.0, dur=None):
    cmd = ['ffmpeg', '-loglevel', 'error', '-ss', str(start), '-i', path]
    if dur:
        cmd += ['-t', str(dur)]
    cmd += ['-vf', f'scale={W}:{H}:force_original_aspect_ratio=decrease,pad={W}:{H}:(ow-iw)/2:(oh-ih)/2,fps={FPS}',
            '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-']
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    size = W * H * 3
    while True:
        buf = p.stdout.read(size)
        if len(buf) < size:
            break
        yield Image.frombuffer('RGB', (W, H), buf)
    p.wait()


def play(path, title, sub, start=0.0, dur=None):
    for i, fr in enumerate(video_frames(path, start, dur)):
        emit(caption(fr, title, sub, min(1, i / 12)))


# 1) Açılış
card('', 'Batman Petrol Ağası', 'Neler yaptık? Gerçek arazi verisi, gerçek güneş ve Blender ile render edilmiş premium görseller.', 3.2)

# 2) Gerçek güneşle değişen manzaralar
card('1', 'Gerçek Batman güneşi', 'Manzara, Batman\'da güneşin o anki yüksekliğine göre değişir: gün doğumu, gündüz, gün batımı, gece.')
pans = {k: Image.open(os.path.join(A, 'horizon', f'{k}.jpg')).convert('RGB') for k in ('safak', 'gunduz', 'aksam', 'gece')}
labels = {'safak': ('Gün doğumu', 'Güneş Kozluk-Sason dağlarının ardından yükselir.'),
          'gunduz': ('Gündüz', 'Raman sırtı ve Kasım karıyla kaplı uzak zirveler.'),
          'aksam': ('Gün batımı', 'Altın saat: sırtlar turuncuya boyanır.'),
          'gece': ('Gece', 'Ay ışığı ve yıldızlar.')}
order = ['safak', 'gunduz', 'aksam', 'gece']
seg = int(3.4 * FPS); fade = int(0.8 * FPS)


def kb(img, t):
    """Ken Burns: dikey kırpım, yavaş yatay kayma ve yakınlaşma."""
    z = 1.0 + 0.08 * t
    ch = img.height / z; cw = ch * W / H
    x0 = (img.width - cw) * (0.25 + 0.5 * t); y0 = (img.height - ch) * 0.5
    return img.crop((int(x0), int(y0), int(x0 + cw), int(y0 + ch))).resize((W, H), Image.LANCZOS)


for i, k in enumerate(order):
    for f in range(seg):
        t = (i * seg + f) / (len(order) * seg)
        fr = kb(pans[k], t)
        if f >= seg - fade and i < len(order) - 1:
            nxt = kb(pans[order[i + 1]], t)
            fr = Image.blend(fr, nxt, (f - (seg - fade)) / fade)
        emit(caption(fr, *labels[k]))

# 3) At kafası yakın plan
card('2', 'Gerçekçi at kafası', 'Gerçek ölçülerde modellendi; kiriş açısı dört-çubuk mekanizmasından hesaplanır. 24 karelik pompa turu.')
m = json.load(open(os.path.join(A, 'manifest.json')))
pj = m['pumpjack']; sheet = Image.open(os.path.join(A, pj['file'])).convert('RGBA')
fw, fh = pj['frame']
site = Image.open(os.path.join(A, 'sites', 'raman.jpg')).convert('RGB')
bgc = site.crop((site.width // 2 - 260, site.height // 2 - 300, site.width // 2 + 100, site.height // 2 + 340)).resize((W, H), Image.LANCZOS)
for f in range(int(5.5 * FPS)):
    i = int(f / FPS / 3.0 * pj['count']) % pj['count']
    r, c = divmod(i, pj['cols'])
    sp = sheet.crop((c * fw, r * fh, (c + 1) * fw, (r + 1) * fh))
    s = 2.1
    sp = sp.resize((int(fw * s), int(fh * s)), Image.LANCZOS)
    img = bgc.copy().convert('RGBA'); img.alpha_composite(sp, ((W - sp.width) // 2, H // 2 - sp.height // 2 - 60))
    emit(caption(img, 'At kafası', 'Krank, karşı ağırlık, biyel, at başı, halat ve cilalı çubuk gerçek hareketiyle.'))

# 4) Saha
card('3', 'Her kuyu kendi pedinde', 'Dağda birbirinden ayrı 9 kuyu pedi, aralarında toprak yollar. Minibüs işçileri getirir, toplanırlar, kuleye yürürler.')
play(os.path.join(HERE, 'out', 'preview_raman.mp4'), 'Raman sahası', 'Sondaj kulesi, pompalayan at kafaları, personel minibüsü ve işçiler.')

# 5) Dünya haritası
card('4', 'Gerçek Batman haritası', 'Copernicus arazi verisinden: Dicle, Batman Çayı, şehir, sırtlardaki sahalar ve yollar.')
play(os.path.join(HERE, 'out', 'preview_world.mp4'), 'Dünya haritası', 'Tankerler sahalardan rafineriye gidip gelir; lojmanlar ve alım merkezi şehirde.')

# 6) Uygulama
card('5', 'Uygulamanın içinden', 'Açılış sinematiği yeni manzaralarla; saha, harita, ekip, pazar ve grafik ayarları.')
play(REC, 'Uygulama', 'Web derlemesinden gerçek ekran kaydı.', start=2.6)

# 7) Katalog
card('6', 'Üretilen görseller', 'Sondaj kulesi, tanker, minibüs, 9 rolde işçiler, rafineri, alım merkezi ve lojmanlar.')
cat = Image.open(os.path.join(ROOT, 'docs', 'gorseller', 'katalog.jpg')).convert('RGB')
cat = cat.resize((int(cat.width * H / cat.height * 1.0), H), Image.LANCZOS)
n = int(9 * FPS)
for f in range(n):
    x = int((cat.width - W) * f / (n - 1))
    emit(cat.crop((x, 0, x + W, H)))

card('', 'Sıradaki adım', 'Bu görselleri Flame ile oyuna bağlamak: haritada ve sahada parmakla gezinme, yakınlaştırma, araçlarla gelen işçiler ve petrol taşıyan tankerler.', 3.6)
enc.stdin.close(); enc.wait()
print('ok', OUT)
