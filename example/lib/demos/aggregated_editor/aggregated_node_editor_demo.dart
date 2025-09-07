import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4, Vector3;

import '../../shared/grid_background.dart';
import 'aggregated_models.dart';
import 'demo_data.dart';
import 'graph_service.dart';

// This demo shows aggregated nodes where each node lists multiple items
// (e.g., multiple policies) and wires connect from specific items to other nodes' items.
// It avoids spawning many separate nodes for similar entities.

class AggregatedNodeEditorDemoPage extends StatefulWidget {
  const AggregatedNodeEditorDemoPage({super.key});

  @override
  State<AggregatedNodeEditorDemoPage> createState() =>
      _AggregatedNodeEditorDemoPageState();
}

class _AggregatedNodeEditorDemoPageState
    extends State<AggregatedNodeEditorDemoPage> {
  late final CanvasKitController _controller;
  late final GraphService _graph;
  _ActiveAggDrag? _activeDrag;
  AggConnection? _selected;
  String?
  _userPrefixFilter; // e.g., 'c:alice' => show edges starting with 'c:alice:'
  final Map<String, GlobalKey> _portKeys = {}; // key: nodeId:itemId
  final Map<String, GlobalKey> _nodeKeys = {}; // key: nodeId
  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'infinite-canvas');
  final Map<String, double> _nodeScrollOffset = {}; // nodeId -> scroll offset
  final Map<String, String> _nodeFilters = {}; // nodeId -> filter text
  bool _itemDragActive = false; // true while dragging a list item out of a node
  int _spawnCounter = 0; // for unique node ids when creating on drop
  String?
  _hoveredNodeId; // set by node DragTargets while hovering during item drag

  // Visual port margin similar to Node Editor demo so ports are hittable outside the node body
  static const double kPortMargin = 12.0;

  GlobalKey _getPortKey(String nodeId, String itemId) {
    return _portKeys.putIfAbsent(
      '$nodeId:$itemId',
      () => GlobalKey(debugLabel: 'port-$nodeId:$itemId'),
    );
  }

  // --- Helper methods for drag-move semantics ---------------------------------
  AggNode _nodeById(String nodeId) {
    return _nodes.firstWhere((n) => n.id == nodeId);
  }

  AggNode _removeItemFromNode(AggNode node, String itemId) {
    AggItem removeFromItem(AggItem it) {
      if (it.id == itemId) {
        // Mark with special id to indicate removal at top-level decision point
        return const AggItem(id: '__removed__', label: '__removed__');
      }
      if (it.children.isEmpty) return it;
      final newChildren = it.children.where((c) => c.id != itemId).toList();
      if (identical(newChildren, it.children)) return it;
      return AggItem(id: it.id, label: it.label, children: newChildren);
    }

    final updatedItems = <AggItem>[];
    for (final it in node.items) {
      final changed = removeFromItem(it);
      if (changed.id != '__removed__') {
        updatedItems.add(changed);
      }
    }
    return AggNode(
      id: node.id,
      title: node.title,
      position: node.position,
      items: updatedItems,
      width: node.width,
      height: node.height,
      inPortsSide: node.inPortsSide,
      outPortsSide: node.outPortsSide,
    );
  }

  void _replaceNode(AggNode updated) {
    final idx = _nodes.indexWhere((e) => e.id == updated.id);
    if (idx != -1) _nodes[idx] = updated;
  }

  // When moving a parent item (e.g., a user) we must update connections for the parent and all its children.
  List<String> _flattenItemIds(AggItem it) {
    final ids = <String>[it.id];
    for (final ch in it.children) {
      ids.add(ch.id);
    }
    return ids;
  }

  void _updateConnectionsOnMoveForItems({
    required List<String> itemIds,
    required String fromNodeId,
    required String toNodeId,
  }) {
    final idSet = itemIds.toSet();
    for (var i = 0; i < _connections.length; i++) {
      final c = _connections[i];
      var newFrom = c.from;
      var newTo = c.to;
      var changed = false;
      if (c.from.nodeId == fromNodeId && idSet.contains(c.from.itemId)) {
        newFrom = AggPort(
          nodeId: toNodeId,
          itemId: c.from.itemId,
          kind: c.from.kind,
        );
        changed = true;
      }
      if (c.to.nodeId == fromNodeId && idSet.contains(c.to.itemId)) {
        newTo = AggPort(nodeId: toNodeId, itemId: c.to.itemId, kind: c.to.kind);
        changed = true;
      }
      if (changed) {
        _connections[i] = AggConnection(from: newFrom, to: newTo);
      }
    }
  }

  bool _sameConn(AggConnection a, AggConnection b) {
    return a.from.nodeId == b.from.nodeId &&
        a.from.itemId == b.from.itemId &&
        a.to.nodeId == b.to.nodeId &&
        a.to.itemId == b.to.itemId;
  }

  GlobalKey _getNodeKey(String nodeId) {
    return _nodeKeys.putIfAbsent(
      nodeId,
      () => GlobalKey(debugLabel: 'node-$nodeId'),
    );
  }

  // // Get visible item IDs for a node based on its filter
  // List<String> _getVisibleItemIds(AggNode node) {
  //   final filter = _nodeFilters[node.id]?.toLowerCase().trim();
  //   if (filter == null || filter.isEmpty) {
  //     return node.flattenedIds();
  //   }

  //   final visibleIds = <String>[];
  //   for (final item in node.items) {
  //     final itemMatches =
  //         item.label.toLowerCase().contains(filter) ||
  //         item.id.toLowerCase().contains(filter);
  //     if (itemMatches) {
  //       visibleIds.add(item.id);
  //     }

  //     for (final child in item.children) {
  //       final childMatches =
  //           child.label.toLowerCase().contains(filter) ||
  //           child.id.toLowerCase().contains(filter);
  //       if (childMatches) {
  //         visibleIds.add(child.id);
  //       }
  //     }
  //   }
  //   return visibleIds;
  // }

  // Use realistic corporate demo data
  late final List<AggNode> _nodes = DemoData.allNodes;
  final List<AggConnection> _connections = [];

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
    _graph = GraphService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      final rects = _nodes
          .map(
            (n) => Rect.fromLTWH(
              n.position.dx,
              n.position.dy,
              n.size.width,
              n.size.height,
            ),
          )
          .toList();
      _controller.fitToRects(rects, size, padding: 80);
    });
    // Load comprehensive corporate demo connections
    _connections.addAll(DemoData.demoConnections);
    // Build directed graph from initial data
    _graph.build(_nodes, _connections);
  }

  @override
  Widget build(BuildContext context) {
    // Normalize filter (empty -> null)
    final String? activeUser =
        (_userPrefixFilter != null && _userPrefixFilter!.trim().isNotEmpty)
        ? _userPrefixFilter!.trim()
        : null;
    // Choose which connections to render based on selected user flow.
    final List<AggConnection> connectionsForRender;
    if (activeUser == null) {
      connectionsForRender = _connections;
    } else {
      // Start vertices: the selected user item and all its children (e.g., u:alice.smith, u:alice.smith:iphone,...)
      final usersNode = _nodes.firstWhere((n) => n.id == 'users');
      final clientRowIds = usersNode
          .flattenedIds()
          .where((id) => id == activeUser || id.startsWith('$activeUser:'))
          .toList();
      final starts = clientRowIds.map(
        (rowId) => GraphService.vertexId(usersNode.id, rowId),
      );
      final visited = _graph.reachableFrom(starts);
      String vid(String nodeId, String itemId) =>
          GraphService.vertexId(nodeId, itemId);
      connectionsForRender = _connections
          .where(
            (c) =>
                visited.contains(vid(c.from.nodeId, c.from.itemId)) &&
                visited.contains(vid(c.to.nodeId, c.to.itemId)),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggregated Node Editor'),
        actions: [
          if (_selected != null)
            Tooltip(
              message: 'Delete selected link',
              child: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  final sel = _selected!;
                  setState(() {
                    _connections.removeWhere((c) => _sameConn(c, sel));
                    _selected = null;
                  });
                  _graph.removeConnection(sel);
                },
              ),
            ),
          if (activeUser != null)
            Tooltip(
              message: 'Clear user filter',
              child: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _userPrefixFilter = null),
              ),
            ),
          PopupMenuButton<String?>(
            tooltip: 'Filter: user flow',
            initialValue: activeUser,
            onSelected: (value) =>
                setState(() => _userPrefixFilter = value ?? ''),
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String?>>[];
              items.add(
                const PopupMenuItem<String?>(
                  value: null,
                  child: Text('All edges'),
                ),
              );
              // List top-level users as selectable user filters
              final usersNode = _nodes.firstWhere((n) => n.id == 'users');
              for (final it in usersNode.items) {
                items.add(
                  PopupMenuItem<String?>(
                    value: it.id,
                    child: Text('User: ${it.label}'),
                  ),
                );
              }
              return items;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt),
                  const SizedBox(width: 4),
                  Text(
                    activeUser == null
                        ? 'All'
                        : activeUser.split(':').skip(1).join(':'),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          CanvasKit(
            key: _canvasKey,
            controller: _controller,
            interactionMode: InteractionMode.programmatic,
            backgroundBuilder: (transform) {
              return GridBackground(
                transform: transform,
                backgroundColor: const Color(0xFFF7FAFF),
                gridSpacing: 80,
                gridColor: const Color(0x22000000),
              );
            },
            gestureOverlayBuilder: (transform, controller) {
              return _ProgrammaticGestureLayer(
                transform: transform,
                controller: controller,
                nodes: _nodes,
                connections: connectionsForRender,
                activeDrag: _activeDrag,
                selected: _selected,
                scrollByNode: _nodeScrollOffset,
                nodeFilters: _nodeFilters,
                itemDragActive: _itemDragActive,
                hoveredNodeId: _hoveredNodeId,
                canvasKey: _canvasKey,
                onAcceptDrop: _handleCanvasDrop,
              );
            },
            children: [
              for (final n in _nodes)
                CanvasItem(
                  id: 'node-${n.id}',
                  worldPosition: n.position,
                  estimatedSize: Size(
                    n.size.width + 2 * kPortMargin,
                    n.size.height,
                  ),
                  draggable: false,
                  child: DragTarget<_DraggedAggItem>(
                    onWillAcceptWithDetails: (details) {
                      final canAccept =
                          true; // TEMP: Allow all drops for testing
                      debugPrint(
                        '[SIMPLE NODE DROP] willAccept ${details.data.item.id} (from: ${details.data.sourceNodeId}) -> target: ${n.id} = $canAccept',
                      );
                      if (canAccept) {
                        setState(() => _hoveredNodeId = n.id);
                      }
                      return canAccept;
                    },
                    onMove: (details) {
                      // Set hover state immediately on move
                      if (_hoveredNodeId != n.id) {
                        setState(() => _hoveredNodeId = n.id);
                        debugPrint('[NODE] Now hovering ${n.id}');
                      }
                    },
                    onLeave: (data) {
                      // Clear hover state with a small delay to prevent race conditions
                      Future.microtask(() {
                        if (mounted && _hoveredNodeId == n.id) {
                          setState(() => _hoveredNodeId = null);
                          debugPrint('[NODE] Cleared hover from ${n.id}');
                        }
                      });
                    },
                    onAcceptWithDetails: (details) {
                      final drag = details.data;
                      debugPrint(
                        '[SIMPLE NODE DROP] accepted ${drag.item.id} -> ${n.id}',
                      );

                      // Don't do anything if dropping on the same node it came from
                      if (drag.sourceNodeId == n.id) {
                        debugPrint(
                          '[NODE DROP] Self-drop ignored - no change needed',
                        );
                        setState(() => _hoveredNodeId = null);
                        return;
                      }

                      setState(() {
                        _hoveredNodeId = null;

                        // Add item to target node if not already present
                        if (!n.flattenedIds().contains(drag.item.id)) {
                          final newItems = List<AggItem>.from(n.items)
                            ..add(drag.item);
                          final updatedTarget = AggNode(
                            id: n.id,
                            title: n.title,
                            position: n.position,
                            items: newItems,
                            width: n.width,
                            height: n.height,
                            inPortsSide: n.inPortsSide,
                            outPortsSide: n.outPortsSide,
                          );
                          _replaceNode(updatedTarget);
                        }

                        // Remove item from source node
                        final src = _nodeById(drag.sourceNodeId);
                        _replaceNode(_removeItemFromNode(src, drag.item.id));

                        // Update connections
                        final movedIds = _flattenItemIds(drag.item);
                        _updateConnectionsOnMoveForItems(
                          itemIds: movedIds,
                          fromNodeId: drag.sourceNodeId,
                          toNodeId: n.id,
                        );
                        _graph.build(_nodes, _connections);
                      });
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        SnackBar(
                          content: Text('Moved ${drag.item.id} to ${n.title}'),
                          duration: const Duration(milliseconds: 900),
                        ),
                      );
                    },
                    builder: (context, candidate, rejected) {
                      final hovering = candidate.isNotEmpty;
                      debugPrint(
                        '[DRAG TARGET BUILDER] node=${n.id}, hovering=$hovering, candidates=${candidate.length}',
                      );
                      return Container(
                        // Reasonable padding to expand drop area
                        padding: _itemDragActive
                            ? EdgeInsets.all(8)
                            : EdgeInsets.zero,
                        decoration: BoxDecoration(
                          color: hovering
                              ? Colors.green.withValues(alpha: 0.2)
                              : (_itemDragActive
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : null),
                          border: hovering
                              ? Border.all(color: Colors.green, width: 3)
                              : (_itemDragActive
                                    ? Border.all(
                                        color: Colors.blue.withValues(alpha: 0.5),
                                        width: 2,
                                      )
                                    : null),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IgnorePointer(
                          ignoring:
                              _itemDragActive, // Allow drag events to reach DragTarget during drag
                          child: _AggregatedNodeWidget(
                            key: _getNodeKey(n.id),
                            node: n,
                            itemDropMode: _itemDragActive,
                            nodeFilter: _nodeFilters[n.id],
                            portKeyForItem: (itemId) =>
                                _getPortKey(n.id, itemId),
                            onItemDragActiveChanged: (active) {
                              if (_itemDragActive != active) {
                                setState(() => _itemDragActive = active);
                              }
                            },
                            onFilterChanged: (nodeId, filter) {
                              setState(() {
                                if (filter.isEmpty) {
                                  _nodeFilters.remove(nodeId);
                                } else {
                                  _nodeFilters[nodeId] = filter;
                                }
                              });
                            },
                            onScrollChanged: (offset) {
                              final prev = _nodeScrollOffset[n.id] ?? 0.0;
                              if (prev != offset) {
                                _nodeScrollOffset[n.id] = offset;
                                setState(() {});
                              }
                            },
                            onTapInPort: (itemId) {
                              final candidates = _connections
                                  .where(
                                    (c) =>
                                        c.to.nodeId == n.id &&
                                        c.to.itemId == itemId,
                                  )
                                  .toList();
                              setState(
                                () => _selected = candidates.isNotEmpty
                                    ? candidates.last
                                    : null,
                              );
                            },
                            onTapOutPort: (itemId) {
                              final candidates = _connections
                                  .where(
                                    (c) =>
                                        c.from.nodeId == n.id &&
                                        c.from.itemId == itemId,
                                  )
                                  .toList();
                              setState(() {
                                if (candidates.length == 1) {
                                  _selected = candidates.single;
                                } else if (candidates.isNotEmpty) {
                                  _selected = candidates.last;
                                } else {
                                  _selected = null;
                                }
                              });
                            },
                            onStartWireFromItem: (itemId, startWorld) {
                              setState(() {
                                _activeDrag = _ActiveAggDrag(
                                  from: AggPort(
                                    nodeId: n.id,
                                    itemId: itemId,
                                    kind: PortKind.out,
                                  ),
                                  startWorld: startWorld,
                                  endWorld: startWorld,
                                );
                              });
                              _controller.beginDrag('wire');
                            },
                            onDragNodeTo: (nextWorldPos) =>
                                setState(() => n.position = nextWorldPos),
                            onNodeResize: (newHeight) {
                              setState(() {
                                final idx = _nodes.indexWhere(
                                  (node) => node.id == n.id,
                                );
                                if (idx != -1) {
                                  _nodes[idx] = AggNode(
                                    id: n.id,
                                    title: n.title,
                                    position: n.position,
                                    items: n.items,
                                    width: n.width,
                                    height: newHeight,
                                    inPortsSide: n.inPortsSide,
                                    outPortsSide: n.outPortsSide,
                                  );
                                }
                              });
                            },
                            portMargin: kPortMargin,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          // Removed Positioned.fill canvas DragTarget - it was blocking everything!
          // Global pointer tracker is always mounted. We only act when _activeDrag != null.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                if (_activeDrag == null && _selected != null) {
                  setState(() => _selected = null);
                }
              },
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
                  final newConn = AggConnection(
                    from: _activeDrag!.from,
                    to: hit,
                  );
                  setState(() {
                    _connections.add(newConn);
                  });
                  _graph.addConnection(newConn);
                }
                setState(() => _activeDrag = null);
                _controller.endDrag('wire');
              },
              onPointerCancel: (_) {
                if (_activeDrag == null) return;
                setState(() => _activeDrag = null);
                _controller.endDrag('wire');
              },
            ),
          ),
        ],
      ),
    );
  }

  void _handleCanvasDrop(dynamic data, Offset worldPosition) {
    if (data is _DraggedAggItem) {
      final drag = data;
      debugPrint(
        '[GRID DROP] creating new node at world position: $worldPosition',
      );
      setState(() {
        final newNodeId = 'spawn-${_spawnCounter++}';
        debugPrint('[GRID DROP] new node ID: $newNodeId');
        final node = AggNode(
          id: newNodeId,
          title: 'Misc',
          position: worldPosition,
          items: [drag.item],
          inPortsSide: PortSide.left,
          outPortsSide: PortSide.right,
        );

        // Remove from source node
        final sourceNode = _nodeById(drag.sourceNodeId);
        debugPrint(
          '[GRID DROP] removing ${drag.item.id} from source node: ${drag.sourceNodeId}',
        );
        _replaceNode(_removeItemFromNode(sourceNode, drag.item.id));

        // Add new node
        _nodes.add(node);
        debugPrint('[GRID DROP] added new node, total nodes: ${_nodes.length}');

        // Update connections
        final movedIds = _flattenItemIds(drag.item);
        _updateConnectionsOnMoveForItems(
          itemIds: movedIds,
          fromNodeId: drag.sourceNodeId,
          toNodeId: newNodeId,
        );
        _graph.build(_nodes, _connections);
      });
    }
  }

  AggPort? _hitTestInPort(Offset worldPoint) {
    const hitRadius = 16.0;
    double minDist = double.infinity;
    for (final n in _nodes) {
      if (n.inPortsSide == PortSide.none) continue;
      for (final itemId in n.flattenedIds()) {
        final scroll = _nodeScrollOffset[n.id] ?? 0.0;
        final base = n.portWorldForItem(itemId, PortKind.inPort);
        final p = base.translate(0, -scroll);
        final d = (p - worldPoint).distance;
        if (d < minDist) {
          minDist = d;
        }
        if (d <= hitRadius) {
          return AggPort(nodeId: n.id, itemId: itemId, kind: PortKind.inPort);
        }
      }
    }
    return null;
  }
}

