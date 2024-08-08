// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;

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

class _MyAppState extends State<MyApp> {
  Color _backgroundColor = const Color.fromARGB(255, 41, 92, 117);
  Color _color1 = const Color.fromARGB(255, 255, 0, 0);
  Color _color2 = const Color.fromARGB(255, 0, 255, 0);
  Color _color3 = const Color.fromARGB(255, 0, 0, 255);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          _buildVertexColorButton('Vert1', _color1, (pickedColor) {
            setState(() {
              _color1 = pickedColor;
            });
          }),
          _buildVertexColorButton('Vert2', _color2, (pickedColor) {
            setState(() {
              _color2 = pickedColor;
            });
          }),
          _buildVertexColorButton('Vert3', _color3, (pickedColor) {
            setState(() {
              _color3 = pickedColor;
            });
          }),
          _buildVertexColorButton('Background', _backgroundColor, (pickedColor) {
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
            backgroundColor: _backgroundColor,
          ),
        ),
      ),
    );
  }

  _buildVertexColorButton(
      String name, Color color, Function(Color color) onUpdate) {
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
    required this.backgroundColor,
  });
  final Color color1;
  final Color color2;
  final Color color3;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('Painting triangle, size: $size');

    final texture = gpu.gpuContext.createTexture(
        gpu.StorageMode.devicePrivate, size.width.ceil(), size.height.ceil());
    if (texture == null) {
      throw Exception('Failed to create texture');
    }

    final renderTarget = gpu.RenderTarget.singleColor(
      gpu.ColorAttachment(
        texture: texture,
        clearValue: backgroundColor,
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

    final verticesDeviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(
        Float32List.fromList([
          // layout:
          //   x, y
          //   vertex color (r,g,b,a)
          -0.5, -0.5, // First vertex
          color1.red / 255, color1.green / 255, color1.blue / 255,
          color1.alpha / 255, // vertex color
          0.5, -0.5, // Second vertex
          color2.red / 255, color2.green / 255, color2.blue / 255,
          color2.alpha / 255, // vertex color
          0.0, 0.5, // Third vertex
          color3.red / 255, color3.green / 255, color3.blue / 255,
          color3.alpha / 255, // vertex color
        ]),
      ),
    );
    if (verticesDeviceBuffer == null) {
      throw Exception('Failed to create device buffer');
    }

    renderPass.bindPipeline(pipeline);

    final verticesView = gpu.BufferView(
      verticesDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: verticesDeviceBuffer.sizeInBytes,
    );
    renderPass.bindVertexBuffer(verticesView, 3);

    renderPass.draw();

    commandBuffer.submit();
    final image = texture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
