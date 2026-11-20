#version 460 core
// Petrol yüzeyinde ince film girişimi: akışkan yanardöner renkler.
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
  vec2 i = floor(p); vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 p = uv * vec2(6.0, 3.0);
  float n = noise(p + vec2(uTime * 0.2, uTime * 0.1)) * 0.6 + noise(p * 2.3 - uTime * 0.15) * 0.4;
  float thickness = n * 6.2831 + uTime * 0.3;
  vec3 film = 0.5 + 0.5 * cos(thickness + vec3(0.0, 2.1, 4.2));
  float mask = smoothstep(0.5, 0.8, n);
  vec3 base = vec3(0.045, 0.036, 0.03);
  // İnce film renkleri: doygunluğu düşük, koyu zemin üzerinde hafif parıltı.
  vec3 sheen = mix(vec3(dot(film, vec3(0.333))), film, 0.6) * 0.32 + 0.03;
  float spec = pow(max(0.0, sin(uv.x * 9.0 + uTime * 0.7) * cos(uv.y * 5.0 - uTime * 0.4)), 12.0) * 0.25;
  vec3 col = mix(base, sheen, mask * 0.5) + vec3(spec);
  fragColor = vec4(col, 1.0);
}