class _ProgrammaticGestureLayer extends StatefulWidget {
  final Matrix4 transform;
  final CanvasKitController controller;
  final List<AggNode> nodes;
  final List<AggConnection> connections;
  final _ActiveAggDrag? activeDrag;
  final AggConnection? selected;
  final Map<String, double> scrollByNode;
  final Map<String, String> nodeFilters;
  final bool itemDragActive;
  final String? hoveredNodeId;
  final GlobalKey canvasKey;
  final void Function(dynamic data, Offset worldPosition)? onAcceptDrop;

  const _ProgrammaticGestureLayer({
    required this.transform,
    required this.controller,
    required this.nodes,
    required this.connections,
    this.activeDrag,
    this.selected,
    required this.scrollByNode,
    required this.nodeFilters,
    this.itemDragActive = false,
    this.hoveredNodeId,
    required this.canvasKey,
    this.onAcceptDrop,
  });

  @override
  State<_ProgrammaticGestureLayer> createState() =>
      _ProgrammaticGestureLayerState();
}

class _ProgrammaticGestureLayerState extends State<_ProgrammaticGestureLayer> {
  double? _scaleStart;
  Offset? _focalWorldAtStart;

  @override
  Widget build(BuildContext context) {
    Widget gestureLayer = Container(
      color: Colors.yellow.withValues(alpha: 0.05), // More subtle yellow to see the area
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            // Mouse wheel zoom
            final double scaleDelta = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
            final Offset screenPos = event.localPosition;
            final Offset worldBefore = widget.controller.screenToWorld(
              screenPos,
            );
            final nextScale = widget.controller.scale * scaleDelta;
            widget.controller.setScale(nextScale, focalWorld: worldBefore);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Single finger pan and pinch-to-zoom
          onScaleStart: (details) {
            if (widget.activeDrag != null) {
              return; // Don't pan/zoom during wire drag
            }
            _scaleStart = widget.controller.scale;
            _focalWorldAtStart = widget.controller.screenToWorld(
              details.localFocalPoint,
            );
          },
          onScaleUpdate: (details) {
            if (widget.activeDrag != null) {
              return; // Don't pan/zoom during wire drag
            }
            if (_scaleStart == null || _focalWorldAtStart == null) return;

            final pointerCount = details.pointerCount;

            if (pointerCount <= 1) {
              // Single finger pan
              final screenDelta = details.focalPointDelta;
              if (screenDelta != Offset.zero) {
                final worldDelta = widget.controller.deltaScreenToWorld(
                  screenDelta,
                );
                widget.controller.translateWorld(worldDelta);
              }
            } else {
              // Two-finger pinch zoom
              final nextScale = _scaleStart! * details.scale;
              widget.controller.setScale(nextScale);

              // Keep focal point under fingers
              final currentScreenOfFocal = widget.controller.worldToScreen(
                _focalWorldAtStart!,
              );
              final screenDelta =
                  details.localFocalPoint - currentScreenOfFocal;
              if (screenDelta != Offset.zero) {
                final worldDelta = widget.controller.deltaScreenToWorld(
                  screenDelta,
                );
                widget.controller.translateWorld(worldDelta);
              }
            }
          },
          onScaleEnd: (details) {
            _scaleStart = null;
            _focalWorldAtStart = null;
          },
          child: CustomPaint(
            painter: _AggWirePainter(
              transform: widget.transform,
              nodes: widget.nodes,
              connections: widget.connections,
              activeDrag: widget.activeDrag,
              selected: widget.selected,
              scrollByNode: widget.scrollByNode,
              nodeFilters: widget.nodeFilters,
            ),
          ),
        ),
      ),
    );

    // Wrap with DragTarget when item drag is active
    if (widget.itemDragActive && widget.onAcceptDrop != null) {
      return DragTarget<_DraggedAggItem>(
        onWillAcceptWithDetails: (details) {
          // Always return true initially - we'll do the real check in onAcceptWithDetails
          debugPrint(
            '[CANVAS] Preliminary willAccept check - hovering: ${widget.hoveredNodeId ?? 'empty space'}',
          );
          return true;
        },
        onAcceptWithDetails: (details) {
          // Do the real check here when state is properly cleared
          if (widget.hoveredNodeId != null) {
            debugPrint(
              '[CANVAS] Rejecting drop - still hovering ${widget.hoveredNodeId}',
            );
            return;
          }

          final data = details.data;
          debugPrint('[CANVAS] Creating new node for ${data.item.label}');
          final ctx = widget.canvasKey.currentContext;
          if (ctx != null) {
            final box = ctx.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.offset);
            final world = widget.controller.screenToWorld(local);
            widget.onAcceptDrop?.call(data, world);
          }
        },
        builder: (context, candidate, rejected) {
          final canAcceptDrop = widget.hoveredNodeId == null;
          final showGreenFeedback = widget.itemDragActive && canAcceptDrop;

          debugPrint(
            '[CANVAS] Visual feedback: ${showGreenFeedback ? 'GREEN (ready)' : 'NONE'} - hovering: ${widget.hoveredNodeId ?? 'empty space'}, candidates: ${candidate.length}',
          );

          return Container(
            decoration: BoxDecoration(
              color: showGreenFeedback ? Colors.green.withValues(alpha: 0.3) : null,
              border: showGreenFeedback
                  ? Border.all(color: Colors.green, width: 3)
                  : null,
            ),
            child: gestureLayer,
          );
        },
      );
    }

    return gestureLayer;
  }
}

