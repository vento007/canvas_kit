import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

class TransparentBackgroundDemoPage extends StatefulWidget {
  const TransparentBackgroundDemoPage({super.key});

  @override
  State<TransparentBackgroundDemoPage> createState() =>
      _TransparentBackgroundDemoPageState();
}

class _TransparentBackgroundDemoPageState
    extends State<TransparentBackgroundDemoPage> {
  Offset _pos1 = const Offset(120, 120);
  Offset _pos2 = const Offset(300, 200);
  Offset _pos3 = const Offset(200, -80);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false, // unify title alignment across demos
        title: const Text('Transparent background demo'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _CheckerboardBackground()),
          CanvasKit(
            children: [
              CanvasItem(
                id: 'node-1',
                worldPosition: _pos1,
                draggable: true,
                child: _node(
                  color: const Color(0xFFEF6C56),
                  label: 'Drag',
                ),
                onWorldMoved: (pos) => setState(() => _pos1 = pos),
              ),
              CanvasItem(
                id: 'node-2',
                worldPosition: _pos2,
                draggable: true,
                child: _node(
                  color: const Color(0xFF66B37A),
                  label: 'Move',
                ),
                onWorldMoved: (pos) => setState(() => _pos2 = pos),
              ),
              CanvasItem(
                id: 'node-3',
                worldPosition: _pos3,
                draggable: true,
                child: _node(
                  color: const Color(0xFF5A7EDC),
                  label: 'Pan',
                ),
                onWorldMoved: (pos) => setState(() => _pos3 = pos),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: const _HintCard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _node({required Color color, required String label}) {
    return Container(
      width: 72,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xCCFFFFFF),
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          'The checkerboard is outside CanvasKit. If you can see it, '
          'CanvasKit is transparent.',
        ),
      ),
    );
  }
}

class _CheckerboardBackground extends StatelessWidget {
  const _CheckerboardBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CheckerboardPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  static const double _cellSize = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paintA = Paint()..color = const Color(0xFFECE5D8);
    final paintB = Paint()..color = const Color(0xFFF8F5EE);
    final cols = (size.width / _cellSize).ceil();
    final rows = (size.height / _cellSize).ceil();

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final paint = ((x + y) % 2 == 0) ? paintA : paintB;
        final rect = Rect.fromLTWH(
          x * _cellSize,
          y * _cellSize,
          _cellSize,
          _cellSize,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
