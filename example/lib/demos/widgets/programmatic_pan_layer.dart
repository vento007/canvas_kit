import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../../shared/grid_background.dart';

/// Minimal helper that makes the programmatic demo concise:
/// - Paints the grid background
/// - Converts screen pan deltas to world deltas and translates via controller
class ProgrammaticPanLayer extends StatefulWidget {
  final Matrix4 transform;
  final CanvasKitController controller;
  final Color backgroundColor;
  final double gridSpacing;
  final Color gridColor;
  final bool paintGrid;

  const ProgrammaticPanLayer({
    super.key,
    required this.transform,
    required this.controller,
    this.backgroundColor = const Color(0xFFFFF7E6),
    this.gridSpacing = 80,
    this.gridColor = const Color(0x22000000),
    this.paintGrid = true,
  });

  @override
  State<ProgrammaticPanLayer> createState() => _ProgrammaticPanLayerState();
}

class _ProgrammaticPanLayerState extends State<ProgrammaticPanLayer> {
  double? _scaleStart;
  Offset? _focalWorldAtStart;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final double scaleDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
          final Offset screenPos = event.localPosition;
          final Offset worldBefore = widget.controller.screenToWorld(screenPos);
          final nextScale = widget.controller.scale * scaleDelta;
          // ignore: avoid_print
          print(
            '[ProgrammaticPanLayer] wheel focalWorld=${worldBefore.dx.toStringAsFixed(1)},${worldBefore.dy.toStringAsFixed(1)} scaleBefore=${widget.controller.scale.toStringAsFixed(3)} -> scaleAfter=${nextScale.toStringAsFixed(3)}',
          );
          widget.controller.setScale(nextScale, focalWorld: worldBefore);
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Pinch (two-finger) zoom + translate to keep focal point fixed
        onScaleStart: (details) {
          _scaleStart = widget.controller.scale;
          _focalWorldAtStart = widget.controller.screenToWorld(
            details.localFocalPoint,
          );
          // ignore: avoid_print
          print(
            '[ProgrammaticPanLayer] onScaleStart pointerCount=${details.pointerCount} focalLocal=${details.localFocalPoint} scaleStart=$_scaleStart focalWorldStart=$_focalWorldAtStart',
          );
        },
        onScaleUpdate: (details) {
          if (_scaleStart == null || _focalWorldAtStart == null) return;
          final pointerCount = details.pointerCount;
          // details.scale is cumulative factor since onScaleStart
          final nextScale = _scaleStart! * details.scale;
          // ignore: avoid_print
          print(
            '[ProgrammaticPanLayer] onScaleUpdate pointerCount=$pointerCount scaleFactor=${details.scale.toStringAsFixed(3)} nextScale=${nextScale.toStringAsFixed(3)} focalLocal=${details.localFocalPoint} focalDelta=${details.focalPointDelta}',
          );

          if (pointerCount <= 1) {
            // One-finger drag: pan by focalPointDelta
            final screenDelta = details.focalPointDelta;
            if (screenDelta != Offset.zero) {
              final worldDelta = widget.controller.deltaScreenToWorld(
                screenDelta,
              );
              // ignore: avoid_print
              print(
                '[ProgrammaticPanLayer] single-finger pan screenDelta=$screenDelta worldDelta=$worldDelta',
              );
              if (worldDelta != Offset.zero) {
                widget.controller.translateWorld(worldDelta);
              }
            }
            return;
          }

          // Two-finger pinch: scale and keep original focal world point under fingers
          widget.controller.setScale(nextScale);
          final currentScreenOfFocal = widget.controller.worldToScreen(
            _focalWorldAtStart!,
          );
          final screenDelta = details.localFocalPoint - currentScreenOfFocal;
          final worldDelta = screenDelta == Offset.zero
              ? Offset.zero
              : widget.controller.deltaScreenToWorld(screenDelta);
          // ignore: avoid_print
          print(
            '[ProgrammaticPanLayer] pinch adjust screenDelta=$screenDelta worldDelta=$worldDelta',
          );
          if (screenDelta != Offset.zero && worldDelta != Offset.zero) {
            widget.controller.translateWorld(worldDelta);
          }
        },
        onScaleEnd: (_) {
          _scaleStart = null;
          _focalWorldAtStart = null;
        },
        child: widget.paintGrid
            ? GridBackground(
                transform: widget.transform,
                backgroundColor: widget.backgroundColor,
                gridSpacing: widget.gridSpacing,
                gridColor: widget.gridColor,
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
