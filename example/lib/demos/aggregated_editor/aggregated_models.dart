import 'package:flutter/material.dart';

/// Public model types for the Aggregated Node Editor demo.
/// Separated from UI code for clarity and reuse.

enum PortSide { none, left, right }
enum PortKind { inPort, out }

class AggItem {
  final String id;
  final String label;
  final List<AggItem> children;
  const AggItem({required this.id, required this.label, this.children = const []});
  bool get hasChildren => children.isNotEmpty;
}

class AggNode {
  final String id;
  final String title;
  Offset position;
  final List<AggItem> items;
  final double width;
  final double? height; // optional fixed height override
  final PortSide inPortsSide;
  final PortSide outPortsSide;

  AggNode({
    required this.id,
    required this.title,
    required this.position,
    required this.items,
    this.width = 280,
    this.height,
    required this.inPortsSide,
    required this.outPortsSide,
  });

  Size get size {
    // Match the node widget's internal paddings so at least one row is fully visible.
    // Header: 44, Filter: 36, Top padding: 10, Bottom padding: 24, Row height: 36 per item.
    const double header = 44.0;
    const double filter = 36.0;
    const double topPad = 10.0;
    const double bottomPad = 24.0;
    const double rowH = 36.0;
    final rows = flattenedIds().length;
    final auto = header + filter + topPad + bottomPad + rowH * rows;
    return Size(width, height ?? auto);
  }

  List<String> flattenedIds() {
    final ids = <String>[];
    for (final it in items) {
      ids.add(it.id);
      for (final ch in it.children) {
        ids.add(ch.id);
      }
    }
    return ids;
  }

  // Compute row center Y for an item id
  double _rowCenterY(String itemId) {
    final header = 44.0;
    final filter = 36.0;
    final rowH = 36.0;
    const topPad = 10.0; // must match list view top padding in widget
    final ids = flattenedIds();
    final idx = ids.indexOf(itemId);
    final safeIdx = idx < 0 ? 0 : idx;
    return position.dy + header + filter + topPad + rowH * (safeIdx + 0.5);
  }

  // Returns world position of port for an item on the given side
  Offset portWorldForItem(String itemId, PortKind kind) {
    // Match the visual layout where ports sit half outside the node body with a margin.
    const double visualPortMargin = 12.0; // must match kPortMargin in the widget
    final y = _rowCenterY(itemId);
    final xLeftCenter = position.dx + visualPortMargin; // center of in-port circle
    final xRightCenter = position.dx + size.width + visualPortMargin; // center of out-port circle
    if (kind == PortKind.inPort) {
      return Offset(inPortsSide == PortSide.left ? xLeftCenter : position.dx, y);
    } else {
      return Offset(outPortsSide == PortSide.right ? xRightCenter : position.dx + size.width, y);
    }
  }
}

class AggPort {
  final String nodeId;
  final String itemId; // specific row in the aggregated node
  final PortKind kind;
  const AggPort({required this.nodeId, required this.itemId, required this.kind});
}

class AggConnection {
  final AggPort from; // out
  final AggPort to; // in
  const AggConnection({required this.from, required this.to});
}
