#version 460 core
// Prosedürel gökyüzü: dikey gradyan, güneş ışıması, fbm bulutlar, gece yıldızları.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform vec3 uTop;
uniform vec3 uBottom;
uniform float uNight;
uniform float uDusk;
uniform vec2 uSun;   // göreli güneş konumu (0..1)

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.03 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  float aspect = uSize.x / max(uSize.y, 1.0);

  vec3 col = mix(uTop, uBottom, smoothstep(0.0, 1.0, uv.y));

  // Güneş ışıması (gün batımında daha geniş ve turuncu)
  vec2 d = (uv - uSun) * vec2(aspect, 1.0);
  float dist = length(d);
  vec3 sunCol = mix(vec3(1.0, 0.95, 0.8), vec3(1.0, 0.55, 0.2), uDusk);
  float glow = exp(-dist * mix(6.0, 3.0, uDusk)) * (1.0 - uNight);
  col += sunCol * glow * 0.55;
  col = mix(col, sunCol, smoothstep(0.06, 0.045, dist) * (1.0 - uNight));

  // Bulutlar: iki katman, farklı hızlarda kayar
  vec2 cp = vec2(uv.x * aspect * 2.2, uv.y * 3.0);
  float c1 = fbm(cp + vec2(uTime * 0.015, 0.0));
  float c2 = fbm(cp * 1.8 + vec2(uTime * 0.03, 3.0));
  float cloud = smoothstep(0.52, 0.78, c1 * 0.65 + c2 * 0.45) * smoothstep(1.0, 0.25, uv.y);
  vec3 cloudLit = mix(vec3(1.0), vec3(1.0, 0.72, 0.5), uDusk);
  cloudLit = mix(cloudLit, vec3(0.22, 0.26, 0.38), uNight);
  vec3 cloudShade = cloudLit * mix(0.72, 0.55, uNight);
  float shade = smoothstep(0.4, 0.9, c2);
  col = mix(col, mix(cloudLit, cloudShade, shade), cloud * 0.85);

  // Yıldızlar
  if (uNight > 0.2) {
    vec2 sp = frag / 2.5;
    float s = hash(floor(sp));
    float twinkle = 0.6 + 0.4 * sin(uTime * 3.0 + s * 40.0);
    float star = step(0.9965, s) * twinkle * (1.0 - cloud) * smoothstep(0.2, 0.9, uNight);
    col += vec3(star);
  }

  // Ufuk pusu
  col = mix(col, uBottom, smoothstep(0.75, 1.0, uv.y) * 0.4);
  fragColor = vec4(col, 1.0);
}
