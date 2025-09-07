import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// Interaction strategy for the canvas.
///
/// - `interactive`: the widget handles pan/zoom gestures internally.
/// - `programmatic`: the app drives pan/zoom via [CanvasKitController]
///   (you can also provide a [gestureOverlayBuilder] to implement custom input).
enum InteractionMode { interactive, programmatic }

/// A composable, high‑performance infinite canvas with pan/zoom and optional bounds.
///
/// - Supply world‑anchored children via [children].
/// - Provide a [backgroundBuilder] to draw grid/images that follow the camera transform.
/// - Add [foregroundLayers] for overlays (e.g. connections) that receive the current transform.
/// - In `programmatic` mode, control the view with [controller] and optionally supply a
///   [gestureOverlayBuilder] to implement custom gestures.
class CanvasKit extends StatefulWidget {
  final List<CanvasItem> children;

  /// Builds a background below the canvas using the current camera [transform].
  final Widget Function(Matrix4 transform)? backgroundBuilder;

  /// Custom painters composed above the canvas; each receives the current [transform].
  final List<CustomPainter Function(Matrix4 transform)> foregroundLayers;
  final double initialZoom;
  final Offset initialPan;
  final double minZoom;
  final double maxZoom;
  final Function(double currentZoom)? onZoomChanged;
  final CanvasKitController? controller;
  final InteractionMode interactionMode;
  final bool enablePan;
  final bool enableWheelZoom;

  /// Optional boundary in world coordinates. When set, panning/zooming is
  /// constrained to keep the view inside this rect.
  final Rect? bounds;

  /// If true (default) and [bounds] are set, the view auto‑fits to bounds on first layout.
  final bool autoFitToBounds;

  /// Padding (screen pixels) used when auto‑fitting to [bounds]. Default is 40.
  final double boundsFitPadding;

  // Optional: if provided in programmatic mode, the package will not handle
  // background pan/wheel; instead, this overlay can implement all gestures.
  // The overlay receives current transform and controller.
  /// App‑provided gesture layer. In `programmatic` mode, supply this to fully
  /// control input while still receiving the current [transform] and [controller].
  final Widget Function(Matrix4 transform, CanvasKitController controller)?
      gestureOverlayBuilder;

  const CanvasKit({
    super.key,
    required this.children,
    this.backgroundBuilder,
    this.foregroundLayers = const [],
    this.initialZoom = 1.0,
    this.initialPan = Offset.zero,
    this.minZoom = 0.1,
    this.maxZoom = 10.0,
    this.onZoomChanged,
    this.controller,
    this.interactionMode = InteractionMode.interactive,
    this.enablePan = true,
    this.enableWheelZoom = true,
    this.gestureOverlayBuilder,
    this.bounds,
    this.autoFitToBounds = true,
    this.boundsFitPadding = 40.0,
  });

  @override
  State<CanvasKit> createState() => _CanvasKitState();
}

/// Public controller for programmatic pan/zoom and conversions.
class CanvasKitController extends ChangeNotifier {
  Matrix4 _transform;
  final double minZoom;
  final double maxZoom;
  _CanvasKitState? _attached;
  final Set<String> _dragging = <String>{};

  /// Optional boundary rect in world coordinates
  Rect? bounds;

  /// If true, automatically constrain transformations to bounds
  bool enableBoundaryConstraints;

  CanvasKitController({
    Matrix4? initialTransform,
    this.minZoom = 0.1,
    this.maxZoom = 10.0,
    this.bounds,
    this.enableBoundaryConstraints = true,
  }) : _transform = initialTransform?.clone() ?? Matrix4.identity();

  Matrix4 get transform => _transform.clone();
  double get scale => _transform.getMaxScaleOnAxis();
  bool isDragging(String id) => _dragging.contains(id);
  bool get hasActiveDrag => _dragging.isNotEmpty;

  void _attachWidget(_CanvasKitState state) {
    _attached = state;
    // Update bounds from widget if not set
    if (bounds == null && state.widget.bounds != null) {
      bounds = state.widget.bounds;
    }
  }

  void _detachWidget(_CanvasKitState state) {
    if (_attached == state) _attached = null;
  }

