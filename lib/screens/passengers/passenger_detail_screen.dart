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

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _addMapObjects() async {
    if (_pointAnnotationManager == null || _polylineAnnotationManager == null) return;
    
    // Clear existing annotations
    await _pointAnnotationManager!.deleteAll();
    await _polylineAnnotationManager!.deleteAll();
    
    // Add markers
    for (final markerOption in _markerOptions) {
      await _pointAnnotationManager!.create(markerOption);
    }
    
    // Add polylines
    for (final lineOption in _polylineOptions) {
      await _polylineAnnotationManager!.create(lineOption);
    }
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
      final driverLoc =
          context.read<DriverLocationProvider>().currentLocation ??
          Point(coordinates: Position(-104.9, 39.7)); // fallback

      Point pickup = widget.passenger.pickupLatLng;
      Point dropoff = widget.passenger.dropoffLatLng;

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

      List<PolylineAnnotationOptions> polylineOptions = [];
      int id = 1;
      for (var route in [route1, route2]) {
polylineOptions.add(
  PolylineAnnotationOptions(
    geometry: LineString(coordinates: route['polyline'].map<Position>((p) => p.coordinates).toList()),
    lineColor: id == 1 ? 0xFF2196F3 : 0xFFFF9800,
    lineWidth: 5.0,
  ),
);
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
        _markerOptions = [
          PointAnnotationOptions(
            geometry: driverLoc,
            iconImage: "marker-15", // Default Mapbox marker
          ),
          PointAnnotationOptions(
            geometry: pickup,
            iconImage: "marker-15",
          ),
          PointAnnotationOptions(
            geometry: dropoff,
            iconImage: "marker-15",
          ),
        ];
        _loading = false;
      });

      // Add objects and move camera after setState
      WidgetsBinding.instance.addPostFrameCallback((_) async {
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
                    onMapCreated: (MapboxMap mapboxMap) async {
                      _mapboxMap = mapboxMap;
                      
                      // Initialize annotation managers
                      _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                      _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
                      
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