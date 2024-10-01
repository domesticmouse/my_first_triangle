// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:vector_math/vector_math.dart' as vm;

const String _kShaderBundlePath =
    'build/shaderbundles/my_first_triangle.shaderbundle';

gpu.ShaderLibrary? _shaderLibrary;

gpu.ShaderLibrary get shaderLibrary {
  _shaderLibrary ??= gpu.ShaderLibrary.fromAsset(_kShaderBundlePath);
  if (_shaderLibrary == null) {
    throw Exception('Failed to load shader bundle');
  }

  return _shaderLibrary!;
}

void main() {
  runApp(
    const MaterialApp(
      title: 'Flutter GPU Triangle Demo',
      debugShowCheckedModeBanner: false,
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  Color _backgroundColor = const Color.fromARGB(255, 40, 80, 110);
  Color _color1 = const Color.fromARGB(255, 255, 50, 50);
  Color _color2 = const Color.fromARGB(255, 50, 255, 50);
  Color _color3 = const Color.fromARGB(255, 50, 50, 255);
  Color _color4 = const Color.fromARGB(255, 50, 255, 255);
  double _angle = 0.0;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();
    _animation =
        Tween<double>(begin: 0.0, end: 8 * math.pi).animate(_controller)
          ..addListener(
            () {
              setState(() {
                _angle = _animation.value;
              });
            },
          );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building with angle $_angle');
    return Scaffold(
      appBar: AppBar(
        actions: [
          VertexColorButton(
              name: 'TL Vertex',
              color: _color1,
              onUpdate: (pickedColor) {
                setState(() {
                  _color1 = pickedColor;
                });
              }),
          VertexColorButton(
              name: 'TR Vertex',
              color: _color2,
              onUpdate: (pickedColor) {
                setState(() {
                  _color2 = pickedColor;
                });
              }),
          VertexColorButton(
              name: 'BL Vertex',
              color: _color3,
              onUpdate: (pickedColor) {
                setState(() {
                  _color3 = pickedColor;
                });
              }),
          VertexColorButton(
              name: 'BR Vertex',
              color: _color4,
              onUpdate: (pickedColor) {
                setState(() {
                  _color4 = pickedColor;
                });
              }),
          VertexColorButton(
              name: 'Background',
              color: _backgroundColor,
              onUpdate: (pickedColor) {
                setState(() {
                  _backgroundColor = pickedColor;
                });
              }),
        ],
      ),
      body: SizedBox.expand(
        child: CustomPaint(
          painter: TrianglePainter(
            color1: _color1,
            color2: _color2,
            color3: _color3,
            color4: _color4,
            backgroundColor: _backgroundColor,
            angle: _angle,
          ),
        ),
      ),
    );
  }
}

class VertexColorButton extends StatelessWidget {
  const VertexColorButton({
    super.key,
    required this.name,
    required this.color,
    required this.onUpdate,
  });
  final String name;
  final Color color;
  final Function(Color color) onUpdate;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => showDialog(
        context: context,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            child: SlidePicker(
              pickerColor: color,
              onColorChanged: onUpdate,
              colorModel: ColorModel.rgb,
              enableAlpha: false,
              displayThumbColor: false,
              showParams: false,
              indicatorBorderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25.0),
                topRight: Radius.circular(25.0),
              ),
            ),
          ),
        ),
      ),
      child: Text(name),
    );
  }
}

class TrianglePainter extends CustomPainter {
  const TrianglePainter({
    required this.color1,
    required this.color2,
    required this.color3,
    required this.color4,
    required this.backgroundColor,
    required this.angle,
  });
  final Color color1;
  final Color color2;
  final Color color3;
  final Color color4;
  final Color backgroundColor;
  final double angle;

  @override
  void paint(Canvas canvas, Size size) {
    final texture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate, size.width.ceil(), size.height.ceil());
    if (texture == null) {
      throw Exception('Failed to create texture');
    }

    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: texture,
        clearValue: backgroundColor.vec4,
        loadAction: gpu.LoadAction.clear,
        storeAction: gpu.StoreAction.store,
      ),
    );

    final commandBuffer = gpu.gpuContext.createCommandBuffer();
    final renderPass = commandBuffer.createRenderPass(renderTarget);

    final vert = shaderLibrary['SimpleVertex'];
    if (vert == null) {
      throw Exception('Failed to load SimpleVertex vertex shader');
    }

    final frag = shaderLibrary['SimpleFragment'];
    if (frag == null) {
      throw Exception('Failed to load SimpleFragment fragment shader');
    }

    final pipeline = gpu.gpuContext.createRenderPipeline(vert, frag);
    const floatsPerVertex = 6;
    final offset = 0.6;
    final vertexList = [
      // layout: x, y, r, g, b, a

      // Triangle #1

      // Bottom left vertex
      -offset, -offset, color3.r, color3.g, color3.b, color3.a,
      // Bottom right vertex
      offset, -offset, color4.r, color4.g, color4.b, color4.a,
      // Top left vertex
      -offset, offset, color1.r, color1.g, color1.b, color1.a,

      // Triangle #2

      // Bottom right vertex
      offset, -offset, color4.r, color4.g, color4.b, color4.a,
      // Top right vertex
      offset, offset, color2.r, color2.g, color2.b, color2.a,
      // Top left vertex
      -offset, offset, color1.r, color1.g, color1.b, color1.a,
    ];
    final verticesDeviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(Float32List.fromList(vertexList)),
    );
    if (verticesDeviceBuffer == null) {
      throw Exception('Failed to create vertices device buffer');
    }

    final model =
        vm.Matrix4.rotationY(angle).multiplied(vm.Matrix4.rotationX(angle / 2));
    final view = vm.Matrix4.translation(vm.Vector3(0.0, 0.0, -2.0));
    final projection =
        vm.makePerspectiveMatrix(vm.radians(45), size.aspectRatio, 0.1, 100);
    final uniforms = [model, view, projection];

    final uniformsDeviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
        ByteData.sublistView(
            Float32List.fromList(uniforms.expand((m) => m.storage).toList())));

    if (uniformsDeviceBuffer == null) {
      throw Exception('Failed to create uniforms device buffer');
    }

    renderPass.bindPipeline(pipeline);

    final verticesView = gpu.BufferView(
      verticesDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: verticesDeviceBuffer.sizeInBytes,
    );
    renderPass.bindVertexBuffer(
        verticesView, vertexList.length ~/ floatsPerVertex);

    final uniformsView = gpu.BufferView(
      uniformsDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: uniformsDeviceBuffer.sizeInBytes,
    );

    renderPass.bindUniform(vert.getUniformSlot('VertInfo'), uniformsView);

    renderPass.draw();

    commandBuffer.submit();
    final image = texture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

extension _ToVec4 on Color {
  vm.Vector4 get vec4 => vm.Vector4(r, g, b, a);
}
