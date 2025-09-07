import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../shared/grid_background.dart';

// Visual port margin that extends beyond the node body so ports are fully hittable.
const double kPortMargin = 12.0;
// Debug: color the padding zone so you can see the hittable transparent area.
const bool kShowPaddingDebug = false; // off by default
const Color kPaddingDebugColor = Color(0x22FF00FF); // translucent magenta
// Concise gesture logs
const bool kLogGestures = true;

class NodeEditorDemoPage extends StatefulWidget {
  const NodeEditorDemoPage({super.key});

  @override
  State<NodeEditorDemoPage> createState() => _NodeEditorDemoPageState();
}

class _NodeEditorDemoPageState extends State<NodeEditorDemoPage> {
  late final CanvasKitController _controller;

  // Simple node model
  // Layout: two rows, three columns with equal spacing
  // Columns X: 180, 460, 740
  // Rows Y: 180 (top), 340 (bottom)
  final List<_Node> _nodes = [
    _Node(
      id: 'src-data',
      title: 'Data Source',
      position: const Offset(180, 180),
      inPorts: 0,
      outPorts: 1,
      size: const Size(160, 90),
    ),
    _Node(
      id: 'src-user',
      title: 'User Input',
      position: const Offset(180, 340),
      inPorts: 0,
      outPorts: 1,
      size: const Size(160, 90),
    ),
    _Node(
      id: 'proc-validate',
      title: 'Validation',
      position: const Offset(460, 180),
      inPorts: 1,
      outPorts: 1,
      size: const Size(160, 90),
    ),
    _Node(
      id: 'proc-transform',
      title: 'Transform',
      position: const Offset(460, 340),
      inPorts: 1,
      outPorts: 1,
      size: const Size(160, 90),
    ),
    _Node(
      id: 'proc-aggregate',
      title: 'Aggregation',
      position: const Offset(740, 180),
      inPorts: 2,
      outPorts: 1,
      size: const Size(160, 90),
    ),
    _Node(
      id: 'out-report',
      title: 'Report',
      position: const Offset(740, 340),
      inPorts: 1,
      outPorts: 0,
      size: const Size(160, 90),
    ),
  ];

  // List of connections (from out-port to in-port)
  // Seed initial connections so the graph is wired on startup
  final List<_Connection> _connections = [
    _Connection(
      from: _PortRef(nodeId: 'src-user', isOut: true, index: 0),
      to: _PortRef(nodeId: 'proc-transform', isOut: false, index: 0),
    ),
    _Connection(
      from: _PortRef(nodeId: 'proc-validate', isOut: true, index: 0),
      to: _PortRef(nodeId: 'proc-aggregate', isOut: false, index: 0),
    ),
    _Connection(
      from: _PortRef(nodeId: 'proc-aggregate', isOut: true, index: 0),
      to: _PortRef(nodeId: 'out-report', isOut: false, index: 0),
    ),
  ];

