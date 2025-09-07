import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../shared/grid_background.dart';
import 'widgets/programmatic_pan_layer.dart';

class ProgrammaticDemoPage extends StatefulWidget {
  const ProgrammaticDemoPage({super.key});

  @override
  State<ProgrammaticDemoPage> createState() => _ProgrammaticDemoPageState();
}

class _ProgrammaticDemoPageState extends State<ProgrammaticDemoPage> {
  late final CanvasKitController _controller;
  Offset _pos1 = const Offset(100, 100);
  Offset _pos2 = const Offset(300, 220);

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
        title: const Text('Programmatic demo (app-owned camera)'),
        actions: [
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _controller.setScale(_controller.scale * 0.9);
            },
          ),
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _controller.setScale(_controller.scale * 1.1);
            },
          ),
          IconButton(
            tooltip: 'Center on Node 1',
            icon: const Icon(Icons.filter_center_focus),
            onPressed: () {
              // Center on the red node at (100,100)
              final size = MediaQuery.of(context).size;
              _controller.centerOn(const Offset(100, 100), size);
            },
          ),
        ],
      ),
      body: CanvasKit(
        controller: _controller,
        interactionMode: InteractionMode.programmatic, // programmatic camera
        // Paint grid as a background layer (no gestures here)
        backgroundBuilder: (t) => GridBackground(
          transform: t,
          backgroundColor: const Color(0xFFFFF7E6),
          gridSpacing: 80,
          gridColor: const Color(0x22000000),
        ),
        // App-owned gesture overlay: handles pan, pinch, and wheel
        gestureOverlayBuilder: (t, c) =>
            ProgrammaticPanLayer(transform: t, controller: c, paintGrid: false),
        children: [
          CanvasItem(
            id: 'node-1 drag me',
            worldPosition: _pos1,
            // We disable package-provided dragging and implement app-owned drag below.
            // This keeps the pattern transparent and editable, without opaque wrappers.
            draggable: false, // app-owned drag in programmatic demo
            child: _appDraggableNode(
              id: 'node-1',
              currentPos: _pos1,
              onWorldMoved: (pos) => setState(() => _pos1 = pos),
              child: _node(color: Colors.red, label: 'App-owned drag'),
            ),
            onWorldMoved: (pos) => setState(() => _pos1 = pos),
          ),
          CanvasItem(
            id: 'node-2 no dragable',
            worldPosition: _pos2,
            draggable: false,
            child: _node(color: Colors.blue, label: 'Not draggable'),
            onWorldMoved: (pos) => setState(() => _pos2 = pos),
          ),
        ],
      ),
    );
  }

  Widget _node({required Color color, required String label}) {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
      ),
    );
  }

  // Programmatic dragging recipe (robust, app-owned):
  // 1) Disable `CanvasItem.draggable` and wrap the child with a `GestureDetector`.
  // 2) On drag start: `_controller.beginDrag(id)` to suppress background pan; seed `lastGlobalPos`.
  // 3) On updates: compute screen delta from global pointer positions
  //      `screenDelta = details.globalPosition - lastGlobalPos`
  //    then convert with the controller
  //      `worldDelta = _controller.deltaScreenToWorld(screenDelta)`
  //    accumulate the world position locally; update `lastGlobalPos`.
  //    This stays correct even if zoom changes mid-drag.
  // 4) On drag end/cancel: `_controller.endDrag(id)` and clear `lastGlobalPos`.
  // Notes:
  //  - Avoid `details.delta`; always use global positions + controller transform.
  //  - Do not manually scale the child; visuals remain consistent with the canvas.
  //  - Keeping this as plain code (vs a wrapper) keeps the pattern explicit.
  Widget _appDraggableNode({
    required String id,
    required Offset currentPos,
    required ValueChanged<Offset> onWorldMoved,
    required Widget child,
  }) {
    Offset dragPos = currentPos; // capture at gesture start and accumulate
    Offset? lastGlobalPos;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        dragPos = currentPos;
        lastGlobalPos = details.globalPosition;
        _controller.beginDrag(id);
      },
      onPanUpdate: (details) {
        final prev = lastGlobalPos ?? details.globalPosition;
        final screenDelta = details.globalPosition - prev;
        lastGlobalPos = details.globalPosition;
        final worldDelta = _controller.deltaScreenToWorld(screenDelta);
        final next = dragPos + worldDelta;
        onWorldMoved(next);
        dragPos = next;
      },
      onPanEnd: (_) {
        _controller.endDrag(id);
        lastGlobalPos = null;
      },
      onPanCancel: () {
        _controller.endDrag(id);
        lastGlobalPos = null;
      },
      child: child,
    );
  }
}
