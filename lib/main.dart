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
  Color _foregroundColor = const Color.fromARGB(255, 211, 91, 5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => Dialog(
                child: SingleChildScrollView(
                  child: SlidePicker(
                    pickerColor: _foregroundColor,
                    onColorChanged: (pickedColor) {
                      setState(() {
                        _foregroundColor = pickedColor;
                      });
                    },
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
            child: const Text('Foreground'),
          ),
          TextButton(
            onPressed: () => showDialog(
              context: context,
              builder: (context) => Dialog(
                child: SingleChildScrollView(
                  child: SlidePicker(
                    pickerColor: _backgroundColor,
                    onColorChanged: (pickedColor) {
                      setState(() {
                        _backgroundColor = pickedColor;
                      });
                    },
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
            child: const Text('Background'),
          ),
        ],
      ),
      body: SizedBox.expand(
        child: CustomPaint(
          painter: TrianglePainter(
            foregroundColor: _foregroundColor,
            backgroundColor: _backgroundColor,
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  const TrianglePainter({
    required this.foregroundColor,
    required this.backgroundColor,
  });
  final Color foregroundColor;
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
          // x, y
          -0.5, -0.5, // First vertex
          0.5, -0.5, // Second vertex
          0.0, 0.5, // Third vertex
        ]),
      ),
    );
    if (verticesDeviceBuffer == null) {
      throw Exception('Failed to create device buffer');
    }

    final colorBuffer = gpu.gpuContext
        .createDeviceBufferWithCopy(ByteData.sublistView(Float32List.fromList([
      foregroundColor.red / 255.0,
      foregroundColor.green / 255.0,
      foregroundColor.blue / 255.0,
      1.0,
    ])));
    if (colorBuffer == null) {
      throw Exception('Failed to create color buffer');
    }

    renderPass.bindPipeline(pipeline);

    final verticesView = gpu.BufferView(
      verticesDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: verticesDeviceBuffer.sizeInBytes,
    );
    renderPass.bindVertexBuffer(verticesView, 3);

    final colorView = gpu.BufferView(
      colorBuffer,
      offsetInBytes: 0,
      lengthInBytes: colorBuffer.sizeInBytes,
    );
    renderPass.bindUniform(frag.getUniformSlot('FragInfo'), colorView);

    renderPass.draw();

    commandBuffer.submit();
    final image = texture.asImage();
    canvas.drawImage(image, Offset.zero, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
