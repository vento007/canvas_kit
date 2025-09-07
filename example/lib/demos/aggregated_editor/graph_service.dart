import 'package:directed_graph/directed_graph.dart';
import 'package:flutter/foundation.dart';

import 'aggregated_models.dart';

/// Holds connectivity for the aggregated editor.
/// - Vertex key format: `${nodeId}:${itemId}` (row identity)
/// - Edges: from out-port item -> in-port item
class GraphService {
  /// Current graph instance; rebuilt from [_adj] on each mutation.
  DirectedGraph<String> graph = DirectedGraph<String>({});

  /// Internal adjacency representation we control.
  final Map<String, Set<String>> _adj = <String, Set<String>>{};

  /// Optional metadata for vertices (types/attributes for validation & filtering)
  final Map<String, VertexMeta> vertexMeta = {};

  static String vertexId(String nodeId, String itemId) => '$nodeId:$itemId';

  /// Rebuild the graph from nodes and connections.
  void build(List<AggNode> nodes, List<AggConnection> connections, {Map<String, VertexMeta>? meta}) {
    vertexMeta
      ..clear()
      ..addAll(meta ?? _buildDefaultMeta(nodes));

    _adj.clear();

    void ensureVertex(String v) {
      _adj.putIfAbsent(v, () => <String>{});
    }

    // Ensure all visible rows exist as vertices (even if orphaned)
    for (final n in nodes) {
      for (final id in n.flattenedIds()) {
        ensureVertex(vertexId(n.id, id));
      }
    }

    // Apply connections
    for (final c in connections) {
      final u = vertexId(c.from.nodeId, c.from.itemId);
      final v = vertexId(c.to.nodeId, c.to.itemId);
      ensureVertex(u);
      ensureVertex(v);
      _adj[u]!.add(v);
    }

    _rebuild();
  }

  void addConnection(AggConnection c) {
    final u = vertexId(c.from.nodeId, c.from.itemId);
    final v = vertexId(c.to.nodeId, c.to.itemId);
    _adj.putIfAbsent(u, () => <String>{});
    _adj.putIfAbsent(v, () => <String>{});
    _adj[u]!.add(v);
    _rebuild();
  }

  void removeConnection(AggConnection c) {
    final u = vertexId(c.from.nodeId, c.from.itemId);
    final v = vertexId(c.to.nodeId, c.to.itemId);
    final out = _adj[u];
    if (out != null) {
      out.remove(v);
      _rebuild();
    }
  }

  bool edgeExists(AggConnection c) {
    final u = vertexId(c.from.nodeId, c.from.itemId);
    final v = vertexId(c.to.nodeId, c.to.itemId);
    final out = _adj[u];
    return out != null && out.contains(v);
  }

  void _rebuild() {
    graph = DirectedGraph<String>({
      for (final entry in _adj.entries) entry.key: Set<String>.from(entry.value),
    });
  }

  /// Return all vertices reachable from any of [starts] following outgoing edges.
  /// The returned set includes the starting vertices.
  Set<String> reachableFrom(Iterable<String> starts) {
    final visited = <String>{};
    final queue = <String>[];
    for (final s in starts) {
      if (s.isEmpty) continue;
      if (visited.add(s)) queue.add(s);
    }
    while (queue.isNotEmpty) {
      final u = queue.removeAt(0);
      final outs = _adj[u];
      if (outs == null) continue;
      for (final v in outs) {
        if (visited.add(v)) queue.add(v);
      }
    }
    return visited;
  }

  Map<String, VertexMeta> _buildDefaultMeta(List<AggNode> nodes) {
    final map = <String, VertexMeta>{};
    for (final n in nodes) {
      for (final id in n.flattenedIds()) {
        map[vertexId(n.id, id)] = const VertexMeta();
      }
    }
    return map;
  }
}

/// Basic vertex metadata; extend later with kind/type, tags, etc.
@immutable
class VertexMeta {
  final String? kind; // e.g., 'client', 'device', 'policy', 'asset'
  const VertexMeta({this.kind});
}
