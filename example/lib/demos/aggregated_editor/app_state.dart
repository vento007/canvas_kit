import 'package:flutter/foundation.dart';
import 'aggregated_models.dart';
import 'demo_data.dart';
import 'graph_service.dart';
import 'filter_state.dart';

/// Professional reactive state management for the aggregated editor
class AppState extends ChangeNotifier {
  // Raw data (immutable)
  final List<AggNode> _rawNodes = DemoData.allNodes;
  final List<AggConnection> _rawConnections = <AggConnection>[];
  final GraphService _graph = GraphService();
  
  // Filtering state
  final FilterState _filterState = FilterState();
  
  // Computed/derived data (reactive)
  Map<String, List<String>>? _cachedVisibleItems;
  
  AppState() {
    _rawConnections.addAll(DemoData.demoConnections);
    _graph.build(_rawNodes, _rawConnections);
    _invalidateCache();
  }
  
  // Read-only access to raw data
  List<AggNode> get nodes => _rawNodes;
  List<AggConnection> get connections => _rawConnections;
  GraphService get graph => _graph;
  
  // Read-only access to filters
  Map<String, String> get textFilters => _filterState.textFilters;
  Map<String, bool> get connectedOnlyFilters => _filterState.connectedOnlyFilters;
  bool get downstreamFilterEnabled => _filterState.downstreamFilterEnabled;
  
  // Main computed property - visible items for each node (cached & reactive)
  Map<String, List<String>> get visibleItemsByNode {
    if (_cachedVisibleItems == null) {
      _cachedVisibleItems = {};
      for (final node in _rawNodes) {
        _cachedVisibleItems![node.id] = _filterState.getVisibleItems(
          node.id, node, _rawNodes, _rawConnections, _graph
        );
      }
    }
    return _cachedVisibleItems!;
  }
  
  // Get visible items for specific node
  List<String> getVisibleItems(String nodeId) {
    return visibleItemsByNode[nodeId] ?? [];
  }
  
  // Filter mutation methods (invalidate cache + notify)
  void setTextFilter(String nodeId, String text) {
    _filterState.setTextFilter(nodeId, text);
    _invalidateCache();
    notifyListeners();
  }
  
  void setConnectedOnlyFilter(String nodeId, bool enabled) {
    _filterState.setConnectedOnly(nodeId, enabled);
    _invalidateCache();
    notifyListeners();
  }
  
  void setDownstreamFilter(bool enabled) {
    _filterState.setDownstreamFilter(enabled);
    _invalidateCache();
    notifyListeners();
  }
  
  void clearFilters() {
    _filterState.clear();
    _invalidateCache();
    notifyListeners();
  }
  
  // Connection mutations
  void addConnection(AggConnection connection) {
    _rawConnections.add(connection);
    _graph.addConnection(connection);
    _invalidateCache();
    notifyListeners();
  }
  
  void removeConnection(AggConnection connection) {
    _rawConnections.removeWhere((c) => 
      c.from.nodeId == connection.from.nodeId &&
      c.from.itemId == connection.from.itemId &&
      c.to.nodeId == connection.to.nodeId &&
      c.to.itemId == connection.to.itemId
    );
    _graph.removeConnection(connection);
    _invalidateCache();
    notifyListeners();
  }
  
  void _invalidateCache() {
    _cachedVisibleItems = null;
  }
}