class _AggWirePainter extends CustomPainter {
  final Matrix4 transform;
  final List<AggNode> nodes;
  final List<AggConnection> connections;
  final _ActiveAggDrag? activeDrag;
  final AggConnection? selected;
  final Map<String, double> scrollByNode;
  final Map<String, String> nodeFilters;

  _AggWirePainter({
    required this.transform,
    required this.nodes,
    required this.connections,
    required this.activeDrag,
    required this.selected,
    required this.scrollByNode,
    required this.nodeFilters,
  });

  Offset _worldToScreen(Offset worldPoint) {
    final v = Vector3(worldPoint.dx, worldPoint.dy, 0)..applyMatrix4(transform);
    return Offset(v.x, v.y);
  }

  // Convert a world-space vertical distance to screen-space pixels using the current transform.
  // Assumes CanvasKit applies uniform scale + translate (no shear/rotation), which holds here.
  double _screenDyForWorldDy(double worldDy) {
    final a = _worldToScreen(const Offset(0, 0)).dy;
    final b = _worldToScreen(Offset(0, worldDy)).dy;
    return (b - a).abs();
  }

  static const double _capRadius = 3.5;

  // Visible viewport edges (in screen space) for item rows within a node.
  // Top edge = header + filter + topPad; Bottom edge = height - topPad (both transformed).
  ({double topEdgeY, double bottomEdgeY}) _viewportScreenEdgesFor(AggNode n) {
    const header = 44.0 + 36.0; // header + filter box
    const topPad = 10.0;
    const bottomPad = 24.0; // extra room to fit 8px – cap – 8px inside the node
    final worldTop = Offset(0, n.position.dy + header + topPad);
    final worldBottom = Offset(0, n.position.dy + n.size.height - bottomPad);
    final top = _worldToScreen(worldTop).dy;
    final bottom = _worldToScreen(worldBottom).dy;
    // Ensure ordering top <= bottom regardless of transform direction
    return (
      topEdgeY: top < bottom ? top : bottom,
      bottomEdgeY: top < bottom ? bottom : top,
    );
  }

