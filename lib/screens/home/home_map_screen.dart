import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

// import 'package:shimmer/shimmer.dart'; //

import '../../providers/driver_location_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/passenger.dart';
import '../../services/passenger_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/modern_shimmer.dart';
import '../../widgets/info_pill.dart';
import '../../widgets/route_segement_card.dart';

class HomeMapPage extends StatefulWidget {
  final String driverId;
  const HomeMapPage({super.key, required this.driverId});
  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  List<PointAnnotationOptions> _markerOptions = [];
  List<PolylineAnnotationOptions> _polylineOptions = [];
  int _selectedSegmentIndex = -1; // -1 means show all routes
  Map<Point, Map<String, String>> _markerInfo = {}; // Store marker info for popups

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationAndRoute();
    });
    
    // Listen to route provider changes
    context.read<RouteProvider>().addListener(() {
      if (!context.read<RouteProvider>().loading) {
        print("Route provider updated, refreshing map objects");
        _updateMapObjects();
      }
    });
  }

  // Function to add directional arrows to polylines
  void _addDirectionalArrows(List<Point> polylinePoints, Color segmentColor, List<PointAnnotationOptions> markerOptions) {
    if (polylinePoints.length < 2) return;
    
    // Add arrow at the end of the polyline
    final lastPoint = polylinePoints.last;
    final secondLastPoint = polylinePoints[polylinePoints.length - 2];
    
    // Calculate direction for the arrow
    final dx = lastPoint.coordinates.lng - secondLastPoint.coordinates.lng;
    final dy = lastPoint.coordinates.lat - secondLastPoint.coordinates.lat;
    final angle = (180 / pi) * atan2(dy, dx);
    
    markerOptions.add(
      PointAnnotationOptions(
        geometry: lastPoint,
        iconImage: "arrow-15", // Directional arrow
        iconColor: segmentColor.value,
        iconRotate: angle,
        iconSize: 1.5,
      ),
    );
    
    // Add arrow in the middle of the polyline
    if (polylinePoints.length > 3) {
      final midIndex = polylinePoints.length ~/ 2;
      final midPoint = polylinePoints[midIndex];
      final prevPoint = polylinePoints[midIndex - 1];
      
      final midDx = midPoint.coordinates.lng - prevPoint.coordinates.lng;
      final midDy = midPoint.coordinates.lat - prevPoint.coordinates.lat;
      final midAngle = (180 / pi) * atan2(midDy, midDx);
      
      markerOptions.add(
        PointAnnotationOptions(
          geometry: midPoint,
          iconImage: "arrow-15",
          iconColor: segmentColor.value,
          iconRotate: midAngle,
          iconSize: 1.2,
        ),
      );
    }
  }

  Future<void> _addMapObjects() async {
    if (_pointAnnotationManager == null || _polylineAnnotationManager == null) {
      print("Annotation managers not initialized");
      return;
    }
    
    print("Adding map objects: ${_markerOptions.length} markers, ${_polylineOptions.length} polylines");
    
    // Clear existing annotations
    await _pointAnnotationManager!.deleteAll();
    await _polylineAnnotationManager!.deleteAll();
    
    // Add markers
    for (final markerOption in _markerOptions) {
      await _pointAnnotationManager!.create(markerOption);
    }
    
    // Add polylines
    for (final lineOption in _polylineOptions) {
      print("Adding polyline with ${lineOption.geometry.coordinates.length} coordinates");
      await _polylineAnnotationManager!.create(lineOption);
    }
    
    print("Map objects added successfully");
  }

  Future<void> _moveCameraToRoute(List<Point> points) async {
    if (_mapboxMap == null || points.isEmpty) return;
    
    double minLat = points.first.coordinates.lat.toDouble();
    double maxLat = points.first.coordinates.lat.toDouble();
    double minLng = points.first.coordinates.lng.toDouble();
    double maxLng = points.first.coordinates.lng.toDouble();
    
    for (final p in points) {
      final lat = p.coordinates.lat.toDouble();
      final lng = p.coordinates.lng.toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position((minLng + maxLng) / 2, (minLat + maxLat) / 2)),
        zoom: 11.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _initializeLocationAndRoute() async {
    print("Initializing location and route...");
    
    await context.read<DriverLocationProvider>().startTracking();

    // Wait for driver location to be available
    final driverProvider = context.read<DriverLocationProvider>();
    if (driverProvider.currentLocation == null) {
      await Future.delayed(Duration(seconds: 2));
    }

    final driverLocation =
        driverProvider.currentLocation ?? Point(coordinates: Position(-104.9, 39.7));
    print("Driver location: ${driverLocation.coordinates.lat}, ${driverLocation.coordinates.lng}");
    
    try {
      // Fetch passengers from backend
      final passengers = await PassengerService.fetchPassengersForDriver(widget.driverId);
      print("Passenger list length: ${passengers.length}");
      
      await context.read<RouteProvider>().buildCompleteRoute(
        passengers,
        driverLocation,
      );
    } catch (e) {
      print("Error fetching passengers: $e");
      // Handle error - maybe show a snackbar or use empty list
      await context.read<RouteProvider>().buildCompleteRoute(
        [],
        driverLocation,
      );
    }

    // _updateMapObjects() will be called automatically by the listener
  }

  void _updateMapObjects() async {
    final routeProvider = context.read<RouteProvider>();
    final driverLoc =
        context.read<DriverLocationProvider>().currentLocation ??
        Point(coordinates: Position(-104.9, 39.7));

    print("Updating map objects. Segments count: ${routeProvider.segments.length}");
    print("Selected segment index: $_selectedSegmentIndex");

    List<PointAnnotationOptions> markerOptions = [];
    List<PolylineAnnotationOptions> polylineOptions = [];
    _markerInfo.clear(); // Clear previous marker info
    
    // Always add driver marker (blue)
    markerOptions.add(
      PointAnnotationOptions(
        geometry: driverLoc,
        iconImage: "marker-15",
        iconColor: 0xFF1976D2, // Blue
      ),
    );
    _markerInfo[driverLoc] = {
      'label': 'Driver',
      'address': 'Current Location',
    };

    if (_selectedSegmentIndex == -1) {
      for (int i = 0; i < routeProvider.segments.length; i++) {
        final segment = routeProvider.segments[i];
        if (i > 0 || segment.startLabel != "Driver") {
          markerOptions.add(
            PointAnnotationOptions(
              geometry: segment.start,
              iconImage: "bus-15", // Pickup marker (green)
              iconColor: 0xFF43A047, // Green
            ),
          );
          _markerInfo[segment.start] = {
            'label': segment.startLabel,
            'address': segment.startAddress,
          };
        }
        markerOptions.add(
          PointAnnotationOptions(
            geometry: segment.end,
            iconImage: "embassy-15", // Dropoff marker (red)
            iconColor: 0xFFE53935, // Red
          ),
        );
        _markerInfo[segment.end] = {
          'label': segment.endLabel,
          'address': segment.endAddress,
        };
        polylineOptions.add(
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: segment.polylinePoints.map((p) => p.coordinates).toList(),
            ),
            lineColor: segment.color.value,
            lineWidth: 5.0,
          ),
        );
        
        // Add start location icon
        if (segment.polylinePoints.isNotEmpty) {
          markerOptions.add(
            PointAnnotationOptions(
              geometry: segment.polylinePoints.first,
              iconImage: "marker-15",
              iconColor: segment.color.value,
              iconSize: 1.2,
            ),
          );
        }
        
        // Add end location icon
        if (segment.polylinePoints.length > 1) {
          markerOptions.add(
            PointAnnotationOptions(
              geometry: segment.polylinePoints.last,
              iconImage: "marker-15",
              iconColor: segment.color.value,
              iconSize: 1.2,
            ),
          );
        }
      }
    } else {
      if (_selectedSegmentIndex >= 0 &&
          _selectedSegmentIndex < routeProvider.segments.length) {
        final segment = routeProvider.segments[_selectedSegmentIndex];
        markerOptions.add(
          PointAnnotationOptions(
            geometry: segment.start,
            iconImage: "bus-15", // Pickup marker (green)
            iconColor: 0xFF43A047, // Green
          ),
        );
        _markerInfo[segment.start] = {
          'label': segment.startLabel,
          'address': segment.startAddress,
        };
        markerOptions.add(
          PointAnnotationOptions(
            geometry: segment.end,
            iconImage: "embassy-15", // Dropoff marker (red)
            iconColor: 0xFFE53935, // Red
          ),
        );
        _markerInfo[segment.end] = {
          'label': segment.endLabel,
          'address': segment.endAddress,
        };
        polylineOptions.add(
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: segment.polylinePoints.map((p) => p.coordinates).toList(),
            ),
            lineColor: segment.color.value,
            lineWidth: 5.0,
          ),
        );
        
        // Add start location icon
        if (segment.polylinePoints.isNotEmpty) {
          markerOptions.add(
            PointAnnotationOptions(
              geometry: segment.polylinePoints.first,
              iconImage: "marker-15",
              iconColor: segment.color.value,
              iconSize: 1.2,
            ),
          );
        }
        
        // Add end location icon
        if (segment.polylinePoints.length > 1) {
          markerOptions.add(
            PointAnnotationOptions(
              geometry: segment.polylinePoints.last,
              iconImage: "marker-15",
              iconColor: segment.color.value,
              iconSize: 1.2,
            ),
          );
        }
      }
    }

    setState(() {
      _markerOptions = markerOptions;
      _polylineOptions = polylineOptions;
    });
    
    print("Created ${markerOptions.length} markers and ${polylineOptions.length} polylines");

    // Move camera to fit all points
    final allPoints = polylineOptions.expand((l) => l.geometry.coordinates.map((c) => Point(coordinates: c))).toList();
    if (allPoints.isNotEmpty) {
      await _moveCameraToRoute(allPoints);
    }
    await _addMapObjects();
  }

  @override
  void dispose() {
    context.read<DriverLocationProvider>().stopTracking();
    super.dispose();
  }

  void _showMarkerInfoDialog(String label, String address) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(label),
          content: Text(address),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = context.watch<RouteProvider>();
    final driverLoc = context.watch<DriverLocationProvider>().currentLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          MapWidget(
            key: ValueKey('mapbox_map'),
            cameraOptions: CameraOptions(
              center: driverLoc ?? Point(coordinates: Position(-104.9, 39.7)),
              zoom: 11.0,
            ),
            styleUri: MapboxStyles.MAPBOX_STREETS,
            onMapCreated: (MapboxMap mapboxMap) async {
              print("Map created, initializing...");
              _mapboxMap = mapboxMap;
              
              // Initialize annotation managers
              _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
              _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
              print("Annotation managers created");
              
              // Add tap listener for markers
              // TODO: Fix annotation listener - Mapbox API might have changed
              // _pointAnnotationManager!.addOnPointAnnotationClickListener((annotation) {
              //   final point = annotation.geometry;
              //   final info = _markerInfo[point];
              //   if (info != null) {
              //     _showMarkerInfoDialog(info['label']!, info['address']!);
              //   }
              // });
              
              // Wait a bit for the map to be fully ready
              await Future.delayed(Duration(milliseconds: 1000));
              
              print("Adding map objects after delay");
              await _addMapObjects();
              final allPoints = _polylineOptions.expand((l) => l.geometry.coordinates.map((c) => Point(coordinates: c))).toList();
              if (allPoints.isNotEmpty) {
                await _moveCameraToRoute(allPoints);
              }
            },
          ),

          // Upper info card
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: GlassCard(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child:
                    routeProvider.loading
                        ? ModernShimmer()
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.green.shade400,
                                      radius: 16,
                                      child: const Icon(
                                        Icons.route,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Complete Route",
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: Icon(Icons.refresh),
                                  onPressed: () {
                                    _initializeLocationAndRoute();
                                  },
                                  tooltip: 'Refresh Routes',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InfoPill(
                                  icon: Icons.route,
                                  label: "Distance",
                                  value:
                                      "${(routeProvider.totalDistance / 1000).toStringAsFixed(1)} km",
                                  color: Colors.deepOrange,
                                ),
                                const SizedBox(width: 18),
                                InfoPill(
                                  icon: Icons.timer,
                                  label: "Time",
                                  value:
                                      "${(routeProvider.totalDuration / 60).toStringAsFixed(0)} min",
                                  color: Colors.indigo,
                                ),
                              ],
                            ),
                          ],
                        ),
              ),
            ),
          ),

          // Route segments list
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              child:
                  routeProvider.loading
                      ? Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount:
                            routeProvider.segments.length +
                            1, // +1 for "All Routes" option
                        itemBuilder: (context, index) {
                          // First card is "All Routes"
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSegmentIndex = -1;
                                    _updateMapObjects();
                                  });
                                },
                                child: RouteSegmentCard(
                                  title: "All Routes",
                                  subtitle:
                                      "${routeProvider.segments.length} segments",
                                  distance:
                                      "${(routeProvider.totalDistance / 1000).toStringAsFixed(1)} km",
                                  duration:
                                      "${(routeProvider.totalDuration / 60).toStringAsFixed(0)} min",
                                  color: Colors.grey,
                                  isSelected: _selectedSegmentIndex == -1,
                                ),
                              ),
                            );
                          }

                          // Actual route segments
                          final segmentIndex = index - 1;
                          final segment = routeProvider.segments[segmentIndex];

                          String title;
                          if (segment.startLabel.contains("Pickup") &&
                              segment.endLabel.contains("Dropoff")) {
                            title = "Ride ${segmentIndex ~/ 2 + 1}";
                          } else if (segment.startLabel.contains("Dropoff") &&
                              segment.endLabel.contains("Pickup")) {
                            title = "To Next Pickup";
                          } else {
                            title = "To First Pickup";
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedSegmentIndex = segmentIndex;
                                  _updateMapObjects();
                                });
                              },
                              child: RouteSegmentCard(
                                title: title,
                                subtitle:
                                    "${segment.startAddress} → ${segment.endAddress}",
                                distance:
                                    "${(segment.distance / 1000).toStringAsFixed(1)} km",
                                duration:
                                    "${(segment.duration / 60).toStringAsFixed(0)} min",
                                color: segment.color,
                                isSelected:
                                    _selectedSegmentIndex == segmentIndex,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}