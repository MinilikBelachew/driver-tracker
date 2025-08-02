import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/passenger.dart';
import '../../providers/driver_location_provider.dart';
import '../../services/google_maps_service.dart';

class PassengerDetailPage extends StatefulWidget {
  final Passenger passenger;
  const PassengerDetailPage({super.key, required this.passenger});

  @override
  State<PassengerDetailPage> createState() => _PassengerDetailPageState();
}

class _PassengerDetailPageState extends State<PassengerDetailPage> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  List<PointAnnotationOptions> _markerOptions = [];
  List<PolylineAnnotationOptions> _polylineOptions = [];
  String _distance = '';
  String _duration = '';
  bool _loading = true;
  Map<Point, Map<String, String>> _markerInfo = {}; // Store marker info for popups

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _addMapObjects() async {
    if (_pointAnnotationManager == null || _polylineAnnotationManager == null) {
      print("Passenger detail: Annotation managers not initialized");
      return;
    }
    
    print("Passenger detail: Adding map objects: ${_markerOptions.length} markers, ${_polylineOptions.length} polylines");
    
    // Clear existing annotations
    await _pointAnnotationManager!.deleteAll();
    await _polylineAnnotationManager!.deleteAll();
    
    // Add markers
    for (final markerOption in _markerOptions) {
      await _pointAnnotationManager!.create(markerOption);
    }
    
    // Add polylines
    for (final lineOption in _polylineOptions) {
      print("Passenger detail: Adding polyline with ${lineOption.geometry.coordinates.length} coordinates");
      await _polylineAnnotationManager!.create(lineOption);
    }
    
    print("Passenger detail: Map objects added successfully");
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

  Future<void> _fetchRoute() async {
    setState(() { _loading = true; });
    try {
      print("Passenger detail: Fetching route for ${widget.passenger.name}");
      
      final driverLoc =
          context.read<DriverLocationProvider>().currentLocation ??
          Point(coordinates: Position(-104.9, 39.7)); // fallback

      Point pickup = widget.passenger.pickupLatLng;
      Point dropoff = widget.passenger.dropoffLatLng;
      
      print("Passenger detail: Driver location: ${driverLoc.coordinates.lat}, ${driverLoc.coordinates.lng}");
      print("Passenger detail: Pickup: ${pickup.coordinates.lat}, ${pickup.coordinates.lng}");
      print("Passenger detail: Dropoff: ${dropoff.coordinates.lat}, ${dropoff.coordinates.lng}");

      // 1. Route from driver to pickup
      final route1 = await MapboxService.getRoutePolyline(
        driverLoc,
        pickup,
      );
      // 2. Route from pickup to dropoff
      final route2 = await MapboxService.getRoutePolyline(pickup, dropoff);

      if (route1 == null || route2 == null) {
        throw Exception('Could not calculate route');
      }

      print("Passenger detail: Route1 points: ${route1['polyline'].length}");
      print("Passenger detail: Route2 points: ${route2['polyline'].length}");

      List<PolylineAnnotationOptions> polylineOptions = [];
      List<PointAnnotationOptions> routeMarkers = [];
      int id = 1;
      
      for (var route in [route1, route2]) {
        final polylinePoints = route['polyline'] as List<Point>;
        final routeColor = id == 1 ? 0xFF2196F3 : 0xFFFF9800;
        
        polylineOptions.add(
          PolylineAnnotationOptions(
            geometry: LineString(
              coordinates: polylinePoints.map((p) => p.coordinates).toList(),
            ),
            lineColor: routeColor,
            lineWidth: 5.0,
          ),
        );
        
        // Add start location icon
        if (polylinePoints.isNotEmpty) {
          routeMarkers.add(
            PointAnnotationOptions(
              geometry: polylinePoints.first,
              iconImage: "marker-15",
              iconColor: routeColor,
              iconSize: 1.2,
            ),
          );
        }
        
        // Add end location icon
        if (polylinePoints.length > 1) {
          routeMarkers.add(
            PointAnnotationOptions(
              geometry: polylinePoints.last,
              iconImage: "marker-15",
              iconColor: routeColor,
              iconSize: 1.2,
            ),
          );
        }
        
        id++;
      }
      
      // Calculate total distance and duration
      double totalDist = route1['distance'] + route2['distance'];
      double totalDur = route1['duration'] + route2['duration'];
      String dist = "${(totalDist / 1000).toStringAsFixed(1)} km";
      String dur = "${(totalDur / 60).toStringAsFixed(0)} min";

      setState(() {
        _polylineOptions = polylineOptions;
        _distance = dist;
        _duration = dur;
        _markerInfo.clear(); // Clear previous marker info
        
        _markerOptions = [
          PointAnnotationOptions(
            geometry: driverLoc,
            iconImage: "marker-15", // Driver marker (blue)
            iconColor: 0xFF1976D2, // Blue
          ),
          PointAnnotationOptions(
            geometry: pickup,
            iconImage: "bus-15", // Pickup marker (green)
            iconColor: 0xFF43A047, // Green
          ),
          PointAnnotationOptions(
            geometry: dropoff,
            iconImage: "embassy-15", // Dropoff marker (red)
            iconColor: 0xFFE53935, // Red
          ),
          ...routeMarkers, // Add route start/end markers
        ];
        
        // Store marker info for popups
        _markerInfo[driverLoc] = {
          'label': 'Driver',
          'address': 'Current Location',
        };
        _markerInfo[pickup] = {
          'label': 'Pickup',
          'address': widget.passenger.pickupAddress,
        };
        _markerInfo[dropoff] = {
          'label': 'Dropoff',
          'address': widget.passenger.dropoffAddress,
        };
        
        _loading = false;
      });
      
      print("Passenger detail: Set state with ${polylineOptions.length} polylines and ${_markerOptions.length} markers");

      // Add objects and move camera after setState
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        print("Passenger detail: Post frame callback - adding map objects");
        await _addMapObjects();
        await _moveCameraToRoute([
          ...route1['polyline'],
          ...route2['polyline'],
        ]);
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.passenger.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRoute,
            tooltip: 'Refresh Route',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: MapWidget(
                    key: ValueKey('mapbox_map'),
                    cameraOptions: CameraOptions(
                      center: widget.passenger.pickupLatLng,
                      zoom: 11.0,
                    ),
                    styleUri: MapboxStyles.MAPBOX_STREETS,
                    onMapCreated: (MapboxMap mapboxMap) async {
                      print("Passenger detail: Map created, initializing...");
                      _mapboxMap = mapboxMap;
                      
                      // Initialize annotation managers
                      _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                      _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
                      print("Passenger detail: Annotation managers created");
                      
                      // TODO: Add marker tap listener when Mapbox API is fixed
                      // _pointAnnotationManager!.addOnPointAnnotationClickListener((annotation) {
                      //   final point = annotation.geometry;
                      //   final info = _markerInfo[point];
                      //   if (info != null) {
                      //     _showMarkerInfoDialog(info['label']!, info['address']!);
                      //   }
                      // });
                      
                      // Wait a bit for the map to be fully ready
                      await Future.delayed(Duration(milliseconds: 1000));
                      
                      print("Passenger detail: Adding map objects after delay");
                      await _addMapObjects();
                      final allPoints = _polylineOptions.expand((l) => l.geometry.coordinates.map((c) => Point(coordinates: c))).toList();
                      if (allPoints.isNotEmpty) {
                        await _moveCameraToRoute(allPoints);
                      }
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Ride Information",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LocationInfoItem(
                        icon: Icons.location_on,
                        color: Colors.green,
                        title: "Pickup Location",
                        subtitle: widget.passenger.pickupAddress,
                        time: widget.passenger.earliestPickup +
                            " - " +
                            widget.passenger.latestPickup,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Container(
                          width: 2,
                          height: 24,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      LocationInfoItem(
                        icon: Icons.flag,
                        color: Colors.red,
                        title: "Dropoff Location",
                        subtitle: widget.passenger.dropoffAddress,
                        time: "",
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RouteInfoCard(
                            icon: Icons.straighten,
                            title: "Distance",
                            value: _distance,
                          ),
                          RouteInfoCard(
                            icon: Icons.timer,
                            title: "Duration",
                            value: _duration,
                          ),
                          RouteInfoCard(
                            icon: Icons.calendar_today,
                            title: "Pickup Window",
                            value: widget.passenger.earliestPickup,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class LocationInfoItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;

  const LocationInfoItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  "Time window: $time",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class RouteInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const RouteInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.28,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}