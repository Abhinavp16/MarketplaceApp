#version 460 core

// Chevrons (> > >) drawn as ordered-dither dots across the slide-to-confirm
// track. They're invisible except where a soft band of light passes, so a
// wave of shimmer sweeps left to right and reveals them.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;   // painted area, logical pixels
uniform float uWave;  // band centre across the track, 0..1; below -0.5 hides
uniform float uCell;  // dot size, logical pixels
uniform float uStart; // arrows begin this far from the left edge
uniform vec4 uColor;  // dot colour (straight alpha = peak opacity)

out vec4 fragColor;

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
  if (uWave < -0.5 || pos.x < uStart) {
    fragColor = vec4(0.0);
    return;
  }

  // Sample at each dot's centre so the arrows read as dots.
  vec2 cell = floor(pos / uCell);
  vec2 p = (cell + 0.5) * uCell;

  // One chevron every `period` px: two arms meeting at an apex on the right.
  float period = 18.0;
  float u = mod(p.x - uStart, period) - period * 0.5;
  float v = p.y - uSize.y * 0.5;
  float halfHeight = uSize.y * 0.17;
  float arm = 4.5 - abs(v);
  float onArm = smoothstep(2.4, 1.0, abs(u - arm));
  float mask = abs(v) < halfHeight ? onArm : 0.0;

  // The wave of light that reveals them.
  float off = (p.x / uSize.x - uWave) / 0.17;
  float band = exp(-off * off);

  float level = mask * band;
  // The floor keeps the band's faint tail from leaving stray dots behind.
  float on = level > bayer8(cell) * 0.94 + 0.06 ? 1.0 : 0.0;
  float alpha = uColor.a * on;
  fragColor = vec4(uColor.rgb * alpha, alpha);
}