  // If p is above topEdge, snap to topEdge - capInset.
  // If p is below bottomEdge, snap to bottomEdge + capInset.
  // Otherwise return unchanged. Returns clamped point and whether it was clamped.
  (Offset, bool) _capClampY(
    Offset p,
    double topEdge,
    double bottomEdge,
    double capInset,
  ) {
    if (p.dy < topEdge) return (Offset(p.dx, topEdge - capInset), true);
    if (p.dy > bottomEdge) return (Offset(p.dx, bottomEdge + capInset), true);
    return (p, false);
  }

  // Helper to check if an item is visible based on node filter
  bool _isItemVisible(String nodeId, String itemId) {
    final filter = nodeFilters[nodeId]?.toLowerCase().trim();
    if (filter == null || filter.isEmpty) {
      return true;
    }

    final node = nodes.firstWhere((n) => n.id == nodeId);
    for (final item in node.items) {
      if (item.id == itemId) {
        return item.label.toLowerCase().contains(filter) ||
            item.id.toLowerCase().contains(filter);
      }
      for (final child in item.children) {
        if (child.id == itemId) {
          return child.label.toLowerCase().contains(filter) ||
              child.id.toLowerCase().contains(filter);
        }
      }
    }
    return false;
  }

  // Get the filtered/visible row index for an item in a node
  int _getVisibleRowIndex(String nodeId, String itemId) {
    final node = nodes.firstWhere((n) => n.id == nodeId);
    final filter = nodeFilters[nodeId]?.toLowerCase().trim();

    // Build the same filtered list as the widget
    final allRows = <({String itemId, int level})>[];
    for (final item in node.items) {
      allRows.add((itemId: item.id, level: 0));
      for (final child in item.children) {
        allRows.add((itemId: child.id, level: 1));
      }
    }

    final visibleRows = filter == null || filter.isEmpty
        ? allRows
        : allRows.where((row) {
            final item = _findItemById(node, row.itemId);
            if (item == null) return false;
            return item.label.toLowerCase().contains(filter) ||
                item.id.toLowerCase().contains(filter);
          }).toList();

    // Find the index in the visible list
    for (int i = 0; i < visibleRows.length; i++) {
      if (visibleRows[i].itemId == itemId) {
        return i;
      }
    }
    return 0; // fallback
  }

