#version 460 core
// Gerçekçi jeolojik kesit: dalgalı/kubbeli sınırlar ve her kayaç türü için
// prosedürel doku. Sınır formülü CrossSectionPainter ile birebir aynıdır.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uSurface;   // yüzeyin göreli yüksekliği
uniform float uNight;
uniform vec4 uCum;        // katman 1..4 kümülatif sınır oranları (0..1 yeraltı)
uniform vec3 uC0;
uniform vec3 uC1;
uniform vec3 uC2;
uniform vec3 uC3;
uniform vec3 uC4;
uniform vec4 uP03;        // katman 0..3 desen türleri
uniform float uP4;        // katman 4 desen türü

out vec4 fragColor;

const float PI = 3.14159265;

float hash(vec2 p) {
  p = fract(p * vec2(233.34, 851.73));
  p += dot(p, p + 23.45);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + 3.7;
    a *= 0.5;
  }
  return v;
}

// x: hücre içi en yakın mesafe, y: ikinci en yakın, zw: hücre kimliği
vec4 voronoi(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float d1 = 8.0;
  float d2 = 8.0;
  vec2 id = vec2(0.0);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
      float d = length(g + o - f);
      if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
    }
  }
  return vec4(d1, d2, id);
}

float cumAt(int i) {
  if (i <= 0) return 0.0;
  if (i == 1) return uCum.x;
  if (i == 2) return uCum.y;
  if (i == 3) return uCum.z;
  if (i == 4) return uCum.w;
  return 2.0;
}

// CrossSectionPainter.boundary ile aynı formül (y, tüm yüksekliğin oranı).
float boundary(int i, float xn) {
  float ug = 1.0 - uSurface;
  if (i == 0) return uSurface;
  if (i >= 5) return 2.0;
  float base = uSurface + ug * cumAt(i);
  float dome = 0.0;
  float dx = (xn - 0.5) * 3.2;
  if (i >= 3) dome = -ug * 0.05 * exp(-dx * dx);
  return base + sin(xn * 2.0 * PI * 1.3 + float(i) * 1.7) * ug * 0.012 + sin(xn * 2.0 * PI * 3.1 + float(i)) * ug * 0.006 + dome;
}

vec3 colorOf(int i) {
  if (i == 0) return uC0;
  if (i == 1) return uC1;
  if (i == 2) return uC2;
  if (i == 3) return uC3;
  return uC4;
}

float patternOf(int i) {
  if (i == 0) return uP03.x;
  if (i == 1) return uP03.y;
  if (i == 2) return uP03.z;
  if (i == 3) return uP03.w;
  return uP4;
}

vec3 soil(vec2 p, vec3 c, float top) {
  float g = fbm(p * 0.08);
  vec3 col = c * (0.78 + 0.4 * g);
  // Kökler: üst kısımda ince koyu dallanmalar
  float root = smoothstep(0.03, 0.0, abs(fbm(vec2(p.x * 0.06, p.y * 0.015)) - 0.5)) * smoothstep(60.0, 0.0, top);
  col = mix(col, c * 0.4, root * 0.7);
  vec4 v = voronoi(p * 0.12);
  float peb = smoothstep(0.3, 0.22, v.x) * step(0.8, hash(v.zw));
  col = mix(col, mix(vec3(0.55, 0.5, 0.44), vec3(0.75, 0.7, 0.6), hash(v.zw + 3.0)) * (1.1 - v.x), peb);
  col *= 0.9 + 0.2 * hash(floor(p));
  return col;
}

vec3 clay(vec2 p, vec3 c) {
  float w = fbm(p * vec2(0.01, 0.03)) * 18.0;
  float lam = sin(p.y * 0.55 + w) * 0.5 + 0.5;
  float lam2 = sin(p.y * 1.7 + w * 1.3) * 0.5 + 0.5;
  vec3 col = c * (0.82 + 0.18 * lam + 0.08 * lam2);
  col = mix(col, c * vec3(1.15, 1.05, 0.9), smoothstep(0.7, 0.9, fbm(p * 0.03)) * 0.4);
  col *= 0.94 + 0.12 * noise(p * 0.8);
  return col;
}

