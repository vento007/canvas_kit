import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ParallaxWidget extends StatefulWidget {
  final Size size;
  final bool autoScroll;
  final double scrollSpeed;
  final double externalScale; // Scale controlled by external resize handle
  final List<String> layers; // Ordered: index 0 = closest (foreground)

  const ParallaxWidget({
    super.key,
    required this.layers,
    this.size = const Size(1200, 800),
    this.autoScroll = true,
    this.scrollSpeed = 0.5,
    this.externalScale = 1.0,
  });

  @override
  State<ParallaxWidget> createState() => _ParallaxWidgetState();
}

class _ParallaxWidgetState extends State<ParallaxWidget>
    with TickerProviderStateMixin {
  Offset _panOffset = const Offset(0, 100); // Start with ground visible
  final Map<String, ui.Image> _images = {};
  late AnimationController _autoScrollController;
  late final List<double> _parallaxFactors;

  List<double> _makeFactors(int n) {
    if (n <= 1) return const [1.0];
    // Interpolate from 1.0 (foreground) down to ~0.18 (background) across n layers
    const double minF = 0.18;
    final List<double> f = [];
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);
      f.add(1.0 + (minF - 1.0) * t);
    }
    return f;
  }

  @override
  void initState() {
    super.initState();
    _parallaxFactors = _makeFactors(widget.layers.length);
    _loadImages();

    if (widget.autoScroll) {
      // Auto-scroll animation
      _autoScrollController = AnimationController(
        duration: const Duration(seconds: 60), // Slow scroll over 60 seconds
        vsync: this,
      )..repeat();

      _autoScrollController.addListener(() {
        setState(() {
          // Add small constant horizontal offset (direction aligned with pan/shader)
          _panOffset = Offset(
            _panOffset.dx + widget.scrollSpeed,
            _panOffset.dy,
          );
        });
      });
    }
  }

  @override
  void dispose() {
    if (widget.autoScroll) {
      _autoScrollController.dispose();
    }
    super.dispose();
  }

  void _loadImages() async {
    for (String imagePath in widget.layers) {
      final AssetImage assetImage = AssetImage(imagePath);
      final ImageStream stream = assetImage.resolve(const ImageConfiguration());
      stream.addListener(
        ImageStreamListener((ImageInfo info, bool synchronousCall) {
          setState(() {
            _images[imagePath] = info.image;
          });
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Container resizes, content scales at same rate - no double scaling
    final scaledSize = Size(
      widget.size.width * widget.externalScale,
      widget.size.height * widget.externalScale,
    );

    return Container(
      width: scaledSize.width,
      height: scaledSize.height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
      ),
      child: GestureDetector(
        onScaleStart: (details) {
          // Start panning only
        },
        onScaleUpdate: (details) {
          setState(() {
            if (details.pointerCount == 1) {
              // Single finger = pan only
              _panOffset -= Offset(
                details.focalPointDelta.dx,
                0,
              ); // Lock Y axis; subtract to match shader's -offset translation
            }
          });
        },
        child: ClipRect(
          child: Stack(
            children: [
              // Multiple parallax layers from back to front (draw layer_08 first, layer_01 last)
              for (int i = widget.layers.length - 1; i >= 0; i--)
                CustomPaint(
                  painter: RepeatingBackgroundPainter(
                    imagePath: widget.layers[i],
                    offset: Offset(
                      _panOffset.dx * _parallaxFactors[i],
                      _panOffset.dy * _parallaxFactors[i],
                    ),
                    scale: widget.externalScale,
                    image: _images[widget.layers[i]],
                  ),
                  size:
                      scaledSize, // Paint to the same size as the frame to avoid double scaling
                ),

              // Debug info overlay
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Pan: ${_panOffset.dx.toInt()}, ${_panOffset.dy.toInt()}\nScale: ${widget.externalScale.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RepeatingBackgroundPainter extends CustomPainter {
  final String imagePath;
  final Offset offset;
  final double scale;
  final ui.Image? image;

  RepeatingBackgroundPainter({
    required this.imagePath,
    required this.offset,
    required this.scale,
    this.image,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) {
      // Paint placeholder while loading
      final paint = Paint()..color = Colors.grey.withValues(alpha: 0.3);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }

    // Create shader from image with repeat tiling and offset
    final double k = scale == 0 ? 1.0 : scale;
    // Scale first (so texture pixels grow with the frame), then translate.
    // Use negative offset so dragging right moves content right (natural feel).
    final matrix = Matrix4.identity()
      ..scale(k, k)
      ..translate(-offset.dx, -offset.dy);
    final shader = ImageShader(
      image!,
      TileMode.repeated,
      TileMode.repeated,
      matrix.storage,
    );

    final paint = Paint()..shader = shader;

    // Paint the entire canvas with the infinitely repeating shader
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(RepeatingBackgroundPainter oldDelegate) {
    return oldDelegate.offset != offset ||
        oldDelegate.scale != scale ||
        oldDelegate.imagePath != imagePath ||
        oldDelegate.image != image;
  }
}
