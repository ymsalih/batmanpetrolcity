import numpy as np
from PIL import Image
import geo
z = geo.load_region(); print('region', z.shape, z.min(), z.max())
zs = geo.downsample(z, 4)  # ~180 m
print('ds', zs.shape)
# Çukurları doldur (basit): hafif yumuşatma
from scipy import ndimage
zsm = geo.fill_depressions(ndimage.gaussian_filter(zs, 0.8))
acc = geo.flow_accumulation(zsm)
np.save('.dem/acc.npy', acc); np.save('.dem/zs.npy', zs)
print('acc max', acc.max())
riv = np.clip(np.log1p(acc)/np.log1p(acc.max()),0,1)**3
Image.fromarray((riv*255).astype(np.uint8)).save('/tmp/claude-0/-home-user-batmanpetrolcity/743883a6-2533-551b-ac51-591747c80ce2/scratchpad/acc.png')
# Sırt tepe noktaları (yerel maksimumlar)
mx = ndimage.maximum_filter(zs, size=25)
peaks = np.argwhere((zs == mx) & (zs > np.percentile(zs, 97)))
H, W = zs.shape
for r, c in sorted(peaks, key=lambda p: -zs[p[0], p[1]])[:12]:
    lat = geo.LAT_N - (r + .5) / H * (geo.LAT_N - geo.LAT_S); lon = geo.LON_W + (c + .5) / W * (geo.LON_E - geo.LON_W)
    print(f'peak {zs[r,c]:.0f} m  lat {lat:.3f} lon {lon:.3f}')