  // Helper to find an item by ID in a node
  AggItem? _findItemById(AggNode node, String itemId) {
    for (final item in node.items) {
      if (item.id == itemId) return item;
      for (final child in item.children) {
        if (child.id == itemId) return child;
      }
    }
    return null;
  }

  // Calculate the correct Y position for a filtered item
  double _getFilteredItemY(String nodeId, String itemId) {
    final node = nodes.firstWhere((n) => n.id == nodeId);
    const header = 44.0 + 36.0; // header + filter box
    const topPad = 10.0;
    const rowH = 36.0;

    final visibleIndex = _getVisibleRowIndex(nodeId, itemId);
    return node.position.dy + header + topPad + rowH * (visibleIndex + 0.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final halo = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5);
    // base wire paint defined per-connection below to vary stroke on selection

    for (final c in connections) {
      final fromNode = nodes.firstWhere((n) => n.id == c.from.nodeId);
      final toNode = nodes.firstWhere((n) => n.id == c.to.nodeId);
      // If either endpoint refers to an item that no longer exists in that node, skip drawing this connection.
      if (!fromNode.flattenedIds().contains(c.from.itemId) ||
          !toNode.flattenedIds().contains(c.to.itemId)) {
        continue;
      }
      // Skip drawing if either endpoint is filtered out
      if (!_isItemVisible(c.from.nodeId, c.from.itemId) ||
          !_isItemVisible(c.to.nodeId, c.to.itemId)) {
        continue;
      }
      // Use filtered positions instead of original positions
      final fromY = _getFilteredItemY(c.from.nodeId, c.from.itemId);
      final toY = _getFilteredItemY(c.to.nodeId, c.to.itemId);
      final fromBase = Offset(
        c.from.kind == PortKind.out
            ? fromNode.position.dx +
                  fromNode.size.width +
                  12.0 // right side + margin
            : fromNode.position.dx + 12.0, // left side + margin
        fromY,
      );
      final toBase = Offset(
        c.to.kind == PortKind.inPort
            ? toNode.position.dx +
                  12.0 // left side + margin
            : toNode.position.dx +
                  toNode.size.width +
                  12.0, // right side + margin
        toY,
      );
      final fromScroll = scrollByNode[fromNode.id] ?? 0.0;
      final toScroll = scrollByNode[toNode.id] ?? 0.0;
      final p0raw = _worldToScreen(fromBase.translate(0, -fromScroll));
      final p1raw = _worldToScreen(toBase.translate(0, -toScroll));
      // Clamp offscreen endpoints into the reserved vertical band outside item rows.
      // Place cap center at: 8px (air) + capRadius + 8px (air) away from the band, in screen space.
      final capInset = _screenDyForWorldDy(8.0) + _capRadius + 8.0;
      final edgesFrom = _viewportScreenEdgesFor(fromNode);
      final edgesTo = _viewportScreenEdgesFor(toNode);
      final (p0, clamped0) = _capClampY(
        p0raw,
        edgesFrom.topEdgeY,
        edgesFrom.bottomEdgeY,
        capInset,
      );
      final (p1, clamped1) = _capClampY(
        p1raw,
        edgesTo.topEdgeY,
        edgesTo.bottomEdgeY,
        capInset,
      );

      // --- Viewport culling -------------------------------------------------
      // If both endpoints are outside their respective node item viewports,
      // and the curve does not intersect the screen, skip drawing this wire.
      final bool endpoint0Visible =
          (p0raw.dy >= edgesFrom.topEdgeY && p0raw.dy <= edgesFrom.bottomEdgeY);
      final bool endpoint1Visible =
          (p1raw.dy >= edgesTo.topEdgeY && p1raw.dy <= edgesTo.bottomEdgeY);
      if (!endpoint0Visible && !endpoint1Visible) {
        // Compute an approximate bezier bounds using control points like _drawWire does.
        final dx = (p1.dx - p0.dx).abs();
        final c1 = p0 + Offset(dx * 0.4, 0);
        final c2 = p1 - Offset(dx * 0.4, 0);
        final double minX = [
          p0.dx,
          p1.dx,
          c1.dx,
          c2.dx,
        ].reduce((a, b) => a < b ? a : b);
        final double maxX = [
          p0.dx,
          p1.dx,
          c1.dx,
          c2.dx,
        ].reduce((a, b) => a > b ? a : b);
        final double minY = [
          p0.dy,
          p1.dy,
          c1.dy,
          c2.dy,
        ].reduce((a, b) => a < b ? a : b);
        final double maxY = [
          p0.dy,
          p1.dy,
          c1.dy,
          c2.dy,
        ].reduce((a, b) => a > b ? a : b);
        final Rect bezierBounds = Rect.fromLTRB(
          minX,
          minY,
          maxX,
          maxY,
        ).inflate(8);
        final Rect screenRect =
            Offset.zero & size; // canvas size is the painter Size
        if (!bezierBounds.overlaps(screenRect)) {
          continue; // fully offscreen and endpoints not visible -> skip
        }
      }
      final color = _colorForConnection(c);
      final isSel = selected != null && _sameConn(c, selected!);
      final selHalo = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 9.0 : 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 1.5);
      final wire = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSel ? 5.0 : 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawWire(canvas, p0, p1, selHalo);
      _drawWire(canvas, p0, p1, wire);
      // Offscreen caps to hint continuation
      final capFill = Paint()..color = color.withValues(alpha: 0.9);
      final capStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      if (clamped0) {
        canvas.drawCircle(p0, _capRadius, capFill);
        canvas.drawCircle(p0, _capRadius, capStroke);
      }
      if (clamped1) {
        canvas.drawCircle(p1, _capRadius, capFill);
        canvas.drawCircle(p1, _capRadius, capStroke);
      }
    }

