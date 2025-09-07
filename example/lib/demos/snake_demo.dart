import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:canvas_kit/canvas_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

class SnakeDemoPage extends StatefulWidget {
  const SnakeDemoPage({super.key});

  @override
  State<SnakeDemoPage> createState() => _SnakeDemoPageState();
}

class _SnakeDemoPageState extends State<SnakeDemoPage> {
  static const double worldWidth = 2000;
  static const double worldHeight = 2000;
  static const Duration tick = Duration(milliseconds: 16); // ~60 FPS
  static const double speed = 140; // px per second
  static const int maxSegments = 30; // fixed length for simplicity
  static const Size segmentSize = Size(16, 16);

  late final CanvasKitController _controller;
  Timer? _timer;
  final FocusNode _focusNode = FocusNode();

  // Snake state
  List<Offset> _segments = [];
  Offset _dir = const Offset(1, 0); // moving right

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
    _resetSnake(centerCamera: false);
    _timer = Timer.periodic(tick, _onTick);
    // Zoom out to show most of the world on first layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = context.size ?? MediaQuery.of(context).size;
      _controller.fitToWorldRect(
        const Rect.fromLTWH(0, 0, worldWidth, worldHeight),
        size,
        padding: 120,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetSnake({bool centerCamera = false}) {
    final Offset center = const Offset(worldWidth / 2, worldHeight / 2);
    _dir = const Offset(1, 0);
    _segments = List.generate(
      8,
      (i) => center - Offset(i * segmentSize.width, 0),
    );
    if (centerCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = context.size ?? MediaQuery.of(context).size;
        _controller.centerOn(center, size);
      });
    }
  }

  void _onTick(Timer t) {
    if (!mounted) return;
    final double dt = tick.inMilliseconds / 1000.0;
    final double step = speed * dt;

    // compute new head
    final Offset head = _segments.first;
    final Offset newHead = head + _dir * step;

    // check bounds
    if (newHead.dx < 0 ||
        newHead.dy < 0 ||
        newHead.dx > worldWidth ||
        newHead.dy > worldHeight) {
      setState(() {
        _resetSnake(centerCamera: false);
      });
      return;
    }

    setState(() {
      _segments.insert(0, newHead);
      // trim to fixed length
      if (_segments.length > maxSegments) {
        _segments.removeRange(maxSegments, _segments.length);
      }
    });
  }

  void _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return; // only handle keydown once
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.keyW) {
      _dir = const Offset(0, -1);
    } else if (key == LogicalKeyboardKey.keyS) {
      _dir = const Offset(0, 1);
    } else if (key == LogicalKeyboardKey.keyA) {
      _dir = const Offset(-1, 0);
    } else if (key == LogicalKeyboardKey.keyD) {
      _dir = const Offset(1, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Snake demo (2000x2000 world, WASD)'),
        actions: [
          IconButton(
            tooltip: 'Center on Snake',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              if (_segments.isNotEmpty) {
                final size = MediaQuery.of(context).size;
                _controller.centerOn(_segments.first, size);
              }
            },
          ),
          IconButton(
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(() => _resetSnake(centerCamera: true)),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: CanvasKit(
          controller: _controller,
          // Let users pan/zoom normally while the snake moves
          interactionMode: InteractionMode.interactive,
          backgroundBuilder: (transform) => _SnakeBackground(
            transform: transform,
            worldRect: const Rect.fromLTWH(0, 0, worldWidth, worldHeight),
          ),
          children: [
            // Draw snake segments as world-anchored items
            for (int i = 0; i < _segments.length; i++)
              CanvasItem(
                id: 'seg-$i',
                worldPosition: _segments[i],
                draggable: false,
                child: Container(
                  width: segmentSize.width,
                  height: segmentSize.height,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? Colors.greenAccent.shade400
                        : Colors.lightGreen,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.green.shade900, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SnakeBackground extends StatelessWidget {
  final Matrix4 transform;
  final Rect worldRect;
  const _SnakeBackground({required this.transform, required this.worldRect});

  Offset _worldToScreen(Offset worldPoint) {
    final v = Vector3(worldPoint.dx, worldPoint.dy, 0)..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SnakeBackgroundPainter(
            transform: transform,
            worldRect: worldRect,
            project: _worldToScreen,
          ),
        );
      },
    );
  }
}

class _SnakeBackgroundPainter extends CustomPainter {
  final Matrix4 transform;
  final Rect worldRect;
  final Offset Function(Offset) project;

  _SnakeBackgroundPainter({
    required this.transform,
    required this.worldRect,
    required this.project,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill screen black
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.black);

    // Project world rect corners to screen space to draw white area.
    final topLeft = project(worldRect.topLeft);
    final topRight = project(worldRect.topRight);
    final bottomLeft = project(worldRect.bottomLeft);
    final bottomRight = project(worldRect.bottomRight);

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SnakeBackgroundPainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.worldRect != worldRect;
  }
}