  void _setTransformInternal(Matrix4 t,
      {bool notify = false, bool applyConstraints = true}) {
    _transform = t.clone();

    // Apply boundary constraints if enabled
    if (applyConstraints &&
        enableBoundaryConstraints &&
        bounds != null &&
        _attached != null) {
      _constrainToBounds();
    }

    if (notify) notifyListeners();
  }

  void beginDrag(String id) {
    _dragging.add(id);
    notifyListeners();
  }

  void endDrag(String id) {
    _dragging.remove(id);
    notifyListeners();
  }

  /// Compute the currently visible world rectangle for a given [viewportSize].
  Rect getVisibleWorldRect(Size viewportSize) {
    final topLeft = screenToWorld(Offset.zero);
    final bottomRight =
        screenToWorld(Offset(viewportSize.width, viewportSize.height));

    return Rect.fromLTRB(
      math.min(topLeft.dx, bottomRight.dx),
      math.min(topLeft.dy, bottomRight.dy),
      math.max(topLeft.dx, bottomRight.dx),
      math.max(topLeft.dy, bottomRight.dy),
    );
  }

  /// Minimum scale required to fit [bounds] entirely inside [viewportSize].
  /// Returns [minZoom] when no bounds are set.
  double getMinimumScaleForBounds(Size viewportSize) {
    if (bounds == null) return minZoom;
    return math
        .max(
          viewportSize.width / bounds!.width,
          viewportSize.height / bounds!.height,
        )
        .clamp(minZoom, maxZoom)
        .toDouble();
  }

  // Helper: Constrain the view to bounds
  void _constrainToBounds() {
    if (bounds == null || _attached == null) return;

    final renderBox = _attached!.context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final viewportSize = renderBox.size;
    final visibleRect = getVisibleWorldRect(viewportSize);

    double dx = 0;
    double dy = 0;

    // If the visible area is smaller than bounds, ensure it stays within
    if (visibleRect.width < bounds!.width) {
      if (visibleRect.left < bounds!.left) {
        dx = bounds!.left - visibleRect.left;
      } else if (visibleRect.right > bounds!.right) {
        dx = bounds!.right - visibleRect.right;
      }
    } else {
      // If visible area is larger than bounds, center the bounds
      dx = bounds!.center.dx - visibleRect.center.dx;
    }

    if (visibleRect.height < bounds!.height) {
      if (visibleRect.top < bounds!.top) {
        dy = bounds!.top - visibleRect.top;
      } else if (visibleRect.bottom > bounds!.bottom) {
        dy = bounds!.bottom - visibleRect.bottom;
      }
    } else {
      // If visible area is larger than bounds, center the bounds
      dy = bounds!.center.dy - visibleRect.center.dy;
    }

    if (dx != 0 || dy != 0) {
      // Note: translateWorld moves the world, which moves the view in the opposite direction
      _transform.translate(-dx, -dy);
    }
  }

  /// Programmatic controls for pan/zoom and conversions.

  /// Replace the view transform and notify listeners.
  void setTransform(Matrix4 t) {
    _setTransformInternal(t, notify: true);
  }

  /// Translate the world by [worldDelta]. Positive X/Y moves content right/down.
  void translateWorld(Offset worldDelta) {
    final next = _transform.clone()..translate(worldDelta.dx, worldDelta.dy);
    _setTransformInternal(next, notify: true);
  }

  /// Set absolute [nextScale] around an optional [focalWorld] point (world coords).
  /// Applies min/max zoom and respects bounds if configured.
  void setScale(double nextScale, {Offset focalWorld = Offset.zero}) {
    // Apply minimum scale for bounds if set
    double minScaleAllowed = minZoom;
    if (bounds != null && _attached != null) {
      final renderBox = _attached!.context.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        minScaleAllowed =
            math.max(minZoom, getMinimumScaleForBounds(renderBox.size));
      }
    }