    if (activeDrag != null) {
      final fromNode = nodes.firstWhere((n) => n.id == activeDrag!.from.nodeId);
      // Use filtered position for active drag too
      final fromY = _getFilteredItemY(
        activeDrag!.from.nodeId,
        activeDrag!.from.itemId,
      );
      final fromBase = Offset(
        fromNode.position.dx +
            fromNode.size.width +
            12.0, // right side + margin
        fromY,
      );
      final fromScroll = scrollByNode[fromNode.id] ?? 0.0;
      final p0raw = _worldToScreen(fromBase.translate(0, -fromScroll));
      final edgesFrom = _viewportScreenEdgesFor(fromNode);
      final capInset = _screenDyForWorldDy(8.0) + _capRadius + 8.0;
      final (p0, _) = _capClampY(
        p0raw,
        edgesFrom.topEdgeY,
        edgesFrom.bottomEdgeY,
        capInset,
      );
      final p1 = _worldToScreen(activeDrag!.endWorld);
      final dragHalo = halo..color = Colors.white;
      final dragColor = _colorForFromPort(activeDrag!.from);
      final dragPaint = Paint()
        ..color = dragColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      _drawWire(canvas, p0, p1, dragHalo);
      _drawWire(canvas, p0, p1, dragPaint);
      // Endpoint indicator for visibility
      final endDotFill = Paint()..color = Colors.blueAccent;
      final endDotStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(p1, 4.5, endDotFill);
      canvas.drawCircle(p1, 4.5, endDotStroke);
    }
  }

  void _drawWire(Canvas canvas, Offset p0, Offset p1, Paint paint) {
    final dx = (p1.dx - p0.dx).abs();
    final c1 = p0 + Offset(dx * 0.4, 0);
    final c2 = p1 - Offset(dx * 0.4, 0);
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p1.dx, p1.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AggWirePainter oldDelegate) {
    return oldDelegate.transform != transform ||
        oldDelegate.nodes != nodes ||
        oldDelegate.connections != connections ||
        oldDelegate.activeDrag != activeDrag ||
        oldDelegate.selected != selected ||
        !_mapEqualsDouble(oldDelegate.scrollByNode, scrollByNode) ||
        !_mapEqualsString(oldDelegate.nodeFilters, nodeFilters);
  }

  // --- Color engine (lives inside painter; uses provided nodes) ------------
  static const String _usersId = 'users';
  static const String _securityPoliciesId = 'security_policies';

  static const List<Color> _palette = <Color>[
    Color(0xFF1976D2), // blue 700
    Color(0xFF388E3C), // green 700
    Color(0xFFF57C00), // orange 700
    Color(0xFFD32F2F), // red 700
    Color(0xFF7B1FA2), // purple 700
    Color(0xFF00796B), // teal 700
    Color(0xFF455A64), // blueGrey 700
    Color(0xFF5D4037), // brown 700
  ];

  Color _colorForConnection(AggConnection c) => _colorForFromPort(c.from);

  Color _colorForFromPort(AggPort from) {
    if (from.nodeId == _usersId) return _colorForUserItem(from.itemId);
    if (from.nodeId == _securityPoliciesId) {
      return _colorForPolicyItem(from.itemId);
    }
    return Colors.blueGrey.shade700;
  }

  Color _colorForUserItem(String itemId) {
    // Derive the user root (e.g., 'u:alice.smith') and color all of that user's rows the same.
    final parts = itemId.split(':');
    final userRoot = parts.length >= 2 ? '${parts[0]}:${parts[1]}' : itemId;
    final users = nodes.firstWhere((n) => n.id == _usersId);
    // Index color by top-level user order
    final topLevelUsers = users.items
        .map((it) => it.id)
        .toList(growable: false);
    final idx = topLevelUsers.indexOf(userRoot);
    final i = (idx >= 0 ? idx : 0) % _palette.length;
    return _palette[i];
  }

  Color _colorForPolicyItem(String itemId) {
    final policies = nodes.firstWhere((n) => n.id == _securityPoliciesId);
    final ids = policies.flattenedIds();
    final idx = ids.indexOf(itemId);
    final i = (idx >= 0 ? idx : 0) % _palette.length;
    return _palette[i];
  }

  bool _sameConn(AggConnection a, AggConnection b) {
    return a.from.nodeId == b.from.nodeId &&
        a.from.itemId == b.from.itemId &&
        a.to.nodeId == b.to.nodeId &&
        a.to.itemId == b.to.itemId;
  }

  static bool _mapEqualsDouble(Map<String, double> a, Map<String, double> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final bv = b[e.key];
      if (bv == null) return false;
      if (bv != e.value) return false;
    }
    return true;
  }

  static bool _mapEqualsString(Map<String, String> a, Map<String, String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      final bv = b[e.key];
      if (bv == null) return false;
      if (bv != e.value) return false;
    }
    return true;
  }
}

