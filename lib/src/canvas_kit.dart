import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

bool _nearZero(double v, {double eps = 1e-9}) => v.abs() <= eps;

bool _isAxisAlignedScaleTranslate(Matrix4 t, {double eps = 1e-9}) {
  final m = t.storage;
  // Column-major:
  // [ m0  m4  m8  m12 ]
  // [ m1  m5  m9  m13 ]
  // [ m2  m6  m10 m14 ]
  // [ m3  m7  m11 m15 ]
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
  final ValueChanged<CanvasKitRenderStats>? onRenderStats;

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
    this.onRenderStats,
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
  Size? _viewportSize;
  int _transformRevision = 0;

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
  int get transformRevision => _transformRevision;
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

  void _setViewportSize(Size size) {
    _viewportSize = size;
  }

  void _markTransformChanged({bool notify = false}) {
    _transformRevision++;
    if (notify) notifyListeners();
  }

  void _setTransformInternal(Matrix4 t,
      {bool notify = false,
      bool applyConstraints = true,
      bool takeOwnership = false}) {
    _transform = takeOwnership ? t : t.clone();

    // Apply boundary constraints if enabled
    if (applyConstraints &&
        enableBoundaryConstraints &&
        bounds != null &&
        _attached != null) {
      _constrainToBounds();
    }

    _markTransformChanged(notify: notify);
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
    if (_isAxisAlignedScaleTranslate(_transform)) {
      final m = _transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      if (!_nearZero(sx) && !_nearZero(sy)) {
        final left = (0.0 - tx) / sx;
        final top = (0.0 - ty) / sy;
        final right = (viewportSize.width - tx) / sx;
        final bottom = (viewportSize.height - ty) / sy;
        return Rect.fromLTRB(
          math.min(left, right),
          math.min(top, bottom),
          math.max(left, right),
          math.max(top, bottom),
        );
      }
    }
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
    if (bounds == null) return;
    final viewportSize = _viewportSize;
    if (viewportSize == null) return;
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
    if (worldDelta == Offset.zero) return;
    final next = _transform.clone()..translate(worldDelta.dx, worldDelta.dy);
    _setTransformInternal(next, notify: true, takeOwnership: true);
  }

  /// Set absolute [nextScale] around an optional [focalWorld] point (world coords).
  /// Applies min/max zoom and respects bounds if configured.
  void setScale(double nextScale, {Offset focalWorld = Offset.zero}) {
    // Apply minimum scale for bounds if set
    double minScaleAllowed = minZoom;
    if (bounds != null && _viewportSize != null) {
      minScaleAllowed =
          math.max(minZoom, getMinimumScaleForBounds(_viewportSize!));
    }

    final clamped = nextScale.clamp(minScaleAllowed, maxZoom).toDouble();
    final current = scale;
    if ((clamped - current).abs() < 1e-6) return;
    final s = clamped / current;
    final next = _transform.clone()
      ..translate(focalWorld.dx, focalWorld.dy)
      ..scale(s, s)
      ..translate(-focalWorld.dx, -focalWorld.dy);
    _setTransformInternal(next, notify: true, takeOwnership: true);
  }

  // Helpers
  /// Convert a screen (logical pixel) point to world coordinates.
  Offset screenToWorld(Offset screenPoint) {
    if (_isAxisAlignedScaleTranslate(_transform)) {
      final m = _transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      if (!_nearZero(sx) && !_nearZero(sy)) {
        return Offset((screenPoint.dx - tx) / sx, (screenPoint.dy - ty) / sy);
      }
    }
    final inverted = Matrix4.inverted(_transform);
    final Vector3 v = Vector3(screenPoint.dx, screenPoint.dy, 0)
      ..applyMatrix4(inverted);
    return Offset(v.x, v.y);
  }

  /// Convert a world point to screen (logical pixel) coordinates.
  Offset worldToScreen(Offset worldPoint) {
    if (_isAxisAlignedScaleTranslate(_transform)) {
      final m = _transform.storage;
      final sx = m[0];
      final sy = m[5];
      final tx = m[12];
      final ty = m[13];
      return Offset(worldPoint.dx * sx + tx, worldPoint.dy * sy + ty);
    }
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
  CanvasKitController? _controller;
  // For interactive pinch handling (simple demo)
  double? _scaleStart;
  Offset? _focalWorldAtStart;
  bool _isInitialized = false;
  int _lastTransformRevision = -1;

  @override
  void initState() {
    super.initState();
    final initial = Matrix4.identity()
      ..translate(widget.initialPan.dx, widget.initialPan.dy)
      ..scale(widget.initialZoom, widget.initialZoom);
    _controller = widget.controller ??
        CanvasKitController(
          initialTransform: initial,
          minZoom: widget.minZoom,
          maxZoom: widget.maxZoom,
          bounds: widget.bounds,
        );
    _controller!._attachWidget(this);
    _controller!.addListener(_onControllerChanged);
    _lastTransformRevision = _controller!.transformRevision;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        _controller!._setViewportSize(viewportSize);
        final transform = _controller!._transform;
        final scale = _controller!.scale;

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) {
            if (!widget.enableWheelZoom || event is! PointerScrollEvent) return;
            if (widget.interactionMode == InteractionMode.programmatic &&
                widget.gestureOverlayBuilder != null) {
              return;
            }
            final double scaleDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
            final Offset screenPos = event.localPosition;
            final Offset worldBefore = _controller!.screenToWorld(screenPos);
            _controller!.setScale(_controller!.scale * scaleDelta,
                focalWorld: worldBefore);
          },
          child: Stack(
            children: [
              if (widget.backgroundBuilder != null)
                Positioned.fill(child: widget.backgroundBuilder!(transform)),

              ...widget.foregroundLayers.map(
                (painterBuilder) => Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: painterBuilder(transform),
                    ),
                  ),
                ),
              ),

              if (widget.gestureOverlayBuilder != null)
                Positioned.fill(
                    child:
                        widget.gestureOverlayBuilder!(transform, _controller!)),

              if (!(widget.interactionMode == InteractionMode.programmatic &&
                  widget.gestureOverlayBuilder != null))
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      if (_controller?.hasActiveDrag == true) return;
                      _scaleStart = _controller!.scale;
                      _focalWorldAtStart =
                          _controller!.screenToWorld(details.localFocalPoint);
                    },
                    onScaleUpdate: (details) {
                      if (!widget.enablePan) return;
                      if (_controller?.hasActiveDrag == true) return;

                      if (widget.interactionMode == InteractionMode.interactive) {
                        final pointerCount = details.pointerCount;
                        if (pointerCount <= 1) {
                          _controller!.translateWorld(_controller!
                              .deltaScreenToWorld(details.focalPointDelta));
                          return;
                        }

                        if (_scaleStart == null || _focalWorldAtStart == null) {
                          return;
                        }

                        final proposed = _scaleStart! * details.scale;
                        _controller!
                            .setScale(proposed, focalWorld: _focalWorldAtStart!);

                        final currentScreen =
                            _controller!.worldToScreen(_focalWorldAtStart!);
                        final screenDelta =
                            details.localFocalPoint - currentScreen;
                        final correction = _controller!.deltaScreenToWorld(
                            screenDelta);
                        _controller!.translateWorld(correction);
                      } else {
                        final worldDelta = _controller!
                            .deltaScreenToWorld(details.focalPointDelta);
                        if (worldDelta == Offset.zero) return;
                        _controller!.translateWorld(worldDelta);
                      }
                    },
                    onScaleEnd: (_) {
                      _scaleStart = null;
                      _focalWorldAtStart = null;
                    },
                    child: const SizedBox.expand(),
                  ),
                ),

              CanvasKitScope(
                transform: transform,
                scale: scale,
                controller: _controller!,
                transformRevision: _controller!.transformRevision,
                child: SimpleCanvas(
                  transform: transform,
                  scale: scale,
                  viewportSize: viewportSize,
                  controller: _controller!,
                  onRenderStats: widget.onRenderStats,
                  children: widget.children,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _onControllerChanged() {
    final controller = _controller!;
    final rev = controller.transformRevision;
    if (rev == _lastTransformRevision) return;
    _lastTransformRevision = rev;
    setState(() {});
    widget.onZoomChanged?.call(controller.scale);
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
  final int transformRevision;

  const CanvasKitScope({
    super.key,
    required this.transform,
    required this.scale,
    required this.controller,
    this.transformRevision = 0,
    required super.child,
  });

  static CanvasKitScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CanvasKitScope>();
    assert(scope != null, 'CanvasKitScope not found in context');
    return scope!;
  }

  static CanvasKitScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CanvasKitScope>();
  }

  @override
  bool updateShouldNotify(covariant CanvasKitScope oldWidget) {
    return oldWidget.transformRevision != transformRevision ||
        !identical(oldWidget.transform, transform) ||
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
  final double? scale;
  final Size? viewportSize;
  final CanvasKitController? controller;
  final ValueChanged<CanvasKitRenderStats>? onRenderStats;

  const SimpleCanvas({
    super.key,
    required this.transform,
    required this.children,
    this.scale,
    this.viewportSize,
    this.controller,
    this.onRenderStats,
  });

  @override
  Widget build(BuildContext context) {
    final scope = CanvasKitScope.maybeOf(context);
    final effectiveController = controller ?? scope?.controller;
    final effectiveScale =
        scale ?? scope?.scale ?? transform.getMaxScaleOnAxis();

    final effectiveViewportSize = viewportSize;
    if (effectiveViewportSize == null) {
      return LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return _buildWith(
          controller: effectiveController,
          scale: effectiveScale,
          viewportSize: size,
        );
      });
    }
    return _buildWith(
      controller: effectiveController,
      scale: effectiveScale,
      viewportSize: effectiveViewportSize,
    );
  }

  Widget _buildWith({
    required CanvasKitController? controller,
    required double scale,
    required Size viewportSize,
  }) {
    Rect visibleWorldRectForTransform(Matrix4 t) {
      if (_isAxisAlignedScaleTranslate(t)) {
        final m = t.storage;
        final sx = m[0];
        final sy = m[5];
        final tx = m[12];
        final ty = m[13];
        if (!_nearZero(sx) && !_nearZero(sy)) {
          final left = (0.0 - tx) / sx;
          final top = (0.0 - ty) / sy;
          final right = (viewportSize.width - tx) / sx;
          final bottom = (viewportSize.height - ty) / sy;
          return Rect.fromLTRB(
            math.min(left, right),
            math.min(top, bottom),
            math.max(left, right),
            math.max(top, bottom),
          );
        }
      }
      final inv = Matrix4.inverted(t);
      final tl = Vector3(0, 0, 0)..applyMatrix4(inv);
      final br =
          Vector3(viewportSize.width, viewportSize.height, 0)..applyMatrix4(inv);
      return Rect.fromLTRB(
        math.min(tl.x, br.x),
        math.min(tl.y, br.y),
        math.max(tl.x, br.x),
        math.max(tl.y, br.y),
      );
    }

    final worldVisible =
        (controller?.getVisibleWorldRect(viewportSize) ??
                visibleWorldRectForTransform(transform))
            .inflate(250.0);
    final screenVisible =
        Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height)
            .inflate(250.0);

    final List<Widget> worldItems = <Widget>[];
    final List<Widget> viewportItems = <Widget>[];
    int visibleWorldCount = 0;
    int visibleViewportCount = 0;

    for (final item in children) {
      final bool visible;
      if (controller?.isDragging(item.id) ?? false) {
        visible = true;
      } else if (item.anchor == CanvasAnchor.world) {
        if (item.estimatedSize != null) {
          final rect = Rect.fromLTWH(
            item.worldPosition.dx,
            item.worldPosition.dy,
            item.estimatedSize!.width,
            item.estimatedSize!.height,
          );
          visible = worldVisible.overlaps(rect);
        } else {
          visible = worldVisible.contains(item.worldPosition);
        }
      } else {
        final point = item.viewportPosition ?? Offset.zero;
        if (item.estimatedSize != null) {
          final shouldScale = item.scaleWithZoom && !item.lockZoom;
          final w = item.estimatedSize!.width * (shouldScale ? scale : 1.0);
          final h = item.estimatedSize!.height * (shouldScale ? scale : 1.0);
          visible = screenVisible.overlaps(Rect.fromLTWH(point.dx, point.dy, w, h));
        } else {
          visible = screenVisible.contains(point);
        }
      }

      if (!visible) continue;

      if (item.anchor == CanvasAnchor.world) {
        Widget visual = item.child;
        if (item.lockZoom) {
          visual = Transform.scale(
            scale: 1.0 / scale,
            alignment: Alignment.topLeft,
            child: visual,
          );
        }
        Widget content = visual;
        if (item.draggable) {
          content = _DraggableWrapper(
            key: ValueKey('drag-${item.id}'),
            itemId: item.id,
            controller: controller,
            anchor: item.anchor,
            initialWorldPosition: item.worldPosition,
            initialViewportPosition: item.viewportPosition ?? Offset.zero,
            onWorldMoved: item.onWorldMoved,
            onViewportMoved: item.onViewportMoved,
            child: visual,
          );
        }
        worldItems.add(Positioned(
          key: ValueKey('item-${item.id}'),
          left: item.worldPosition.dx,
          top: item.worldPosition.dy,
          child: content,
        ));
        visibleWorldCount++;
      } else {
        final vp = item.viewportPosition ?? Offset.zero;
        Widget content = item.child;
        if (item.draggable) {
          content = _DraggableWrapper(
            key: ValueKey('drag-${item.id}'),
            itemId: item.id,
            controller: controller,
            anchor: item.anchor,
            initialWorldPosition: item.worldPosition,
            initialViewportPosition: item.viewportPosition ?? Offset.zero,
            onWorldMoved: item.onWorldMoved,
            onViewportMoved: item.onViewportMoved,
            child: content,
          );
        }
        if (item.scaleWithZoom && !item.lockZoom) {
          content = Transform.scale(
            scale: scale,
            alignment: Alignment.topLeft,
            child: content,
          );
        }
        viewportItems.add(Positioned(
          key: ValueKey('item-${item.id}'),
          left: vp.dx,
          top: vp.dy,
          child: content,
        ));
        visibleViewportCount++;
      }
    }

    onRenderStats?.call(CanvasKitRenderStats(
      totalItems: children.length,
      visibleItems: visibleWorldCount + visibleViewportCount,
      visibleWorldItems: visibleWorldCount,
      visibleViewportItems: visibleViewportCount,
      visibleWorldRect: worldVisible,
      scale: scale,
      viewportSize: viewportSize,
    ));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Transform(
          transform: transform,
          alignment: Alignment.topLeft,
          child: Stack(
            clipBehavior: Clip.none,
            children: worldItems,
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: viewportItems,
        ),
      ],
    );
  }
}

