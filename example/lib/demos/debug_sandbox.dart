import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A minimal page to debug simultaneous pinch and mouse wheel zoom/pan
/// without depending on the CanvasKit package.
class DebugSandboxPage extends StatefulWidget {
  const DebugSandboxPage({super.key});

  @override
  State<DebugSandboxPage> createState() => _DebugSandboxPageState();
}

class _DebugSandboxPageState extends State<DebugSandboxPage> {
  // Camera state
  double _scale = 1.0; // zoom
  Offset _offset = Offset.zero; // world origin in screen space

  // Gesture session state
  double? _scaleStart;
  Offset? _focalWorldStart;

  static const double _minScale = 0.2;
  static const double _maxScale = 5.0;

  // Helpers ---------------------------------------------------------------
  Offset _screenToWorld(Offset screen) => (screen - _offset) / _scale;
  Offset _worldToScreen(Offset world) => world * _scale + _offset;

  void _applyZoomAround(Offset screenFocal, double nextScale) {
    nextScale = nextScale.clamp(_minScale, _maxScale);
    final worldFocal = _screenToWorld(screenFocal);
    // Keep world focal locked under the same screen point
    final nextOffset = screenFocal - worldFocal * nextScale;
    if (kDebugMode) {
      debugPrint('[Sandbox] zoomAround focalScreen=$screenFocal worldFocal=$worldFocal '
          'scaleBefore=${_scale.toStringAsFixed(3)} -> scaleAfter=${nextScale.toStringAsFixed(3)}');
    }
    setState(() {
      _scale = nextScale;
      _offset = nextOffset;
    });
  }

  void _applyPanScreen(Offset screenDelta) {
    if (kDebugMode) {
      debugPrint('[Sandbox] pan screenDelta=$screenDelta');
    }
    setState(() {
      _offset += screenDelta;
    });
  }

  // UI -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Sandbox: Pinch + Wheel'),
        actions: [
          IconButton(
            tooltip: 'Reset',
            onPressed: () => setState(() {
              _scale = 1.0;
              _offset = Offset.zero;
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                // Trackpad or mouse wheel. Translate vertical scroll to zoom.
                final box = context.findRenderObject() as RenderBox?;
                final local = box?.globalToLocal(event.position) ?? Offset(constraints.maxWidth / 2, constraints.maxHeight / 2);
                // dy < 0 => zoom in, dy > 0 => zoom out
                final double factor = math.pow(1.0015, -event.scrollDelta.dy).toDouble();
                final nextScale = _scale * factor;
                if (kDebugMode) {
                  debugPrint('[Sandbox] wheel delta=${event.scrollDelta} local=$local factor=${factor.toStringAsFixed(3)}');
                }
                _applyZoomAround(local, nextScale);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (details) {
                _scaleStart = _scale;
                _focalWorldStart = _screenToWorld(details.localFocalPoint);
                if (kDebugMode) {
                  debugPrint('[Sandbox] onScaleStart pointers=${details.pointerCount} '
                      'focalLocal=${details.localFocalPoint} scaleStart=${_scaleStart!.toStringAsFixed(3)} '
                      'focalWorldStart=$_focalWorldStart');
                }
              },
              onScaleUpdate: (details) {
                final pointerCount = details.pointerCount;
                final focalLocal = details.localFocalPoint;

                // Zoom component (pinch) ------------------------------------------------
                final startScale = _scaleStart ?? _scale;
                final pinchScale = (startScale * details.scale).clamp(_minScale, _maxScale);

                if (pointerCount >= 2) {
                  // Maintain focal lock while scaling
                  final worldFocal = _focalWorldStart ?? _screenToWorld(focalLocal);
                  final nextOffset = focalLocal - worldFocal * pinchScale;
                  if (kDebugMode) {
                    debugPrint('[Sandbox] onScaleUpdate pinch pointers=$pointerCount scaleFactor=${details.scale.toStringAsFixed(3)} '
                        'nextScale=${pinchScale.toStringAsFixed(3)} focalLocal=$focalLocal focalDelta=${details.focalPointDelta}');
                  }
                  setState(() {
                    _scale = pinchScale;
                    _offset = nextOffset;
                  });
                } else {
                  // Single finger: pan only
                  final panDelta = details.focalPointDelta;
                  if (kDebugMode) {
                    debugPrint('[Sandbox] onScaleUpdate pan pointers=$pointerCount panDelta=$panDelta');
                  }
                  _applyPanScreen(panDelta);
                }
              },
              onScaleEnd: (_) {
                _scaleStart = null;
                _focalWorldStart = null;
                if (kDebugMode) debugPrint('[Sandbox] onScaleEnd');
              },
              child: CustomPaint(
                painter: _GridPainter(scale: _scale, offset: _offset),
                child: Stack(
                  children: [
                    // A couple of world-anchored sample nodes
                    _worldNode(const Offset(100, 100), color: Colors.red, label: 'A'),
                    _worldNode(const Offset(300, 220), color: Colors.blue, label: 'B'),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _worldNode(Offset worldPos, {required Color color, required String label}) {
    final screenPos = _worldToScreen(worldPos);
    return Positioned(
      left: screenPos.dx - 30,
      top: screenPos.dy - 20,
      child: IgnorePointer(
        child: Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double scale;
  final Offset offset;
  const _GridPainter({required this.scale, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF7E6));

    // Draw grid in screen space using world spacing 80px
    const worldSpacing = 80.0;
    final screenSpacing = worldSpacing * scale;
    final origin = offset; // world (0,0) in screen coordinates

    final paint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.0;

    // Vertical lines
    double x = origin.dx % screenSpacing;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      x += screenSpacing;
    }
    // Horizontal lines
    double y = origin.dy % screenSpacing;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += screenSpacing;
    }

    // Axis lines
    canvas.drawLine(Offset(origin.dx, 0), Offset(origin.dx, size.height), Paint()..color = Colors.red.withValues(alpha: 0.4));
    canvas.drawLine(Offset(0, origin.dy), Offset(size.width, origin.dy), Paint()..color = Colors.green.withValues(alpha: 0.4));

    // HUD text
    final tp = TextPainter(
      text: TextSpan(
        text: 'scale=${scale.toStringAsFixed(3)}\noffset=${offset.dx.toStringAsFixed(1)}, ${offset.dy.toStringAsFixed(1)}',
        style: const TextStyle(color: Colors.black87, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    tp.paint(canvas, const Offset(8, 8));
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.offset != offset;
  }
}
