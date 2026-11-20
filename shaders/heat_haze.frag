#version 460 core
// Batman sıcağı: yükselen ısı dalgaları ve sıcak renk tonu (yarı saydam katman).
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uStrength;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float y = uv.y * 40.0 + uTime * 3.0;
  float wave = sin(uv.x * 18.0 + sin(y) * 1.5 + uTime * 2.0) * sin(y * 0.7 - uTime * 1.3);
  float band = smoothstep(0.6, 1.0, wave) * 0.12;
  float ground = smoothstep(0.3, 1.0, uv.y);
  vec3 warm = vec3(1.0, 0.62, 0.25);
  float a = (0.10 + band) * uStrength * (0.4 + 0.6 * ground);
  fragColor = vec4(warm * a, a);
}
