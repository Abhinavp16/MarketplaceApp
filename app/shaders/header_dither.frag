#version 460 core

// Ordered (Bayer) dither for the Home header: light pooled in the top-right
// corner is drawn as a grid of small dots, and a soft band of extra dots can
// sweep diagonally across.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;   // painted area, logical pixels
uniform float uSweep; // sweep position 0..1, or below 0 when idle
uniform float uCell;  // dot size, logical pixels
uniform vec4 uColor;  // dot colour (straight alpha)

out vec4 fragColor;

// Recursive Bayer thresholds, 0..1.
float bayer2(vec2 a) {
  a = floor(a);
  return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a) {
  return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

float bayer8(vec2 a) {
  return bayer4(0.5 * a) * 0.25 + bayer2(a);
}

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 uv = pos / uSize;

  // Light pooling in the top-right corner, fading towards the bottom-left.
  float d = distance(uv * vec2(1.0, uSize.y / uSize.x), vec2(1.0, 0.0));
  float light = smoothstep(0.95, 0.0, d) * 0.5;

  // The sweep: a soft diagonal band travelling from left to right.
  float band = 0.0;
  if (uSweep >= 0.0) {
    float along = (uv.x + (1.0 - uv.y)) * 0.5;
    float centre = mix(-0.25, 1.25, uSweep);
    float offset = (along - centre) / 0.11;
    band = exp(-offset * offset) * 0.42;
  }

  float level = clamp(light + band, 0.0, 1.0);
  float threshold = bayer8(floor(pos / uCell));
  float on = level > threshold ? 1.0 : 0.0;

  float alpha = uColor.a * on;
  fragColor = vec4(uColor.rgb * alpha, alpha);
}
