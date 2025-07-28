import 'dart:async';

import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:provider/provider.dart';

// import 'package:shimmer/shimmer.dart'; //

import '../../providers/driver_location_provider.dart';
import '../../providers/route_provider.dart';
import '../../models/passenger.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/modern_shimmer.dart';
import '../../widgets/info_pill.dart';
import '../../widgets/route_segement_card.dart';

class HomeMapPage extends StatefulWidget {
  const HomeMapPage({super.key});
  @override
  State<HomeMapPage> createState() => _HomeMapPageState();
}

class _HomeMapPageState extends State<HomeMapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  int _selectedSegmentIndex = -1; // -1 means show all routes

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationAndRoute();
    });
  }

  Future<void> _initializeLocationAndRoute() async {
    await context.read<DriverLocationProvider>().startTracking();

    // Wait for driver location to be available
    final driverProvider = context.read<DriverLocationProvider>();
    if (driverProvider.currentLocation == null) {
      await Future.delayed(Duration(seconds: 2));
    }

    final driverLocation =
        driverProvider.currentLocation ?? LatLng(39.7, -104.9);
    await context.read<RouteProvider>().buildCompleteRoute(
      passengerList,
      driverLocation,
    );

    _updateMapObjects();
  }

  void _updateMapObjects() {
    final routeProvider = context.read<RouteProvider>();
    final driverLoc =
        context.read<DriverLocationProvider>().currentLocation ??
        LatLng(39.7, -104.9);

    Set<Marker> markers = {};
    Set<Polyline> polylines = {};

    // Always add driver marker
    markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Driver Location'),
      ),
    );

    // If showing all segments, build all markers and polylines
    if (_selectedSegmentIndex == -1) {
      // Add all segment markers and polylines
      for (int i = 0; i < routeProvider.segments.length; i++) {
        final segment = routeProvider.segments[i];

        // No need to add start marker for first segment, as it's the driver
        if (i > 0 || segment.startLabel != "Driver") {
          markers.add(
            Marker(
              markerId: MarkerId('marker_start_$i'),
              position: segment.start,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                segment.startLabel.contains("Pickup")
                    ? BitmapDescriptor.hueAzure
                    : BitmapDescriptor.hueOrange,
              ),
              infoWindow: InfoWindow(
                title: segment.startLabel,
                snippet: segment.startAddress,
              ),
            ),
          );
        }

        // Always add end marker
        markers.add(
          Marker(
            markerId: MarkerId('marker_end_$i'),
            position: segment.end,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              segment.endLabel.contains("Pickup")
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: segment.endLabel,
              snippet: segment.endAddress,
            ),
          ),
        );

        // Add polyline
        polylines.add(
          Polyline(
            polylineId: PolylineId('polyline_$i'),
            points: segment.polylinePoints,
            color: segment.color,
            width: 5,
          ),
        );
      }
    } else {
      // Show only selected segment
      if (_selectedSegmentIndex >= 0 &&
          _selectedSegmentIndex < routeProvider.segments.length) {
        final segment = routeProvider.segments[_selectedSegmentIndex];

        // Add start marker
        markers.add(
          Marker(
            markerId: MarkerId('marker_start'),
            position: segment.start,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              segment.startLabel.contains("Pickup")
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: segment.startLabel,
              snippet: segment.startAddress,
            ),
          ),
        );

        // Add end marker
        markers.add(
          Marker(
            markerId: MarkerId('marker_end'),
            position: segment.end,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              segment.endLabel.contains("Pickup")
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueOrange,
            ),
            infoWindow: InfoWindow(
              title: segment.endLabel,
              snippet: segment.endAddress,
            ),
          ),
        );

        // Add polyline
        polylines.add(
          Polyline(
            polylineId: PolylineId('polyline'),
            points: segment.polylinePoints,
            color: segment.color,
            width: 5,
          ),
        );
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  @override
  void dispose() {
    context.read<DriverLocationProvider>().stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routeProvider = context.watch<RouteProvider>();
    final driverLoc = context.watch<DriverLocationProvider>().currentLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driverLoc ?? LatLng(39.7, -104.9),
              zoom: 11,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;

              // Set map style based on theme
              if (isDark) {
                controller.setMapStyle('''
                  [
                    {
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#242f3e"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#746855"
                        }
                      ]
                    },
                    {
                      "elementType": "labels.text.stroke",
                      "stylers": [
                        {
                          "color": "#242f3e"
                        }
                      ]
                    },
                    {
                      "featureType": "administrative.locality",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#d59563"
                        }
                      ]
                    },
                    {
                      "featureType": "poi",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#d59563"
                        }
                      ]
                    },
                    {
                      "featureType": "poi.park",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#263c3f"
                        }
                      ]
                    },
                    {
                      "featureType": "poi.park",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#6b9a76"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#38414e"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "geometry.stroke",
                      "stylers": [
                        {
                          "color": "#212a37"
                        }
                      ]
                    },
                    {
                      "featureType": "road",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#9ca5b3"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#746855"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "geometry.stroke",
                      "stylers": [
                        {
                          "color": "#1f2835"
                        }
                      ]
                    },
                    {
                      "featureType": "road.highway",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#f3d19c"
                        }
                      ]
                    },
                    {
                      "featureType": "transit",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#2f3948"
                        }
                      ]
                    },
                    {
                      "featureType": "transit.station",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#d59563"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "geometry",
                      "stylers": [
                        {
                          "color": "#17263c"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "labels.text.fill",
                      "stylers": [
                        {
                          "color": "#515c6d"
                        }
                      ]
                    },
                    {
                      "featureType": "water",
                      "elementType": "labels.text.stroke",
                      "stylers": [
                        {
                          "color": "#17263c"
                        }
                      ]
                    }
                  ]
                ''');
              }
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: true,
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

                                  // Fit map bounds to selected segment
                                  if (_mapController != null) {
                                    LatLngBounds bounds = _calculateBounds(
                                      segment.polylinePoints,
                                    );
                                    _mapController!.animateCamera(
                                      CameraUpdate.newLatLngBounds(bounds, 100),
                                    );
                                  }
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

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}