vec3 rock(vec2 p, vec3 c) {
  vec4 v = voronoi(p * vec2(0.045, 0.06));
  float edge = v.y - v.x;
  float tone = hash(v.zw);
  vec3 col = c * (0.75 + 0.45 * tone);
  // Blok kenarı: üstten ışık, alttan gölge (bevel)
  float bevel = smoothstep(0.0, 0.18, edge);
  col *= 0.55 + 0.45 * bevel;
  col *= 0.88 + 0.24 * fbm(p * 0.15);
  // Çatlak dolgusu (açık renk kalsit damarları)
  float vein = smoothstep(0.02, 0.0, abs(fbm(p * 0.02) - 0.5)) * 0.6;
  col = mix(col, vec3(0.82, 0.8, 0.75), vein * 0.4);
  return col;
}

vec3 limestone(vec2 p, vec3 c) {
  float bed = fract(p.y / 13.0 + fbm(p * 0.01) * 0.6);
  float plane = smoothstep(0.06, 0.0, bed) + smoothstep(0.94, 1.0, bed);
  float row = floor(p.y / 13.0 + fbm(p * 0.01) * 0.6);
  float joint = smoothstep(0.04, 0.0, abs(fract(p.x / (28.0 + 10.0 * hash(vec2(row, 1.0))) + hash(vec2(row, 2.0))) - 0.5) - 0.46);
  vec3 col = c * (0.85 + 0.2 * fbm(p * 0.05));
  col *= 1.0 - 0.35 * plane - 0.25 * joint;
  // Fosil kabukları ve çörtler
  vec4 v = voronoi(p * 0.07);
  float fossil = smoothstep(0.16, 0.1, v.x) * step(0.88, hash(v.zw));
  float ring = smoothstep(0.03, 0.0, abs(v.x - 0.12)) * step(0.88, hash(v.zw));
  col = mix(col, c * 1.18, fossil * 0.5);
  col = mix(col, c * 0.6, ring * 0.6);
  col *= 0.95 + 0.1 * hash(floor(p * 0.7));
  return col;
}

vec3 reservoir(vec2 p, vec3 c) {
  // Gözenekli kumtaşı: tane tane
  float grain = hash(floor(p * 0.9));
  vec3 col = mix(vec3(0.42, 0.36, 0.28), vec3(0.6, 0.52, 0.4), grain);
  col *= 0.75 + 0.35 * fbm(p * 0.05);
  vec4 v = voronoi(p * 0.35);
  col *= 0.7 + 0.3 * smoothstep(0.0, 0.3, v.x);
  return mix(col, c, 0.35);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float xn = uv.x;
  if (uv.y < uSurface - 0.002) {
    fragColor = vec4(0.0);
    return;
  }

  int layer = 4;
  for (int i = 1; i <= 4; i++) {
    if (uv.y < boundary(i, xn)) {
      layer = i - 1;
      break;
    }
  }
  float top = (uv.y - boundary(layer, xn)) * uSize.y;      // katman üstünden piksel
  float bottom = (boundary(layer + 1, xn) - uv.y) * uSize.y;
  vec2 p = frag;
  vec3 c = colorOf(layer);
  float kind = patternOf(layer);

  vec3 col;
  if (kind < 0.5) col = soil(p, c, top);
  else if (kind < 1.5) col = clay(p, c);
  else if (kind < 2.5) col = rock(p, c);
  else if (kind < 3.5) col = limestone(p, c);
  else col = reservoir(p, c);

  // Katman temasları: üstte ince açık şerit, altta gölge
  col *= 1.0 + 0.12 * smoothstep(4.0, 0.0, top);
  col *= 1.0 - 0.3 * smoothstep(10.0, 0.0, bottom);
  col *= 1.0 - 0.5 * smoothstep(1.6, 0.0, top) * step(1.0, float(layer));

  // Derinlikle artan karanlık ve gece
  float depth = (uv.y - uSurface) / (1.0 - uSurface);
  col *= 1.0 - 0.45 * depth;
  col = mix(col, col * vec3(0.55, 0.6, 0.75), uNight * 0.5);

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
