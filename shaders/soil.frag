#version 460 core
// Kurak bozkır toprağı: renk lekeleri, çakıllar, kılcal çatlaklar, kuru ot,
// yukarıdan gelen ışık ve gece tonlaması. Zamandan bağımsızdır (önbelleklenir).
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uNight;
uniform float uSeed;
uniform float uScale;   // doku ölçeği (piksel başına)
uniform vec3 uBase;     // ana toprak rengi

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(234.34, 435.345) + uSeed * 0.17);
  p += dot(p, p + 34.23);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + 3.1;
    a *= 0.5;
  }
  return v;
}

// Hücresel (voronoi) mesafe: çakıl ve çatlak deseni için.
vec2 voronoi(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float d1 = 8.0;
  float d2 = 8.0;
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 g = vec2(float(x), float(y));
      vec2 o = vec2(hash(i + g), hash(i + g + 19.0));
      float d = length(g + o - f);
      if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
    }
  }
  return vec2(d1, d2);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  vec2 p = frag / uScale;

  // Büyük ölçekli renk lekeleri (nem, mineral farkı)
  float big = fbm(p * 0.05);
  float mid = fbm(p * 0.25 + 7.0);
  vec3 col = uBase * (0.82 + 0.3 * big);
  col = mix(col, uBase * vec3(1.18, 1.1, 0.95), smoothstep(0.55, 0.75, mid) * 0.5);
  col = mix(col, uBase * vec3(0.75, 0.7, 0.66), smoothstep(0.45, 0.25, mid) * 0.4);

  // Kılcal kuraklık çatlakları
  vec2 v = voronoi(p * 0.09);
  float crack = smoothstep(0.06, 0.0, v.y - v.x);
  col *= 1.0 - crack * 0.35 * smoothstep(0.4, 0.6, big);

  // Çakıllar: küçük, üstten ışıklı taşlar
  vec2 sv = voronoi(p * 0.55 + 11.0);
  float stone = smoothstep(0.22, 0.17, sv.x) * step(0.72, hash(floor(p * 0.55 + 11.0)));
  vec3 stoneCol = mix(vec3(0.62, 0.58, 0.52), vec3(0.42, 0.38, 0.34), hash(floor(p * 0.55)));
  float stoneLight = 0.8 + 0.4 * (0.5 - fract(p.y * 0.55 + 11.0));
  col = mix(col, stoneCol * stoneLight, stone);

  // İnce kum taneciği
  col *= 0.92 + 0.16 * hash(floor(frag));

  // Kuru ot tutamları
  float tuft = step(0.985, hash(floor(p * 0.35)));
  vec2 tf = fract(p * 0.35) - 0.5;
  float blade = smoothstep(0.08, 0.0, abs(tf.x + tf.y * 0.3)) * smoothstep(0.4, -0.2, tf.y);
  col = mix(col, vec3(0.55, 0.5, 0.28), tuft * blade * 0.8);

  // Yukarıdan gelen ışık ve kenar kararması
  col *= 1.05 - 0.25 * uv.y;
  float vig = smoothstep(1.2, 0.4, length((uv - 0.5) * vec2(1.0, 1.3)));
  col *= 0.8 + 0.2 * vig;

  col = mix(col, col * vec3(0.27, 0.31, 0.46), uNight * 0.85);
  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
