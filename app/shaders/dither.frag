// 1-bit ordered (Bayer 8x8) dither — renders a sampled image as
// monochrome dots in the active palette tint.
//
// Inputs:
//   uResolution — render rect size in logical pixels
//   uTint       — fg color of the active palette (RGB; alpha unused)
//   uImage      — source image sampler
//
// Output:
//   Premultiplied RGBA. Cells either fully on (uTint) or fully off
//   (transparent), giving the cover photo the same CRT phosphor look
//   the rest of the UI uses.

#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uResolution;
uniform vec4 uTint;
uniform sampler2D uImage;

out vec4 fragColor;

// 8x8 Bayer matrix, normalised to (0, 1). Standard order — produces
// even, anisotropy-free patterns at any zoom level.
const float bayer[64] = float[64](
   0.0/64.0, 32.0/64.0,  8.0/64.0, 40.0/64.0,  2.0/64.0, 34.0/64.0, 10.0/64.0, 42.0/64.0,
  48.0/64.0, 16.0/64.0, 56.0/64.0, 24.0/64.0, 50.0/64.0, 18.0/64.0, 58.0/64.0, 26.0/64.0,
  12.0/64.0, 44.0/64.0,  4.0/64.0, 36.0/64.0, 14.0/64.0, 46.0/64.0,  6.0/64.0, 38.0/64.0,
  60.0/64.0, 28.0/64.0, 52.0/64.0, 20.0/64.0, 62.0/64.0, 30.0/64.0, 54.0/64.0, 22.0/64.0,
   3.0/64.0, 35.0/64.0, 11.0/64.0, 43.0/64.0,  1.0/64.0, 33.0/64.0,  9.0/64.0, 41.0/64.0,
  51.0/64.0, 19.0/64.0, 59.0/64.0, 27.0/64.0, 49.0/64.0, 17.0/64.0, 57.0/64.0, 25.0/64.0,
  15.0/64.0, 47.0/64.0,  7.0/64.0, 39.0/64.0, 13.0/64.0, 45.0/64.0,  5.0/64.0, 37.0/64.0,
  63.0/64.0, 31.0/64.0, 55.0/64.0, 23.0/64.0, 61.0/64.0, 29.0/64.0, 53.0/64.0, 21.0/64.0
);

void main() {
  vec2 fragCoord = FlutterFragCoord();

  // Sample the source image at the matching UV.
  vec2 uv = fragCoord / uResolution;
  vec3 srcRgb = texture(uImage, uv).rgb;

  // Rec. 601 luma — close enough to perceptual brightness without the
  // cost of a colour-space conversion.
  float luma = dot(srcRgb, vec3(0.299, 0.587, 0.114));

  // Lift mids slightly so dark photos still register at all.
  luma = pow(luma, 0.85);

  // Bayer threshold for the current pixel.
  ivec2 cell = ivec2(mod(fragCoord, 8.0));
  float threshold = bayer[cell.y * 8 + cell.x];

  float on = step(threshold, luma);
  fragColor = vec4(uTint.rgb * on, on);
}
