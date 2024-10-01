// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  final Color _backgroundColor = Colors.black;
  double _angle = 0.0;
  double _progress = 0.0;

  late AnimationController _angleController;
  late Animation<double> _angleAnimation;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _angleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    _angleAnimation =
        Tween<double>(begin: 0.0, end: 2 * math.pi).animate(_angleController)
          ..addListener(
            () {
              setState(() {
                _angle = _angleAnimation.value;
              });
            },
          );

    _progressController =
        AnimationController(duration: const Duration(seconds: 30), vsync: this)
          ..repeat(reverse: true);
    final Animation<double> curve =
        CurvedAnimation(parent: _progressController, curve: Curves.easeInOut);
    _progressAnimation = Tween(begin: 0.0, end: 100.0).animate(curve)
      ..addListener(() {
        setState(() {
          _progress = _progressAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _angleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: CustomPaint(
          painter: TrianglePainter(
            backgroundColor: _backgroundColor,
            angle: _angle,
            progress: _progress,
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  const TrianglePainter({
    required this.backgroundColor,
    required this.angle,
    required this.progress,
  });
  final Color backgroundColor;
  final double angle;
  final double progress;

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
    const floatsPerVertex = 4;
    final offset = 0.8;
    final vertexList = <double>[
      // layout: x, y, u, v

      // Triangle #1

      // Bottom left vertex
      -offset, -offset, -1, -1,
      // Bottom right vertex
      offset, -offset, 1, -1,
      // Top left vertex
      -offset, offset, -1, 1,

      // Triangle #2

      // Bottom right vertex
      offset, -offset, 1, -1,
      // Top right vertex
      offset, offset, 1, 1,
      // Top left vertex
      -offset, offset, -1, 1,
    ];
    final verticesDeviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
      ByteData.sublistView(Float32List.fromList(vertexList)),
    );
    if (verticesDeviceBuffer == null) {
      throw Exception('Failed to create vertices device buffer');
    }

    final model = vm.Matrix4.rotationY(angle);
    final view = vm.Matrix4.translation(vm.Vector3(0.0, 0.0, -2.0));
    final projection =
        vm.makePerspectiveMatrix(vm.radians(45), size.aspectRatio, 0.1, 100);
    final vertUniforms = [model, view, projection];

    final vertUniformsDeviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
        ByteData.sublistView(Float32List.fromList(
            vertUniforms.expand((m) => m.storage).toList())));

    if (vertUniformsDeviceBuffer == null) {
      throw Exception('Failed to create vert uniforms device buffer');
    }

    final fragUniforms = [progress];
    final fragUniformsDeviceBuffer = gpu.gpuContext.createDeviceBufferWithCopy(
        ByteData.sublistView(Float32List.fromList(fragUniforms)));

    if (fragUniformsDeviceBuffer == null) {
      throw Exception('Failed to create frag uniforms device buffer');
    }

    renderPass.bindPipeline(pipeline);

    final verticesView = gpu.BufferView(
      verticesDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: verticesDeviceBuffer.sizeInBytes,
    );
    renderPass.bindVertexBuffer(
        verticesView, vertexList.length ~/ floatsPerVertex);

    final vertUniformsView = gpu.BufferView(
      vertUniformsDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: vertUniformsDeviceBuffer.sizeInBytes,
    );

    renderPass.bindUniform(vert.getUniformSlot('VertInfo'), vertUniformsView);

    final fragUniformsView = gpu.BufferView(
      fragUniformsDeviceBuffer,
      offsetInBytes: 0,
      lengthInBytes: fragUniformsDeviceBuffer.sizeInBytes,
    );

    renderPass.bindUniform(frag.getUniformSlot('FragInfo'), fragUniformsView);

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
