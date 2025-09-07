import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../shared/grid_background.dart';
import 'widgets/interactive_node.dart';

class InteractiveNodeDemoPage extends StatefulWidget {
  const InteractiveNodeDemoPage({super.key});

  @override
  State<InteractiveNodeDemoPage> createState() =>
      _InteractiveNodeDemoPageState();
}

class _InteractiveNodeDemoPageState extends State<InteractiveNodeDemoPage> {
  late final CanvasKitController _controller;

  // Interactive node (can toggle anchoring)
  bool _iAnchoredToViewport = false;
  bool _iLocked = false;
  bool _iLockZoom = false;
  Offset _iWorldPos = const Offset(180, 140);
  Offset _iViewportPos = const Offset(24, 24);

  // Regular simple node (always world-anchored, package drag)
  Offset _regularPos = const Offset(420, 260);

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false, // unify title alignment across demos
        title: const Text('Interactive Node demo (separate widgets)'),
        actions: [
          IconButton(
            tooltip: 'Fit both nodes',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              final size = MediaQuery.of(context).size;
              final Rect interactiveRect = _iAnchoredToViewport
                  ? Rect.fromLTWH(
                      _controller.screenToWorld(_iViewportPos).dx,
                      _controller.screenToWorld(_iViewportPos).dy,
                      220,
                      160,
                    )
                  : Rect.fromLTWH(_iWorldPos.dx, _iWorldPos.dy, 220, 160);
              final rects = <Rect>[
                interactiveRect,
                Rect.fromLTWH(_regularPos.dx, _regularPos.dy, 60, 40),
              ];
              _controller.fitToRects(rects, size);
            },
          ),
        ],
      ),
      body: CanvasKit(
        controller: _controller,
        backgroundBuilder: (t) => GridBackground(
          transform: t,
          backgroundColor: const Color(0xFFF7FFF2),
          gridSpacing: 80,
          gridColor: const Color(0x22000000),
        ),
        children: [
          // A single InteractiveNode that can toggle between viewport/world anchoring
          CanvasItem(
            id: 'interactive-node',
            worldPosition: _iWorldPos,
            anchor: _iAnchoredToViewport
                ? CanvasAnchor.viewport
                : CanvasAnchor.world,
            viewportPosition: _iViewportPos,
            scaleWithZoom: true,
            lockZoom: _iLockZoom,
            draggable: false, // Node handles its own drag internally
            child: InteractiveNode(
              id: 'interactive',
              position: _iWorldPos,
              viewportPosition: _iViewportPos,
              enableDrag: true,
              locked: _iLocked,
              lockZoom: _iLockZoom,
              anchoredToViewport: _iAnchoredToViewport,
              onMoved: (next) {
                setState(() {
                  if (_iAnchoredToViewport) {
                    _iViewportPos = next;
                  } else {
                    _iWorldPos = next;
                  }
                });
              },
              onToggleLocked: (v) => setState(() => _iLocked = v),
              onToggleLockZoom: (v) {
                setState(() {
                  _iLockZoom = v;
                  if (v) {
                    // When locking size, prefer viewport anchor so it behaves like a palette.
                    if (!_iAnchoredToViewport) {
                      _iAnchoredToViewport = true;
                      _iViewportPos = _controller.worldToScreen(_iWorldPos);
                    }
                  } else {
                    // When unlocking size, return to world anchor for normal node behavior.
                    if (_iAnchoredToViewport) {
                      _iAnchoredToViewport = false;
                      _iWorldPos = _controller.screenToWorld(_iViewportPos);
                    }
                  }
                });
              },
              onToggleAnchored:
                  (nextAnchor, {viewportPosSuggestion, worldPosSuggestion}) {
                    setState(() {
                      _iAnchoredToViewport = nextAnchor;
                      if (nextAnchor) {
                        _iViewportPos =
                            viewportPosSuggestion ??
                            _controller.worldToScreen(_iWorldPos);
                      } else {
                        _iWorldPos =
                            worldPosSuggestion ??
                            _controller.screenToWorld(_iViewportPos);
                      }
                    });
                  },
            ),
          ),

          // A small regular node to contrast with the interactive one
          CanvasItem(
            id: 'regular-node',
            worldPosition: _regularPos,
            draggable: true,
            onWorldMoved: (p) => setState(() => _regularPos = p),
            child: Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.teal,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Regular',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
