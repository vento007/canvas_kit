import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// Grid background widget that can handle DragTarget drops for creating new nodes
class DroppableGridBackground extends StatelessWidget {
  final Matrix4 transform;
  final double gridSpacing;
  final Color backgroundColor;
  final Color gridColor;
  final bool itemDragActive;
  final String? hoveredNodeId;
  final void Function(dynamic data, Offset worldPosition)? onAcceptDrop;
  final CanvasKitController controller;
  final GlobalKey canvasKey;

  const DroppableGridBackground({
    super.key,
    required this.transform,
    required this.controller,
    required this.canvasKey,
    this.gridSpacing = 50.0,
    this.backgroundColor = const Color(0xFFFAFAFA),
    this.gridColor = const Color(0x66999999),
    this.itemDragActive = false,
    this.hoveredNodeId,
    this.onAcceptDrop,
  });

  @override
  Widget build(BuildContext context) {
    Widget gridWidget = CustomPaint(
      painter: _DroppableGridPainter(
        transform: transform,
        gridSpacing: gridSpacing,
        backgroundColor: backgroundColor,
        gridColor: gridColor,
        itemDragActive: itemDragActive,
        canAcceptDrop: itemDragActive && hoveredNodeId == null,
      ),
      child: Container(), // Fill available space
    );

    // Use GestureDetector with opaque behavior to receive pointer events in background
    debugPrint(
      '[GRID DRAGTARGET] itemDragActive=$itemDragActive, hoveredNodeId=$hoveredNodeId, onAcceptDrop=${onAcceptDrop != null}',
    );

    if (itemDragActive && onAcceptDrop != null) {
      return DragTarget(
        onWillAcceptWithDetails: (details) {
          final accept = hoveredNodeId == null;
          debugPrint(
            '[GRID DROP] willAccept (hovered=$hoveredNodeId) => $accept',
          );
          return accept;
        },
        onAcceptWithDetails: (details) {
          final data = details.data;
          debugPrint('[GRID DROP] accepted data=$data');
          final ctx = canvasKey.currentContext;
          if (ctx != null) {
            final box = ctx.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.offset);
            final world = controller.screenToWorld(local);
            onAcceptDrop?.call(data, world);
          }
        },
        builder: (context, candidate, rejected) {
          return GestureDetector(
            behavior: HitTestBehavior
                .opaque, // KEY: This allows background to receive events!
            child: gridWidget,
          );
        },
      );
    }

    return gridWidget;
  }
}

class _DroppableGridPainter extends CustomPainter {
  final Matrix4 transform;
  final double gridSpacing;
  final Color backgroundColor;
  final Color gridColor;
  final bool itemDragActive;
  final bool canAcceptDrop;

  _DroppableGridPainter({
    required this.transform,
    required this.gridSpacing,
    required this.backgroundColor,
    required this.gridColor,
    this.itemDragActive = false,
    this.canAcceptDrop = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill background with visual feedback when ready to accept drops
    Color actualBackgroundColor = backgroundColor;
    if (canAcceptDrop) {
      // Tint the background green when ready to accept drops
      actualBackgroundColor =
          Color.lerp(backgroundColor, Colors.green.withValues(alpha: 0.1), 0.5) ??
          backgroundColor;
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = actualBackgroundColor,
    );

    final Paint gridPaint = Paint()
      ..color = canAcceptDrop ? Colors.green.withValues(alpha: 0.3) : gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = canAcceptDrop ? 1.5 : 1.0;

    // Slightly thicker paint for the world origin axes (x=0 and y=0)
    final Paint axisPaint = Paint()
      ..color = canAcceptDrop ? Colors.green.withValues(alpha: 0.4) : gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = canAcceptDrop ? 3.0 : 2.0;

    // Calculate what world coordinates are currently visible
    final worldTopLeft = _screenToWorld(Offset.zero);
    final worldBottomRight = _screenToWorld(Offset(size.width, size.height));

    // Align grid start to grid spacing
    final startX = (worldTopLeft.dx / gridSpacing).floor() * gridSpacing;
    final startY = (worldTopLeft.dy / gridSpacing).floor() * gridSpacing;
    final endX = worldBottomRight.dx;
    final endY = worldBottomRight.dy;

    // Draw vertical grid lines
    for (double worldX = startX; worldX <= endX; worldX += gridSpacing) {
      final p1 = _worldToScreen(Offset(worldX, worldTopLeft.dy));
      final p2 = _worldToScreen(Offset(worldX, worldBottomRight.dy));
      canvas.drawLine(p1, p2, gridPaint);
    }

    // Draw horizontal grid lines
    for (double worldY = startY; worldY <= endY; worldY += gridSpacing) {
      final p1 = _worldToScreen(Offset(worldTopLeft.dx, worldY));
      final p2 = _worldToScreen(Offset(worldBottomRight.dx, worldY));
      canvas.drawLine(p1, p2, gridPaint);
    }

    // Draw the origin axes thicker if visible in the viewport
    final bool originVerticalVisible =
        worldTopLeft.dx <= 0 && worldBottomRight.dx >= 0;
    final bool originHorizontalVisible =
        worldTopLeft.dy <= 0 && worldBottomRight.dy >= 0;
    if (originVerticalVisible) {
      final p1 = _worldToScreen(Offset(0, worldTopLeft.dy));
      final p2 = _worldToScreen(Offset(0, worldBottomRight.dy));
      canvas.drawLine(p1, p2, axisPaint);
    }
    if (originHorizontalVisible) {
      final p1 = _worldToScreen(Offset(worldTopLeft.dx, 0));
      final p2 = _worldToScreen(Offset(worldBottomRight.dx, 0));
      canvas.drawLine(p1, p2, axisPaint);
    }

    // Draw a single origin marker at (0,0) if visible
    final Paint markerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final originScreen = _worldToScreen(const Offset(0, 0));
    if (originScreen.dx >= -20 &&
        originScreen.dx <= size.width + 20 &&
        originScreen.dy >= -20 &&
        originScreen.dy <= size.height + 20) {
      canvas.drawCircle(originScreen, 6.0, markerPaint);

      final textSpan = const TextSpan(
        text: '0,0',
        style: TextStyle(color: Colors.black, fontSize: 12),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, originScreen + const Offset(10, -6));
    }
  }

  Offset _screenToWorld(Offset screenPoint) {
    final inverted = Matrix4.inverted(transform);
    final Vector3 v = Vector3(screenPoint.dx, screenPoint.dy, 0)
      ..applyMatrix4(inverted);
    return Offset(v.x, v.y);
  }

  Offset _worldToScreen(Offset worldPoint) {
    final Vector3 v = Vector3(worldPoint.dx, worldPoint.dy, 0)
      ..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _DroppableGridPainter &&
        (oldDelegate.transform != transform ||
            oldDelegate.canAcceptDrop != canAcceptDrop ||
            oldDelegate.itemDragActive != itemDragActive);
  }
}
