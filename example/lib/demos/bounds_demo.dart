import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../shared/bounds_grid_background.dart';

class BoundsDemoPage extends StatefulWidget {
  const BoundsDemoPage({super.key});

  @override
  State<BoundsDemoPage> createState() => _BoundsDemoPageState();
}

class _BoundsDemoPageState extends State<BoundsDemoPage> {
  late final CanvasKitController _controller;

  // Fixed bounds rectangle
  static const Rect _bounds = Rect.fromLTWH(-500, -400, 1000, 800);

  // State tracking
  bool _isInitialized = false;
  Offset? _lastPanPosition;

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Helper: Get the visible world rectangle
  Rect _getVisibleWorldRect(Size viewportSize) {
    final topLeft = _controller.screenToWorld(Offset.zero);
    final bottomRight = _controller.screenToWorld(
      Offset(viewportSize.width, viewportSize.height),
    );

    return Rect.fromLTRB(
      math.min(topLeft.dx, bottomRight.dx),
      math.min(topLeft.dy, bottomRight.dy),
      math.max(topLeft.dx, bottomRight.dx),
      math.max(topLeft.dy, bottomRight.dy),
    );
  }

  // Helper: Calculate minimum scale to fit bounds in viewport
  double _getMinimumScale(Size viewportSize) {
    return math.max(
      viewportSize.width / _bounds.width,
      viewportSize.height / _bounds.height,
    );
  }

  // Helper: Constrain the view to bounds
  void _constrainToBounds(Size viewportSize) {
    final visibleRect = _getVisibleWorldRect(viewportSize);

    double dx = 0;
    double dy = 0;

    // If the visible area is smaller than bounds, ensure it stays within
    if (visibleRect.width < _bounds.width) {
      if (visibleRect.left < _bounds.left) {
        dx = _bounds.left - visibleRect.left;
      } else if (visibleRect.right > _bounds.right) {
        dx = _bounds.right - visibleRect.right;
      }
    } else {
      // If visible area is larger than bounds, center the bounds
      dx = _bounds.center.dx - visibleRect.center.dx;
    }

    if (visibleRect.height < _bounds.height) {
      if (visibleRect.top < _bounds.top) {
        dy = _bounds.top - visibleRect.top;
      } else if (visibleRect.bottom > _bounds.bottom) {
        dy = _bounds.bottom - visibleRect.bottom;
      }
    } else {
      // If visible area is larger than bounds, center the bounds
      dy = _bounds.center.dy - visibleRect.center.dy;
    }

    if (dx != 0 || dy != 0) {
      // Note: translateWorld moves the world, which moves the view in the opposite direction
      _controller.translateWorld(Offset(-dx, -dy));
    }
  }

  // Initialize the view centered on bounds
  void _initializeView(Size viewportSize) {
    if (_isInitialized) return;
    _isInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Set initial scale to fit bounds
      final minScale = _getMinimumScale(viewportSize);
      _controller.setScale(minScale * 1.1); // Slightly zoomed in from minimum

      // Center on bounds
      final visibleRect = _getVisibleWorldRect(viewportSize);
      final dx = _bounds.center.dx - visibleRect.center.dx;
      final dy = _bounds.center.dy - visibleRect.center.dy;

      if (dx != 0 || dy != 0) {
        _controller.translateWorld(Offset(-dx, -dy));
      }

      if (kDebugMode) {
        print('[BoundsDemo] Initialized with scale: ${_controller.scale}');
      }
    });
  }

  void _handleWheel(PointerScrollEvent event, Size viewportSize) {
    // Calculate scale change
    final scaleDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    final currentScale = _controller.scale;

    // Calculate minimum scale to prevent zooming out beyond bounds
    final minScale = math.max(
      _controller.minZoom,
      _getMinimumScale(viewportSize),
    );

    // Apply scale with constraints
    final newScale = (currentScale * scaleDelta).clamp(
      minScale,
      _controller.maxZoom,
    );

    // Scale around the pointer position
    final focalWorld = _controller.screenToWorld(event.localPosition);
    _controller.setScale(newScale, focalWorld: focalWorld);

    // Ensure we stay within bounds after scaling
    _constrainToBounds(viewportSize);

    if (kDebugMode) {
      print(
        '[BoundsDemo] Zoom: ${currentScale.toStringAsFixed(3)} -> ${newScale.toStringAsFixed(3)}',
      );
    }
  }

  void _handlePanStart(DragStartDetails details) {
    _lastPanPosition = details.localPosition;
  }

  void _handlePanUpdate(DragUpdateDetails details, Size viewportSize) {
    if (_lastPanPosition == null) return;

    // Calculate world delta
    final screenDelta = details.localPosition - _lastPanPosition!;
    final worldDelta = _controller.deltaScreenToWorld(screenDelta);

    // Apply the translation
    _controller.translateWorld(worldDelta);

    // Constrain to bounds
    _constrainToBounds(viewportSize);

    // Update last position
    _lastPanPosition = details.localPosition;

    if (kDebugMode && worldDelta.distance > 0) {
      final visibleRect = _getVisibleWorldRect(viewportSize);
      debugPrint('[BoundsDemo] Pan: delta=$worldDelta, visible=$visibleRect');
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _lastPanPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      appBar: null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          // Initialize view on first build
          if (!_isInitialized) {
            _initializeView(viewportSize);
          }

          return CanvasKit(
            controller: _controller,
            interactionMode: InteractionMode.programmatic,
            backgroundBuilder: (transform) => BoundsGridBackground(
              transform: transform,
              bounds: _bounds,
              backgroundColor: const Color(0xFFF2F8FF),
              gridSpacing: 80,
              gridColor: const Color(0x22000000),
              frameColor: const Color(0xFF303030),
              frameWidth: 32,
            ),
            gestureOverlayBuilder: (transform, controller) {
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _handleWheel(event, viewportSize);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _handlePanStart,
                  onPanUpdate: (details) =>
                      _handlePanUpdate(details, viewportSize),
                  onPanEnd: _handlePanEnd,
                  child: Stack(
                    children: [
                      // Canvas items
                      CanvasKitScope(
                        transform: transform,
                        scale: controller.scale,
                        controller: controller,
                        transformRevision: controller.transformRevision,
                        child: SimpleCanvas(
                          transform: transform,
                          scale: controller.scale,
                          viewportSize: viewportSize,
                          controller: controller,
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
                                  border: Border.all(
                                    color: Colors.black26,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  '0,0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Bounds visualization (optional - remove if not needed)
                            CanvasItem(
                              id: 'bounds',
                              worldPosition: _bounds.topLeft,
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
                          ],
                        ),
                      ),
                      // Debug info overlay (optional)
                      if (kDebugMode)
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
                              stream: Stream.periodic(
                                const Duration(milliseconds: 100),
                              ),
                              builder: (context, snapshot) {
                                final visible = _getVisibleWorldRect(
                                  viewportSize,
                                );
                                return Text(
                                  'Scale: ${controller.scale.toStringAsFixed(2)}\n'
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
                ),
              );
            },
            children: const [],
          );
        },
      ),
    );
  }
}
