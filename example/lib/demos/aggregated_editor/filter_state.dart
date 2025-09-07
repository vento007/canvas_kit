import 'aggregated_models.dart';
import 'graph_service.dart';

/// Clean filtering system - each filter removes items from candidates
class FilterState {
  // All filters in one place
  final Map<String, String> textFilters = {};
  final Map<String, bool> connectedOnlyFilters = {};
  bool downstreamFilterEnabled = false;
  
  /// Main method - applies all filters in sequence (each removes items)
  List<String> getVisibleItems(String nodeId, AggNode node, List<AggNode> allNodes, List<AggConnection> connections, GraphService graph) {
    Set<String> candidates = node.flattenedIds().toSet();
    
    // Filter 1: Text filter (removes non-matching items)
    candidates = _applyTextFilter(candidates, nodeId, node);
    
    // Filter 2: Connected-only filter (removes items without connections)
    candidates = _applyConnectedOnlyFilter(candidates, nodeId, connections);
    
    // Filter 3: Downstream filter (removes items not reachable from visible items)
    if (downstreamFilterEnabled) {
      candidates = _applyDownstreamFilter(candidates, nodeId, allNodes, connections, graph);
    }
    
    return candidates.toList();
  }
  
  /// Remove items that don't match text filter
  Set<String> _applyTextFilter(Set<String> candidates, String nodeId, AggNode node) {
    final textFilter = textFilters[nodeId]?.toLowerCase().trim();
    if (textFilter == null || textFilter.isEmpty) {
      return candidates; // No text filter, keep all candidates
    }
    
    return candidates.where((itemId) {
      // Find the item in the node structure
      for (final item in node.items) {
        if (item.id == itemId) {
          return item.label.toLowerCase().contains(textFilter) ||
                 item.id.toLowerCase().contains(textFilter);
        }
        for (final child in item.children) {
          if (child.id == itemId) {
            return child.label.toLowerCase().contains(textFilter) ||
                   child.id.toLowerCase().contains(textFilter);
          }
        }
      }
      return false;
    }).toSet();
  }
  
  /// Remove items that have no connections
  Set<String> _applyConnectedOnlyFilter(Set<String> candidates, String nodeId, List<AggConnection> connections) {
    final connectedOnlyMode = connectedOnlyFilters[nodeId] ?? false;
    if (!connectedOnlyMode) {
      return candidates; // No connected-only filter, keep all candidates
    }
    
    return candidates.where((itemId) {
      // Check if item has any connections
      for (final conn in connections) {
        if ((conn.from.nodeId == nodeId && conn.from.itemId == itemId) ||
            (conn.to.nodeId == nodeId && conn.to.itemId == itemId)) {
          return true;
        }
      }
      return false;
    }).toSet();
  }
  
  /// Remove items not reachable from currently visible items across all nodes
  Set<String> _applyDownstreamFilter(Set<String> candidates, String nodeId, List<AggNode> allNodes, List<AggConnection> connections, GraphService graph) {
    // Get all currently visible items (before downstream filter) from ALL nodes
    final allVisibleVertices = <String>[];
    
    for (final node in allNodes) {
      Set<String> nodeCandidates = node.flattenedIds().toSet();
      nodeCandidates = _applyTextFilter(nodeCandidates, node.id, node);
      nodeCandidates = _applyConnectedOnlyFilter(nodeCandidates, node.id, connections);
      
      // Convert to graph vertices
      for (final itemId in nodeCandidates) {
        allVisibleVertices.add('${node.id}:$itemId');
      }
    }
    
    // Use graph to find all reachable items
    final reachableVertices = graph.reachableFrom(allVisibleVertices);
    
    // Convert back to item IDs for this node
    final reachableItemIds = <String>{};
    for (final vertex in reachableVertices) {
      final parts = vertex.split(':');
      if (parts.length >= 2 && parts[0] == nodeId) {
        final itemId = parts.sublist(1).join(':');
        reachableItemIds.add(itemId);
      }
    }
    
    // Only keep candidates that are reachable
    return candidates.intersection(reachableItemIds);
  }
  
  // Update methods
  void setTextFilter(String nodeId, String text) {
    if (text.isEmpty) {
      textFilters.remove(nodeId);
    } else {
      textFilters[nodeId] = text;
    }
  }
  
  void setConnectedOnly(String nodeId, bool enabled) {
    if (enabled) {
      connectedOnlyFilters[nodeId] = enabled;
    } else {
      connectedOnlyFilters.remove(nodeId);
    }
  }
  
  void setDownstreamFilter(bool enabled) {
    downstreamFilterEnabled = enabled;
  }
  
  void clear() {
    textFilters.clear();
    connectedOnlyFilters.clear();
    downstreamFilterEnabled = false;
  }
}