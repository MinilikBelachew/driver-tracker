import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _controller;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  String _distance = '';
  String _duration = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (LatLng latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      northeast: LatLng(x1!, y1!),
      southwest: LatLng(x0!, y0!),
    );
  }

  void _moveCameraToRoute(List<LatLng> points) {
    if (_controller == null || points.isEmpty) return;

    LatLngBounds bounds = _boundsFromLatLngList(points);
    _controller!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50), // 50 pixels padding
    );
  }

  Future<void> _fetchRoute() async {
    try {
      final driverLoc =
          context.read<DriverLocationProvider>().currentLocation ??
          LatLng(39.7, -104.9); // fallback

      LatLng pickup = widget.passenger.pickupLatLng;
      LatLng dropoff = widget.passenger.dropoffLatLng;

      // 1. Route from driver to pickup
      final route1 = await GoogleMapsService.getRoutePolyline(
        driverLoc,
        pickup,
      );
      // 2. Route from pickup to dropoff
      final route2 = await GoogleMapsService.getRoutePolyline(pickup, dropoff);

      if (route1 == null || route2 == null) {
        throw Exception('Could not calculate route');
      }

      Set<Polyline> plines = {};
      int id = 1;
      for (var route in [route1, route2]) {
        plines.add(
          Polyline(
            polylineId: PolylineId('route$id'),
            points: route['polyline'],
            color: id == 1 ? Colors.blue : Colors.orange,
            width: 5,
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
        _polylines = plines;
        _loading = false;
        _distance = dist;
        _duration = dur;
        _markers = {
          Marker(
            markerId: const MarkerId('driver'),
            position: driverLoc,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: const InfoWindow(title: 'Driver'),
          ),
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: InfoWindow(
              title: 'Pickup',
              snippet: widget.passenger.pickupAddress,
            ),
          ),
          Marker(
            markerId: const MarkerId('dropoff'),
            position: dropoff,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: 'Drop-off',
              snippet: widget.passenger.dropoffAddress,
            ),
          ),
        };
      });

      // Move camera to show entire route
      _moveCameraToRoute([...route1['polyline'], ...route2['polyline']]);
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
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: widget.passenger.pickupLatLng,
                        zoom: 11,
                      ),
                      markers: _markers,
                      polylines: _polylines,
                      onMapCreated: (controller) {
                        _controller = controller;
                        // Show driver info window by default
                        controller.showMarkerInfoWindow(
                          const MarkerId('driver'),
                        );
                      },
                      myLocationEnabled: true,
                      zoomControlsEnabled: false,
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
                          time:
                              widget.passenger.earliestPickup +
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