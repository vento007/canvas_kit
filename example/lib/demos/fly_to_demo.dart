import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:canvas_kit/canvas_kit.dart';

import '../shared/grid_background.dart';

class FlyToDemoPage extends StatefulWidget {
  const FlyToDemoPage({super.key});

  @override
  State<FlyToDemoPage> createState() => _FlyToDemoPageState();
}

class _FlyToDemoPageState extends State<FlyToDemoPage>
    with TickerProviderStateMixin {
  late final CanvasKitController _controller;
  AnimationController? _anim; // current animation controller (phase)

  // World targets to fly to
  final Map<String, Offset> _targets = const {
    'Origin': Offset(0, 0),
    'Alpha': Offset(-400, -180),
    'Beta': Offset(600, 120),
    'Gamma': Offset(1200, -700),
    'Delta': Offset(-900, 800),
  };

  // Item positions (match targets for easy tapping)
  final Offset _alpha = const Offset(-400, -180);
  final Offset _beta = const Offset(600, 120);
  final Offset _gamma = const Offset(1200, -700);
  final Offset _delta = const Offset(-900, 800);

  // Live tuning controls
  int _durationMs = 800;
  final Map<String, Curve> _curveOptions = const {
    'easeInOutCubic': Curves.easeInOutCubic,
    'easeOutCubic': Curves.easeOutCubic,
    'easeInOut': Curves.easeInOut,
    'easeInOutQuad': Curves.easeInOutQuad,
    'fastOutSlowIn': Curves.fastOutSlowIn,
  };
  String _moveCurveKey = 'easeInOutCubic';
  bool _autoDuration = false; // compute duration from distance
  double _autoDurMsPerPx = 0.25; // ms per pixel of travel (approx)
  // (debug logging removed)

  @override
  void initState() {
    super.initState();
    _controller = CanvasKitController();
  }

  @override
  void dispose() {
    _anim?.dispose();
    super.dispose();
  }

  void _stopFlight() {
    _anim?.stop(canceled: true);
    _anim?.dispose();
    _anim = null;
  }

  Future<void> _flyTo(Offset target, {Duration? duration, Curve? curve}) async {
    // Cancel any ongoing animation
    _stopFlight();

    if (!mounted) return;
    final Size viewport = MediaQuery.of(context).size;

    // Helper: current world center at screen center
    Offset worldCenter() => _controller.screenToWorld(
      Offset(viewport.width / 2, viewport.height / 2),
    );

    // Start parameters
    final double s0 = _controller.scale; // keep scale constant during flight
    final Offset c0 = worldCenter();
    final Offset c1 = target;

    // Drive both center and scale together in one fluent move
    // Duration selection: explicit > auto > manual
    final int computedMs;
    if (duration != null) {
      computedMs = duration.inMilliseconds;
    } else if (_autoDuration) {
      // compute pixels to travel at current scale
      final Offset c0Screen = _controller.worldToScreen(c0);
      final Offset c1Screen = _controller.worldToScreen(c1);
      final double dPx = (c1Screen - c0Screen).distance;
      final int ms = (400 + _autoDurMsPerPx * dPx).round();
      computedMs = ms.clamp(300, 1600);
    } else {
      computedMs = _durationMs;
    }

    _anim = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: computedMs),
    );
    // logging removed
    void tick() {
      final double baseT = _anim!.value; // 0..1
      // Move progress (center)
      final Curve moveCurve = curve ?? _curveOptions[_moveCurveKey]!;
      final double tMove = moveCurve.transform(baseT);
      // Keep scale constant during flight
      final double s = s0;
      final Offset c = Offset(
        c0.dx + (c1.dx - c0.dx) * tMove,
        c0.dy + (c1.dy - c0.dy) * tMove,
      );
      final Matrix4 m = Matrix4.identity()
        ..translate(viewport.width / 2, viewport.height / 2)
        ..scale(s, s)
        ..translate(-c.dx, -c.dy);
      _controller.setTransform(m);
      // logging removed
    }

    _anim!.addListener(tick);
    try {
      await _anim!.forward();
    } finally {
      _anim!.removeListener(tick);
      _anim!.dispose();
      _anim = null;
      // logging removed
    }
  }

  // (phased helper methods removed – unified animation drives center and scale together)

  Offset _randomTarget() {
    final keys = _targets.keys.toList();
    final r = math.Random();
    return _targets[keys[r.nextInt(keys.length)]]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Fly To demo (animated camera)'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune),
            onPressed: _openSettings,
          ),
          IconButton(
            tooltip: 'Fly to random',
            icon: const Icon(Icons.explore),
            onPressed: () => _flyTo(_randomTarget()),
          ),
          IconButton(
            tooltip: 'Stop',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _stopFlight,
          ),
        ],
      ),
      body: CanvasKit(
        controller: _controller,
        backgroundBuilder: (t) => GridBackground(
          transform: t,
          gridSpacing: 100,
          backgroundColor: const Color(0xFFF7F9FF),
          gridColor: const Color(0x22000000),
        ),
        children: [
          // Markers you can tap to fly to
          _targetItem(
            'Alpha',
            _alpha,
            color: Colors.redAccent,
            size: const Size(200, 120),
          ),
          _targetItem(
            'Beta',
            _beta,
            color: Colors.green,
            size: const Size(160, 90),
          ),
          _targetItem(
            'Gamma',
            _gamma,
            color: Colors.deepPurple,
            size: const Size(200, 160),
          ),
          _targetItem(
            'Delta',
            _delta,
            color: Colors.teal,
            size: const Size(180, 130),
          ),
          _targetItem(
            'Origin',
            const Offset(-20, -20),
            color: Colors.orange,
            size: const Size(40, 40),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in _targets.entries)
              FilledButton.tonal(
                onPressed: () => _flyTo(e.value),
                child: Text('Fly to ${e.key}'),
              ),
          ],
        ),
      ),
    );
  }

  CanvasItem _targetItem(
    String label,
    Offset pos, {
    required Color color,
    required Size size,
  }) {
    return CanvasItem(
      id: 'target-$label',
      worldPosition: pos,
      draggable: false,
      estimatedSize: size,
      child: _node(label, color, size, onTap: () => _flyTo(pos)),
    );
  }

  Widget _node(String label, Color color, Size size, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9, // take up to 90% of screen height
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, modalSetState) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Flight Settings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // (logging controls removed)
                      // Auto duration
                      SwitchListTile(
                        title: const Text('Auto duration (distance based)'),
                        value: _autoDuration,
                        onChanged: (v) {
                          setState(() => _autoDuration = v);
                          modalSetState(() {});
                        },
                      ),
                      // Auto factor
                      Row(
                        children: [
                          const SizedBox(width: 120, child: Text('Auto ms/px')),
                          Expanded(
                            child: Slider(
                              min: 0.05,
                              max: 0.8,
                              divisions: 15,
                              label: _autoDurMsPerPx.toStringAsFixed(2),
                              value: _autoDurMsPerPx,
                              onChanged: _autoDuration
                                  ? (v) {
                                      setState(() => _autoDurMsPerPx = v);
                                      modalSetState(() {});
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              _autoDurMsPerPx.toStringAsFixed(2),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Manual duration
                      // Duration
                      Row(
                        children: [
                          const SizedBox(
                            width: 120,
                            child: Text('Duration (ms)'),
                          ),
                          Expanded(
                            child: Slider(
                              min: 200,
                              max: 2000,
                              divisions: 18,
                              label: '$_durationMs',
                              value: _durationMs.toDouble(),
                              onChanged: _autoDuration
                                  ? null
                                  : (v) {
                                      setState(() => _durationMs = v.round());
                                      modalSetState(() {});
                                    },
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              '$_durationMs',
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Move curve (center motion)
                      Row(
                        children: [
                          const SizedBox(width: 120, child: Text('Move curve')),
                          Expanded(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _moveCurveKey,
                              items: _curveOptions.keys
                                  .map(
                                    (k) => DropdownMenuItem(
                                      value: k,
                                      child: Text(k),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (k) {
                                if (k == null) return;
                                setState(() => _moveCurveKey = k);
                                modalSetState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