    final clamped = nextScale.clamp(minScaleAllowed, maxZoom).toDouble();
    final current = scale;
    if ((clamped - current).abs() < 1e-6) return;
    final s = clamped / current;
    final next = _transform.clone()
      ..translate(focalWorld.dx, focalWorld.dy)
      ..scale(s, s)
      ..translate(-focalWorld.dx, -focalWorld.dy);
    _setTransformInternal(next, notify: true);
  }

  // Helpers
  /// Convert a screen (logical pixel) point to world coordinates.
  Offset screenToWorld(Offset screenPoint) {
    final inverted = Matrix4.inverted(_transform);
    final Vector3 v = Vector3(screenPoint.dx, screenPoint.dy, 0)
      ..applyMatrix4(inverted);
    return Offset(v.x, v.y);
  }

  /// Convert a world point to screen (logical pixel) coordinates.
  Offset worldToScreen(Offset worldPoint) {
    final Vector3 v = Vector3(worldPoint.dx, worldPoint.dy, 0)
      ..applyMatrix4(_transform);
    return Offset(v.x, v.y);
  }

  /// Convert a screen delta to a world‑space delta at the current zoom.
  Offset deltaScreenToWorld(Offset screenDelta) {
    final s = scale;
    return Offset(screenDelta.dx / s, screenDelta.dy / s);
  }

  /// Fit the view to cover all [worldPoints] with optional screen [padding] (pixels).
  void fitToPositions(List<Offset> worldPoints, Size viewportSize,
      {double padding = 40}) {
    if (worldPoints.isEmpty) return;
    double minX = worldPoints.first.dx, maxX = worldPoints.first.dx;
    double minY = worldPoints.first.dy, maxY = worldPoints.first.dy;
    for (final p in worldPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final worldRect = Rect.fromLTRB(minX, minY, maxX, maxY);
    fitToWorldRect(worldRect, viewportSize, padding: padding);
  }

  /// Fit to a list of world-space rects (sizes respected).
  void fitToRects(List<Rect> worldRects, Size viewportSize,
      {double padding = 40}) {
    if (worldRects.isEmpty) return;
    double minL = worldRects.first.left, minT = worldRects.first.top;
    double maxR = worldRects.first.right, maxB = worldRects.first.bottom;
    for (final r in worldRects) {
      if (r.left < minL) minL = r.left;
      if (r.top < minT) minT = r.top;
      if (r.right > maxR) maxR = r.right;
      if (r.bottom > maxB) maxB = r.bottom;
    }
    fitToWorldRect(Rect.fromLTRB(minL, minT, maxR, maxB), viewportSize,
        padding: padding);
  }

  /// Fit the view to [worldRect] with optional screen [padding] (pixels).
  void fitToWorldRect(Rect worldRect, Size viewportSize,
      {double padding = 40}) {
    final targetW = viewportSize.width - padding * 2;
    final targetH = viewportSize.height - padding * 2;
    final rectW = worldRect.width <= 0 ? 1.0 : worldRect.width;
    final rectH = worldRect.height <= 0 ? 1.0 : worldRect.height;
    final sx = targetW / rectW;
    final sy = targetH / rectH;

    // Apply minimum scale for bounds if set
    double minScaleAllowed = minZoom;
    if (bounds != null) {
      minScaleAllowed =
          math.max(minZoom, getMinimumScaleForBounds(viewportSize));
    }

    final targetScale =
        (sx < sy ? sx : sy).clamp(minScaleAllowed, maxZoom).toDouble();

    // Center rect in viewport
    final centerWorld = worldRect.center;
    final next = Matrix4.identity()
      ..translate(viewportSize.width / 2, viewportSize.height / 2)
      ..scale(targetScale, targetScale)
      ..translate(-centerWorld.dx, -centerWorld.dy);
    setTransform(next);
  }

  /// Fit the view to [bounds] using the given viewport and padding.
  void fitToBounds(Size viewportSize, {double? padding}) {
    if (bounds == null) return;
    fitToWorldRect(bounds!, viewportSize, padding: padding ?? 40);
  }

  /// Center the view on a world point while preserving current scale.
  void centerOn(Offset worldPoint, Size viewportSize) {
    final s = scale;
    final next = Matrix4.identity()
      ..translate(viewportSize.width / 2, viewportSize.height / 2)
      ..scale(s, s)
      ..translate(-worldPoint.dx, -worldPoint.dy);
    setTransform(next);
  }
}

