#version 460 core

// Liquid light for the Profile identity card: soft pools of light that melt
// and shift like light on water. Three sine waves over a gently warped grid.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;   // painted area, logical pixels
uniform float uTime;  // seconds
uniform vec4 uColor;  // light colour (straight alpha = peak opacity)

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy / 52.0;
  float t = uTime;

  // Warp the grid so the waves bend into blobs instead of stripes.
  vec2 q = vec2(
    p.x + 0.6 * sin(p.y * 1.3 + t * 0.5),
    p.y + 0.6 * cos(p.x * 1.1 - t * 0.4)
  );

  float n = sin(q.x * 1.2 + t * 0.6)
          + sin(q.y * 1.7 - t * 0.45)
          + sin((q.x + q.y) * 0.8 + t * 0.3);
  n = (n + 3.0) / 6.0;

  // Only the crests light up; everything else stays the card's own green.
  float level = pow(max(0.0, n - 0.45) / 0.55, 1.6);

  float alpha = uColor.a * level;
  fragColor = vec4(uColor.rgb * alpha, alpha);
}