  // Active connection drag
  _ActiveDrag? _activeDrag;

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
    // After first layout, fit the camera to include all nodes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      final rects = _nodes
          .map(
            (n) => Rect.fromLTWH(
              n.position.dx,
              n.position.dy,
              n.size.width + kPortMargin * 2,
              n.size.height,
            ),
          )
          .toList();
      _controller.fitToRects(rects, size, padding: 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Node Editor (drag nodes, draw wires)'),
      ),
      body: Stack(
        children: [
          // Infinite canvas content
          CanvasKit(
            controller: _controller,
            interactionMode: InteractionMode.interactive,
            backgroundBuilder: (transform) => _EditorBackground(
              transform: transform,
              nodes: _nodes,
              connections: _connections,
              activeDrag: _activeDrag,
              onBackgroundPanUpdate: (screenDelta) {
                // If we're dragging a connection, update its end in world space
                if (_activeDrag != null) {
                  final s = _controller.scale;
                  setState(() {
                    _activeDrag = _activeDrag!.copyWith(
                      endWorld:
                          _activeDrag!.endWorld +
                          Offset(screenDelta.dx / s, screenDelta.dy / s),
                    );
                  });
                } else {
                  // Pan background normally
                  final worldDelta = _controller.deltaScreenToWorld(
                    screenDelta,
                  );
                  _controller.translateWorld(worldDelta);
                }
              },
              onBackgroundPanEnd: (screenPos, transform) {
                if (_activeDrag == null) return;
                final endWorld = _screenToWorld(screenPos, transform);
                final hit = _hitTestInPort(endWorld);
                if (hit != null) {
                  setState(() {
                    _connections.add(
                      _Connection(from: _activeDrag!.from, to: hit),
                    );
                  });
                }
                setState(() => _activeDrag = null);
              },
            ),
            children: [
              // Nodes as draggable CanvasItems
              for (final node in _nodes)
                CanvasItem(
                  id: 'node-${node.id}',
                  worldPosition: node.position,
                  draggable:
                      false, // custom drag inside node widget to avoid gesture conflicts with ports
                  child: _NodeWidget(
                    node: node,
                    onDragNodeTo: (nextWorldPos) => setState(() {
                      node.position = nextWorldPos;
                    }),
                    onStartWireFromOutPort: (portIndex, portWorldPos) {
                      setState(() {
                        _activeDrag = _ActiveDrag(
                          from: _PortRef(
                            nodeId: node.id,
                            isOut: true,
                            index: portIndex,
                          ),
                          startWorld: portWorldPos,
                          endWorld: portWorldPos,
                        );
                      });
                      // Suppress background pan while drawing a wire
                      _controller.beginDrag('wire');
                    },
                  ),
                ),
            ],
          ),
          // Global pointer tracker so the active wire follows the cursor/finger anywhere
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerMove: (event) {
                if (_activeDrag == null) return;
                final endWorld = _controller.screenToWorld(event.localPosition);
                setState(() {
                  _activeDrag = _activeDrag!.copyWith(endWorld: endWorld);
                });
              },
              onPointerHover: (event) {
                if (_activeDrag == null) return;
                final endWorld = _controller.screenToWorld(event.localPosition);
                setState(() {
                  _activeDrag = _activeDrag!.copyWith(endWorld: endWorld);
                });
              },
              onPointerUp: (event) {
                if (_activeDrag == null) return;
                final endWorld = _controller.screenToWorld(event.localPosition);
                final hit = _hitTestInPort(endWorld);
                if (hit != null) {
                  setState(() {
                    _connections.add(
                      _Connection(from: _activeDrag!.from, to: hit),
                    );
                  });
                }
                setState(() => _activeDrag = null);
                _controller.endDrag('wire');
              },
            ),
          ),
        ],
      ),
    );
  }

  _PortRef? _hitTestInPort(Offset worldPoint) {
    const hitRadius = 16.0;
    for (final n in _nodes) {
      for (int i = 0; i < n.inPorts; i++) {
        final p = n.inPortWorld(i);
        if ((p - worldPoint).distance <= hitRadius) {
          return _PortRef(nodeId: n.id, isOut: false, index: i);
        }
      }
    }
    return null;
  }
}

// Background draws the wires and handles background panning and active wire drag.
class _EditorBackground extends StatelessWidget {
  final Matrix4 transform;
  final List<_Node> nodes;
  final List<_Connection> connections;
  final _ActiveDrag? activeDrag;
  final void Function(Offset screenDelta) onBackgroundPanUpdate;
  final void Function(Offset screenPos, Matrix4 transform) onBackgroundPanEnd;