class _CanvasKitState extends State<CanvasKit> {
  late Matrix4 _transform;
  CanvasKitController? _controller;
  // For interactive pinch handling (simple demo)
  double? _scaleStart;
  Offset? _focalWorldAtStart;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _transform = Matrix4.identity()
      ..translate(widget.initialPan.dx, widget.initialPan.dy)
      ..scale(widget.initialZoom, widget.initialZoom);
    _controller = widget.controller ??
        CanvasKitController(
          initialTransform: _transform.clone(),
          minZoom: widget.minZoom,
          maxZoom: widget.maxZoom,
          bounds: widget.bounds,
        );
    _controller!._attachWidget(this);
    _controller!.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-fit to bounds on first layout if requested
    if (!_isInitialized && widget.autoFitToBounds && widget.bounds != null) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          _controller!
              .fitToBounds(renderBox.size, padding: widget.boundsFitPadding);
        }
      });
    }
  }

  // EXACT COPY from main_simple.dart
  Offset _screenToWorld(Offset screenPoint) {
    final inverted = Matrix4.inverted(_transform);
    final Vector3 v = Vector3(screenPoint.dx, screenPoint.dy, 0)
      ..applyMatrix4(inverted);
    return Offset(v.x, v.y);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _transform.getMaxScaleOnAxis();
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerSignal: (event) {
          if (!widget.enableWheelZoom || event is! PointerScrollEvent) return;
          // If programmatic mode and a gesture overlay is provided, defer wheel handling to overlay
          if (widget.interactionMode == InteractionMode.programmatic &&
              widget.gestureOverlayBuilder != null) {
            return;
          }
          final PointerScrollEvent e = event; // safe after type check
          if (kDebugMode) {
            print(
                '[CanvasKit] PointerScrollEvent received. interactionMode=${widget.interactionMode} delta=${e.scrollDelta}');
          }
          final double scaleDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
          final Offset screenPos = event.localPosition;
          final Offset worldBefore = _screenToWorld(screenPos);

          if (widget.interactionMode == InteractionMode.interactive) {
            // Local state-managed zoom
            final currentZoom = _transform.getMaxScaleOnAxis();

            // Calculate minimum zoom based on bounds if set
            double minZoomAllowed = widget.minZoom;
            if (widget.bounds != null) {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null && renderBox.hasSize) {
                minZoomAllowed = math.max(widget.minZoom,
                    _controller!.getMinimumScaleForBounds(renderBox.size));
              }
            }

            final newZoom = (currentZoom * scaleDelta)
                .clamp(minZoomAllowed, widget.maxZoom);
            if ((newZoom - currentZoom).abs() > 1e-6) {
              setState(() {
                final Matrix4 next = _transform.clone();
                next.translate(worldBefore.dx, worldBefore.dy);
                next.scale(newZoom / currentZoom, newZoom / currentZoom);
                next.translate(-worldBefore.dx, -worldBefore.dy);
                _transform = next;
                _controller?._setTransformInternal(next, notify: true);
              });
              if (kDebugMode) {
                final hasDrag = _controller?.hasActiveDrag == true;
                print(
                    '[CanvasKit] Zoom applied (interactive) focalWorld=${worldBefore.dx.toStringAsFixed(1)},${worldBefore.dy.toStringAsFixed(1)} scaleBefore=${currentZoom.toStringAsFixed(3)} -> scaleAfter=${_transform.getMaxScaleOnAxis().toStringAsFixed(3)} hasActiveDrag=$hasDrag');
              }
              widget.onZoomChanged?.call(_transform.getMaxScaleOnAxis());
            }
          } else {
            // Programmatic: drive zoom via controller
            final currentZoom = _controller!.scale;
            _controller!
                .setScale(currentZoom * scaleDelta, focalWorld: worldBefore);
            if (kDebugMode) {
              final hasDrag = _controller?.hasActiveDrag == true;
              print(
                  '[CanvasKit] Zoom applied (programmatic via controller) focalWorld=${worldBefore.dx.toStringAsFixed(1)},${worldBefore.dy.toStringAsFixed(1)} scaleBefore=${currentZoom.toStringAsFixed(3)} -> scaleAfter=${_controller!.scale.toStringAsFixed(3)} hasActiveDrag=$hasDrag');
            }
            widget.onZoomChanged?.call(_controller!.scale);
          }
        },
        child: Stack(
          children: [
            // User-provided background with current transform
            if (widget.backgroundBuilder != null)
              Positioned.fill(child: widget.backgroundBuilder!(_transform)),

            // User-provided foreground layers (connections, overlays, etc.)
            ...widget.foregroundLayers.map(
              (painterBuilder) => Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: painterBuilder(_transform),
                  ),
                ),
              ),
            ),

            // App-provided gesture overlay (if any)
            if (widget.gestureOverlayBuilder != null)
              Positioned.fill(
                  child:
                      widget.gestureOverlayBuilder!(_transform, _controller!)),

            // Empty space gesture detection (suppressed in programmatic mode when overlay is provided)
            if (!(widget.interactionMode == InteractionMode.programmatic &&
                widget.gestureOverlayBuilder != null))
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (details) {
                    // Prevent background gestures while dragging any item
                    if (_controller?.hasActiveDrag == true) return;
                    _scaleStart = _transform.getMaxScaleOnAxis();
                    _focalWorldAtStart =
                        _screenToWorld(details.localFocalPoint);
                    if (kDebugMode) {
                      print(
                          '[CanvasKit] onScaleStart (interactive) focalLocal=${details.localFocalPoint} scaleStart=$_scaleStart focalWorldStart=$_focalWorldAtStart');
                    }
                  },
                  onScaleUpdate: (details) {
                    // Skip if overlay is provided in programmatic mode (guarded above) or if pan disabled
                    if (!widget.enablePan) return;
                    if (_controller?.hasActiveDrag == true) return;

                    if (widget.interactionMode == InteractionMode.interactive) {
                      // Unify single-finger pan and two-finger pinch
                      final pointerCount = details.pointerCount;
                      if (pointerCount <= 1) {
                        // Single-finger pan: use focalPointDelta and convert to world delta by dividing by scale
                        final scale = _transform.getMaxScaleOnAxis();
                        final adjustedDelta = Offset(
                            details.focalPointDelta.dx / scale,
                            details.focalPointDelta.dy / scale);
                        if (adjustedDelta == Offset.zero) return;
                        setState(() {
                          final next = _transform.clone()
                            ..translate(adjustedDelta.dx, adjustedDelta.dy);
                          _transform = next;
                          _controller?._setTransformInternal(next,
                              notify: true);
                        });
                        if (kDebugMode) {
                          print(
                              '[CanvasKit] Pan (interactive, scale) adjustedDelta=$adjustedDelta');
                        }
                        return;
                      }

                      // Two-finger pinch: focal-locked zoom with corrective translation
                      if (_scaleStart == null || _focalWorldAtStart == null) {
                        return;
                      }
                      final currentScale = _scaleStart!;
                      final proposed = currentScale * details.scale;

                      // Calculate minimum zoom based on bounds if set
                      double minZoomAllowed = widget.minZoom;
                      if (widget.bounds != null) {
                        final renderBox =
                            context.findRenderObject() as RenderBox?;
                        if (renderBox != null && renderBox.hasSize) {
                          minZoomAllowed = math.max(
                              widget.minZoom,
                              _controller!
                                  .getMinimumScaleForBounds(renderBox.size));
                        }
                      }

                      // Clamp to widget min/max
                      final clamped = proposed
                          .clamp(minZoomAllowed, widget.maxZoom)
                          .toDouble();

                      // Apply scaling around the original focal world point
                      final Matrix4 next = _transform.clone()
                        ..translate(
                            _focalWorldAtStart!.dx, _focalWorldAtStart!.dy)
                        ..scale(clamped / _transform.getMaxScaleOnAxis(),
                            clamped / _transform.getMaxScaleOnAxis())
                        ..translate(
                            -_focalWorldAtStart!.dx, -_focalWorldAtStart!.dy);

                      // Compute corrective pan to keep the focal under the fingers
                      final Vector3 focalWorldVec = Vector3(
                          _focalWorldAtStart!.dx, _focalWorldAtStart!.dy, 0)
                        ..applyMatrix4(next);
                      final Offset focalScreenNow =
                          Offset(focalWorldVec.x, focalWorldVec.y);
                      final Offset screenDelta =
                          details.localFocalPoint - focalScreenNow;
                      final double scaleNow = clamped;
                      final Offset worldDelta = Offset(
                          screenDelta.dx / scaleNow, screenDelta.dy / scaleNow);

                      setState(() {
                        final Matrix4 nextWithTranslate = next.clone()
                          ..translate(worldDelta.dx, worldDelta.dy);
                        _transform = nextWithTranslate;
                        _controller?._setTransformInternal(nextWithTranslate,
                            notify: true);
                      });
                      if (kDebugMode) {
                        print(
                            '[CanvasKit] Pinch (interactive) pointerCount=$pointerCount clamped=$clamped screenDelta=$screenDelta worldDelta=$worldDelta');
                      }
                      widget.onZoomChanged
                          ?.call(_transform.getMaxScaleOnAxis());
                    } else {
                      // Programmatic mode (no overlay): keep previous behavior for single-finger pan only
                      // Convert screen delta to world delta via controller
                      final worldDelta = _controller!
                          .deltaScreenToWorld(details.focalPointDelta);
                      if (worldDelta == Offset.zero) return;
                      _controller!.translateWorld(worldDelta);
                      // Debug print removed to reduce log noise during panning
                      // if (kDebugMode) {
                      //   debugPrint('[CanvasKit] Pan (programmatic via controller, scale gesture) worldDelta=$worldDelta');
                      // }
                    }
                  },
                  onScaleEnd: (_) {
                    _scaleStart = null;
                    _focalWorldAtStart = null;
                  },
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent, // Make it hittable but invisible
                  ),
                ),
              ),

            // Canvas with user widgets
            CanvasKitScope(
              transform: _transform,
              scale: scale,
              controller: _controller!,
              child: SimpleCanvas(
                transform: _transform,
                children: widget.children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onControllerChanged() {
    // When controller changes transform programmatically, update local state
    final t = _controller!.transform;
    if (!identical(t, _transform)) {
      setState(() {
        _transform = t.clone();
      });
      if (widget.onZoomChanged != null) {
        widget.onZoomChanged!(_transform.getMaxScaleOnAxis());
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?._detachWidget(this);
    super.dispose();
  }
}

// Viewer only handles transforms and positioning - no graphics

/// Anchor coordinate space for a [CanvasItem].
///
/// - [world]: position is in world units and affected by pan/zoom.
/// - [viewport]: position is in logical pixels relative to the screen and
///   unaffected by pan (optionally scaled via [CanvasItem.scaleWithZoom]).
enum CanvasAnchor { world, viewport }

/// Inherited context for canvas transform, current scale and controller.
class CanvasKitScope extends InheritedWidget {
  final Matrix4 transform;
  final double scale;
  final CanvasKitController controller;

  const CanvasKitScope({
    super.key,
    required this.transform,
    required this.scale,
    required this.controller,
    required super.child,
  });

  static CanvasKitScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CanvasKitScope>();
    assert(scope != null, 'CanvasKitScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(covariant CanvasKitScope oldWidget) {
    return oldWidget.transform != transform ||
        oldWidget.scale != scale ||
        oldWidget.controller != controller;
  }
}

// SimpleCanvas from working version with anchor support
/// A widget placed on the canvas at a world (or viewport) position.
class CanvasItem {
  final String id;

  /// World coordinate of the top‑left corner (when [anchor] == [CanvasAnchor.world]).
  final Offset worldPosition;

  /// Child widget to render.
  final Widget child;

  /// If true, the item can be dragged (drag deltas are converted to world or viewport space).
  final bool draggable;

  /// Callback with the updated world position during drag.
  final ValueChanged<Offset>? onWorldMoved;

  /// Anchoring mode for this item.
  final CanvasAnchor anchor;

  /// Viewport‑anchored position (logical pixels) when [anchor] == [CanvasAnchor.viewport].
  final Offset? viewportPosition;

  /// Callback with updated viewport position during drag.
  final ValueChanged<Offset>? onViewportMoved;

  /// For viewport‑anchored items only: scale the child with the canvas zoom.
  final bool scaleWithZoom; // only for viewport anchoring
  /// If true, do not scale the child with zoom (useful for HUD elements).
  final bool lockZoom; // if true, do not scale child with canvas zoom
  /// Optional estimated widget size. World units for world‑anchored; logical pixels for viewport‑anchored.
  /// Enables rect‑overlap culling for better performance.
  final Size? estimatedSize;

  CanvasItem({
    required this.id,
    required this.worldPosition,
    required this.child,
    this.draggable = false,
    this.onWorldMoved,
    this.anchor = CanvasAnchor.world,
    this.viewportPosition,
    this.onViewportMoved,
    this.scaleWithZoom = false,
    this.lockZoom = false,
    this.estimatedSize,
  });
}

/// Lightweight compositor that positions [CanvasItem]s using the current transform.
class SimpleCanvas extends StatelessWidget {
  final Matrix4 transform;
  final List<CanvasItem> children;

  const SimpleCanvas({
    super.key,
    required this.transform,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
      // Scale the culling margin with zoom so large (zoomed) widgets aren't culled prematurely
      final currentScale = transform.getMaxScaleOnAxis();
      // Slightly over-scale margin to account for very large widgets near edges
      final scaledMargin = 200 * currentScale * 1.25; // was 200 * scale
      final screenBounds =
          Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height)
              .deflate(-scaledMargin);
      return Stack(
        clipBehavior: Clip.none,
        children: children.where((item) {
          final Vector3 worldPos =
              Vector3(item.worldPosition.dx, item.worldPosition.dy, 0);
          final Vector3 screenPos = worldPos..applyMatrix4(transform);
          final Offset point = item.anchor == CanvasAnchor.world
              ? Offset(screenPos.x, screenPos.y)
              : (item.viewportPosition ?? Offset.zero);
          // Keep actively dragging items even if offscreen
          final scope =
              context.dependOnInheritedWidgetOfExactType<CanvasKitScope>();
          final dragging = scope?.controller.isDragging(item.id) ?? false;
          if (dragging) return true;

          // If we know the item's size, compute its screen-space rect and test overlap
          if (item.estimatedSize != null) {
            if (item.anchor == CanvasAnchor.world) {
              final appliedScale = item.lockZoom ? 1.0 : currentScale;
              final w = item.estimatedSize!.width * appliedScale;
              final h = item.estimatedSize!.height * appliedScale;
              final rect = Rect.fromLTWH(point.dx, point.dy, w, h);
              return screenBounds.overlaps(rect);
            } else {
              // viewport anchored: size is in logical pixels; scale only if requested
              final shouldScale = item.scaleWithZoom && !item.lockZoom;
              final w = item.estimatedSize!.width *
                  (shouldScale ? currentScale : 1.0);
              final h = item.estimatedSize!.height *
                  (shouldScale ? currentScale : 1.0);
              final rect = Rect.fromLTWH(point.dx, point.dy, w, h);
              return screenBounds.overlaps(rect);
            }
          }

          // Fallback: point containment
          return screenBounds.contains(point);
        }).map((item) {
          final scale = transform.getMaxScaleOnAxis();
          late final double left;
          late final double top;
          Widget content = item.child;

          if (item.anchor == CanvasAnchor.world) {
            final Vector3 worldPos =
                Vector3(item.worldPosition.dx, item.worldPosition.dy, 0);
            final Vector3 screenPos = worldPos..applyMatrix4(transform);
            left = screenPos.x;
            top = screenPos.y;
            final double appliedScale = item.lockZoom ? 1.0 : scale;

            // If draggable, wrap first, then apply Transform around the wrapper so hit testing scales too
            if (item.draggable) {
              content = _DraggableWrapper(
                key: ValueKey('drag-${item.id}'),
                itemId: item.id,
                // When wrapped by a Transform above, local deltas are already in scaled space; use 1.0
                scale: 1.0,
                anchor: item.anchor,
                initialWorldPosition: item.worldPosition,
                initialViewportPosition: item.viewportPosition ?? Offset.zero,
                onWorldMoved: item.onWorldMoved,
                onViewportMoved: item.onViewportMoved,
                child: content,
              );
              content = Transform.scale(
                scale: appliedScale,
                alignment: Alignment.topLeft,
                child: content,
              );
            } else {
              // Non-draggable: previous behavior
              content = Transform.scale(
                scale: appliedScale,
                alignment: Alignment.topLeft,
                child: content,
              );
            }
          } else {
            // viewport anchored
            final vp = item.viewportPosition ?? Offset.zero;
            left = vp.dx;
            top = vp.dy;
            final shouldScale = item.scaleWithZoom && !item.lockZoom;

            if (item.draggable) {
              content = _DraggableWrapper(
                key: ValueKey('drag-${item.id}'),
                itemId: item.id,
                // If we apply Transform below, set scale accordingly; otherwise use current scale
                scale: shouldScale ? 1.0 : scale,
                anchor: item.anchor,
                initialWorldPosition: item.worldPosition,
                initialViewportPosition: item.viewportPosition ?? Offset.zero,
                onWorldMoved: item.onWorldMoved,
                onViewportMoved: item.onViewportMoved,
                child: content,
              );
              if (shouldScale) {
                content = Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: content,
                );
              }
            } else {
              if (shouldScale) {
                content = Transform.scale(
                  scale: scale,
                  alignment: Alignment.topLeft,
                  child: content,
                );
              }
            }
          }

          return Positioned(
            key: ValueKey('item-${item.id}'),
            left: left,
            top: top,
            child: content,
          );
        }).toList(),
      );
    });
  }
}

