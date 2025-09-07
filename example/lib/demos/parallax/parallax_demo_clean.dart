import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../../shared/grid_background.dart';
import '../widgets/parallax_widget.dart';

class ParallaxDemoCleanPage extends StatefulWidget {
  const ParallaxDemoCleanPage({super.key});

  @override
  State<ParallaxDemoCleanPage> createState() => _ParallaxDemoCleanPageState();
}

class _ParallaxDemoCleanPageState extends State<ParallaxDemoCleanPage> {
  late final CanvasKitController _controller;
  Offset _parallaxPosition = Offset.zero;
  double _parallaxInternalScale = 1.0;
  Offset _parallax2Position = const Offset(1600, 0);
  double _parallax2Scale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
    // After first layout, fit the camera to include both parallax widgets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final viewportSize = renderBox.size;

      final r1 = Rect.fromLTWH(
        _parallaxPosition.dx,
        _parallaxPosition.dy,
        1200 * _parallaxInternalScale,
        800 * _parallaxInternalScale,
      );
      final r2 = Rect.fromLTWH(
        _parallax2Position.dx,
        _parallax2Position.dy,
        1200 * _parallax2Scale,
        800 * _parallax2Scale,
      );
      _controller.fitToRects([r1, r2], viewportSize, padding: 120);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parallax (Programmatic Mode)')),
      body: CanvasKit(
        controller: _controller,
        // Add grid background
        backgroundBuilder: (t) => GridBackground(
          transform: t,
          backgroundColor: const Color(0xFFFFF7E6),
          gridSpacing: 80,
          gridColor: const Color(0x22000000),
        ),
        children: [
          // Main parallax widget (PARALLAX)
          CanvasItem(
            id: 'parallax-widget',
            worldPosition: _parallaxPosition,
            draggable:
                false, // Don't make this draggable to avoid gesture conflicts
            child: ParallaxWidget(
              layers: const [
                'assets/PARALLAX/layer_01_1920 x 1080.png',
                'assets/PARALLAX/layer_02_1920 x 1080.png',
                'assets/PARALLAX/layer_03_1920 x 1080.png',
                'assets/PARALLAX/layer_04_1920 x 1080.png',
                'assets/PARALLAX/layer_05_1920 x 1080.png',
                'assets/PARALLAX/layer_06_1920 x 1080.png',
                'assets/PARALLAX/layer_07_1920 x 1080.png',
                'assets/PARALLAX/layer_08_1920 x 1080.png',
              ],
              size: const Size(1200, 800),
              autoScroll: true,
              scrollSpeed: 0.5,
              externalScale:
                  _parallaxInternalScale, // Pass external scale from resize handle
            ),
          ),
          // Draggable handle/tab for moving the parallax widget
          CanvasItem(
            id: 'parallax-handle',
            worldPosition: Offset(
              _parallaxPosition.dx - 50,
              _parallaxPosition.dy - 50,
            ), // Top-left of parallax
            draggable: true,
            onWorldMoved: (newHandlePos) {
              setState(() {
                // Update parallax position based on handle position
                _parallaxPosition = Offset(
                  newHandlePos.dx + 50,
                  newHandlePos.dy + 50,
                );
              });
            },
            child: Container(
              width: 80,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'DRAG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_parallaxInternalScale.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white70, fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
          // Resize handle for scaling the parallax widget
          CanvasItem(
            id: 'parallax-resize-handle',
            worldPosition: Offset(
              _parallaxPosition.dx +
                  (1200 * _parallaxInternalScale) -
                  30, // Bottom-right follows scaled size
              _parallaxPosition.dy + (800 * _parallaxInternalScale) - 30,
            ),
            draggable: true,
            onWorldMoved: (newHandlePos) {
              setState(() {
                // Calculate scale based on handle position relative to parallax top-left
                final handleOffset = newHandlePos - _parallaxPosition;
                // Use the larger dimension (width or height ratio) to determine scale
                final widthScale =
                    (handleOffset.dx + 30) / 1200; // +30 for handle size offset
                final heightScale = (handleOffset.dy + 30) / 800;
                final newScale =
                    (widthScale + heightScale) /
                    2; // Average of both dimensions
                _parallaxInternalScale = newScale.clamp(0.5, 3.0);
              });
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

          // Second parallax widget (PARALLAX2)
          CanvasItem(
            id: 'parallax2-widget',
            worldPosition: _parallax2Position,
            draggable: false,
            child: ParallaxWidget(
              layers: const [
                'assets/PARALLAX2/layer_01_1920 x 1080.png',
                'assets/PARALLAX2/layer_02_1920 x 1080.png',
                'assets/PARALLAX2/layer_03_1920 x 1080.png',
                'assets/PARALLAX2/layer_04_1920 x 1080.png',
                'assets/PARALLAX2/layer_05_1920 x 1080.png',
                'assets/PARALLAX2/layer_06_1920 x 1080.png',
                'assets/PARALLAX2/layer_07_1920 x 1080.png',
              ],
              size: const Size(1200, 800),
              autoScroll: true,
              scrollSpeed: 0.5,
              externalScale: _parallax2Scale,
            ),
          ),
          // Move handle for second parallax
          CanvasItem(
            id: 'parallax2-handle',
            worldPosition: Offset(
              _parallax2Position.dx - 50,
              _parallax2Position.dy - 50,
            ),
            draggable: true,
            onWorldMoved: (newHandlePos) {
              setState(() {
                _parallax2Position = Offset(
                  newHandlePos.dx + 50,
                  newHandlePos.dy + 50,
                );
              });
            },
            child: Container(
              width: 80,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'DRAG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_parallax2Scale.toStringAsFixed(1)}x',
                    style: const TextStyle(color: Colors.white70, fontSize: 8),
                  ),
                ],
              ),
            ),
          ),
          // Resize handle for second parallax
          CanvasItem(
            id: 'parallax2-resize-handle',
            worldPosition: Offset(
              _parallax2Position.dx + (1200 * _parallax2Scale) - 30,
              _parallax2Position.dy + (800 * _parallax2Scale) - 30,
            ),
            draggable: true,
            onWorldMoved: (newHandlePos) {
              setState(() {
                final handleOffset = newHandlePos - _parallax2Position;
                final widthScale = (handleOffset.dx + 30) / 1200;
                final heightScale = (handleOffset.dy + 30) / 800;
                final newScale = (widthScale + heightScale) / 2;
                _parallax2Scale = newScale.clamp(0.5, 3.0);
              });
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.open_in_full,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
