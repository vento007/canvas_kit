import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

/// Interactive node with internal controls to test gesture handling
class InteractiveNode extends StatefulWidget {
  final String id;
  final Offset position;
  final Function(Offset newPosition) onMoved;
  final bool enableDrag;
  final bool locked; // if true, CanvasItem should be non-draggable
  final bool anchoredToViewport; // if true, CanvasItem uses viewport anchoring
  final Offset? viewportPosition; // current viewport position (when anchored)
  final ValueChanged<bool>? onToggleLocked;
  final bool
  lockZoom; // if true, the parent CanvasItem should ignore zoom scaling
  final ValueChanged<bool>? onToggleLockZoom;
  final void Function(
    bool nextViewportAnchor, {
    Offset? viewportPosSuggestion,
    Offset? worldPosSuggestion,
  })?
  onToggleAnchored;

  const InteractiveNode({
    super.key,
    required this.id,
    required this.position,
    required this.onMoved,
    this.enableDrag = false,
    this.locked = false,
    this.anchoredToViewport = false,
    this.viewportPosition,
    this.onToggleLocked,
    this.lockZoom = false,
    this.onToggleLockZoom,
    this.onToggleAnchored,
  });

  @override
  State<InteractiveNode> createState() => _InteractiveNodeState();
}

class _InteractiveNodeState extends State<InteractiveNode> {
  final List<String> _items = ['Item 1', 'Item 2'];
  final TextEditingController _textController = TextEditingController();
  bool _isHovering = false;
  // Accumulated drag positions during a gesture to keep movement 1:1 with cursor
  // even if parent rebuilds are batched.
  Offset? _dragWorldPos;
  Offset? _dragViewportPos;
  Offset? _lastGlobalPos;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _addItem({String? label}) {
    final String text = (label ?? '').trim();
    final String toAdd = text.isNotEmpty ? text : 'Item ${_items.length + 1}';
    setState(() {
      _items.add(toAdd);
    });
    if (text.isNotEmpty) {
      _textController.clear();
    }
    // ignore: avoid_print
    print("Added item: $toAdd");
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    // ignore: avoid_print
    print("Removed item at index $index");
  }

  @override
  Widget build(BuildContext context) {
    Widget content = IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 200,
          maxWidth: 300,
          minHeight: 150,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.purple, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with node info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.widgets, color: Colors.purple, size: 16),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Interactive',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Lock toggle (enables/disables dragging at CanvasItem level)
                  Tooltip(
                    message: widget.locked
                        ? 'Unlock drag'
                        : 'Lock (disable drag)',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onToggleLocked?.call(!widget.locked),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(
                            Icons.lock_open,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Anchor toggle (world <-> viewport)
                  Tooltip(
                    message: widget.anchoredToViewport
                        ? 'Anchor to world'
                        : 'Anchor to viewport',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        final scope = CanvasKitScope.of(context);
                        if (!widget.anchoredToViewport) {
                          // switching world -> viewport: suggest current screen position
                          final screen = _worldToScreen(
                            widget.position,
                            scope.transform,
                          );
                          widget.onToggleAnchored?.call(
                            true,
                            viewportPosSuggestion: screen,
                          );
                        } else {
                          // switching viewport -> world: suggest world from current viewport position
                          final vp = widget.viewportPosition ?? Offset.zero;
                          final world = _screenToWorld(vp, scope.transform);
                          widget.onToggleAnchored?.call(
                            false,
                            worldPosSuggestion: world,
                          );
                        }
                      },
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(
                            Icons.push_pin_outlined,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Lock zoom (ignore canvas zoom scaling)
                  Tooltip(
                    message: widget.lockZoom
                        ? 'Unlock size (scale with zoom)'
                        : 'Lock size (ignore zoom)',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          widget.onToggleLockZoom?.call(!widget.lockZoom),
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(
                            Icons.open_in_full,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Interactive content area
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text field
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Enter text',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                    onSubmitted: (value) {
                      final v = value.trim();
                      if (v.isNotEmpty) {
                        _addItem(label: v);
                      }
                      // ignore: avoid_print
                      print("Text submitted: $value");
                    },
                  ),

                  const SizedBox(height: 8),

                  // Items list with add/remove
                  Row(
                    children: [
                      const Text(
                        'Items:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          final v = _textController.text.trim();
                          if (v.isNotEmpty) {
                            _addItem(label: v);
                          } else {
                            _addItem();
                          }
                        },
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _isHovering = true),
                          onExit: (_) => setState(() => _isHovering = false),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _isHovering
                                  ? Colors.green
                                  : Colors.green.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Items list
                  Column(
                    children: _items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _removeItem(index),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Disable drag when not enabled or locked
    if (!widget.enableDrag || widget.locked) {
      return content;
    }

    // Local drag handling: convert deltas based on current anchor/zoom and
    // signal drag begin/end to the canvas controller so background panning is blocked.
    return Builder(
      builder: (context) {
        final scope = CanvasKitScope.of(context);
        return GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onPanStart: (details) {
            // Initialize drag bases from latest props at gesture start
            _dragWorldPos = widget.position;
            _dragViewportPos = widget.viewportPosition ?? Offset.zero;
            _lastGlobalPos = details.globalPosition;
            scope.controller.beginDrag(widget.id);
          },
          onPanUpdate: (details) {
            // Compute raw screen-space delta from global positions to avoid transform scaling artifacts.
            final prev = _lastGlobalPos ?? details.globalPosition;
            final screenDelta = details.globalPosition - prev;
            _lastGlobalPos = details.globalPosition;

            // Convert to world units only when anchored to world.
            final Offset delta = widget.anchoredToViewport
                ? screenDelta
                : Offset(
                    screenDelta.dx / scope.scale,
                    screenDelta.dy / scope.scale,
                  );

            if (widget.anchoredToViewport) {
              final base =
                  _dragViewportPos ?? (widget.viewportPosition ?? Offset.zero);
              final newPos = base + delta;
              widget.onMoved(newPos);
              _dragViewportPos = newPos;
            } else {
              final base = _dragWorldPos ?? widget.position;
              final newPos = base + delta;
              widget.onMoved(newPos);
              _dragWorldPos = newPos;
            }
          },
          onPanEnd: (_) {
            scope.controller.endDrag(widget.id);
            _dragWorldPos = null;
            _dragViewportPos = null;
            _lastGlobalPos = null;
          },
          onPanCancel: () {
            scope.controller.endDrag(widget.id);
            _dragWorldPos = null;
            _dragViewportPos = null;
            _lastGlobalPos = null;
          },
          child: content,
        );
      },
    );
  }

  Offset _worldToScreen(Offset worldPoint, Matrix4 transform) {
    final Vector3 v = Vector3(worldPoint.dx, worldPoint.dy, 0)
      ..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }

  Offset _screenToWorld(Offset screenPoint, Matrix4 transform) {
    final inverted = Matrix4.inverted(transform);
    final Vector3 v = Vector3(screenPoint.dx, screenPoint.dy, 0)
      ..applyMatrix4(inverted);
    return Offset(v.x, v.y);
  }
}