class _AggregatedNodeWidget extends StatefulWidget {
  const _AggregatedNodeWidget({
    super.key,
    required this.node,
    required this.portMargin,
    required this.itemDropMode,
    this.onScrollChanged,
    this.onItemDragActiveChanged,
    this.portKeyForItem,
    this.onTapInPort,
    this.onTapOutPort,
    this.onStartWireFromItem,
    this.onDragNodeTo,
    this.onFilterChanged,
    this.nodeFilter,
    this.onNodeResize,
  });

  final AggNode node;
  final double portMargin;
  final bool itemDropMode;
  final String? nodeFilter;

  // Optional callbacks/properties used by the implementation
  final void Function(double offset)? onScrollChanged;
  final void Function(bool active)? onItemDragActiveChanged;
  final GlobalKey Function(String itemId)? portKeyForItem;
  final void Function(String itemId)? onTapInPort;
  final void Function(String itemId)? onTapOutPort;
  final void Function(String itemId, Offset startWorld)? onStartWireFromItem;
  final void Function(Offset nextWorldPos)? onDragNodeTo;
  final void Function(String nodeId, String filter)? onFilterChanged;
  final void Function(double newHeight)? onNodeResize;

  @override
  State<_AggregatedNodeWidget> createState() => _AggregatedNodeWidgetState();
}

class _AggregatedNodeWidgetState extends State<_AggregatedNodeWidget> {
  late Offset _dragStartWorld;
  Offset? _lastGlobalPos;
  late final ScrollController _scrollController;
  late final TextEditingController _filterController;
  double _currentScrollOffset() =>
      _scrollController.hasClients ? _scrollController.offset : 0.0;

  // Resize tracking
  double? _resizeStartHeight;
  Offset? _resizeStartGlobalPos;

  @override
  void initState() {
    super.initState();
    _dragStartWorld = widget.node.position;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _filterController = TextEditingController(text: widget.nodeFilter ?? '');
  }

