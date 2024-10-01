// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#version 460 core

in vec2 position;
in vec4 color;

out vec4 vertex_color;

uniform VertInfo {
  mat4 model;
  mat4 view;
  mat4 projection;
};

void main() {
  gl_Position = projection * view * model * vec4(position, 0.0, 1.0);
  vertex_color = color;
}
