import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// Grid background widget that users can provide to CanvasKit
class GridBackground extends StatelessWidget {
  final Matrix4 transform;
  final double gridSpacing;
  final Color backgroundColor;
  final Color gridColor;

  const GridBackground({
    super.key,
    required this.transform,
    this.gridSpacing = 50.0,
    this.backgroundColor = const Color(0xFFFAFAFA),
    this.gridColor = const Color(0x66999999),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GridPainter(
        transform: transform,
        gridSpacing: gridSpacing,
        backgroundColor: backgroundColor,
        gridColor: gridColor,
      ),
      child: Container(), // Fill available space
    );
  }
}

class _GridPainter extends CustomPainter {
  final Matrix4 transform;
  final double gridSpacing;
  final Color backgroundColor;
  final Color gridColor;
  
  _GridPainter({
    required this.transform,
    required this.gridSpacing,
    required this.backgroundColor,
    required this.gridColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Fill background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );
    
    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // Slightly thicker paint for the world origin axes (x=0 and y=0)
    final Paint axisPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

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
    final bool originVerticalVisible = worldTopLeft.dx <= 0 && worldBottomRight.dx >= 0;
    final bool originHorizontalVisible = worldTopLeft.dy <= 0 && worldBottomRight.dy >= 0;
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
    if (originScreen.dx >= -20 && originScreen.dx <= size.width + 20 &&
        originScreen.dy >= -20 && originScreen.dy <= size.height + 20) {
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
    final Vector3 v = Vector3(screenPoint.dx, screenPoint.dy, 0)..applyMatrix4(inverted);
    return Offset(v.x, v.y);
  }

  Offset _worldToScreen(Offset worldPoint) {
    final Vector3 v = Vector3(worldPoint.dx, worldPoint.dy, 0)..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _GridPainter && oldDelegate.transform != transform;
  }
}