  @override
  void didUpdateWidget(covariant _AggregatedNodeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.position != widget.node.position) {
      _dragStartWorld = widget.node.position;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _onScroll() {
    widget.onScrollChanged?.call(_scrollController.offset);
  }

  @override
  Widget build(BuildContext context) {
    final scope = CanvasKitScope.of(context);

    // Build flattened rows with indent level and apply filtering
    final allRows = <({AggItem item, int level})>[];
    for (final it in widget.node.items) {
      allRows.add((item: it, level: 0));
      for (final ch in it.children) {
        allRows.add((item: ch, level: 1));
      }
    }

    // Apply filter if present
    final filter = widget.nodeFilter?.toLowerCase().trim();
    final rows = filter == null || filter.isEmpty
        ? allRows
        : allRows
              .where(
                (row) =>
                    row.item.label.toLowerCase().contains(filter) ||
                    row.item.id.toLowerCase().contains(filter),
              )
              .toList();

    final box = GestureDetector(
      behavior:
          HitTestBehavior.deferToChild, // let port detectors win when touched
      onPanStart: (details) {
        _dragStartWorld = widget.node.position;
        _lastGlobalPos = details.globalPosition;
        scope.controller.beginDrag('node-${widget.node.id}');
      },
      onPanUpdate: (details) {
        final prev = _lastGlobalPos ?? details.globalPosition;
        final screenDelta = details.globalPosition - prev;
        _lastGlobalPos = details.globalPosition;

        final before = _dragStartWorld;
        final worldDelta = scope.controller.deltaScreenToWorld(screenDelta);
        final after = before + worldDelta;
        _dragStartWorld = after;
        widget.onDragNodeTo?.call(after);
      },
      onPanEnd: (_) {
        scope.controller.endDrag('node-${widget.node.id}');
        _lastGlobalPos = null;
      },
      onPanCancel: () {
        scope.controller.endDrag('node-${widget.node.id}');
        _lastGlobalPos = null;
      },
      child: SizedBox(
        width: widget.node.size.width + 2 * widget.portMargin,
        height: widget.node.size.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Node body shifted right by port margin so left margin is free for in-ports
            Positioned(
              left: widget.portMargin,
              top: 0,
              width: widget.node.size.width,
              height: widget.node.size.height,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black26, width: 1),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),  
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.04),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.node.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          // Removed complex drop indicator
                        ],
                      ),
                    ),
                    // Filter input box
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.black.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _filterController,
                        decoration: InputDecoration(
                          hintText: 'Filter items...',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          isDense: true,
                          prefixIcon: Icon(
                            Icons.search,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          suffixIcon: widget.nodeFilter?.isNotEmpty == true
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  onPressed: () {
                                    _filterController.clear();
                                    widget.onFilterChanged?.call(
                                      widget.node.id,
                                      '',
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                )
                              : null,
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (value) {
                          widget.onFilterChanged?.call(widget.node.id, value);
                        },
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        // Inset horizontally so the scrollbar doesn't sit under ports
                        padding: const EdgeInsets.only(right: 18),
                        child: Padding(
                          // Inset vertically for content (asymmetric): 10 top, 24 bottom
                          padding: const EdgeInsets.only(top: 10, bottom: 24),
                          child: Scrollbar(
                            controller: _scrollController,
                            child: ListView.builder(
                              controller: _scrollController,
                              // No vertical padding here; handled by the outer Padding above
                              padding: EdgeInsets.zero,
                              itemCount: rows.length,
                              itemBuilder: (context, i) {
                                final row = rows[i];
                                final item = row.item;
                                final indent = row.level == 1 ? 16.0 : 0.0;
                                final textStyle = TextStyle(
                                  fontSize: 12,
                                  fontWeight: row.level == 0 && item.hasChildren
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                );

                                Widget rowChild = Container(
                                  height: 36,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: Colors.black.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 12 + indent,
                                      right: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        // Small drag handle to start a drag immediately (desktop-friendly)
                                        Draggable<_DraggedAggItem>(
                                          data: _DraggedAggItem(
                                            item: item,
                                            sourceNodeId: widget.node.id,
                                          ),
                                          onDragStarted: () {
                                            widget.onItemDragActiveChanged
                                                ?.call(true);
                                            debugPrint(
                                              '[DRAG ITEM] start item=${item.id}',
                                            );
                                          },
                                          onDragEnd: (details) {
                                            widget.onItemDragActiveChanged
                                                ?.call(false);
                                            debugPrint(
                                              '[DRAG ITEM] end item=${item.id} wasAccepted=${details.wasAccepted}',
                                            );
                                          },
                                          feedback: Material(
                                            color: Colors.transparent,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(2, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                item.label,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: const SizedBox(
                                            width: 40,
                                            child: Opacity(
                                              opacity: 0.2,
                                              child: Icon(
                                                Icons.drag_indicator,
                                                size: 24,
                                                color: Colors.black38,
                                              ),
                                            ),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 8),
                                            child: SizedBox(
                                              width: 40,
                                              child: Icon(
                                                Icons.drag_indicator,
                                                size: 24,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              item.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textStyle,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                                // Allow long-press dragging anywhere on the row (mobile-friendly)
                                return LongPressDraggable<_DraggedAggItem>(
                                  data: _DraggedAggItem(
                                    item: item,
                                    sourceNodeId: widget.node.id,
                                  ),
                                  dragAnchorStrategy: pointerDragAnchorStrategy,
                                  onDragStarted: () {
                                    widget.onItemDragActiveChanged?.call(true);
                                    debugPrint(
                                      '[DRAG ITEM] start (long-press) item=${item.id}',
                                    );
                                  },
                                  onDragEnd: (details) {
                                    widget.onItemDragActiveChanged?.call(false);
                                    debugPrint(
                                      '[DRAG ITEM] end (long-press) item=${item.id} wasAccepted=${details.wasAccepted}',
                                    );
                                  },
                                  feedback: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.2),
                                            blurRadius: 6,
                                            offset: Offset(2, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        item.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.35,
                                    child: rowChild,
                                  ),
                                  child: rowChild,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Ports, visually clipped to the list viewport area. Disabled during item drop mode.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: widget.itemDropMode,
                child: ClipRect(
                  clipper: _PortViewportClipper(
                    header: 44.0 + 36.0,
                    topPad: 10.0,
                    bottomPad: 24.0,
                  ), // header + filter box
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (widget.node.inPortsSide == PortSide.left) ...[
                        for (final id in widget.node.flattenedIds())
                          Positioned(
                            left:
                                widget.portMargin -
                                12, // center at x=portMargin
                            top:
                                _rowCenterYFor(id) -
                                12 -
                                _currentScrollOffset(),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.onTapInPort?.call(id),
                                child: const Center(
                                  child: _PortDot(color: Colors.redAccent),
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (widget.node.outPortsSide == PortSide.right) ...[
                        for (final id in widget.node.flattenedIds())
                          Positioned(
                            right:
                                widget.portMargin -
                                12, // center at x=width+portMargin
                            top:
                                _rowCenterYFor(id) -
                                12 -
                                _currentScrollOffset(),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: (_) {
                                  final startWorld = widget.node
                                      .portWorldForItem(id, PortKind.out);
                                  widget.onStartWireFromItem?.call(
                                    id,
                                    startWorld,
                                  );
                                },
                                onTap: () => widget.onTapOutPort?.call(id),
                                child: Center(
                                  child: Container(
                                    key: widget.portKeyForItem?.call(id),
                                    width: 12,
                                    height: 12,
                                    alignment: Alignment.center,
                                    child: const _PortDot(color: Colors.green),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Resize handle at the bottom
            Positioned(
              left: widget.portMargin,
              bottom: -4,
              width: widget.node.size.width,
              height: 8,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) {
                  _resizeStartHeight = widget.node.size.height;
                  _resizeStartGlobalPos = details.globalPosition;
                  scope.controller.beginDrag('resize-${widget.node.id}');
                },
                onPanUpdate: (details) {
                  final startPos =
                      _resizeStartGlobalPos ?? details.globalPosition;
                  final screenDelta = details.globalPosition - startPos;

                  // Convert total screen delta to world delta, we only care about Y
                  final worldDelta = scope.controller.deltaScreenToWorld(
                    screenDelta,
                  );
                  final startHeight =
                      _resizeStartHeight ?? widget.node.size.height;
                  final newHeight = (startHeight + worldDelta.dy).clamp(
                    150.0,
                    1000.0,
                  );
                  widget.onNodeResize?.call(newHeight);
                },
                onPanEnd: (_) {
                  scope.controller.endDrag('resize-${widget.node.id}');
                  _resizeStartGlobalPos = null;
                  _resizeStartHeight = null;
                },
                onPanCancel: () {
                  scope.controller.endDrag('resize-${widget.node.id}');
                  _resizeStartGlobalPos = null;
                  _resizeStartHeight = null;
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeUpDown,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.drag_handle,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Removed complex drop overlay - now handled by outer DragTarget
          ],
        ),
      ),
    );
    return box;
  }

  // Local helper to compute row center Y relative to the outer stack
  double _rowCenterYFor(String itemId) {
    final header = 44.0 + 36.0; // header + filter box
    final rowH = 36.0;
    const topPad = 10.0; // must match model AggNode._rowCenterY topPad

    // Get filtered rows to compute correct positions
    final allRows = <({AggItem item, int level})>[];
    for (final it in widget.node.items) {
      allRows.add((item: it, level: 0));
      for (final ch in it.children) {
        allRows.add((item: ch, level: 1));
      }
    }

    final filter = widget.nodeFilter?.toLowerCase().trim();
    final visibleRows = filter == null || filter.isEmpty
        ? allRows
        : allRows
              .where(
                (row) =>
                    row.item.label.toLowerCase().contains(filter) ||
                    row.item.id.toLowerCase().contains(filter),
              )
              .toList();

    final visibleIds = visibleRows.map((row) => row.item.id).toList();
    final idx = visibleIds.indexOf(itemId);
    final safeIdx = idx < 0 ? 0 : idx;
    return header + topPad + rowH * (safeIdx + 0.5);
  }
}

class _PortDot extends StatelessWidget {
  final Color color;
  const _PortDot({required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    );
  }
}

class _PortViewportClipper extends CustomClipper<Rect> {
  final double header;
  final double topPad;
  final double bottomPad;
  const _PortViewportClipper({
    required this.header,
    required this.topPad,
    required this.bottomPad,
  });

  @override
  Rect getClip(Size size) {
    final double top = header + topPad;
    final double height = (size.height - header - topPad - bottomPad).clamp(
      0.0,
      size.height,
    );
    return Rect.fromLTWH(0, top, size.width, height);
  }

  @override
  bool shouldReclip(covariant _PortViewportClipper oldClipper) {
    return oldClipper.header != header ||
        oldClipper.topPad != topPad ||
        oldClipper.bottomPad != bottomPad;
  }
}

// Payload for dragging an aggregated item between nodes
class _DraggedAggItem {
  final AggItem item;
  final String sourceNodeId;
  const _DraggedAggItem({required this.item, required this.sourceNodeId});
}

class _ActiveAggDrag {
  final AggPort from; // out-port
  final Offset startWorld;
  final Offset endWorld;
  const _ActiveAggDrag({
    required this.from,
    required this.startWorld,
    required this.endWorld,
  });
  _ActiveAggDrag copyWith({Offset? endWorld}) => _ActiveAggDrag(
    from: from,
    startWorld: startWorld,
    endWorld: endWorld ?? this.endWorld,
  );
}
