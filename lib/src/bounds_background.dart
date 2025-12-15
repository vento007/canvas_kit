import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

bool _nearZero(double v, {double eps = 1e-9}) => v.abs() <= eps;

bool _isAxisAlignedScaleTranslate(Matrix4 t, {double eps = 1e-9}) {
  final m = t.storage;
  return _nearZero(m[1], eps: eps) &&
      _nearZero(m[4], eps: eps) &&
      _nearZero(m[2], eps: eps) &&
      _nearZero(m[6], eps: eps) &&
      _nearZero(m[8], eps: eps) &&
      _nearZero(m[9], eps: eps) &&
      _nearZero(m[3], eps: eps) &&
      _nearZero(m[7], eps: eps) &&
      _nearZero(m[11], eps: eps) &&
      _nearZero(m[14], eps: eps) &&
      (m[10] - 1.0).abs() <= eps &&
      (m[15] - 1.0).abs() <= eps;
}

/// Package-provided background that draws a grid clipped to a fixed world
/// bounds rectangle and an inner frame that scales with zoom.
class BoundsBackground extends StatelessWidget {
  final Matrix4 transform;
  final Rect bounds;
  final double gridSpacing;
  final Color backgroundColor;
  final Color gridColor;
  final Color frameColor;
  final double frameWidth;

  const BoundsBackground({
    super.key,
    required this.transform,
    required this.bounds,
    this.gridSpacing = 80,
    this.backgroundColor = const Color(0xFFF2F8FF),
    this.gridColor = const Color(0x22000000),
    this.frameColor = const Color(0xFF303030),
    this.frameWidth = 32,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BoundsGridPainter(
        transform: transform,
        bounds: bounds,
        gridSpacing: gridSpacing,
        backgroundColor: backgroundColor,
        gridColor: gridColor,
        frameColor: frameColor,
        frameWidth: frameWidth,
      ),
    );
  }
}

class _BoundsGridPainter extends CustomPainter {
  final Matrix4 transform;
  final Rect bounds;
  final double gridSpacing;
  final Color backgroundColor;
  final Color gridColor;
  final Color frameColor;
  final double frameWidth;

