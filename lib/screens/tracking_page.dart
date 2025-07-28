// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:provider/provider.dart';
// import '../services/native_location_service.dart';
// import '../providers/map_style_provider.dart';
// import '../screens/profile_screen.dart';

// class TrackingPage extends StatefulWidget {
//   final String token;
//   final int driverId;
//   final String driverName;
//   final VoidCallback onLogout;

//   const TrackingPage({
//     super.key,
//     required this.token,
//     required this.driverId,
//     required this.driverName,
//     required this.onLogout,
//   });

//   @override
//   _TrackingPageState createState() => _TrackingPageState();
// }

// class _TrackingPageState extends State<TrackingPage> {
//   LatLng? _currentPosition;
//   double? _currentSpeed; // <-- ADD THIS: To store the speed
//   StreamSubscription<Map<dynamic, dynamic>>? _locationSubscription;
//   final MapController _mapController = MapController();
//   int _selectedIndex = 0;
//   bool _isMapReady = false;

//   @override
//   void initState() {
//     super.initState();
//     _initLocationUpdates();
//     _startLocationService();
//   }

//   void _initLocationUpdates() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _locationSubscription = NativeLocationService.locationStream.listen(
//         _handleLocationUpdate,
//         onError: (error) {
//           print("Location stream error: $error");
//           if (!mounted) return;
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text("Location update error: $error"),
//               behavior: SnackBarBehavior.floating,
//             ),
//           );
//         },
//         cancelOnError: false,
//       );
//     });
//   }

//   void _startLocationService() async {
//     try {
//       await NativeLocationService.startService(
//         token: widget.token,
//         driverId: widget.driverId,
//         serverUrl: "https://driver-cotrolling.onrender.com",
//       );
//     } catch (e) {
//       print("Failed to start service: $e");
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Failed to start location service"),
//           behavior: SnackBarBehavior.floating,
//         ),
//       );
//     }
//   }

//   // --- THIS METHOD IS UPDATED ---
//   void _handleLocationUpdate(Map<dynamic, dynamic> locationData) {
//     if (!mounted) return;

//     final newPosition = LatLng(locationData['lat'], locationData['lng']);
//     // Extract speed. It might be null or not present initially.
//     final newSpeed = locationData['speed'] as double?;

//     setState(() {
//       _currentPosition = newPosition;
//       _currentSpeed = newSpeed; // <-- SET THE SPEED
//     });

//     if (_selectedIndex == 0 && _isMapReady) {
//       _mapController.move(newPosition, _mapController.camera.zoom);
//     }
//   }

//   @override
//   void dispose() {
//     _locationSubscription?.cancel();
//     _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mapStyleProvider = Provider.of<MapStyleProvider>(context);
//     final theme = Theme.of(context);
    
//     // Convert speed from m/s to km/h, defaulting to 0 if null.
//     final speedInKmh = (_currentSpeed ?? 0) * 3.6;

//     final List<Widget> widgetOptions = [
//       Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: _currentPosition ?? const LatLng(0, 0),
//               initialZoom: 15.0,
//               onMapReady: () {
//                 setState(() => _isMapReady = true);
//                 if (_currentPosition != null) {
//                   _mapController.move(_currentPosition!, _mapController.camera.zoom);
//                 }
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: mapStyleProvider.currentMapStyle.url,
//                 userAgentPackageName: 'com.example.driver',
//               ),
//               if (_currentPosition != null)
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       point: _currentPosition!,
//                       width: 80,
//                       height: 80,
//                       child: Transform.rotate(
//                         angle: 45, // You could update this with bearing/course later
//                         child: Icon(
//                           Icons.navigation,
//                           color: theme.primaryColor,
//                           size: 40,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//             ],
//           ),
//           // --- THIS UI WIDGET IS UPDATED ---
//           if (_currentPosition != null)
//             Positioned(
//               top: 20,
//               left: 20,
//               right: 20,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                 decoration: BoxDecoration(
//                   color: theme.cardColor,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.1),
//                       blurRadius: 10,
//                       spreadRadius: 2,
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}',
//                           style: theme.textTheme.bodyMedium,
//                         ),
//                         Text(
//                           'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
//                           style: theme.textTheme.bodyMedium,
//                         ),
//                       ],
//                     ),
//                     // Speed Display Column
//                     Column(
//                       children: [
//                         Text(
//                           speedInKmh.toStringAsFixed(1),
//                           style: theme.textTheme.headlineSmall?.copyWith(
//                             fontWeight: FontWeight.bold,
//                             color: theme.primaryColor,
//                           ),
//                         ),
//                         Text(
//                           "km/h",
//                           style: theme.textTheme.bodySmall,
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//       ProfileScreen(
//         driverName: widget.driverName,
//         driverId: widget.driverId.toString(),
//         onLogout: widget.onLogout,
//       ),
//     ];
    
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           _selectedIndex == 0 ? 'Home' : 'My Profile',
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//         actions: _selectedIndex == 0
//             ? [
//                 IconButton(
//                   icon: Icon(Icons.my_location),
//                   onPressed: () {
//                     if (_currentPosition != null) {
//                       _mapController.move(_currentPosition!, _mapController.camera.zoom);
//                     }
//                   },
//                 ),
//               ]
//             : null,
//       ),
//       body: IndexedStack(
//         index: _selectedIndex,
//         children: widgetOptions,
//       ),
//       bottomNavigationBar: Container(
//         decoration: BoxDecoration(
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.1),
//               blurRadius: 10,
//               spreadRadius: 2,
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//           child: BottomNavigationBar(
//             items: [
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.map),
//                 label: 'Tracking',
//                 activeIcon: Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: theme.primaryColor.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Icon(Icons.map, color: theme.primaryColor),
//                 ),
//               ),
//               BottomNavigationBarItem(
//                 icon: Icon(Icons.person),
//                 label: 'Profile',
//                 activeIcon: Container(
//                   padding: EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: theme.primaryColor.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Icon(Icons.person, color: theme.primaryColor),
//                 ),
//               ),
//             ],
//             currentIndex: _selectedIndex,
//             onTap: (index) {
//               setState(() {
//                 _selectedIndex = index;
//               });
//             },
//             selectedItemColor: theme.primaryColor,
//             unselectedItemColor: Colors.grey,
//             showSelectedLabels: true,
//             showUnselectedLabels: true,
//             type: BottomNavigationBarType.fixed,
//             elevation: 10,
//           ),
//         ),
//       ),
//     );
//   }
// }