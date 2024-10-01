// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#version 460 core

in vec2 vertex_uv;

out vec4 frag_color;

uniform FragInfo { float progress; };

// Adapted for Flutter from https://www.youtube.com/shorts/h5PuIm6fRr8
float mandelbrot(vec2 uv) {
  const float MAX_ITER = 128;
  vec2 c = 2.4 * uv - vec2(0.7, 0.0);
  vec2 z = vec2(0.0);

  for (float iter = 0.0; iter < MAX_ITER; iter++) {
    z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    if (length(z) > 4.0) {
      return iter / MAX_ITER;
    }
  }

  return 0.0;
}

vec3 hash13(float m) {
  if (m == 0.0)
    return vec3(0.0);

  float r = fract(sin(m) * progress);
  float g = fract(sin(m + r));
  float b = fract(sin(m + r + g));
  return vec3(r, g, b);
}

void main() {
  float m = mandelbrot(vertex_uv);
  vec3 col = hash13(m);

  frag_color = vec4(col, 1.0);
}
