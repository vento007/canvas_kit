import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../shared/grid_background.dart';

class InteractiveDemoPage extends StatefulWidget {
  const InteractiveDemoPage({super.key});

  @override
  State<InteractiveDemoPage> createState() => _InteractiveDemoPageState();
}

class _InteractiveDemoPageState extends State<InteractiveDemoPage> {
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
        title: const Text('Interactive demo (package-owned gestures)'),
      ),
      body: CanvasKit(
        controller: _controller,
        // Default = InteractionMode.interactive (package handles pan + wheel)
        backgroundBuilder: (transform) => GridBackground(
          transform: transform,
          backgroundColor: const Color(0xFFF2F8FF),
          gridSpacing: 80,
          gridColor: const Color(0x22000000),
        ),
        children: [
          CanvasItem(
            id: 'node-1',
            worldPosition: _pos1,
            draggable: true,
            child: _node(color: Colors.red),
            onWorldMoved: (pos) => setState(() => _pos1 = pos),
          ),
          CanvasItem(
            id: 'node-2',
            worldPosition: _pos2,
            draggable: true,
            child: _node(color: Colors.green),
            onWorldMoved: (pos) => setState(() => _pos2 = pos),
          ),
        ],
      ),
    );
  }

  Widget _node({required Color color}) {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: const Text('Drag', style: TextStyle(color: Colors.white)),
    );
  }
}