  const _EditorBackground({
    required this.transform,
    required this.nodes,
    required this.connections,
    required this.activeDrag,
    required this.onBackgroundPanUpdate,
    required this.onBackgroundPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shared grid background used across demos
        Positioned.fill(
          child: GridBackground(
            transform: transform,
            backgroundColor: const Color(0xFFF2F8FF),
            gridSpacing: 80,
            gridColor: const Color(0x22000000),
          ),
        ),
        // Gesture layer + wires on top
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => onBackgroundPanUpdate(d.delta),
            onPanEnd: (d) {
              // Use last known finger position; GestureDetector does not give it here,
              // so we approximate with center of the widget. We'll improve via Listener if needed.
              final box = context.findRenderObject() as RenderBox?;
              final center = box?.size.center(Offset.zero) ?? Offset.zero;
              onBackgroundPanEnd(center, transform);
            },
            child: CustomPaint(
              painter: _WirePainter(
                transform: transform,
                nodes: nodes,
                connections: connections,
                activeDrag: activeDrag,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WirePainter extends CustomPainter {
  final Matrix4 transform;
  final List<_Node> nodes;
  final List<_Connection> connections;
  final _ActiveDrag? activeDrag;

  _WirePainter({
    required this.transform,
    required this.nodes,
    required this.connections,
    required this.activeDrag,
  });

  Offset _worldToScreen(Offset worldPoint) {
    final v = Vector3(worldPoint.dx, worldPoint.dy, 0)..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw connections
    final wirePaint = Paint()
      ..color = Colors.blueGrey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final c in connections) {
      final fromNode = nodes.firstWhere((n) => n.id == c.from.nodeId);
      final toNode = nodes.firstWhere((n) => n.id == c.to.nodeId);
      final p0 = _worldToScreen(fromNode.outPortWorld(c.from.index));
      final p1 = _worldToScreen(toNode.inPortWorld(c.to.index));
      _drawWire(canvas, p0, p1, wirePaint);
    }

    // Active drag wire
    if (activeDrag != null) {
      final p0 = _worldToScreen(activeDrag!.startWorld);
      final p1 = _worldToScreen(activeDrag!.endWorld);
      _drawWire(canvas, p0, p1, wirePaint..color = Colors.blueAccent);
    }
  }

  void _drawWire(Canvas canvas, Offset p0, Offset p1, Paint paint) {
    // Simple cubic curve with tangents along x
    final dx = (p1.dx - p0.dx).abs();
    final c1 = p0 + Offset(dx * 0.4, 0);
    final c2 = p1 - Offset(dx * 0.4, 0);
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WirePainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.nodes != nodes ||
        oldDelegate.connections != connections ||
        oldDelegate.activeDrag != activeDrag;
  }
}

class _NodeWidget extends StatefulWidget {
  final _Node node;
  final void Function(Offset nextWorldPos) onDragNodeTo;
  final void Function(int outPortIndex, Offset portWorldPos)
  onStartWireFromOutPort;

  const _NodeWidget({
    required this.node,
    required this.onDragNodeTo,
    required this.onStartWireFromOutPort,
  });

  @override
  State<_NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<_NodeWidget> {
  late Offset _dragStartWorld;
  Offset? _lastGlobalPos;

  @override
  void initState() {
    super.initState();
    _dragStartWorld = widget.node.position;
  }

  @override
  void didUpdateWidget(covariant _NodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.position != widget.node.position) {
      _dragStartWorld = widget.node.position;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = CanvasKitScope.of(context);

    final box = GestureDetector(
      behavior:
          HitTestBehavior.deferToChild, // let port detectors win when touched
      onPanStart: (details) {
        _dragStartWorld = widget.node.position;
        _lastGlobalPos = details.globalPosition;
        scope.controller.beginDrag('node-${widget.node.id}');
        if (kLogGestures) {
          debugPrint(
            '[NodeEditor] node drag start id=${widget.node.id} startWorld=${_dragStartWorld.dx.toStringAsFixed(1)},${_dragStartWorld.dy.toStringAsFixed(1)} scale=${scope.scale.toStringAsFixed(3)}',
          );
        }
      },
      onPanUpdate: (details) {
        // Use global pointer positions to compute screen delta, then convert to world delta.
        final prev = _lastGlobalPos ?? details.globalPosition;
        final screenDelta = details.globalPosition - prev;
        _lastGlobalPos = details.globalPosition;

        final before = _dragStartWorld;
        final worldDelta = scope.controller.deltaScreenToWorld(screenDelta);
        final after = before + worldDelta;
        _dragStartWorld = after;
        widget.onDragNodeTo(after);
        if (kLogGestures) {
          debugPrint(
            '[NodeEditor] node drag move id=${widget.node.id} screenDelta=${screenDelta.dx.toStringAsFixed(1)},${screenDelta.dy.toStringAsFixed(1)} scale=${scope.scale.toStringAsFixed(3)} worldDelta=${worldDelta.dx.toStringAsFixed(2)},${worldDelta.dy.toStringAsFixed(2)} before=${before.dx.toStringAsFixed(1)},${before.dy.toStringAsFixed(1)} after=${after.dx.toStringAsFixed(1)},${after.dy.toStringAsFixed(1)}',
          );
        }
      },
      onPanEnd: (_) {
        scope.controller.endDrag('node-${widget.node.id}');
        _lastGlobalPos = null;
        if (kLogGestures) {
          debugPrint('[NodeEditor] node drag end id=${widget.node.id}');
        }
      },
      onPanCancel: () {
        scope.controller.endDrag('node-${widget.node.id}');
        _lastGlobalPos = null;
        if (kLogGestures) {
          debugPrint('[NodeEditor] node drag cancel id=${widget.node.id}');
        }
      },
      child: SizedBox(
        // Make the gesture/hit-test area include the padding explicitly
        width: widget.node.size.width + 2 * kPortMargin,
        height: widget.node.size.height,
        child: Stack(
          clipBehavior: Clip.none, // allow ports to overhang further if needed
          children: [
            // Pink padding debug background spanning the full tappable area (including margins)
            if (kShowPaddingDebug) Container(color: kPaddingDebugColor),

            // The actual node body placed inside with left margin = kPortMargin
            Positioned(
              left: kPortMargin,
              top: 0,
              width: widget.node.size.width,
              height: widget.node.size.height,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black54, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        widget.node.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: SizedBox(),
                    ), // body space (ports sit in outer Stack)
                  ],
                ),
              ),
            ),

            // In-ports (left) relative to the OUTER stack (which includes margins)
            for (int i = 0; i < widget.node.inPorts; i++)
              Positioned(
                left:
                    kPortMargin -
                    12, // center at x=kPortMargin so circle sticks out half into margin
                top: widget.node.portYOffset(i) - 12,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(child: _PortCircle(color: Colors.redAccent)),
                ),
              ),

            // Out-ports (right) with their own gesture detectors; also relative to OUTER stack
            for (int i = 0; i < widget.node.outPorts; i++)
              Positioned(
                right:
                    kPortMargin -
                    12, // center at x=width+kPortMargin so circle sticks out half into margin
                top: widget.node.portYOffset(i) - 12,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {
                      final worldPos = widget.node.outPortWorld(i);
                      widget.onStartWireFromOutPort(i, worldPos);
                      if (kLogGestures) {
                        debugPrint(
                          '[NodeEditor] start wire from node=${widget.node.id} out[$i] @ ${worldPos.dx.toStringAsFixed(1)},${worldPos.dy.toStringAsFixed(1)}',
                        );
                      }
                    },
                    child: const Center(
                      child: _PortCircle(color: Colors.green),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return box;
  }
}

class _PortCircle extends StatelessWidget {
  final Color color;
  const _PortCircle({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

class _Node {
  final String id;
  final String title;
  Offset position;
  final int inPorts;
  final int outPorts;
  final Size size;

  _Node({
    required this.id,
    required this.title,
    required this.position,
    this.inPorts = 1,
    this.outPorts = 1,
    required this.size,
  });

  // vertical offset for ith port inside node content area
  double portYOffset(int i) {
    final innerHeight = size.height - 28; // header 28
    if (inPorts <= 1 && outPorts <= 1) return innerHeight / 2;
    final count = (inPorts > outPorts ? inPorts : outPorts).clamp(1, 8);
    return 28 + innerHeight * ((i + 1) / (count + 1));
  }

  Offset inPortWorld(int index) {
    // Visual in-port center sits at body-left (which is node.position.x + kPortMargin)
    final local = Offset(kPortMargin, portYOffset(index));
    return position + local;
  }

  Offset outPortWorld(int index) {
    final local = Offset(size.width + kPortMargin, portYOffset(index));
    return position + local;
  }
}

class _Connection {
  final _PortRef from; // out
  final _PortRef to; // in
  _Connection({required this.from, required this.to});
}

class _PortRef {
  final String nodeId;
  final bool isOut;
  final int index;
  _PortRef({required this.nodeId, required this.isOut, required this.index});
}

class _ActiveDrag {
  final _PortRef from; // out-port
  final Offset startWorld;
  final Offset endWorld;
  _ActiveDrag({
    required this.from,
    required this.startWorld,
    required this.endWorld,
  });
  _ActiveDrag copyWith({Offset? endWorld}) => _ActiveDrag(
    from: from,
    startWorld: startWorld,
    endWorld: endWorld ?? this.endWorld,
  );
}

Offset _screenToWorld(Offset screenPoint, Matrix4 transform) {
  final inverted = Matrix4.inverted(transform);
  final v = Vector3(screenPoint.dx, screenPoint.dy, 0)..applyMatrix4(inverted);
  return Offset(v.x, v.y);
}
