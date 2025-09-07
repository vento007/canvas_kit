import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Asset Test')),
        body: Center(
          child: Image.asset(
            'assets/PARALLAX/layer_01_1920 x 1080.png',
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading asset: $error');
              return Text('Failed to load asset: $error');
            },
          ),
        ),
      ),
    );
  }
}