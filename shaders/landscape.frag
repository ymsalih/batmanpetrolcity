#version 460 core
// Premium manzara: gökyüzü + bulutlar + güneş/ışık hüzmeleri + yıldızlar,
// dört katman aşınmış dağ sırtı (Raman Dağı kütlesi), yamaç ışıklandırması,
// erozyon olukları, vadi sisi, atmosferik perspektif, bulut gölgeleri,
// çalılık, gece köy ışıkları, ön planda bozkır ve ince film greni.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec3 uTop;
uniform vec3 uBottom;
uniform float uNight;
uniform float uDusk;
uniform vec2 uSun;      // göreli güneş konumu (y>1: ufkun altında)
uniform float uSeed;
uniform float uParallax;

out vec4 fragColor;

float hash1(float n) { return fract(sin(n * 127.1 + uSeed * 17.0) * 43758.5453); }
float hash2(vec2 p) {
  p = fract(p * vec2(123.34, 456.21) + uSeed * 0.13);
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise1(float x) {
  float i = floor(x);
  float f = fract(x);
  float u = f * f * (3.0 - 2.0 * f);
  return mix(hash1(i), hash1(i + 1.0), u);
}

float noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  float a = hash2(i);
  float b = hash2(i + vec2(1.0, 0.0));
  float c = hash2(i + vec2(0.0, 1.0));
  float d = hash2(i + vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm2(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise2(p);
    p = p * 2.02 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

// Sırtlı (ridged) 1B fbm: keskin zirveler, yumuşak etekler.
float ridged(float x, int octaves) {
  float v = 0.0;
  float a = 0.55;
  float f = 1.0;
  for (int i = 0; i < 6; i++) {
    if (i >= octaves) break;
    float n = noise1(x * f + float(i) * 13.1);
    n = 1.0 - abs(n * 2.0 - 1.0);
    v += a * n * n;
    f *= 2.07;
    a *= 0.48;
  }
  return v;
}

// Katman yüksekliği (bant yüksekliğinin oranı, alttan).
float layerHeight(int layer, float X, int octaves) {
  float base;
  float amp;
  float freq;
  float shift;
  if (layer == 0) { base = 0.40; amp = 0.42; freq = 0.85; shift = 0.15; }
  else if (layer == 1) { base = 0.28; amp = 0.30; freq = 1.5; shift = 0.35; }
  else if (layer == 2) { base = 0.17; amp = 0.20; freq = 2.4; shift = 0.6; }
  else { base = 0.08; amp = 0.10; freq = 3.8; shift = 1.0; }
  float x = X * freq + uParallax * shift + float(layer) * 7.3 + uSeed * 3.0;
  float h = base + amp * (ridged(x, octaves) - 0.35);
  if (layer == 0) {
    // Raman Dağı kütlesi: belirgin, geniş bir ana zirve.
    float d = X - 0.38 * uSize.x / uSize.y;
    h += 0.22 * exp(-d * d * 3.5);
  }
  return h;
}

float atmosAmount(int i) {
  if (i == 0) return 0.62;
  if (i == 1) return 0.42;
  if (i == 2) return 0.22;
  return 0.08;
}

vec3 skyColor(vec2 uv, float aspect, vec3 sunCol, out float cloudMask) {
  vec3 col = mix(uTop, uBottom, smoothstep(0.0, 1.0, uv.y));
  vec2 d = (uv - uSun) * vec2(aspect, 1.0);
  float dist = length(d);
  float day = 1.0 - uNight;
  col += sunCol * exp(-dist * mix(5.0, 2.6, uDusk)) * 0.6 * day;
  col = mix(col, sunCol * 1.2, smoothstep(0.055, 0.04, dist) * day);

  // Akşam ışık hüzmeleri
  float ang = atan(d.y, d.x);
  float rays = pow(max(0.0, sin(ang * 24.0 + noise1(ang * 6.0) * 4.0)), 6.0);
  col += sunCol * rays * exp(-dist * 2.2) * uDusk * day * 0.18;

  vec2 cp = vec2(uv.x * aspect * 1.8, uv.y * 3.2);
  float c1 = fbm2(cp + vec2(uTime * 0.012, 0.0));
  float c2 = fbm2(cp * 2.1 + vec2(uTime * 0.025, 4.0));
  cloudMask = smoothstep(0.5, 0.8, c1 * 0.65 + c2 * 0.45) * smoothstep(0.9, 0.15, uv.y);
  vec3 lit = mix(vec3(1.0), vec3(1.0, 0.7, 0.48), uDusk);
  lit = mix(lit, vec3(0.2, 0.24, 0.36), uNight);
  vec3 shade = lit * mix(0.7, 0.5, uNight);
  // Güneşe bakan bulut kenarları parlak (gümüş astar)
  float silver = smoothstep(0.35, 0.0, dist) * day * 0.6;
  col = mix(col, mix(lit, shade, smoothstep(0.4, 0.9, c2)) + silver * sunCol * 0.4, cloudMask * 0.88);

  if (uNight > 0.2) {
    vec2 sp = uv * uSize / 2.0;
    float s = hash2(floor(sp));
    float tw = 0.55 + 0.45 * sin(uTime * 2.5 + s * 50.0);
    col += vec3(step(0.997, s) * tw * (1.0 - cloudMask) * smoothstep(0.2, 0.9, uNight));
  }
  return col;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / max(uSize.y, 1.0);
  float X = uv.x * aspect;
  float day = 1.0 - uNight;

  vec3 sunCol = mix(vec3(1.0, 0.93, 0.78), vec3(1.0, 0.52, 0.22), uDusk);
  float cloudMask;
  vec3 col = skyColor(uv, aspect, sunCol, cloudMask);

  // Işık yönü: güneş solda/sağda ve yükseklik
  float sunDirX = clamp((uSun.x - 0.5) * 2.2, -1.0, 1.0);
  vec2 L = normalize(vec2(sunDirX, mix(0.25, 1.0, clamp(1.0 - uSun.y, 0.0, 1.0))));

  // Bulut gölgeleri (zemin üzerinde gezinir)
  float cloudShadow = smoothstep(0.55, 0.8, fbm2(vec2(X * 1.2 - uTime * 0.02, 3.0)));

  vec3 farRock = vec3(0.47, 0.42, 0.44);
  vec3 nearRock = vec3(0.52, 0.38, 0.25);
  vec3 haze = mix(uBottom, vec3(0.75, 0.72, 0.7), 0.25 * day);

  for (int i = 0; i < 4; i++) {
    float h = layerHeight(i, X, 6);
    float ridgeY = 1.0 - h;
    if (uv.y >= ridgeY) {
      float t = float(i) / 3.0;
      float depth = uv.y - ridgeY;
      // Işık, yamaç ölçeğindeki kaba yükseklikten: sütun çizgisi oluşmaz.
      float e = 0.035;
      float slope = (layerHeight(i, X + e, 3) - layerHeight(i, X - e, 3)) / (2.0 * e);
      // Sırttan aşağı inildikçe yamaç yüzeyi yuvarlanır (2B hacim hissi).
      float bulge = fbm2(vec2(X * 4.0, depth * 5.0) + float(i) * 3.0) - 0.5;
      vec2 n = normalize(vec2(-slope - bulge * 1.4, 1.0 + depth * 1.5));
      float diff = max(dot(n, L), 0.0);

      vec3 rock = mix(farRock, nearRock, t);
      // Erozyon olukları (yamaç boyunca hafif uzamış) ve tabakalar
      float sc = 8.0 + 10.0 * t;
      float gully = fbm2(vec2(X * sc + depth * slope * 2.0, depth * sc * 0.75) + float(i) * 5.0);
      float strata = noise2(vec2(X * 2.0, (uv.y + X * 0.05) * (26.0 + 20.0 * t)));
      float grain = noise2(vec2(X, uv.y) * (60.0 + 60.0 * t));
      rock *= 0.8 + 0.3 * gully + 0.06 * strata + 0.06 * grain;
      // Açık renkli kireçtaşı yüzleri
      rock = mix(rock, vec3(0.72, 0.66, 0.56), smoothstep(0.6, 0.78, gully) * 0.3);
      // Oluk diplerinde gölge
      float ao = smoothstep(0.42, 0.25, gully) * 0.25;

      float light = (0.42 + 0.8 * diff) * (1.0 - ao);
      vec3 c = rock * light * mix(vec3(1.0), sunCol, 0.35 + 0.4 * uDusk);
      // Gölgeli yüzlerde gökyüzü yansıması
      c += uTop * 0.08 * (1.0 - diff);

      // Çalılık (yakın katmanlarda)
      if (i >= 2) {
        vec2 cell = floor(vec2(X * 160.0, uv.y * 120.0));
        float b = hash2(cell + float(i) * 31.0);
        float shrub = step(0.86, b) * smoothstep(0.0, 0.04, depth);
        c = mix(c, vec3(0.22, 0.26, 0.14) * light, shrub * 0.7);
      }

      // Bulut gölgesi
      c *= 1.0 - 0.28 * cloudShadow * day;

      // Sırt kenarında akşam ışığı (rim)
      float rim = smoothstep(0.006, 0.0, depth) * uDusk * day;
      c += sunCol * rim * 0.5;

      // Vadi sisi: sırtın altına doğru artar
      float fog = smoothstep(0.0, 0.28, depth) * (0.55 - 0.4 * t);
      c = mix(c, haze, fog * 0.6);
      // Atmosferik perspektif
      c = mix(c, haze, atmosAmount(i));

      // Gece: ay ışığı ve köy ışıkları
      c = mix(c, c * vec3(0.28, 0.33, 0.5), uNight * 0.85);
      if (i == 3 && uNight > 0.4) {
        vec2 lc = floor(vec2(X * 90.0, uv.y * 60.0));
        float lamp = step(0.985, hash2(lc + 7.0)) * smoothstep(0.02, 0.08, depth);
        float tw = 0.7 + 0.3 * sin(uTime * 3.0 + hash2(lc) * 20.0);
        c += vec3(1.0, 0.72, 0.35) * lamp * tw * smoothstep(0.4, 0.9, uNight);
      }
      col = c;
    }
  }

  // Ön plan bozkır şeridi
  float plainY = 0.93 + 0.012 * sin(X * 6.0 + uSeed);
  if (uv.y > plainY) {
    float g = fbm2(vec2(X * 30.0, uv.y * 30.0));
    vec3 soil = mix(vec3(0.62, 0.48, 0.32), vec3(0.5, 0.38, 0.24), g);
    float grass = step(0.8, hash2(floor(vec2(X * 220.0, uv.y * 80.0))));
    soil = mix(soil, vec3(0.42, 0.44, 0.22), grass * 0.5);
    soil *= 0.75 + 0.35 * max(L.y, 0.0);
    soil *= 1.0 - 0.25 * cloudShadow * day;
    soil = mix(soil, soil * vec3(0.28, 0.32, 0.48), uNight * 0.85);
    col = soil;
  }

  // İnce film greni
  col += (hash2(frag + fract(uTime) * 61.0) - 0.5) * 0.025;
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
