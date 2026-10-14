#version 460 core

// Language switch: a snapshot of the screen in the old language dissolves
// behind a curved wave travelling from the top-left to the bottom-right. The
// wave's edge is an ordered (Bayer) dither, and a trail of tinted dots
// follows it, so the new language is revealed dot by dot.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;      // painted area, logical pixels
uniform float uProgress; // 0 = old screen everywhere, 1 = fully revealed
uniform float uCell;     // dot size, logical pixels
uniform vec4 uTint;      // trail dot colour (straight alpha)
uniform sampler2D uImage; // the old screen

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

  // Distance along the top-left -> bottom-right diagonal, bent into a
  // gentle curve that sways as the wave travels.
  float along = (uv.x + uv.y) * 0.5;
  float across = uv.x - uv.y;
  float curve = 0.06 * sin(across * 3.2 + uProgress * 4.0);

  const float band = 0.10;   // width of the dithered edge
  const float trail = 0.16;  // width of the dot trail behind it
  float front = mix(-band - 0.08, 1.0 + band + trail + 0.08, uProgress);
  // > 0 ahead of the wave (old screen), < 0 behind it (new screen).
  float level = (along + curve - front) / band;

  float threshold = bayer8(floor(pos / uCell));

  // The edge: the old screen thins out into dots.
  if (level * 0.5 + 0.5 > threshold) {
    fragColor = texture(uImage, uv);
    return;
  }

  // Just behind the edge: tinted dots that thin out with distance.
  float behind = clamp(1.0 + level * band / trail, 0.0, 1.0);
  if (behind * 0.55 > threshold) {
    float alpha = uTint.a * behind;
    fragColor = vec4(uTint.rgb * alpha, alpha);
    return;
  }

  fragColor = vec4(0.0);
}
