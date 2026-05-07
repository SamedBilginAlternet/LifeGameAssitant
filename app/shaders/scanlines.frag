// CRT scanline overlay.
//
// Inputs:
//   uResolution — viewport size in logical pixels
//   uTime       — wall-clock seconds since shader start (drift)
//   uOpacity    — base scanline opacity from CrtTheme (0.10 / 0.12)
//   uTint       — fg color of the active palette (RGB)
//
// Output:
//   premultiplied RGBA. The shader is rendered over the app's content
//   via AnimatedSampler so transparency falls through.
//
// Why fragment shader, not BoxDecoration repeating-image: we want sub-
// pixel vertical drift on a 4-second loop, plus the ability to clamp
// opacity by the active palette without bundling separate PNG strips.

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform float uTime;
uniform float uOpacity;
uniform vec4 uTint;

out vec4 fragColor;

void main() {
  vec2 fragCoord = FlutterFragCoord();

  // 4-second sine drift, amplitude 2px.
  float drift = sin(uTime * 1.5707963) * 2.0; // PI/2

  // Lines at 4px stride. (sin pattern gives a soft top/bottom edge.)
  float y = fragCoord.y + drift;
  float scanline = 0.5 + 0.5 * sin(y * 1.5707963); // PI/2 → period 4

  // Heavily biased so only the bright bands carry visible alpha.
  scanline = pow(scanline, 8.0);

  float alpha = scanline * uOpacity;
  fragColor = vec4(uTint.rgb * alpha, alpha);
}
