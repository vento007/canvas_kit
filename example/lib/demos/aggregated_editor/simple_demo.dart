// import 'package:flutter/material.dart';
// import 'app_state.dart';

// // Quick test - run this by adding to main.dart temporarily
// void main() {
//   runApp(MaterialApp(home: SimpleDemoPage()));
// }

// /// Simple reactive demo to prove the concept works
// class SimpleDemoPage extends StatefulWidget {
//   const SimpleDemoPage({Key? key}) : super(key: key);

//   @override
//   State<SimpleDemoPage> createState() => _SimpleDemoPageState();
// }

// class _SimpleDemoPageState extends State<SimpleDemoPage> {
//   late final AppState _appState;

//   @override
//   void initState() {
//     super.initState();
//     _appState = AppState();
//     // Listen to state changes and rebuild UI
//     _appState.addListener(() {
//       if (mounted) setState(() {});
//     });
//   }

//   @override
//   void dispose() {
//     _appState.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Reactive Filter Test'),
//         actions: [
//           // Downstream filter toggle
//           IconButton(
//             icon: Icon(
//               _appState.downstreamFilterEnabled ? Icons.filter_alt : Icons.filter_alt_outlined,
//               color: _appState.downstreamFilterEnabled ? Colors.blue : null,
//             ),
//             onPressed: () {
//               _appState.setDownstreamFilter(!_appState.downstreamFilterEnabled);
//               print('Downstream filter: ${_appState.downstreamFilterEnabled}');
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Filter controls
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: TextField(
//                     decoration: const InputDecoration(
//                       labelText: 'Filter Users',
//                       hintText: 'Type "frank"',
//                     ),
//                     onChanged: (value) {
//                       _appState.setTextFilter('users', value);
//                     },
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 ElevatedButton(
//                   onPressed: () {
//                     _appState.setConnectedOnlyFilter('users', !(_appState.connectedOnlyFilters['users'] ?? false));
//                   },
//                   child: Text(_appState.connectedOnlyFilters['users'] == true ? 'Connected Only: ON' : 'Connected Only: OFF'),
//                 ),
//               ],
//             ),
//           ),
//           // Results display
//           Expanded(
//             child: ListView(
//               children: _appState.nodes.map((node) {
//                 final visibleItems = _appState.getVisibleItems(node.id);
//                 final totalItems = node.flattenedIds().length;
                
//                 return Card(
//                   margin: const EdgeInsets.all(8),
//                   child: ListTile(
//                     title: Text(node.title),
//                     subtitle: Text('Showing ${visibleItems.length}/${totalItems} items'),
//                     trailing: Text('${(visibleItems.length / totalItems * 100).toInt()}%'),
//                     onTap: () {
//                       print('${node.id} visible items: $visibleItems');
//                     },
//                   ),
//                 );
//               }).toList(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }