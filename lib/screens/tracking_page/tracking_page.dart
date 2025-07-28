import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/native_location_service.dart';

class TrackingMapContent extends StatefulWidget {
  final String token;
  final int driverId;
  final String driverName;

  const TrackingMapContent({
    super.key,
    required this.token,
    required this.driverId,
    required this.driverName,
  });

  @override
  _TrackingMapContentState createState() => _TrackingMapContentState();
}

class _TrackingMapContentState extends State<TrackingMapContent> {
  LatLng? _currentPosition;
  double? _currentSpeed;
  StreamSubscription<Map<dynamic, dynamic>>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    _initLocationUpdates();
  }

  void _initLocationUpdates() {
    _locationSubscription = NativeLocationService.locationStream.listen(
      _handleLocationUpdate,
      onError: (error) {
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
  }

  void _handleLocationUpdate(Map<dynamic, dynamic> locationData) {
    if (!mounted) return;
    final newPosition = LatLng(locationData['lat'], locationData['lng']);
    final newSpeed = locationData['speed'] as double?;

    setState(() {
      _currentPosition = newPosition;
      _currentSpeed = newSpeed;
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speedInKmh = (_currentSpeed ?? 0) * 3.6;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: _currentPosition == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Current Location',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Speed',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${speedInKmh.toStringAsFixed(1)} km/h',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}