  _BoundsGridPainter({
    required this.transform,
    required this.bounds,
    required this.gridSpacing,
    required this.backgroundColor,
    required this.gridColor,
    required this.frameColor,
    required this.frameWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fill entire screen with background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    // Compute the bounds rectangle in screen space and align to pixel edges
    final screenTL = _worldToScreen(bounds.topLeft);
    final screenBR = _worldToScreen(bounds.bottomRight);
    // Validate coordinates
    if (!screenTL.dx.isFinite || !screenTL.dy.isFinite ||
        !screenBR.dx.isFinite || !screenBR.dy.isFinite) {
      assert(() {
        // Debug aid: report skip reason
        // ignore: avoid_print
        print('[BoundsBackground] skip paint: non-finite screen coords TL=$screenTL BR=$screenBR');
        return true;
      }());
      return; // skip painting if transform produced invalid coordinates
    }
    final rawLeft = screenTL.dx < screenBR.dx ? screenTL.dx : screenBR.dx;
    final rawRight = screenTL.dx < screenBR.dx ? screenBR.dx : screenTL.dx;
    final rawTop = screenTL.dy < screenBR.dy ? screenTL.dy : screenBR.dy;
    final rawBottom = screenTL.dy < screenBR.dy ? screenBR.dy : screenTL.dy;
    final screenLeft = rawLeft.floorToDouble();
    final screenRight = rawRight.ceilToDouble();
    final screenTop = rawTop.floorToDouble();
    final screenBottom = rawBottom.ceilToDouble();
    if (!screenLeft.isFinite || !screenTop.isFinite || !screenRight.isFinite || !screenBottom.isFinite) {
      assert(() {
        // ignore: avoid_print
        print('[BoundsBackground] skip paint: non-finite LTRB=[$screenLeft,$screenTop,$screenRight,$screenBottom]');
        return true;
      }());
      return;
    }
    // Ensure non-empty rect
    if (screenLeft >= screenRight || screenTop >= screenBottom) {
      assert(() {
        // ignore: avoid_print
        print('[BoundsBackground] skip paint: empty rect LTRB=[$screenLeft,$screenTop,$screenRight,$screenBottom]');
        return true;
      }());
      return;
    }
    final Rect screenBoundsRect = Rect.fromLTRB(screenLeft, screenTop, screenRight, screenBottom);

    // Clip to bounds area and draw grid inside that fixed world rect
    canvas.save();
    canvas.clipRect(screenBoundsRect, doAntiAlias: false);

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Only draw visible grid lines (massive savings for huge bounds).
    final visibleWorld = _visibleWorldRect(size).intersect(bounds);
    if (!visibleWorld.isEmpty) {
      final startX =
          (visibleWorld.left / gridSpacing).floorToDouble() * gridSpacing;
      final endX =
          (visibleWorld.right / gridSpacing).ceilToDouble() * gridSpacing;
      final startY =
          (visibleWorld.top / gridSpacing).floorToDouble() * gridSpacing;
      final endY =
          (visibleWorld.bottom / gridSpacing).ceilToDouble() * gridSpacing;

      for (double worldX = startX; worldX <= endX; worldX += gridSpacing) {
        if (worldX < bounds.left || worldX > bounds.right) continue;
        final p1 = _worldToScreen(Offset(worldX, visibleWorld.top));
        final p2 = _worldToScreen(Offset(worldX, visibleWorld.bottom));
        canvas.drawLine(p1, p2, gridPaint);
      }

      for (double worldY = startY; worldY <= endY; worldY += gridSpacing) {
        if (worldY < bounds.top || worldY > bounds.bottom) continue;
        final p1 = _worldToScreen(Offset(visibleWorld.left, worldY));
        final p2 = _worldToScreen(Offset(visibleWorld.right, worldY));
        canvas.drawLine(p1, p2, gridPaint);
      }
    }

    canvas.restore();

    // Draw the thick frame inside the bounds.
    // Make the frame width scale with the current zoom so it appears thicker when zoomed in.
    final double scaleX = math.sqrt(transform.storage[0] * transform.storage[0] +
        transform.storage[1] * transform.storage[1]);
    final double scaleY = math.sqrt(transform.storage[4] * transform.storage[4] +
        transform.storage[5] * transform.storage[5]);
    final double avgScale = (scaleX + scaleY) / 2.0;

    final double w = (frameWidth * avgScale).clamp(1.0, 200.0);
    final Paint frameFill = Paint()
      ..color = frameColor
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;

    if (w > 0) {
      // Left
      canvas.drawRect(
        Rect.fromLTRB(screenLeft, screenTop, (screenLeft + w).clamp(screenLeft, screenRight), screenBottom),
        frameFill,
      );
      // Right
      canvas.drawRect(
        Rect.fromLTRB((screenRight - w).clamp(screenLeft, screenRight), screenTop, screenRight, screenBottom),
        frameFill,
      );
      // Top
      canvas.drawRect(
        Rect.fromLTRB(screenLeft + w, screenTop, screenRight - w, (screenTop + w).clamp(screenTop, screenBottom)),
        frameFill,
      );
      // Bottom
      canvas.drawRect(
        Rect.fromLTRB(screenLeft + w, (screenBottom - w).clamp(screenTop, screenBottom), screenRight - w, screenBottom),
        frameFill,
      );
    }
  }

  Offset _worldToScreen(Offset worldPoint) {
    if (_isAxisAlignedScaleTranslate(transform)) {
      final m = transform.storage;
      return Offset(
        worldPoint.dx * m[0] + m[12],
        worldPoint.dy * m[5] + m[13],
      );
    }
    final Vector3 v =
        Vector3(worldPoint.dx, worldPoint.dy, 0)..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }

  Rect _visibleWorldRect(Size size) {
    if (_isAxisAlignedScaleTranslate(transform)) {
      final m = transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      if (!_nearZero(sx) && !_nearZero(sy)) {
        final left = (0.0 - tx) / sx;
        final top = (0.0 - ty) / sy;
        final right = (size.width - tx) / sx;
        final bottom = (size.height - ty) / sy;
        return Rect.fromLTRB(
          math.min(left, right),
          math.min(top, bottom),
          math.max(left, right),
          math.max(top, bottom),
        );
      }
    }
    final inv = Matrix4.inverted(transform);
    final tl = Vector3(0, 0, 0)..applyMatrix4(inv);
    final br = Vector3(size.width, size.height, 0)..applyMatrix4(inv);
    return Rect.fromLTRB(
      math.min(tl.x, br.x),
      math.min(tl.y, br.y),
      math.max(tl.x, br.x),
      math.max(tl.y, br.y),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is! _BoundsGridPainter) return true;
    return oldDelegate.transform != transform ||
        oldDelegate.bounds != bounds ||
        oldDelegate.gridSpacing != gridSpacing ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.frameColor != frameColor ||
        oldDelegate.frameWidth != frameWidth;
  }
}
