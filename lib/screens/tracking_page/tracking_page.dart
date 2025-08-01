import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// Remove the import for map_style_provider.dart
import '../../services/native_location_service.dart';

class TrackingPage extends StatefulWidget {
  final String token;
  final String driverId;
  final String driverName;

  const TrackingPage({
    super.key,
    required this.token,
    required this.driverId,
    required this.driverName,
  });

  @override
  _TrackingPageState createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  LatLng? _currentPosition;
  double? _currentSpeed;
  StreamSubscription<Map<dynamic, dynamic>>? _locationSubscription;
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _initLocationUpdates();
    _startLocationService();
  }

  void _initLocationUpdates() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationSubscription = NativeLocationService.locationStream.listen(
        _handleLocationUpdate,
        onError: (error) {
          print("Location stream error: $error");
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location update error: $error"),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        cancelOnError: false,
      );
    });
  }

  void _startLocationService() async {
    try {
      await NativeLocationService.startService(
        token: widget.token,
        driverId: widget.driverId,
        serverUrl: "https://driver-cotrolling.onrender.com",
      );
    } catch (e) {
      print("Failed to start service: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to start location service"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleLocationUpdate(Map<dynamic, dynamic> locationData) {
    if (!mounted) return;

    final newPosition = LatLng(locationData['lat'], locationData['lng']);
    final newSpeed = locationData['speed'] as double?;

    setState(() {
      _currentPosition = newPosition;
      _currentSpeed = newSpeed;
    });

    if (_isMapReady) {
      _mapController.move(newPosition, _mapController.camera.zoom);
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove: final mapStyleProvider = Provider.of<MapStyleProvider>(context);
    final theme = Theme.of(context);

    final speedInKmh = (_currentSpeed ?? 0) * 3.6;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tracking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, _mapController.camera.zoom);
              }
            },
          ),
        
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(0, 0),
              initialZoom: 15.0,
              onMapReady: () {
                setState(() => _isMapReady = true);
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, _mapController.camera.zoom);
                }
              },
            ),
            children: [
              TileLayer(
                // Directly use the standard OpenStreetMap URL
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.driver',
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 80,
                      height: 80,
                      child: Transform.rotate(
                        angle: 45, // You could update this with bearing/course later
                        child: Icon(
                          Icons.navigation,
                          color: theme.primaryColor,
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_currentPosition != null)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          speedInKmh.toStringAsFixed(1),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        Text(
                          "km/h",
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}











// import 'dart:async';
// import 'package:flutter/material.dart';
// // Remove FlutterMap and LatLng imports as they are no longer needed for the UI
// // import 'package:flutter_map/flutter_map.dart';
// // import 'package:latlong2/latlong.dart';
// import 'package:provider/provider.dart';
// import '../../services/native_location_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// // Still needed for context, though not directly for map

// class TrackingPage extends StatefulWidget {
//   final String token;
//   final int driverId;
//   final String driverName;
  

//   const TrackingPage({
//     super.key,
//     required this.token,
//     required this.driverId,
//     required this.driverName,
    
//   });

//   @override
//   _TrackingPageState createState() => _TrackingPageState();
// }

// class _TrackingPageState extends State<TrackingPage> {
//   // Use dynamic for _currentPosition as it won't be a LatLng object directly anymore for UI
//   Map<dynamic, dynamic>? _currentLocationData;
//   double? _currentSpeed;
//   StreamSubscription<Map<dynamic, dynamic>>? _locationSubscription;
//   // Remove MapController as there's no map
//   // final MapController _mapController = MapController();
//   // Remove _isMapReady as there's no map
//   // bool _isMapReady = false;

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

//   void _handleLocationUpdate(Map<dynamic, dynamic> locationData) {
//     if (!mounted) return;

//     // Store the entire locationData map
//     setState(() {
//       _currentLocationData = locationData;
//       _currentSpeed = locationData['speed'] as double?;
//     });

//     // No need to move the map
//   }

//   @override
//   void dispose() {
//     _locationSubscription?.cancel();
//     // No map controller to dispose
//     // _mapController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // mapStyleProvider is no longer directly used for UI, but might be for context if needed elsewhere
//     final mapStyleProvider = Provider.of<MapStyleProvider>(context);
//     final theme = Theme.of(context);

//     final speedInKmh = (_currentSpeed ?? 0) * 3.6;

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Tracking Info', // Changed title to reflect only information display
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         centerTitle: true,
//         // Removed the "my location" button as there's no map to center
//         // actions: [
//         //   IconButton(
//         //     icon: const Icon(Icons.my_location),
//         //     onPressed: () {
//         //       if (_currentPosition != null) {
//         //         _mapController.move(_currentPosition!, _mapController.camera.zoom);
//         //       }
//         //     },
//         //   ),
//         // ],
//       ),
//       body: Center( // Center the information on the screen
//         child: _currentLocationData != null
//             ? Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
//                 margin: const EdgeInsets.all(20), // Add some margin
//                 decoration: BoxDecoration(
//                   color: theme.cardColor,
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.15),
//                       blurRadius: 15,
//                       spreadRadius: 3,
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min, // Make the column take minimum space
//                   children: [
//                     Text(
//                       'Latitude: ${_currentLocationData!['lat'].toStringAsFixed(5)}',
//                       style: theme.textTheme.headlineSmall, // Larger text for emphasis
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       'Longitude: ${_currentLocationData!['lng'].toStringAsFixed(5)}',
//                       style: theme.textTheme.headlineSmall,
//                     ),
//                     const SizedBox(height: 20),
//                     Text(
//                       'Speed:',
//                       style: theme.textTheme.titleLarge,
//                     ),
//                     Text(
//                       '${speedInKmh.toStringAsFixed(1)} km/h',
//                       style: theme.textTheme.displaySmall?.copyWith( // Even larger for speed
//                         fontWeight: FontWeight.bold,
//                         color: theme.primaryColor,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//             : Text(
//                 'Waiting for location data...',
//                 style: theme.textTheme.titleMedium,
//               ),
//       ),
//     );
//   }
// }


// enum MapStyle {
//   osmStandard(name: 'Standard', url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
//   osmHot(name: 'Humanitarian', url: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png'),
//   stamenToner(name: 'Toner', url: 'https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png');

//   const MapStyle({required this.name, required this.url});
//   final String name;
//   final String url;
// }

// class MapStyleProvider with ChangeNotifier {
//   MapStyle _currentMapStyle = MapStyle.osmStandard;
//   MapStyle get currentMapStyle => _currentMapStyle;

//   Future<void> loadMapStyle() async {
//     final prefs = await SharedPreferences.getInstance();
//     final savedStyleName = prefs.getString('mapStyle');
//     if (savedStyleName != null) {
//       _currentMapStyle = MapStyle.values.firstWhere(
//         (style) => style.name == savedStyleName,
//         orElse: () => MapStyle.osmStandard,
//       );
//     }
//     notifyListeners();
//   }

//   void setMapStyle(MapStyle style) async {
//     _currentMapStyle = style;
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setString('mapStyle', style.name);
//     notifyListeners();
//   }
// }