import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../shared/grid_background.dart';

class BoundsDemoAltPage extends StatefulWidget {
  const BoundsDemoAltPage({super.key});

  @override
  State<BoundsDemoAltPage> createState() => _BoundsDemoAltPageState();
}

class _BoundsDemoAltPageState extends State<BoundsDemoAltPage> {
  late final CanvasKitController _controller;

  // Define the boundary rectangle in world coordinates (now 9x original, same center)
  // Original:  Rect.fromLTWH(-500, -400, 1000, 800)
  // 3x:       Rect.fromLTWH(-1500, -1200, 3000, 2400)
  // 9x:       Rect.fromLTWH(-4500, -3600, 9000, 7200)
  static const Rect _bounds = Rect.fromLTWH(-4500, -3600, 9000, 7200);

  // Track if bounds are enabled
  bool _boundsEnabled = true;

  // For interactive mode demo (default to interactive so items are draggable)
  bool _interactiveMode = true;

  // Draggable item positions (kept in state so they visually move)
  Offset _item1Pos = const Offset(100, 100);
  Offset _item2Pos = const Offset(-200, -150);
  Offset _bigNodePos = const Offset(0, 0);

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController(
      bounds: _bounds,
      enableBoundaryConstraints: _boundsEnabled,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleBounds() {
    setState(() {
      _boundsEnabled = !_boundsEnabled;
      _controller.enableBoundaryConstraints = _boundsEnabled;
    });
  }

  void _toggleMode() {
    setState(() {
      _interactiveMode = !_interactiveMode;
    });
  }

  void _resetView() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _controller.fitToBounds(renderBox.size, padding: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bounds Demo (Alt ${_interactiveMode ? "Interactive" : "Programmatic"})',
        ),
        actions: [
          IconButton(
            icon: Icon(_boundsEnabled ? Icons.lock : Icons.lock_open),
            onPressed: _toggleBounds,
            tooltip: _boundsEnabled ? 'Disable Bounds' : 'Enable Bounds',
          ),
          IconButton(
            icon: Icon(_interactiveMode ? Icons.touch_app : Icons.code),
            onPressed: _toggleMode,
            tooltip: 'Toggle Mode',
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: _resetView,
            tooltip: 'Reset View',
          ),
        ],
      ),
      body: Stack(
        children: [
          CanvasKit(
            controller: _controller,
            interactionMode: _interactiveMode
                ? InteractionMode.interactive
                : InteractionMode.programmatic,
            bounds: _boundsEnabled ? _bounds : null,
            autoFitToBounds: true,
            boundsFitPadding: 40,
            backgroundBuilder: (transform) => GridBackground(
              transform: transform,
              backgroundColor: const Color(0xFFF2F8FF),
              gridSpacing: 80,
              gridColor: const Color(0x22000000),
            ),
            foregroundLayers: _boundsEnabled
                ? [
                    (Matrix4 transform) => _BoundsCornerPainter(
                      transform: transform,
                      bounds: _bounds,
                    ),
                  ]
                : const [],
            children: [
              // Origin marker
              CanvasItem(
                id: 'origin',
                worldPosition: const Offset(-20, -20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black26, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '0,0',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              // Big demo node for easy dragging visibility
              CanvasItem(
                id: 'big-node',
                worldPosition: _bigNodePos,
                draggable: true,
                onWorldMoved: (pos) {
                  // ignore: avoid_print
                  print('[AltBounds] big-node moved to $pos');
                  setState(() => _bigNodePos = pos);
                },
                child: Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Drag This Big Node',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              // Bounds visualization
              if (_boundsEnabled)
                CanvasItem(
                  id: 'bounds',
                  worldPosition: _bounds.topLeft,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Container(
                      width: _bounds.width,
                      height: _bounds.height,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              // Some items within bounds
              CanvasItem(
                id: 'item1',
                worldPosition: _item1Pos,
                draggable: true,
                onWorldMoved: (newPosition) =>
                    setState(() => _item1Pos = newPosition),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Drag Me!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              CanvasItem(
                id: 'item2',
                worldPosition: _item2Pos,
                draggable: true,
                onWorldMoved: (newPosition) =>
                    setState(() => _item2Pos = newPosition),
                child: Container(
                  width: 600,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Another Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Info overlay
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: StreamBuilder(
                stream: Stream.periodic(const Duration(milliseconds: 100)),
                builder: (context, snapshot) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null || !renderBox.hasSize) {
                    return const Text(
                      'Loading...',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }

                  final visible = _controller.getVisibleWorldRect(
                    renderBox.size,
                  );
                  return Text(
                    'Scale: ${_controller.scale.toStringAsFixed(2)}\n'
                    'Bounds: ${_boundsEnabled ? "ON" : "OFF"}\n'
                    'Mode: ${_interactiveMode ? "Interactive" : "Programmatic"}\n'
                    'Visible: (${visible.left.toStringAsFixed(0)}, ${visible.top.toStringAsFixed(0)}) '
                    'to (${visible.right.toStringAsFixed(0)}, ${visible.bottom.toStringAsFixed(0)})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundsCornerPainter extends CustomPainter {
  final Matrix4 transform;
  final Rect bounds;

  _BoundsCornerPainter({required this.transform, required this.bounds});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    final Paint stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final radius = 6.0;

    // Convert world points to screen using full transform
    Offset w2s(Offset wp) {
      final v = Vector3(wp.dx, wp.dy, 0)..applyMatrix4(transform);
      return Offset(v.x, v.y);
    }

    final corners = <Offset>[
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ].map(w2s).toList();

    for (final p in corners) {
      canvas.drawCircle(p, radius, fill);
      canvas.drawCircle(p, radius, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _BoundsCornerPainter old) {
    return old.transform != transform || old.bounds != bounds;
  }
}