/// Internal wrapper that converts screen-space drag deltas into world-space
/// and calls back with the updated world position. It does not keep state;
/// the parent should update the `CanvasItem.worldPosition`.
class _DraggableWrapper extends StatefulWidget {
  final double scale;
  final CanvasAnchor anchor;
  final Offset initialWorldPosition;
  final Offset initialViewportPosition;
  final ValueChanged<Offset>? onWorldMoved;
  final ValueChanged<Offset>? onViewportMoved;
  final Widget child;
  final String itemId;

  const _DraggableWrapper({
    super.key,
    required this.itemId,
    required this.scale,
    required this.anchor,
    required this.initialWorldPosition,
    required this.initialViewportPosition,
    this.onWorldMoved,
    this.onViewportMoved,
    required this.child,
  });

  @override
  State<_DraggableWrapper> createState() => _DraggableWrapperState();
}

class _DraggableWrapperState extends State<_DraggableWrapper> {
  late Offset _dragStartWorldPos;
  late Offset _dragStartViewportPos;

  @override
  void initState() {
    super.initState();
    _dragStartWorldPos = widget.initialWorldPosition;
    _dragStartViewportPos = widget.initialViewportPosition;
  }

  @override
  void didUpdateWidget(covariant _DraggableWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep in sync with latest world position from parent
    if (oldWidget.initialWorldPosition != widget.initialWorldPosition) {
      _dragStartWorldPos = widget.initialWorldPosition;
    }
    if (oldWidget.initialViewportPosition != widget.initialViewportPosition) {
      _dragStartViewportPos = widget.initialViewportPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CanvasKitScope>();
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onPanStart: (details) {
        _dragStartWorldPos = widget.initialWorldPosition;
        _dragStartViewportPos = widget.initialViewportPosition;
        scope?.controller.beginDrag(widget.itemId);
        if (kDebugMode) {
          print(
              '[CanvasKit] Drag start itemId=${widget.itemId} anchor=${widget.anchor} scale=${widget.scale} worldStart=$_dragStartWorldPos viewportStart=$_dragStartViewportPos');
        }
      },
      onPanUpdate: (details) {
        if (widget.anchor == CanvasAnchor.world) {
          if (widget.onWorldMoved == null) return;
          // Convert screen delta to world delta using current scale
          final worldDelta = Offset(
              details.delta.dx / widget.scale, details.delta.dy / widget.scale);
          final nextPos = _dragStartWorldPos + worldDelta;
          widget.onWorldMoved?.call(nextPos);
          _dragStartWorldPos = nextPos;
          if (kDebugMode) {
            print(
                '[CanvasKit] Drag update (world) itemId=${widget.itemId} deltaScreen=${details.delta} worldDelta=$worldDelta nextWorld=$nextPos');
          }
        } else {
          if (widget.onViewportMoved == null) return;
          final nextVp = _dragStartViewportPos +
              details.delta; // viewport is in screen pixels
          widget.onViewportMoved?.call(nextVp);
          _dragStartViewportPos = nextVp;
          if (kDebugMode) {
            print(
                '[CanvasKit] Drag update (viewport) itemId=${widget.itemId} deltaScreen=${details.delta} nextViewport=$nextVp');
          }
        }
      },
      onPanEnd: (_) {
        scope?.controller.endDrag(widget.itemId);
        if (kDebugMode) {
          print('[CanvasKit] Drag end itemId=${widget.itemId}');
        }
      },
      onPanCancel: () {
        scope?.controller.endDrag(widget.itemId);
        if (kDebugMode) {
          print('[CanvasKit] Drag cancel itemId=${widget.itemId}');
        }
      },
      child: widget.child,
    );
  }
}
