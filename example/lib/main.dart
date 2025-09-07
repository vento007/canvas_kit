import 'package:flutter/gestures.dart' as gestures;
import 'package:flutter/material.dart';

import 'demos/aggregated_editor/aggregated_node_editor_demo.dart';
import 'demos/bounds_demo.dart';
import 'demos/bounds_demo_alt.dart';
import 'demos/debug_sandbox.dart';
import 'demos/interactive_demo.dart';
import 'demos/interactive_node_demo.dart';
import 'demos/node_editor_demo.dart';
import 'demos/programmatic_demo.dart';
import 'demos/snake_demo.dart';
import 'demos/fly_to_demo.dart';
import 'demos/parallax/parallax_demo_clean.dart';

void main() {
  // Enable gesture arena diagnostics for debugging recognizer conflicts
  gestures.debugPrintGestureArenaDiagnostics =
      false; // set to true only when debugging
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CanvasKit Demos',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a demo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InteractiveDemoPage(),
                    ),
                  ),
                  child: const Text('Interactive (package pan/zoom)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BoundsDemoPage()),
                  ),
                  child: const Text('Bounds Demo (programmatic, simple)'),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProgrammaticDemoPage(),
                    ),
                  ),
                  child: const Text('Programmatic (app camera control)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BoundsDemoAltPage(),
                    ),
                  ),
                  child: const Text('Bounds Demo (alt, controller bounds)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DebugSandboxPage()),
                  ),
                  child: const Text(
                    'Debug Sandbox (pinch + wheel, no package)',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InteractiveNodeDemoPage(),
                    ),
                  ),
                  child: const Text('Interactive Node (separate widgets)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AggregatedNodeEditorDemoPage(),
                    ),
                  ),
                  child: const Text('Aggregated Node Editor (grouped items)'),
                ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NodeEditorDemoPage(),
                    ),
                  ),
                  child: const Text('Node Editor (wires)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FlyToDemoPage()),
                  ),
                  child: const Text('Fly To (animated camera)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SnakeDemoPage()),
                  ),
                  child: const Text('Snake (2000x2000, WASD)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParallaxDemoCleanPage()),
                  ),
                  child: const Text('Parallax (Programmatic Mode)'),
                ),
                const SizedBox(height: 12),
               
              
              ],
            ),
          ),
        ),
      ),
    );
  }
}