class CanvasKitRenderStats {
  final int totalItems;
  final int visibleItems;
  final int visibleWorldItems;
  final int visibleViewportItems;
  final Rect visibleWorldRect;
  final double scale;
  final Size viewportSize;

  const CanvasKitRenderStats({
    required this.totalItems,
    required this.visibleItems,
    required this.visibleWorldItems,
    required this.visibleViewportItems,
    required this.visibleWorldRect,
    required this.scale,
    required this.viewportSize,
  });
}

/// Internal wrapper that converts screen-space drag deltas into world-space
/// and calls back with the updated world position. It does not keep state;
/// the parent should update the `CanvasItem.worldPosition`.
class _DraggableWrapper extends StatefulWidget {
  final CanvasKitController? controller;
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
    this.controller,
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
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onPanStart: (details) {
        _dragStartWorldPos = widget.initialWorldPosition;
        _dragStartViewportPos = widget.initialViewportPosition;
        widget.controller?.beginDrag(widget.itemId);
      },
      onPanUpdate: (details) {
        if (widget.anchor == CanvasAnchor.world) {
          if (widget.onWorldMoved == null) return;
          // With the world layer transformed, gesture deltas are already in world-space.
          final worldDelta = details.delta;
          final nextPos = _dragStartWorldPos + worldDelta;
          widget.onWorldMoved?.call(nextPos);
          _dragStartWorldPos = nextPos;
        } else {
          if (widget.onViewportMoved == null) return;
          final nextVp = _dragStartViewportPos +
              details.delta; // viewport is in screen pixels
          widget.onViewportMoved?.call(nextVp);
          _dragStartViewportPos = nextVp;
        }
      },
      onPanEnd: (_) {
        widget.controller?.endDrag(widget.itemId);
      },
      onPanCancel: () {
        widget.controller?.endDrag(widget.itemId);
      },
      child: widget.child,
    );
  }
}
